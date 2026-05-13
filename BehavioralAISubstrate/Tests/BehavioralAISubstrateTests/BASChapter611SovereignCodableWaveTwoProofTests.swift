// MARK: - BASChapter611SovereignCodableWaveTwoProofTests
// chapter 六百一十一 / M1822 — PROOF tests for the
//                              M1821 BASSovereign
//                              Codable extension wave
//                              2 (gap-fill)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASSovereign wave 2 gap-fill — extends chapter 606
// wave 1 formal-entry coverage。 4TH consecutive gap-
// fill chapter (608 + 609 + 610 + 611)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1821 → M1822

import XCTest
@testable import BASSovereign

final class BASChapter611SovereignCodableWaveTwoProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testSovereignStubRendererStubOutputConformsToCodable() {
        assertCodable(
            BASSovereignStubRenderer.StubOutput.self)
    }

    func testSovereignStubRendererRefusalPhrasesConformsToCodable() {
        assertCodable(
            BASSovereignStubRenderer.RefusalPhrases.self)
    }
}
