import XCTest
import BASRuntimeCore
@testable import BASOrchestration

/// M97 — Unit tests for L1 / L2 / L5 `coverageSummary` projections.
///
/// Pre-M97 state: `BASObservationCoverageProjections.swift` carried
/// projections for L6 / L7 / L9 / L10 / L12, plus file-level
/// projections for L3 (ThoughtFold) and L4 (WorldPrior) in their own
/// coverage files, plus L13 (ShadowTrial) in BASMemory. But the
/// three bundle types for L1 (LeaseLife), L2 (NeuralOrgan), and L5
/// (HostConstitution) had no `coverageSummary` edge — meaning hosts
/// could not stream them through
/// `QinaoSovereignControlPlane.recordTurnCoverage(additionalSummaries:)`
/// without writing their own bundle→summary mapper.
///
/// M97 adds the three projections. These tests pin:
///
/// 1. Layer identity for each projection (`.leaseLife` / `.neuralOrgan`
///    / `.hostConstitution`)
/// 2. turnID / sessionID / emittedAt round-trip from bundle to summary
/// 3. `totalObservations == observations.count`
/// 4. `distinctSubjectCount == subjectIDs.count`
/// 5. `hasCoreSignalCoverage` surfaces the existing bundle predicate
///    (lease baseline / map sealed / any anchor)
/// 6. `budgetTotalCost == <Module>SignalBudget.totalCost(for: bundle)`
///    byte-equal
final class BASL1L2L5CoverageProjectionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 0)

    // MARK: - Helpers

    private func leaseLifeObs(
        kind: BASLeaseLifeSignalKind,
        subject: String
    ) -> BASLeaseLifeObservation {
        BASLeaseLifeObservation(
            kind: kind,
            shape: .nominal,
            subjectID: subject,
            salience: 0.5,
            confidence: 0.5,
            content: "x",
            observedAt: t0)
    }

    private func neuralOrganObs(
        kind: BASNeuralOrganSignalKind,
        subject: String
    ) -> BASNeuralOrganObservation {
        BASNeuralOrganObservation(
            kind: kind,
            shape: .quiet,
            subjectID: subject,
            salience: 0.5,
            confidence: 0.5,
            content: "x",
            observedAt: t0)
    }

    private func hostConstitutionObs(
        kind: BASHostConstitutionSignalKind,
        subject: String
    ) -> BASHostConstitutionObservation {
        BASHostConstitutionObservation(
            kind: kind,
            shape: .governing,
            subjectID: subject,
            salience: 0.5,
            confidence: 0.5,
            content: "x",
            observedAt: t0)
    }

    // MARK: - L1 LeaseLife

    func testLeaseLifeProjectionCarriesLayerAndFields() {
        let bundle = BASLeaseLifeObservationBundle(
            turnID: "t.l1",
            sessionID: "s.l1",
            observations: [
                leaseLifeObs(kind: .leaseGranted,
                    subject: "lease.alpha"),
                leaseLifeObs(kind: .runModeDetermined,
                    subject: "run.engage"),
                leaseLifeObs(kind: .thermalReadingObserved,
                    subject: "thermal.nominal"),
                leaseLifeObs(kind: .deviceRouteSelected,
                    subject: "device.hybridLocal"),
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .leaseLife)
        XCTAssertEqual(s.turnID, "t.l1")
        XCTAssertEqual(s.sessionID, "s.l1")
        XCTAssertEqual(s.emittedAt, t0)
        XCTAssertEqual(s.totalObservations, 4)
        XCTAssertEqual(
            s.distinctSubjectCount, 4,
            "4 distinct subject IDs")
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "baseline grants + runMode + thermal + device = healthy L1")
        XCTAssertEqual(
            s.budgetTotalCost,
            BASLeaseLifeSignalBudget.totalCost(for: bundle),
            accuracy: 1e-9,
            "byte-equal budget delegation")
    }

    func testLeaseLifeProjectionMissingBaselineIsNotCore() {
        // Only leaseGranted + runModeDetermined; missing thermal +
        // device → hasCoreSignalCoverage must be false.
        let bundle = BASLeaseLifeObservationBundle(
            turnID: "t.l1.partial",
            sessionID: "s.l1",
            observations: [
                leaseLifeObs(kind: .leaseGranted,
                    subject: "lease.a"),
                leaseLifeObs(kind: .runModeDetermined,
                    subject: "run.engage"),
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertFalse(s.hasCoreSignalCoverage)
        XCTAssertEqual(s.distinctSubjectCount, 2)
    }

    // MARK: - L2 NeuralOrgan

    func testNeuralOrganProjectionCarriesLayerAndFields() {
        let bundle = BASNeuralOrganObservationBundle(
            turnID: "t.l2",
            sessionID: "s.l2",
            observations: [
                neuralOrganObs(kind: .organMapSealed,
                    subject: "morph.scout"),
                neuralOrganObs(kind: .organActive,
                    subject: "organ.coreCortex"),
                neuralOrganObs(kind: .routingPolicyApplied,
                    subject: "policy.hotColdMorph"),
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .neuralOrgan)
        XCTAssertEqual(s.turnID, "t.l2")
        XCTAssertEqual(s.sessionID, "s.l2")
        XCTAssertEqual(s.totalObservations, 3)
        XCTAssertEqual(
            s.distinctSubjectCount, 3,
            "3 distinct L2 subject IDs")
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "organ map sealed ⇒ hasCoreSignalCoverage")
        XCTAssertEqual(
            s.budgetTotalCost,
            BASNeuralOrganSignalBudget.totalCost(for: bundle),
            accuracy: 1e-9)
    }

    func testNeuralOrganProjectionEmptyBundleIsNotCore() {
        let bundle = BASNeuralOrganObservationBundle(
            turnID: "t.l2.empty",
            sessionID: "s.l2",
            observations: [],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.totalObservations, 0)
        XCTAssertEqual(s.distinctSubjectCount, 0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "empty bundle has no mapSealed signal")
        XCTAssertEqual(s.budgetTotalCost, 0, accuracy: 1e-9)
    }

    // MARK: - L5 HostConstitution

    func testHostConstitutionProjectionCarriesLayerAndFields() {
        let bundle = BASHostConstitutionObservationBundle(
            turnID: "t.l5",
            sessionID: "s.l5",
            observations: [
                hostConstitutionObs(kind: .anchorActive,
                    subject: "anchor.identity"),
                hostConstitutionObs(kind: .anchorActive,
                    subject: "anchor.value"),
                hostConstitutionObs(kind: .versionCommitted,
                    subject: "version.v1"),
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .hostConstitution)
        XCTAssertEqual(s.turnID, "t.l5")
        XCTAssertEqual(s.sessionID, "s.l5")
        XCTAssertEqual(s.totalObservations, 3)
        XCTAssertEqual(
            s.distinctSubjectCount, 3,
            "3 distinct governance subjects")
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "at least one anchor ⇒ hasAnyAnchor true")
        XCTAssertEqual(
            s.budgetTotalCost,
            BASHostConstitutionSignalBudget.totalCost(for: bundle),
            accuracy: 1e-9)
    }

    func testHostConstitutionProjectionNoAnchorIsNotCore() {
        let bundle = BASHostConstitutionObservationBundle(
            turnID: "t.l5.no-anchor",
            sessionID: "s.l5",
            observations: [
                hostConstitutionObs(kind: .versionCommitted,
                    subject: "version.v2"),
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "version commit without anchor ⇒ not core")
    }

    // MARK: - Round-trip into BASObservationReconciliationReport

    /// A full 3-layer (L1 + L2 + L5) report round-trips its
    /// per-layer identity cleanly — this is the shape Qinao will
    /// feed into `recordTurnCoverage(additionalSummaries:)` at the
    /// QinaoRuntime.sendSession choke-point.
    func testThreeLayerReportCarriesDistinctLayerIdentities() {
        let l1 = BASLeaseLifeObservationBundle(
            turnID: "t.x",
            sessionID: "s.x",
            observations: [
                leaseLifeObs(kind: .leaseGranted,
                    subject: "lease.x"),
            ],
            emittedAt: t0)
        let l2 = BASNeuralOrganObservationBundle(
            turnID: "t.x",
            sessionID: "s.x",
            observations: [
                neuralOrganObs(kind: .organMapSealed,
                    subject: "morph.scout"),
            ],
            emittedAt: t0)
        let l5 = BASHostConstitutionObservationBundle(
            turnID: "t.x",
            sessionID: "s.x",
            observations: [
                hostConstitutionObs(kind: .anchorActive,
                    subject: "anchor.identity"),
            ],
            emittedAt: t0)

        let report = BASObservationReconciliationReport(
            turnID: "t.x",
            sessionID: "s.x",
            summaries: [
                l1.coverageSummary,
                l2.coverageSummary,
                l5.coverageSummary,
            ])
        XCTAssertEqual(
            report.summaries.map(\.layer),
            [.leaseLife, .neuralOrgan, .hostConstitution])
        XCTAssertEqual(report.summaries.count, 3)
    }
}
