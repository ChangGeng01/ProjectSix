import XCTest
@testable import BASRuntimeCore

/// device-recon id5: Mac teeth for the lock-screen cooldown spin. The spin must
/// bound its duration on the INJECTED monotonic clock, not a hidden wall-clock —
/// so a backward NTP/DST step can't stall it. Injecting a simulated monotonic
/// clock proves both the deadline math and that the loop honors the injected
/// clock (a hidden Date() would ignore it and spin real-time).
final class BASIdleGuardedSpinTests: XCTestCase {

    func testTerminatesUnderInjectedMonotonicClock() {
        // Clock advances 1ms per read; a 10ms spin ⇒ ~10 reads. Bounded iteration
        // count proves the loop uses the INJECTED clock (a hidden Date() would run
        // the real 10ms and iterate millions of times).
        var t: UInt64 = 0
        let iters = BASIdleGuardedSpin.spin(seconds: 0.010) {
            defer { t &+= 1_000_000 }   // +1 ms per read
            return t
        }
        XCTAssertGreaterThan(iters, 0, "the spin ran")
        XCTAssertLessThan(iters, 1000,
            "10ms deadline / 1ms-per-read ⇒ ~10 iterations — the injected clock bounds it")
    }

    func testNonPositiveDurationIsANoOp() {
        XCTAssertEqual(BASIdleGuardedSpin.spin(seconds: 0) { 0 }, 0)
        XCTAssertEqual(BASIdleGuardedSpin.spin(seconds: -5) { 0 }, 0)
    }

    func testDeadlineIsRelativeToTheStartRead() {
        // end = start + seconds; a clock starting at a large offset must still only
        // spin for `seconds`, not until some absolute epoch.
        var t: UInt64 = 1_000_000_000_000   // large monotonic offset
        let iters = BASIdleGuardedSpin.spin(seconds: 0.005) {
            defer { t &+= 1_000_000 }
            return t
        }
        XCTAssertGreaterThan(iters, 0)
        XCTAssertLessThan(iters, 1000,
            "5ms / 1ms-per-read ⇒ ~5 iterations regardless of the absolute clock offset")
    }
}
