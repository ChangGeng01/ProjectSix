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
@testable import BASRuntimeCore

final class BASChapter582LeaseLifeCodableWaveTwoProofTests:
    XCTestCase
{

    func testOSThermalStateConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTripsAllCases(
            BASThermalTwin.OSThermalState.self)
    }

    func testThermalTwinReadingConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASThermalTwin.Reading(
                osState: .nominal,
                thermalLevel: .nominal,
                guardLevel: .nominal,
                accumulatedPressure: 0.0,
                observedAt: Date(timeIntervalSince1970: 0)))
    }

    func testLungStateAccumulatorSnapshotConformsToCodable()
    {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASLungStateAccumulator.Snapshot(
                pressure: 0.0,
                turnCount: 0,
                lastTurnAt: nil,
                lastDecayAt: nil))
    }
}
