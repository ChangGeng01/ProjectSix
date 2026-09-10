import XCTest
@testable import BASMLXAdapter

/// Pure-function tests for the universal prompt-lookup (n-gram) drafter — the model-free, any-LLM,
/// byte-identical speculative draft source.
final class BASPromptLookupDrafterTests: XCTestCase {

    func testExactMatchReturnsContinuation() {
        // [1,2,3,4,1,2]: the suffix [1,2] recurs at idx 0-1; the K tokens that followed it are [3,4,1,2]
        // (canonical prompt-lookup proposes K tokens; periodic wrap is fine — verify rejects at any divergence).
        let d = BASPromptLookupDrafter(ngramMin: 2, ngramMax: 2, numDraftTokens: 4)
        XCTAssertEqual(d.propose(over: [1, 2, 3, 4, 1, 2]), [3, 4, 1, 2])
    }

    func testNoMatchReturnsEmpty() {
        // No suffix recurs → no draft (the honest "no speedup, no harm" path).
        let d = BASPromptLookupDrafter(ngramMin: 1, ngramMax: 3, numDraftTokens: 4)
        XCTAssertEqual(d.propose(over: [1, 2, 3, 4, 5, 6]), [])
    }

    func testLongestNgramWins() {
        // Suffix [9,1,2] (n=3, tried first) recurs at idx 0-2 → its continuation [3,7,8,9] (K=4).
        let tokens = [9, 1, 2, 3, 7, 8, 9, 1, 2]
        let d = BASPromptLookupDrafter(ngramMin: 1, ngramMax: 3, numDraftTokens: 4)
        XCTAssertEqual(d.propose(over: tokens), [3, 7, 8, 9],
            "longest matching suffix [9,1,2] → its continuation, K=4")
    }

    func testKClampAtSequenceEnd() {
        // start+K exceeds the sequence → clamp to what exists. [5,6,7,5,6]: suffix [5,6] recurs at 0-1,
        // continuation from idx 2 = tokens[2..<5] = [7,5,6] (3 < K=4 → clamped).
        let d = BASPromptLookupDrafter(ngramMin: 2, ngramMax: 2, numDraftTokens: 4)
        XCTAssertEqual(d.propose(over: [5, 6, 7, 5, 6]), [7, 5, 6])
    }

    func testMostRecentPriorOccurrenceWins() {
        // [1,2,0,  1,2,9,  1,2]: suffix [1,2] — the MOST RECENT prior occurrence is at idx 3-4, continuation [9]
        // (not the older idx 0-1 continuation [0]).
        let d = BASPromptLookupDrafter(ngramMin: 2, ngramMax: 2, numDraftTokens: 1)
        XCTAssertEqual(d.propose(over: [1, 2, 0, 1, 2, 9, 1, 2]), [9])
    }

    func testTooShortSequenceReturnsEmpty() {
        let d = BASPromptLookupDrafter()
        XCTAssertEqual(d.propose(over: []), [])
        XCTAssertEqual(d.propose(over: [1]), [])
    }

    func testRepetitiveStructuredOutputHits() {
        // JSON-ish repetition: keys recur → the drafter proposes the recurring continuation.
        // tokens model: KEY VAL1 SEP KEY VAL2 SEP KEY  → suffix [SEP,KEY] recurs → proposes [VAL?]... here we
        // just assert a real continuation is found (non-empty) on repetitive structure.
        let KEY = 100, SEP = 5
        let tokens = [KEY, 1, SEP, KEY, 2, SEP, KEY]
        let d = BASPromptLookupDrafter(ngramMin: 1, ngramMax: 3, numDraftTokens: 2)
        // suffix [SEP,KEY] (n=2) recurs at idx 2-3 → continuation [2, SEP].
        XCTAssertEqual(d.propose(over: tokens), [2, SEP])
    }

    func testConfigClamps() {
        // Defensive: invalid config clamps to sane floors (no crash).
        let d = BASPromptLookupDrafter(ngramMin: 0, ngramMax: -3, numDraftTokens: 0)
        XCTAssertEqual(d.ngramMin, 1)
        XCTAssertEqual(d.ngramMax, 1)
        XCTAssertEqual(d.numDraftTokens, 1)
        _ = d.propose(over: [1, 2, 1])  // must not crash
    }
}
