import XCTest
import Darwin
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
        // WEAK timescale sanity check only — it does NOT discriminate the
        // runtimecore-a #1 fix (id3): wall>=mono holds whether
        // bas_wallclock_nanos reads mach_continuous_time (fixed) OR
        // mach_absolute_time (buggy), because both share the timescale and
        // wall is read after mono. The real discriminator is
        // testWallclockSleepAdvanceMatchesSleepInterval below.
        let mono = try BASMonotonicNanos.rawCNanos()
        let wall = try BASWallclockNanos.rawCNanos()   // read AFTER mono
        XCTAssertGreaterThanOrEqual(wall, mono,
            "the sleep-inclusive clock, read after the uptime clock, is at least as large")
    }

    func testWallclockSleepAdvanceMatchesSleepInterval() throws {
        // id3 DISCRIMINATING teeth (no false-green). Independently measure
        // the accumulated sleep-since-boot as continuous − absolute (mach
        // ticks → ns via timebase). If the machine has not slept, that gap
        // is ~0 → XCTSkip (honest: sleep-advance is device-gated, cannot be
        // induced in a unit test). When it HAS slept, bas_wallclock_nanos
        // (continuous) minus bas_monotonic_nanos (absolute) must equal that
        // sleep interval — under the OLD bug (wallclock read absolute) the
        // difference collapses to ~0 and this reds.
        var tb = mach_timebase_info_data_t()
        guard mach_timebase_info(&tb) == KERN_SUCCESS, tb.denom != 0 else {
            throw XCTSkip("mach_timebase_info unavailable")
        }
        let ticks = mach_continuous_time() &- mach_absolute_time()
        let sleepNs = ticks / UInt64(tb.denom) * UInt64(tb.numer)
            &+ (ticks % UInt64(tb.denom) * UInt64(tb.numer)) / UInt64(tb.denom)
        // Require a clear ≥1s sleep so read-order/scheduling skew (µs) is
        // negligible against the signal; otherwise abstain.
        try XCTSkipUnless(sleepNs > 1_000_000_000,
            "machine has not slept since boot (sleep gap "
            + "\(sleepNs) ns); sleep-advance is device-gated")
        let mono = try BASMonotonicNanos.rawCNanos()
        let wall = try BASWallclockNanos.rawCNanos()   // read AFTER mono
        let basGap = wall - mono
        // Tolerance: 5% of the sleep interval + 50ms for read skew.
        let tol = Double(sleepNs) * 0.05 + 50_000_000
        XCTAssertEqual(Double(basGap), Double(sleepNs), accuracy: tol,
            "bas_wallclock_nanos − bas_monotonic_nanos must equal the "
            + "sleep interval (\(sleepNs) ns); a ~0 gap means wallclock "
            + "still reads the sleep-EXCLUDED clock (the reverted bug)")
    }
}
