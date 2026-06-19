import Foundation
import BASOrgan

/// The Universal Draft Layer's pluggable model-free draft SOURCE contract — what `BASPromptLookupDecoder` /
/// `BASTreeSpecDecoder` need from a source: an identity (for the acceptance profiler), a per-round draft length,
/// a linear proposal, and a TREE proposal. Widening the decoders to `any BASUniversalDraftSource` lets any
/// model-free source — single-sequence prompt-lookup, the cross-turn suffix automaton, future ones — plug into
/// the EXACT same verify/accept/trim loop. Byte-identity is structural: the loop only ever emits the target's
/// own argmax (the accept-longest-prefix + `for i in 0...acc` emit loop in `BASPromptLookupDecoder.generate`), so a
/// source changes only the acceptance rate, never a byte.
///
/// `propose`/`proposeTree` are `mutating` to admit STATEFUL sources (the incremental cross-turn index); the
/// stateless, value-type `BASPromptLookupDrafter` satisfies the mutating requirements with its existing
/// non-mutating methods, so its callers + behavior are unchanged.
///
/// NOTE (不要亏): `proposeTree` is a CAPABILITY, not a default decode path — tree-verify measured 0.76× (a net
/// loss) on-device, so the router never selects a tree; the tree path stays measure-only until a cache-gather
/// patch removes its structural replay-forward cost.
public protocol BASUniversalDraftSource: Sendable {
    /// Stable identity for `BASAcceptanceProfiler` (e.g. "prompt-lookup", "suffix-automaton").
    var sourceID: String { get }
    /// Maximum continuation length proposed per round (the decoder clamps further via adaptive-K).
    var numDraftTokens: Int { get }
    /// The drafted continuation given the running token sequence — `[]` for "no draft" (no speedup, no harm).
    mutating func propose(over tokens: [Int]) -> [Int]
    /// A candidate TREE (the k most-recent distinct continuations) for one-forward tree-verify. Linear sources
    /// return a degenerate single-branch tree (branch 0 == `propose`), so a caller can always ask for a tree.
    mutating func proposeTree(over tokens: [Int], maxBranch: Int, maxNodes: Int) -> BASDraftTree
}

/// The shipped, certified model-free drafter conforms unchanged (it already has `propose` + `proposeTree` +
/// `numDraftTokens`); only its `sourceID` is named here.
extension BASPromptLookupDrafter: BASUniversalDraftSource {
    public var sourceID: String { BASDraftSourceChoice.promptLookupID }
}
