import XCTest
@testable import TrueKeep

final class PhotoLibraryAuthorizationTests: XCTestCase {
    func testConfirmedKeepStorePersistsUniqueSortedIDsAndResets() throws {
        let suiteName = "ConfirmedKeepStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ConfirmedKeepStore(defaults: defaults)

        store.saveAssetIDs(["photo-b", "photo-a", "photo-b"])

        XCTAssertEqual(defaults.stringArray(forKey: ConfirmedKeepStore.defaultsKey), ["photo-a", "photo-b"])
        XCTAssertEqual(store.loadAssetIDs(), ["photo-a", "photo-b"])

        store.reset()

        XCTAssertTrue(store.loadAssetIDs().isEmpty)
        XCTAssertNil(defaults.object(forKey: ConfirmedKeepStore.defaultsKey))
    }

    func testLaunchConfigurationRecognizesConfirmedKeepResetArgument() {
        let configuration = AppLaunchConfiguration(
            arguments: [AppLaunchConfiguration.resetConfirmedKeepsArgument],
            environment: [:]
        )

        XCTAssertTrue(configuration.resetsConfirmedKeeps)
    }

    func testPhotoScanDateRangeDefaultsToLastMonth() {
        XCTAssertEqual(PhotoScanDateRange.defaultValue, .lastMonth)
        XCTAssertEqual(PhotoScanDateRange.allCases, [.lastMonth, .lastThreeMonths, .all])
    }

