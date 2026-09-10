// MARK: - BASTurnRuntimePlanLedgerCoherenceIssueTests — chapter 四百十八 / M1042

import XCTest
@testable import BASHostKit

final class BASTurnRuntimePlanLedgerCoherenceIssueTests:
    XCTestCase
{

    // MARK: - All 3 cases construct cleanly

    func testPlanStagesNotInLedgerCase() {
        let issue = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA, .stageB])
        if case let .planStagesNotInLedger(stages) = issue {
            XCTAssertEqual(stages, [.stageA, .stageB])
        } else {
            XCTFail("expected .planStagesNotInLedger")
        }
    }

    func testLedgerStagesNotInPlanCase() {
        let issue = BASTurnRuntimePlanLedgerCoherenceIssue
            .ledgerStagesNotInPlan([.stageC])
        if case let .ledgerStagesNotInPlan(stages) = issue {
            XCTAssertEqual(stages, [.stageC])
        } else {
            XCTFail("expected .ledgerStagesNotInPlan")
        }
    }

    func testOrderMismatchCase() {
        let issue = BASTurnRuntimePlanLedgerCoherenceIssue
            .orderMismatch(
                planOrder: [.stageA, .stageB],
                ledgerOrder: [.stageB, .stageA])
        if case let .orderMismatch(plan, ledger) = issue {
            XCTAssertEqual(plan, [.stageA, .stageB])
            XCTAssertEqual(ledger, [.stageB, .stageA])
        } else {
            XCTFail("expected .orderMismatch")
        }
    }

    // MARK: - Equatable + Hashable contract

    func testEqualIssuesEqual() {
        let a = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA])
        let b = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA])
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testDifferentIssueCasesAreNotEqual() {
        let a = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA])
        let b = BASTurnRuntimePlanLedgerCoherenceIssue
            .ledgerStagesNotInPlan([.stageA])
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Determinism

    func testIssueConstructionIsDeterministic() {
        let a = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA, .stageB])
        let b = BASTurnRuntimePlanLedgerCoherenceIssue
            .planStagesNotInLedger([.stageA, .stageB])
        XCTAssertEqual(a, b)
    }
}
