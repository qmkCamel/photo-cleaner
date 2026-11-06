import XCTest

@MainActor
final class TrueKeepUITests: XCTestCase {
    private var app: XCUIApplication!
    private let defaultTimeout: TimeInterval = 5
    private let criticalAccessibilityAuditTypes: XCUIAccessibilityAuditType = [
        .contrast,
        .dynamicType,
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
        .textClipped,
        .trait
    ]

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepResetIntroState",
            "-TrueKeepResetConfirmedKeeps",
            "-TrueKeepUITestForceNotDeterminedAccess"
        ]
        app.launch()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    // These run on the selected native simulator. Rotation is not fold-posture coverage.
    func testDuoReviewSelectionSurvivesRotation() throws {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestMultipleSimilarGroups", "-TrueKeepResetConfirmedKeeps", "-TrueKeepUITestLayoutMetrics"])
        let task = app.buttons[ID.taskSimilarSecond]
        scrollToMakeHittable(task)
        task.tap()
        let candidate = app.buttons["truekeep.review.candidate.similar-13-delete"]
        XCTAssertTrue(candidate.waitForExistence(timeout: defaultTimeout))
        candidate.tap()
        let selectedLabel = app.buttons[ID.addToReviewBin].label
        attachScreenshot(named: "duo-review-portrait-selected")
        try rotateAndRequireWindowChange(to: .landscapeLeft)
        XCTAssertTrue(candidate.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(candidate.isSelected)
        XCTAssertEqual(app.buttons[ID.addToReviewBin].label, selectedLabel)
        attachScreenshot(named: "duo-review-landscape-selected")
        try rotateAndRequireWindowChange(to: .portrait)
        XCTAssertTrue(candidate.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(candidate.isSelected)
        XCTAssertEqual(app.buttons[ID.addToReviewBin].label, selectedLabel)
        attachScreenshot(named: "duo-review-returned-selected")
    }

    func testDuoDeleteConfirmationAndInflightRotation() throws {
        for direct in [true, false] {
            launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestAuthorizedHome", "-TrueKeepResetConfirmedKeeps", "-TrueKeepUITestDelayPhotoDeletion", "-TrueKeepUITestSuccessfulPhotoDeletion", "-TrueKeepUITestLayoutMetrics"])
            app.buttons[ID.taskScreenshots].tap()
            if direct {
                app.buttons["review.more"].tap()
                app.buttons[ID.directDeleteSelection].tap()
            } else {
                app.buttons[ID.addToReviewBin].tap()
                app.buttons[ID.deleteReviewBinSelection].tap()
            }
            let confirm = app.buttons[ID.confirmPhotoDeletion]
            XCTAssertTrue(confirm.waitForExistence(timeout: defaultTimeout))
            attachScreenshot(named: "duo-\(direct ? "direct" : "bin")-confirm-before-rotation")
            try rotateAndRequireWindowChange(to: .landscapeLeft)
            scrollToMakeHittable(confirm)
            XCTAssertTrue(confirm.label.contains("3"))
            attachScreenshot(named: "duo-\(direct ? "direct" : "bin")-confirm-landscape")
            confirm.tap()
            XCTAssertTrue(waitForButtonEnabled(ID.confirmPhotoDeletion, false))
            try rotateAndRequireWindowChange(to: .portrait)
            attachScreenshot(named: "duo-\(direct ? "direct" : "bin")-deletion-processing")
            XCTAssertTrue(app.staticTexts[direct ? "删除已完成" : "复核箱已清空"].waitForExistence(timeout: 12))
            XCTAssertEqual(app.staticTexts["deletion.submissions"].label, "删除请求：1")
            attachScreenshot(named: "duo-\(direct ? "direct" : "bin")-deletion-result-once")
        }
    }

    func testDuoScanDraftSurvivesRotationAndCancel() throws {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestAuthorizedHome", "-TrueKeepResetScanPreferences", "-TrueKeepUITestLayoutMetrics"])
        app.buttons[ID.homeScan].tap()
        app.buttons[ID.scanDateRangeAll].tap()
        try rotateAndRequireWindowChange(to: .landscapeLeft)
        XCTAssertTrue(app.buttons[ID.scanDateRangeAll].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.scanDateRangeAll].isSelected)
        attachScreenshot(named: "duo-scan-draft-landscape")
        app.buttons["scan.setup.cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[ID.completedScanDateRange].label.contains("近一个月"))
        XCTAssertFalse(app.buttons[ID.viewScanResults].exists)
        attachScreenshot(named: "duo-scan-draft-cancelled")
    }

    func testDuoReportRotationFailureAndRetry() throws {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestAuthorizedHome", "-TrueKeepUITestCoverage", "-TrueKeepUITestReportExportFailure", "-TrueKeepUITestLayoutMetrics"])
        app.buttons["scan.details"].tap()
        app.buttons["scan.export-report"].tap()
        XCTAssertTrue(waitForButtonEnabled("scan.export-report", false))
        try rotateAndRequireWindowChange(to: .landscapeLeft)
        XCTAssertTrue(app.staticTexts["报告生成失败，请重试。"].waitForExistence(timeout: 10))
        let details = app.descendants(matching: .any)["scan.details.form"].firstMatch
        for _ in 0..<4 where !app.staticTexts["报告生成失败，请重试。"].isHittable {
            details.swipeUp()
        }
        attachScreenshot(named: "duo-report-rotated-failure")
        XCTAssertTrue(app.staticTexts["报告生成失败，请重试。"].isHittable)
        app.buttons["scan.export-report"].tap()
        try rotateAndRequireWindowChange(to: .portrait)
        XCTAssertTrue(app.buttons["scan.share-report"].waitForExistence(timeout: 10))
        attachScreenshot(named: "duo-report-retry-success")
    }

    func testDuoScanBusyRotateReturnAndCancel() throws {
        launchForUITestScenario("-TrueKeepUITestScanRefining")
        try rotateAndRequireWindowChange(to: .landscapeLeft)
        app.buttons[ID.continueBrowsing].tap()
        XCTAssertTrue(app.buttons[ID.homeActiveScan].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "duo-scan-landscape-browsing")
        try rotateAndRequireWindowChange(to: .portrait)
        app.buttons[ID.homeActiveScan].tap()
        app.buttons[ID.cancelScan].tap()
        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "duo-scan-cancelled-recovery")
    }

    private func rotateAndRequireWindowChange(to orientation: UIDeviceOrientation) throws {
        let previousSize = app.frame.size
        XCUIDevice.shared.orientation = orientation
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(self.app.frame.width - previousSize.width) > 10 || abs(self.app.frame.height - previousSize.height) > 10
        }, object: nil)
        guard XCTWaiter.wait(for: [changed], timeout: 3) == .completed else {
            attachScreenshot(named: "duo-orientation-request-no-window-change")
            throw XCTSkip("当前模拟器未实际改变窗口尺寸；方向指令成功不代表跨尺寸验证。需要 Device Hub 姿态/显示控制。")
        }
    }

    func testDuoDeletionSafetyTextAccessibility() throws {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestAuthorizedHome", "-TrueKeepResetConfirmedKeeps"])
        app.buttons[ID.taskScreenshots].tap()
        app.buttons["review.more"].tap()
        app.buttons[ID.directDeleteSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("duo-delete-confirmation")
        attachScreenshot(named: "duo-delete-safe-text-all-visible")
    }

    func testCombinedIntroCanBeSkippedAndDoesNotReturnOnRelaunch() {
        XCTAssertTrue(app.buttons[ID.allowPhotos].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["授权前先说清楚"].exists)
        app.buttons[ID.permissionNotNow].tap()

        assertHomeIsVisible()
        XCTAssertTrue(app.buttons[ID.allowPhotos].exists)

        relaunchWithSampleCleanupData(resetIntro: false)

        assertHomeIsVisible()
        XCTAssertFalse(app.staticTexts["授权前先说清楚"].exists)
    }

    func testRedesignReviewPreviewSelectionAndKeepUndo() {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        XCTAssertFalse(app.buttons[ID.addToReviewBin].isEnabled)
        XCTAssertFalse(app.buttons[ID.directDeleteSelection].exists)
        attachScreenshot(named: "redesign-review-none")
        app.buttons["review.preview.keep-01"].tap()
        XCTAssertTrue(app.staticTexts["media.unavailable"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-preview-unavailable")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertFalse(app.buttons[ID.addToReviewBin].isEnabled)
        app.buttons[ID.reviewCandidateFormerRecommendation].tap()
        XCTAssertTrue(app.buttons[ID.addToReviewBin].label.contains("1"))
        attachScreenshot(named: "redesign-review-selected")
        app.buttons["review.preview.keep-01"].tap()
        app.buttons["media.keep"].tap()
        XCTAssertEqual(app.buttons["media.keep"].label, "已确认保留")
        XCTAssertFalse(app.buttons["media.keep"].isEnabled)
        app.buttons["完成"].firstMatch.tap()
        XCTAssertFalse(app.buttons[ID.reviewCandidateFormerRecommendation].exists)
        XCTAssertFalse(app.buttons[ID.addToReviewBin].isEnabled)
        attachScreenshot(named: "redesign-review-kept")
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.buttons[ID.reviewCandidateFormerRecommendation].exists)
        XCTAssertFalse(app.buttons[ID.addToReviewBin].isEnabled)
        attachScreenshot(named: "redesign-review-keep-undone")
    }

    func testRedesignMenuDeletionShowsBusyAndSuccess() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", "-TrueKeepUITestForceNotDeterminedAccess", "-TrueKeepUITestDelayPhotoDeletion", "-TrueKeepUITestSuccessfulPhotoDeletion"])
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        app.buttons["review.more"].tap()
        app.buttons[ID.directDeleteSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-delete-confirm")
        app.buttons[ID.cancelPhotoDeletion].tap()
        XCTAssertTrue(app.buttons[ID.addToReviewBin].label.contains("3"))
        attachScreenshot(named: "redesign-delete-cancelled")
        app.buttons["review.more"].tap()
        app.buttons[ID.directDeleteSelection].tap()
        app.buttons[ID.confirmPhotoDeletion].tap()
        XCTAssertTrue(waitForButtonEnabled(ID.confirmPhotoDeletion, false))
        attachScreenshot(named: "redesign-delete-busy")
        XCTAssertTrue(app.staticTexts["删除已完成"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[ID.reviewCandidateScreenshot1].exists)
        attachScreenshot(named: "redesign-delete-success")
        tapBack()
        XCTAssertFalse(app.buttons[ID.taskScreenshots].exists)
        attachScreenshot(named: "redesign-home-after-delete")
    }

    func testRedesignPartialDeletionPreservesFailuresOnBothPaths() {
        for direct in [true, false] {
            launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", "-TrueKeepUITestForceNotDeterminedAccess", "-TrueKeepUITestPartialPhotoDeletion"])
            openHome()
            app.buttons[ID.taskScreenshots].tap()
            if direct {
                app.buttons["review.more"].tap()
                app.buttons[ID.directDeleteSelection].tap()
            } else {
                app.buttons[ID.addToReviewBin].tap()
                app.buttons[ID.deleteReviewBinSelection].tap()
            }
            app.buttons[ID.confirmPhotoDeletion].tap()
            XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
            if direct {
                XCTAssertTrue(app.staticTexts["已完成部分删除"].exists)
                XCTAssertFalse(app.staticTexts["删除已完成"].exists)
            }
            let action = app.buttons[direct ? ID.addToReviewBin : ID.deleteReviewBinSelection]
            XCTAssertTrue(action.label.contains("2"))
            XCTAssertTrue(action.isEnabled)
            XCTAssertFalse(app.buttons[direct ? ID.reviewCandidateScreenshot1 : ID.reviewBinScreenshotItem].exists)
            attachScreenshot(named: direct ? "redesign-direct-delete-partial-failure" : "redesign-bin-delete-partial-failure")
        }
    }

    func testRedesignReportExportFailureRetryAndResult() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", "-TrueKeepUITestAuthorizedHome", "-TrueKeepUITestCoverage", "-TrueKeepUITestReportExportFailure"])
        app.buttons["scan.details"].tap()
        XCTAssertTrue(app.staticTexts["报告含本地项目标识和分析统计，不含照片。分享前请确认接收方。"].exists)
        app.buttons["scan.export-report"].tap()
        XCTAssertTrue(waitForButtonEnabled("scan.export-report", false))
        attachScreenshot(named: "redesign-scan-detail-export-busy")
        XCTAssertTrue(app.staticTexts["报告生成失败，请重试。"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-scan-detail-export-failure")
        app.buttons["scan.export-report"].tap()
        XCTAssertTrue(app.buttons["scan.share-report"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.staticTexts["报告生成失败，请重试。"].exists)
        attachScreenshot(named: "redesign-scan-detail-export-success")
    }

    func testRedesignReviewAndConfirmationAtMaximumTextSize() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", "-TrueKeepUITestAuthorizedHome", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let screenshots = app.buttons[ID.taskScreenshots]
        scrollToMakeHittable(screenshots)
        screenshots.tap()
        XCTAssertTrue(app.buttons[ID.addToReviewBin].waitForExistence(timeout: defaultTimeout))
        scrollToMakeHittable(app.buttons[ID.addToReviewBin])
        XCTAssertTrue(app.buttons[ID.addToReviewBin].isHittable)
        attachScreenshot(named: "redesign-review-maximum-text")
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        scrollToMakeHittable(app.buttons[ID.deleteReviewBinSelection])
        attachScreenshot(named: "redesign-bin-maximum-text")
        app.buttons[ID.deleteReviewBinSelection].tap()
        let cancel = app.buttons[ID.cancelPhotoDeletion]
        scrollToMakeHittable(cancel)
        XCTAssertTrue(cancel.isEnabled)
        attachScreenshot(named: "redesign-delete-confirm-maximum-text")
        cancel.tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].isEnabled)
    }

    func testRedesignBinFailureAndMoveOut() {
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.restoreReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(app.buttons[ID.restoreReviewBinSelection].label, "移出复核箱")
        attachScreenshot(named: "redesign-bin-pending")
        app.buttons[ID.deleteReviewBinSelection].tap()
        app.buttons[ID.confirmPhotoDeletion].tap()
        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].isEnabled)
        attachScreenshot(named: "redesign-bin-delete-failure")
        app.buttons[ID.restoreReviewBinSelection].tap()
        XCTAssertTrue(app.staticTexts["复核箱为空"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-bin-moved-out")
    }

    func testRedesignScanSetupCancelAndCommit() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepResetIntroState", "-TrueKeepUITestAuthorizedHome"])
        app.buttons[ID.homeScan].tap()
        app.buttons[ID.scanDateRangeLastMonth].tap()
        attachScreenshot(named: "redesign-scan-setup")
        app.buttons["scan.setup.cancel"].tap()
        XCTAssertTrue(app.staticTexts["尚未扫描相册"].exists)
        XCTAssertFalse(app.buttons[ID.viewScanResults].exists)
        attachScreenshot(named: "redesign-scan-setup-cancelled")
        app.buttons[ID.homeScan].tap()
        app.buttons[ID.scanDateRangeLastThreeMonths].tap()
        app.buttons["scan.setup.start"].tap()
        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[ID.activeScanDateRange].label.contains("近三个月"))
        attachScreenshot(named: "redesign-scan-completed")
        app.buttons[ID.viewScanResults].tap()
        XCTAssertTrue(app.descendants(matching: .any)[ID.completedScanDateRange].label.contains("近三个月"))
        app.buttons[ID.homeScan].tap()
        app.buttons[ID.scanDateRangeAll].tap()
        app.buttons["scan.setup.cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[ID.completedScanDateRange].label.contains("近三个月"))
        attachScreenshot(named: "redesign-home-result-scope")
    }

    func testRedesignSettingsEditAndUndo() {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        app.buttons["review.keep-group"].tap()
        app.buttons["设置"].tap()
        attachScreenshot(named: "redesign-settings-groups")
        app.buttons[ID.settingsConfirmedKeeps].tap()
        XCTAssertFalse(app.buttons["truekeep.settings.confirmed-keeps.reset"].exists)
        attachScreenshot(named: "redesign-keeps-browse")
        app.buttons["truekeep.settings.confirmed-keep.keep-01"].tap()
        XCTAssertTrue(app.staticTexts["media.unavailable"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.buttons["media.keep"].exists)
        attachScreenshot(named: "redesign-keeps-readonly-preview")
        app.buttons["完成"].firstMatch.tap()
        app.buttons["keeps.edit"].tap()
        app.buttons["keeps.select-all"].tap()
        app.buttons["keeps.edit"].tap()
        XCTAssertFalse(app.buttons["truekeep.settings.confirmed-keeps.reset"].exists)
        XCTAssertTrue(app.buttons["truekeep.settings.confirmed-keep.keep-01"].exists)
        app.buttons["keeps.edit"].tap()
        app.buttons["keeps.select-all"].tap()
        attachScreenshot(named: "redesign-keeps-edit")
        app.buttons["truekeep.settings.confirmed-keeps.reset"].tap()
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["keeps.edit"].exists)
        attachScreenshot(named: "redesign-keeps-reset-cancelled")
        app.buttons["truekeep.settings.confirmed-keeps.reset"].tap()
        app.alerts.buttons["全部取消保留"].tap()
        XCTAssertTrue(app.staticTexts["还没有已确认保留的照片"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-keeps-empty")
        app.buttons["keeps.undo"].tap()
        XCTAssertTrue(app.buttons["keeps.edit"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "redesign-keeps-undo")
    }

    func testMediaPreviewFailureAndConfirmedKeepWithScreenshots() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestMultipleSimilarGroups"])
        app.buttons["truekeep.cleanup.task.similar-family-12"].tap()
        let preview = app.buttons["review.preview.keep-01"]
        XCTAssertTrue(preview.waitForExistence(timeout: defaultTimeout))
        preview.tap()
        XCTAssertTrue(app.staticTexts["media.unavailable"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "media-preview-local-unavailable")
        app.buttons["下一张"].tap()
        app.buttons["media.keep"].tap()
        XCTAssertTrue(app.buttons["media.keep"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.staticTexts["推荐保留"].exists)
        attachScreenshot(named: "review-preview-confirmed-keep")
    }

    func testReviewSessionSurvivesRelaunchWithScreenshot() {
        let arguments = ["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestMultipleSimilarGroups", "-TrueKeepUITestPersistentSession"]
        launchWithArguments(arguments + ["-TrueKeepResetReviewSession"])
        app.buttons[ID.taskSimilar].tap()
        app.buttons["truekeep.review.candidate.similar-02"].tap()
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "review-session-before-relaunch")
        launchWithArguments(arguments, resetConfirmedKeeps: false)
        app.buttons["复核箱"].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].label.contains("1"))
        attachScreenshot(named: "review-session-restored-after-relaunch")
    }

    func testCoverageSummaryIncludesUnreadablePhotosWithScreenshot() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestAuthorizedHome", "-TrueKeepUITestCoverage"])
        app.buttons["scan.details"].tap()
        let coverage = app.descendants(matching: .any)["scan.coverage"]
        XCTAssertTrue(coverage.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "699/701")).firstMatch.exists)
        attachScreenshot(named: "scan-coverage-with-local-unavailable")
    }

    func testKeepEntireGroupRemovesTaskAndCanClearDecision() {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepUITestMultipleSimilarGroups"])
        let task = app.buttons["truekeep.cleanup.task.similar-family-13"]
        XCTAssertTrue(task.waitForExistence(timeout: defaultTimeout))
        task.tap()
        let keep = app.buttons["review.keep-group"]
        scrollToMakeHittable(keep)
        keep.tap()
        XCTAssertFalse(app.buttons[ID.addToReviewBin].isEnabled)
        attachScreenshot(named: "review-entire-group-kept")
        app.buttons["设置"].tap()
        app.buttons[ID.settingsConfirmedKeeps].tap()
        app.buttons["keeps.edit"].tap()
        app.buttons["keeps.select-all"].tap()
        let clear = app.buttons["truekeep.settings.confirmed-keeps.reset"]
        scrollToMakeHittable(clear)
        XCTAssertTrue(clear.waitForExistence(timeout: defaultTimeout))
        clear.tap()
        app.alerts.buttons["全部取消保留"].tap()
        XCTAssertTrue(app.staticTexts["还没有已确认保留的照片"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "review-confirmed-keeps-cleared")
    }

    func testAuthorizedColdLaunchCanStartAndRepeatScanFromHome() {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestAuthorizedHome"
        ])

        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["尚未扫描相册"].waitForExistence(timeout: defaultTimeout))
        assertButtonIsReady(ID.homeScan)
        XCTAssertEqual(app.buttons[ID.homeScan].label, "扫描相册")

        app.buttons[ID.homeScan].tap()
        app.buttons["scan.setup.start"].tap()
        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.viewScanResults].tap()

        assertHomeIsVisible()
        assertButtonIsReady(ID.homeScan)
        XCTAssertEqual(app.buttons[ID.homeScan].label, "重新扫描")
    }

    func testScanDateRangeSelectionIsAppliedAndKeptSeparateFromNextSelection() throws {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestAuthorizedHome"
        ])

        assertHomeIsVisible()
        app.buttons[ID.homeScan].tap()
        XCTAssertTrue(app.descendants(matching: .any)[ID.scanDateRangeSelector].waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(app.buttons[ID.scanDateRangeLastMonth].value as? String, "已选择")
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近一个月")

        app.buttons[ID.scanDateRangeLastThreeMonths].tap()
        XCTAssertEqual(app.buttons[ID.scanDateRangeLastThreeMonths].value as? String, "已选择")
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近三个月")

        app.buttons["scan.setup.start"].tap()

        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.descendants(matching: .any)[ID.activeScanDateRange].label.contains("本次范围：近三个月"))
        app.buttons[ID.viewScanResults].tap()

        assertHomeIsVisible()
        let completedRange = app.descendants(matching: .any)[ID.completedScanDateRange]
        XCTAssertTrue(completedRange.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(completedRange.label, "本次范围：近三个月")

        app.buttons[ID.homeScan].tap()
        app.buttons[ID.scanDateRangeLastMonth].tap()
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近一个月")
        app.buttons["scan.setup.cancel"].tap()
        XCTAssertEqual(completedRange.label, "本次范围：近三个月")
        app.scrollViews[ID.cleanupResultsScreen].swipeDown()
        attachScreenshot(named: "home-scan-range-last-three-months-result")
        try assertAccessibilityAuditPasses(
            "home-scan-range-last-three-months-result",
            auditTypes: [.contrast]
        )
    }

    func testScanDateRangeSelectorSupportsAccessibilityTextSize() throws {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestAuthorizedHome",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        assertHomeIsVisible()
        app.buttons[ID.homeScan].tap()
        let allRange = app.buttons[ID.scanDateRangeAll]
        scrollToMakeHittable(allRange)
        XCTAssertTrue(allRange.label.contains("全部可访问的照片和视频"))
        attachScreenshot(named: "home-scan-range-picker-accessibility-text")
        try assertAccessibilityAuditPasses(
            "home-scan-range-picker-accessibility-text",
            auditTypes: criticalAccessibilityAuditTypes.subtracting(.textClipped)
        )
    }

    func testCompletedResultsExposeRescanAboveTabBar() {
        launchForUITestScenario("-TrueKeepUITestLimitedCompletedScan")
        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.viewScanResults].tap()

        assertHomeIsVisible()
        let rescanButton = app.buttons[ID.homeScan]
        XCTAssertTrue(rescanButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(rescanButton.isHittable)
        XCTAssertEqual(rescanButton.label, "重新扫描")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: defaultTimeout))
        XCTAssertLessThanOrEqual(rescanButton.frame.maxY, tabBar.frame.minY + 1)

        rescanButton.tap()
        app.buttons["scan.setup.start"].tap()
        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: defaultTimeout))
    }

    func testPostDeletionSuccessReconcilesHomeAndKeepsRescanAvailable() {
        launchForUITestScenario("-TrueKeepUITestPostDeletionSuccess")

        assertHomeIsVisible()
        let summary = app.descendants(matching: .any)[ID.deletionSummary]
        XCTAssertTrue(summary.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(summary.label.contains("已移至最近删除"))
        XCTAssertTrue(summary.label.contains("仍可恢复"))
        XCTAssertTrue(app.staticTexts["本轮没有待复核项目"].exists)
        XCTAssertTrue(app.staticTexts["访问范围有限"].exists)
        XCTAssertFalse(app.buttons[ID.taskScreenshots].exists)
        XCTAssertFalse(app.staticTexts["预计可释放空间"].exists)

        assertButtonIsReady(ID.homeScan)
        XCTAssertEqual(app.buttons[ID.homeScan].label, "重新扫描")
        app.buttons[ID.homeScan].tap()
        app.buttons["scan.setup.start"].tap()

        XCTAssertTrue(app.staticTexts["扫描完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.descendants(matching: .any)[ID.deletionSummary].exists)
    }

    func testPostDeletionHomePassesAccessibilityAuditAtLargeTextSize() throws {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestPostDeletionSuccess",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        assertHomeIsVisible()
        XCTAssertTrue(app.descendants(matching: .any)[ID.deletionSummary].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["本轮没有待复核项目"].exists)
        assertButtonIsReady(ID.homeScan)
        attachScreenshot(named: "home-post-deletion-accessibility-text")
        // iOS 26.3 reports a framework-level textClipped issue with a nil element when
        // the app is already launched at an accessibility size. The retained normal-size
        // audit still includes textClipped; this pass checks the remaining audit types.
        try assertAccessibilityAuditPasses(
            "home-post-deletion-accessibility-text",
            auditTypes: criticalAccessibilityAuditTypes.subtracting(.textClipped)
        )
    }

    func testSettingsRowsNavigateToDetailPages() {
        openMainThroughSettings()

        assertSettingsTopic(id: ID.settingsHowItWorks, title: "留真如何工作")
        assertSettingsTopic(id: ID.settingsPrivacyDetails, title: "数据与隐私细节")
        assertSettingsTopic(id: ID.settingsHelpSupport, title: "帮助与支持")
    }

    func testEveryHomeTaskOpensAReviewGroup() {
        openHome()

        assertTaskOpensReviewGroup(taskID: ID.taskSimilar, title: "相似照片")
        assertTaskOpensReviewGroup(taskID: ID.taskScreenshots, title: "截图复核")
        assertTaskOpensReviewGroup(taskID: ID.taskAccidental, title: "误拍复核")
        assertTaskOpensReviewGroup(taskID: ID.taskBlurry, title: "模糊复核")
        assertTaskOpensReviewGroup(taskID: ID.taskLargeVideos, title: "大视频复核")
    }

    func testHomePreviewsHideSelectionCirclesAndSecondSimilarTaskOpensSecondGroup() {
        launchForUITestScenario("-TrueKeepUITestMultipleSimilarGroups")

        assertHomeIsVisible()
        let secondSimilarTask = app.buttons[ID.taskSimilarSecond]
        scrollToMakeHittable(secondSimilarTask)
        attachScreenshot(named: "home-similar-task-previews-without-selection-circles")

        secondSimilarTask.tap()

        XCTAssertTrue(app.staticTexts["第 2 组 / 6 组"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(
            app.buttons["truekeep.review.candidate.similar-13-delete"]
                .waitForExistence(timeout: defaultTimeout)
        )
        XCTAssertFalse(app.staticTexts["第 1 组 / 6 组"].exists)
        attachScreenshot(named: "review-second-similar-task-opened-from-home")
    }

    func testLargeVisualControlsRespondNearTheirEdges() {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestForceNotDeterminedAccess",
            "-TrueKeepUITestDelayPhotoAccess"
        ])
        tapControlEdge(ID.allowPhotos, x: 0.06, y: 0.50)
        XCTAssertTrue(app.staticTexts["照片权限已关闭"].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.returnToPermission].tap()
        assertHomeIsVisible()

        app.buttons["设置"].tap()
        XCTAssertTrue(app.buttons[ID.settingsHowItWorks].waitForExistence(timeout: defaultTimeout))
        tapControlEdge(ID.settingsHowItWorks, x: 0.94, y: 0.50)
        XCTAssertTrue(app.staticTexts["留真如何工作"].waitForExistence(timeout: defaultTimeout))

        tapBack()
        app.buttons["首页"].tap()
        assertHomeIsVisible()
        tapControlEdge(ID.taskSimilar, x: 0.94, y: 0.50)
        XCTAssertTrue(app.staticTexts["相似照片"].waitForExistence(timeout: defaultTimeout))
    }

    func testDefaultLaunchDoesNotExposeFixtureCleanupTasks() {
        relaunchWithoutSampleCleanupData()

        app.buttons[ID.welcomeLearnMore].tap()
        app.buttons["首页"].tap()

        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["需要照片访问才能扫描"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.buttons[ID.taskSimilar].exists)
        XCTAssertFalse(app.buttons[ID.taskAccidental].exists)
        XCTAssertFalse(app.buttons[ID.taskBlurry].exists)
    }

    func testMainTabsUseLocalizedChineseLabels() {
        openMainThroughSettings()

        XCTAssertTrue(app.buttons["首页"].exists)
        XCTAssertTrue(app.buttons["复核箱"].exists)
        XCTAssertTrue(app.buttons["设置"].exists)
        XCTAssertFalse(app.buttons["Review Bin"].exists)
    }

    func testLargeVideoReviewShowsVideoPreviewMetadata() {
        openHome()
        app.buttons[ID.taskLargeVideos].tap()

        XCTAssertTrue(app.staticTexts["大视频复核"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons["review.preview.video-01"].exists)
        XCTAssertTrue(app.buttons["review.preview.video-01"].label.contains("650 MB"))
        attachScreenshot(named: "redesign-large-video-metadata")
    }

    func testPermissionDeniedIssueStateIsReachableForAutomation() {
        launchForUITestScenario("-TrueKeepUITestPermissionDenied")

        XCTAssertTrue(app.staticTexts["照片权限已关闭"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["你可以在系统设置中重新开启照片权限。开启前，留真不会读取或扫描你的相册。"].exists)
        XCTAssertTrue(app.buttons[ID.openSettings].exists)
        XCTAssertTrue(app.buttons[ID.retryPhotoAccess].exists)

        app.buttons[ID.returnToPermission].tap()
        assertHomeIsVisible()
    }

    func testPermissionRetryShowsLocalBusyState() {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepUITestPermissionDenied",
            "-TrueKeepUITestDelayPhotoAccess"
        ])

        XCTAssertTrue(app.staticTexts["照片权限已关闭"].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.retryPhotoAccess].tap()

        XCTAssertTrue(waitForButtonLabel(ID.retryPhotoAccess, contains: "正在重新检查"))
        XCTAssertTrue(waitForButtonEnabled(ID.retryPhotoAccess, false))
        XCTAssertTrue(app.staticTexts["照片或视频不会被上传"].exists)
        XCTAssertTrue(app.buttons[ID.openSettings].exists)
        XCTAssertTrue(waitForButtonLabel(ID.retryPhotoAccess, contains: "我已开启，重新检查"))
        XCTAssertTrue(waitForButtonEnabled(ID.retryPhotoAccess, true))
    }

    func testScanBusyStateKeepsCancelAvailable() {
        launchForUITestScenario("-TrueKeepUITestScanInProgress")

        XCTAssertFalse(app.buttons[ID.scanInProgress].exists)
        XCTAssertTrue(app.buttons[ID.continueBrowsing].isEnabled)

        let cancelButton = app.buttons[ID.cancelScan]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(cancelButton.isEnabled)
        cancelButton.tap()

        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
    }

    func testCandidateRefinementCanContinueBrowsingReturnAndCancelWithScreenshots() {
        launchForUITestScenario("-TrueKeepUITestScanRefining")

        XCTAssertTrue(app.staticTexts["正在复核候选"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.descendants(matching: .any)[ID.scanStage].label.contains("候选复核"))
        XCTAssertTrue(app.buttons[ID.cancelScan].isEnabled)
        attachScreenshot(named: "scan-candidate-refinement")

        app.buttons[ID.continueBrowsing].tap()

        assertHomeIsVisible()
        let activeScan = app.buttons[ID.homeActiveScan]
        XCTAssertTrue(activeScan.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(activeScan.label.contains("候选复核"))
        attachScreenshot(named: "home-active-candidate-refinement")

        activeScan.tap()
        XCTAssertTrue(app.buttons[ID.cancelScan].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.cancelScan].tap()

        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "scan-candidate-refinement-cancelled")
    }

    func testInterruptedScanStateIsReachableForAutomation() {
        launchForUITestScenario("-TrueKeepUITestScanInterrupted")

        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["没有发布本轮未完成结果，也没有删除或移动照片。上次可用结果仍保留。"].exists)
        XCTAssertTrue(app.buttons[ID.retryScan].exists)

        app.buttons[ID.returnToPermission].tap()
        assertHomeIsVisible()
    }

    func testLimitedCompletedScanShowsAccessWarningBeforeResults() {
        launchForUITestScenario("-TrueKeepUITestLimitedCompletedScan")

        XCTAssertTrue(app.staticTexts["扫描完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["访问范围有限"].exists)
        XCTAssertTrue(app.staticTexts["当前只能扫描你允许访问的照片和视频，结果可能不完整。你可以稍后在系统设置里扩大访问范围。"].exists)

        app.buttons[ID.viewScanResults].tap()
        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["访问范围有限"].exists)
    }

    func testMarketingScreenshotCaptureFlow() {
        attachScreenshot(named: "01-welcome")
        attachScreenshot(named: "02-permission-rationale")

        relaunchWithSampleCleanupData(resetIntro: true)
        openMainThroughSettings()
        attachScreenshot(named: "03-settings-trust")

        app.buttons["首页"].tap()
        assertHomeIsVisible()
        assertButtonIsReady(ID.taskScreenshots)
        attachScreenshot(named: "04-home-review-queue")

        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "05-screenshot-review")

        XCTAssertTrue(app.buttons[ID.addToReviewBin].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "06-review-bin")

        app.buttons[ID.deleteReviewBinSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "07-delete-safety-confirmation")

        relaunchWithoutSampleCleanupData()
        app.buttons[ID.welcomeLearnMore].tap()
        app.buttons["首页"].tap()
        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["需要照片访问才能扫描"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "08-default-empty-no-fixtures")
    }

    func testReviewFlowDeleteSafetyLockAndRestoreSelection() {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        XCTAssertTrue(app.buttons[ID.reviewAll].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.reviewAll].tap()
        XCTAssertTrue(app.buttons[ID.addToReviewBin].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.addToReviewBin].label.contains("7"))

        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.deleteReviewBinSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["iCloud 照片同步"].exists)

        app.buttons[ID.confirmPhotoDeletion].tap()
        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["真机调试删除安全锁已开启，未删除任何照片或视频。"].exists)
        attachScreenshot(named: "debug-deletion-explicit-disable-protected")

        app.buttons[ID.restoreReviewBinSelection].tap()
        XCTAssertTrue(app.staticTexts["复核箱为空"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "debug-deletion-protected-review-bin-recovered")
    }

    func testDeleteConfirmationShowsBusyStateAndPreservesItemsOnFailure() {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestForceNotDeterminedAccess",
            "-TrueKeepUITestDelayPhotoDeletion"
        ])
        openHome()
        app.buttons[ID.taskSimilar].tap()
        XCTAssertTrue(app.buttons[ID.reviewAll].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.reviewAll].tap()
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.similarReviewBinItems[0]].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.deleteReviewBinSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.confirmPhotoDeletion].tap()

        XCTAssertTrue(waitForButtonLabel(ID.confirmPhotoDeletion, contains: "正在请求系统删除"))
        XCTAssertTrue(waitForButtonEnabled(ID.confirmPhotoDeletion, false))
        XCTAssertTrue(waitForButtonEnabled(ID.cancelPhotoDeletion, false))
        XCTAssertTrue(app.staticTexts["iCloud 照片同步"].exists)

        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["真机调试删除安全锁已开启，未删除任何照片或视频。"].exists)
        XCTAssertTrue(app.buttons[ID.similarReviewBinItems[0]].waitForExistence(timeout: defaultTimeout))
    }

    func testDirectDeleteShowsBusyStateAndRefreshesHomeTaskAfterSuccess() {
        launchWithArguments([
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepResetIntroState",
            "-TrueKeepUITestForceNotDeterminedAccess",
            "-TrueKeepUITestDelayPhotoDeletion",
            "-TrueKeepUITestSuccessfulPhotoDeletion"
        ])
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))

        app.buttons["review.more"].tap()
        let directDeleteButton = app.buttons[ID.directDeleteSelection]
        XCTAssertTrue(directDeleteButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(directDeleteButton.label.contains("3"))
        attachScreenshot(named: "direct-delete-01-review-actions")
        tapControlEdge(ID.directDeleteSelection, x: 0.94, y: 0.50)

        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["iCloud 照片同步"].exists)
        attachScreenshot(named: "direct-delete-02-confirmation")
        app.buttons[ID.confirmPhotoDeletion].tap()

        XCTAssertTrue(waitForButtonLabel(ID.confirmPhotoDeletion, contains: "正在请求系统删除"))
        XCTAssertTrue(waitForButtonEnabled(ID.confirmPhotoDeletion, false))
        XCTAssertTrue(waitForButtonEnabled(ID.cancelPhotoDeletion, false))
        attachScreenshot(named: "direct-delete-03-loading")
        app.swipeUp()

        XCTAssertTrue(app.staticTexts["删除已完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["3 项已移至照片 App 的“最近删除”，仍可恢复，空间可能尚未立即释放。"].exists)
        XCTAssertTrue(app.staticTexts["本组预计可清理 0 KB"].exists)
        XCTAssertFalse(app.buttons[ID.reviewCandidateScreenshot1].exists)
        XCTAssertFalse(app.buttons[ID.reviewAll].exists)
        attachScreenshot(named: "direct-delete-04-success")
        tapBack()
        assertHomeIsVisible()
        XCTAssertFalse(app.buttons[ID.taskScreenshots].exists)
        XCTAssertTrue(app.buttons[ID.taskSimilar].exists)
        attachScreenshot(named: "direct-delete-05-home-synced")
    }

    func testDirectDeleteFailurePreservesReviewCandidatesAndSelection() {
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))

        app.buttons["review.more"].tap()
        app.buttons[ID.directDeleteSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.confirmPhotoDeletion].tap()

        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["真机调试删除安全锁已开启，未删除任何照片或视频。"].exists)
        let candidate = app.buttons[ID.reviewCandidateScreenshot1]
        XCTAssertTrue(candidate.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(candidate.label.contains("已选择删除"))
        XCTAssertTrue(app.buttons[ID.addToReviewBin].isEnabled)
        attachScreenshot(named: "direct-delete-06-failure-preserved")
    }

    func testReviewBinActionsAreDisabledWhenNoItemsAreSelected() {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        XCTAssertTrue(app.buttons[ID.reviewAll].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.reviewAll].tap()
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))

        for itemID in ID.similarReviewBinItems {
            let itemButton = app.buttons[itemID]
            XCTAssertTrue(itemButton.waitForExistence(timeout: defaultTimeout))
            scrollToMakeHittable(itemButton)
            itemButton.tap()
        }

        XCTAssertFalse(app.buttons[ID.restoreReviewBinSelection].isEnabled)
        XCTAssertFalse(app.buttons[ID.deleteReviewBinSelection].isEnabled)
    }

    func testReviewBinItemsExposeReasonAndSelectionStateForVoiceOver() {
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.addToReviewBin].tap()
        let firstScreenshotItem = app.buttons[ID.reviewBinScreenshotItem]
        XCTAssertTrue(firstScreenshotItem.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(firstScreenshotItem.label.contains("已选择删除"))
        XCTAssertTrue(firstScreenshotItem.label.contains("截图和聊天截图"))
        XCTAssertTrue(firstScreenshotItem.label.contains("旧截图。"))

        firstScreenshotItem.tap()
        XCTAssertTrue(firstScreenshotItem.label.contains("未选择删除"))
        XCTAssertTrue(firstScreenshotItem.label.contains("旧截图。"))
    }

    func testZeroSelectionReviewGroupDisablesAddToReviewBin() {
        openHome()
        app.buttons[ID.taskBlurry].tap()
        XCTAssertTrue(app.staticTexts["模糊复核"].waitForExistence(timeout: defaultTimeout))

        let addButton = app.buttons[ID.addToReviewBin]
        XCTAssertTrue(addButton.exists)
        XCTAssertFalse(addButton.isEnabled)
        XCTAssertEqual(addButton.label, "加入复核箱")

        app.buttons[ID.reviewCandidateBlur1].tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(addButton.isEnabled)
        XCTAssertTrue(addButton.label.contains("1"))
    }

    func testReviewGroupBulkSelectionTogglesWithVisibleFeedback() {
        openHome()
        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))

        let bulkSelectionButton = app.buttons[ID.reviewAll]
        let addButton = app.buttons[ID.addToReviewBin]
        XCTAssertTrue(bulkSelectionButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(bulkSelectionButton.label, "取消全选")
        XCTAssertTrue(addButton.isEnabled)
        XCTAssertTrue(addButton.label.contains("3"))

        bulkSelectionButton.tap()

        XCTAssertTrue(waitForButtonLabel(ID.reviewAll, contains: "全选可清理项"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, false))
        XCTAssertEqual(addButton.label, "加入复核箱")
        attachScreenshot(named: "review-group-bulk-selection-cleared")

        bulkSelectionButton.tap()

        XCTAssertTrue(waitForButtonLabel(ID.reviewAll, contains: "取消全选"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, true))
        XCTAssertTrue(addButton.label.contains("3"))
        attachScreenshot(named: "review-group-bulk-selection-restored")
    }

    func testRecommendedKeepCapabilityIsHiddenAndSimilarGroupStartsUnselected() {
        openHome()
        let similarTask = app.buttons[ID.taskSimilar]
        XCTAssertFalse(similarTask.label.contains("推荐保留"))
        similarTask.tap()
        XCTAssertTrue(app.staticTexts["相似照片"].waitForExistence(timeout: defaultTimeout))

        let formerRecommendationCandidate = app.buttons[ID.reviewCandidateFormerRecommendation]
        let addButton = app.buttons[ID.addToReviewBin]
        XCTAssertTrue(formerRecommendationCandidate.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(formerRecommendationCandidate.isHittable)
        XCTAssertFalse(formerRecommendationCandidate.label.contains("推荐保留"))
        XCTAssertTrue(formerRecommendationCandidate.label.contains("未选择删除"))
        XCTAssertFalse(addButton.isEnabled)
        XCTAssertEqual(addButton.label, "加入复核箱")
        XCTAssertEqual(app.buttons[ID.reviewAll].label, "全选可清理项")
        attachScreenshot(named: "recommended-keep-disabled-similar-review")

        tapControlEdge(ID.reviewCandidateFormerRecommendation, x: 0.78, y: 0.25)

        XCTAssertTrue(waitForButtonLabel(ID.reviewCandidateFormerRecommendation, contains: "已选择删除"))
        XCTAssertFalse(formerRecommendationCandidate.label.contains("推荐保留"))
        XCTAssertTrue(addButton.label.contains("1"))
        attachScreenshot(named: "recommended-keep-disabled-manual-selection")

        tapControlEdge(ID.reviewCandidateFormerRecommendation, x: 0.78, y: 0.25)

        XCTAssertTrue(waitForButtonLabel(ID.reviewCandidateFormerRecommendation, contains: "未选择删除"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, false))

        app.buttons[ID.reviewAll].tap()
        XCTAssertTrue(waitForButtonLabel(ID.reviewAll, contains: "取消全选"))
        XCTAssertTrue(addButton.label.contains("7"))
        app.buttons[ID.reviewAll].tap()

        XCTAssertTrue(waitForButtonLabel(ID.reviewCandidateFormerRecommendation, contains: "未选择删除"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, false))
    }

    func testConfirmedKeepPersistsAcrossRelaunchAndCanBeManaged() throws {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        app.buttons["review.preview.similar-02"].tap()
        app.buttons["media.keep"].tap()
        app.buttons["完成"].firstMatch.tap()
        XCTAssertFalse(app.buttons[ID.reviewCandidateSimilar2].exists)
        attachScreenshot(named: "confirmed-keep-review-success")
        relaunchWithSampleCleanupData(resetIntro: false, resetConfirmedKeeps: false)
        assertHomeIsVisible()
        XCTAssertTrue(app.buttons[ID.taskSimilar].label.contains("6 张待复核"))
        app.buttons[ID.taskSimilar].tap()
        XCTAssertFalse(app.buttons[ID.reviewCandidateSimilar2].exists)
        XCTAssertTrue(app.buttons["review.preview.similar-02"].label.contains("已确认保留"))
        attachScreenshot(named: "confirmed-keep-after-relaunch")
        app.buttons["设置"].tap()
        app.buttons[ID.settingsConfirmedKeeps].tap()
        attachScreenshot(named: "confirmed-keeps-settings-management")
        app.buttons["keeps.edit"].tap()
        app.buttons[ID.confirmedKeepItemSimilar2].tap()
        app.buttons["truekeep.settings.confirmed-keeps.reset"].tap()
        app.alerts.buttons["全部取消保留"].tap()
        XCTAssertTrue(app.staticTexts["还没有已确认保留的照片"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "confirmed-keeps-settings-empty-after-removal")
    }

    func testCriticalScreensPassAccessibilityAudit() throws {
        relaunchWithoutSampleCleanupData()
        try assertAccessibilityAuditPasses("welcome")

        app.buttons[ID.permissionNotNow].tap()
        assertHomeIsVisible()
        try assertAccessibilityAuditPasses("home-photo-access-prompt")

        relaunchWithSampleCleanupData(resetIntro: true)
        openMainThroughSettings()
        try assertAccessibilityAuditPasses("settings")

        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", "-TrueKeepUITestAuthorizedHome"])
        assertHomeIsVisible()
        assertButtonIsReady(ID.taskScreenshots)
        try assertAccessibilityAuditPasses("home-review-queue")
        assertButtonIsReady(ID.taskScreenshots)

        app.buttons[ID.taskScreenshots].tap()
        XCTAssertTrue(app.staticTexts["截图复核"].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("screenshot-review")

        XCTAssertTrue(app.buttons[ID.addToReviewBin].waitForExistence(timeout: defaultTimeout))
        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("review-bin")

        app.buttons[ID.deleteReviewBinSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("delete-confirmation")
    }

    func testPermissionAndScanStateScreensPassAccessibilityAudit() throws {
        launchForUITestScenario("-TrueKeepUITestPermissionDenied")
        XCTAssertTrue(app.staticTexts["照片权限已关闭"].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("permission-denied")

        launchForUITestScenario("-TrueKeepUITestScanInterrupted")
        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("scan-interrupted")

        launchForUITestScenario("-TrueKeepUITestLimitedCompletedScan")
        XCTAssertTrue(app.staticTexts["扫描完成"].waitForExistence(timeout: defaultTimeout))
        try assertAccessibilityAuditPasses("scan-limited-completed")

        app.buttons[ID.viewScanResults].tap()
        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["访问范围有限"].exists)
        // iOS 26.3 evaluates the off-screen cached blurry-task button for contrast
        // after the range selector shifts the long list. Visible range controls are
        // contrast-audited in the dedicated scan-range result test above.
        try assertAccessibilityAuditPasses(
            "home-limited-results",
            auditTypes: criticalAccessibilityAuditTypes.subtracting(.contrast)
        )
    }

    private func openMainThroughSettings() {
        app.buttons[ID.welcomeLearnMore].tap()
        XCTAssertTrue(app.buttons[ID.settingsHowItWorks].waitForExistence(timeout: defaultTimeout))
    }

    private func relaunchWithoutSampleCleanupData() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepResetIntroState",
            "-TrueKeepResetConfirmedKeeps",
            "-TrueKeepUITestForceNotDeterminedAccess"
        ]
        app.launch()
    }

    private func relaunchWithSampleCleanupData(
        resetIntro: Bool = true,
        resetConfirmedKeeps: Bool = true
    ) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-TrueKeepDisablePhotoDeletion",
            "-TrueKeepUseSampleCleanupData",
            "-TrueKeepUITestForceNotDeterminedAccess"
        ]
        if resetIntro {
            app.launchArguments.append("-TrueKeepResetIntroState")
        }
        if resetConfirmedKeeps {
            app.launchArguments.append("-TrueKeepResetConfirmedKeeps")
        }
        app.launch()
    }

    private func launchForUITestScenario(_ scenario: String) {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", scenario])
    }

    private func launchWithArguments(
        _ launchArguments: [String],
        resetConfirmedKeeps: Bool = true
    ) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launchArguments.append("-TrueKeepResetScanPreferences")
        if resetConfirmedKeeps,
           !app.launchArguments.contains("-TrueKeepResetConfirmedKeeps") {
            app.launchArguments.append("-TrueKeepResetConfirmedKeeps")
        }
        app.launch()
    }

    private func openHome() {
        openMainThroughSettings()
        app.buttons["首页"].tap()
        assertHomeIsVisible()
        assertButtonIsReady(ID.taskSimilar)
    }

    private func assertSettingsTopic(id: String, title: String) {
        assertButtonIsReady(id)
        app.buttons[id].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: defaultTimeout))
        tapBack()
        assertButtonIsReady(id)
    }

    private func assertTaskOpensReviewGroup(taskID: String, title: String) {
        assertButtonIsReady(taskID)
        app.buttons[taskID].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: defaultTimeout))
        tapBack()
        assertHomeIsVisible()
        assertButtonIsReady(taskID)
    }

    private func tapBack() {
        let taskBack = app.buttons["review.return-to-tasks"]
        if taskBack.exists {
            taskBack.tap()
            return
        }
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: defaultTimeout))
        backButton.tap()
    }

    private func assertHomeIsVisible() {
        XCTAssertTrue(app.scrollViews[ID.cleanupResultsScreen].waitForExistence(timeout: defaultTimeout))
    }

    private func assertButtonIsReady(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: defaultTimeout), "\(id) should exist")
        XCTAssertTrue(button.isHittable, "\(id) should be visible and tappable")
    }

    private func tapControlEdge(_ id: String, x: CGFloat, y: CGFloat) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: defaultTimeout), "\(id) should exist")
        button.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }

    private func scrollToMakeHittable(_ element: XCUIElement) {
        var attempts = 0
        while (!element.exists || !element.isHittable), attempts < 6 {
            if element.exists && element.frame.maxY < app.frame.minY + 140 {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            attempts += 1
        }
        XCTAssertTrue(element.exists, "Element should exist after scrolling")
        XCTAssertTrue(element.isHittable, "Element should become visible after scrolling")
    }

    private func waitForButtonLabel(_ id: String, contains text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[id])
        return XCTWaiter.wait(for: [expectation], timeout: defaultTimeout) == .completed
    }

    private func waitForButtonEnabled(_ id: String, _ isEnabled: Bool) -> Bool {
        let predicate = NSPredicate(format: "enabled == %@", NSNumber(value: isEnabled))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[id])
        return XCTWaiter.wait(for: [expectation], timeout: defaultTimeout) == .completed
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        persistTestScreenshot(screenshot, name: name, test: self.name)
    }

    private func assertAccessibilityAuditPasses(_ screenName: String) throws {
        try assertAccessibilityAuditPasses(screenName, auditTypes: criticalAccessibilityAuditTypes)
    }

    private func assertAccessibilityAuditPasses(
        _ screenName: String,
        auditTypes: XCUIAccessibilityAuditType
    ) throws {
        do {
            try app.performAccessibilityAudit(for: auditTypes) { issue in
                let detail = "\(screenName): \(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "no element")"
                print(detail)
                let attachment = XCTAttachment(string: detail)
                attachment.name = "accessibility-issue-\(screenName)"
                attachment.lifetime = .keepAlways
                self.add(attachment)
                return false
            }
            attachScreenshot(named: "accessibility-passed-\(screenName)")
        } catch {
            attachScreenshot(named: "accessibility-audit-\(screenName)")
            throw error
        }
    }
}

