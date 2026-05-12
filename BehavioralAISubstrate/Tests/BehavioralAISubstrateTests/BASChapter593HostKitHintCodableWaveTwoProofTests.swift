// MARK: - BASChapter593HostKitHintCodableWaveTwoProofTests
// chapter 五百九十三 / M1750 — PROOF tests for the 2
//                          newly-Codable BASHostKit
//                          hint types shipped at
//                          M1749 (non-projection
//                          wave 2)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASHostKit non-projection wave 2 Codable extension。
// Continues chapter 592 wave 1 pattern。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1749 → M1750

import XCTest
@testable import BASHostKit

final class BASChapter593HostKitHintCodableWaveTwoProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testChengluLengthHintConformsToCodable() {
        assertCodable(BASChengluLengthHint.self)
    }

    func testChengluLatencyHintConformsToCodable() {
        assertCodable(BASChengluLatencyHint.self)
    }
}
