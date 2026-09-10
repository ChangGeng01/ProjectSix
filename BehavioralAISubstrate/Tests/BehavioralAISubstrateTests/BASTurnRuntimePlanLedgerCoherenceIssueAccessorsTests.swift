// MARK: - BASTurnRuntimePlanLedgerCoherenceIssueAccessorsTests
// chapter 四百十九 / M1048

import XCTest
@testable import BASHostKit

final class BASTurnRuntimePlanLedgerCoherenceIssueAccessorsTests:
    XCTestCase
{

    private func planForStages(
        _ stages: [BASTurnRuntimeStage]
    ) -> BASTurnRuntimeStagePlan {
        BASTurnRuntimeStagePlan(
            steps: stages.map { .sequential($0) })
    }

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

    // MARK: - coherenceIssueCount

    func testCoherenceIssueCountZeroWhenIdentical() {
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: planForStages([.stageA, .stageB]),
            ledger: ledgerForStages([.stageA, .stageB]))
        XCTAssertEqual(
            coherence.coherenceIssueCount, 0)
    }

    func testCoherenceIssueCountReflectsIssueList() {
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: planForStages([.stageA, .stageB]),
            ledger: ledgerForStages([.stageC]))
        XCTAssertEqual(
            coherence.coherenceIssueCount,
            coherence.coherenceIssues().count)
        XCTAssertGreaterThan(
            coherence.coherenceIssueCount, 0)
    }

    // MARK: - firstIssue

    func testFirstIssueNilWhenCoherent() {
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: planForStages([.stageA]),
            ledger: ledgerForStages([.stageA]))
        XCTAssertNil(coherence.firstIssue)
    }

    func testFirstIssueMatchesFirstInIssuesList() {
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: planForStages([.stageA]),
            ledger: ledgerForStages([.stageB]))
        XCTAssertNotNil(coherence.firstIssue)
        XCTAssertEqual(
            coherence.firstIssue,
            coherence.coherenceIssues().first)
    }

    // MARK: - Determinism

    func testAccessorsAreDeterministic() {
        let coherence = BASTurnRuntimePlanLedgerCoherence(
            plan: planForStages([.stageA]),
            ledger: ledgerForStages([.stageB]))
        XCTAssertEqual(
            coherence.coherenceIssueCount,
            coherence.coherenceIssueCount)
        XCTAssertEqual(
            coherence.firstIssue,
            coherence.firstIssue)
    }
}
