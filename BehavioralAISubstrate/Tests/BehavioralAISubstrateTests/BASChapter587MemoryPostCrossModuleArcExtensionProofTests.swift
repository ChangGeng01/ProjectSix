// MARK: - BASChapter587MemoryPostCrossModuleArcExtensionProofTests
// chapter 五百八十七 / M1726 — PROOF tests for the 2
//                          newly-Codable BASMemory
//                          types shipped at M1725
//                          (post-cross-module-arc
//                          extension)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-cross-module-arc BASMemory Codable extension。
// Chapter 569 cross-module arc covered 10 BASMemory
// types;this chapter extends 2 more in the beyond-
// M1700 narrative arc。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1725 → M1726

import XCTest
@testable import BASMemory

final class BASChapter587MemoryPostCrossModuleArcExtensionProofTests:
    XCTestCase
{

    func testMemoryTrustProfileConformsToCodable() {
        // #18: real round-trip
        let value = BASMemoryTrustProfile(
            score: 0,
            tier: .low,
            provenanceRisk: false,
            confidenceMultiplier: 0,
            decayGraceMultiplier: 0)
        assertCodableRoundTrips(value)
    }

    func testMemoryTieringReconciliationOutcomeDecisionConformsToCodable() {
        // #18: real round-trip
        let profile = BASMemoryTieringProfile(
            atomID: "",
            currentTier: .hot,
            recencyScore: 0,
            accessFrequency: 0,
            sensitivityDrift: 0,
            worldContextStaleness: 0,
            observedAt: Date(timeIntervalSince1970: 0))
        let value = BASMemoryTieringReconciliationOutcome.Decision(
            profile: profile,
            transition: .hold(tier: .hot, reason: .withinThresholds))
        assertCodableRoundTrips(value)
    }
}
