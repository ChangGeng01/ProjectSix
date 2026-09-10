import XCTest
@testable import BASSovereign

/// M329 — pin substrate contracts that
/// `QinaoSampleHost --cross-device-sync-demo` relies on. Same
/// pattern as M313/M314/M322/M328: demo lives in executable
/// target, tests pin BASSovereign primitives the demo composes.
///
/// What this file pins:
///
///   1. `BASSovereignCrossDeviceClock.tick(...)` increments the
///      device's counter monotonically.
///   2. `BASSovereignCrossDeviceClock.merged(with:)` is
///      commutative — `A.merged(B) == B.merged(A)` (vector
///      clock element-wise max).
///   3. `BASSovereignFragmentMerger.mergeOrdered(...)` is
///      symmetric — `merge(A,B) == merge(B,A)` (set membership
///      + total ordering doesn't depend on input order).
///   4. Empty inputs to merger produce empty output (clean
///      base case).
///   5. Frames seen on both sides appear exactly once in the
///      merged timeline (full-frame dedup).
final class QinaoSampleHostCrossDeviceSyncDemoTests: XCTestCase {

    // MARK: - 1. Clock tick monotonicity

    func testClockTickIncrementsMonotonically() {
        var clock = BASSovereignCrossDeviceClock.initial
        XCTAssertEqual(clock.counter(for: "device-A"), 0)
        clock = clock.tick(deviceID: "device-A")
        XCTAssertEqual(clock.counter(for: "device-A"), 1)
        clock = clock.tick(deviceID: "device-A")
        XCTAssertEqual(clock.counter(for: "device-A"), 2)
        // Other device's counter stays at 0.
        XCTAssertEqual(clock.counter(for: "device-B"), 0)
    }

    // MARK: - 2. Clock merge commutativity

    func testClockMergeIsCommutative() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: [
                "device-A": 3,
                "device-B": 1,
            ])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: [
                "device-A": 2,
                "device-B": 4,
                "device-C": 1,
            ])
        let ab = a.merged(with: b)
        let ba = b.merged(with: a)
        XCTAssertEqual(ab, ba)
        // Element-wise max sanity check:
        XCTAssertEqual(ab.counter(for: "device-A"), 3)
        XCTAssertEqual(ab.counter(for: "device-B"), 4)
        XCTAssertEqual(ab.counter(for: "device-C"), 1)
    }

    // MARK: - Fixture: 2-device timeline

    private func makeFrame(
        ref: String, deviceID: String,
        clock: BASSovereignCrossDeviceClock
    ) -> BASSovereignCrossDeviceLedgerFrame {
        BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: deviceID,
            clock: clock)
    }

    private func twoDeviceFixture() -> (
        a: [BASSovereignCrossDeviceLedgerFrame],
        b: [BASSovereignCrossDeviceLedgerFrame]
    ) {
        var clockA = BASSovereignCrossDeviceClock.initial
        var framesA: [
            BASSovereignCrossDeviceLedgerFrame
        ] = []
        for i in 1...3 {
            clockA = clockA.tick(deviceID: "device-A")
            framesA.append(
                makeFrame(
                    ref: "audit-A-\(i)",
                    deviceID: "device-A",
                    clock: clockA))
        }
        var clockB = BASSovereignCrossDeviceClock.initial
        var framesB: [
            BASSovereignCrossDeviceLedgerFrame
        ] = []
        for i in 1...2 {
            clockB = clockB.tick(deviceID: "device-B")
            framesB.append(
                makeFrame(
                    ref: "audit-B-\(i)",
                    deviceID: "device-B",
                    clock: clockB))
        }
        return (framesA, framesB)
    }

    // MARK: - 3. Merger symmetric under reverse

    func testMergerIsSymmetricUnderReverse() {
        let f = twoDeviceFixture()
        let ab = BASSovereignFragmentMerger.mergeOrdered(
            f.a, f.b)
        let ba = BASSovereignFragmentMerger.mergeOrdered(
            f.b, f.a)
        XCTAssertEqual(ab, ba)
        // Both sides see all 5 frames.
        XCTAssertEqual(ab.count, 5)
    }

    // MARK: - 4. Empty input edge case

    func testMergerHandlesEmptyInputs() {
        let empty: [BASSovereignCrossDeviceLedgerFrame] = []
        let merged = BASSovereignFragmentMerger
            .mergeOrdered(empty, empty)
        XCTAssertTrue(merged.isEmpty)
    }

    func testMergerWithOneEmptyReturnsOther() {
        let f = twoDeviceFixture()
        let empty: [BASSovereignCrossDeviceLedgerFrame] = []
        let merged = BASSovereignFragmentMerger
            .mergeOrdered(f.a, empty)
        XCTAssertEqual(merged.count, f.a.count)
        let allRefs = merged.map(\.auditEntryRef)
        let aRefs = f.a.map(\.auditEntryRef)
        XCTAssertEqual(Set(allRefs), Set(aRefs))
    }

    // MARK: - 5. Full-frame dedup when same frame appears in both

    func testMergerDedupsIdenticalFrames() {
        let clock =
            BASSovereignCrossDeviceClock(
                deviceCounters: ["device-A": 1])
        let shared = makeFrame(
            ref: "shared-1",
            deviceID: "device-A",
            clock: clock)
        // shared frame appears in both inputs
        let merged = BASSovereignFragmentMerger
            .mergeOrdered([shared], [shared])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].auditEntryRef, "shared-1")
    }
}
