import Foundation
@preconcurrency import CoreML
import CoreGraphics
import CryptoKit
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
    var isExactDuplicate: Bool
    var wasRefined: Bool

    init(
        similarGroupID: String? = nil,
        recommendedKeep: Bool = false,
        isAccidental: Bool = false,
        isBlurry: Bool = false,
        isExactDuplicate: Bool = false,
        wasRefined: Bool = true
    ) {
        self.similarGroupID = similarGroupID
        self.recommendedKeep = recommendedKeep
        self.isAccidental = isAccidental
        self.isBlurry = isBlurry
        self.isExactDuplicate = isExactDuplicate
        self.wasRefined = wasRefined
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
    var aspectRatio: Double
    var quality: PhotoQualityAssessment

    init(
        perceptualHash: UInt64,
        featurePrint: PhotoFeaturePrint? = nil,
        brightness: Double,
        saturation: Double,
        sharpness: Double,
        aspectRatio: Double = 1,
        quality: PhotoQualityAssessment? = nil
    ) {
        self.perceptualHash = perceptualHash
        self.featurePrint = featurePrint
        self.brightness = brightness
        self.saturation = saturation
        self.sharpness = sharpness
        self.aspectRatio = max(0.01, aspectRatio)
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
    var faceCaptureQuality: Double?
    var isUtility: Bool
    var source: PhotoQualitySource

    init(
        overallQuality: Double,
        blurRisk: Double,
        accidentalRisk: Double,
        faceCaptureQuality: Double? = nil,
        isUtility: Bool = false,
        source: PhotoQualitySource = .heuristic
    ) {
        self.overallQuality = Self.clamp(overallQuality)
        self.blurRisk = Self.clamp(blurRisk)
        self.accidentalRisk = Self.clamp(accidentalRisk)
        self.faceCaptureQuality = faceCaptureQuality.map(Self.clamp)
        self.isUtility = isUtility
        self.source = source
    }

    var recommendedKeepScore: Double {
        guard let faceCaptureQuality else { return overallQuality }
        return (overallQuality * 0.8) + (faceCaptureQuality * 0.2)
    }

    static func heuristic(
        from features: PhotoQualityFeatures,
        thresholds: PhotoQualityThresholds = .coarse
    ) -> PhotoQualityAssessment {
        let sharpnessScore = clamp(features.sharpness / thresholds.sharpnessExcellent)
        let exposureScore = clamp(1.0 - abs(features.brightness - 0.5) / 0.5)
        let saturationScore = clamp(features.saturation / 0.35)
        let overallQuality = (sharpnessScore * 0.65) + (exposureScore * 0.25) + (saturationScore * 0.10)

        let blurRisk = features.sharpness <= thresholds.blurCertain
            ? 1.0
            : clamp(
                (thresholds.blurClear - features.sharpness)
                    / max(0.0001, thresholds.blurClear - thresholds.blurCertain)
            )
        let accidentalRisk: Double
        if features.brightness < 0.11
            || features.brightness > 0.92
            || (features.saturation < 0.045 && features.sharpness < thresholds.lowInformationCertain) {
            accidentalRisk = 1.0
        } else {
            let darkRisk = clamp((0.16 - features.brightness) / 0.16)
            let brightRisk = clamp((features.brightness - 0.86) / 0.14)
            let lowInformationRisk = min(
                clamp((0.07 - features.saturation) / 0.07),
                clamp(
                    (thresholds.lowInformationClear - features.sharpness)
                        / thresholds.lowInformationClear
                )
            )
            accidentalRisk = max(darkRisk, brightRisk, lowInformationRisk)
        }

        return PhotoQualityAssessment(
            overallQuality: overallQuality,
            blurRisk: blurRisk,
            accidentalRisk: accidentalRisk,
            source: .heuristic
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

struct PhotoQualityThresholds: Hashable, Sendable {
    var sharpnessExcellent: Double
    var blurCertain: Double
    var blurClear: Double
    var lowInformationCertain: Double
    var lowInformationClear: Double

    static let coarse = PhotoQualityThresholds(
        sharpnessExcellent: 0.08,
        blurCertain: 0.018,
        blurClear: 0.028,
        lowInformationCertain: 0.015,
        lowInformationClear: 0.024
    )

    // Refined sharpness is normalized back to the coarse reference scale, but it
    // keeps a separate policy so future calibration cannot silently change both stages.
    static let refined = PhotoQualityThresholds(
        sharpnessExcellent: 0.08,
        blurCertain: 0.018,
        blurClear: 0.028,
        lowInformationCertain: 0.015,
        lowInformationClear: 0.024
    )
}

enum PhotoVisualAnalysisStage: Hashable, Sendable {
    case coarse
    case refined
}

struct PhotoVisualAnalysisPolicy: Hashable, Sendable {
    var coarseTargetLongSide: CGFloat = 224
    var refinedTargetLongSide: CGFloat = 512
    var coarseRasterLongSide: Int = 64
    var refinedRasterLongSide: Int = 128
    var similarHashDistance: Int = 8
    var similarFeaturePrintDistance: Double = 0.16
    var exactFeaturePrintDistance: Double = 0.025
    var similarTimeWindow: TimeInterval = 180
    var blurryRiskThreshold: Double = 0.85
    var accidentalRiskThreshold: Double = 0.85
    var coarseBoundaryRiskThreshold: Double = 0.70
    var aspectRatioLogTolerance: Double = 0.16

    func targetSize(for stage: PhotoVisualAnalysisStage) -> CGSize {
        let side = stage == .coarse ? coarseTargetLongSide : refinedTargetLongSide
        return CGSize(width: side, height: side)
    }

    func rasterLongSide(for stage: PhotoVisualAnalysisStage) -> Int {
        stage == .coarse ? coarseRasterLongSide : refinedRasterLongSide
    }

    func qualityThresholds(for stage: PhotoVisualAnalysisStage) -> PhotoQualityThresholds {
        stage == .coarse ? .coarse : .refined
    }
}

enum PhotoQualitySource: String, Hashable, Sendable {
    case heuristic
    case visionAesthetics
    case customCoreML
}

protocol PhotoQualityScoring: Sendable {
    func assessment(
        for image: CGImage,
        features: PhotoQualityFeatures
    ) -> PhotoQualityAssessment?
}

struct HeuristicPhotoQualityScorer: PhotoQualityScoring {
    func assessment(
        for image: CGImage,
        features: PhotoQualityFeatures
    ) -> PhotoQualityAssessment? {
        PhotoQualityAssessment.heuristic(from: features)
    }
}

struct VisionPhotoQualityScorer: PhotoQualityScoring {
    func assessment(
        for image: CGImage,
        features: PhotoQualityFeatures
    ) -> PhotoQualityAssessment? {
        let aestheticsRequest = VNCalculateImageAestheticsScoresRequest()
        let faceQualityRequest = VNDetectFaceCaptureQualityRequest()
        faceQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision3

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([aestheticsRequest, faceQualityRequest])
        } catch {
            return nil
        }

        guard let aesthetics = aestheticsRequest.results?.first else { return nil }
        let faceQualities = faceQualityRequest.results?.compactMap(\.faceCaptureQuality) ?? []

        return Self.assessment(
            overallScore: Double(aesthetics.overallScore),
            isUtility: aesthetics.isUtility,
            faceCaptureQualities: faceQualities.map(Double.init),
            heuristic: PhotoQualityAssessment.heuristic(from: features)
        )
    }

    static func assessment(
        overallScore: Double,
        isUtility: Bool,
        faceCaptureQualities: [Double],
        heuristic: PhotoQualityAssessment
    ) -> PhotoQualityAssessment {
        let normalizedOverallQuality = (overallScore + 1.0) / 2.0
        let modelAccidentalRisk = isUtility ? 0 : max(0, -overallScore)
        let faceCaptureQuality = faceCaptureQualities.isEmpty
            ? nil
            : faceCaptureQualities.reduce(0, +) / Double(faceCaptureQualities.count)

        return PhotoQualityAssessment(
            overallQuality: normalizedOverallQuality,
            blurRisk: heuristic.blurRisk,
            accidentalRisk: max(heuristic.accidentalRisk, modelAccidentalRisk),
            faceCaptureQuality: faceCaptureQuality,
            isUtility: isUtility,
            source: .visionAesthetics
        )
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

    func assessment(
        for image: CGImage,
        features: PhotoQualityFeatures
    ) -> PhotoQualityAssessment? {
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
            accidentalRisk: accidentalRisk ?? 0,
            source: .customCoreML
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

enum PhotoImageRequestStrategy {
    static let deliveryModes: [PHImageRequestOptionsDeliveryMode] = [
        .fastFormat,
        .highQualityFormat
    ]

    static func firstAvailable<Value>(
        request: (PHImageRequestOptionsDeliveryMode) -> Value?
    ) -> Value? {
        for deliveryMode in deliveryModes {
            if let value = request(deliveryMode) {
                return value
            }
        }

        return nil
    }

    static func requestOptions(
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true
        return options
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

enum PhotoResourceDigestKind: Hashable, Sendable {
    case stillPhoto
    case livePhoto
}

struct PhotoResourceDigestSet: Hashable, Sendable {
    var kind: PhotoResourceDigestKind
    var photoDigest: Data
    var pairedVideoDigest: Data? = nil

    var isComplete: Bool {
        switch kind {
        case .stillPhoto:
            return !photoDigest.isEmpty
        case .livePhoto:
            return !photoDigest.isEmpty && pairedVideoDigest?.isEmpty == false
        }
    }
}

enum PhotoExactDuplicateGrouper {
    static func groups(
        candidateAssetIDs: [String],
        digestsByAssetID: [String: PhotoResourceDigestSet]
    ) -> [[String]] {
        let comparable = candidateAssetIDs.compactMap { assetID -> (String, PhotoResourceDigestSet)? in
            guard let digest = digestsByAssetID[assetID], digest.isComplete else { return nil }
            return (assetID, digest)
        }
        let grouped = Dictionary(grouping: comparable, by: { $0.1 })
        return grouped.values
            .map { $0.map(\.0).sorted() }
            .filter { $0.count >= 2 }
            .sorted { $0.lexicographicallyPrecedes($1) }
    }
}

struct SystemPhotoDuplicateVerifier {
    func exactDuplicateGroups(
        candidateGroups: [[String]],
        assetsByID: [String: PHAsset]
    ) async throws -> [[String]] {
        var exactGroups: [[String]] = []

        for candidateGroup in candidateGroups {
            try Task.checkCancellation()
            var digestsByAssetID: [String: PhotoResourceDigestSet] = [:]

            for assetID in candidateGroup.sorted() {
                try Task.checkCancellation()
                guard let asset = assetsByID[assetID] else { continue }
                do {
                    if let digest = try await digestSet(for: asset) {
                        digestsByAssetID[assetID] = digest
                    }
                } catch {
                    try Task.checkCancellation()
                    // A single unavailable local resource only removes exact-duplicate evidence.
                }
            }

            exactGroups.append(
                contentsOf: PhotoExactDuplicateGrouper.groups(
                    candidateAssetIDs: candidateGroup,
                    digestsByAssetID: digestsByAssetID
                )
            )
        }
        return exactGroups
    }

    private func digestSet(for asset: PHAsset) async throws -> PhotoResourceDigestSet? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let photoResource = primaryPhotoResource(from: resources) else { return nil }
        let photoDigest = try await PhotoAssetResourceDigester.digest(for: photoResource)

        if asset.mediaSubtypes.contains(.photoLive) {
            guard let pairedVideo = pairedVideoResource(from: resources) else { return nil }
            let videoDigest = try await PhotoAssetResourceDigester.digest(for: pairedVideo)
            return PhotoResourceDigestSet(
                kind: .livePhoto,
                photoDigest: photoDigest,
                pairedVideoDigest: videoDigest
            )
        }

        return PhotoResourceDigestSet(
            kind: .stillPhoto,
            photoDigest: photoDigest,
            pairedVideoDigest: nil
        )
    }

    private func primaryPhotoResource(from resources: [PHAssetResource]) -> PHAssetResource? {
        for type in [PHAssetResourceType.fullSizePhoto, .photo, .alternatePhoto] {
            if let resource = resources.first(where: { $0.type == type }) {
                return resource
            }
        }
        return nil
    }

    private func pairedVideoResource(from resources: [PHAssetResource]) -> PHAssetResource? {
        for type in [PHAssetResourceType.fullSizePairedVideo, .pairedVideo] {
            if let resource = resources.first(where: { $0.type == type }) {
                return resource
            }
        }
        return nil
    }
}

private enum PhotoAssetResourceDigester {
    static func digest(for resource: PHAssetResource) async throws -> Data {
        let manager = PHAssetResourceManager.default()
        let accumulator = PhotoResourceSHA256Accumulator()
        let request = PhotoRequestCancellation<PHAssetResourceDataRequestID> { requestID in
            manager.cancelDataRequest(requestID)
        }
        let options = PhotoAssetResourceRequestStrategy.localOnlyOptions()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let requestID = manager.requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: { data in
                        accumulator.update(data)
                    },
                    completionHandler: { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: accumulator.finalize())
                        }
                    }
                )
                request.store(requestID)
            }
        } onCancel: {
            request.cancel()
        }
    }
}

enum PhotoAssetResourceRequestStrategy {
    static func localOnlyOptions() -> PHAssetResourceRequestOptions {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        return options
    }
}

final class PhotoResourceSHA256Accumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var hasher = SHA256()

    func update(_ data: Data) {
        lock.lock()
        hasher.update(data: data)
        lock.unlock()
    }

    func finalize() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return Data(hasher.finalize())
    }
}

