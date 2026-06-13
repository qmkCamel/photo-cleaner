import XCTest

@MainActor
final class PrivacyManifestTests: XCTestCase {
    func testPrivacyManifestDeclaresNoCollectionOrTracking() throws {
        let manifest = try loadPrivacyManifest()

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(manifest["NSPrivacyTrackingDomains"] as? [String], [])
        XCTAssertEqual(manifest["NSPrivacyCollectedDataTypes"] as? [[String: AnyHashable]], [])
        XCTAssertEqual(manifest["NSPrivacyAccessedAPITypes"] as? [[String: AnyHashable]], [])
    }

    private func loadPrivacyManifest() throws -> [String: Any] {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectDirectory = testsDirectory.deletingLastPathComponent()
        let manifestURL = projectDirectory
            .appendingPathComponent("TrueKeep")
            .appendingPathComponent("Resources")
            .appendingPathComponent("PrivacyInfo.xcprivacy")

        let data = try Data(contentsOf: manifestURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw NSError(
                domain: "PrivacyManifestTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "PrivacyInfo.xcprivacy is not a dictionary plist."]
            )
        }
        return dictionary
    }
}
