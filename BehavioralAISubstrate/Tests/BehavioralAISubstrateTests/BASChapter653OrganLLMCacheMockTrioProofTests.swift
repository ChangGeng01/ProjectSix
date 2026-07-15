// MARK: - BASChapter653OrganLLMCacheMockTrioProofTests
// chapter 六百五十三 / M1990 — PROOF tests for the M1989
//                              BASOrgan LLM-cache-mock trio
//                              Codable extension (5th post-
//                              hexa-#6 gap-fill,2 chapters
//                              from chapter 六百五十五 hexa
//                              #7 opportunity)

import XCTest
@testable import BASOrgan

final class BASChapter653OrganLLMCacheMockTrioProofTests:
    XCTestCase
{

    func testBASLLMModelRouterErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASLLMModelRouterError
                .noAdapterRegisteredForClass(.small))
    }

    func testBASLLMPromptCacheOutcomeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(BASLLMPromptCacheOutcome.miss)
        assertCodableRoundTrips(
            BASLLMPromptCacheOutcome.partial(prefixHash: 0))
    }

    func testBASFoundationModelsMockResponseConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASFoundationModelsMockResponse.text(body: ""))
        assertCodableRoundTrips(
            BASFoundationModelsMockResponse.error(reason: ""))
    }
}
