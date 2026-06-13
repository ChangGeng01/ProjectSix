// MARK: - BASTreeSpecTests — tree-structured prompt-lookup foundation (the pure, host-testable geometry)
//
// Tree-decode can ONLY silently diverge from greedy via the ancestry / depth-major-flatten / mask geometry, so
// that geometry is pinned here with brute-force invariants — before any MLX/vendor work.

import XCTest
@testable import BASMLXAdapter

final class BASTreeSpecTests: XCTestCase {

    // MARK: - DraftTree.flatten geometry

    func testFlattenAncestryDepthAndRopeSegments() {
        // Two depth-1 branches (parent 0), each with one depth-2 child. BFS order: d1a, d1b, d2a, d2b.
        let tree = BASDraftTree(nodes: [
            .init(token: 11, parent: 0),   // flat 1, depth 1
            .init(token: 22, parent: 0),   // flat 2, depth 1
            .init(token: 33, parent: 1),   // flat 3, depth 2 (child of d1a)
            .init(token: 44, parent: 2),   // flat 4, depth 2 (child of d1b)
        ])
        let f = tree.flatten(seed: 7)
        XCTAssertEqual(f.tokens, [7, 11, 22, 33, 44])
        XCTAssertEqual(f.depth, [0, 1, 1, 2, 2])
        XCTAssertEqual(f.ancestorSets, [[0], [0, 1], [0, 2], [0, 1, 3], [0, 2, 4]])
        XCTAssertEqual(f.ropeSegments.map(\.range), [0..<1, 1..<3, 3..<5])
        XCTAssertEqual(f.ropeSegments.map(\.depth), [0, 1, 2])
        // Every node's position advances exactly 1 over its parent (the byte-identity RoPE guard).
        for (i, anc) in f.ancestorSets.enumerated() where i > 0 {
            let parent = anc.subtracting([i]).max()!   // proper ancestors; immediate parent is the largest
            XCTAssertEqual(f.depth[i], f.depth[parent] + 1)
        }
    }

    // MARK: - Tree attention mask exactness (the silent-divergence vector)

    func testMaskGridAncestryExact() {
        let tree = BASDraftTree(nodes: [
            .init(token: 11, parent: 0), .init(token: 22, parent: 0),
            .init(token: 33, parent: 1), .init(token: 44, parent: 2),
        ])
        let f = tree.flatten(seed: 7)
        let cacheOffset = 3
        let grid = BASTreeAttentionMask.grid(ancestorSets: f.ancestorSets, cacheOffset: cacheOffset)
        let neg = BASTreeAttentionMask.maskedFill
        let s = f.tokens.count
        for i in 0..<s {
            // Prefix columns are always visible (0).
            for c in 0..<cacheOffset { XCTAssertEqual(grid[i][c], 0, "prefix col \(c) must be visible for node \(i)") }
            // Tree columns: 0 iff ancestor, else neg.
            var zeros = 0
            for j in 0..<s {
                let expected: Float = f.ancestorSets[i].contains(j) ? 0 : neg
                XCTAssertEqual(grid[i][cacheOffset + j], expected, "node \(i) key \(j)")
                if grid[i][cacheOffset + j] == 0 { zeros += 1 }
            }
            // Exactly depth+1 zeros in the tree block (self + proper ancestors).
            XCTAssertEqual(zeros, f.depth[i] + 1, "node \(i) must attend exactly depth+1 tree keys")
        }
    }

    // MARK: - proposeTree

    private let drafter = BASPromptLookupDrafter(ngramMin: 1, ngramMax: 3, numDraftTokens: 4)

    func testProposeTreeMaxBranch1EqualsLinearPropose() {
        // The pinned regression invariant: a 1-branch tree flattens to EXACTLY the linear propose().
        let cases: [[Int]] = [
            [1, 2, 3, 9, 1, 2],
            [5, 6, 7, 8, 5, 6, 7],
            [1, 1, 1, 1],
            [42, 7, 42, 7, 42],
        ]
        for toks in cases {
            let linear = drafter.propose(over: toks)
            let tree = drafter.proposeTree(over: toks, maxBranch: 1, maxNodes: 8)
            let flatTokens = Array(tree.flatten(seed: toks.last ?? 0).tokens.dropFirst())
            XCTAssertEqual(flatTokens, linear, "maxBranch=1 must equal linear propose() for \(toks)")
        }
    }

    func testProposeTreeBranchesOnDistinctContinuations() {
        // The LONGEST recurring suffix [1,2] (n=2) occurs twice with DIFFERENT next tokens (7 at the recent occ
        // index 3, 5 at the older index 0) → 2 branches. (No 3-gram recurs, so longest-first lands on [1,2].)
        let toks = [1, 2, 5, 1, 2, 7, 1, 2]
        let tree = drafter.proposeTree(over: toks, maxBranch: 2, maxNodes: 8)
        let f = tree.flatten(seed: 2)
        // Depth-1 nodes are the two distinct continuations; most-recent (7) first.
        let depth1 = f.tokens.enumerated().filter { f.depth[$0.offset] == 1 }.map(\.element)
        XCTAssertEqual(depth1.first, 7, "branch 0 = most-recent occurrence's next token")
        XCTAssertTrue(depth1.contains(5), "branch 1 = the distinct older continuation")
        XCTAssertEqual(Set(depth1).count, depth1.count, "sibling branches must be distinct tokens")
        // BFS/depth-major: depths are non-decreasing.
        XCTAssertEqual(f.depth, f.depth.sorted(), "nodes must be depth-major")
    }

    func testProposeTreeRespectsNodeBudget() {
        let toks = [1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 1, 2]
        let tree = drafter.proposeTree(over: toks, maxBranch: 2, maxNodes: 5)
        XCTAssertLessThanOrEqual(tree.nodes.count, 5)
        // Parent-precedes-child + depth-major hold (flatten would precondition-fail otherwise).
        _ = tree.flatten(seed: 2)
    }
}
