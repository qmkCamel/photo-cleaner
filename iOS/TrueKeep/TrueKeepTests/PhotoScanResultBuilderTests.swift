import XCTest
import CoreML
import CoreGraphics
import Photos
@testable import TrueKeep

final class PhotoScanResultBuilderTests: XCTestCase {
    func testPhotoImageRequestOptionsStayLocalForBothDeliveryModes() {
        for deliveryMode in PhotoImageRequestStrategy.deliveryModes {
            let options = PhotoImageRequestStrategy.requestOptions(deliveryMode: deliveryMode)

            XCTAssertEqual(options.deliveryMode, deliveryMode)
            XCTAssertEqual(options.resizeMode, .fast)
            XCTAssertFalse(options.isNetworkAccessAllowed)
            XCTAssertTrue(options.isSynchronous)
        }
    }

    func testPhotoImageRequestStrategyStopsAfterFastImageIsAvailable() {
        var requestedModes: [PHImageRequestOptionsDeliveryMode] = []

        let image = PhotoImageRequestStrategy.firstAvailable { deliveryMode in
            requestedModes.append(deliveryMode)
            return deliveryMode == .fastFormat ? "fast-image" : "high-quality-image"
        }

        XCTAssertEqual(image, "fast-image")
        XCTAssertEqual(requestedModes, [.fastFormat])
    }

    func testPhotoImageRequestStrategyFallsBackToHighQualityImage() {
        var requestedModes: [PHImageRequestOptionsDeliveryMode] = []

        let image = PhotoImageRequestStrategy.firstAvailable { deliveryMode in
            requestedModes.append(deliveryMode)
            return deliveryMode == .highQualityFormat ? "high-quality-image" : nil
        }

        XCTAssertEqual(image, "high-quality-image")
        XCTAssertEqual(requestedModes, [.fastFormat, .highQualityFormat])
    }

    func testPhotoImageRequestStrategyReturnsNilAfterBothLocalRequestsFail() {
        var requestedModes: [PHImageRequestOptionsDeliveryMode] = []

        let image: String? = PhotoImageRequestStrategy.firstAvailable { deliveryMode in
            requestedModes.append(deliveryMode)
            return nil
        }

        XCTAssertNil(image)
        XCTAssertEqual(requestedModes, [.fastFormat, .highQualityFormat])
    }

    func testBuildsScreenshotAndLargeVideoTasksFromAssetSnapshots() {
        let state = PhotoScanResultBuilder.state(
            from: [
                PhotoAssetSnapshot(
                    id: "screen-1",
                    kind: .photo,
                    isScreenshot: true,
                    duration: 0,
                    estimatedBytes: 1_200_000
                ),
                PhotoAssetSnapshot(
                    id: "video-1",
                    kind: .video,
                    isScreenshot: false,
                    duration: 360,
                    estimatedBytes: 540_000_000
                ),
                PhotoAssetSnapshot(
                    id: "photo-1",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 2_800_000
                )
            ]
        )

        XCTAssertEqual(state.tasks.map(\.category), [.screenshots, .largeVideos])
        XCTAssertEqual(state.tasks.map(\.candidateCount), [1, 1])
        XCTAssertEqual(state.totalEstimatedBytes, 541_200_000)
        XCTAssertEqual(state.reviewGroups.map(\.category), [.screenshots, .largeVideos])
    }

    func testRealScanCandidatesKeepPhotoAssetIdentifierForThumbnails() {
        let state = PhotoScanResultBuilder.state(
            from: [
                PhotoAssetSnapshot(
                    id: "screen-1",
                    kind: .photo,
                    isScreenshot: true,
                    duration: 0,
                    estimatedBytes: 1_200_000
                )
            ]
        )

        let candidate = state.reviewGroups[0].candidates[0]

        XCTAssertEqual(candidate.id, "screen-1")
        XCTAssertEqual(candidate.thumbnailAssetID, "screen-1")
    }

    func testFixtureCandidatesDoNotClaimPhotoAssetThumbnails() {
        let state = CleanupFlowState.sample()

        XCTAssertTrue(state.currentReviewGroup.candidates.allSatisfy { $0.thumbnailAssetID == nil })
    }

