import XCTest
@testable import Before

final class NotificationServiceTests: XCTestCase {
    func testTomorrowReminderDateAlwaysMovesToNextDayMorning() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 22, minute: 30))!

        let nextDate = NotificationService.nextTomorrowReminderDate(after: baseDate, calendar: calendar)

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, BeforePolicy.Notifications.tomorrowReminderHour)
        XCTAssertEqual(components.minute, BeforePolicy.Notifications.tomorrowReminderMinute)
    }

    func testTomorrowReminderDateFromMorningStillMovesToFollowingDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 9, minute: 1))!

        let nextDate = NotificationService.nextTomorrowReminderDate(after: baseDate, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, BeforePolicy.Notifications.tomorrowReminderHour)
        XCTAssertEqual(components.minute, BeforePolicy.Notifications.tomorrowReminderMinute)
        XCTAssertGreaterThan(nextDate, baseDate)
    }

    func testPredictiveNotificationIdentifierIsStableAndLowercased() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        let identifier = BeforeNotificationIdentifier.predictiveIntervention(for: id)

        XCTAssertEqual(identifier, "before.predictive.intervention.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertEqual(identifier, identifier.lowercased())
    }

    func testPredictiveNotificationPresentationUsesCandidateCopyAndFutureDelay() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let now = Date(timeIntervalSince1970: 100)
        let candidate = InterventionPredictionCandidate(
            id: id,
            riskLevel: .medium,
            title: "  Use the candidate headline.  ",
            detail: "Use the candidate detail.",
            reason: "candidate reason",
            createdAt: now,
            expiresAt: now.addingTimeInterval(300)
        )

        let presentation = BeforePredictiveInterventionNotificationPresentationSupport.presentation(
            for: candidate,
            now: now
        )

        XCTAssertEqual(
            presentation.identifier,
            "before.predictive.intervention.11111111-2222-3333-4444-555555555555"
        )
        XCTAssertEqual(presentation.title, "Use the candidate headline.")
        XCTAssertEqual(presentation.body, "Use the candidate detail.")
        XCTAssertEqual(presentation.timeInterval, 90)
    }

    func testPredictiveNotificationPresentationFallsBackToSharedRiskCopyWhenCandidateCopyIsBlank() {
        let now = Date(timeIntervalSince1970: 200)
        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "   ",
            detail: "\n",
            reason: "candidate reason",
            createdAt: now,
            expiresAt: now.addingTimeInterval(-10)
        )

        let presentation = BeforePredictiveInterventionNotificationPresentationSupport.presentation(
            for: candidate,
            now: now
        )

        XCTAssertEqual(
            presentation.title,
            BeforeProductCompatibility.predictiveInterventionPresentation.highRiskTitle
        )
        XCTAssertEqual(
            presentation.body,
            BeforeProductCompatibility.predictiveInterventionPresentation.highRiskDetail
        )
        XCTAssertEqual(presentation.timeInterval, 60)
    }
}
