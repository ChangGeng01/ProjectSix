// MARK: - BASChapter609OrganCodableWaveTwoProofTests
// chapter 六百九 / M1814 — PROOF test for the M1813
//                          BASOrgan Codable extension
//                          wave 2 (gap-fill)
//
// ## Coverage (1 compile-time conformance test)
//
// BASOrgan wave 2 gap-fill — BASOrganCapacity becomes
// Codable, extending the chapter 598 wave 1 first-
// ever coverage。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     this newly-Codable type
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1813 → M1814

import XCTest
@testable import BASOrgan

final class BASChapter609OrganCodableWaveTwoProofTests:
    XCTestCase
{

    func testOrganCapacityConformsToCodable() {
        // #18: real round-trip
        let value = BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: false)
        assertCodableRoundTrips(value)
    }
}
