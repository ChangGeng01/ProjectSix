// MARK: - BASChapter576OrchestrationCodablePostArcProofTests
// chapter 五百七十六 / M1682 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration types
//                          shipped at M1681 (post-arc
//                          follow-up to chapter 574
//                          BASOrchestration arc seal)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-arc follow-up to the BASOrchestration Codable
// extension arc。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1681 → M1682

import XCTest
@testable import BASOrchestration

final class BASChapter576OrchestrationCodablePostArcProofTests:
    XCTestCase
{

    func testNeuralCoreFrameConformsToCodable() {
        // #18: real round-trip
        let organMap = BASNeuralOrganMap(
            morph: .scout,
            activeOrgans: [],
            routingPolicy: .scoutProbe)
        let frame = BASNeuralCoreFrame(organMap: organMap)
        assertCodableRoundTrips(frame)
    }

    func testProductRedLineLinterViolationConformsToCodable() {
        // #18: real round-trip
        let violation = BASProductRedLineLinter.Violation(
            redLine: .noAnthropomorphism,
            offendingInput: "",
            matchedSubstring: "")
        assertCodableRoundTrips(violation)
    }
}
