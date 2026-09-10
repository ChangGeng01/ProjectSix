// MARK: - BASChapter594HostKitHintCodableWaveThreeProofTests
// chapter 五百九十四 / M1754 — PROOF tests for the 2
//                          newly-Codable BASHostKit
//                          hint types shipped at
//                          M1753 (non-projection
//                          wave 3)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASHostKit non-projection wave 3 Codable extension。
// Continues chapter 592 + 593 pattern;completes
// hint-type coverage so BASChengluHintSet aggregator
// can become Codable at chapter 595。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1753 → M1754

import XCTest
@testable import BASHostKit

final class BASChapter594HostKitHintCodableWaveThreeProofTests:
    XCTestCase
{

    func testChengluMultiHeadHintConformsToCodable() {
        // #18: real round-trip
        let value = BASChengluMultiHeadHint(
            outputKey: "",
            score: 0.0,
            confidence: .high)
        assertCodableRoundTrips(value)
    }

    func testChengluPermitPredictHintConformsToCodable() {
        // #18: real round-trip
        let value = BASChengluPermitPredictHint(
            policy: .block,
            blockProbability: 0.0,
            confidence: .high)
        assertCodableRoundTrips(value)
    }
}
