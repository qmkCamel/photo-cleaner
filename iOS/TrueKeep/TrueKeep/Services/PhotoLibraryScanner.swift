import Foundation
@preconcurrency import CoreML
import CoreGraphics
import Photos
@preconcurrency import UIKit
@preconcurrency import Vision

enum PhotoAssetMediaKind: Hashable, Sendable {
    case photo
    case video
}

struct PhotoAssetSnapshot: Hashable, Sendable {
    var id: String
    var kind: PhotoAssetMediaKind
    var isScreenshot: Bool
    var duration: TimeInterval
    var estimatedBytes: Int64?
    var visualClassification: PhotoVisualClassification?

    init(
        id: String,
        kind: PhotoAssetMediaKind,
        isScreenshot: Bool,
        duration: TimeInterval,
        estimatedBytes: Int64? = nil,
        visualClassification: PhotoVisualClassification? = nil
    ) {
        self.id = id
        self.kind = kind
        self.isScreenshot = isScreenshot
        self.duration = duration
        self.estimatedBytes = estimatedBytes
        self.visualClassification = visualClassification
    }
}

struct PhotoVisualClassification: Hashable, Sendable {
    var similarGroupID: String?
    var recommendedKeep: Bool
    var isAccidental: Bool
    var isBlurry: Bool

    init(
        similarGroupID: String? = nil,
        recommendedKeep: Bool = false,
        isAccidental: Bool = false,
        isBlurry: Bool = false
    ) {
        self.similarGroupID = similarGroupID
        self.recommendedKeep = recommendedKeep
        self.isAccidental = isAccidental
        self.isBlurry = isBlurry
    }

    var hasFindings: Bool {
        similarGroupID != nil || isAccidental || isBlurry
    }
}

struct PhotoVisualMetrics: Hashable, Sendable {
    var perceptualHash: UInt64
    var featurePrint: PhotoFeaturePrint?
    var brightness: Double
    var saturation: Double
    var sharpness: Double
    var quality: PhotoQualityAssessment

    init(
        perceptualHash: UInt64,
        featurePrint: PhotoFeaturePrint? = nil,
        brightness: Double,
        saturation: Double,
        sharpness: Double,
        quality: PhotoQualityAssessment? = nil
    ) {
        self.perceptualHash = perceptualHash
        self.featurePrint = featurePrint
        self.brightness = brightness
        self.saturation = saturation
        self.sharpness = sharpness
        let features = PhotoQualityFeatures(
            brightness: brightness,
            saturation: saturation,
            sharpness: sharpness,
            hashBitDensity: Double(perceptualHash.nonzeroBitCount) / 64.0
        )
        self.quality = quality ?? PhotoQualityAssessment.heuristic(from: features)
    }
}

enum PhotoFeatureElementType: Int, Hashable, Sendable {
    case unknown = 0
    case float = 1
    case double = 2

    init(visionElementType: VNElementType) {
        self = PhotoFeatureElementType(rawValue: Int(visionElementType.rawValue)) ?? .unknown
    }
}

struct PhotoFeaturePrint: Hashable, Sendable {
    var data: Data
    var elementType: PhotoFeatureElementType
    var elementCount: Int

    init(data: Data, elementType: PhotoFeatureElementType = .float, elementCount: Int? = nil) {
        self.data = data
        self.elementType = elementType
        switch elementType {
        case .float:
            self.elementCount = elementCount ?? data.count / MemoryLayout<Float>.stride
        case .double:
            self.elementCount = elementCount ?? data.count / MemoryLayout<Double>.stride
        case .unknown:
            self.elementCount = elementCount ?? 0
        }
    }

    init(observation: VNFeaturePrintObservation) {
        self.init(
            data: observation.data,
            elementType: PhotoFeatureElementType(visionElementType: observation.elementType),
            elementCount: observation.elementCount
        )
    }

