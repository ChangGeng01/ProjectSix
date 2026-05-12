// MARK: - BASChapter582LeaseLifeCodableWaveTwoProofTests
// chapter 五百八十二 / M1706 — PROOF tests for the 2
//                          newly-Codable BASLeaseLife
//                          types + 1 enum shipped at
//                          M1705 (wave 2 of BAS
//                          LeaseLife extension)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASLeaseLife wave 2 follow-up to chapter 581 first-
// ever BASLeaseLife Codable extension。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 types + 1 enum
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1705 → M1706

import XCTest
@testable import BASLeaseLife

final class BASChapter582LeaseLifeCodableWaveTwoProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testOSThermalStateConformsToCodable() {
        assertCodable(BASThermalTwin.OSThermalState.self)
    }

    func testThermalTwinReadingConformsToCodable() {
        assertCodable(BASThermalTwin.Reading.self)
    }

    func testLungStateAccumulatorSnapshotConformsToCodable()
    {
        assertCodable(
            BASLungStateAccumulator.Snapshot.self)
    }
}
