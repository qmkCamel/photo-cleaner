import XCTest
@testable import TrueKeep

@MainActor
final class CleanupFlowStateTests: XCTestCase {
    func testZeroStorageFormattingUsesNumericValue() {
        XCTAssertEqual(Int64(0).formattedStorage, "0 KB")
    }

    func testReviewSelectionMovesIntoReviewBinBeforeDeletion() {
        var state = CleanupFlowState.sample()

        XCTAssertEqual(state.reviewBinItems.count, 0)
        XCTAssertEqual(state.currentReviewSelectionCount, 3)

        state.addCurrentSelectionToReviewBin()

        XCTAssertEqual(state.reviewBinItems.count, 3)
        XCTAssertTrue(state.reviewBinItems.allSatisfy(\.selectedForDelete))
        XCTAssertFalse(state.hasDeletedItems)
    }

    func testSuccessfulDeletionClearsAllDerivedResultsAndExposesStructuredSummary() {
        var state = screenshotState()
        state.addCurrentSelectionToReviewBin()
        let deletedIDs = state.selectedReviewBinAssetIDs

        state.applyDeletionResult(.success(deletedAssetIDs: deletedIDs))

        XCTAssertEqual(state.reviewBinItems.count, 0)
        XCTAssertEqual(state.reviewGroups.count, 0)
        XCTAssertEqual(state.tasks.count, 0)
        XCTAssertEqual(state.selectedCandidateIDs.count, 0)
        XCTAssertTrue(state.hasDeletedItems)
        XCTAssertEqual(state.deletionSummary?.deletedAssetIDs, Set(deletedIDs))
        XCTAssertEqual(state.deletionSummary?.itemCount, 3)
        XCTAssertEqual(state.deletionSummary?.estimatedBytes, 6_000_000)
        XCTAssertEqual(state.postDeletionRecoveryMessage, "所选项目已移至 Photos 的“最近删除”。建议保留恢复窗口，不要立即清空。")
    }

    func testDirectDeletionRemovesCandidatesAndSynchronizesHomeTaskAndReviewBin() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        let deletedIDs = state.selectedCurrentReviewAssetIDs
        let unaffectedScreenshotCount = state.tasks.first { $0.category == .screenshots }?.candidateCount

        state.applyDirectDeletionResult(.success(deletedAssetIDs: deletedIDs))