    func testRecentPhotoScanDateRangesUseRollingCalendarMonthsAndClosedBounds() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 8,
                day: 11,
                hour: 20
            ))
        )

        let monthBounds = try XCTUnwrap(
            PhotoScanDateRange.lastMonth.dateBounds(
                endingAt: referenceDate,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            monthBounds.lowerBound,
            calendar.date(byAdding: .month, value: -1, to: referenceDate)
        )
        XCTAssertEqual(monthBounds.upperBound, referenceDate)
        XCTAssertTrue(
            PhotoScanDateRange.lastMonth.includes(
                creationDate: monthBounds.lowerBound,
                endingAt: referenceDate,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            PhotoScanDateRange.lastMonth.includes(
                creationDate: monthBounds.upperBound,
                endingAt: referenceDate,
                calendar: calendar
            )
        )

        let threeMonthBounds = try XCTUnwrap(
            PhotoScanDateRange.lastThreeMonths.dateBounds(
                endingAt: referenceDate,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            threeMonthBounds.lowerBound,
            calendar.date(byAdding: .month, value: -3, to: referenceDate)
        )
        XCTAssertEqual(threeMonthBounds.upperBound, referenceDate)
    }

    func testAllRangeHasNoDateBoundsAndRecentRangesExcludeUnknownDates() {
        let referenceDate = Date(timeIntervalSince1970: 1_786_473_600)

        XCTAssertNil(PhotoScanDateRange.all.dateBounds(endingAt: referenceDate))
        XCTAssertTrue(PhotoScanDateRange.all.includes(creationDate: nil, endingAt: referenceDate))
        XCTAssertFalse(PhotoScanDateRange.lastMonth.includes(creationDate: nil, endingAt: referenceDate))
        XCTAssertFalse(PhotoScanDateRange.lastThreeMonths.includes(creationDate: nil, endingAt: referenceDate))
    }

    func testFullAndLimitedAccessCanScan() {
        XCTAssertTrue(PhotoLibraryAccess.full.canScan)
        XCTAssertTrue(PhotoLibraryAccess.limited.canScan)
    }

    func testDeniedAndRestrictedAccessRequireSettings() {
        XCTAssertTrue(PhotoLibraryAccess.denied.requiresSettings)
        XCTAssertTrue(PhotoLibraryAccess.restricted.requiresSettings)
    }

    func testLimitedAccessExposesIncompleteResultsWarning() {
        XCTAssertNil(PhotoLibraryAccess.full.scanLimitationWarning)
        XCTAssertEqual(
            PhotoLibraryAccess.limited.scanLimitationWarning,
            "当前只能扫描你允许访问的照片和视频，结果可能不完整。你可以稍后在系统设置里扩大访问范围。"
        )
    }

    func testPermissionDecisionRoutesFullAndLimitedAccessToScan() {
        XCTAssertEqual(PhotoPermissionDecision.phase(after: .full), .scan)
        XCTAssertEqual(PhotoPermissionDecision.phase(after: .limited), .scan)
    }

    func testPermissionDecisionRoutesDeniedAndRestrictedToPermissionIssue() {
        XCTAssertEqual(PhotoPermissionDecision.phase(after: .denied), .permissionIssue(.denied))
        XCTAssertEqual(PhotoPermissionDecision.phase(after: .restricted), .permissionIssue(.restricted))
    }

    func testPermissionDecisionRoutesNotDeterminedToMainAfterIntroAction() {
        XCTAssertEqual(PhotoPermissionDecision.phase(after: .notDetermined), .main)
    }

    func testAuthorizedHomeScenarioStartsWithoutCompletedScan() {
        let configuration = AppLaunchConfiguration(
            arguments: [AppLaunchConfiguration.uiTestAuthorizedHomeArgument],
            environment: [:]
        )

        XCTAssertEqual(configuration.uiTestScenario, .authorizedHome)
        XCTAssertEqual(configuration.initialPhase(for: .full), .main)
        XCTAssertEqual(configuration.initialPhotoAccess, .full)
        XCTAssertFalse(configuration.initialHasCompletedScan)
    }

    func testSampleCleanupDataRepresentsCompletedScanResults() {
        let configuration = AppLaunchConfiguration(
            arguments: [AppLaunchConfiguration.sampleCleanupDataArgument],
            environment: [:]
        )

        XCTAssertTrue(configuration.initialHasCompletedScan)
    }

    func testPostDeletionSuccessScenarioStartsOnLimitedHomeWithReconciledResults() {
        let configuration = AppLaunchConfiguration(
            arguments: [AppLaunchConfiguration.uiTestPostDeletionSuccessArgument],
            environment: [:]
        )

        XCTAssertEqual(configuration.uiTestScenario, .postDeletionSuccess)
        XCTAssertEqual(configuration.initialPhase(for: .limited), .main)
        XCTAssertEqual(configuration.initialPhotoAccess, .limited)
        XCTAssertTrue(configuration.initialHasCompletedScan)
        XCTAssertNotNil(configuration.initialCleanupState.deletionSummary)
        XCTAssertTrue(configuration.initialCleanupState.tasks.isEmpty)
        XCTAssertTrue(configuration.initialCleanupState.reviewGroups.isEmpty)
    }

    func testPhotoPermissionCopyDescribesOnDeviceVisualCandidatesWithSafetyLimits() throws {
        XCTAssertEqual(
            PhotoLibraryAccess.notDetermined.displayMessage,
            "留真需要照片权限，才能在本机扫描截图、大视频和低置信度视觉候选。"
        )

        assertDescribesVisualCandidatesSafely(PhotoLibraryAccess.notDetermined.displayMessage)
        assertDescribesVisualCandidatesSafely(SupportedScanCopy.permissionSafetyMessage)

        let usageDescription = try loadAppInfoPlist()["NSPhotoLibraryUsageDescription"] as? String
        XCTAssertEqual(usageDescription, SupportedScanCopy.photoLibraryUsageDescription)
        assertDescribesVisualCandidatesSafely(usageDescription)
    }

    private func assertDescribesVisualCandidatesSafely(
        _ copy: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let copy else {
            XCTFail("Expected copy to be present.", file: file, line: line)
            return
        }

        for requiredTerm in ["本机", "候选"] {
            XCTAssertTrue(
                copy.contains(requiredTerm),
                "Public permission copy should frame visual results as local review candidates: \(requiredTerm)",
                file: file,
                line: line
            )
        }

        for overclaim in ["自动删除", "无需确认", "上传你的照片"] {
            XCTAssertFalse(
                copy.contains(overclaim),
                "Public permission copy must not overclaim safety: \(overclaim)",
                file: file,
                line: line
            )
        }
    }

    private func loadAppInfoPlist() throws -> [String: Any] {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectDirectory = testsDirectory.deletingLastPathComponent()
        let infoURL = projectDirectory
            .appendingPathComponent("TrueKeep")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Info.plist")

        let data = try Data(contentsOf: infoURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw NSError(
                domain: "PhotoLibraryAuthorizationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist is not a dictionary plist."]
            )
        }
        return dictionary
    }
}
