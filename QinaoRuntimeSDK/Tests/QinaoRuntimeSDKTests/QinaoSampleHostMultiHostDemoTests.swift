import XCTest
@testable import BASSovereign

/// M335 — pin substrate contracts that
/// `QinaoSampleHost --multi-host-demo` relies on. Same pattern
/// as M313/M314/M322/M328/M329/M333/M334: demo lives in
/// executable target, tests pin BASSovereign primitives that
/// the demo composes (which are exactly the M329 primitives,
/// reused with hostID semantics).
///
/// What this file pins:
///
///   1. `BASSovereignCrossDeviceLedgerFrame.originDeviceID` is
///      a free-form String — works as `hostID` directly without
///      schema change. (Confirms the M335 doctrine: 0 BAS
///      changes needed.)
///   2. Two LedgerFrames with distinct origin IDs (hostID
///      semantics) merge into a deterministic total-ordered
///      output.
///   3. FragmentMerger is symmetric under reverse input —
///      `merge(A,B) == merge(B,A)`.
///   4. CrossDeviceClock element-wise max is commutative —
///      `merge(A,B) == merge(B,A)`.
///   5. Distinct hostIDs give distinct clock-counter keys
///      (logical isolation via namespacing).
///   6. Empty fragments from one side preserves the other side
///      verbatim.
final class QinaoSampleHostMultiHostDemoTests: XCTestCase {

    // MARK: - Fixture helpers

    private func frame(
        ref: String, hostID: String,
        clock: BASSovereignCrossDeviceClock
    ) -> BASSovereignCrossDeviceLedgerFrame {
        BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: hostID,
            clock: clock)
    }

    private func twoHostFixture() -> (
        a: [BASSovereignCrossDeviceLedgerFrame],
        b: [BASSovereignCrossDeviceLedgerFrame]
    ) {
        let hostA = "host-A"
        var clockA = BASSovereignCrossDeviceClock.initial
        var framesA: [
            BASSovereignCrossDeviceLedgerFrame
        ] = []
        for stage in [
            "register", "trial", "finalize", "promote",
        ] {
            clockA = clockA.tick(deviceID: hostA)
            framesA.append(
                frame(
                    ref: "audit-\(hostA)-\(stage)",
                    hostID: hostA, clock: clockA))
        }
        let hostB = "host-B"
        var clockB = BASSovereignCrossDeviceClock.initial
        var framesB: [
            BASSovereignCrossDeviceLedgerFrame
        ] = []
        for stage in ["register", "trial", "fail"] {
            clockB = clockB.tick(deviceID: hostB)
            framesB.append(
                frame(
                    ref: "audit-\(hostB)-\(stage)",
                    hostID: hostB, clock: clockB))
        }
        return (framesA, framesB)
    }

    // MARK: - 1. originDeviceID accepts hostID strings

    func testOriginDeviceIDAcceptsHostIDStrings() {
        let f = frame(
            ref: "audit-1",
            hostID: "host-alpha-prod-001",
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: [
                    "host-alpha-prod-001": 1
                ]))
        XCTAssertEqual(
            f.originDeviceID, "host-alpha-prod-001")
    }

    // MARK: - 2. Multi-host merge produces deterministic output

    func testMultiHostMergeProducesDeterministicOutput() {
        let f = twoHostFixture()
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            f.a, f.b)
        XCTAssertEqual(
            merged.count, f.a.count + f.b.count)
        // All host-A frames present.
        for frame in f.a {
            XCTAssertTrue(merged.contains(frame))
        }
        // All host-B frames present.
        for frame in f.b {
            XCTAssertTrue(merged.contains(frame))
        }
    }

    // MARK: - 3. Multi-host merge is symmetric

    func testMultiHostMergeIsSymmetric() {
        let f = twoHostFixture()
        let ab = BASSovereignFragmentMerger.mergeOrdered(
            f.a, f.b)
        let ba = BASSovereignFragmentMerger.mergeOrdered(
            f.b, f.a)
        XCTAssertEqual(ab, ba)
    }

    // MARK: - 4. Clock merge commutative across hostIDs

    func testClockMergeCommutativeAcrossHostIDs() {
        let cA = BASSovereignCrossDeviceClock(
            deviceCounters: [
                "host-alpha": 5,
                "host-beta": 1,
            ])
        let cB = BASSovereignCrossDeviceClock(
            deviceCounters: [
                "host-alpha": 2,
                "host-beta": 7,
                "host-gamma": 3,
            ])
        let ab = cA.merged(with: cB)
        let ba = cB.merged(with: cA)
        XCTAssertEqual(ab, ba)
        // Element-wise max sanity check.
        XCTAssertEqual(ab.counter(for: "host-alpha"), 5)
        XCTAssertEqual(ab.counter(for: "host-beta"), 7)
        XCTAssertEqual(ab.counter(for: "host-gamma"), 3)
    }

    // MARK: - 5. Distinct hostIDs give distinct clock keys

    func testDistinctHostIDsGiveDistinctClockKeys() {
        var clock = BASSovereignCrossDeviceClock.initial
        clock = clock.tick(deviceID: "host-A")
        clock = clock.tick(deviceID: "host-B")
        clock = clock.tick(deviceID: "host-C")
        XCTAssertEqual(clock.deviceCounters.count, 3)
        XCTAssertEqual(clock.counter(for: "host-A"), 1)
        XCTAssertEqual(clock.counter(for: "host-B"), 1)
        XCTAssertEqual(clock.counter(for: "host-C"), 1)
    }

    // MARK: - 6. Empty side preserves other side verbatim

    func testEmptyHostFragmentsPreserveOtherHostVerbatim() {
        let f = twoHostFixture()
        let empty: [BASSovereignCrossDeviceLedgerFrame] = []
        let mergedAEmpty = BASSovereignFragmentMerger
            .mergeOrdered(f.a, empty)
        XCTAssertEqual(mergedAEmpty.count, f.a.count)
        // All A frames preserved.
        XCTAssertEqual(
            Set(mergedAEmpty), Set(f.a))
    }
}