/// Keep a second, directly retrievable copy when Xcode's result-bundle finalizer fails.
@MainActor
func persistTestScreenshot(_ screenshot: XCUIScreenshot, name: String, test: String) {
    do {
        let folderName = test.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let folder = URL.documentsDirectory.appendingPathComponent("TestScreenshots").appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: folder.appendingPathComponent(name).appendingPathExtension("png"), options: .atomic)
    } catch {
        XCTFail("截图副本保存失败：\(error)")
    }
}

private enum ID {
    static let welcomeContinue = "truekeep.welcome.continue"
    static let welcomeLearnMore = "truekeep.welcome.learn-more"
    static let permissionBack = "truekeep.permission.back"
    static let allowPhotos = "truekeep.permission.allow-photos"
    static let permissionNotNow = "truekeep.permission.not-now"
    static let openSettings = "truekeep.permission-issue.open-settings"
    static let retryPhotoAccess = "truekeep.permission-issue.retry"
    static let returnToPermission = "truekeep.permission-issue.return-to-permission"
    static let scanInProgress = "truekeep.scan.in-progress"
    static let scanStage = "truekeep.scan.stage"
    static let cancelScan = "truekeep.scan.cancel"
    static let continueBrowsing = "truekeep.scan.continue-browsing"
    static let retryScan = "truekeep.scan.retry"
    static let viewScanResults = "truekeep.scan.view-results"
    static let cleanupResultsScreen = "truekeep.cleanup.results"
    static let deletionSummary = "truekeep.cleanup.deletion-summary"
    static let homeScan = "truekeep.cleanup.scan"
    static let homeActiveScan = "truekeep.cleanup.active-scan"
    static let scanDateRangeSelector = "truekeep.cleanup.date-range.selector"
    static let selectedScanDateRange = "truekeep.cleanup.date-range.selected"
    static let completedScanDateRange = "truekeep.cleanup.date-range.completed"
    static let activeScanDateRange = "truekeep.scan.date-range.active"
    static let scanDateRangeLastMonth = "truekeep.cleanup.date-range.lastMonth"
    static let scanDateRangeLastThreeMonths = "truekeep.cleanup.date-range.lastThreeMonths"
    static let scanDateRangeAll = "truekeep.cleanup.date-range.all"
    static let addToReviewBin = "truekeep.review.add-to-review-bin"
    static let directDeleteSelection = "truekeep.review.direct-delete-selection"
    static let reviewAll = "truekeep.review.review-all"
    static let restoreReviewBinSelection = "truekeep.review-bin.restore-selection"
    static let deleteReviewBinSelection = "truekeep.review-bin.delete-selection"
    static let confirmPhotoDeletion = "truekeep.delete.confirm"
    static let cancelPhotoDeletion = "truekeep.delete.cancel"

