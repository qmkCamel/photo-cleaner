import LocalPhotoModels
import XCTest
@testable import TrueKeep

@MainActor
final class LocalPhotoModelControllerTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "LocalModelTests-\(UUID().uuidString)")!
    }

    func testDefaultIsDisabledAndModelSelectionPersists() {
        let settings = defaults()
        let controller = LocalPhotoModelController(defaults: settings, arguments: [])
        XCTAssertFalse(controller.isEnabled)
        controller.select(.gemma)
        controller.setEnabled(true)
        let restored = LocalPhotoModelController(defaults: settings, arguments: [])
        XCTAssertEqual(restored.selectedModel, .gemma)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertFalse(restored.isFixture)
    }

    func testFixtureRequiresDeletionSafetyFlag() {
        let controller = LocalPhotoModelController(defaults: defaults(), arguments: ["-TrueKeepUITestLocalModels"])
        XCTAssertFalse(controller.isFixture)
    }

    func testMissingModelFailsWithoutStartingTask() {
        let controller = LocalPhotoModelController(defaults: defaults(), arguments: [])
        controller.setEnabled(true)
        controller.analyze(groupID: "g", assetIDs: ["photo"])
        XCTAssertFalse(controller.isBusy)
        XCTAssertNotNil(controller.errorMessage)
    }

    func testAnalysisFailurePreservesReportAndSwitchClearsIt() async throws {
        let controller = LocalPhotoModelController(
            files: TestFiles(), analyzer: TestAnalyzer(), defaults: defaults(),
            arguments: ["-TrueKeepUITestLocalModels", "-TrueKeepDisablePhotoDeletion"]
        )
        await controller.refresh()
        controller.analyze(groupID: "g", assetIDs: ["one"])
        try await waitUntilIdle(controller)
        XCTAssertEqual(controller.report?.photos.first?.id, "one")
        controller.analyze(groupID: "g", assetIDs: ["one"])
        try await waitUntilIdle(controller)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertEqual(controller.report?.photos.first?.id, "one")
        controller.select(.gemma)
        XCTAssertNil(controller.report)
        XCTAssertNil(controller.errorMessage)
    }

    func testCancellationBlocksStaleResultsAndDuplicateSubmission() async throws {
        let analyzer = TestAnalyzer(delay: .milliseconds(100))
        let controller = LocalPhotoModelController(
            files: TestFiles(), analyzer: analyzer, defaults: defaults(),
            arguments: ["-TrueKeepUITestLocalModels", "-TrueKeepDisablePhotoDeletion"]
        )
        await controller.refresh()
        controller.analyze(groupID: "old", assetIDs: ["one"])
        controller.analyze(groupID: "duplicate", assetIDs: ["two"])
        controller.select(.gemma)
        XCTAssertEqual(controller.selectedModel, .qwen)
        controller.invalidateAnalysis()
        try await waitUntilIdle(controller)
        XCTAssertNil(controller.report)
        XCTAssertNil(controller.errorMessage)
        let calls = await analyzer.calls
        XCTAssertLessThanOrEqual(calls, 1)
        controller.setEnabled(false)
        controller.analyze(groupID: "disabled", assetIDs: ["one"])
        XCTAssertFalse(controller.isBusy)
    }

    private func waitUntilIdle(_ controller: LocalPhotoModelController) async throws {
        for _ in 0..<100 {
            if !controller.isBusy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Model action did not settle")
    }
}

private actor TestFiles: ModelFileInstalling {
    func installedModels() -> Set<LocalPhotoModel> { Set(LocalPhotoModel.allCases) }
    func directory(for model: LocalPhotoModel) -> URL { URL(fileURLWithPath: "/test") }
    func install(_ model: LocalPhotoModel, progress: @escaping PhotoModelProgressHandler) {}
    func remove(_ model: LocalPhotoModel) {}
}

private actor TestAnalyzer: PhotoSemanticAnalyzing {
    private(set) var calls = 0
    let delay: Duration
    init(delay: Duration = .milliseconds(1)) { self.delay = delay }
    func analyze(
        photos: [SemanticPhoto], model: LocalPhotoModel, directory: URL, progress: @escaping PhotoModelProgressHandler
    ) async throws -> PhotoSemanticReport {
        calls += 1
        try await Task.sleep(for: delay)
        if calls == 2 { throw PhotoModelError.invalidOutput }
        return .init(model: model, photos: photos.map {
            .init(id: $0.id, observation: .init(subject: "fixture", observations: [], uncertain: true))
        }, completedAt: Date(), elapsedSeconds: 0.1)
    }
}
