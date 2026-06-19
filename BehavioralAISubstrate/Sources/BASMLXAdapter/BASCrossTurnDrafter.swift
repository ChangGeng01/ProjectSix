import Foundation
import BASOrgan

/// Cross-turn, model-free draft SOURCE for `BASPromptLookupDecoder`: a `BASSuffixAutomaton` seeded with the
/// conversation's PRIOR-TURN tokens, then fed this turn's prompt + generated tokens as the decode loop calls
/// `propose(over:)`. So the draft can reuse tokens from EARLIER turns — where RAG / agentic / tool-loop
/// repetition actually lives — not just the current sequence, while the verify/accept/trim loop stays
/// byte-identical (the verifier only emits the target's argmax).
///
/// EMPTY-STORE INVARIANT (the regression anchor): seeded with no prior tokens, this is byte-identical to the
/// shipped `BASPromptLookupDrafter` — the automaton's `propose` is parity-proven equal to the linear scan over
/// the same tokens, and the decoder loop is unchanged.
public struct BASCrossTurnDrafter: BASUniversalDraftSource {

    public var sourceID: String { BASDraftSourceChoice.suffixAutomatonID }
    public let numDraftTokens: Int
    private var automaton: BASSuffixAutomaton
    /// How many of the decoder's running `rolling` sequence have already been folded into the automaton.
    private var synced: Int = 0

    public init(
        priorTokens: [Int], ngramMin: Int = 1, ngramMax: Int = 3,
        numDraftTokens: Int = 4, capacityPerSession: Int = 8192
    ) {
        var a = BASSuffixAutomaton(
            ngramMin: ngramMin, ngramMax: ngramMax,
            numDraftTokens: numDraftTokens, capacity: capacityPerSession)
        a.append(contentsOf: priorTokens)
        self.automaton = a
        self.numDraftTokens = a.numDraftTokens
    }

    /// Fold any newly-emitted tail of `rolling` into the cross-turn corpus, then propose over the WHOLE corpus
    /// (prior turns + this turn's prompt + generated). `rolling` only grows within a generate call, so the
    /// `synced` cursor advances monotonically.
    public mutating func propose(over tokens: [Int]) -> [Int] {
        sync(tokens)
        return automaton.propose(k: numDraftTokens)
    }

    /// Cross-turn TREE proposal: the k most-recent distinct continuations from the corpus, assembled into a
    /// `BASDraftTree` via the certified `buildTree`. CAPABILITY ONLY — the router never selects a tree
    /// (tree-verify is a measured 0.76× loss); this feeds the measure-only tree probe + future cache-gather work.
    public mutating func proposeTree(over tokens: [Int], maxBranch: Int, maxNodes: Int) -> BASDraftTree {
        sync(tokens)
        let branches = automaton.proposeDistinct(maxBranch: maxBranch, k: numDraftTokens)
        guard !branches.isEmpty else { return BASDraftTree(nodes: []) }
        return BASPromptLookupDrafter.buildTree(branches: branches, maxNodes: maxNodes)
    }

    /// Fold any newly-emitted tail of `rolling` into the cross-turn corpus (monotonic within a generate call).
    private mutating func sync(_ tokens: [Int]) {
        if tokens.count > synced {
            automaton.append(contentsOf: Array(tokens[synced...]))
            synced = tokens.count
        }
    }
}
