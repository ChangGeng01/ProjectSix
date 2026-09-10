// MARK: - BASChapter592HostKitConfigurationHintCodableProofTests
// chapter 五百九十二 / M1746 — PROOF tests for the 2
//                          newly-Codable BASHostKit
//                          types shipped at M1745
//                          (configuration + hint
//                          extension)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASHostKit configuration + hint Codable extension
// (non-projection territory beyond chapter 553 cascade
// + chapter 564 aggregator arcs)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1745 → M1746

import XCTest
@testable import BASHostKit

final class BASChapter592HostKitConfigurationHintCodableProofTests:
    XCTestCase
{

    func testCognitiveOSBundleOptionsConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(BASCognitiveOSBundleOptions())
    }

    func testChengluPreflightHintConformsToCodable() {
        // #18: real round-trip
        let value = BASChengluPreflightHint(
            route: .afm,
            probability: 0,
            confidence: .high)
        assertCodableRoundTrips(value)
    }
}
