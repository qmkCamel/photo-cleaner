import XCTest
@testable import TrueKeep

@MainActor
final class CleanupFlowStateTests: XCTestCase {
    func testReviewSelectionMovesIntoReviewBinBeforeDeletion() {
        var state = CleanupFlowState.sample()

        XCTAssertEqual(state.reviewBinItems.count, 0)
        XCTAssertEqual(state.currentReviewSelectionCount, 3)

        state.addCurrentSelectionToReviewBin()

        XCTAssertEqual(state.reviewBinItems.count, 3)
        XCTAssertTrue(state.reviewBinItems.allSatisfy(\.selectedForDelete))
        XCTAssertFalse(state.hasDeletedItems)
    }

    func testConfirmDeleteClearsReviewBinAndExposesRecoveryMessage() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()

        state.applyDeletionResult(.success(deletedAssetIDs: state.selectedReviewBinAssetIDs))

        XCTAssertEqual(state.reviewBinItems.count, 0)
        XCTAssertTrue(state.hasDeletedItems)
        XCTAssertEqual(state.postDeletionRecoveryMessage, "所选项目已移入 Photos 的 Recently Deleted。建议保留恢复窗口，不要立即清空。")
    }

    func testSelectedReviewBinAssetIDsOnlyIncludesSelectedItems() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        state.toggleReviewBinItem(state.reviewBinItems[0])

        XCTAssertEqual(Set(state.selectedReviewBinAssetIDs), Set(state.reviewBinItems.dropFirst().map(\.id)))
    }

    func testFailedPhotoDeletionKeepsItemsAndShowsError() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        let originalIDs = state.reviewBinItems.map(\.id)

        state.applyDeletionResult(.failure(assetIDs: state.selectedReviewBinAssetIDs, message: "Photos 删除失败，请稍后重试。"))

        XCTAssertEqual(state.reviewBinItems.map(\.id), originalIDs)
        XCTAssertFalse(state.hasDeletedItems)
        XCTAssertEqual(state.deletionErrorMessage, "Photos 删除失败，请稍后重试。")
    }

    func testPartialPhotoDeletionRemovesDeletedItemsAndKeepsFailuresSelected() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        let deletedID = state.reviewBinItems[0].id
        let failedID = state.reviewBinItems[1].id

        state.applyDeletionResult(.partial(deletedAssetIDs: [deletedID], failedAssetIDs: [failedID], message: "1 项未能删除。"))

        XCTAssertFalse(state.reviewBinItems.contains { $0.id == deletedID })
        XCTAssertTrue(state.reviewBinItems.contains { $0.id == failedID && $0.selectedForDelete })
        XCTAssertTrue(state.hasDeletedItems)
        XCTAssertEqual(state.deletionErrorMessage, "1 项未能删除。")
    }

    func testRecommendedKeepCandidateIsNeverSelectedForDeletionByDefault() {
        let state = CleanupFlowState.sample()
        let keepCandidate = state.currentReviewGroup.candidates.first { $0.recommendedKeep }

        XCTAssertNotNil(keepCandidate)
        XCTAssertFalse(keepCandidate?.defaultSelectedForDeletion ?? true)
    }

    func testSelectingReviewGroupByCategoryRefreshesDefaultSelection() {
        var state = PhotoScanResultBuilder.state(
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
                    duration: 420,
                    estimatedBytes: 640_000_000
                )
            ]
        )

        state.selectReviewGroup(for: .largeVideos)

        XCTAssertEqual(state.currentReviewGroup.category, .largeVideos)
        XCTAssertEqual(state.currentReviewSelectionCount, 1)
        XCTAssertTrue(state.selectedCandidateIDs.contains("video-1"))
        XCTAssertFalse(state.selectedCandidateIDs.contains("screen-1"))
    }

    func testSampleTasksEachOpenAReviewGroup() {
        let state = CleanupFlowState.sample()
        let reviewCategories = Set(state.reviewGroups.map(\.category))

        XCTAssertEqual(Set(state.tasks.map(\.category)), reviewCategories)
    }

    func testSelectingAllReviewCandidatesExcludesRecommendedKeepItems() {
        var state = CleanupFlowState.sample()

        state.selectAllCandidatesInCurrentGroup()

        XCTAssertEqual(
            state.selectedCandidateIDs,
            Set(state.currentReviewGroup.candidates.filter { !$0.recommendedKeep }.map(\.id))
        )
        XCTAssertFalse(state.selectedCandidateIDs.contains("keep-01"))
    }

    func testReviewGroupNavigationMovesBetweenGroupsAndRefreshesSelection() {
        var state = CleanupFlowState(
            tasks: [],
            reviewGroups: [
                reviewGroup(id: "screenshots", category: .screenshots, candidateID: "screen-1"),
                reviewGroup(id: "large-videos", category: .largeVideos, candidateID: "video-1")
            ],
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: ["screen-1"],
            reviewBinItems: [],
            hasDeletedItems: false,
            postDeletionRecoveryMessage: nil,
            deletionErrorMessage: nil
        )

        XCTAssertFalse(state.canMoveToPreviousReviewGroup)
        XCTAssertTrue(state.canMoveToNextReviewGroup)

        XCTAssertTrue(state.moveToNextReviewGroup())
        XCTAssertEqual(state.currentReviewGroup.category, .largeVideos)
        XCTAssertEqual(state.selectedCandidateIDs, ["video-1"])
        XCTAssertTrue(state.canMoveToPreviousReviewGroup)
        XCTAssertFalse(state.canMoveToNextReviewGroup)

        XCTAssertTrue(state.moveToPreviousReviewGroup())
        XCTAssertEqual(state.currentReviewGroup.category, .screenshots)
        XCTAssertEqual(state.selectedCandidateIDs, ["screen-1"])
    }

    private func reviewGroup(id: String, category: CleanupCategory, candidateID: String) -> CleanupGroup {
        CleanupGroup(
            id: id,
            category: category,
            title: category.title,
            subtitle: "1 项",
            groupIndex: 1,
            totalGroups: 1,
            explanation: "测试组",
            candidates: [
                CleanupCandidate(
                    id: candidateID,
                    category: category,
                    confidence: .high,
                    defaultSelectedForDeletion: true,
                    recommendedKeep: false,
                    reason: "测试候选",
                    estimatedBytes: 1,
                    thumbnail: .screenshot
                )
            ]
        )
    }
}
