import XCTest
import BASRuntimeCore
@testable import BASLeaseLife

/// M39 — L1 lease-life coverage projection tests.
///
/// Exercises the pure projection on `BASLeaseLifeCoordinator.TurnRecorded`.
/// The `TurnRecorded` value type is constructed directly so tests can sweep
/// every guard-level × cancelled-breath combination without touching the
/// actor-backed lung/thermal/scheduler primitives. The actor end-to-end
/// behavior is covered by the existing L1 coordinator tests; here we only
/// need the projection to be deterministic for any recorded value.
final class BASLeaseLifeObservationCoverageTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers

    private func makeLung(
        pressure: Double = 0.3,
        turnCount: Int = 4
    ) -> BASLungStateAccumulator.Snapshot {
        BASLungStateAccumulator.Snapshot(
            pressure: pressure,
            turnCount: turnCount,
            lastTurnAt: t0,
            lastDecayAt: t0)
    }

    private func makeReading(
        osState: BASThermalTwin.OSThermalState = .fair,
        thermalLevel: BASThermalLevel = .warm,
        guardLevel: BASThermalGuardLevel = .watch,
        accumulated: Double = 0.3,
        at: Date? = nil
    ) -> BASThermalTwin.Reading {
        BASThermalTwin.Reading(
            osState: osState,
            thermalLevel: thermalLevel,
            guardLevel: guardLevel,
            accumulatedPressure: accumulated,
            observedAt: at ?? t0)
    }

    private func makeRecorded(
        lung: BASLungStateAccumulator.Snapshot? = nil,
        reading: BASThermalTwin.Reading? = nil,
        cancelledBreathIDs: [String] = []
    ) -> BASLeaseLifeCoordinator.TurnRecorded {
        BASLeaseLifeCoordinator.TurnRecorded(
            lung: lung ?? makeLung(),
            thermal: reading ?? makeReading(),
            cancelledBreathIDs: cancelledBreathIDs)
    }

    // MARK: - Shape

    func testProjectionCarriesLayerAndFields() {
        let observedAt = t0.addingTimeInterval(42)
        let recorded = makeRecorded(
            reading: makeReading(
                guardLevel: .nominal,
                at: observedAt),
            cancelledBreathIDs: [])
        let s = recorded.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(s.layer, .leaseLife)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(
            s.totalObservations, 2,
            "lung + thermal = 2 base observations, no cancels")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "lung and thermal are two distinct subjects")
        XCTAssertTrue(s.hasCoreSignalCoverage)
        XCTAssertEqual(s.emittedAt, observedAt)
        XCTAssertEqual(
            s.budgetTotalCost,
            0.05,
            accuracy: 1e-9,
            "nominal guard, no cancels → turnBaseCost × 1")
    }

    // MARK: - hasCoreSignalCoverage semantics

    func testNonEmergencyGuardLevelsHaveCoreSignalCoverage() {
        for level: BASThermalGuardLevel in [.nominal, .watch, .throttle] {
            let rec = makeRecorded(
                reading: makeReading(guardLevel: level))
            XCTAssertTrue(
                rec.hasCoreSignalCoverage,
                "guard=\(level) should be core-covered")
        }
    }

    func testEmergencyGuardLevelLosesCoreSignalCoverage() {
        let rec = makeRecorded(
            reading: makeReading(
                osState: .critical,
                thermalLevel: .critical,
                guardLevel: .emergency,
                accumulated: 0.95))
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "emergency = L1 spoke but did not sustain core function")
    }

    // MARK: - Cancelled-breath subjects

    func testEachCancelledBreathAddsASubject() {
        let rec = makeRecorded(
            reading: makeReading(guardLevel: .throttle),
            cancelledBreathIDs: ["b-1", "b-2", "b-3"])
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(
            s.totalObservations, 5,
            "2 base + 3 cancelled = 5 observations")
        XCTAssertEqual(
            s.distinctSubjectCount, 5,
            "lung + thermal + 3 distinct breath ids")
    }

    func testDuplicateCancelledIDsCollapseInDistinctCount() {
        // The coordinator uses `Set` internally so duplicates should
        // not surface, but the projection defensively collapses them
        // so a pathological producer can't inflate distinct counts.
        let rec = makeRecorded(
            cancelledBreathIDs: ["b-1", "b-1", "b-2"])
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(
            s.totalObservations, 5,
            "totalObservations reflects the raw array count")
        XCTAssertEqual(
            s.distinctSubjectCount, 4,
            "lung + thermal + {b-1, b-2} = 4 distinct subjects")
    }

    // MARK: - Budget

    func testBudgetBaseCost() {
        let rec = makeRecorded(
            reading: makeReading(guardLevel: .nominal),
            cancelledBreathIDs: [])
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(s.budgetTotalCost, 0.05, accuracy: 1e-9)
    }

    func testBudgetAddsPerCancelledBreath() {
        let rec = makeRecorded(
            reading: makeReading(guardLevel: .nominal),
            cancelledBreathIDs: ["b-1", "b-2"])
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(
            s.budgetTotalCost,
            0.05 + 0.02 * 2,
            accuracy: 1e-9)
    }

    func testBudgetMultiplierForThrottle() {
        let rec = makeRecorded(
            reading: makeReading(guardLevel: .throttle),
            cancelledBreathIDs: ["b-1"])
        let raw = (0.05 + 0.02) * 1.5
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(s.budgetTotalCost, raw, accuracy: 1e-9)
    }

    func testBudgetMultiplierForEmergency() {
        let rec = makeRecorded(
            reading: makeReading(
                osState: .critical,
                thermalLevel: .critical,
                guardLevel: .emergency),
            cancelledBreathIDs: ["b-1"])
        let raw = (0.05 + 0.02) * 2.0
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(s.budgetTotalCost, raw, accuracy: 1e-9)
    }

    func testBudgetClampsAtOne() {
        // 50 cancelled breaths × 0.02 = 1.0 base + 0.05 = 1.05
        // multiplied by emergency (×2) → 2.10 raw, must clamp to 1.
        let ids = (0..<50).map { "b-\($0)" }
        let rec = makeRecorded(
            reading: makeReading(
                osState: .critical,
                thermalLevel: .critical,
                guardLevel: .emergency),
            cancelledBreathIDs: ids)
        let s = rec.coverageSummary(
            turnID: "t-1", sessionID: "s-1")
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
    }

    // MARK: - Budget helpers (pure)

    func testMultiplierTable() {
        XCTAssertEqual(
            BASLeaseLifeObservationBudget.multiplier(for: .nominal),
            1.0, accuracy: 1e-12)
        XCTAssertEqual(
            BASLeaseLifeObservationBudget.multiplier(for: .watch),
            1.0, accuracy: 1e-12)
        XCTAssertEqual(
            BASLeaseLifeObservationBudget.multiplier(for: .throttle),
            1.5, accuracy: 1e-12)
        XCTAssertEqual(
            BASLeaseLifeObservationBudget.multiplier(for: .emergency),
            2.0, accuracy: 1e-12)
    }

    // MARK: - Cross-layer integration

    func testLeaseLifeSummaryFeedsReconciliationReportAsEleventhLayer() {
        // Construct eleven summaries — one per layer that currently
        // projects — and verify the L1 summary slots into the report
        // without displacing anything else.
        let rec = makeRecorded()
        let l1 = rec.coverageSummary(turnID: "t-1", sessionID: "s-1")

        // Other layers are sketched with minimal valid summaries. The
        // reconciler's contract doesn't care about the inner numbers,
        // only that the layer tag is unique per entry.
        func stub(
            _ layer: BASCognitiveLayer
        ) -> BASObservationCoverageSummary {
            BASObservationCoverageSummary(
                layer: layer,
                turnID: "t-1", sessionID: "s-1",
                totalObservations: 1,
                distinctSubjectCount: 1,
                hasCoreSignalCoverage: true,
                budgetTotalCost: 0.01,
                emittedAt: t0)
        }

        let report = BASObservationReconciliationReport(
            turnID: "t-1", sessionID: "s-1",
            summaries: [
                l1,
                stub(.worldPrior),
                stub(.presenceEye),
                stub(.mirrorBlade),
                stub(.hippocampalWell),
                stub(.dreamLoop),
                stub(.triSelfTribunal),
                stub(.riskClimate),
                stub(.gentleHand),
                stub(.evolutionFurnace),
                stub(.sovereign)
            ])

        XCTAssertEqual(
            report.coveredLayers.count, 11,
            "all 11 currently-projecting layers round-trip")
        XCTAssertEqual(
            report.coveredLayers.first, .leaseLife,
            "first-seen order preserved — L1 is first here")
        XCTAssertEqual(
            report.summary(forLayer: .leaseLife),
            l1,
            "L1 summary round-trips intact")
    }
}