        XCTAssertFalse(deletedIDs.isEmpty)
        XCTAssertTrue(state.currentReviewGroup.candidates.allSatisfy { !deletedIDs.contains($0.id) })
        XCTAssertTrue(state.reviewBinItems.allSatisfy { !deletedIDs.contains($0.id) })
        XCTAssertTrue(state.selectedCandidateIDs.isDisjoint(with: deletedIDs))
        XCTAssertEqual(state.tasks.first { $0.category == .similar }?.candidateCount, 4)
        XCTAssertEqual(
            state.tasks.first { $0.category == .similar }?.estimatedBytes,
            state.currentReviewGroup.estimatedBytes
        )
        XCTAssertEqual(
            state.tasks.first { $0.category == .screenshots }?.candidateCount,
            unaffectedScreenshotCount
        )
        XCTAssertTrue(
            state.tasks.first { $0.category == .similar }?.previewCandidates.allSatisfy { !deletedIDs.contains($0.id) }
                ?? false
        )
        XCTAssertNil(state.reviewGroupDeletionErrorMessage)
        XCTAssertTrue(state.hasDeletedItems)
    }

    func testPartialDirectDeletionRemovesSuccessAndKeepsFailuresSelected() throws {
        var state = CleanupFlowState.sample()
        let selectedIDs = state.selectedCurrentReviewAssetIDs
        let deletedID = try XCTUnwrap(selectedIDs.first)
        let failedIDs = Array(selectedIDs.dropFirst())

        state.applyDirectDeletionResult(
            .partial(
                deletedAssetIDs: [deletedID],
                failedAssetIDs: failedIDs,
                message: "部分照片未能删除，请重试。"
            )
        )

        XCTAssertFalse(state.currentReviewGroup.candidates.contains { $0.id == deletedID })
        XCTAssertTrue(failedIDs.allSatisfy { failedID in
            state.currentReviewGroup.candidates.contains { $0.id == failedID }
        })
        XCTAssertTrue(failedIDs.allSatisfy { state.selectedCandidateIDs.contains($0) })
        XCTAssertEqual(state.reviewGroupDeletionErrorMessage, "1 项已删除，2 项未完成。部分照片未能删除，请重试。")
        XCTAssertEqual(state.tasks.first { $0.category == .similar }?.candidateCount, 6)
    }

    func testFailedDirectDeletionPreservesCandidatesAndSelection() {
        var state = CleanupFlowState.sample()
        let originalCandidateIDs = state.currentReviewGroup.candidates.map(\.id)
        let originalSelection = state.selectedCandidateIDs

        state.applyDirectDeletionResult(
            .failure(assetIDs: state.selectedCurrentReviewAssetIDs, message: "Photos 删除失败，请稍后重试。")
        )

        XCTAssertEqual(state.currentReviewGroup.candidates.map(\.id), originalCandidateIDs)
        XCTAssertEqual(state.selectedCandidateIDs, originalSelection)
        XCTAssertEqual(state.reviewGroupDeletionErrorMessage, "Photos 删除失败，请稍后重试。")
        XCTAssertFalse(state.hasDeletedItems)
    }

    func testSelectedReviewBinAssetIDsOnlyIncludesSelectedItems() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        state.toggleReviewBinItem(state.reviewBinItems[0])

        XCTAssertEqual(Set(state.selectedReviewBinAssetIDs), Set(state.reviewBinItems.dropFirst().map(\.id)))
    }

    func testFailedPhotoDeletionKeepsItemsAndShowsError() {
        var state = screenshotState()
        state.addCurrentSelectionToReviewBin()
        let originalGroups = state.reviewGroups
        let originalTasks = state.tasks
        let originalReviewBin = state.reviewBinItems
        let originalSelection = state.selectedCandidateIDs

        state.applyDeletionResult(.failure(assetIDs: state.selectedReviewBinAssetIDs, message: "Photos 删除失败，请稍后重试。"))

        XCTAssertEqual(state.reviewBinItems, originalReviewBin)
        XCTAssertEqual(state.reviewGroups, originalGroups)
        XCTAssertEqual(state.tasks, originalTasks)
        XCTAssertEqual(state.selectedCandidateIDs, originalSelection)
        XCTAssertFalse(state.hasDeletedItems)
        XCTAssertNil(state.deletionSummary)
        XCTAssertEqual(state.deletionErrorMessage, "Photos 删除失败，请稍后重试。")
    }

    func testPartialPhotoDeletionRemovesOnlySuccessesAndRebuildsRemainingTask() {
        var state = screenshotState()
        state.addCurrentSelectionToReviewBin()
        let deletedID = state.reviewBinItems[0].id
        let failedIDs = Array(state.reviewBinItems.dropFirst().map(\.id))

        state.applyDeletionResult(.partial(deletedAssetIDs: [deletedID], failedAssetIDs: failedIDs, message: "2 项未能删除。"))

        XCTAssertFalse(state.reviewBinItems.contains { $0.id == deletedID })
        XCTAssertTrue(failedIDs.allSatisfy { failedID in
            state.reviewBinItems.contains { $0.id == failedID && $0.selectedForDelete }
        })
        XCTAssertFalse(state.reviewGroups.flatMap(\.candidates).contains { $0.id == deletedID })
        XCTAssertFalse(state.tasks.flatMap(\.previewCandidates).contains { $0.id == deletedID })
        XCTAssertEqual(state.tasks.first?.candidateCount, 2)
        XCTAssertEqual(state.totalEstimatedBytes, 5_000_000)
        XCTAssertTrue(state.hasDeletedItems)
        XCTAssertEqual(state.deletionSummary?.deletedAssetIDs, [deletedID])
        XCTAssertEqual(state.deletionSummary?.estimatedBytes, 1_000_000)
        XCTAssertEqual(state.deletionErrorMessage, "2 项未能删除。")
    }

    func testDeletingLastActionableCandidateDropsRecommendedKeepOnlyGroup() {
        let keepCandidate = candidate(id: "keep", bytes: 0, selected: false, recommendedKeep: true)
        let deleteCandidate = candidate(id: "delete", bytes: 2_000_000, selected: true)
        let group = CleanupGroup(
            id: "similar-group",
            category: .similar,
            title: "相似照片",
            subtitle: "1 组",
            groupIndex: 1,
            totalGroups: 1,
            explanation: "测试组",
            candidates: [keepCandidate, deleteCandidate]
        )
        var state = CleanupFlowState(
            tasks: CleanupTaskBuilder.tasks(from: [group]),
            reviewGroups: [group],
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: [deleteCandidate.id],
            reviewBinItems: [],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )
        state.addCurrentSelectionToReviewBin()

        state.applyDeletionResult(.success(deletedAssetIDs: [deleteCandidate.id]))

        XCTAssertTrue(state.tasks.isEmpty)
        XCTAssertTrue(state.reviewGroups.isEmpty)
        XCTAssertEqual(state.deletionSummary?.itemCount, 1)
        XCTAssertFalse(state.deletionSummary?.deletedAssetIDs.contains(keepCandidate.id) ?? true)
    }

    func testDeletionSummaryAccumulatesUniqueAssetsAcrossBatches() {
        var state = screenshotState(count: 2)
        state.addCurrentSelectionToReviewBin()
        let firstItem = state.reviewBinItems[0]
        let secondItem = state.reviewBinItems[1]
        state.toggleReviewBinItem(secondItem)

        state.applyDeletionResult(.success(deletedAssetIDs: [firstItem.id]))
        state.toggleReviewBinItem(secondItem)
        state.applyDeletionResult(.success(deletedAssetIDs: [secondItem.id, secondItem.id]))

        XCTAssertEqual(state.deletionSummary?.deletedAssetIDs, [firstItem.id, secondItem.id])
        XCTAssertEqual(state.deletionSummary?.itemCount, 2)
        XCTAssertEqual(state.deletionSummary?.estimatedBytes, 3_000_000)
        XCTAssertTrue(state.tasks.isEmpty)
    }

    func testDeletingEarlierGroupPreservesCurrentReviewGroupByIdentity() {
        let firstGroup = reviewGroup(id: "screenshots", category: .screenshots, candidateID: "screen-1")
        let secondGroup = reviewGroup(id: "large-videos", category: .largeVideos, candidateID: "video-1")
        var state = CleanupFlowState(
            tasks: CleanupTaskBuilder.tasks(from: [firstGroup, secondGroup]),
            reviewGroups: [firstGroup, secondGroup],
            currentReviewGroupIndex: 1,
            selectedCandidateIDs: ["video-1"],
            reviewBinItems: [
                ReviewBinItem(
                    candidate: firstGroup.candidates[0],
                    selectedForDelete: true,
                    addedAt: Date(timeIntervalSince1970: 0)
                )
            ],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )

        state.applyDeletionResult(.success(deletedAssetIDs: ["screen-1"]))

        XCTAssertEqual(state.currentReviewGroup.id, secondGroup.id)
        XCTAssertEqual(state.currentReviewGroupIndex, 0)
        XCTAssertEqual(state.selectedCandidateIDs, ["video-1"])
    }

    func testNewScanStateDoesNotCarryDeletionSummary() {
        var deletedState = screenshotState(count: 1)
        deletedState.addCurrentSelectionToReviewBin()
        deletedState.applyDeletionResult(.success(deletedAssetIDs: deletedState.selectedReviewBinAssetIDs))

        let newScanState = PhotoScanResultBuilder.state(from: [])

        XCTAssertNotNil(deletedState.deletionSummary)
        XCTAssertNil(newScanState.deletionSummary)
        XCTAssertFalse(newScanState.hasDeletedItems)
    }

    func testRecommendedKeepCandidateIsNeverSelectedForDeletionByDefault() {
        let state = CleanupFlowState.sample()
        let keepCandidate = state.currentReviewGroup.candidates.first { $0.recommendedKeep }

        XCTAssertNotNil(keepCandidate)
        XCTAssertFalse(keepCandidate?.defaultSelectedForDeletion ?? true)
    }

    func testSelectingReviewGroupByIDRefreshesDefaultSelection() throws {
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

        let videoGroupID = try XCTUnwrap(
            state.reviewGroups.first(where: { $0.category == .largeVideos })?.id
        )
        XCTAssertTrue(state.selectReviewGroup(id: videoGroupID))

        XCTAssertEqual(state.currentReviewGroup.category, .largeVideos)
        XCTAssertEqual(state.currentReviewSelectionCount, 1)
        XCTAssertTrue(state.selectedCandidateIDs.contains("video-1"))
        XCTAssertFalse(state.selectedCandidateIDs.contains("screen-1"))
    }

    func testSelectingReviewGroupByIDTargetsMatchingGroupWhenCategoriesRepeat() {
        let firstGroup = reviewGroup(
            id: "similar-first",
            category: .similar,
            candidateID: "similar-first-candidate"
        )
        let secondGroup = reviewGroup(
            id: "similar-second",
            category: .similar,
            candidateID: "similar-second-candidate"
        )
        var state = CleanupFlowState(
            tasks: [],
            reviewGroups: [firstGroup, secondGroup],
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: ["similar-first-candidate"],
            reviewBinItems: [],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )

        XCTAssertTrue(state.selectReviewGroup(id: secondGroup.id))
        XCTAssertEqual(state.currentReviewGroup.id, secondGroup.id)
        XCTAssertEqual(state.selectedCandidateIDs, ["similar-second-candidate"])
    }

    func testSelectingMissingReviewGroupIDPreservesCurrentState() {
        var state = CleanupFlowState.sample()
        let originalState = state

        XCTAssertFalse(state.selectReviewGroup(id: "missing-group"))
        XCTAssertEqual(state, originalState)
    }

    func testDirectDeletionOnlyRemovesMatchingGroupWhenCategoriesRepeat() {
        let firstGroup = reviewGroup(id: "similar-1", category: .similar, candidateID: "similar-1-photo")
        let secondGroup = reviewGroup(id: "similar-2", category: .similar, candidateID: "similar-2-photo")
        var state = CleanupFlowState(
            tasks: CleanupTaskBuilder.tasks(from: [firstGroup, secondGroup]),
            reviewGroups: [firstGroup, secondGroup],
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: ["similar-1-photo"],
            reviewBinItems: [],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )

        XCTAssertTrue(state.selectReviewGroup(id: secondGroup.id))
        XCTAssertEqual(state.currentReviewGroup.id, "similar-2")
        XCTAssertEqual(state.selectedCandidateIDs, ["similar-2-photo"])

        state.applyDirectDeletionResult(.success(deletedAssetIDs: ["similar-2-photo"]))

        XCTAssertNotNil(state.tasks.first { $0.id == "similar-1" })
        XCTAssertNil(state.tasks.first { $0.id == "similar-2" })
        XCTAssertNotNil(state.reviewGroups.first { $0.id == "similar-1" })
        XCTAssertNil(state.reviewGroups.first { $0.id == "similar-2" })
        XCTAssertEqual(state.deletionSummary?.deletedAssetIDs, ["similar-2-photo"])
    }

    func testSampleTasksEachOpenAReviewGroup() {
        let state = CleanupFlowState.sample()
        let reviewCategories = Set(state.reviewGroups.map(\.category))
        let reviewGroupIDs = Set(state.reviewGroups.map(\.id))

        XCTAssertEqual(Set(state.tasks.map(\.category)), reviewCategories)
        XCTAssertEqual(Set(state.tasks.map(\.id)), reviewGroupIDs)
    }

    func testTogglingAllReviewCandidatesCompletesSelectionAndExcludesRecommendedKeepItems() {
        var state = CleanupFlowState.sample()

        XCTAssertFalse(state.areAllCandidatesInCurrentGroupSelected)
        state.toggleAllCandidatesInCurrentGroup()

        XCTAssertEqual(
            state.selectedCandidateIDs,
            Set(state.currentReviewGroup.candidates.filter { !$0.recommendedKeep }.map(\.id))
        )
        XCTAssertTrue(state.areAllCandidatesInCurrentGroupSelected)
        XCTAssertFalse(state.selectedCandidateIDs.contains("keep-01"))
    }

    func testTogglingFullySelectedReviewGroupClearsOnlyCurrentSelectableCandidates() {
        var state = CleanupFlowState.sample()
        state.toggleAllCandidatesInCurrentGroup()
        state.selectedCandidateIDs.insert("selection-from-another-group")

        XCTAssertTrue(state.areAllCandidatesInCurrentGroupSelected)
        state.toggleAllCandidatesInCurrentGroup()

        XCTAssertEqual(state.selectedCandidateIDs, ["selection-from-another-group"])
        XCTAssertFalse(state.areAllCandidatesInCurrentGroupSelected)
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
            deletionSummary: nil,
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

    private func screenshotState(count: Int = 3) -> CleanupFlowState {
        PhotoScanResultBuilder.state(
            from: (1...count).map { index in
                PhotoAssetSnapshot(
                    id: "screen-\(index)",
                    kind: .photo,
                    isScreenshot: true,
                    duration: 0,
                    estimatedBytes: Int64(index) * 1_000_000
                )
            }
        )
    }

    private func candidate(
        id: String,
        bytes: Int64,
        selected: Bool,
        recommendedKeep: Bool = false
    ) -> CleanupCandidate {
        CleanupCandidate(
            id: id,
            category: .similar,
            confidence: .high,
            defaultSelectedForDeletion: selected,
            recommendedKeep: recommendedKeep,
            reason: "测试候选",
            estimatedBytes: bytes,
            thumbnail: .screenshot
        )
    }
}
