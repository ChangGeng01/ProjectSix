// MARK: - BASChapter636WorldPriorCoreMLErrorTrioProofTests
// chapter 六百三十六 / M1922 — PROOF tests for the M1921
//                              cross-module BASWorldPrior
//                              + BASAppleAdapters error
//                              trio Codable extension
//                              (1st post-hexa-#4 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module error trio gap-fill — 3 Error enums
// across 2 modules:
//
//   BASWorldPrior (nested-in-actor):
//     - BASWorldPriorVault.VaultError (8-case)
//     - BASWorldPriorCounterfactualSeeder.SeederError
//       (1-case)
//
//   BASAppleAdapters (top-level):
//     - BASCoreMLAdapterError (1-case)
//
// FIRST post-hexa-#4 gap-fill chapter。 FIRST
// BASWorldPrior touch in ANY hexa cycle — module was
// untouched in hexa #1+#2+#3+#4 cycles。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 635 hexa #4 catalog seal precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1921 → M1922

import XCTest
@testable import BASWorldPrior
@testable import BASAppleAdapters

final class BASChapter636WorldPriorCoreMLErrorTrioProofTests:
    XCTestCase
{

    func testBASWorldPriorVaultVaultErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASWorldPriorVault.VaultError
                .duplicateTemplateID(""))
        assertCodableRoundTrips(
            BASWorldPriorVault.VaultError
                .axiomCollision(id: "", incoming: "", resident: ""))
    }

    func testBASWorldPriorCounterfactualSeederSeederErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASWorldPriorCounterfactualSeeder.SeederError
                .unknownTemplate(""))
    }

    func testBASCoreMLAdapterErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASCoreMLAdapterError
                .multiArrayConstructionFailed(expectedShape: []))
    }
}
