import XCTest
@testable import TrueKeep

final class PhotoDeletionResultTests: XCTestCase {
    func testDebugSafetyPolicyDisablesDeletionByDefault() {
        let policy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep"],
            environment: [:],
            isDebugBuild: true
        )

        XCTAssertTrue(policy.isDeletionDisabled)
    }

    func testDebugSafetyPolicyRequiresExplicitDestructiveDeletionOptIn() {
        let defaultDebugPolicy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep"],
            environment: [:],
            isDebugBuild: true
        )

        let destructiveArgumentPolicy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep", PhotoDeletionSafetyPolicy.destructiveDeletionEnabledArgument],
            environment: [:],
            isDebugBuild: true
        )

        let destructiveEnvironmentPolicy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep"],
            environment: [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledEnvironmentKey: "1"],
            isDebugBuild: true
        )

        XCTAssertTrue(defaultDebugPolicy.isDeletionDisabled)
        XCTAssertFalse(destructiveArgumentPolicy.isDeletionDisabled)
        XCTAssertFalse(destructiveEnvironmentPolicy.isDeletionDisabled)
    }

    func testExplicitDeletionDisableWinsOverDestructiveDeletionOptIn() {
        let policy = PhotoDeletionSafetyPolicy.resolved(
            arguments: [
                "TrueKeep",
                PhotoDeletionSafetyPolicy.deletionDisabledArgument,
                PhotoDeletionSafetyPolicy.destructiveDeletionEnabledArgument
            ],
            environment: [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledEnvironmentKey: "1"],
            isDebugBuild: true
        )

        XCTAssertTrue(policy.isDeletionDisabled)
    }

    func testReleaseSafetyPolicyAllowsDeletionUnlessExplicitlyDisabled() {
        let defaultReleasePolicy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep"],
            environment: [:],
            isDebugBuild: false
        )

        let disabledReleasePolicy = PhotoDeletionSafetyPolicy.resolved(
            arguments: ["TrueKeep", PhotoDeletionSafetyPolicy.deletionDisabledArgument],
            environment: [:],
            isDebugBuild: false
        )

        XCTAssertFalse(defaultReleasePolicy.isDeletionDisabled)
        XCTAssertTrue(disabledReleasePolicy.isDeletionDisabled)
    }

    func testDeletionServiceHonorsDebugSafetyLockBeforeTouchingPhotos() async {
        let service = SystemPhotoLibraryDeletionService(
            safetyPolicy: PhotoDeletionSafetyPolicy(isDeletionDisabled: true)
        )

        let result = await service.deleteAssets(withLocalIdentifiers: ["asset-1"])

        XCTAssertEqual(
            result,
            .failure(
                assetIDs: ["asset-1"],
                message: "真机调试删除安全锁已开启，未删除任何照片或视频。"
            )
        )
    }

    func testResolvedDeletionResultSucceedsWhenEveryRequestedAssetDeleted() {
        let result = PhotoDeletionResult.resolved(
            requestedAssetIDs: ["a", "b"],
            deletedAssetIDs: ["a", "b"],
            failureMessage: "删除失败。"
        )

        XCTAssertEqual(result, .success(deletedAssetIDs: ["a", "b"]))
    }

    func testResolvedDeletionResultReportsPartialMissingAssets() {
        let result = PhotoDeletionResult.resolved(
            requestedAssetIDs: ["a", "b"],
            deletedAssetIDs: ["a"],
            failureMessage: "1 项未能删除，可能已被移动或权限发生变化。"
        )

        XCTAssertEqual(
            result,
            .partial(
                deletedAssetIDs: ["a"],
                failedAssetIDs: ["b"],
                message: "1 项未能删除，可能已被移动或权限发生变化。"
            )
        )
    }

    func testResolvedDeletionResultFailsWhenNothingDeleted() {
        let result = PhotoDeletionResult.resolved(
            requestedAssetIDs: ["a", "b"],
            deletedAssetIDs: [],
            failureMessage: "没有项目被删除。"
        )

        XCTAssertEqual(result, .failure(assetIDs: ["a", "b"], message: "没有项目被删除。"))
    }
}
