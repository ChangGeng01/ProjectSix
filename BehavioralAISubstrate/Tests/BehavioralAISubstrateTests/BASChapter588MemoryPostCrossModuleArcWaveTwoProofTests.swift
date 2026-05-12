// MARK: - BASChapter588MemoryPostCrossModuleArcWaveTwoProofTests
// chapter 五百八十八 / M1730 — PROOF tests for the 2
//                          newly-Codable BASMemory
//                          types shipped at M1729
//                          (post-cross-module-arc
//                          wave 2)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-cross-module-arc BASMemory wave 2 Codable
// extension。 Continues chapter 587 wave 1 in the
// beyond-M1700 narrative arc。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1729 → M1730

import XCTest
@testable import BASMemory

final class BASChapter588MemoryPostCrossModuleArcWaveTwoProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testHostCandidatePipelineRejectionRecordConformsToCodable() {
        assertCodable(
            BASHostCandidatePipeline.RejectionRecord.self)
    }

    func testMemoryMutationEventEmitterEmitOutcomeConformsToCodable() {
        assertCodable(
            BASMemoryMutationEventEmitter.EmitOutcome.self)
    }
}