    func testUnclassifiedSnapshotsDoNotCreateVisualReviewTasks() {
        let state = PhotoScanResultBuilder.state(
            from: [
                PhotoAssetSnapshot(
                    id: "photo-1",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 3_000_000
                ),
                PhotoAssetSnapshot(
                    id: "short-video-1",
                    kind: .video,
                    isScreenshot: false,
                    duration: 45,
                    estimatedBytes: 80_000_000
                )
            ]
        )

        XCTAssertTrue(state.tasks.isEmpty)
        XCTAssertTrue(state.reviewGroups.isEmpty)
        XCTAssertEqual(state.currentReviewSelectionCount, 0)
    }

    func testBuildsVisualClassifierTasksFromClassifiedPhotoSnapshots() {
        let state = PhotoScanResultBuilder.state(
            from: [
                PhotoAssetSnapshot(
                    id: "similar-keep",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 2_800_000,
                    visualClassification: PhotoVisualClassification(
                        similarGroupID: "burst-1",
                        recommendedKeep: true
                    )
                ),
                PhotoAssetSnapshot(
                    id: "similar-delete",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 2_600_000,
                    visualClassification: PhotoVisualClassification(
                        similarGroupID: "burst-1",
                        recommendedKeep: false
                    )
                ),
                PhotoAssetSnapshot(
                    id: "pocket-shot",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 1_900_000,
                    visualClassification: PhotoVisualClassification(isAccidental: true)
                ),
                PhotoAssetSnapshot(
                    id: "soft-focus",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    estimatedBytes: 2_100_000,
                    visualClassification: PhotoVisualClassification(isBlurry: true)
                )
            ]
        )

        XCTAssertEqual(state.tasks.map(\.category), [.similar, .accidental, .blurry])
        XCTAssertEqual(state.tasks.map(\.candidateCount), [2, 1, 1])
        XCTAssertEqual(state.reviewGroups.map(\.category), [.similar, .accidental, .blurry])
    }

    func testSimilarVisualGroupKeepsBestCandidateOutOfDefaultDeletionSelection() {
        let state = PhotoScanResultBuilder.state(
            from: [
                PhotoAssetSnapshot(
                    id: "keeper",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    visualClassification: PhotoVisualClassification(
                        similarGroupID: "burst-1",
                        recommendedKeep: true
                    )
                ),
                PhotoAssetSnapshot(
                    id: "candidate",
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    visualClassification: PhotoVisualClassification(
                        similarGroupID: "burst-1",
                        recommendedKeep: false
                    )
                )
            ]
        )

        let similarCandidates = state.reviewGroups[0].candidates

        XCTAssertEqual(similarCandidates.map(\.id), ["keeper", "candidate"])
        XCTAssertTrue(similarCandidates[0].recommendedKeep)
        XCTAssertFalse(similarCandidates[0].defaultSelectedForDeletion)
        XCTAssertEqual(state.selectedCandidateIDs, ["candidate"])
    }