final class PhotoRequestCancellation<RequestID: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let cancelAction: @Sendable (RequestID) -> Void
    private var requestID: RequestID?
    private var isCancelled = false

    init(cancelAction: @escaping @Sendable (RequestID) -> Void) {
        self.cancelAction = cancelAction
    }

    func store(_ requestID: RequestID) {
        lock.lock()
        self.requestID = requestID
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel {
            cancelAction(requestID)
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let requestID = requestID
        lock.unlock()
        if let requestID {
            cancelAction(requestID)
        }
    }
}

enum PhotoScanProgress: Hashable, Sendable {
    case coarseAnalysis(completed: Int, total: Int)
    case candidateRefinement(completed: Int, total: Int)
    case finalizing
}

typealias PhotoScanProgressHandler = @Sendable (PhotoScanProgress) async -> Void

protocol PhotoLibraryScanning: Sendable {
    func scan(
        access: PhotoLibraryAccess,
        dateRange: PhotoScanDateRange,
        onProgress: @escaping PhotoScanProgressHandler
    ) async -> CleanupFlowState
}

extension PhotoLibraryScanning {
    func scan(access: PhotoLibraryAccess, dateRange: PhotoScanDateRange) async -> CleanupFlowState {
        await scan(access: access, dateRange: dateRange, onProgress: { _ in })
    }
}

