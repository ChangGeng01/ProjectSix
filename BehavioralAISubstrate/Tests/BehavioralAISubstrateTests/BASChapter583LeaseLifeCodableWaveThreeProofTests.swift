// MARK: - BASChapter583LeaseLifeCodableWaveThreeProofTests
// chapter 五百八十三 / M1710 — PROOF tests for the 2
//                          newly-Codable BASLeaseLife
//                          types shipped at M1709
//                          (wave 3 of BASLeaseLife
//                          extension)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASLeaseLife wave 3 follow-up to chapter 581 first-
// ever + chapter 582 wave 2 BASLeaseLife Codable
// extensions。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1709 → M1710

import XCTest
@testable import BASLeaseLife
@testable import BASRuntimeCore

final class BASChapter583LeaseLifeCodableWaveThreeProofTests:
    XCTestCase
{

    func testLeaseLifeCoordinatorTurnRecordedConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASLeaseLifeCoordinator.TurnRecorded(
                lung: BASLungStateAccumulator.Snapshot(
                    pressure: 0.0,
                    turnCount: 0,
                    lastTurnAt: nil,
                    lastDecayAt: nil),
                thermal: BASThermalTwin.Reading(
                    osState: .nominal,
                    thermalLevel: .nominal,
                    guardLevel: .nominal,
                    accumulatedPressure: 0.0,
                    observedAt: Date(timeIntervalSince1970: 0)),
                cancelledBreathIDs: []))
    }

    func testComputeRouterConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(BASComputeRouter())
    }
}
