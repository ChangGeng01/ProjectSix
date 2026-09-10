// MARK: - BASChapter595HostKitHintCodableWaveFourProofTests
// chapter 五百九十五 / M1758 — PROOF tests for the 2
//                          newly-Codable BASHostKit
//                          types shipped at M1757
//                          (wave 4 culmination)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASHostKit non-projection wave 4 CULMINATION
// Codable extension。 BASChengluHintSet aggregator
// composes all 5 individual Chenglu hint types from
// waves 1-3。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1757 → M1758

import XCTest
@testable import BASHostKit

final class BASChapter595HostKitHintCodableWaveFourProofTests:
    XCTestCase
{

    func testChengluHintSetConformsToCodable() {
        // #18: real round-trip (all-nil aggregate = the empty set)
        assertCodableRoundTrips(BASChengluHintSet.empty)
    }

    func testTrainingDataExportFilterConformsToCodable() {
        // #18: real round-trip (all-default filter = export everything)
        assertCodableRoundTrips(BASTrainingDataExportFilter.all)
    }
}