    func distance(to other: PhotoFeaturePrint) -> Double? {
        guard elementType == other.elementType,
              elementCount == other.elementCount,
              elementCount > 0
        else {
            return nil
        }

        switch elementType {
        case .float:
            return normalizedDistance(to: other, elementSize: MemoryLayout<Float>.stride) { buffer, offset in
                Double(buffer.loadUnaligned(fromByteOffset: offset, as: Float.self))
            }
        case .double:
            return normalizedDistance(to: other, elementSize: MemoryLayout<Double>.stride) { buffer, offset in
                buffer.loadUnaligned(fromByteOffset: offset, as: Double.self)
            }
        case .unknown:
            return nil
        }
    }

    private func normalizedDistance(
        to other: PhotoFeaturePrint,
        elementSize: Int,
        valueAt: (UnsafeRawBufferPointer, Int) -> Double
    ) -> Double? {
        let requiredByteCount = elementCount * elementSize
        guard data.count >= requiredByteCount, other.data.count >= requiredByteCount else {
            return nil
        }

        return data.withUnsafeBytes { lhsBuffer in
            other.data.withUnsafeBytes { rhsBuffer in
                var squaredDistance = 0.0

                for index in 0..<elementCount {
                    let offset = index * elementSize
                    let delta = valueAt(lhsBuffer, offset) - valueAt(rhsBuffer, offset)
                    squaredDistance += delta * delta
                }

                return sqrt(squaredDistance / Double(elementCount))
            }
        }
    }
}

struct PhotoQualityFeatures: Hashable, Sendable {
    var brightness: Double
    var saturation: Double
    var sharpness: Double
    var hashBitDensity: Double

    var featureValues: [Double] {
        [brightness, saturation, sharpness, hashBitDensity]
    }
}

struct PhotoQualityAssessment: Hashable, Sendable {
    var overallQuality: Double
    var blurRisk: Double
    var accidentalRisk: Double

    init(overallQuality: Double, blurRisk: Double, accidentalRisk: Double) {
        self.overallQuality = Self.clamp(overallQuality)
        self.blurRisk = Self.clamp(blurRisk)
        self.accidentalRisk = Self.clamp(accidentalRisk)
    }

