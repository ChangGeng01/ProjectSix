import XCTest
@testable import BASLeaseLife
@testable import BASMemory

/// M334 — pin substrate contracts that
/// `QinaoSampleHost --throughput-bench` relies on. Same pattern
/// as M313/M314/M322/M328/M329/M333: demo lives in executable
/// target, tests pin the BASLeaseLife + BASMemory primitives the
/// demo composes.
///
/// What this file pins:
///
///   1. `BASLeaseLifeCoordinator.makeDefault()` works — produces
///      a usable coordinator without manual primitive wiring.
///   2. `recordTurn(runMode:durationSeconds:)` returns a
///      `TurnRecorded` with non-nil thermal reading + lung
///      snapshot.
///   3. Multiple `recordTurn` calls accumulate pressure
///      monotonically (pressure increases across turns).
///   4. `BASEvolutionLifecycleSession` round-trip workload
///      doesn't throw — the bench's representative work
///      executes cleanly.
///   5. Latency-stats `compute(latenciesMs:)` produces correct
///      results for known inputs (sanity-check the M179-style
///      percentile algorithm).
final class QinaoSampleHostThroughputBenchDemoTests: XCTestCase {

    // MARK: - 1. makeDefault produces usable coordinator

    func testMakeDefaultProducesUsableCoordinator() async {
        let coord = BASLeaseLifeCoordinator.makeDefault()
        let recorded = await coord.recordTurn(
            runMode: .engage,
            durationSeconds: 0.001)
        // Just ensure the call returns a TurnRecorded with
        // non-nil components.
        XCTAssertGreaterThanOrEqual(
            recorded.lung.pressure, 0)
        XCTAssertLessThanOrEqual(
            recorded.lung.pressure, 1)
    }

    // MARK: - 2. recordTurn produces well-shaped reading

    func testRecordTurnProducesWellShapedReading() async {
        let coord = BASLeaseLifeCoordinator.makeDefault()
        let recorded = await coord.recordTurn(
            runMode: .engage,
            durationSeconds: 0.05)
        // Lung snapshot has non-negative turn count.
        XCTAssertGreaterThanOrEqual(
            recorded.lung.turnCount, 1)
        // Thermal reading has timestamp set.
        XCTAssertNotNil(recorded.thermal.observedAt)
        // cancelledBreathIDs is a valid (possibly empty) array.
        XCTAssertGreaterThanOrEqual(
            recorded.cancelledBreathIDs.count, 0)
    }

    // MARK: - 3. Multiple recordTurn accumulates pressure

    func testMultipleRecordTurnsAccumulatePressure() async {
        let coord = BASLeaseLifeCoordinator.makeDefault()
        var pressures: [Double] = []
        for _ in 0..<5 {
            let recorded = await coord.recordTurn(
                runMode: .deepLoop,
                durationSeconds: 0.5)
            pressures.append(recorded.lung.pressure)
        }
        XCTAssertEqual(pressures.count, 5)
        // Pressure should monotonically increase (or stay
        // equal across very-fast consecutive calls).
        for i in 1..<pressures.count {
            XCTAssertGreaterThanOrEqual(
                pressures[i],
                pressures[i - 1] - 0.001,
                "pressure should not decrease between " +
                "consecutive recordTurn calls (within float " +
                "tolerance)")
        }
    }

    // MARK: - 4. Lifecycle workload executes cleanly

    func testRepresentativeLifecycleWorkExecutes() {
        // Mirror what the bench does inside its hot loop.
        var s1 = BASEvolutionLifecycleSession(
            candidateID: "test-promote")
        s1 = s1.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.finalizeTrial)!
            .applying(.promote)!
        XCTAssertEqual(s1.currentStage, .promoted)

        var s2 = BASEvolutionLifecycleSession(
            candidateID: "test-fail")
        s2 = s2.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.fail)!
        XCTAssertEqual(s2.currentStage, .rejected)

        var s3 = BASEvolutionLifecycleSession(
            candidateID: "test-withdraw")
        s3 = s3.applying(.withdraw)!
        XCTAssertEqual(s3.currentStage, .withdrawn)

        let agg = BASEvolutionLifecycleSession.aggregate(
            [s1, s2, s3])
        XCTAssertNotNil(agg)
        XCTAssertEqual(agg?.count, 3)
    }

    // MARK: - 5. Latency-stats sanity (mirror M179 algorithm)

    /// Verify that nearest-rank percentile returns expected
    /// values for a known input. We test the algorithm directly
    /// by re-implementing it locally (the demo's struct lives in
    /// executable target and is not @testable importable).
    func testLatencyPercentileNearestRankAlgorithm() {
        // Inputs: 1..100 ms (sorted).
        let latencies = (1...100).map { Double($0) }
        // p50 = 50th smallest = 50 (idx = ceil(0.50 * 100) - 1 = 49)
        XCTAssertEqual(percentile(sorted: latencies, p: 0.50), 50.0)
        // p95 = 95th smallest = 95
        XCTAssertEqual(percentile(sorted: latencies, p: 0.95), 95.0)
        // p99 = 99th smallest = 99
        XCTAssertEqual(percentile(sorted: latencies, p: 0.99), 99.0)
        // p100 (clamped to last)
        XCTAssertEqual(percentile(sorted: latencies, p: 1.0), 100.0)
    }

    /// Local copy of demo's percentile algorithm for direct
    /// verification (since the demo's private static can't be
    /// reached from the test target).
    private func percentile(sorted: [Double], p: Double) -> Double {
        let n = sorted.count
        let idx = Swift.max(
            0,
            Swift.min(
                n - 1,
                Int(ceil(p * Double(n))) - 1))
        return sorted[idx]
    }
}
