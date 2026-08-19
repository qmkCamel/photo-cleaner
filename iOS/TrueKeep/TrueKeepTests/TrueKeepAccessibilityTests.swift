import XCTest
@testable import TrueKeep

final class TrueKeepAccessibilityTests: XCTestCase {
    func testPrimaryControlIdentifiersAreUniqueAndAutomationSafe() {
        let identifiers = TrueKeepAccessibility.Control.allCases.map(\.id)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(identifiers.allSatisfy { !$0.contains(" ") })
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("truekeep.") })
    }

    func testPrimaryControlIdentifiersCoverCriticalFlowActions() {
        let controls = Set(TrueKeepAccessibility.Control.allCases)

        XCTAssertTrue(controls.contains(.allowPhotos))
        XCTAssertTrue(controls.contains(.scanInProgress))
        XCTAssertTrue(controls.contains(.cancelScan))
        XCTAssertTrue(controls.contains(.viewScanResults))
        XCTAssertTrue(controls.contains(.homeScan))
        XCTAssertTrue(controls.contains(.deletionSummary))
        XCTAssertTrue(controls.contains(.addToReviewBin))
        XCTAssertTrue(controls.contains(.deleteReviewBinSelection))
        XCTAssertTrue(controls.contains(.confirmPhotoDeletion))
        XCTAssertTrue(controls.contains(.privacySafetyTab))
    }

    func testDynamicIdentifiersRemainStableForAutomation() {
        XCTAssertEqual(
            TrueKeepAccessibility.cleanupTask(id: "screenshots-chat-03"),
            "truekeep.cleanup.task.screenshots-chat-03"
        )
        XCTAssertEqual(
            TrueKeepAccessibility.reviewCandidate(id: "asset-1"),
            "truekeep.review.candidate.asset-1"
        )
        XCTAssertEqual(
            TrueKeepAccessibility.reviewBinItem(id: "asset-1"),
            "truekeep.review-bin.item.asset-1"
        )
    }

    func testAppSourcesDoNotUseFixedSizeTextFonts() throws {
        let appSourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TrueKeep")
        let swiftFiles = FileManager.default
            .enumerator(at: appSourceRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        let fixedFontUsages = try swiftFiles.flatMap { fileURL in
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            return source
                .components(separatedBy: .newlines)
                .enumerated()
                .compactMap { lineNumber, line -> String? in
                    guard line.contains(".font(.system(size:") else { return nil }
                    let relativePath = fileURL.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")
                    return "\(relativePath):\(lineNumber + 1): \(line.trimmingCharacters(in: .whitespaces))"
                }
        }

        XCTAssertTrue(
            fixedFontUsages.isEmpty,
            "Use TrueKeepTheme.Font dynamic text styles instead of fixed .system(size:) fonts:\n\(fixedFontUsages.joined(separator: "\n"))"
        )
    }
}
