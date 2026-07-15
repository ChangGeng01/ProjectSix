// MARK: - BASTokenRecyclingMatrixTests — the pure Token Recycling adjacency core (universal decode-draft lever)
//
// Pins BASTokenRecyclingMatrix: M[token] = the target's own top-k successors; greedy chain + narrow-tree draft.
// The decode-loop integration (feeding top-k from the verify forward) is the Phase-2 follow-up; this pins the
// algorithm. Byte-identity is the loop's job (verify commits only target argmax) — not tested here.

import XCTest
@testable import BASOrgan

final class BASTokenRecyclingMatrixTests: XCTestCase {

    // 1. Greedy chain walks M[last][0] → … and stops at the first unseen token.
    func testProposeChainWalksMostLikelyPath() {
        var m = BASTokenRecyclingMatrix(k: 8)
        m.observe(after: 1, topK: [2, 9])      // 1 → 2 (most likely)
        m.observe(after: 2, topK: [3, 7])      // 2 → 3
        m.observe(after: 3, topK: [4])         // 3 → 4
        XCTAssertEqual(m.proposeChain(from: 1, length: 4), [2, 3, 4],
                       "greedy path 1→2→3→4, then 4 unseen → stop (3 tokens, not 4)")
        XCTAssertEqual(m.proposeChain(from: 1, length: 2), [2, 3], "honors the length cap")
    }

    // 2. Empty matrix / unseen seed / zero length → no draft (loss-proof: nothing proposed).
    func testEmptyAndUnseenProposeNothing() {
        var m = BASTokenRecyclingMatrix(k: 4)
        XCTAssertEqual(m.proposeChain(from: 1, length: 4), [])           // empty M
        m.observe(after: 1, topK: [2])
        XCTAssertEqual(m.proposeChain(from: 99, length: 4), [])          // unseen seed
        XCTAssertEqual(m.proposeChain(from: 1, length: 0), [])           // zero length
        XCTAssertEqual(m.proposeBranches(from: 1, maxBranch: 2, depth: 0), [])  // zero depth
    }

    // 3. Narrow tree: top-maxBranch roots, each extended greedily to `depth` total tokens.
    func testProposeBranchesNarrowTree() {
        var m = BASTokenRecyclingMatrix(k: 8)
        m.observe(after: 1, topK: [2, 5, 8])   // 1 → {2,5,8}
        m.observe(after: 2, topK: [3])         // 2 → 3
        m.observe(after: 5, topK: [6])         // 5 → 6
        let branches = m.proposeBranches(from: 1, maxBranch: 2, depth: 2)
        XCTAssertEqual(branches, [[2, 3], [5, 6]], "2 roots (2,5), each depth-2: [2,3] and [5,6]")
    }

    // 4. Cycle guard: a self/loop transition (repetitive text) does not spin forever.
    func testChainCycleGuard() {
        var m = BASTokenRecyclingMatrix(k: 4)
        m.observe(after: 1, topK: [2])
        m.observe(after: 2, topK: [1])         // 1↔2 loop
        let chain = m.proposeChain(from: 1, length: 10)
        XCTAssertEqual(chain, [2], "1→2 then 2→1 is a cycle (1 already seen) → stop, not infinite")
    }

    // 5. k caps the retained successors (matrix width); latest observation wins.
    func testWidthCapAndLatestWins() {
        var m = BASTokenRecyclingMatrix(k: 2)
        m.observe(after: 1, topK: [2, 3, 4, 5])           // capped to [2,3]
        XCTAssertEqual(m.proposeBranches(from: 1, maxBranch: 5, depth: 1), [[2], [3]])
        m.observe(after: 1, topK: [9, 8])                  // latest-wins
        XCTAssertEqual(m.proposeBranches(from: 1, maxBranch: 5, depth: 1), [[9], [8]])
        XCTAssertEqual(m.coverage, 1)
    }
}
