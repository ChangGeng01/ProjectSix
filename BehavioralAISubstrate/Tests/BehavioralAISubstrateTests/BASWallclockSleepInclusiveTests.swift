import XCTest
@testable import BASRuntimeCore

/// audit runtimecore-a #1 — `bas_wallclock_nanos` now reads the sleep-INCLUSIVE clock
/// (`mach_continuous_time`) instead of the sleep-EXCLUDED `mach_absolute_time`, so a timestamp
/// straddling a system sleep advances by the sleep interval (attestation-freshness / thermal
/// resume detection). The sleep-ADVANCE property is inherently DEVICE-verified: the ONLY behavioral
/// difference between the two Mach clocks is sleep, which a unit test cannot induce (on a machine
/// that has not slept since boot the two read identically). This pins the Mac-observable invariants:
/// the C bridge succeeds, returns a plausible since-boot value, and is monotonic non-decreasing.
final class BASWallclockSleepInclusiveTests: XCTestCase {

    func testWallclockBridgeSucceedsAndIsMonotonic() throws {
        let a = try BASWallclockNanos.rawCNanos()
        let b = try BASWallclockNanos.rawCNanos()
        XCTAssertGreaterThan(a, 0, "a plausible since-boot timestamp, not zero/garbage")
        XCTAssertGreaterThanOrEqual(b, a, "the clock must be monotonic non-decreasing")
    }

    func testWallclockNeverReadsBehindTheSleepExcludedClock() throws {
        // mach_continuous_time (sleep-inclusive) can never be BEHIND CLOCK_UPTIME_RAW
        // (sleep-excluded) on the same epoch, modulo a few µs of read-order skew. This is a weak
        // cross-check that the two clocks share a timescale; the strict sleep gap is device-verified.
        let mono = try BASMonotonicNanos.rawCNanos()
        let wall = try BASWallclockNanos.rawCNanos()   // read AFTER mono
        XCTAssertGreaterThanOrEqual(wall, mono,
            "the sleep-inclusive clock, read after the uptime clock, is at least as large")
    }
}