struct SystemPhotoLibraryScanner: PhotoLibraryScanning {
    private let policy: PhotoLibraryScanPolicy
    private let analysisPolicy: PhotoVisualAnalysisPolicy
    private let qualityScorer: any PhotoQualityScoring
    private let now: @Sendable () -> Date

    init(
        policy: PhotoLibraryScanPolicy = .init(),
        analysisPolicy: PhotoVisualAnalysisPolicy = .init(),
        qualityScorer: (any PhotoQualityScoring)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.policy = policy
        self.analysisPolicy = analysisPolicy
        self.qualityScorer = qualityScorer ?? VisionPhotoQualityScorer()
        self.now = now
    }

    func scan(
        access: PhotoLibraryAccess,
        dateRange: PhotoScanDateRange,
        onProgress: @escaping PhotoScanProgressHandler
    ) async -> CleanupFlowState {
        guard access.canScan else {
            return PhotoScanResultBuilder.state(from: [])
        }

        let referenceDate = now()
        do {
            return PhotoScanResultBuilder.state(
                from: try await fetchAssetSnapshots(
                    dateRange: dateRange,
                    referenceDate: referenceDate,
                    onProgress: onProgress
                )
            )
        } catch is CancellationError {
            return PhotoScanResultBuilder.state(from: [])
        } catch {
            return PhotoScanResultBuilder.state(from: [])
        }
    }

