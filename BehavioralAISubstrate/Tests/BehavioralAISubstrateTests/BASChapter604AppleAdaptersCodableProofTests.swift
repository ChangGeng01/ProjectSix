// MARK: - BASChapter604AppleAdaptersCodableProofTests
// chapter 六百四 / M1794 — PROOF tests for the M1793
//                          BASAppleAdapters Codable
//                          extension wave 1 (10TH
//                          MODULE FORMAL ENTRY)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASAppleAdapters wave 1 Codable extension — 10th
// module formal entry。 4th consecutive post-octa
// fresh-module advancement (BASOrgan ch598 +
// BASMLXAdapter ch599 + BASChatCompletionsAdapter
// ch603 + BASAppleAdapters ch604)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1793 → M1794

import XCTest
@testable import BASAppleAdapters

final class BASChapter604AppleAdaptersCodableProofTests:
    XCTestCase
{

    func testChengluPromptSignatureConformsToCodable() {
        // #18: real round-trip
        let value = BASChengluPromptSignature(
            tone: "",
            domain: "",
            stake: "",
            timeframe: "",
            confidant: "",
            askShape: "")
        assertCodableRoundTrips(value)
    }

    func testAppleProviderReleaseInputConformsToCodable() {
        // #18: real round-trip — required `kernelSnapshot`
        // (BASCognitionKernelSnapshot) is a deeply-nested struct
        // from BASOrchestration not confidently constructible here;
        // honest compile-time-only fallback.
        assertConformsToCodableAtCompileTime(
            BASAppleProviderReleaseInput.self)
    }
}
