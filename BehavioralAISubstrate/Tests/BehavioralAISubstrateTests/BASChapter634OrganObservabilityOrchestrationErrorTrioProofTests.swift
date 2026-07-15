// MARK: - BASChapter634OrganObservabilityOrchestrationErrorTrioProofTests
// chapter 六百三十四 / M1914 — PROOF tests for the M1913
//                              cross-module BASOrgan/
//                              BASObservability/
//                              BASOrchestration error
//                              trio Codable extension
//                              (6th post-hexa-#3 gap-
//                              fill — final before hexa
//                              #4 catalog opportunity)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module error trio gap-fill — 3 Error enums
// across 3 distinct modules:
//
//   BASOrgan (top-level):
//     - BASToolDispatchError (4-case)
//
//   BASObservability (nested-in-class):
//     - BASUpdateTicketLifecycleSQLiteStorage.SQLiteError
//       (7-case)
//
//   BASOrchestration (nested-in-actor):
//     - BASWorldAwareRiskBridge.BridgeError (1-case)
//
// SIXTH post-hexa-#3 gap-fill chapter (629-634)。
// FINAL gap-fill before chapter 635 hexa #4 catalog
// opportunity。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 + 629-633 prior post-hexa-#3
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1913 → M1914

import XCTest
@testable import BASOrgan
@testable import BASObservability
@testable import BASOrchestration

final class BASChapter634OrganObservabilityOrchestrationErrorTrioProofTests:
    XCTestCase
{

    func testBASToolDispatchErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASToolDispatchError.noHandlerRegistered(toolName: ""))
        assertCodableRoundTrips(
            BASToolDispatchError.timeoutExceeded(
                toolName: "", deadlineMs: 0))
    }

    func testBASUpdateTicketLifecycleSQLiteStorageSQLiteErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASUpdateTicketLifecycleSQLiteStorage.SQLiteError
                .openFailed(reason: ""))
        assertCodableRoundTrips(
            BASUpdateTicketLifecycleSQLiteStorage.SQLiteError
                .prepareFailed(sql: "", reason: ""))
    }

    func testBASWorldAwareRiskBridgeBridgeErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASWorldAwareRiskBridge.BridgeError
                .unknownTemplate(""))
    }
}
