import XCTest
@testable import BASMetalSubstrate

/// audit devicetestapp MED-8 — the in-flight command-buffer budget must refuse the
/// allocation that would exceed the queue's quota, so the GPU heartbeat probe returns a
/// bounded `.timedOut` on a wedge instead of blocking the 65th makeCommandBuffer and
/// freezing adjudication ~21 min in. Pure counter — no Metal, no device.
final class BASMetalProbeInFlightBudgetTests: XCTestCase {

    func testRefusesBeyondCap() {
        let b = BASMetalProbeInFlightBudget(cap: 60)
        for i in 0..<60 {
            XCTAssertTrue(b.tryAcquire(), "acquire \(i) within cap must succeed")
        }
        XCTAssertEqual(b.inFlight, 60)
        // THE fix: the 61st (the buffer that would block a wedged queue) is refused.
        XCTAssertFalse(b.tryAcquire(),
            "at capacity, tryAcquire must refuse — the probe returns .timedOut, never blocks")
    }

    func testReleaseFreesASlot() {
        let b = BASMetalProbeInFlightBudget(cap: 60)
        for _ in 0..<60 { _ = b.tryAcquire() }
        XCTAssertFalse(b.tryAcquire())
        b.release()                       // a buffer completed
        XCTAssertEqual(b.inFlight, 59)
        XCTAssertTrue(b.tryAcquire(), "a completion frees exactly one slot")
    }

    func testReleaseNeverGoesNegative() {
        let b = BASMetalProbeInFlightBudget(cap: 4)
        b.release(); b.release()          // spurious releases are ignored
        XCTAssertEqual(b.inFlight, 0)
        XCTAssertTrue(b.tryAcquire())
        XCTAssertEqual(b.inFlight, 1)
    }
}
