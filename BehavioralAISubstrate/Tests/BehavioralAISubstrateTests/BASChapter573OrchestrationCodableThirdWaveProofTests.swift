// MARK: - BASChapter573OrchestrationCodableThirdWaveProofTests
// chapter 五百七十三 / M1670 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration value types
//                          shipped at M1669
//
// ## Coverage (2 compile-time conformance tests)
//
// Third wave of BASOrchestration Codable extension。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1669 → M1670

import XCTest
@testable import BASOrchestration

final class BASChapter573OrchestrationCodableThirdWaveProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testLatentTissueStateConformsToCodable() {
        assertCodable(BASLatentTissueState.self)
    }

    func testBadToneLinterViolationConformsToCodable() {
        assertCodable(BASBadToneLinter.Violation.self)
    }
}