    static func heuristic(from features: PhotoQualityFeatures) -> PhotoQualityAssessment {
        let sharpnessScore = clamp(features.sharpness / 0.08)
        let exposureScore = clamp(1.0 - abs(features.brightness - 0.5) / 0.5)
        let saturationScore = clamp(features.saturation / 0.35)
        let overallQuality = (sharpnessScore * 0.65) + (exposureScore * 0.25) + (saturationScore * 0.10)

        let blurRisk = features.sharpness <= 0.018
            ? 1.0
            : clamp((0.028 - features.sharpness) / 0.010)
        let accidentalRisk: Double
        if features.brightness < 0.11
            || features.brightness > 0.92
            || (features.saturation < 0.045 && features.sharpness < 0.015) {
            accidentalRisk = 1.0
        } else {
            let darkRisk = clamp((0.16 - features.brightness) / 0.16)
            let brightRisk = clamp((features.brightness - 0.86) / 0.14)
            let lowInformationRisk = min(
                clamp((0.07 - features.saturation) / 0.07),
                clamp((0.024 - features.sharpness) / 0.024)
            )
            accidentalRisk = max(darkRisk, brightRisk, lowInformationRisk)
        }

        return PhotoQualityAssessment(
            overallQuality: overallQuality,
            blurRisk: blurRisk,
            accidentalRisk: accidentalRisk
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

protocol PhotoQualityScoring: Sendable {
    func assessment(for features: PhotoQualityFeatures) -> PhotoQualityAssessment?
}

struct HeuristicPhotoQualityScorer: PhotoQualityScoring {
    func assessment(for features: PhotoQualityFeatures) -> PhotoQualityAssessment? {
        PhotoQualityAssessment.heuristic(from: features)
    }
}

struct CoreMLPhotoQualityScorer: PhotoQualityScoring, @unchecked Sendable {
    static let bundledModelName = "TrueKeepPhotoQuality"

    private let model: MLModel

    init?(bundle: Bundle = .main, modelName: String = bundledModelName) {
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "mlmodelc"),
              let loadedModel = try? MLModel(contentsOf: modelURL)
        else {
            return nil
        }

        self.model = loadedModel
    }

    init(model: MLModel) {
        self.model = model
    }

    func assessment(for features: PhotoQualityFeatures) -> PhotoQualityAssessment? {
        guard let input = makeInput(from: features),
              let prediction = try? model.prediction(from: input)
        else {
            return nil
        }

        return Self.assessment(from: prediction)
    }

    static func assessment(from prediction: MLFeatureProvider) -> PhotoQualityAssessment? {
        let overallQuality = outputDouble(
            named: ["overall_quality", "quality_score", "quality"],
            from: prediction
        )
        let blurRisk = outputDouble(
            named: ["blur_risk", "blur_score", "blurry_risk", "blurry_score"],
            from: prediction
        )
        let accidentalRisk = outputDouble(
            named: ["accidental_risk", "accidental_score", "mistake_risk"],
            from: prediction
        )

        guard overallQuality != nil || blurRisk != nil || accidentalRisk != nil else {
            return nil
        }

        return PhotoQualityAssessment(
            overallQuality: overallQuality ?? 0.5,
            blurRisk: blurRisk ?? 0,
            accidentalRisk: accidentalRisk ?? 0
        )
    }

    private func makeInput(from features: PhotoQualityFeatures) -> MLFeatureProvider? {
        if model.modelDescription.inputDescriptionsByName["quality_features"] != nil,
           let featureArray = try? MLMultiArray(
            shape: [NSNumber(value: features.featureValues.count)],
            dataType: .double
           ) {
            for (index, value) in features.featureValues.enumerated() {
                featureArray[index] = NSNumber(value: value)
            }
            return try? MLDictionaryFeatureProvider(dictionary: [
                "quality_features": MLFeatureValue(multiArray: featureArray)
            ])
        }

        return try? MLDictionaryFeatureProvider(dictionary: [
            "brightness": features.brightness,
            "saturation": features.saturation,
            "sharpness": features.sharpness,
            "hash_density": features.hashBitDensity
        ])
    }

    private static func outputDouble(
        named candidateNames: [String],
        from prediction: MLFeatureProvider
    ) -> Double? {
        for name in candidateNames {
            guard let value = prediction.featureValue(for: name) else { continue }

            switch value.type {
            case .double:
                return value.doubleValue
            case .int64:
                return Double(value.int64Value)
            case .multiArray:
                guard let multiArray = value.multiArrayValue, multiArray.count > 0 else {
                    return nil
                }
                return multiArray[0].doubleValue
            default:
                continue
            }
        }

        return nil
    }
}

struct PhotoVisualInput: Hashable, Sendable {
    var assetID: String
    var creationDate: Date?
    var metrics: PhotoVisualMetrics
}

struct PhotoLibraryScanPolicy: Hashable, Sendable {
    var isLowPowerModeEnabled: Bool
    var standardBatchSize: Int
    var lowPowerBatchSize: Int
    var standardVisualClassificationLimit: Int
    var lowPowerVisualClassificationLimit: Int

    init(
        isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        standardBatchSize: Int = 200,
        lowPowerBatchSize: Int = 50,
        standardVisualClassificationLimit: Int = 300,
        lowPowerVisualClassificationLimit: Int = 80
    ) {
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.standardBatchSize = max(1, standardBatchSize)
        self.lowPowerBatchSize = max(1, lowPowerBatchSize)
        self.standardVisualClassificationLimit = max(0, standardVisualClassificationLimit)
        self.lowPowerVisualClassificationLimit = max(0, lowPowerVisualClassificationLimit)
    }

    var effectiveBatchSize: Int {
        isLowPowerModeEnabled ? lowPowerBatchSize : standardBatchSize
    }

    var effectiveVisualClassificationLimit: Int {
        isLowPowerModeEnabled ? lowPowerVisualClassificationLimit : standardVisualClassificationLimit
    }
}

enum PhotoAssetSnapshotBatcher {
    static func batchRanges(totalCount: Int, batchSize: Int) -> [Range<Int>] {
        guard totalCount > 0 else { return [] }

        let effectiveBatchSize = max(1, batchSize)
        return stride(from: 0, to: totalCount, by: effectiveBatchSize).map { start in
            start..<min(start + effectiveBatchSize, totalCount)
        }
    }

    static func collect<T>(
        totalCount: Int,
        batchSize: Int,
        shouldCancel: () -> Bool = { Task.isCancelled },
        itemAt: (Int) -> T
    ) async throws -> [T] {
        var items: [T] = []
        items.reserveCapacity(totalCount)

        for range in batchRanges(totalCount: totalCount, batchSize: batchSize) {
            if shouldCancel() {
                throw CancellationError()
            }

            for index in range {
                items.append(itemAt(index))
            }

            await Task.yield()
        }

        return items
    }
}

protocol PhotoLibraryScanning: Sendable {
    func scan(access: PhotoLibraryAccess) async -> CleanupFlowState
}

struct SystemPhotoLibraryScanner: PhotoLibraryScanning {
    private let policy: PhotoLibraryScanPolicy
    private let qualityScorer: any PhotoQualityScoring

    init(
        policy: PhotoLibraryScanPolicy = .init(),
        qualityScorer: (any PhotoQualityScoring)? = CoreMLPhotoQualityScorer()
    ) {
        self.policy = policy
        self.qualityScorer = qualityScorer ?? HeuristicPhotoQualityScorer()
    }

    func scan(access: PhotoLibraryAccess) async -> CleanupFlowState {
        guard access.canScan else {
            return PhotoScanResultBuilder.state(from: [])
        }

        do {
            return PhotoScanResultBuilder.state(from: try await fetchAssetSnapshots())
        } catch is CancellationError {
            return PhotoScanResultBuilder.state(from: [])
        } catch {
            return PhotoScanResultBuilder.state(from: [])
        }
    }

    private func fetchAssetSnapshots() async throws -> [PhotoAssetSnapshot] {
        let photoAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions())
        let visualClassifications = try await fetchVisualClassifications(from: photoAssets)
        let photoSnapshots = try await PhotoAssetSnapshotBatcher.collect(
            totalCount: photoAssets.count,
            batchSize: policy.effectiveBatchSize
        ) { index in
            let asset = photoAssets.object(at: index)
            return PhotoAssetSnapshot(
                id: asset.localIdentifier,
                kind: .photo,
                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                duration: 0,
                visualClassification: visualClassifications[asset.localIdentifier]
            )
        }

        let videoAssets = PHAsset.fetchAssets(with: .video, options: fetchOptions())
        let videoSnapshots = try await PhotoAssetSnapshotBatcher.collect(
            totalCount: videoAssets.count,
            batchSize: policy.effectiveBatchSize
        ) { index in
            let asset = videoAssets.object(at: index)
            return PhotoAssetSnapshot(
                id: asset.localIdentifier,
                kind: .video,
                isScreenshot: false,
                duration: asset.duration
            )
        }

        return photoSnapshots + videoSnapshots
    }

    private func fetchVisualClassifications(
        from photoAssets: PHFetchResult<PHAsset>
    ) async throws -> [String: PhotoVisualClassification] {
        guard policy.effectiveVisualClassificationLimit > 0 else { return [:] }

        let imageManager = PHImageManager.default()
        let maxCount = min(photoAssets.count, policy.effectiveVisualClassificationLimit)
        var inputs: [PhotoVisualInput] = []
        inputs.reserveCapacity(maxCount)

        for index in 0..<maxCount {
            try Task.checkCancellation()

            let asset = photoAssets.object(at: index)
            guard !asset.mediaSubtypes.contains(.photoScreenshot),
                  let metrics = Self.visualMetrics(
                    for: asset,
                    imageManager: imageManager,
                    qualityScorer: qualityScorer
                  )
            else {
                continue
            }

            inputs.append(
                PhotoVisualInput(
                    assetID: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    metrics: metrics
                )
            )

            if index.isMultiple(of: 25) {
                await Task.yield()
            }
        }

        return PhotoVisualClassifier.classifications(from: inputs)
    }

    private static func visualMetrics(
        for asset: PHAsset,
        imageManager: PHImageManager,
        qualityScorer: any PhotoQualityScoring
    ) -> PhotoVisualMetrics? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true

        var requestedImage: UIImage?
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 224, height: 224),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let hasError = info?[PHImageErrorKey] != nil
            guard !isCancelled, !hasError else { return }
            requestedImage = image
        }

        guard let cgImage = requestedImage?.cgImage else { return nil }
        return PhotoVisualAnalyzer.metrics(from: cgImage, qualityScorer: qualityScorer)
    }

    private func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        return options
    }
}

