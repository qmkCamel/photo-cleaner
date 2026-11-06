import XCTest
@testable import TrueKeep

final class PhotoDeletionResultTests: XCTestCase {
    func testDebugOptInPersistsAcrossDefaultsInstances() throws {
        for useEnvironment in [false, true] {
            let suite = "TrueKeepDeletionTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let firstLaunch = PhotoDeletionSafetyPolicy.resolved(
                arguments: useEnvironment ? [] : [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledArgument],
                environment: useEnvironment ? [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledEnvironmentKey: "1"] : [:],
                isDebugBuild: true,
                defaults: defaults
            )
            let relaunched = PhotoDeletionSafetyPolicy.resolved(
                arguments: [], environment: [:], isDebugBuild: true,
                defaults: try XCTUnwrap(UserDefaults(suiteName: suite))
            )
            XCTAssertFalse(firstLaunch.isDeletionDisabled)
            XCTAssertFalse(relaunched.isDeletionDisabled)
        }
    }

    func testExplicitDisableRevokesSavedOptInEvenWithEnableArgument() throws {
        for useEnvironment in [false, true] {
            let suite = "TrueKeepDeletionTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(true, forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey)
            var arguments = [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledArgument]
            if !useEnvironment { arguments.append(PhotoDeletionSafetyPolicy.deletionDisabledArgument) }
            let disabled = PhotoDeletionSafetyPolicy.resolved(
                arguments: arguments,
                environment: useEnvironment ? [PhotoDeletionSafetyPolicy.deletionDisabledEnvironmentKey: "1"] : [:],
                isDebugBuild: true, defaults: defaults
            )
            XCTAssertTrue(disabled.isDeletionDisabled)
            XCTAssertNil(defaults.object(forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey))
            XCTAssertTrue(PhotoDeletionSafetyPolicy.resolved(
                arguments: [], environment: [:], isDebugBuild: true, defaults: defaults
            ).isDeletionDisabled)
        }
    }

    func testReleaseDoesNotReadOrModifyDebugOptIn() throws {
        let suite = "TrueKeepDeletionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey)
        XCTAssertFalse(PhotoDeletionSafetyPolicy.resolved(
            arguments: [PhotoDeletionSafetyPolicy.destructiveDeletionEnabledArgument],
            environment: [:], isDebugBuild: false, defaults: defaults
        ).isDeletionDisabled)
        XCTAssertFalse(defaults.bool(forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey))
        defaults.set(true, forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey)
        XCTAssertTrue(PhotoDeletionSafetyPolicy.resolved(
            arguments: [PhotoDeletionSafetyPolicy.deletionDisabledArgument],
            environment: [:], isDebugBuild: false, defaults: defaults
        ).isDeletionDisabled)
        XCTAssertTrue(defaults.bool(forKey: PhotoDeletionSafetyPolicy.persistedDestructiveDeletionKey))
    }

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
