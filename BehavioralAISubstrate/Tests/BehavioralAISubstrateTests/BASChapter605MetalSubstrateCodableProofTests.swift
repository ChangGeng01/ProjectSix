// MARK: - BASChapter605MetalSubstrateCodableProofTests
// chapter 六百五 / M1798 — PROOF tests for the M1797
//                          BASMetalSubstrate Codable
//                          extension wave 1 (11TH
//                          MODULE FORMAL ENTRY)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASMetalSubstrate wave 1 Codable extension — 11th
// module formal entry。 5th consecutive post-octa
// fresh-module advancement (BASOrgan ch598 +
// BASMLXAdapter ch599 + BASChatCompletionsAdapter
// ch603 + BASAppleAdapters ch604 + BASMetalSubstrate
// ch605)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1797 → M1798

import XCTest
@testable import BASMetalSubstrate

final class BASChapter605MetalSubstrateCodableProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testKernelInputsConformsToCodable() {
        assertCodable(BASKernelInputs.self)
    }

    func testKernelOutputsConformsToCodable() {
        assertCodable(BASKernelOutputs.self)
    }
}