enum PhotoVisualClassifier {
    private static let similarHashDistance = 8
    private static let similarFeaturePrintDistance = 0.16
    private static let similarTimeWindow: TimeInterval = 180
    private static let blurryQualityRiskThreshold = 0.85
    private static let accidentalQualityRiskThreshold = 0.85

    static func classifications(from inputs: [PhotoVisualInput]) -> [String: PhotoVisualClassification] {
        guard !inputs.isEmpty else { return [:] }

        var classifications: [String: PhotoVisualClassification] = [:]
        var groupedAssetIDs = Set<String>()
        let sortedInputs = inputs.sorted { lhs, rhs in
            (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
        }

        for input in sortedInputs where !groupedAssetIDs.contains(input.assetID) {
            let cluster = sortedInputs.filter { candidate in
                guard !groupedAssetIDs.contains(candidate.assetID) else { return false }
                return isSimilar(input, candidate)
            }

            guard cluster.count >= 2 else { continue }

            let keepAssetID = cluster.max { lhs, rhs in
                lhs.metrics.quality.overallQuality < rhs.metrics.quality.overallQuality
            }?.assetID
            let groupID = stableGroupID(for: cluster.map(\.assetID))

            for member in cluster {
                groupedAssetIDs.insert(member.assetID)
                classifications[member.assetID] = PhotoVisualClassification(
                    similarGroupID: groupID,
                    recommendedKeep: member.assetID == keepAssetID
                )
            }
        }

        for input in inputs where !groupedAssetIDs.contains(input.assetID) {
            var classification = classifications[input.assetID] ?? PhotoVisualClassification()
            classification.isAccidental = isAccidental(input.metrics)
            classification.isBlurry = !classification.isAccidental && isBlurry(input.metrics)

            if classification.hasFindings {
                classifications[input.assetID] = classification
            }
        }

        return classifications
    }

    private static func isSimilar(_ lhs: PhotoVisualInput, _ rhs: PhotoVisualInput) -> Bool {
        if lhs.assetID == rhs.assetID {
            return true
        }

        guard let lhsDate = lhs.creationDate,
              let rhsDate = rhs.creationDate,
              abs(lhsDate.timeIntervalSince(rhsDate)) <= similarTimeWindow
        else {
            return false
        }

        if let lhsFeaturePrint = lhs.metrics.featurePrint,
           let rhsFeaturePrint = rhs.metrics.featurePrint,
           let distance = lhsFeaturePrint.distance(to: rhsFeaturePrint) {
            return distance <= similarFeaturePrintDistance
        }

        return hammingDistance(lhs.metrics.perceptualHash, rhs.metrics.perceptualHash) <= similarHashDistance
    }

    private static func isBlurry(_ metrics: PhotoVisualMetrics) -> Bool {
        metrics.quality.blurRisk >= blurryQualityRiskThreshold
    }

    private static func isAccidental(_ metrics: PhotoVisualMetrics) -> Bool {
        metrics.quality.accidentalRisk >= accidentalQualityRiskThreshold
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    private static func stableGroupID(for assetIDs: [String]) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in assetIDs.sorted().joined(separator: "|").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "similar-\(String(hash, radix: 16))"
    }
}

enum PhotoVisualAnalyzer {
    private static let sampleWidth = 32
    private static let sampleHeight = 32
    private static let bytesPerPixel = 4

