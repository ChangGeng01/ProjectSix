// MARK: - BASChapter633SovereignErrorTrioProofTests
// chapter 六百三十三 / M1910 — PROOF tests for the M1909
//                              BASSovereign error trio
//                              Codable extension (5th
//                              post-hexa-#3 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign error trio gap-fill — 3 Error enums all
// nested within BASSovereign struct/actor types:
//
//   BASSovereign (nested):
//     - BASSovereignHostVersionTree.TreeError
//     - BASSovereignFingerprintStore.StoreError
//     - BASSovereignTokenAuthority.AuthorityError
//
// FIFTH post-hexa-#3 gap-fill chapter (629-633)。
// FIRST BASSovereign post-hexa-#3 touch — module
// previously untouched in the hexa #3 catalog cycle。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 + 629-632 prior post-hexa-#3
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1909 → M1910

import XCTest
@testable import BASSovereign

final class BASChapter633SovereignErrorTrioProofTests:
    XCTestCase
{

    func testTreeErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignHostVersionTree.TreeError
                .unknownVersion(id: ""))
        assertCodableRoundTrips(
            BASSovereignHostVersionTree.TreeError
                .cycle(at: ""))
    }

    func testStoreErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignFingerprintStore.StoreError
                .manifestMalformed(reason: ""))
        assertCodableRoundTrips(
            BASSovereignFingerprintStore.StoreError
                .rootSignatureInvalid)
    }

    func testAuthorityErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignTokenAuthority.AuthorityError
                .invalidIntent(""))
        assertCodableRoundTrips(
            BASSovereignTokenAuthority.AuthorityError
                .expired(tokenID: ""))
    }
}