    private func fetchAssetSnapshots(
        dateRange: PhotoScanDateRange,
        referenceDate: Date,
        onProgress: @escaping PhotoScanProgressHandler
    ) async throws -> [PhotoAssetSnapshot] {
        let options = fetchOptions(dateRange: dateRange, referenceDate: referenceDate)
        let photoAssets = PHAsset.fetchAssets(with: .image, options: options)
        let visualClassifications = try await fetchVisualClassifications(
            from: photoAssets,
            onProgress: onProgress
        )
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

        let videoAssets = PHAsset.fetchAssets(with: .video, options: options)
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

        await onProgress(.finalizing)
        return photoSnapshots + videoSnapshots
    }

    private func fetchVisualClassifications(
        from photoAssets: PHFetchResult<PHAsset>,
        onProgress: @escaping PhotoScanProgressHandler
    ) async throws -> [String: PhotoVisualClassification] {
        guard policy.effectiveVisualClassificationLimit > 0 else { return [:] }

        let imageManager = PHCachingImageManager()
        let maxCount = min(photoAssets.count, policy.effectiveVisualClassificationLimit)
        var coarseInputs: [PhotoVisualInput] = []
        coarseInputs.reserveCapacity(maxCount)
        var assetsByID: [String: PHAsset] = [:]
        await onProgress(.coarseAnalysis(completed: 0, total: maxCount))

        for index in 0..<maxCount {
            try Task.checkCancellation()

            let asset = photoAssets.object(at: index)
            assetsByID[asset.localIdentifier] = asset
            if !asset.mediaSubtypes.contains(.photoScreenshot),
               let metrics = Self.visualMetrics(
                    for: asset,
                    imageManager: imageManager,
                    qualityScorer: qualityScorer,
                    stage: .coarse,
                    policy: analysisPolicy
               ) {
                coarseInputs.append(
                    PhotoVisualInput(
                        assetID: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        metrics: metrics
                    )
                )
            }

            await onProgress(.coarseAnalysis(completed: index + 1, total: maxCount))

            if index.isMultiple(of: 25) {
                await Task.yield()
            }
        }

        let refinementIDs = PhotoVisualClassifier.refinementAssetIDs(
            from: coarseInputs,
            policy: analysisPolicy
        )
        let orderedRefinementIDs = coarseInputs
            .map(\.assetID)
            .filter { refinementIDs.contains($0) }
        var refinedInputsByID: [String: PhotoVisualInput] = [:]
        refinedInputsByID.reserveCapacity(orderedRefinementIDs.count)
        await onProgress(
            .candidateRefinement(completed: 0, total: orderedRefinementIDs.count)
        )

        for (index, assetID) in orderedRefinementIDs.enumerated() {
            try Task.checkCancellation()
            if let asset = assetsByID[assetID],
               let metrics = Self.visualMetrics(
                    for: asset,
                    imageManager: imageManager,
                    qualityScorer: qualityScorer,
                    stage: .refined,
                    policy: analysisPolicy
               ) {
                refinedInputsByID[assetID] = PhotoVisualInput(
                    assetID: assetID,
                    creationDate: asset.creationDate,
                    metrics: metrics
                )
            }
            await onProgress(
                .candidateRefinement(
                    completed: index + 1,
                    total: orderedRefinementIDs.count
                )
            )
            if index.isMultiple(of: 10) {
                await Task.yield()
            }
        }

        let coarseByID = Dictionary(uniqueKeysWithValues: coarseInputs.map { ($0.assetID, $0) })
        let resolvedInputs = orderedRefinementIDs.compactMap { id in
            refinedInputsByID[id] ?? coarseByID[id]
        }
        let provisionalClassifications = PhotoVisualClassifier.classifications(
            from: resolvedInputs,
            policy: analysisPolicy
        )
        let refinedInputs = orderedRefinementIDs.compactMap { refinedInputsByID[$0] }
        let exactCandidates = PhotoVisualClassifier.exactDuplicateCandidateGroups(
            from: refinedInputs,
            classifications: provisionalClassifications,
            policy: analysisPolicy
        )
        let exactGroups = try await SystemPhotoDuplicateVerifier().exactDuplicateGroups(
            candidateGroups: exactCandidates,
            assetsByID: assetsByID
        )

        return PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarseInputs,
            refinedInputsByID: refinedInputsByID,
            exactDuplicateGroups: exactGroups,
            policy: analysisPolicy
        )
    }

    private static func visualMetrics(
        for asset: PHAsset,
        imageManager: PHImageManager,
        qualityScorer: any PhotoQualityScoring,
        stage: PhotoVisualAnalysisStage,
        policy: PhotoVisualAnalysisPolicy
    ) -> PhotoVisualMetrics? {
        guard let cgImage = PhotoImageRequestStrategy.firstAvailable(request: {
            (deliveryMode: PHImageRequestOptionsDeliveryMode) -> CGImage? in
            guard let image = requestImage(
                for: asset,
                imageManager: imageManager,
                deliveryMode: deliveryMode,
                stage: stage,
                policy: policy
            ) else { return nil }
            return PhotoImageOrientationNormalizer.normalizedCGImage(from: image)
        }) else {
            return nil
        }

        return PhotoVisualAnalyzer.metrics(
            from: cgImage,
            qualityScorer: qualityScorer,
            stage: stage,
            policy: policy
        )
    }

    private static func requestImage(
        for asset: PHAsset,
        imageManager: PHImageManager,
        deliveryMode: PHImageRequestOptionsDeliveryMode,
        stage: PhotoVisualAnalysisStage,
        policy: PhotoVisualAnalysisPolicy
    ) -> UIImage? {
        let options = PhotoImageRequestStrategy.requestOptions(deliveryMode: deliveryMode)

        var requestedImage: UIImage?
        imageManager.requestImage(
            for: asset,
            targetSize: policy.targetSize(for: stage),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let hasError = info?[PHImageErrorKey] != nil
            guard !isCancelled, !hasError else { return }
            requestedImage = image
        }

        return requestedImage
    }

    private func fetchOptions(
        dateRange: PhotoScanDateRange,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        if let bounds = dateRange.dateBounds(endingAt: referenceDate, calendar: calendar) {
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                bounds.lowerBound as NSDate,
                bounds.upperBound as NSDate
            )
        }
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        return options
    }
}

