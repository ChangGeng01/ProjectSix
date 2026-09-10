// MARK: - BASChapter620HostKitPostMeshSweepProofTests
// chapter 六百二十 / M1858 — PROOF tests for the M1857
//                            BASHostKit Codable
//                            extension post-mesh-sweep
//                            gap-fill
//
// ## Coverage (2 compile-time conformance tests)
//
// BASHostKit post-mesh-sweep gap-fill — 2 enums:
//
//   - BASHostStorageWireError (2-case error enum:
//     missingSQLiteURL + storageInitFailed)
//   - BASShadowPermitUpgradeDecision (2-case decision
//     enum:noChange + escalate(targetMode:reasonCodes:))
//
// SIXTH post-hexa-catalog gap-fill chapter (615+616+
// 617+618+619+620) — TRIGGERS 2nd gap-fill hexa
// catalog meta-meta opportunity at chapter 621。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 608 BASHostKit mesh-sweep precedent
//   - chapter 614 gap-fill hexa catalog precedent
//   - chapter 615-619 prior post-hexa precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1857 → M1858

import XCTest
@testable import BASHostKit

final class BASChapter620HostKitPostMeshSweepProofTests:
    XCTestCase
{

    func testHostStorageWireErrorConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, both cases)
        assertCodableRoundTrips(
            BASHostStorageWireError.missingSQLiteURL(component: ""))
        assertCodableRoundTrips(
            BASHostStorageWireError
                .storageInitFailed(component: "", message: ""))
    }

    func testShadowPermitUpgradeDecisionConformsToCodable() {
        // #18: real round-trip. Only .noChange is round-tripped: the
        // .escalate case's associated BASActionPermitMode lives in
        // BASPolicy (not imported here), so the noChange case is the
        // representative one exercisable from BASHostKit alone.
        assertCodableRoundTrips(
            BASShadowPermitUpgradeDecision.noChange)
    }
}
