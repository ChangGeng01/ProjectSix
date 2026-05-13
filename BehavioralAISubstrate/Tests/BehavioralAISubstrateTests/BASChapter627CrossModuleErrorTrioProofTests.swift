// MARK: - BASChapter627CrossModuleErrorTrioProofTests
// chapter 六百二十七 / M1886 — PROOF tests for the M1885
//                              cross-module error trio
//                              Codable extension (6TH
//                              post-hexa-#2 gap-fill —
//                              triggers hexa #3 at ch628)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module error trio — 3 Error enums across 2
// modules:
//
//   BASAppleAdapters:
//     - BASAppleCurrentBrainBootstrapHostResolutionError
//
//   BASSovereign (nested-in-actor):
//     - BASSovereignAuditLedger.LedgerError
//     - BASSovereignKeychainBinding.KeychainError
//
// SIXTH post-hexa-#2 gap-fill chapter (622-627) —
// TRIGGERS chapter 628 hexa #3 catalog opportunity!
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 621 hexa #2 + 622-626 prior post-hexa-#2
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1885 → M1886

import XCTest
@testable import BASAppleAdapters
@testable import BASSovereign

final class BASChapter627CrossModuleErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASAppleCurrentBrainBootstrapHostResolutionErrorConformsToCodable() {
        assertCodable(
            BASAppleCurrentBrainBootstrapHostResolutionError.self)
    }

    func testLedgerErrorConformsToCodable() {
        assertCodable(
            BASSovereignAuditLedger.LedgerError.self)
    }

    func testKeychainErrorConformsToCodable() {
        assertCodable(
            BASSovereignKeychainBinding.KeychainError.self)
    }
}