enum PhotoVisualClassifier {
    static func classifications(
        from inputs: [PhotoVisualInput],
        policy: PhotoVisualAnalysisPolicy = .init()
    ) -> [String: PhotoVisualClassification] {
        guard !inputs.isEmpty else { return [:] }

        var classifications: [String: PhotoVisualClassification] = [:]
        var groupedAssetIDs = Set<String>()
        let sortedInputs = inputs.sorted { lhs, rhs in
            (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
        }

        for input in sortedInputs where !groupedAssetIDs.contains(input.assetID) {
            let cluster = sortedInputs.filter { candidate in
                guard !groupedAssetIDs.contains(candidate.assetID) else { return false }
                return isSimilar(input, candidate, policy: policy)
            }

            guard cluster.count >= 2 else { continue }

            let keepAssetID = cluster.max { lhs, rhs in
                lhs.metrics.quality.recommendedKeepScore < rhs.metrics.quality.recommendedKeepScore
            }?.assetID
            let groupID = stableGroupID(for: cluster.map(\.assetID), prefix: "similar")

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
            classification.isAccidental = isAccidental(input.metrics, policy: policy)
            classification.isBlurry = !classification.isAccidental && isBlurry(input.metrics, policy: policy)

            if classification.hasFindings {
                classifications[input.assetID] = classification
            }
        }

        return classifications
    }

    static func refinementAssetIDs(
        from inputs: [PhotoVisualInput],
        policy: PhotoVisualAnalysisPolicy = .init()
    ) -> Set<String> {
        let preliminary = classifications(from: inputs, policy: policy)
        var ids = Set(preliminary.keys)

        for input in inputs {
            let boundaryRisk = max(
                input.metrics.quality.blurRisk,
                input.metrics.quality.accidentalRisk
            )
            if boundaryRisk >= policy.coarseBoundaryRiskThreshold {
                ids.insert(input.assetID)
            }
        }
        return ids
    }

    static func finalClassifications(
        coarseInputs: [PhotoVisualInput],
        refinedInputsByID: [String: PhotoVisualInput],
        exactDuplicateGroups: [[String]],
        policy: PhotoVisualAnalysisPolicy = .init()
    ) -> [String: PhotoVisualClassification] {
        let refinementIDs = refinementAssetIDs(from: coarseInputs, policy: policy)
        let coarseByID = Dictionary(uniqueKeysWithValues: coarseInputs.map { ($0.assetID, $0) })
        let validExactDuplicateGroups = exactDuplicateGroups
            .map { group in
                group.filter { refinedInputsByID[$0] != nil }
            }
            .filter { $0.count >= 2 }
        let exactIDs = Set(validExactDuplicateGroups.flatMap { $0 })
        let resolvedInputs = refinementIDs.compactMap { id in
            refinedInputsByID[id] ?? coarseByID[id]
        }
        var classifications = Self.classifications(
            from: resolvedInputs.filter { !exactIDs.contains($0.assetID) },
            policy: policy
        )

        let coarseClassifications = Self.classifications(from: coarseInputs, policy: policy)
        for id in refinementIDs where refinedInputsByID[id] == nil && !exactIDs.contains(id) {
            guard var fallback = coarseClassifications[id] else { continue }
            fallback.wasRefined = false
            classifications[id] = fallback
        }

        let resolvedByID = Dictionary(uniqueKeysWithValues: resolvedInputs.map { ($0.assetID, $0) })
        for group in validExactDuplicateGroups {
            let members = group.compactMap { resolvedByID[$0] }
            guard members.count >= 2 else { continue }
            let keepAssetID = members.max { lhs, rhs in
                lhs.metrics.quality.recommendedKeepScore < rhs.metrics.quality.recommendedKeepScore
            }?.assetID
            let groupID = stableGroupID(for: members.map(\.assetID), prefix: "exact")

            for member in members {
                classifications[member.assetID] = PhotoVisualClassification(
                    similarGroupID: groupID,
                    recommendedKeep: member.assetID == keepAssetID,
                    isExactDuplicate: true,
                    wasRefined: refinedInputsByID[member.assetID] != nil
                )
            }
        }
        return classifications
    }

    static func exactDuplicateCandidateGroups(
        from inputs: [PhotoVisualInput],
        classifications: [String: PhotoVisualClassification],
        policy: PhotoVisualAnalysisPolicy = .init()
    ) -> [[String]] {
        let inputsByGroup = Dictionary(grouping: inputs) { input in
            classifications[input.assetID]?.similarGroupID
        }
        var result: [[String]] = []

        for (groupID, groupInputs) in inputsByGroup {
            guard groupID != nil, groupInputs.count >= 2 else { continue }
            var remaining = groupInputs.sorted { $0.assetID < $1.assetID }

            while let anchor = remaining.first {
                remaining.removeFirst()
                let matches = remaining.filter {
                    isPotentialExactDuplicate(anchor, $0, policy: policy)
                }
                let matchIDs = Set(matches.map(\.assetID))
                remaining.removeAll { matchIDs.contains($0.assetID) }
                let cluster = [anchor.assetID] + matches.map(\.assetID)
                if cluster.count >= 2 {
                    result.append(cluster.sorted())
                }
            }
        }
        return result.sorted { $0.lexicographicallyPrecedes($1) }
    }

    private static func isSimilar(
        _ lhs: PhotoVisualInput,
        _ rhs: PhotoVisualInput,
        policy: PhotoVisualAnalysisPolicy
    ) -> Bool {
        if lhs.assetID == rhs.assetID {
            return true
        }

        guard let lhsDate = lhs.creationDate,
              let rhsDate = rhs.creationDate,
              abs(lhsDate.timeIntervalSince(rhsDate)) <= policy.similarTimeWindow
        else {
            return false
        }

        if let lhsFeaturePrint = lhs.metrics.featurePrint,
           let rhsFeaturePrint = rhs.metrics.featurePrint,
           let distance = lhsFeaturePrint.distance(to: rhsFeaturePrint) {
            return distance <= policy.similarFeaturePrintDistance
        }

        guard aspectRatiosAreComparable(lhs.metrics.aspectRatio, rhs.metrics.aspectRatio, policy: policy) else {
            return false
        }
        return hammingDistance(lhs.metrics.perceptualHash, rhs.metrics.perceptualHash)
            <= policy.similarHashDistance
    }

    private static func isPotentialExactDuplicate(
        _ lhs: PhotoVisualInput,
        _ rhs: PhotoVisualInput,
        policy: PhotoVisualAnalysisPolicy
    ) -> Bool {
        if let lhsFeaturePrint = lhs.metrics.featurePrint,
           let rhsFeaturePrint = rhs.metrics.featurePrint,
           let distance = lhsFeaturePrint.distance(to: rhsFeaturePrint) {
            return distance <= policy.exactFeaturePrintDistance
        }

        return aspectRatiosAreComparable(lhs.metrics.aspectRatio, rhs.metrics.aspectRatio, policy: policy)
            && hammingDistance(lhs.metrics.perceptualHash, rhs.metrics.perceptualHash) == 0
    }

    private static func aspectRatiosAreComparable(
        _ lhs: Double,
        _ rhs: Double,
        policy: PhotoVisualAnalysisPolicy
    ) -> Bool {
        abs(log(max(0.01, lhs) / max(0.01, rhs))) <= policy.aspectRatioLogTolerance
    }

    private static func isBlurry(
        _ metrics: PhotoVisualMetrics,
        policy: PhotoVisualAnalysisPolicy
    ) -> Bool {
        metrics.quality.blurRisk >= policy.blurryRiskThreshold
    }

    private static func isAccidental(
        _ metrics: PhotoVisualMetrics,
        policy: PhotoVisualAnalysisPolicy
    ) -> Bool {
        metrics.quality.accidentalRisk >= policy.accidentalRiskThreshold
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    private static func stableGroupID(for assetIDs: [String], prefix: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in assetIDs.sorted().joined(separator: "|").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(prefix)-\(String(hash, radix: 16))"
    }
}

enum PhotoVisualAnalyzer {
    private static let bytesPerPixel = 4

    static func metrics(
        from cgImage: CGImage,
        qualityScorer: any PhotoQualityScoring = HeuristicPhotoQualityScorer(),
        stage: PhotoVisualAnalysisStage = .coarse,
        policy: PhotoVisualAnalysisPolicy = .init()
    ) -> PhotoVisualMetrics? {
        guard let raster = PhotoAspectPreservingRasterizer.raster(
            from: cgImage,
            maxLongSide: policy.rasterLongSide(for: stage)
        ) else { return nil }

        var luminance = [Double]()
        luminance.reserveCapacity(raster.width * raster.height)
        var brightnessSum = 0.0
        var saturationSum = 0.0

        for pixelIndex in stride(from: 0, to: raster.pixels.count, by: bytesPerPixel) {
            let red = Double(raster.pixels[pixelIndex]) / 255.0
            let green = Double(raster.pixels[pixelIndex + 1]) / 255.0
            let blue = Double(raster.pixels[pixelIndex + 2]) / 255.0
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
        let perceptualHash = perceptualHash(
            from: luminance,
            width: raster.width,
            height: raster.height
        )
        let brightness = brightnessSum / pixelCount
        let saturation = saturationSum / pixelCount
        let sharpness = edgeSharpness(
            from: luminance,
            width: raster.width,
            height: raster.height
        )
        let qualityFeatures = PhotoQualityFeatures(
            brightness: brightness,
            saturation: saturation,
            sharpness: sharpness,
            hashBitDensity: Double(perceptualHash.nonzeroBitCount) / 64.0
        )
        let heuristic = PhotoQualityAssessment.heuristic(
            from: qualityFeatures,
            thresholds: policy.qualityThresholds(for: stage)
        )
        let quality = adjustedQuality(
            qualityScorer.assessment(for: cgImage, features: qualityFeatures),
            heuristic: heuristic
        )

        return PhotoVisualMetrics(
            perceptualHash: perceptualHash,
            featurePrint: PhotoFeaturePrintGenerator.featurePrint(from: cgImage),
            brightness: brightness,
            saturation: saturation,
            sharpness: sharpness,
            aspectRatio: Double(cgImage.width) / Double(max(1, cgImage.height)),
            quality: quality
        )
    }

    private static func adjustedQuality(
        _ assessment: PhotoQualityAssessment?,
        heuristic: PhotoQualityAssessment
    ) -> PhotoQualityAssessment {
        guard let assessment else { return heuristic }

        switch assessment.source {
        case .heuristic:
            return heuristic
        case .visionAesthetics:
            return PhotoQualityAssessment(
                overallQuality: assessment.overallQuality,
                blurRisk: heuristic.blurRisk,
                accidentalRisk: max(heuristic.accidentalRisk, assessment.accidentalRisk),
                faceCaptureQuality: assessment.faceCaptureQuality,
                isUtility: assessment.isUtility,
                source: assessment.source
            )
        case .customCoreML:
            return assessment
        }
    }

    private static func edgeSharpness(
        from luminance: [Double],
        width: Int,
        height: Int
    ) -> Double {
        guard width > 0, height > 0, luminance.count == width * height else { return 0 }

        var edgeSum = 0.0
        var comparisons = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x

                if x > 0 {
                    edgeSum += abs(luminance[index] - luminance[index - 1])
                    comparisons += 1
                }

                if y > 0 {
                    edgeSum += abs(luminance[index] - luminance[index - width])
                    comparisons += 1
                }
            }
        }

        guard comparisons > 0 else { return 0 }
        let referenceScale = Double(max(1, min(width, height))) / 32.0
        return (edgeSum / Double(comparisons)) * referenceScale
    }

    private static func perceptualHash(
        from luminance: [Double],
        width: Int,
        height: Int
    ) -> UInt64 {
        guard width > 0, height > 0, luminance.count == width * height else { return 0 }

        var hash: UInt64 = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let left = sampledLuminance(
                    luminance,
                    sampleX: x,
                    sampleY: y,
                    width: width,
                    height: height
                )
                let right = sampledLuminance(
                    luminance,
                    sampleX: x + 1,
                    sampleY: y,
                    width: width,
                    height: height
                )
                if left > right {
                    hash |= UInt64(1) << UInt64(y * 8 + x)
                }
            }
        }

