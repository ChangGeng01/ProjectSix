// MARK: - BASTurnRuntimePlanLedgerCoherenceCanonicalTests
// chapter 四百十八 / M1044

import XCTest
@testable import BASHostKit

final class BASTurnRuntimePlanLedgerCoherenceCanonicalTests:
    XCTestCase
{

    // MARK: - Empty ledger flagged as planStagesNotInLedger

    func testEmptyLedgerFlagsCanonicalPlanStagesMissing() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        let coherence = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        XCTAssertFalse(coherence.isFullyCoherent)
        var found = false
        for issue in coherence.coherenceIssues() {
            if case let .planStagesNotInLedger(
                missing) = issue
            {
                XCTAssertEqual(
                    missing.count,
                    BASTurnRuntimeStage.allCases.count,
                    "all canonical stages should be" +
                    " missing")
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Full canonical-order ledger is coherent

    func testFullCanonicalOrderLedgerIsCoherent() {
        var ledger = BASTurnRuntimeStageLedger.empty()
        let canonical = BASTurnRuntimeStagePlan.canonical()
        for stage in canonical.orderedStages {
            ledger = ledger.appending(
                record: .completed(stage, durationMs: 1))
        }
        let coherence = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        XCTAssertTrue(coherence.isFullyCoherent,
            "ledger executing canonical order matches plan")
    }

    // MARK: - Reversed canonical-order flags orderMismatch

    func testReversedCanonicalOrderFlagsMismatch() {
        var ledger = BASTurnRuntimeStageLedger.empty()
        let canonical = BASTurnRuntimeStagePlan.canonical()
        for stage in canonical.orderedStages.reversed() {
            ledger = ledger.appending(
                record: .completed(stage, durationMs: 1))
        }
        let coherence = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        var found = false
        for issue in coherence.coherenceIssues() {
            if case .orderMismatch(_, _) = issue {
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Determinism

    func testCanonicalCoherenceIsDeterministic() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        let a = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        let b = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        XCTAssertEqual(a, b)
        XCTAssertEqual(
            a.coherenceIssues(), b.coherenceIssues())
    }
}
