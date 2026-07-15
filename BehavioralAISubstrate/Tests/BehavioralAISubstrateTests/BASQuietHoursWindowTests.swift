import XCTest
@testable import BASPolicy

/// audit policy-obs-misc MED-4 — the quiet-hours window formula handled only
/// cross-midnight; a same-day window silenced nearly all hours, and start==end
/// silenced a full 24h. All three cases are now correct.
final class BASQuietHoursWindowTests: XCTestCase {

    private typealias P = BASPredictiveNotificationPolicyEngine

    func testCrossMidnightWindow() {
        // 22:00–05:00 quiet
        XCTAssertTrue(P.isHourInQuietWindow(hour: 23, start: 22, end: 5))
        XCTAssertTrue(P.isHourInQuietWindow(hour: 3, start: 22, end: 5))
        XCTAssertTrue(P.isHourInQuietWindow(hour: 22, start: 22, end: 5))
        XCTAssertFalse(P.isHourInQuietWindow(hour: 5, start: 22, end: 5))   // end is exclusive
        XCTAssertFalse(P.isHourInQuietWindow(hour: 12, start: 22, end: 5))
    }

    func testSameDayWindow() {
        // 09:00–17:00 quiet — the case the old OR formula got WRONG
        XCTAssertTrue(P.isHourInQuietWindow(hour: 12, start: 9, end: 17))
        XCTAssertFalse(P.isHourInQuietWindow(hour: 20, start: 9, end: 17),
            "20:00 is OUTSIDE a 9–17 window (old `hour>=9 || hour<17` wrongly said quiet)")
        XCTAssertFalse(P.isHourInQuietWindow(hour: 5, start: 9, end: 17))
        XCTAssertFalse(P.isHourInQuietWindow(hour: 17, start: 9, end: 17))  // end exclusive
    }

    func testEmptyWindowStartEqualsEndIsNeverQuiet() {
        for hour in 0..<24 {
            XCTAssertFalse(P.isHourInQuietWindow(hour: hour, start: 9, end: 9),
                "start==end is an empty window — must NEVER be quiet (was 24h fully silent)")
        }
    }
}
