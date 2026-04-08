import XCTest
@testable import Before

final class WidgetSafeCopyTests: XCTestCase {
    func testWidgetSafeCopyReturnsGenericMessageWithoutContext() {
        let message = WidgetSafeCopy.message(for: nil, verdict: nil)

        XCTAssertEqual(message, .generic)
    }

    func testLegacyWidgetSnapshotStillDecodesAndFallsBackToSafeCopy() throws {
        let legacyData = """
        {
          "latestReminder": "I am not actually hungry, I am just upset.",
          "latestVerdict": "pause",
          "latestScenario": "eat",
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: legacyData)

        XCTAssertNil(snapshot.safeMessage)
        XCTAssertEqual(snapshot.messageBody, WidgetSafeMessage.generic.body)
    }
}
