// MARK: - BASMemoryPressureArithmeticTests
//
// audit M-e #2 — `bas_memory_pressure_percent` used `used = total -
// free`, counting `inactive` (reclaimable cache) as resident pressure.
// A healthy device with a large file cache therefore read ~90-100% used
// and `BASSystemProbe.isUnderPressure()` (> 80% threshold) was pinned
// true。 The ratio is now split into a pure helper counting only
// `active + wired` — these tests exercise it with synthetic page counts.

import XCTest
import BASCSystemBridge

final class BASMemoryPressureArithmeticTests: XCTestCase {

    private func pressure(
        free: Int64, active: Int64, inactive: Int64, wired: Int64
    ) -> (rc: Int32, pct: Int32) {
        var pct: Int32 = -99
        let rc = bas_memory_pressure_percent_from(
            free, active, inactive, wired, &pct)
        return (rc, pct)
    }

    /// The regression: a healthy device whose free pages are low ONLY
    /// because the kernel filled RAM with reclaimable file cache must
    /// NOT read as under pressure。 total 1M pages, 600k inactive cache,
    /// only 300k truly resident (active+wired)。
    func testHealthyDeviceWithLargeCacheIsNotUnderPressure() {
        let r = pressure(
            free: 100_000, active: 200_000,
            inactive: 600_000, wired: 100_000)
        XCTAssertEqual(r.rc, 0)
        XCTAssertEqual(r.pct, 30,
            "used = active(200k)+wired(100k) = 300k of 1M ⇒ 30%")
        XCTAssertLessThanOrEqual(r.pct, 80,
            "the OLD `total-free` formula read 90% here ⇒ isUnderPressure恒真")
    }

    /// Genuine pressure — little cache, memory truly resident。
    func testGenuinePressureReadsHigh() {
        let r = pressure(
            free: 10_000, active: 900_000,
            inactive: 10_000, wired: 80_000)
        XCTAssertEqual(r.rc, 0)
        XCTAssertEqual(r.pct, 98,
            "used = active(900k)+wired(80k) = 980k of 1M ⇒ 98%")
        XCTAssertGreaterThan(r.pct, 80, "real pressure still trips the gate")
    }

    /// Available headroom = free + inactive; an all-cache/idle machine
    /// reads near zero, not near 100。
    func testIdleMachineReadsNearZero() {
        let r = pressure(
            free: 500_000, active: 0,
            inactive: 490_000, wired: 10_000)
        XCTAssertEqual(r.rc, 0)
        XCTAssertEqual(r.pct, 1, "only 10k wired resident of 1M ⇒ 1%")
    }

    /// Degenerate totals fail closed with -1 (probe honesty — never
    /// 0-as-unknown)。
    func testZeroTotalFailsClosed() {
        let r = pressure(free: 0, active: 0, inactive: 0, wired: 0)
        XCTAssertEqual(r.rc, -1)
        XCTAssertEqual(r.pct, -1)
    }

    /// Full pressure — no cache, no free — reads exactly 100 and clamps。
    func testFullyResidentReadsHundred() {
        let r = pressure(
            free: 0, active: 700_000, inactive: 0, wired: 300_000)
        XCTAssertEqual(r.rc, 0)
        XCTAssertEqual(r.pct, 100)
    }
}
