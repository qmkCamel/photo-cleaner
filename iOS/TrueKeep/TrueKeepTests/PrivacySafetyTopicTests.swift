import XCTest
@testable import TrueKeep

final class PrivacySafetyTopicTests: XCTestCase {
    func testSettingsTopicsHaveTappableDestinations() {
        let topics = PrivacySafetyTopic.allCases

        XCTAssertEqual(topics.map(\.title), ["已确认保留", "留真如何工作", "数据与隐私细节", "帮助与支持"])
        XCTAssertTrue(topics.allSatisfy { !$0.detailTitle.isEmpty })
        XCTAssertTrue(topics.allSatisfy { !$0.detailBody.isEmpty })
    }

    func testSettingsTopicsHaveStableAccessibilityIdentifiers() {
        XCTAssertEqual(
            PrivacySafetyTopic.confirmedKeeps.accessibilityIdentifier,
            "truekeep.settings.topic.confirmed-keeps"
        )
        XCTAssertEqual(
            PrivacySafetyTopic.howItWorks.accessibilityIdentifier,
            "truekeep.settings.topic.how-it-works"
        )
        XCTAssertEqual(
            PrivacySafetyTopic.privacyDetails.accessibilityIdentifier,
            "truekeep.settings.topic.privacy-details"
        )
        XCTAssertEqual(
            PrivacySafetyTopic.helpSupport.accessibilityIdentifier,
            "truekeep.settings.topic.help-support"
        )
    }
}
