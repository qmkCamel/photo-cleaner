import XCTest
import CoreML
import CoreGraphics
import CryptoKit
import Photos
import UIKit
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

    func testAspectPreservingRasterDimensionsKeepLandscapePortraitAndPanoramaComposition() {
        XCTAssertEqual(
            PhotoAspectPreservingRasterizer.dimensions(
                sourceWidth: 400,
                sourceHeight: 200,
                maxLongSide: 64
            ).width,
            64
        )
        XCTAssertEqual(
            PhotoAspectPreservingRasterizer.dimensions(
                sourceWidth: 400,
                sourceHeight: 200,
                maxLongSide: 64
            ).height,
            32
        )
        XCTAssertEqual(
            PhotoAspectPreservingRasterizer.dimensions(
                sourceWidth: 200,
                sourceHeight: 400,
                maxLongSide: 64
            ).width,
            32
        )
        XCTAssertEqual(
            PhotoAspectPreservingRasterizer.dimensions(
                sourceWidth: 800,
                sourceHeight: 100,
                maxLongSide: 64
            ).height,
            8
        )
    }

    func testVisualAnalyzerRetainsSourceAspectRatioAtBothStages() throws {
        let landscape = try makeImage(width: 400, height: 200)
        let portrait = try makeImage(width: 150, height: 450)

        let coarse = PhotoVisualAnalyzer.metrics(
            from: landscape,
            qualityScorer: NilPhotoQualityScorer(),
            stage: .coarse
        )
        let refined = PhotoVisualAnalyzer.metrics(
            from: portrait,
            qualityScorer: NilPhotoQualityScorer(),
            stage: .refined
        )

        XCTAssertEqual(coarse?.aspectRatio ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(refined?.aspectRatio ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testOrientationNormalizerAppliesRightRotationBeforeAnalysis() throws {
        let source = try makeImage(width: 40, height: 20)
        let orientedImage = UIImage(cgImage: source, scale: 1, orientation: .right)

        let normalized = try XCTUnwrap(
            PhotoImageOrientationNormalizer.normalizedCGImage(from: orientedImage)
        )

        XCTAssertEqual(normalized.width, 20)
        XCTAssertEqual(normalized.height, 40)
    }

    func testHashFallbackRejectsMateriallyDifferentAspectRatios() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let inputs = [
            visualInput(id: "landscape", date: now, hash: 0b1010, aspectRatio: 2.0),
            visualInput(id: "portrait", date: now.addingTimeInterval(5), hash: 0b1010, aspectRatio: 0.5)
        ]

        let classifications = PhotoVisualClassifier.classifications(from: inputs)

        XCTAssertNil(classifications["landscape"]?.similarGroupID)
        XCTAssertNil(classifications["portrait"]?.similarGroupID)
    }

    func testRefinementSelectionIncludesAllSimilarMembersAndRiskBoundaryCandidates() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let inputs = [
            visualInput(id: "similar-a", date: now, hash: 0b1010),
            visualInput(id: "similar-b", date: now.addingTimeInterval(5), hash: 0b1011),
            visualInput(
                id: "risk-boundary",
                date: nil,
                hash: UInt64.max,
                blurRisk: 0.72
            ),
            visualInput(id: "clean", date: nil, hash: 0x00ff_00ff)
        ]

        let ids = PhotoVisualClassifier.refinementAssetIDs(from: inputs)

        XCTAssertEqual(ids, Set(["similar-a", "similar-b", "risk-boundary"]))
    }

    func testRefinedFeaturePrintCanSplitCoarseSimilarGroup() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let coarse = [
            visualInput(id: "first", date: now, hash: 0b1010),
            visualInput(id: "second", date: now.addingTimeInterval(5), hash: 0b1011)
        ]
        let refined = [
            "first": visualInput(
                id: "first",
                date: now,
                hash: 0b1010,
                featurePrint: featurePrint([0, 0, 0, 0])
            ),
            "second": visualInput(
                id: "second",
                date: now.addingTimeInterval(5),
                hash: 0b1011,
                featurePrint: featurePrint([1, 1, 1, 1])
            )
        ]

        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarse,
            refinedInputsByID: refined,
            exactDuplicateGroups: []
        )

        XCTAssertNil(classifications["first"]?.similarGroupID)
        XCTAssertNil(classifications["second"]?.similarGroupID)
    }

    func testRefinementCanRemoveCoarseBlurAndAccidentalFindings() {
        let coarse = [
            visualInput(
                id: "risk",
                date: nil,
                hash: 0,
                blurRisk: 0.95,
                accidentalRisk: 0.90
            )
        ]
        let refined = [
            "risk": visualInput(
                id: "risk",
                date: nil,
                hash: 0,
                blurRisk: 0.05,
                accidentalRisk: 0.04
            )
        ]

        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarse,
            refinedInputsByID: refined,
            exactDuplicateGroups: []
        )

        XCTAssertNil(classifications["risk"])
    }

    func testRefinedQualityCanChangeRecommendedKeep() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let coarse = [
            visualInput(id: "first", date: now, hash: 0b1010, overallQuality: 0.9),
            visualInput(id: "second", date: now.addingTimeInterval(5), hash: 0b1011, overallQuality: 0.4)
        ]
        let refined = [
            "first": visualInput(id: "first", date: now, hash: 0b1010, overallQuality: 0.3),
            "second": visualInput(
                id: "second",
                date: now.addingTimeInterval(5),
                hash: 0b1011,
                overallQuality: 0.95
            )
        ]

        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarse,
            refinedInputsByID: refined,
            exactDuplicateGroups: []
        )

        XCTAssertFalse(classifications["first"]?.recommendedKeep ?? true)
        XCTAssertTrue(classifications["second"]?.recommendedKeep ?? false)
    }

    func testUnavailableRefinementKeepsCandidateLowConfidenceAndUnselected() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let coarse = [
            visualInput(id: "refined", date: now, hash: 0b1010, overallQuality: 0.9),
            visualInput(id: "coarse-only", date: now.addingTimeInterval(5), hash: 0b1011, overallQuality: 0.4)
        ]
        let refined = [
            "refined": visualInput(
                id: "refined",
                date: now,
                hash: 0b1010,
                overallQuality: 0.9
            )
        ]
        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarse,
            refinedInputsByID: refined,
            exactDuplicateGroups: []
        )
        let state = PhotoScanResultBuilder.state(
            from: coarse.map { input in
                PhotoAssetSnapshot(
                    id: input.assetID,
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    visualClassification: classifications[input.assetID]
                )
            }
        )
        let coarseCandidate = state.reviewGroups
            .flatMap(\.candidates)
            .first { $0.id == "coarse-only" }

        XCTAssertEqual(coarseCandidate?.confidence, .low)
        XCTAssertFalse(coarseCandidate?.defaultSelectedForDeletion ?? true)
        XCTAssertTrue(coarseCandidate?.reason.contains("仅保留粗筛结果") ?? false)
    }

    func testExactDuplicateGroupUsesDistinctUserFacingCopy() {
        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: [
                visualInput(id: "exact-a", date: Date(), hash: 0),
                visualInput(id: "exact-b", date: Date(), hash: 0)
            ],
            refinedInputsByID: [
                "exact-a": visualInput(id: "exact-a", date: Date(), hash: 0),
                "exact-b": visualInput(id: "exact-b", date: Date(), hash: 0)
            ],
            exactDuplicateGroups: [["exact-a", "exact-b"]]
        )
        let state = PhotoScanResultBuilder.state(
            from: ["exact-a", "exact-b"].map { id in
                PhotoAssetSnapshot(
                    id: id,
                    kind: .photo,
                    isScreenshot: false,
                    duration: 0,
                    visualClassification: classifications[id]
                )
            }
        )

        XCTAssertEqual(state.reviewGroups.first?.title, "精确重复照片")
        XCTAssertTrue(state.tasks.first?.description.contains("内容完全相同") ?? false)
        XCTAssertTrue(state.reviewGroups.first?.candidates.allSatisfy(\.isExactDuplicate) ?? false)
    }

    func testExactDuplicateRequiresCompletedRefinementForEveryMarkedMember() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let coarse = [
            visualInput(id: "refined", date: now, hash: 0),
            visualInput(id: "coarse-only", date: now.addingTimeInterval(5), hash: 0)
        ]

        let classifications = PhotoVisualClassifier.finalClassifications(
            coarseInputs: coarse,
            refinedInputsByID: [
                "refined": visualInput(id: "refined", date: now, hash: 0)
            ],
            exactDuplicateGroups: [["refined", "coarse-only"]]
        )

        XCTAssertFalse(classifications["refined"]?.isExactDuplicate ?? false)
        XCTAssertFalse(classifications["coarse-only"]?.isExactDuplicate ?? false)
        XCTAssertFalse(classifications["coarse-only"]?.wasRefined ?? true)
    }

    func testExactDuplicateGrouperSeparatesStillLiveAndIncompleteResources() {
        let samePhoto = Data([1, 2, 3])
        let sameVideo = Data([4, 5, 6])
        let groups = PhotoExactDuplicateGrouper.groups(
            candidateAssetIDs: ["still-a", "still-b", "live-a", "live-b", "incomplete"],
            digestsByAssetID: [
                "still-a": PhotoResourceDigestSet(kind: .stillPhoto, photoDigest: samePhoto),
                "still-b": PhotoResourceDigestSet(kind: .stillPhoto, photoDigest: samePhoto),
                "live-a": PhotoResourceDigestSet(
                    kind: .livePhoto,
                    photoDigest: samePhoto,
                    pairedVideoDigest: sameVideo
                ),
                "live-b": PhotoResourceDigestSet(
                    kind: .livePhoto,
                    photoDigest: samePhoto,
                    pairedVideoDigest: sameVideo
                ),
                "incomplete": PhotoResourceDigestSet(
                    kind: .livePhoto,
                    photoDigest: samePhoto,
                    pairedVideoDigest: nil
                )
            ]
        )

        XCTAssertEqual(groups, [["live-a", "live-b"], ["still-a", "still-b"]])
    }

    func testResourceDigestOptionsNeverAllowNetworkAccess() {
        let options = PhotoAssetResourceRequestStrategy.localOnlyOptions()

        XCTAssertFalse(options.isNetworkAccessAllowed)
    }

    func testResourceDigestAccumulatorHashesIncrementalChunks() {
        let accumulator = PhotoResourceSHA256Accumulator()
        accumulator.update(Data("first-".utf8))
        accumulator.update(Data("second".utf8))

        XCTAssertEqual(
            accumulator.finalize(),
            Data(SHA256.hash(data: Data("first-second".utf8)))
        )
    }

    func testResourceRequestCancellationHandlesCancellationBeforeRequestIDArrives() {
        let recorder = CancelledRequestRecorder()
        let cancellation = PhotoRequestCancellation<Int> { requestID in
            recorder.append(requestID)
        }

        cancellation.cancel()
        cancellation.store(42)

        XCTAssertEqual(recorder.values, [42])
    }

    private func visualInput(
        id: String,
        date: Date?,
        hash: UInt64,
        featurePrint: PhotoFeaturePrint? = nil,
        aspectRatio: Double = 1,
        overallQuality: Double = 0.6,
        blurRisk: Double = 0,
        accidentalRisk: Double = 0
    ) -> PhotoVisualInput {
        PhotoVisualInput(
            assetID: id,
            creationDate: date,
            metrics: PhotoVisualMetrics(
                perceptualHash: hash,
                featurePrint: featurePrint,
                brightness: 0.5,
                saturation: 0.3,
                sharpness: 0.06,
                aspectRatio: aspectRatio,
                quality: PhotoQualityAssessment(
                    overallQuality: overallQuality,
                    blurRisk: blurRisk,
                    accidentalRisk: accidentalRisk
                )
            )
        )
    }

    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
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

private final class CancelledRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [Int] = []

    var values: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(_ value: Int) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
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