        return hash
    }

    private static func sampledLuminance(
        _ luminance: [Double],
        sampleX: Int,
        sampleY: Int,
        width: Int,
        height: Int
    ) -> Double {
        let sourceX = min(width - 1, Int((Double(sampleX) / 8.0) * Double(width - 1)))
        let sourceY = min(height - 1, Int((Double(sampleY) / 7.0) * Double(height - 1)))
        return luminance[sourceY * width + sourceX]
    }
}

struct PhotoAnalysisRaster: Sendable {
    var width: Int
    var height: Int
    var pixels: [UInt8]
}

enum PhotoAspectPreservingRasterizer {
    static func dimensions(
        sourceWidth: Int,
        sourceHeight: Int,
        maxLongSide: Int
    ) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0, maxLongSide > 0 else {
            return (0, 0)
        }

        let scale = min(
            Double(maxLongSide) / Double(sourceWidth),
            Double(maxLongSide) / Double(sourceHeight)
        )
        return (
            max(1, Int((Double(sourceWidth) * scale).rounded())),
            max(1, Int((Double(sourceHeight) * scale).rounded()))
        )
    }

    static func raster(from cgImage: CGImage, maxLongSide: Int) -> PhotoAnalysisRaster? {
        let size = dimensions(
            sourceWidth: cgImage.width,
            sourceHeight: cgImage.height,
            maxLongSide: maxLongSide
        )
        guard size.width > 0, size.height > 0 else { return nil }

        let bytesPerRow = size.width * 4
        var pixels = [UInt8](repeating: 0, count: size.height * bytesPerRow)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            context.interpolationQuality = .medium
            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: size.width, height: size.height)
            )
            return true
        }

        guard rendered else { return nil }
        return PhotoAnalysisRaster(width: size.width, height: size.height, pixels: pixels)
    }
}

