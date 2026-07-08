// MARK: - BASChapter630MetalBiomimeticErrorTrioProofTests
// chapter 六百三十 / M1898 — PROOF tests for the M1897
//                            BASMetalSubstrate
//                            biomimetic error trio
//                            Codable extension (2nd
//                            post-hexa-#3 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASMetalSubstrate biomimetic error trio gap-fill —
// 3 Error enums (different domain than chapter 626's
// metal-error-trio):
//
//   - BASBiomimeticSnapshotError
//   - BASPlasticityError
//   - BASPredictiveCodingError
//
// SECOND post-hexa-#3 gap-fill chapter (629 + 630)。
// NEW kind 'metal-biomimetic-error-trio'。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1897 → M1898

import XCTest
@testable import BASMetalSubstrate

final class BASChapter630MetalBiomimeticErrorTrioProofTests:
    XCTestCase
{

    func testBASBiomimeticSnapshotErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBiomimeticSnapshotError.shapeMismatch(reason: ""))
    }

    func testBASPlasticityErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASPlasticityError.shapeMismatch(reason: ""))
        assertCodableRoundTrips(
            BASPlasticityError.gpuUnavailable(reason: ""))
    }

    func testBASPredictiveCodingErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASPredictiveCodingError.shapeMismatch(reason: ""))
    }
}