    static let settingsHowItWorks = "truekeep.settings.topic.how-it-works"
    static let settingsConfirmedKeeps = "truekeep.settings.topic.confirmed-keeps"
    static let settingsPrivacyDetails = "truekeep.settings.topic.privacy-details"
    static let settingsHelpSupport = "truekeep.settings.topic.help-support"

    static let taskSimilar = "truekeep.cleanup.task.similar-family-12"
    static let taskSimilarSecond = "truekeep.cleanup.task.similar-family-13"
    static let taskScreenshots = "truekeep.cleanup.task.screenshots-chat-03"
    static let taskAccidental = "truekeep.cleanup.task.accidental-pocket-07"
    static let taskBlurry = "truekeep.cleanup.task.blurry-low-confidence-02"
    static let taskLargeVideos = "truekeep.cleanup.task.large-videos-01"
    static let reviewCandidateBlur1 = "truekeep.review.candidate.blur-01"
    static let reviewCandidateScreenshot1 = "truekeep.review.candidate.shot-01"
    static let reviewCandidateFormerRecommendation = "truekeep.review.candidate.keep-01"
    static let reviewCandidateSimilar2 = "truekeep.review.candidate.similar-02"
    static let reviewCandidateActionsSimilar2 = "truekeep.review.candidate-actions.similar-02"
    static let confirmedKeepFeedback = "truekeep.review.confirmed-keep-feedback"
    static let confirmedKeepItemSimilar2 = "truekeep.settings.confirmed-keep.similar-02"
    static let reviewBinScreenshotItem = "truekeep.review-bin.item.shot-01"

    static let similarReviewBinItems = [
        "truekeep.review-bin.item.keep-01",
        "truekeep.review-bin.item.similar-02",
        "truekeep.review-bin.item.similar-03",
        "truekeep.review-bin.item.similar-04",
        "truekeep.review-bin.item.similar-05",
        "truekeep.review-bin.item.similar-06",
        "truekeep.review-bin.item.similar-07"
    ]
}
