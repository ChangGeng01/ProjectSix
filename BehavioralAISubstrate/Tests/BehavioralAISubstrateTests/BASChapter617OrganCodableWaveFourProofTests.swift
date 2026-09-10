// MARK: - BASChapter617OrganCodableWaveFourProofTests
// chapter 六百一十七 / M1846 — PROOF tests for the M1845
//                              BASOrgan Codable
//                              extension wave 4
//                              (gap-fill via chain)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASOrgan gap-fill wave 4 — 3 types gained Codable
// via domino chain:
//
//   - BASOrganDraft (8-field draft)
//   - BASLLMExtractionResult (4-field result holding
//     BASOrganDraft as primary field)
//   - BASLLMExtractionEngineError (error enum with 4
//     single-String-associated-value cases)
//
// THIRD post-hexa-catalog gap-fill chapter (615 + 616
// + 617)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 614 gap-fill hexa catalog precedent
//   - chapter 615/616 first/second-post-hexa precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1845 → M1846

import XCTest
@testable import BASOrgan

final class BASChapter617OrganCodableWaveFourProofTests:
    XCTestCase
{

    func testBASOrganDraftConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASOrganDraft(
                requestID: "",
                providerID: "",
                role: .scout,
                body: "",
                inputTokensEstimated: 0,
                outputTokensEstimated: 0,
                producedAt: Date(timeIntervalSince1970: 0),
                traceID: ""))
    }

    func testBASLLMExtractionResultConformsToCodable() {
        // #18: honest compile-time-only fallback — BASLLMExtractionResult
        // requires deeply-nested BASLLMExtractionByproducts +
        // BASLLMTaskPackage values that cannot be confidently
        // minimally constructed here.
        assertConformsToCodableAtCompileTime(
            BASLLMExtractionResult.self)
    }

    func testBASLLMExtractionEngineErrorConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative cases)
        assertCodableRoundTrips(
            BASLLMExtractionEngineError.retrievalFailed(reason: ""))
        assertCodableRoundTrips(
            BASLLMExtractionEngineError.adapterFailed(reason: ""))
    }
}
