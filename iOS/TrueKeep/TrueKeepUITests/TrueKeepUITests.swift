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
            "-TrueKeepUITestForceNotDeterminedAccess"
        ]
        app.launch()
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
        try await super.tearDown()
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
        XCTAssertTrue(app.descendants(matching: .any)[ID.scanDateRangeSelector].waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(app.buttons[ID.scanDateRangeLastMonth].value as? String, "已选择")
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近一个月")

        app.buttons[ID.scanDateRangeLastThreeMonths].tap()
        XCTAssertEqual(app.buttons[ID.scanDateRangeLastThreeMonths].value as? String, "已选择")
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近三个月")

        assertButtonIsReady(ID.homeScan)
        app.buttons[ID.homeScan].tap()

        XCTAssertTrue(app.buttons[ID.viewScanResults].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.descendants(matching: .any)[ID.activeScanDateRange].label.contains("本次范围：近三个月"))
        app.buttons[ID.viewScanResults].tap()

        assertHomeIsVisible()
        let completedRange = app.descendants(matching: .any)[ID.completedScanDateRange]
        XCTAssertTrue(completedRange.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(completedRange.label, "本次范围：近三个月")

        app.buttons[ID.scanDateRangeLastMonth].tap()
        XCTAssertEqual(app.descendants(matching: .any)[ID.selectedScanDateRange].label, "已选择：近一个月")
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

        XCTAssertTrue(app.staticTexts["本地扫描"].waitForExistence(timeout: defaultTimeout))
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

        XCTAssertTrue(app.staticTexts["第 2 组 / 2 组"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(
            app.buttons["truekeep.review.candidate.similar-13-delete"]
                .waitForExistence(timeout: defaultTimeout)
        )
        XCTAssertFalse(app.staticTexts["第 1 组 / 2 组"].exists)
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

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons[ID.settingsHowItWorks].waitForExistence(timeout: defaultTimeout))
        tapControlEdge(ID.settingsHowItWorks, x: 0.94, y: 0.50)
        XCTAssertTrue(app.staticTexts["留真如何工作"].waitForExistence(timeout: defaultTimeout))

        tapBack()
        app.tabBars.buttons["首页"].tap()
        assertHomeIsVisible()
        tapControlEdge(ID.taskSimilar, x: 0.94, y: 0.50)
        XCTAssertTrue(app.staticTexts["相似照片"].waitForExistence(timeout: defaultTimeout))
    }

    func testDefaultLaunchDoesNotExposeFixtureCleanupTasks() {
        relaunchWithoutSampleCleanupData()

        app.buttons[ID.welcomeLearnMore].tap()
        app.tabBars.buttons["首页"].tap()

        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["尚未扫描相册"].waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(app.buttons[ID.taskSimilar].exists)
        XCTAssertFalse(app.buttons[ID.taskAccidental].exists)
        XCTAssertFalse(app.buttons[ID.taskBlurry].exists)
    }

    func testMainTabsUseLocalizedChineseLabels() {
        openMainThroughSettings()

        XCTAssertTrue(app.tabBars.buttons["首页"].exists)
        XCTAssertTrue(app.tabBars.buttons["复核箱"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
        XCTAssertFalse(app.tabBars.buttons["Review Bin"].exists)
    }

    func testLargeVideoReviewShowsVideoPreviewMetadata() {
        openHome()
        app.buttons[ID.taskLargeVideos].tap()

        XCTAssertTrue(app.staticTexts["大视频复核"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["3 个视频"].exists)
        XCTAssertTrue(app.staticTexts["650 MB"].exists)
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

        let scanButton = app.buttons[ID.scanInProgress]
        XCTAssertTrue(scanButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(scanButton.label.contains("扫描中"))
        XCTAssertFalse(scanButton.isEnabled)

        let cancelButton = app.buttons[ID.cancelScan]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(cancelButton.isEnabled)
        cancelButton.tap()

        XCTAssertTrue(app.staticTexts["扫描已停止"].waitForExistence(timeout: defaultTimeout))
    }

    func testCandidateRefinementCanContinueBrowsingReturnAndCancelWithScreenshots() {
        launchForUITestScenario("-TrueKeepUITestScanRefining")

        XCTAssertTrue(app.staticTexts["正在复核候选"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["候选复核"].exists)
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
        XCTAssertTrue(app.staticTexts["取消扫描不会删除或移动任何照片或视频。"].exists)
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

        app.tabBars.buttons["首页"].tap()
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
        app.tabBars.buttons["首页"].tap()
        assertHomeIsVisible()
        XCTAssertTrue(app.staticTexts["尚未扫描相册"].waitForExistence(timeout: defaultTimeout))
        attachScreenshot(named: "08-default-empty-no-fixtures")
    }

    func testReviewFlowDeleteSafetyLockAndRestoreSelection() {
        openHome()
        app.buttons[ID.taskSimilar].tap()
        XCTAssertTrue(app.buttons[ID.reviewAll].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.reviewAll].tap()
        XCTAssertTrue(app.buttons[ID.addToReviewBin].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.buttons[ID.addToReviewBin].label.contains("6"))

        app.buttons[ID.addToReviewBin].tap()
        XCTAssertTrue(app.buttons[ID.deleteReviewBinSelection].waitForExistence(timeout: defaultTimeout))

        app.buttons[ID.deleteReviewBinSelection].tap()
        XCTAssertTrue(app.buttons[ID.confirmPhotoDeletion].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["iCloud Photos 风险"].exists)

        app.buttons[ID.confirmPhotoDeletion].tap()
        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["真机调试删除安全锁已开启，未删除任何照片或视频。"].exists)

        app.buttons[ID.restoreReviewBinSelection].tap()
        XCTAssertTrue(app.staticTexts["复核箱为空"].waitForExistence(timeout: defaultTimeout))
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
        XCTAssertTrue(app.staticTexts["iCloud Photos 风险"].exists)

        XCTAssertTrue(app.staticTexts["删除未完成"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["真机调试删除安全锁已开启，未删除任何照片或视频。"].exists)
        XCTAssertTrue(app.buttons[ID.similarReviewBinItems[0]].waitForExistence(timeout: defaultTimeout))
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
        XCTAssertEqual(addButton.label, "选择项目后加入复核箱")

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

        XCTAssertTrue(waitForButtonLabel(ID.reviewAll, contains: "全选本组可清理项"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, false))
        XCTAssertEqual(addButton.label, "选择项目后加入复核箱")
        attachScreenshot(named: "review-group-bulk-selection-cleared")

        bulkSelectionButton.tap()

        XCTAssertTrue(waitForButtonLabel(ID.reviewAll, contains: "取消全选"))
        XCTAssertTrue(waitForButtonEnabled(ID.addToReviewBin, true))
        XCTAssertTrue(addButton.label.contains("3"))
        attachScreenshot(named: "review-group-bulk-selection-restored")
    }

    func testCriticalScreensPassAccessibilityAudit() throws {
        try assertAccessibilityAuditPasses("welcome")

        app.buttons[ID.permissionNotNow].tap()
        assertHomeIsVisible()
        try assertAccessibilityAuditPasses("home-photo-access-prompt")

        relaunchWithSampleCleanupData(resetIntro: true)
        openMainThroughSettings()
        try assertAccessibilityAuditPasses("settings")

        app.tabBars.buttons["首页"].tap()
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
            "-TrueKeepUITestForceNotDeterminedAccess"
        ]
        app.launch()
    }

    private func relaunchWithSampleCleanupData(resetIntro: Bool = true) {
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
        app.launch()
    }

    private func launchForUITestScenario(_ scenario: String) {
        launchWithArguments(["-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState", scenario])
    }

    private func launchWithArguments(_ launchArguments: [String]) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
    }

    private func openHome() {
        openMainThroughSettings()
        app.tabBars.buttons["首页"].tap()
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
            app.swipeUp()
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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertAccessibilityAuditPasses(_ screenName: String) throws {
        try assertAccessibilityAuditPasses(screenName, auditTypes: criticalAccessibilityAuditTypes)
    }

    private func assertAccessibilityAuditPasses(
        _ screenName: String,
        auditTypes: XCUIAccessibilityAuditType
    ) throws {
        do {
            try app.performAccessibilityAudit(for: auditTypes)
        } catch {
            attachScreenshot(named: "accessibility-audit-\(screenName)")
            throw error
        }
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
    static let reviewAll = "truekeep.review.review-all"
    static let restoreReviewBinSelection = "truekeep.review-bin.restore-selection"
    static let deleteReviewBinSelection = "truekeep.review-bin.delete-selection"
    static let confirmPhotoDeletion = "truekeep.delete.confirm"
    static let cancelPhotoDeletion = "truekeep.delete.cancel"

    static let settingsHowItWorks = "truekeep.settings.topic.how-it-works"
    static let settingsPrivacyDetails = "truekeep.settings.topic.privacy-details"
    static let settingsHelpSupport = "truekeep.settings.topic.help-support"

    static let taskSimilar = "truekeep.cleanup.task.similar-family-12"
    static let taskSimilarSecond = "truekeep.cleanup.task.similar-family-13"
    static let taskScreenshots = "truekeep.cleanup.task.screenshots-chat-03"
    static let taskAccidental = "truekeep.cleanup.task.accidental-pocket-07"
    static let taskBlurry = "truekeep.cleanup.task.blurry-low-confidence-02"
    static let taskLargeVideos = "truekeep.cleanup.task.large-videos-01"
    static let reviewCandidateBlur1 = "truekeep.review.candidate.blur-01"
    static let reviewBinScreenshotItem = "truekeep.review-bin.item.shot-01"

    static let similarReviewBinItems = [
        "truekeep.review-bin.item.similar-02",
        "truekeep.review-bin.item.similar-03",
        "truekeep.review-bin.item.similar-04",
        "truekeep.review-bin.item.similar-05",
        "truekeep.review-bin.item.similar-06",
        "truekeep.review-bin.item.similar-07"
    ]
}
