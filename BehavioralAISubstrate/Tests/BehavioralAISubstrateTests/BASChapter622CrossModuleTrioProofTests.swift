// MARK: - BASChapter622CrossModuleTrioProofTests
// chapter 六百二十二 / M1866 — PROOF tests for the M1865
//                              cross-module trio Codable
//                              extension (1st post-hexa-#2
//                              gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module trio gap-fill — 3 types across 2 modules:
//
//   BASOrchestration:
//     - BASPromptStateValue (3-case enum:string +
//       integer + boolean)
//
//   BASHostKit:
//     - BASTurnRuntimePlanLedgerCoherence (2-field struct)
//     - BASTurnRuntimePlanLedgerCoherenceIssue (3-case
//       enum)
//
// FIRST post-hexa-#2 gap-fill chapter — begins 3rd hexa
// run toward chapter 627 hexa #3 opportunity。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 621 gap-fill hexa #2 precedent
//   - chapter 614 gap-fill hexa #1 precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1865 → M1866

import XCTest
@testable import BASOrchestration
@testable import BASHostKit

final class BASChapter622CrossModuleTrioProofTests:
    XCTestCase
{

    func testBASPromptStateValueConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(BASPromptStateValue.string(""))
        assertCodableRoundTrips(BASPromptStateValue.integer(0))
        assertCodableRoundTrips(BASPromptStateValue.boolean(false))
    }

    func testBASTurnRuntimePlanLedgerCoherenceConformsToCodable() {
        // #18: real round-trip — minimal instance (empty plan + empty ledger)
        let instance = BASTurnRuntimePlanLedgerCoherence(
            plan: BASTurnRuntimeStagePlan(),
            ledger: BASTurnRuntimeStageLedger())
        assertCodableRoundTrips(instance)
    }

    func testBASTurnRuntimePlanLedgerCoherenceIssueConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASTurnRuntimePlanLedgerCoherenceIssue
                .planStagesNotInLedger([]))
    }
}
