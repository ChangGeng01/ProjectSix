import XCTest
@testable import BASOrgan
import BASMLXAdapter

/// `BASSuffixAutomaton` is an O(1) cross-turn acceleration of `BASPromptLookupDrafter.propose(over:)`. These
/// tests pin the load-bearing PARITY INVARIANT: the automaton's `propose()` equals the certified linear
/// drafter's `propose(over:)` over the automaton's retained window — exactly, never approximately — across the
/// pinned fixtures, a randomized fuzz, and after FIFO eviction. (If parity holds, byte-identity is inherited:
/// the verify loop only emits the target's own argmax, so a different draft source changes only acceptance.)
final class BASSuffixAutomatonTests: XCTestCase {

    /// Deterministic RNG so the fuzz is reproducible across runs/machines.
    private struct LCG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private func fed(_ tokens: [Int], _ lo: Int, _ hi: Int, _ k: Int, cap: Int = 1_000_000) -> BASSuffixAutomaton {
        var a = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: cap)
        a.append(contentsOf: tokens)
        return a
    }

    // MARK: - Pinned fixtures (mirror BASPromptLookupDrafterTests — same expected continuations)

    func testExactMatchReturnsContinuation() {
        XCTAssertEqual(fed([1, 2, 3, 4, 1, 2], 2, 2, 4).propose(), [3, 4, 1, 2])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertEqual(fed([1, 2, 3, 4, 5, 6], 1, 3, 4).propose(), [])
    }

    func testLongestNgramWins() {
        XCTAssertEqual(fed([9, 1, 2, 3, 7, 8, 9, 1, 2], 1, 3, 4).propose(), [3, 7, 8, 9])
    }

    func testKClampAtSequenceEnd() {
        XCTAssertEqual(fed([5, 6, 7, 5, 6], 2, 2, 4).propose(), [7, 5, 6])
    }

    func testMostRecentPriorOccurrenceWins() {
        XCTAssertEqual(fed([1, 2, 0, 1, 2, 9, 1, 2], 2, 2, 1).propose(), [9])
    }

    func testTooShortSequenceReturnsEmpty() {
        XCTAssertEqual(fed([], 1, 3, 4).propose(), [])
        XCTAssertEqual(fed([1], 1, 3, 4).propose(), [])
    }

    func testKOverrideClampsAndOverrides() {
        // Default K=4 → [3,4,1,2]; override k=2 → [3,4].
        let a = fed([1, 2, 3, 4, 1, 2], 2, 2, 4)
        XCTAssertEqual(a.propose(k: 2), [3, 4])
        XCTAssertEqual(a.propose(k: 0), [3], "k clamps to ≥1")
    }

    func testRemoveAllResets() {
        var a = fed([1, 2, 3, 4, 1, 2], 2, 2, 4)
        XCTAssertEqual(a.propose(), [3, 4, 1, 2])
        a.removeAll()
        XCTAssertEqual(a.count, 0)
        XCTAssertEqual(a.propose(), [])
    }

    // MARK: - Cross-turn: the whole point (corpus spans appends from earlier "turns")

    func testCrossTurnMatchFromEarlierTurn() {
        let A = 10, B = 11, C = 12, D = 13, Q = 99
        var a = BASSuffixAutomaton(ngramMin: 2, ngramMax: 3, numDraftTokens: 2, capacity: 1000)
        a.append(contentsOf: [A, B, C, D, Q])   // "turn 1"
        a.append(contentsOf: [A, B])            // "turn 2" ends on the recurring suffix [A,B]
        XCTAssertEqual(a.propose(), [C, D],
            "the suffix [A,B] recurs from turn 1 → its continuation [C,D] is proposed across the turn boundary")
        // And it equals the linear oracle over the same accumulated corpus.
        let drafter = BASPromptLookupDrafter(ngramMin: 2, ngramMax: 3, numDraftTokens: 2)
        XCTAssertEqual(a.propose(), drafter.propose(over: a.currentTokens()))
    }

    // MARK: - Randomized fuzz parity (the real proof) — incremental, every step, many configs

    func testFuzzParityAgainstDrafterEveryStep() {
        var rng = LCG(seed: 0xC0FFEE_D00D)
        let configs: [(Int, Int, Int)] = [(1, 1, 4), (1, 3, 4), (2, 2, 1), (2, 3, 2), (1, 2, 6), (3, 3, 4)]
        for (lo, hi, k) in configs {
            for vocab in [2, 3, 5, 8] {
                for _ in 0..<30 {
                    let len = Int.random(in: 0...60, using: &rng)
                    let seq = (0..<len).map { _ in Int.random(in: 0..<vocab, using: &rng) }
                    let drafter = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
                    var auto = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: 1_000_000)
                    for i in 0..<seq.count {
                        auto.append(seq[i])
                        let expected = drafter.propose(over: Array(seq[0...i]))
                        XCTAssertEqual(auto.propose(), expected,
                            "PARITY config(\(lo),\(hi),\(k)) vocab=\(vocab) i=\(i) seq=\(Array(seq[0...i]))")
                    }
                }
            }
        }
    }

    // MARK: - Eviction: bounded corpus + parity over the retained window

    func testEvictionKeepsBoundAndParityOverRetainedWindow() {
        var rng = LCG(seed: 0x5EED)
        let lo = 1, hi = 3, k = 4, cap = 24
        let drafter = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        var auto = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: cap)
        for _ in 0..<600 {
            auto.append(Int.random(in: 0..<4, using: &rng))
            XCTAssertLessThanOrEqual(auto.count, cap, "corpus must stay bounded by capacity")
            XCTAssertEqual(auto.propose(), drafter.propose(over: auto.currentTokens()),
                "parity must hold over the retained window after FIFO eviction + index rebuild")
        }
    }

    // MARK: - proposeDistinct (tree-variant feed): the pinned "branch 0 == propose()" invariant

    func testProposeDistinctBranch0EqualsProposeFuzz() {
        var rng = LCG(seed: 0xB0FFE7)
        for (lo, hi, k) in [(1, 3, 4), (2, 2, 2), (1, 2, 6)] {
            for vocab in [2, 3, 5] {
                for mb in [1, 2, 3] {
                    for _ in 0..<20 {
                        let len = Int.random(in: 0...50, using: &rng)
                        let seq = (0..<len).map { _ in Int.random(in: 0..<vocab, using: &rng) }
                        var a = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: 1_000_000)
                        for t in seq {
                            a.append(t)
                            XCTAssertEqual(a.proposeDistinct(maxBranch: mb, k: k).first ?? [], a.propose(k: k),
                                "branch 0 of proposeDistinct must equal the linear propose() — the pinned invariant")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Batched append parity (the eviction perf fix must not change the retained window)

    func testBatchedAppendMatchesOneByOneAndStaysBounded() {
        var rng = LCG(seed: 0xBA7C)
        let lo = 1, hi = 3, k = 4
        let drafter = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        for cap in [16, 24, 40] {
            for _ in 0..<50 {
                let len = Int.random(in: 0...120, using: &rng)
                let seq = (0..<len).map { _ in Int.random(in: 0..<5, using: &rng) }
                var batched = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: cap)
                batched.append(contentsOf: seq)
                var oneByOne = BASSuffixAutomaton(ngramMin: lo, ngramMax: hi, numDraftTokens: k, capacity: cap)
                for t in seq { oneByOne.append(t) }
                XCTAssertLessThanOrEqual(batched.count, cap, "batched append stays bounded")
                XCTAssertEqual(batched.currentTokens(), oneByOne.currentTokens(),
                    "append(contentsOf:) must retain the EXACT same window as one-by-one append(_:)")
                XCTAssertEqual(batched.propose(), drafter.propose(over: batched.currentTokens()),
                    "batched-append parity over the retained window")
            }
        }
    }
}
