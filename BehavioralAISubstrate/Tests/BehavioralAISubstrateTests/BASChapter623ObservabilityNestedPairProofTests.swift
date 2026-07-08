// MARK: - BASChapter623ObservabilityNestedPairProofTests
// chapter 六百二十三 / M1870 — PROOF tests for the M1869
//                              BASObservability nested-
//                              in-actor pair Codable
//                              extension (2nd post-hexa-
//                              #2 gap-fill)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASObservability nested-in-actor pair gap-fill — 2
// enums within BASUpdateTicketLifecycleCoordinator:
//
//   - LifecycleError (3-case error enum)
//   - TrialOutcome (3-case outcome enum)
//
// SECOND post-hexa-#2 gap-fill chapter (622 + 623)。
// NEW kind 'nested-in-actor-pair' distinct from
// chapter 622's 'cross-module-trio'。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 614 + 621 gap-fill hexa precedents
//   - chapter 622 1st post-hexa-#2 precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1869 → M1870

import XCTest
@testable import BASObservability

final class BASChapter623ObservabilityNestedPairProofTests:
    XCTestCase
{

    func testLifecycleErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASUpdateTicketLifecycleCoordinator
                .LifecycleError.unknownTicket(id: ""))
    }

    func testTrialOutcomeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASUpdateTicketLifecycleCoordinator
                .TrialOutcome.passed(reasonCodes: []))
    }
}