    static func metrics(
        from cgImage: CGImage,
        qualityScorer: any PhotoQualityScoring = HeuristicPhotoQualityScorer()
    ) -> PhotoVisualMetrics? {
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }

        guard rendered else { return nil }

        var luminance = [Double]()
        luminance.reserveCapacity(sampleWidth * sampleHeight)
        var brightnessSum = 0.0
        var saturationSum = 0.0

        for pixelIndex in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[pixelIndex]) / 255.0
            let green = Double(pixels[pixelIndex + 1]) / 255.0
            let blue = Double(pixels[pixelIndex + 2]) / 255.0
            let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let saturation = maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel

            luminance.append(luma)
            brightnessSum += luma
            saturationSum += saturation
        }

        let pixelCount = Double(luminance.count)
        guard pixelCount > 0 else { return nil }
        let perceptualHash = perceptualHash(from: luminance)
        let brightness = brightnessSum / pixelCount
        let saturation = saturationSum / pixelCount
        let sharpness = edgeSharpness(from: luminance)
        let qualityFeatures = PhotoQualityFeatures(
            brightness: brightness,
            saturation: saturation,
            sharpness: sharpness,
            hashBitDensity: Double(perceptualHash.nonzeroBitCount) / 64.0
        )

        return PhotoVisualMetrics(
            perceptualHash: perceptualHash,
            featurePrint: PhotoFeaturePrintGenerator.featurePrint(from: cgImage),
            brightness: brightness,
            saturation: saturation,
            sharpness: sharpness,
            quality: qualityScorer.assessment(for: qualityFeatures)
                ?? PhotoQualityAssessment.heuristic(from: qualityFeatures)
        )
    }

    private static func edgeSharpness(from luminance: [Double]) -> Double {
        guard luminance.count == sampleWidth * sampleHeight else { return 0 }

        var edgeSum = 0.0
        var comparisons = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let index = y * sampleWidth + x

                if x > 0 {
                    edgeSum += abs(luminance[index] - luminance[index - 1])
                    comparisons += 1
                }

                if y > 0 {
                    edgeSum += abs(luminance[index] - luminance[index - sampleWidth])
                    comparisons += 1
                }
            }
        }

        return comparisons == 0 ? 0 : edgeSum / Double(comparisons)
    }

    private static func perceptualHash(from luminance: [Double]) -> UInt64 {
        guard luminance.count == sampleWidth * sampleHeight else { return 0 }

        var hash: UInt64 = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let left = sampledLuminance(luminance, x: x, y: y)
                let right = sampledLuminance(luminance, x: x + 1, y: y)
                if left > right {
                    hash |= UInt64(1) << UInt64(y * 8 + x)
                }
            }
        }

        return hash
    }

    private static func sampledLuminance(_ luminance: [Double], x: Int, y: Int) -> Double {
        let sourceX = min(sampleWidth - 1, Int((Double(x) / 8.0) * Double(sampleWidth - 1)))
        let sourceY = min(sampleHeight - 1, Int((Double(y) / 7.0) * Double(sampleHeight - 1)))
        return luminance[sourceY * sampleWidth + sourceX]
    }
}

