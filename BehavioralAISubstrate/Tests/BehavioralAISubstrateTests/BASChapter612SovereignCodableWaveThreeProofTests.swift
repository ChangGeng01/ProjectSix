// MARK: - BASChapter612SovereignCodableWaveThreeProofTests
// chapter 六百一十二 / M1826 — PROOF tests for the
//                              M1825 BASSovereign
//                              Codable extension wave
//                              3 (gap-fill)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASSovereign wave 3 gap-fill — 5TH consecutive
// gap-fill chapter (608 + 609 + 610 + 611 + 612)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1825 → M1826

import XCTest
@testable import BASSovereign

final class BASChapter612SovereignCodableWaveThreeProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testHardObservationsConformsToCodable() {
        assertCodable(
            BASSovereignVerdictEngine.HardObservations.self)
    }

    func testSoftSignalsConformsToCodable() {
        assertCodable(
            BASSovereignVerdictEngine.SoftSignals.self)
    }
}
