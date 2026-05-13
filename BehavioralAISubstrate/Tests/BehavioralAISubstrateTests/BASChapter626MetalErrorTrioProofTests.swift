// MARK: - BASChapter626MetalErrorTrioProofTests
// chapter 六百二十六 / M1882 — PROOF tests for the M1881
//                              BASMetalSubstrate metal
//                              error trio Codable
//                              extension (5th post-
//                              hexa-#2 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASMetalSubstrate metal error trio gap-fill — 3 Error
// enums:
//
//   - BASKernelError
//   - BASKernelLookupError
//   - BASMambaSSMError
//
// FIFTH post-hexa-#2 gap-fill chapter (622-626)。 NEW
// kind 'metal-error-trio' — second error-cluster wave
// in the post-hexa-#2 run but in BASMetalSubstrate
// module。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 621 hexa #2 + 622-625 prior post-hexa-#2
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1881 → M1882

import XCTest
@testable import BASMetalSubstrate

final class BASChapter626MetalErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASKernelErrorConformsToCodable() {
        assertCodable(BASKernelError.self)
    }

    func testBASKernelLookupErrorConformsToCodable() {
        assertCodable(BASKernelLookupError.self)
    }

    func testBASMambaSSMErrorConformsToCodable() {
        assertCodable(BASMambaSSMError.self)
    }
}
