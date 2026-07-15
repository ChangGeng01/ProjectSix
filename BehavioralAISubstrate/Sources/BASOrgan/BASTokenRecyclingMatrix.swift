import Foundation

/// BASTokenRecyclingMatrix — the pure core of the UNIVERSAL "Token Recycling" decode-draft lever (the
/// universal-decode-accel audit's #1 new lever; `decode-accel-frontier-2026` memory).
///
/// Token Recycling drafts from the TARGET's OWN top-k logit adjacency — `M[token]` = the most-likely next tokens
/// the model itself predicted right after `token`. Unlike prompt-lookup / cross-turn suffix (which mine literal
/// repeated TEXT, so they only fire on echo/repetition), this fires on **first-occurrence peaked tokens** whose
/// next-token distribution is sharp — a slice the text-based drafters structurally cannot reach. It is:
///   • UNIVERSAL — model-agnostic, no per-model training, no calibration (just the target's own logits).
///   • `f`≈0 — proposing is a dictionary walk, NO model forward (this is what makes it loss-proof where the 1B
///     GPU draft was a 0.87× net loss: cost, not acceptance, killed that lane).
///   • Byte-identical when verified — the drafter only PROPOSES; the spec loop commits ONLY the target's argmax
///     (ADR-039), so a wrong proposal costs latency, never bytes.
///
/// This type is the pure algorithm (matrix maintenance + draft extraction), MLX-free and fully host-testable —
/// exactly like `BASSuffixAutomaton`. The decode-loop integration (feeding `observe(after:topK:)` the target's
/// per-step top-k from the verify forward, and converting `proposeBranches` into a `BASDraftTree`) is a separate
/// BAS-controlled spec loop (the red-line decoders cannot be modified to feed logits) — the Phase-2 follow-up.
public struct BASTokenRecyclingMatrix: Sendable, Equatable {

    /// `M`: token → its top-k most-likely successors (ordered most-likely-first), as last observed from the target.
    private var adjacency: [Int: [Int]] = [:]

    /// How many successors to retain per token (the matrix width). The paper uses 8–10; the A19 wants this small
    /// (a narrow tree keeps the verify forward cheap — depth ≫ width, since on the A19 the verify is NOT free).
    public let k: Int

    public init(k: Int = 8) { self.k = max(1, k) }

    /// Record the target's top-k predicted successors of `token` (from the model's logits at that decode step).
    /// Latest-wins (the adjacency tracks the model's current belief). Empty `topK` is a no-op.
    public mutating func observe(after token: Int, topK: [Int]) {
        guard !topK.isEmpty else { return }
        adjacency[token] = Array(topK.prefix(k))
    }

    /// The greedy single-path draft from `last`: M[last][0] → M[that][0] → … up to `length` tokens (the
    /// most-likely continuation the model would self-predict). Stops early at the first unseen token.
    public func proposeChain(from last: Int, length: Int) -> [Int] {
        guard length > 0 else { return [] }
        var out: [Int] = []
        var cur = last
        var seen: Set<Int> = [last]           // cycle guard (M can form loops on repetitive text)
        for _ in 0..<length {
            guard let nexts = adjacency[cur], let n = nexts.first, !seen.contains(n) else { break }
            out.append(n)
            seen.insert(n)
            cur = n
        }
        return out
    }

    /// Branched draft paths from `last`: the top-`maxBranch` successors at the root, each extended greedily to
    /// `depth` total tokens — the narrow-tree shape the A19 wants (a few wide at the root, deep per branch, so the
    /// verify forward stays cheap). Returns one [Int] path per branch (each starting with the branch root).
    public func proposeBranches(from last: Int, maxBranch: Int, depth: Int) -> [[Int]] {
        guard depth > 0, let roots = adjacency[last] else { return [] }
        return roots.prefix(max(1, maxBranch)).map { root in
            [root] + proposeChain(from: root, length: depth - 1)
        }
    }

    /// Number of tokens with a recorded successor list (matrix coverage — for the promotion-gate telemetry).
    public var coverage: Int { adjacency.count }
}
