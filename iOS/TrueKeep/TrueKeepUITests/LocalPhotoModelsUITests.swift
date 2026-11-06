import XCTest

@MainActor
final class LocalPhotoModelsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-TrueKeepDisablePhotoDeletion", "-TrueKeepUseSampleCleanupData", "-TrueKeepResetIntroState",
            "-TrueKeepResetConfirmedKeeps", "-TrueKeepUITestAuthorizedHome", "-TrueKeepUITestLocalModels"
        ]
        app.launch()
        app.buttons["设置"].tap()
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testAnalysisProgressSelectionContinuitySuccessAndFailure() {
        app.buttons["首页"].tap()
        app.buttons["truekeep.cleanup.task.screenshots-chat-03"].tap()
        let analyze = app.buttons["truekeep.models.analyze"]
        reveal(analyze, aboveReviewFooter: true)
        analyze.tap()
        XCTAssertTrue(app.buttons["truekeep.models.cancel"].waitForExistence(timeout: 5))
        let selection = app.buttons["truekeep.review.review-all"]
        XCTAssertTrue(selection.isEnabled)
        selection.tap()
        XCTAssertEqual(selection.label, "全选可清理项")
        capture("local-model-01-running-selection-responsive")
        let result = app.descendants(matching: .any)["truekeep.models.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        reveal(result)
        capture("local-model-02-success-fixture")
        XCTAssertEqual(selection.label, "全选可清理项")
        reveal(analyze, aboveReviewFooter: true)
        analyze.tap()
        XCTAssertTrue(app.staticTexts["truekeep.models.analysis-error"].waitForExistence(timeout: 15))
        XCTAssertTrue(result.exists)
        reveal(app.staticTexts["truekeep.models.analysis-error"])
        capture("local-model-03-failure-retains-result")
    }

    func testModelSwitchRemovalDownloadCancellationAndNavigation() {
        let settings = app.buttons["truekeep.settings.local-models"]
        reveal(settings)
        settings.tap()
        let picker = app.buttons["truekeep.models.picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Gemma 4 E2B"].tap()
        capture("local-model-04-gemma-settings")
        let remove = app.buttons["truekeep.models.remove"]
        reveal(remove)
        remove.tap()
        app.alerts.buttons["移除"].tap()
        let download = app.buttons["truekeep.models.download"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        app.alerts.buttons["下载"].tap()
        XCTAssertTrue(app.buttons["truekeep.models.cancel"].waitForExistence(timeout: 5))
        app.buttons["truekeep.models.cancel"].tap()
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        app.alerts.buttons["下载"].tap()
        app.buttons["首页"].tap()
        XCTAssertTrue(app.buttons["truekeep.cleanup.task.screenshots-chat-03"].waitForExistence(timeout: 5))
        app.buttons["设置"].tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 8))
        capture("local-model-05-download-complete-fixture")
    }

    func testCancelAnalysisAndChangingGroupDiscardPendingResult() {
        app.buttons["首页"].tap()
        app.buttons["truekeep.cleanup.task.screenshots-chat-03"].tap()
        let analyze = app.buttons["truekeep.models.analyze"]
        reveal(analyze, aboveReviewFooter: true)
        analyze.tap()
        let cancel = app.buttons["truekeep.models.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(analyze.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["truekeep.models.result"].exists)
        capture("local-model-06-analysis-cancelled")
        analyze.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let next = app.buttons["truekeep.review.next-group"]
        let positionBefore = app.staticTexts["review.group-position"].label
        for _ in 0..<6 {
            let overlappedByNavigation = app.navigationBars.allElementsBoundByIndex.contains { $0.frame.intersects(next.frame) }
            if next.isHittable && next.frame.minY > app.frame.minY && !overlappedByNavigation { break }
            app.swipeDown()
        }
        capture("local-model-group-navigation-before-tap")
        next.tap()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.staticTexts["review.group-position"].label != positionBefore
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed, "必须实际进入下一组，不能仅凭 tap 返回认为已导航")
        XCTAssertTrue(analyze.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["truekeep.models.result"].exists)
        XCTAssertFalse(app.staticTexts["truekeep.models.analysis-error"].exists)
        capture("local-model-07-group-change-discards-pending")
    }

    func testModelSettingsSupportsAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["设置"].tap()
        let settings = app.buttons["truekeep.settings.local-models"]
        reveal(settings)
        settings.tap()
        let picker = app.buttons["truekeep.models.picker"]
        reveal(picker)
        capture("local-model-08-accessibility-settings")
        let remove = app.buttons["truekeep.models.remove"]
        reveal(remove)
        XCTAssertGreaterThanOrEqual(remove.frame.height, 44)
        capture("local-model-09-accessibility-actions")
    }

    private func reveal(_ element: XCUIElement, aboveReviewFooter: Bool = false) {
        for _ in 0..<6 {
            if element.exists && element.isHittable && (!aboveReviewFooter || element.frame.midY < app.frame.height - 280) { return }
            if element.exists && element.frame.maxY < 140 { app.swipeDown(velocity: .slow) }
            else { app.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        persistTestScreenshot(screenshot, name: name, test: self.name)
    }
}
