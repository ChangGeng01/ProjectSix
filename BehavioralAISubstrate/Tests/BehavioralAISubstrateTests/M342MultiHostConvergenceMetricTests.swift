import XCTest
@testable import BASSovereign

/// M342 — pin the multi-host convergence measurement plane primitive.
///
/// This is the **measurement plane** leg of the v5 doctrine triple
/// for the `Multi-instance distribution` candidate parked in
/// `QINAO_MANIFESTO_V5_DOCTRINE` appendix.
///
/// What this file pins:
///
///   1. Disjoint-host happy path: 2 hosts each contribute N frames,
///      0 overlap → consensus has N+M frames, no duplicates,
///      symmetric merge.
///   2. Overlap detection: when A and B share K frames, dedup
///      cardinality = (|A|+|B|-K).
///   3. `allInvariantsHold` returns true when consensus card matches
///      and dedup is clean and merge is symmetric; false otherwise.
///   4. `failingInvariants` lists the specific broken contracts.
///   5. Clock divergence peak captures the max counter delta across
///      union of device IDs.
///   6. Wall-clock seconds field is non-negative even with same-
///      instant clock fixture.
///   7. Codable round-trip.
final class M342MultiHostConvergenceMetricTests: XCTestCase {

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

    private func disjointFixture() -> (
        framesA: [BASSovereignCrossDeviceLedgerFrame],
        framesB: [BASSovereignCrossDeviceLedgerFrame],
        clockA: BASSovereignCrossDeviceClock,
        clockB: BASSovereignCrossDeviceClock
    ) {
        var clockA = BASSovereignCrossDeviceClock.initial
        var framesA: [BASSovereignCrossDeviceLedgerFrame] = []
        for stage in ["s1", "s2", "s3", "s4"] {
            clockA = clockA.tick(deviceID: "host-A")
            framesA.append(frame(
                ref: "audit-A-\(stage)",
                hostID: "host-A", clock: clockA))
        }
        var clockB = BASSovereignCrossDeviceClock.initial
        var framesB: [BASSovereignCrossDeviceLedgerFrame] = []
        for stage in ["s1", "s2", "s3"] {
            clockB = clockB.tick(deviceID: "host-B")
            framesB.append(frame(
                ref: "audit-B-\(stage)",
                hostID: "host-B", clock: clockB))
        }
        return (framesA, framesB, clockA, clockB)
    }

    // MARK: - Tests

    func testDisjointHostsProduceCleanConsensus() {
        let f = disjointFixture()
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: f.framesA,
            framesB: f.framesB,
            clockA: f.clockA,
            clockB: f.clockB)

        XCTAssertEqual(metric.framesContributedA, 4)
        XCTAssertEqual(metric.framesContributedB, 3)
        XCTAssertEqual(metric.framesInConsensus, 7)
        XCTAssertEqual(metric.frameOverlapCount, 0)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus, 0)
        XCTAssertTrue(metric.mergeIsSymmetric)
        XCTAssertTrue(metric.allInvariantsHold)
        XCTAssertEqual(metric.failingInvariants, [])
    }

    func testOverlapIsDeduplicated() {
        // Both A and B carry the same frame (e.g., they previously
        // exchanged a snapshot).
        var clockA = BASSovereignCrossDeviceClock.initial
        clockA = clockA.tick(deviceID: "host-A")
        let sharedFrame = frame(
            ref: "audit-shared",
            hostID: "host-A", clock: clockA)

        let framesA = [sharedFrame]
        let framesB = [sharedFrame]
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: framesA, framesB: framesB,
            clockA: clockA, clockB: clockA)

        XCTAssertEqual(metric.framesContributedA, 1)
        XCTAssertEqual(metric.framesContributedB, 1)
        XCTAssertEqual(metric.frameOverlapCount, 1)
        XCTAssertEqual(metric.framesInConsensus, 1)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus, 0)
        XCTAssertTrue(metric.allInvariantsHold)
    }

    func testEmptyHostInputsAreCleanlyHandled() {
        let empty: [BASSovereignCrossDeviceLedgerFrame] = []
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: empty, framesB: empty,
            clockA: .initial, clockB: .initial)

        XCTAssertEqual(metric.framesContributedA, 0)
        XCTAssertEqual(metric.framesContributedB, 0)
        XCTAssertEqual(metric.framesInConsensus, 0)
        XCTAssertEqual(metric.frameOverlapCount, 0)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus, 0)
        XCTAssertTrue(metric.mergeIsSymmetric)
        XCTAssertTrue(metric.allInvariantsHold)
        XCTAssertEqual(metric.clockDivergencePeak, 0)
    }

    func testClockDivergencePeakDetectsCounterDelta() {
        let f = disjointFixture()
        // host-A advanced its own counter to 4; host-B advanced
        // its own counter to 3. Peak delta should be max(4, 3) = 4
        // since the two device IDs are disjoint and the
        // missing-counter side reads as 0.
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: f.framesA, framesB: f.framesB,
            clockA: f.clockA, clockB: f.clockB)

        XCTAssertEqual(metric.clockDivergencePeak, 4)
    }

    func testFailingInvariantsListsAllBrokenContracts() {
        // Synthesize a metric that violates every contract.
        let bad = BASMultiHostConvergenceMetric(
            framesContributedA: 3,
            framesContributedB: 2,
            framesInConsensus: 100,    // wrong: should be 5
            frameOverlapCount: 0,
            duplicateFramesInConsensus: 7,  // should be 0
            mergeIsSymmetric: false,        // should be true
            clockDivergencePeak: 0,
            mergeWallClockSeconds: 0)
        XCTAssertFalse(bad.allInvariantsHold)
        let failures = bad.failingInvariants
        XCTAssertEqual(failures.count, 3)
        XCTAssertTrue(
            failures.contains {
                $0.contains("consensus-cardinality")
            })
        XCTAssertTrue(
            failures.contains {
                $0.contains("duplicates-in-consensus")
            })
        XCTAssertTrue(
            failures.contains { $0 == "merge-asymmetric" })
    }

    func testWallClockSecondsIsNonNegative() {
        let f = disjointFixture()
        // Use a frozen clock that returns the same Date both
        // times — elapsed will be 0 (or tiny negative due to
        // Date precision); metric must clamp to 0.
        let frozenDate = Date()
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: f.framesA, framesB: f.framesB,
            clockA: f.clockA, clockB: f.clockB,
            clock: { frozenDate })
        XCTAssertGreaterThanOrEqual(
            metric.mergeWallClockSeconds, 0)
    }

    func testCodableRoundTrip() throws {
        let f = disjointFixture()
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: f.framesA, framesB: f.framesB,
            clockA: f.clockA, clockB: f.clockB)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(metric)
        let decoded = try JSONDecoder().decode(
            BASMultiHostConvergenceMetric.self, from: data)
        XCTAssertEqual(metric, decoded)
    }

    func testMetricMatchesFragmentMergerContract() {
        // For the canonical M335 disjoint case, the metric must
        // reflect exactly the same outcome as the M335 demo's
        // own ConsensusReport invariants. This pins the metric
        // against the production merger contract.
        let f = disjointFixture()
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: f.framesA, framesB: f.framesB,
            clockA: f.clockA, clockB: f.clockB)

        // Production merger result (independent of measurement).
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            f.framesA, f.framesB)
        XCTAssertEqual(
            metric.framesInConsensus, merged.count)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus,
            merged.count - Set(merged).count)
    }
}