    func testVisualClassifierGroupsNearHashesAndKeepsSharpestInput() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "soft",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.02
                    )
                ),
                PhotoVisualInput(
                    assetID: "sharp",
                    creationDate: now.addingTimeInterval(30),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.09
                    )
                )
            ]
        )

        XCTAssertEqual(classifications["soft"]?.similarGroupID, classifications["sharp"]?.similarGroupID)
        XCTAssertFalse(classifications["soft"]?.recommendedKeep ?? true)
        XCTAssertTrue(classifications["sharp"]?.recommendedKeep ?? false)
    }

    func testVisualClassifierPrefersFeaturePrintSimilarityOverPerceptualHash() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "first",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0,
                        featurePrint: featurePrint([0.10, 0.20, 0.30, 0.40]),
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.04
                    )
                ),
                PhotoVisualInput(
                    assetID: "second",
                    creationDate: now.addingTimeInterval(20),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: UInt64.max,
                        featurePrint: featurePrint([0.11, 0.19, 0.29, 0.41]),
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.06
                    )
                )
            ]
        )

        XCTAssertEqual(classifications["first"]?.similarGroupID, classifications["second"]?.similarGroupID)
    }

    func testVisualClassifierFallsBackToPerceptualHashWhenFeaturePrintIsMissing() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "first",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.04
                    )
                ),
                PhotoVisualInput(
                    assetID: "second",
                    creationDate: now.addingTimeInterval(20),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.06
                    )
                )
            ]
        )

        XCTAssertEqual(classifications["first"]?.similarGroupID, classifications["second"]?.similarGroupID)
    }

    func testVisualClassifierDoesNotUseHashFallbackWhenFeaturePrintsAreComparableAndDistant() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "first",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        featurePrint: featurePrint([0.0, 0.0, 0.0, 0.0]),
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.04
                    )
                ),
                PhotoVisualInput(
                    assetID: "second",
                    creationDate: now.addingTimeInterval(20),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        featurePrint: featurePrint([1.0, 1.0, 1.0, 1.0]),
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.06
                    )
                )
            ]
        )

        XCTAssertNil(classifications["first"]?.similarGroupID)
        XCTAssertNil(classifications["second"]?.similarGroupID)
    }

    func testVisualClassifierUsesQualityScoreForRecommendedKeep() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "model-keeper",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.02,
                        quality: PhotoQualityAssessment(
                            overallQuality: 0.92,
                            blurRisk: 0.05,
                            accidentalRisk: 0.02
                        )
                    )
                ),
                PhotoVisualInput(
                    assetID: "sharp-but-worse-quality",
                    creationDate: now.addingTimeInterval(20),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.10,
                        quality: PhotoQualityAssessment(
                            overallQuality: 0.48,
                            blurRisk: 0.10,
                            accidentalRisk: 0.02
                        )
                    )
                )
            ]
        )

        XCTAssertTrue(classifications["model-keeper"]?.recommendedKeep ?? false)
        XCTAssertFalse(classifications["sharp-but-worse-quality"]?.recommendedKeep ?? true)
    }

    func testVisualClassifierUsesFaceCaptureQualityAsRecommendedKeepSupport() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "lower-face-quality",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.05,
                        quality: PhotoQualityAssessment(
                            overallQuality: 0.8,
                            blurRisk: 0.05,
                            accidentalRisk: 0.02,
                            faceCaptureQuality: 0.2,
                            source: .visionAesthetics
                        )
                    )
                ),
                PhotoVisualInput(
                    assetID: "higher-face-quality",
                    creationDate: now.addingTimeInterval(20),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.05,
                        quality: PhotoQualityAssessment(
                            overallQuality: 0.8,
                            blurRisk: 0.05,
                            accidentalRisk: 0.02,
                            faceCaptureQuality: 0.9,
                            source: .visionAesthetics
                        )
                    )
                )
            ]
        )

        XCTAssertFalse(classifications["lower-face-quality"]?.recommendedKeep ?? true)
        XCTAssertTrue(classifications["higher-face-quality"]?.recommendedKeep ?? false)
    }

    func testVisualClassifierDoesNotGroupNearHashesOutsideTimeWindow() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "first",
                    creationDate: now,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1010,
                        brightness: 0.45,
                        saturation: 0.3,
                        sharpness: 0.02
                    )
                ),
                PhotoVisualInput(
                    assetID: "later",
                    creationDate: now.addingTimeInterval(600),
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0b1011,
                        brightness: 0.46,
                        saturation: 0.32,
                        sharpness: 0.09
                    )
                )
            ]
        )

        XCTAssertNil(classifications["first"]?.similarGroupID)
        XCTAssertNil(classifications["later"]?.similarGroupID)
    }

    func testVisualClassifierMarksAccidentalAndBlurrySingles() {
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "dark-pocket-shot",
                    creationDate: nil,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0,
                        brightness: 0.05,
                        saturation: 0.02,
                        sharpness: 0.02
                    )
                ),
                PhotoVisualInput(
                    assetID: "soft-focus",
                    creationDate: nil,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 1,
                        brightness: 0.44,
                        saturation: 0.2,
                        sharpness: 0.005
                    )
                )
            ]
        )

        XCTAssertTrue(classifications["dark-pocket-shot"]?.isAccidental ?? false)
        XCTAssertFalse(classifications["dark-pocket-shot"]?.isBlurry ?? true)
        XCTAssertTrue(classifications["soft-focus"]?.isBlurry ?? false)
    }

    func testVisualClassifierUsesQualityAssessmentForBlurrySingles() {
        let classifications = PhotoVisualClassifier.classifications(
            from: [
                PhotoVisualInput(
                    assetID: "model-blurry",
                    creationDate: nil,
                    metrics: PhotoVisualMetrics(
                        perceptualHash: 0,
                        brightness: 0.48,
                        saturation: 0.28,
                        sharpness: 0.08,
                        quality: PhotoQualityAssessment(
                            overallQuality: 0.22,
                            blurRisk: 0.96,
                            accidentalRisk: 0.02
                        )
                    )
                )
            ]
        )

        XCTAssertTrue(classifications["model-blurry"]?.isBlurry ?? false)
    }

    func testCoreMLQualityScorerParsesNamedModelOutputs() {
        let prediction = StubFeatureProvider(
            values: [
                "quality_score": MLFeatureValue(double: 0.74),
                "blur_risk": MLFeatureValue(double: 0.13),
                "accidental_risk": MLFeatureValue(double: 0.08)
            ]
        )

        let assessment = CoreMLPhotoQualityScorer.assessment(from: prediction)

        XCTAssertEqual(assessment?.overallQuality, 0.74)
        XCTAssertEqual(assessment?.blurRisk, 0.13)
        XCTAssertEqual(assessment?.accidentalRisk, 0.08)
    }

    func testVisionQualityScorerNormalizesAestheticsAndAveragesFaceQuality() {
        let assessment = VisionPhotoQualityScorer.assessment(
            overallScore: 0.6,
            isUtility: false,
            faceCaptureQualities: [0.6, 0.8],
            heuristic: PhotoQualityAssessment(
                overallQuality: 0.4,
                blurRisk: 0.2,
                accidentalRisk: 0.1
            )
        )

        XCTAssertEqual(assessment.overallQuality, 0.8, accuracy: 0.0001)
        XCTAssertEqual(assessment.faceCaptureQuality ?? 0, 0.7, accuracy: 0.0001)
        XCTAssertEqual(assessment.blurRisk, 0.2, accuracy: 0.0001)
        XCTAssertEqual(assessment.accidentalRisk, 0.1, accuracy: 0.0001)
        XCTAssertEqual(assessment.source, .visionAesthetics)
    }

    func testVisionQualityScorerUsesOnlyExtremelyLowNonUtilityScoreAsAccidentalRisk() {
        let assessment = VisionPhotoQualityScorer.assessment(
            overallScore: -0.9,
            isUtility: false,
            faceCaptureQualities: [],
            heuristic: PhotoQualityAssessment(
                overallQuality: 0.5,
                blurRisk: 0.1,
                accidentalRisk: 0.2
            )
        )

        XCTAssertEqual(assessment.accidentalRisk, 0.9, accuracy: 0.0001)
    }

    func testVisionQualityScorerDoesNotTreatUtilityAsAccidental() {
        let assessment = VisionPhotoQualityScorer.assessment(
            overallScore: -0.95,
            isUtility: true,
            faceCaptureQualities: [],
            heuristic: PhotoQualityAssessment(
                overallQuality: 0.5,
                blurRisk: 0.1,
                accidentalRisk: 0.2
            )
        )

        XCTAssertTrue(assessment.isUtility)
        XCTAssertEqual(assessment.accidentalRisk, 0.2, accuracy: 0.0001)
    }

    func testVisualAnalyzerFallsBackToHeuristicsWhenVisionScoringFails() throws {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bytesPerRow: 16,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        let image = try XCTUnwrap(context.makeImage())

        let metrics = PhotoVisualAnalyzer.metrics(
            from: image,
            qualityScorer: NilPhotoQualityScorer()
        )

        XCTAssertEqual(metrics?.quality.source, .heuristic)
    }

    private func featurePrint(_ values: [Float]) -> PhotoFeaturePrint {
        var mutableValues = values
        let data = mutableValues.withUnsafeMutableBytes { buffer in
            Data(buffer)
        }
        return PhotoFeaturePrint(
            data: data,
            elementType: .float,
            elementCount: values.count
        )
    }
}

private struct NilPhotoQualityScorer: PhotoQualityScoring {
    func assessment(
        for image: CGImage,
        features: PhotoQualityFeatures
    ) -> PhotoQualityAssessment? {
        nil
    }
}

private final class StubFeatureProvider: MLFeatureProvider {
    let values: [String: MLFeatureValue]

    init(values: [String: MLFeatureValue]) {
        self.values = values
    }

    var featureNames: Set<String> {
        Set(values.keys)
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        values[featureName]
    }
}
