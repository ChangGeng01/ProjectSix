// MARK: - BASTurnRuntimePlanLedgerCoherenceTests — chapter 四百十八 / M1043

import XCTest
@testable import BASHostKit

final class BASTurnRuntimePlanLedgerCoherenceTests:
    XCTestCase
{

    private func ledgerForStages(
        _ stages: [BASTurnRuntimeStage]
    ) -> BASTurnRuntimeStageLedger {
        var ledger = BASTurnRuntimeStageLedger.empty()
        for stage in stages {
            ledger = ledger.appending(
                record: .completed(stage, durationMs: 1))
        }
        return ledger
    }

    private func planForStages(
        _ stages: [BASTurnRuntimeStage]
    ) -> BASTurnRuntimeStagePlan {
        BASTurnRuntimeStagePlan(
            steps: stages.map {
                .sequential($0)
            })
    }

    // MARK: - Identical plan + ledger → fully coherent

    func testIdenticalPlanLedgerIsCoherent() {
        let plan = planForStages([.stageA, .stageB])
        let ledger = ledgerForStages([.stageA, .stageB])
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        XCTAssertTrue(coherence.isFullyCoherent)
        XCTAssertTrue(
            coherence.coherenceIssues().isEmpty)
    }

    // MARK: - Plan stages missing from ledger flagged

    func testPlanStagesMissingFromLedgerFlagged() {
        let plan = planForStages([.stageA, .stageB, .stageC])
        let ledger = ledgerForStages([.stageA, .stageB])
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        var found = false
        for issue in coherence.coherenceIssues() {
            if case let .planStagesNotInLedger(
                missing) = issue
            {
                XCTAssertEqual(missing, [.stageC])
                found = true
            }
        }
        XCTAssertTrue(found)
        XCTAssertFalse(coherence.isFullyCoherent)
    }

    // MARK: - Ledger stages missing from plan flagged

    func testLedgerStagesMissingFromPlanFlagged() {
        let plan = planForStages([.stageA])
        let ledger = ledgerForStages([.stageA, .stageB])
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        var found = false
        for issue in coherence.coherenceIssues() {
            if case let .ledgerStagesNotInPlan(
                extra) = issue
            {
                XCTAssertEqual(extra, [.stageB])
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Order mismatch flagged

    func testOrderMismatchFlagged() {
        let plan = planForStages([.stageA, .stageB])
        let ledger = ledgerForStages([.stageB, .stageA])
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        var found = false
        for issue in coherence.coherenceIssues() {
            if case let .orderMismatch(
                planOrder: p, ledgerOrder: l) = issue
            {
                XCTAssertEqual(p, [.stageA, .stageB])
                XCTAssertEqual(l, [.stageB, .stageA])
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Determinism

    func testCoherenceIssuesIsDeterministic() {
        let plan = planForStages([.stageA, .stageB])
        let ledger = ledgerForStages([.stageA, .stageC])
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        XCTAssertEqual(
            coherence.coherenceIssues(),
            coherence.coherenceIssues())
    }

    // MARK: - Empty plan + empty ledger is coherent

    func testEmptyPlanEmptyLedgerIsCoherent() {
        let plan = BASTurnRuntimeStagePlan()
        let ledger = BASTurnRuntimeStageLedger.empty()
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: plan, ledger: ledger)
        XCTAssertTrue(coherence.isFullyCoherent)
    }
}
