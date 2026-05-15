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

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASLLMModelRouterErrorConformsToCodable() {
        assertCodable(BASLLMModelRouterError.self)
    }

    func testBASLLMPromptCacheOutcomeConformsToCodable() {
        assertCodable(BASLLMPromptCacheOutcome.self)
    }

    func testBASFoundationModelsMockResponseConformsToCodable() {
        assertCodable(BASFoundationModelsMockResponse.self)
    }
}
