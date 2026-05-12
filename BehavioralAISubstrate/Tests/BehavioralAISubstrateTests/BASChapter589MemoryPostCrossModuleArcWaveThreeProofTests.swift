// MARK: - BASChapter589MemoryPostCrossModuleArcWaveThreeProofTests
// chapter 五百八十九 / M1734 — PROOF tests for the 2
//                          newly-Codable BASMemory
//                          types shipped at M1733
//                          (post-cross-module-arc
//                          wave 3)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-cross-module-arc BASMemory wave 3 Codable
// extension。 Completes 3-wave BASMemory post-arc
// trilogy。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1733 → M1734

import XCTest
@testable import BASMemory

final class BASChapter589MemoryPostCrossModuleArcWaveThreeProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testMemoryImportanceScorerConformsToCodable() {
        assertCodable(BASMemoryImportanceScorer.self)
    }

    func testMemoryMutationWriterMutationOutcomeConformsToCodable() {
        assertCodable(
            BASMemoryMutationWriter.MutationOutcome.self)
    }
}
