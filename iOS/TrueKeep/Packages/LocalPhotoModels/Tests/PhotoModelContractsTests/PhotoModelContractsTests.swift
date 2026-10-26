import CryptoKit
import Foundation
import XCTest
@testable import PhotoModelContracts

final class PhotoModelContractsTests: XCTestCase {
    func testPackagePrivacyManifestCoversLocalStorageChecks() throws {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/PhotoModelContracts/PrivacyInfo.xcprivacy")
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: source), format: nil)
        let manifest = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        let entries = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let reasons = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (String, [String])? in
            guard let type = entry["NSPrivacyAccessedAPIType"] as? String,
                  let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] else { return nil }
            return (type, reasons)
        })
        XCTAssertEqual(reasons["NSPrivacyAccessedAPICategoryDiskSpace"], ["E174.1"])
        XCTAssertEqual(reasons["NSPrivacyAccessedAPICategoryFileTimestamp"], ["C617.1"])
    }

    func testModelCatalogPinsVersionsAndWeights() {
        XCTAssertEqual(LocalPhotoModel.allCases.count, 2)
        for model in LocalPhotoModel.allCases {
            XCTAssertEqual(model.revision.count, 40)
            XCTAssertEqual(Set(model.files.map(\.name)).count, model.files.count)
            XCTAssertTrue(model.files.allSatisfy { !$0.name.contains("/") && $0.bytes > 0 })
            XCTAssertNotNil(model.files.first { $0.name == "model.safetensors" }?.sha256)
            XCTAssertTrue(model.sourceURL.absoluteString.contains(model.revision))
            XCTAssertEqual(model.sourceURL.scheme, "https")
        }
        XCTAssertLessThan(LocalPhotoModel.qwen.downloadBytes, 700_000_000)
        XCTAssertGreaterThan(LocalPhotoModel.gemma.downloadBytes, 3_500_000_000)
    }

    func testDecodesStructuredObservation() throws {
        let result = try PhotoObservation.decode(#"{"subject":"票据","observations":["可见印刷文字"],"uncertain":false}"#)
        XCTAssertEqual(result.subject, "票据")
        XCTAssertFalse(result.uncertain)
    }

    func testAllowsExplicitAbstentionAndOneJSONFence() throws {
        let result = try PhotoObservation.decode("```json\n" + #"{"subject":"不明确","observations":[],"uncertain":true}"# + "\n```")
        XCTAssertTrue(result.uncertain)
    }

    func testSmallModelCaptionIsAlwaysUncertainAndNeverRepairsJSON() throws {
        let observation = try PhotoObservation.unverifiedCaption("  一个盾形图标，内部有相机光圈。\n")
        XCTAssertTrue(observation.uncertain)
        XCTAssertTrue(observation.observations.isEmpty)
        XCTAssertEqual(observation.subject, "一个盾形图标，内部有相机光圈。")
        for text in ["", "{\"subject\":\"x\"}", "[\"x\"]", "first\nsecond", "```json\nx", "<think>x</think>", String(repeating: "x", count: 161)] {
            XCTAssertThrowsError(try PhotoObservation.unverifiedCaption(text))
        }
    }

    func testRejectsMalformedOutputAndDeletionInstructions() {
        for text in [
            "delete all", "prefix {\"subject\":\"x\"}",
            #"{"subject":"x","observations":[],"uncertain":false}"#,
            #"{"subject":"x","observations":["a"],"uncertain":false,"delete":true}"#,
            #"{"subject":"","observations":["a"],"uncertain":true}"#,
            #"{"subject":"x","observations":["a","b","c","d","e"],"uncertain":true}"#
        ] { XCTAssertThrowsError(try PhotoObservation.decode(text), text) }
    }

    func testVerifiesSizeAndSHA256() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("abc".utf8)
        try bytes.write(to: url)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        XCTAssertNoThrow(try ModelFileStore.verify(url, file: .init("model.safetensors", 3, hash)))
        XCTAssertThrowsError(try ModelFileStore.verify(url, file: .init("model.safetensors", 4, hash)))
        XCTAssertThrowsError(try ModelFileStore.verify(url, file: .init("model.safetensors", 3, String(repeating: "0", count: 64))))
    }

    func testIncompleteInstallationIsNotReadyAndRemovalIsScoped() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let partial = root.appendingPathComponent(LocalPhotoModel.qwen.id).appendingPathComponent(LocalPhotoModel.qwen.revision)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try JSONEncoder().encode(LocalPhotoModel.qwen.files).write(to: partial.appendingPathComponent("installed.json"))
        let unrelated = root.appendingPathComponent("unrelated.txt")
        try Data("preserve".utf8).write(to: unrelated)
        let store = ModelFileStore(root: root)
        let installed = await store.installedModels()
        XCTAssertTrue(installed.isEmpty)
        do { _ = try await store.directory(for: .qwen); XCTFail("Incomplete model became ready") }
        catch { XCTAssertTrue(error is PhotoModelError) }
        try await store.remove(.qwen)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testCancelledInstallDoesNotPublishModel() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ModelFileStore(root: root)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await store.install(.qwen) { _ in }
        }
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let installed = await store.installedModels()
        XCTAssertTrue(installed.isEmpty)
        let paths = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(paths.contains { $0.hasPrefix("staging-") })
    }

    func testNetworkFailureCleansStagingAndRetryPreservesOtherModel() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = root.appendingPathComponent(LocalPhotoModel.qwen.id).appendingPathComponent(LocalPhotoModel.qwen.revision)
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        // Sparse fixtures exercise the readiness marker without downloading or allocating real weights.
        for file in LocalPhotoModel.qwen.files {
            let url = installed.appendingPathComponent(file.name)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: UInt64(file.bytes))
            try handle.close()
        }
        try JSONEncoder().encode(LocalPhotoModel.qwen.files).write(to: installed.appendingPathComponent("installed.json"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineModelProtocol.self]
        let store = ModelFileStore(root: root, session: URLSession(configuration: configuration))
        for _ in 0..<2 {
            do { try await store.install(.gemma) { _ in }; XCTFail("Expected offline failure") }
            catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
            let models = await store.installedModels()
            XCTAssertEqual(models, [.qwen])
            let paths = try FileManager.default.contentsOfDirectory(atPath: root.path)
            XCTAssertFalse(paths.contains { $0.hasPrefix("staging-") })
        }
    }
}

private final class OfflineModelProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
