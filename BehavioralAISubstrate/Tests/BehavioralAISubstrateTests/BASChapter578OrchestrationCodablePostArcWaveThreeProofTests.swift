// MARK: - BASChapter578OrchestrationCodablePostArcWaveThreeProofTests
// chapter 五百七十八 / M1690 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration types shipped
//                          at M1689 (post-arc wave 3
//                          to chapter 574 BAS
//                          Orchestration arc seal)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-arc wave 3 follow-up to the BASOrchestration
// Codable extension arc。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1689 → M1690

import XCTest
@testable import BASOrchestration

final class BASChapter578OrchestrationCodablePostArcWaveThreeProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testNeuralPublicThoughtProjectionConformsToCodable() {
        assertCodable(BASNeuralPublicThoughtProjection.self)
    }

    func testSoftHandModeSelectorSelectionResultConformsToCodable() {
        assertCodable(
            BASSoftHandModeSelector.SelectionResult.self)
    }
}
