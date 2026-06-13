import XCTest
@testable import TrueKeep

final class PublicScanCapabilityCopyTests: XCTestCase {
    func testPhotoPermissionCopyClaimsOnlyOnDeviceReviewCandidatesWithSafetyLimits() throws {
        let usageDescription = try loadAppInfoPlist()["NSPhotoLibraryUsageDescription"] as? String

        XCTAssertEqual(usageDescription, SupportedScanCopy.photoLibraryUsageDescription)
        assertDescribesOnDeviceReviewCandidatesSafely(usageDescription)
        assertDescribesOnDeviceReviewCandidatesSafely(SupportedScanCopy.permissionSafetyMessage)
        assertDescribesOnDeviceReviewCandidatesSafely(PhotoLibraryAccess.notDetermined.displayMessage)
    }

    private func assertDescribesOnDeviceReviewCandidatesSafely(
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
                "Public scan copy should describe local review candidates: \(requiredTerm)",
                file: file,
                line: line
            )
        }

        for overclaim in ["自动删除", "无需确认", "上传你的照片"] {
            XCTAssertFalse(
                copy.contains(overclaim),
                "Public scan copy must not overclaim safety: \(overclaim)",
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
                domain: "PublicScanCapabilityCopyTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist is not a dictionary plist."]
            )
        }
        return dictionary
    }
}
