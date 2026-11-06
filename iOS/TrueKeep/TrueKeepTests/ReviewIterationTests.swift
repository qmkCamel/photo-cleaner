import XCTest
@testable import TrueKeep

@MainActor
final class ReviewIterationTests: XCTestCase {
    func testSessionRoundTripAndExpirationNeverDeletePhotos() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReviewSessionStore(fileURL: root.appendingPathComponent("session.json"))
        var state = CleanupFlowState.sample()
        state.toggleAllCandidatesInCurrentGroup()
        state.addCurrentSelectionToReviewBin()
        let now = Date()
        state.reviewBinItems[0].addedAt = now.addingTimeInterval(-31 * 86_400)
        let expiredID = state.reviewBinItems[0].id
        try store.save(SavedReviewSession(state: state, completedRange: .all))
        let restored = try XCTUnwrap(store.load(now: now))
        XCTAssertEqual(restored.completedRange, .all)
        XCTAssertFalse(restored.state.reviewBinItems.contains { $0.id == expiredID })
        XCTAssertTrue(restored.state.reviewGroups.flatMap(\.candidates).contains { $0.id == expiredID })
        XCTAssertFalse(TrueKeepFeatureFlags.recommendedKeepEnabled)
    }

    func testCorruptSessionThrowsAndRemainsUntouched() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("invalid".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try ReviewSessionStore(fileURL: url).load())
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testRebuildKeepsCorruptFileBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ReviewSessionStore(fileURL: root.appendingPathComponent("session.json"))
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: store.fileURL)
        try store.rebuildPreservingBackup(SavedReviewSession(state: .sample(), completedRange: .all))
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("review-session-backup-") })
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        XCTAssertNotNil(try store.load())
    }

    func testRescanMergeRetainsBinAndAppliesConfirmedKeeps() {
        var state = CleanupFlowState.sample()
        state.toggleAllCandidatesInCurrentGroup()
        state.addCurrentSelectionToReviewBin()
        let binIDs = state.selectedReviewBinAssetIDs
        let secondGroup = state.reviewGroups.last!
        let keeps = Set(secondGroup.candidates.map(\.id))
        state.applyConfirmedKeepAssetIDs(keeps)
        state.mergeScanResult(.sample(), confirmedKeepAssetIDs: keeps)
        XCTAssertEqual(state.selectedReviewBinAssetIDs, binIDs)
        XCTAssertFalse(state.tasks.contains { $0.id == secondGroup.id })
        XCTAssertTrue(state.selectedCandidateIDs.isEmpty)
    }

    func testConfirmedKeepClearsBinAndRememberedSelectionWithoutEnablingRecommendation() throws {
        var state = CleanupFlowState.sample()
        let group = state.currentReviewGroup
        let newKeep = try XCTUnwrap(group.candidates.first { !$0.recommendedKeep })
        state.toggleAllCandidatesInCurrentGroup()
        state.addCurrentSelectionToReviewBin()
        state.applyConfirmedKeepAssetIDs([newKeep.id])
        XCTAssertTrue(state.currentReviewGroup.candidates.first { $0.id == newKeep.id }!.confirmedKeep)
        XCTAssertFalse(state.reviewBinItems.contains { $0.id == newKeep.id })
        XCTAssertFalse(state.selectedCandidateIDs.contains(newKeep.id))
        state.selectReviewGroup(id: group.id)
        XCTAssertFalse(state.selectedCandidateIDs.contains(newKeep.id))
        state.mergeScanResult(.sample(), confirmedKeepAssetIDs: [newKeep.id])
        state.selectReviewGroup(id: group.id)
        XCTAssertFalse(state.selectedCandidateIDs.contains(newKeep.id))
        XCTAssertFalse(state.currentReviewGroup.candidates.contains(where: \.isRecommendedKeepActive))
        state.applyConfirmedKeepAssetIDs([])
        state.selectReviewGroup(id: group.id)
        XCTAssertFalse(state.selectedCandidateIDs.contains(newKeep.id), "取消保护不能恢复先前删除选择")
    }

    func testLatestConfirmedKeepStoreOverridesRestoredSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReviewSessionStore(fileURL: root.appendingPathComponent("session.json"))
        var state = CleanupFlowState.sample()
        state.toggleAllCandidatesInCurrentGroup()
        state.addCurrentSelectionToReviewBin()
        let id = try XCTUnwrap(state.currentReviewGroup.candidates.first?.id)
        try store.save(SavedReviewSession(state: state, completedRange: .all))
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let keeps = ConfirmedKeepStore(defaults: defaults)
        keeps.saveAssetIDs([id])
        var restored = try XCTUnwrap(store.load()).state
        restored.applyConfirmedKeepAssetIDs(keeps.loadAssetIDs(), hideProtectedNonSimilarCandidates: true)
        XCTAssertFalse(restored.selectedReviewBinAssetIDs.contains(id))
        restored.selectReviewGroup(id: state.currentReviewGroup.id)
        XCTAssertFalse(restored.selectedCandidateIDs.contains(id))
        XCTAssertTrue(restored.currentReviewGroup.candidates.first { $0.id == id }!.confirmedKeep)
    }

    func testConfirmedSimilarReferenceSurvivesPermissionReconciliation() {
        var state = CleanupFlowState.sample()
        let group = state.currentReviewGroup
        let keep = group.candidates[0].id
        state.applyConfirmedKeepAssetIDs([keep])
        let available = Set(state.reviewGroups.flatMap { $0.candidates.map(\.id) })
        state.reconcileAccessibleAssets(available)
        XCTAssertTrue(state.reviewGroups.contains { $0.id == group.id })
        XCTAssertTrue(state.reviewGroups[0].candidates.first { $0.id == keep }!.confirmedKeep)
    }

    func testSuccessfulRescanResetsDeletionSummaryAndDoesNotResurrectDeletedItems() {
        var state = CleanupFlowState.sample()
        let id = state.currentReviewGroup.candidates[0].id
        state.applyDirectDeletionResult(.success(deletedAssetIDs: [id]))
        XCTAssertNotNil(state.deletionSummary)
        state.mergeScanResult(.sample(), confirmedKeepAssetIDs: [])
        XCTAssertNil(state.deletionSummary)
        XCTAssertFalse(state.reviewGroups.flatMap(\.candidates).contains { $0.id == id })
    }

    func testPermissionShrinkAndEmptyGroupAreSafeWithoutDeletionSummary() {
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        state.reconcileAccessibleAssets([])
        XCTAssertTrue(state.reviewGroups.isEmpty)
        XCTAssertTrue(state.currentReviewGroup.candidates.isEmpty)
        XCTAssertNil(state.deletionSummary)
        XCTAssertFalse(state.selectReviewGroup(id: "removed"))
    }

    func testPartialSelectionSurvivesGroupNavigation() throws {
        var state = CleanupFlowState.sample()
        let first = state.currentReviewGroup
        let candidate = try XCTUnwrap(first.candidates.first { !$0.recommendedKeep })
        state.toggleReviewCandidate(candidate)
        let selected = state.selectedCandidateIDs
        state.moveToNextReviewGroup()
        state.selectReviewGroup(id: first.id)
        XCTAssertEqual(state.selectedCandidateIDs, selected)
    }

    func testCacheInvalidatesModifiedAssetsAndKeepsBoundedSize() {
        let a = PhotoAnalysisCache.key(assetID: "a", modified: Date(timeIntervalSince1970: 1), width: 100, height: 100, stage: "coarse")
        let b = PhotoAnalysisCache.key(assetID: "a", modified: Date(timeIntervalSince1970: 2), width: 100, height: 100, stage: "coarse")
        XCTAssertNotEqual(a, b)
        var cache = PhotoAnalysisCache()
        for index in 0..<(PhotoAnalysisCache.capacity + 120) {
            cache.insert(metrics(), key: "\(index)", assetID: "\(index)")
        }
        cache.trim()
        XCTAssertLessThanOrEqual(cache.entries.count, PhotoAnalysisCache.capacity)
        cache.retainAssets(["2119"])
        XCTAssertLessThanOrEqual(cache.entries.count, 1)
    }

    func testBatchRangesCoverBeyondBothFormerGlobalLimits() {
        for lowPower in [false, true] {
            let policy = PhotoLibraryScanPolicy(isLowPowerModeEnabled: lowPower)
            let ranges = PhotoAssetSnapshotBatcher.batchRanges(totalCount: 701, batchSize: policy.visualBatchSize)
            XCTAssertEqual(ranges.flatMap { Array($0) }, Array(0..<701))
        }
    }

    func testCrossTimeDuplicatesNeedResourceEvidenceBeforeExactClassification() {
        let inputs = [
            PhotoVisualInput(assetID: "a", creationDate: Date(timeIntervalSince1970: 0), metrics: metrics()),
            PhotoVisualInput(assetID: "b", creationDate: Date(timeIntervalSince1970: 86_400), metrics: metrics())
        ]
        XCTAssertEqual(PhotoVisualClassifier.crossTimeDuplicateCandidateGroups(from: inputs), [["a", "b"]])
        XCTAssertNil(PhotoVisualClassifier.classifications(from: inputs)["a"]?.similarGroupID)
        let refined = Dictionary(uniqueKeysWithValues: inputs.map { ($0.assetID, $0) })
        let unconfirmed = PhotoVisualClassifier.finalClassifications(coarseInputs: inputs, refinedInputsByID: refined, exactDuplicateGroups: [])
        XCTAssertNotEqual(unconfirmed["a"]?.isExactDuplicate, true)
        let confirmed = PhotoVisualClassifier.finalClassifications(coarseInputs: inputs, refinedInputsByID: refined, exactDuplicateGroups: [["a", "b"]])
        XCTAssertEqual(confirmed["a"]?.isExactDuplicate, true)
        XCTAssertEqual(confirmed["a"]?.similarGroupID, confirmed["b"]?.similarGroupID)
    }

    private func metrics() -> PhotoVisualMetrics {
        PhotoVisualMetrics(perceptualHash: 0xaaaa, brightness: 0.5, saturation: 0.5, sharpness: 0.1)
    }
}
