import XCTest
@testable import BASMLXAdapter
import BASOrgan

/// `BASCrossTurnDrafter` adapts the cross-turn `BASSuffixAutomaton` to the `BASUniversalDraftSource` contract the
/// decoder consumes. These pin: (1) the EMPTY-STORE regression anchor — with no prior tokens it proposes exactly
/// what the shipped `BASPromptLookupDrafter` does over the same rolling sequence (⇒ byte-identical decode), and
/// (2) cross-turn — a non-empty prior corpus makes its proposal equal the linear scan over `prior + rolling`.
final class BASCrossTurnDrafterTests: XCTestCase {

    /// Drive the adapter over a growing `rolling` exactly as the decode loop does.
    private func proposals(prior: [Int], rolling steps: [Int], lo: Int, hi: Int, k: Int) -> [[Int]] {
        var d = BASCrossTurnDrafter(priorTokens: prior, ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        var rolling: [Int] = []
        var out: [[Int]] = []
        for t in steps { rolling.append(t); out.append(d.propose(over: rolling)) }
        return out
    }

    func testEmptyStoreIsByteIdenticalToPromptLookup() {
        let lo = 1, hi = 3, k = 4
        let oracle = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        let steps = [1, 2, 3, 4, 1, 2, 3, 5, 1, 2, 3]
        var d = BASCrossTurnDrafter(priorTokens: [], ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        var rolling: [Int] = []
        for t in steps {
            rolling.append(t)
            XCTAssertEqual(d.propose(over: rolling), oracle.propose(over: rolling),
                "empty prior ⇒ identical draft to BASPromptLookupDrafter at every step (regression anchor)")
        }
    }

    func testSourceIDsMatchRouterConstants() {
        // respondAccelerated folds telemetry keyed by drafter.sourceID; the router selects + the profiler is
        // keyed by these constants. If they ever drift, the online profiler learns under the wrong key. Pin it.
        XCTAssertEqual(BASPromptLookupDrafter().sourceID, BASDraftSourceChoice.promptLookupID)
        XCTAssertEqual(
            BASCrossTurnDrafter(priorTokens: []).sourceID, BASDraftSourceChoice.suffixAutomatonID)
    }

    func testCrossTurnReusesPriorTurnTokens() {
        // Prior turn established "10 11 12 13"; this turn ends on the recurring suffix [10,11] → proposes [12,13].
        var d = BASCrossTurnDrafter(priorTokens: [10, 11, 12, 13, 99], ngramMin: 2, ngramMax: 3, numDraftTokens: 2)
        _ = d.propose(over: [10])
        XCTAssertEqual(d.propose(over: [10, 11]), [12, 13],
            "the suffix [10,11] recurs from the prior turn → its continuation [12,13] is drafted across turns")
    }

    func testCrossTurnEqualsLinearScanOverPriorPlusRolling() {
        let lo = 1, hi = 3, k = 4
        let prior = [7, 8, 9, 1, 2, 3, 7, 8]
        let oracle = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        let steps = [9, 1, 2, 9, 1]
        let got = proposals(prior: prior, rolling: steps, lo: lo, hi: hi, k: k)
        var rolling: [Int] = []
        for (i, t) in steps.enumerated() {
            rolling.append(t)
            XCTAssertEqual(got[i], oracle.propose(over: prior + rolling),
                "cross-turn draft must equal the linear scan over (prior ++ rolling)")
        }
    }

    // The cross-turn TREE assembly (proposeDistinct → buildTree) — the feed for the (gated-off) tree path. Pins
    // that, empty-store, the assembled BASDraftTree is byte-identical to the shipped BASPromptLookupDrafter.proposeTree.
    func testEmptyStoreProposeTreeMatchesPromptLookup() {
        let lo = 1, hi = 3, k = 4
        let oracle = BASPromptLookupDrafter(ngramMin: lo, ngramMax: hi, numDraftTokens: k)
        let seqs: [[Int]] = [[1, 2, 3, 4, 1, 2, 3, 5, 1, 2, 3], [9, 1, 2, 3, 7, 8, 9, 1, 2], [5, 6, 7, 5, 6]]
        for mb in [1, 2, 3] {
            for nodes in [4, 8] {
                for seq in seqs {
                    var d = BASCrossTurnDrafter(priorTokens: [], ngramMin: lo, ngramMax: hi, numDraftTokens: k)
                    var rolling: [Int] = []
                    for t in seq {
                        rolling.append(t)
                        let got = d.proposeTree(over: rolling, maxBranch: mb, maxNodes: nodes)
                        let want = oracle.proposeTree(over: rolling, maxBranch: mb, maxNodes: nodes)
                        XCTAssertEqual(got.nodes, want.nodes,
                            "empty-store cross-turn proposeTree must assemble the same tree as BASPromptLookupDrafter "
                            + "(seq=\(rolling) mb=\(mb) nodes=\(nodes))")
                    }
                }
            }
        }
    }
}
