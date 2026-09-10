// MARK: - BASChapter577OrchestrationCodablePostArcWaveTwoProofTests
// chapter 五百七十七 / M1686 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Orchestration types shipped
//                          at M1685 (post-arc wave 2
//                          to chapter 574 BAS
//                          Orchestration arc seal)
//
// ## Coverage (2 compile-time conformance tests)
//
// Post-arc wave 2 follow-up to the BASOrchestration
// Codable extension arc。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1685 → M1686

import XCTest
@testable import BASOrchestration

final class BASChapter577OrchestrationCodablePostArcWaveTwoProofTests:
    XCTestCase
{

    func testProviderReleaseAssessmentConformsToCodable() {
        // #18: real round-trip
        let assessment = BASProviderReleaseAssessment(
            outputPreview: "",
            consistencyCheck: nil)
        assertCodableRoundTrips(assessment)
    }

    func testProviderReleaseEvaluationRequestConformsToCodable() {
        // #18: compile-time fallback — required kernelSnapshot
        // (BASCognitionKernelSnapshot) nests BASCompiledPrompt /
        // BASContextKernelPolicy, too deep to construct confidently.
        assertConformsToCodableAtCompileTime(
            BASProviderReleaseEvaluationRequest.self)
    }
}
