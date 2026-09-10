import XCTest
@testable import Before

final class TomorrowBoxDelayTests: XCTestCase {
    func testOneDayDelayMovesToNextMorningWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let delayed = TomorrowBoxDelay.oneDay.reschedule(from: base, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: delayed)

        XCTAssertEqual(components.hour, BeforePolicy.Notifications.tomorrowReminderHour)
        XCTAssertEqual(components.minute, BeforePolicy.Notifications.tomorrowReminderMinute)
    }

    func testLongerDelayStaysLaterThanShorterDelay() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let oneDay = TomorrowBoxDelay.oneDay.reschedule(from: base)
        let oneWeek = TomorrowBoxDelay.oneWeek.reschedule(from: base)

        XCTAssertGreaterThan(oneWeek, oneDay)
    }
}
