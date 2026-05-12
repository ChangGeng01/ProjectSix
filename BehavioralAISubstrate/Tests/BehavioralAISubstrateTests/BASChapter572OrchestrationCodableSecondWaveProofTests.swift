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

final class BASChapter572OrchestrationCodableSecondWaveProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testKunlunPermitEscalationDecisionConformsToCodable()
    {
        assertCodable(
            BASKunlunPermitEscalationDecision.self)
    }

    func testForbiddenCandidateZoneGateDecisionConformsToCodable()
    {
        assertCodable(
            BASForbiddenCandidateZoneGateDecision.self)
    }
}
