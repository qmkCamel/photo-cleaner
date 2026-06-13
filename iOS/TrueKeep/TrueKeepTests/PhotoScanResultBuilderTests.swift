import XCTest
@testable import TrueKeep

final class PhotoScanResultBuilderTests: XCTestCase {
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
}
