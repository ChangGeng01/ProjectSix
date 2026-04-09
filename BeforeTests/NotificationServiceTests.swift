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
}
