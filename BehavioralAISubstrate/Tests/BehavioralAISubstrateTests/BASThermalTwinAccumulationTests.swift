import XCTest
@testable import BASLeaseLife

/// deep-audit LOW: pins the mechanism behind BASThermalTwinFeed's DORMANT accumulated-pressure signal.
/// BASThermalTwin.sample() only READS accumulatedPressure — it never self-accumulates; the accumulator is
/// raised ONLY by updateAccumulatedPressure. So a feed whose private twin is never fed (exactly
/// BASThermalTwinFeed's situation) reports pressure 0, NOT the "hysteresis-bearing signal" the old comment
/// claimed. If sample() is ever made to self-accumulate (making the feed's signal real), this reds — a
/// deliberate signal to update the feed's honesty note.
final class BASThermalTwinAccumulationTests: XCTestCase {

    func testSampleAloneNeverAccumulatesPressure() async {
        let twin = BASThermalTwin()
        for _ in 0..<5 {
            let r = await twin.sample()
            XCTAssertEqual(r.accumulatedPressure, 0.0,
                "sample() must NOT self-accumulate — an un-fed twin (BASThermalTwinFeed's) stays at 0")
        }
        // The ONLY path that raises accumulated pressure is the explicit update.
        let fed = await twin.updateAccumulatedPressure(0.7)
        XCTAssertEqual(fed.accumulatedPressure, 0.7, accuracy: 1e-9,
            "updateAccumulatedPressure is the sole accumulator path (which the feed never calls)")
    }
}
