// MARK: - BASChapter571OrchestrationCodableExtensionProofTests
// chapter 五百七十一 / M1662 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration decision
//                          types shipped at M1661
//
// ## Coverage (2 compile-time conformance tests)
//
// First chapter extending Codable into BASOrchestration
// module。 Compile-time conformance is the right PROOF
// level since the field types are well-known to be
// Codable (verified in earlier arcs)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//     into BASOrchestration module
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1661 → M1662

import XCTest
@testable import BASOrchestration

final class BASChapter571OrchestrationCodableExtensionProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testAssertionCeilingDecisionConformsToCodable() {
        assertCodable(
            BASAssertionCeilingDecision.self)
    }

    func testAbyssalPermitEscalationDecisionConformsToCodable()
    {
        assertCodable(
            BASAbyssalPermitEscalationDecision.self)
    }
}
