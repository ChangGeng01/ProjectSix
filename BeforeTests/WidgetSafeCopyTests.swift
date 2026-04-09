import XCTest
@testable import Before

final class WidgetSafeCopyTests: XCTestCase {
    func testWidgetSafeCopyReturnsGenericMessageWithoutContext() {
        let message = WidgetSafeCopy.message(for: nil, verdict: nil)

        XCTAssertEqual(message, .generic)
    }

    func testKnownWidgetSafeMessagesStayShortAndContextFree() {
        let cases: [(ScenarioType?, CheckVerdict?)] = [
            (.buy, .pause),
            (.buy, .notRecommended),
            (.eat, .pause),
            (.scroll, .notRecommended),
            (.other, .goAhead),
            (nil, nil)
        ]

        for input in cases {
            let message = WidgetSafeCopy.message(for: input.0, verdict: input.1)

            XCTAssertEqual(message.surface, .publicSafe)
            XCTAssertFalse(message.headline.isEmpty)
            XCTAssertLessThanOrEqual(message.headline.count, 24)
            XCTAssertFalse(message.body.isEmpty)
            XCTAssertLessThanOrEqual(message.body.count, 80)
            XCTAssertFalse(message.body.lowercased().contains("reminder"))
            XCTAssertFalse(message.body.lowercased().contains("upset"))
        }
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
        XCTAssertEqual(snapshot.messageHeadline, WidgetSafeMessage.generic.headline)
        XCTAssertEqual(snapshot.messageBody, WidgetSafeMessage.generic.body)
    }

    func testLegacyReminderPayloadDoesNotOverrideSafeWidgetCopy() throws {
        let legacyData = """
        {
          "safeMessage": {
            "body": "A safe widget line."
          },
          "latestReminder": "My private reminder should never appear here.",
          "latestVerdict": "pause",
          "latestScenario": "buy",
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: legacyData)

        XCTAssertEqual(snapshot.messageBody, "A safe widget line.")
        XCTAssertFalse(snapshot.messageBody.contains("private reminder"))
    }

    func testLegacySafeMessageWithoutSurfaceOrHeadlineStillDecodesAsPublicSafe() throws {
        let legacyData = """
        {
          "safeMessage": {
            "body": "A safe widget line."
          },
          "latestVerdict": "pause",
          "latestScenario": "buy",
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: legacyData)

        XCTAssertEqual(snapshot.messageSurface, .publicSafe)
        XCTAssertEqual(snapshot.messageHeadline, WidgetSafeMessage.generic.headline)
        XCTAssertEqual(snapshot.messageBody, "A safe widget line.")
    }
}
