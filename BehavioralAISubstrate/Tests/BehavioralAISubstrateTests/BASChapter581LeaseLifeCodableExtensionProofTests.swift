// MARK: - BASChapter581LeaseLifeCodableExtensionProofTests
// chapter 五百八十一 / M1702 — PROOF tests for the 2
//                          newly-Codable BASLeaseLife
//                          types shipped at M1701
//                          (first-ever BASLeaseLife
//                          Codable extension beyond
//                          the M1700 narrative arc)
//
// ## Coverage (2 compile-time conformance tests)
//
// First-ever BASLeaseLife Codable extension。 Opens
// fresh module territory beyond the M1700 round-number
// Codable extension narrative arc close-out。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1701 → M1702

import XCTest
@testable import BASLeaseLife
@testable import BASRuntimeCore

final class BASChapter581LeaseLifeCodableExtensionProofTests:
    XCTestCase
{

    func testBreathSchedulerRequestConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBreathScheduler.Request(
                id: "",
                maintenanceClass: .none,
                earliestFireAt: Date(timeIntervalSince1970: 0),
                reasonCodes: []))
    }

    func testBreathSchedulerScheduledBreathConformsToCodable()
    {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBreathScheduler.ScheduledBreath(
                request: BASBreathScheduler.Request(
                    id: "",
                    maintenanceClass: .none,
                    earliestFireAt: Date(timeIntervalSince1970: 0),
                    reasonCodes: []),
                scheduledAt: Date(timeIntervalSince1970: 0),
                guardLevelAtSchedule: .nominal))
    }
}
