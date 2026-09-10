// MARK: - BASChapter572OrchestrationCodableSecondWaveProofTests
// chapter 五百七十二 / M1666 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration decision
//                          types shipped at M1665
//
// ## Coverage (2 compile-time conformance tests)
//
// Second wave of BASOrchestration Codable extension。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1665 → M1666

import XCTest
@testable import BASOrchestration
@testable import BASPolicy

final class BASChapter572OrchestrationCodableSecondWaveProofTests:
    XCTestCase
{

    func testKunlunPermitEscalationDecisionConformsToCodable()
    {
        // #18: real round-trip
        let decision = BASKunlunPermitEscalationDecision(
            permit: BASActionPermit(mode: .answer),
            reasonCodes: [],
            suppressedByHumanAnchor: false,
            triggered: false)
        assertCodableRoundTrips(decision)
    }

    func testForbiddenCandidateZoneGateDecisionConformsToCodable()
    {
        // #18: real round-trip
        let decision = BASForbiddenCandidateZoneGateDecision(
            denied: false,
            reasonCodes: [],
            wasQuarantined: false,
            releaseConditionsMet: false)
        assertCodableRoundTrips(decision)
    }
}