enum PhotoFeaturePrintGenerator {
    static func featurePrint(from cgImage: CGImage) -> PhotoFeaturePrint? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            return PhotoFeaturePrint(observation: observation)
        } catch {
            return nil
        }
    }
}

enum PhotoScanResultBuilder {
    static func state(from snapshots: [PhotoAssetSnapshot]) -> CleanupFlowState {
        let screenshotCandidates = candidates(
            from: snapshots.filter(\.isScreenshot),
            category: .screenshots
        )
        let largeVideoCandidates = candidates(
            from: snapshots.filter { snapshot in
                snapshot.kind == .video && isLargeVideo(snapshot)
            },
            category: .largeVideos
        )
        let visuallyClassifiedPhotos = snapshots.filter { snapshot in
            snapshot.kind == .photo && !snapshot.isScreenshot && snapshot.visualClassification?.hasFindings == true
        }
        let similarGroups = similarReviewGroups(from: visuallyClassifiedPhotos)
        let similarAssetIDs = Set(similarGroups.flatMap { group in
            group.candidates.map(\.id)
        })
        let accidentalCandidates = candidates(
            from: visuallyClassifiedPhotos.filter { snapshot in
                !similarAssetIDs.contains(snapshot.id) && snapshot.visualClassification?.isAccidental == true
            },
            category: .accidental
        )
        let blurryCandidates = candidates(
            from: visuallyClassifiedPhotos.filter { snapshot in
                !similarAssetIDs.contains(snapshot.id) && snapshot.visualClassification?.isBlurry == true
            },
            category: .blurry
        )

        let groups = similarGroups + [
            reviewGroup(
                id: "screenshots",
                category: .screenshots,
                title: "截图和临时信息",
                explanation: "这些是系统识别出的截图。临时聊天截图、票据和一次性信息通常可以优先复核。",
                candidates: screenshotCandidates
            ),
            reviewGroup(
                id: "accidental",
                category: .accidental,
                title: "可能是误拍",
                explanation: "这些照片亮度、色彩或画面信息异常，像口袋误触、地面、天花板或无主体画面。请逐张确认。",
                candidates: accidentalCandidates
            ),
            reviewGroup(
                id: "blurry",
                category: .blurry,
                title: "模糊或遮挡",
                explanation: "这些照片的边缘清晰度较低，可能是手抖、失焦或遮挡。低置信度项目默认不替你选中。",
                candidates: blurryCandidates
            ),
            reviewGroup(
                id: "large-videos",
                category: .largeVideos,
                title: "占空间的视频",
                explanation: "这些视频时长较长或体积较大。请先确认是否还有纪念价值，再加入复核箱。",
                candidates: largeVideoCandidates
            )
        ].compactMap { $0 }

        let tasks = groups.map { group in
            CleanupTask(
                id: group.id,
                category: group.category,
                description: taskDescription(for: group.category, count: group.candidates.count),
                candidateCount: group.candidates.count,
                estimatedBytes: group.estimatedBytes,
                confidenceLabel: confidenceLabel(for: group.category),
                previewCandidates: Array(group.candidates.prefix(4))
            )
        }

        return CleanupFlowState(
            tasks: tasks,
            reviewGroups: groups,
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: Set(groups.first?.candidates.filter(\.defaultSelectedForDeletion).map(\.id) ?? []),
            reviewBinItems: [],
            hasDeletedItems: false,
            postDeletionRecoveryMessage: nil,
            deletionErrorMessage: nil
        )
    }

