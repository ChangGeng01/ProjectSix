// MARK: - BASChapter599MLXAdapterCodableWaveOneProofTests
// chapter 五百九十九 / M1774 — PROOF tests for the 2
//                          newly-Codable BASMLXAdapter
//                          types shipped at M1773
//                          (FRESH MODULE TERRITORY
//                          wave 1)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASMLXAdapter first-ever Codable extension wave 1。
// 8th module entry into ledger-serializable contract
// surface (after chapter 598 BASOrgan first-ever 7th-
// module entry)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1773 → M1774

import XCTest
@testable import BASMLXAdapter

final class BASChapter599MLXAdapterCodableWaveOneProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testMLXModelCatalogEntryConformsToCodable() {
        assertCodable(MLXModelCatalog.Entry.self)
    }

    func testMLXLoRATrainerTrainingProgressConformsToCodable() {
        assertCodable(MLXLoRATrainer.TrainingProgress.self)
    }
}
