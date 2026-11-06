import XCTest
@testable import TrueKeep

final class AdaptiveLayoutTests: XCTestCase {
    func testSplitRequiresEveryConstraint() {
        XCTAssertTrue(policy(720, 480).usesSplitNavigation)
        XCTAssertFalse(policy(719, 480).usesSplitNavigation)
        XCTAssertFalse(policy(720, 479).usesSplitNavigation)
        XCTAssertFalse(AdaptiveLayoutPolicy(size: CGSize(width: 1000, height: 800), isRegular: false, isAccessibilitySize: false).usesSplitNavigation)
        XCTAssertFalse(AdaptiveLayoutPolicy(size: CGSize(width: 1000, height: 800), isRegular: true, isAccessibilitySize: true).usesSplitNavigation)
    }

    func testGridBoundariesAndAccessibility() {
        for (width, count) in [(0, 1), (155, 1), (323, 1), (324, 2), (492, 3), (660, 4), (2000, 4)] {
            XCTAssertEqual(AdaptiveLayoutPolicy.columnCount(width: CGFloat(width), accessibility: false), count)
            XCTAssertEqual(AdaptiveLayoutPolicy.columnCount(width: CGFloat(width), accessibility: true), 1)
        }
    }

    func testShortWindowMovesActionsIntoScrollContent() {
        XCTAssertTrue(policy(1000, 439).usesInlineActions)
        XCTAssertFalse(policy(1000, 440).usesInlineActions)
    }

    func testSafeBoundsAreNotDeductedTwice() {
        let bounds = CGRect(x: 0, y: 0, width: 900, height: 700)
        XCTAssertEqual(AdaptiveLayoutPolicy.unobstructedBounds(in: bounds, avoiding: []), bounds)
        XCTAssertEqual(AdaptiveLayoutPolicy.unobstructedBounds(in: bounds, avoiding: [CGRect(x: -50, y: 0, width: 50, height: 700)]), bounds)
    }

    func testHorizontalFoldUsesUnobstructedPane() {
        let result = AdaptiveLayoutPolicy.unobstructedBounds(in: CGRect(x: 0, y: 0, width: 900, height: 700), avoiding: [CGRect(x: 0, y: 300, width: 900, height: 40)])
        XCTAssertEqual(result, CGRect(x: 0, y: 340, width: 900, height: 360))
        XCTAssertFalse(policy(result.width, result.height).usesSplitNavigation)
    }

    func testPhysicalAsymmetryDoesNotMirrorWithLanguage() {
        let result = AdaptiveLayoutPolicy.unobstructedBounds(in: CGRect(x: 0, y: 0, width: 900, height: 700), avoiding: [CGRect(x: 0, y: 0, width: 80, height: 700)])
        XCTAssertEqual(result.minX, 80)
        XCTAssertEqual(result.width, 820)
    }

    private func policy(_ width: CGFloat, _ height: CGFloat) -> AdaptiveLayoutPolicy {
        .init(size: CGSize(width: width, height: height), isRegular: true, isAccessibilitySize: false)
    }
}

@MainActor
final class DeletionCoordinatorTests: XCTestCase {
    func testDuplicateSubmissionAndDismissWhileRunning() async {
        let coordinator = DeletionCoordinator()
        let service = SuspendedDeletionService()
        coordinator.prepare(source: .reviewBin, assetIDs: ["b", "a", "a"])
        let original = coordinator.request
        let finished = expectation(description: "one result")
        coordinator.submit(validIDs: ["a", "b"], service: service) { request, _ in
            XCTAssertEqual(request, original)
            finished.fulfill()
        }
        coordinator.dismiss()
        coordinator.prepare(source: .group("other"), assetIDs: ["c"])
        coordinator.submit(validIDs: ["a", "b"], service: service) { _, _ in XCTFail("duplicate result") }
        XCTAssertTrue(coordinator.isDeleting)
        XCTAssertEqual(coordinator.request, original)
        XCTAssertEqual(coordinator.submissionCount, 1)
        await service.completeWhenStarted()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertFalse(coordinator.isDeleting)
        XCTAssertNil(coordinator.request)
        coordinator.dismiss()
        XCTAssertNil(coordinator.message, "系统收起已完成表单不能误报未提交删除")
        let count = await service.calls
        XCTAssertEqual(count, 1)
    }

    func testChangedSnapshotNeedsAnotherExplicitConfirmation() async {
        let coordinator = DeletionCoordinator()
        coordinator.prepare(source: .group("g"), assetIDs: ["a", "b"])
        coordinator.submit(validIDs: ["b", "new"], service: ImmediateDeletionService()) { _, _ in XCTFail("must reconfirm") }
        XCTAssertEqual(coordinator.request?.assetIDs, ["b"])
        XCTAssertEqual(coordinator.submissionCount, 0)
        XCTAssertNotNil(coordinator.message)
        let finished = expectation(description: "reconfirmed")
        coordinator.submit(validIDs: ["b", "new"], service: ImmediateDeletionService()) { request, _ in
            XCTAssertEqual(request.assetIDs, ["b"])
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(coordinator.submissionCount, 1)
    }

    func testAllInvalidCannotSubmitAndCancelHasExplicitFeedback() {
        let coordinator = DeletionCoordinator()
        coordinator.prepare(source: .reviewBin, assetIDs: ["a"])
        for _ in 0..<2 {
            coordinator.submit(validIDs: [], service: ImmediateDeletionService()) { _, _ in XCTFail("invalid") }
        }
        XCTAssertEqual(coordinator.submissionCount, 0)
        coordinator.dismiss()
        XCTAssertNil(coordinator.request)
        XCTAssertEqual(coordinator.message, "未提交删除，照片没有变化。")
    }

    func testFailureReleasesLockWithoutAutomaticRetry() async {
        let coordinator = DeletionCoordinator()
        coordinator.prepare(source: .reviewBin, assetIDs: ["a"])
        let finished = expectation(description: "failure")
        coordinator.submit(validIDs: ["a"], service: ImmediateDeletionService(fails: true)) { _, result in
            if case .failure = result {} else { XCTFail("expected failure") }
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertFalse(coordinator.isDeleting)
        XCTAssertEqual(coordinator.submissionCount, 1)
    }
}

private struct ImmediateDeletionService: PhotoLibraryDeleting {
    var fails = false
    func deleteAssets(withLocalIdentifiers assetIDs: [String]) async -> PhotoDeletionResult {
        fails ? .failure(assetIDs: assetIDs, message: "test failure") : .success(deletedAssetIDs: assetIDs)
    }
}

private actor SuspendedDeletionService: PhotoLibraryDeleting {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<PhotoDeletionResult, Never>?
    func deleteAssets(withLocalIdentifiers assetIDs: [String]) async -> PhotoDeletionResult {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func completeWhenStarted() async {
        while continuation == nil { await Task.yield() }
        continuation?.resume(returning: .success(deletedAssetIDs: ["a", "b"]))
        continuation = nil
    }
}