    private static func candidates(
        from snapshots: [PhotoAssetSnapshot],
        category: CleanupCategory
    ) -> [CleanupCandidate] {
        snapshots.enumerated().map { index, snapshot in
            let recommendedKeep = category == .similar && snapshot.visualClassification?.recommendedKeep == true
            return CleanupCandidate(
                id: snapshot.id,
                category: category,
                confidence: confidence(for: category),
                defaultSelectedForDeletion: defaultSelectedForDeletion(
                    category: category,
                    recommendedKeep: recommendedKeep
                ),
                recommendedKeep: recommendedKeep,
                reason: reason(for: category),
                estimatedBytes: estimatedBytes(for: snapshot, category: category),
                thumbnail: thumbnail(for: category, index: index),
                thumbnailAssetID: snapshot.id
            )
        }
    }

    private static func similarReviewGroups(from snapshots: [PhotoAssetSnapshot]) -> [CleanupGroup] {
        let groupedSnapshots = Dictionary(grouping: snapshots) { snapshot in
            snapshot.visualClassification?.similarGroupID
        }
        let groups = groupedSnapshots.compactMap { groupID, snapshots -> (String, [PhotoAssetSnapshot])? in
            guard let groupID, snapshots.count >= 2 else { return nil }
            return (groupID, snapshots)
        }
        .sorted { lhs, rhs in
            lhs.0 < rhs.0
        }

        return groups.enumerated().map { index, group in
            let candidates = candidates(from: group.1, category: .similar)
            return CleanupGroup(
                id: group.0,
                category: .similar,
                title: "相似照片",
                subtitle: "第 \(index + 1) 组 / \(groups.count) 组",
                groupIndex: index + 1,
                totalGroups: groups.count,
                explanation: "这些照片来自短时间内的相似画面。留真会推荐保留清晰度最高的一张，其余项目需要你确认后才能加入复核箱。",
                candidates: candidates
            )
        }
    }