enum PhotoImageOrientationNormalizer {
    static func normalizedCGImage(from image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let pixelSize = CGSize(
            width: max(1, (image.size.width * image.scale).rounded()),
            height: max(1, (image.size.height * image.scale).rounded())
        )
        return UIGraphicsImageRenderer(size: pixelSize, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: pixelSize)) }
            .cgImage
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
    static func state(
        from snapshots: [PhotoAssetSnapshot],
        confirmedKeepAssetIDs: Set<String> = []
    ) -> CleanupFlowState {
        let screenshotCandidates = candidates(
            from: snapshots.filter { $0.isScreenshot && !confirmedKeepAssetIDs.contains($0.id) },
            category: .screenshots,
            confirmedKeepAssetIDs: confirmedKeepAssetIDs
        )
        let largeVideoCandidates = candidates(
            from: snapshots.filter { snapshot in
                snapshot.kind == .video
                    && isLargeVideo(snapshot)
                    && !confirmedKeepAssetIDs.contains(snapshot.id)
            },
            category: .largeVideos,
            confirmedKeepAssetIDs: confirmedKeepAssetIDs
        )
        let visuallyClassifiedPhotos = snapshots.filter { snapshot in
            snapshot.kind == .photo && !snapshot.isScreenshot && snapshot.visualClassification?.hasFindings == true
        }
        let similarGroups = similarReviewGroups(
            from: visuallyClassifiedPhotos,
            confirmedKeepAssetIDs: confirmedKeepAssetIDs
        )
        let similarAssetIDs = Set(similarGroups.flatMap { group in
            group.candidates.map(\.id)
        })
        let accidentalCandidates = candidates(
            from: visuallyClassifiedPhotos.filter { snapshot in
                !similarAssetIDs.contains(snapshot.id)
                    && !confirmedKeepAssetIDs.contains(snapshot.id)
                    && snapshot.visualClassification?.isAccidental == true
            },
            category: .accidental,
            confirmedKeepAssetIDs: confirmedKeepAssetIDs
        )
        let blurryCandidates = candidates(
            from: visuallyClassifiedPhotos.filter { snapshot in
                !similarAssetIDs.contains(snapshot.id)
                    && !confirmedKeepAssetIDs.contains(snapshot.id)
                    && snapshot.visualClassification?.isBlurry == true
            },
            category: .blurry,
            confirmedKeepAssetIDs: confirmedKeepAssetIDs
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

        let tasks = CleanupTaskBuilder.tasks(from: groups)

        return CleanupFlowState(
            tasks: tasks,
            reviewGroups: groups,
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: Set(groups.first?.candidates.filter(\.defaultSelectedForDeletion).map(\.id) ?? []),
            reviewBinItems: [],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )
    }

    private static func candidates(
        from snapshots: [PhotoAssetSnapshot],
        category: CleanupCategory,
        confirmedKeepAssetIDs: Set<String>
    ) -> [CleanupCandidate] {
        snapshots.enumerated().map { index, snapshot in
            let recommendedKeep = category == .similar && snapshot.visualClassification?.recommendedKeep == true
            let wasRefined = snapshot.visualClassification?.wasRefined ?? true
            let isExactDuplicate = snapshot.visualClassification?.isExactDuplicate == true
            return CleanupCandidate(
                id: snapshot.id,
                category: category,
                confidence: confidence(for: category, snapshot: snapshot),
                defaultSelectedForDeletion: defaultSelectedForDeletion(
                    category: category,
                    recommendedKeep: recommendedKeep,
                    wasRefined: wasRefined
                ),
                recommendedKeep: recommendedKeep,
                confirmedKeep: confirmedKeepAssetIDs.contains(snapshot.id),
                reason: reason(for: category, snapshot: snapshot),
                estimatedBytes: estimatedBytes(for: snapshot, category: category),
                thumbnail: thumbnail(for: category, index: index),
                thumbnailAssetID: snapshot.id,
                isExactDuplicate: isExactDuplicate
            )
        }
    }

    private static func similarReviewGroups(
        from snapshots: [PhotoAssetSnapshot],
        confirmedKeepAssetIDs: Set<String>
    ) -> [CleanupGroup] {
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
            let candidates = candidates(
                from: group.1,
                category: .similar,
                confirmedKeepAssetIDs: confirmedKeepAssetIDs
            )
            let isExactDuplicate = candidates.allSatisfy(\.isExactDuplicate)
            return CleanupGroup(
                id: group.0,
                category: .similar,
                title: isExactDuplicate ? "精确重复照片" : "相似照片",
                subtitle: "第 \(index + 1) 组 / \(groups.count) 组",
                groupIndex: index + 1,
                totalGroups: groups.count,
                explanation: isExactDuplicate
                    ? "这些照片的本地底层资源内容完全一致。留真会推荐保留一张，其他项目仍需你确认后才能加入复核箱。"
                    : "这些照片来自短时间内的相似画面。留真会综合清晰度和可用的人脸质量推荐保留一张，其余项目需要你确认后才能加入复核箱。",
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

    private static func defaultSelectedForDeletion(
        category: CleanupCategory,
        recommendedKeep: Bool,
        wasRefined: Bool
    ) -> Bool {
        guard !recommendedKeep, wasRefined else { return false }

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

    private static func confidence(
        for category: CleanupCategory,
        snapshot: PhotoAssetSnapshot
    ) -> CandidateConfidence {
        if snapshot.visualClassification?.isExactDuplicate == true {
            return .high
        }
        if snapshot.visualClassification?.wasRefined == false {
            return .low
        }
        switch category {
        case .screenshots:
            return .high
        case .largeVideos, .similar:
            return .medium
        case .accidental, .blurry:
            return .low
        }
    }

    private static func reason(
        for category: CleanupCategory,
        snapshot: PhotoAssetSnapshot
    ) -> String {
        if snapshot.visualClassification?.isExactDuplicate == true {
            return "本机底层资源摘要一致，确认为内容完全相同的照片。"
        }
        if snapshot.visualClassification?.wasRefined == false {
            return "本机未能读取复核图片，仅保留粗筛结果供你谨慎检查。"
        }
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
