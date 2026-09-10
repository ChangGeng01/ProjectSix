// MARK: - BASChapter647SovereignPrivilegeScanTrioProofTests
// chapter 六百四十七 / M1966 — PROOF tests for the M1965
//                              BASSovereign privilege-
//                              scan trio Codable
//                              extension (5th post-hexa-
//                              #5 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign trio gap-fill — 3 struct types across
// privilege-arbiter + integrity-sentinel-scan
// subsystems:
//
//   BASSovereign (nested across 2 actors):
//     - BASSovereignPrivilegeArbiter.ScopeKey
//       (3-field struct)
//     - BASSovereignIntegritySentinel.ScanRequest
//       (wraps [ArtifactClaim] from ch646 — recursive
//       proof)
//     - BASSovereignIntegritySentinel.ScanReport
//       (uses Set<ArtifactKind> from ch641 — recursive
//       proof + Set<T> Codable composition)
//
// FIFTH post-hexa-#5 gap-fill chapter。 8th BAS
// Sovereign touch overall。 3-LEVEL RECURSIVE CODABLE
// COMPOSITION:ArtifactKind (ch641) → ArtifactClaim
// (ch646) → ScanRequest (this chapter)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 641 prior ArtifactKind Codable extension
//   - chapter 646 prior ArtifactClaim Codable extension
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1965 → M1966

import XCTest
@testable import BASSovereign

final class BASChapter647SovereignPrivilegeScanTrioProofTests:
    XCTestCase
{

    func testBASSovereignPrivilegeArbiterScopeKeyConformsToCodable() {
        // #18: real round-trip
        let value = BASSovereignPrivilegeArbiter.ScopeKey(sessionID: "")
        assertCodableRoundTrips(value)
    }

    func testBASSovereignIntegritySentinelScanRequestConformsToCodable() {
        // #18: real round-trip
        let value = BASSovereignIntegritySentinel.ScanRequest(claims: [])
        assertCodableRoundTrips(value)
    }

    func testBASSovereignIntegritySentinelScanReportConformsToCodable() {
        // #18: real round-trip (memberwise init reachable via @testable)
        let value = BASSovereignIntegritySentinel.ScanReport(
            failedArtifactIDs: [],
            failedKinds: [],
            observedSelfMutation: false)
        assertCodableRoundTrips(value)
    }
}