    private static func reviewGroup(
        id: String,
        category: CleanupCategory,
        title: String,
        explanation: String,
        candidates: [CleanupCandidate]
    ) -> CleanupGroup? {
        guard !candidates.isEmpty else { return nil }

        return CleanupGroup(
            id: id,
            category: category,
            title: title,
            subtitle: "\(candidates.count) 项",
            groupIndex: 1,
            totalGroups: 1,
            explanation: explanation,
            candidates: candidates
        )
    }

    private static func isLargeVideo(_ snapshot: PhotoAssetSnapshot) -> Bool {
        if let estimatedBytes = snapshot.estimatedBytes, estimatedBytes >= 500_000_000 {
            return true
        }
        return snapshot.duration >= 300
    }

    private static func defaultSelectedForDeletion(category: CleanupCategory, recommendedKeep: Bool) -> Bool {
        guard !recommendedKeep else { return false }

        switch category {
        case .similar, .screenshots, .largeVideos:
            return true
        case .accidental, .blurry:
            return false
        }
    }

    private static func estimatedBytes(
        for snapshot: PhotoAssetSnapshot,
        category: CleanupCategory
    ) -> Int64 {
        if let estimatedBytes = snapshot.estimatedBytes {
            return estimatedBytes
        }

        switch category {
        case .screenshots:
            return 1_200_000
        case .largeVideos:
            return max(120_000_000, Int64(snapshot.duration * 6_000_000))
        case .similar, .accidental, .blurry:
            return 2_500_000
        }
    }

    private static func taskDescription(for category: CleanupCategory, count: Int) -> String {
        switch category {
        case .screenshots:
            return "\(count) 张截图，优先复核临时内容"
        case .largeVideos:
            return "\(count) 个长视频或大视频，建议逐个确认"
        case .similar:
            return "\(count) 张本机识别的相似照片，已推荐保留一张"
        case .accidental:
            return "\(count) 张疑似误拍，低置信度复核"
        case .blurry:
            return "\(count) 张疑似模糊或遮挡，低置信度复核"
        }
    }

    private static func confidenceLabel(for category: CleanupCategory) -> String {
        switch category {
        case .screenshots:
            return "可快速清理"
        case .largeVideos:
            return "建议复核"
        case .similar:
            return "推荐复核"
        case .accidental, .blurry:
            return "谨慎复核"
        }
    }

    private static func confidence(for category: CleanupCategory) -> CandidateConfidence {
        switch category {
        case .screenshots:
            return .high
        case .largeVideos, .similar:
            return .medium
        case .accidental, .blurry:
            return .low
        }
    }

    private static func reason(for category: CleanupCategory) -> String {
        switch category {
        case .screenshots:
            return "系统识别为截图，可能是临时信息。"
        case .largeVideos:
            return "时长较长或体积较大，建议复核。"
        case .similar:
            return "本机视觉识别为短时间内的相似画面。"
        case .accidental:
            return "亮度、色彩或画面信息异常，可能是误拍。"
        case .blurry:
            return "边缘清晰度较低，可能是模糊或遮挡。"
        }
    }

    private static func thumbnail(for category: CleanupCategory, index: Int) -> ThumbnailStyle {
        switch category {
        case .screenshots:
            return [ThumbnailStyle.screenshot, .receipt, .notes][index % 3]
        case .largeVideos:
            return [ThumbnailStyle.videoSunset, .videoPark, .videoIndoor][index % 3]
        case .similar:
            return .kidPortrait
        case .accidental:
            return .floor
        case .blurry:
            return .blur
        }
    }
}
