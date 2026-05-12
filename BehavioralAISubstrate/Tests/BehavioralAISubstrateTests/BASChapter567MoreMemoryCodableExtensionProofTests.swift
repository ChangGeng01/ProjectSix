// MARK: - BASChapter567MoreMemoryCodableExtensionProofTests
// chapter 五百六十七 / M1646 — PROOF tests for the 5
//                          newly-Codable BASMemory
//                          types shipped at M1645
//
// ## Coverage (5 compile-time conformance tests)
//
// Compile-time conformance checks for:
//   - BASConstitutionMatch
//   - BASMemoryClosedLoopApplyOutcome
//   - BASEvolutionPromotionGateVerdict
//   - BASPreparedMemoryGovernanceDraft
//   - BASShadowTrialLedgerEntry
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 5 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1645 → M1646

import XCTest
@testable import BASMemory

final class BASChapter567MoreMemoryCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - Compile-time conformance helper

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    // MARK: - 5 compile-time conformance PROOFs

    func testConstitutionMatchConformsToCodable() {
        assertCodable(BASConstitutionMatch.self)
    }

    func testMemoryClosedLoopApplyOutcomeConformsToCodable()
    {
        assertCodable(
            BASMemoryClosedLoopApplyOutcome.self)
    }

    func testEvolutionPromotionGateVerdictConformsToCodable()
    {
        assertCodable(
            BASEvolutionPromotionGateVerdict.self)
    }

    func testPreparedMemoryGovernanceDraftConformsToCodable()
    {
        assertCodable(
            BASPreparedMemoryGovernanceDraft.self)
    }

    func testShadowTrialLedgerEntryConformsToCodable() {
        assertCodable(BASShadowTrialLedgerEntry.self)
    }
}
