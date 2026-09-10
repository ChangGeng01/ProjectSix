import Foundation

/// Universal, model-free speculative-decode drafter (prompt-lookup / n-gram). The "draft" is the model's OWN
/// token sequence: take the last n generated tokens, find the most-recent PRIOR occurrence of that n-gram in
/// the full sequence, and propose the K tokens that followed it. The target model then verifies those tokens in
/// ONE forward pass (greedy argmax, accept-longest-prefix → byte-identical to single-model greedy).
///
/// Universal by construction: no draft MODEL, no tokenizer matching (it uses the target's own token ids), no
/// extra memory — works with ANY LLM. Near-free (a backward scan, no MLX call). Speeds up only REPETITIVE
/// output (RAG-quoted context, JSON/structured, code, verification/extraction); on non-repetitive output it
/// proposes nothing (returns []) → no speedup but no harm (the verify forward happens either way).
///
/// Pure value type (no mutation; `propose` is a read). Host-unit-testable; the decode loop that drives it lives
/// in `BASPromptLookupDecoder` (MLX-gated).
public struct BASPromptLookupDrafter: Sendable, Equatable {

    /// Shortest n-gram suffix tried.
    public let ngramMin: Int
    /// Longest n-gram suffix tried (tried FIRST — a longer match is a more confident draft).
    public let ngramMax: Int
    /// K — the maximum continuation length proposed per round (clamped to what's available).
    public let numDraftTokens: Int

    public init(ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4) {
        let lo = max(1, ngramMin)
        self.ngramMin = lo
        self.ngramMax = max(lo, ngramMax)
        self.numDraftTokens = max(1, numDraftTokens)
    }

    /// The K tokens that followed the most-recent prior occurrence of the last-n suffix; longest n wins.
    /// Returns `[]` when no suffix (ngramMin…ngramMax) recurs — the honest "no speedup, no harm" path.
    public func propose(over tokens: [Int]) -> [Int] {
        let count = tokens.count
        guard count >= 2 else { return [] }
        // Longest-first: a longer matched suffix is a stronger continuation signal.
        var n = min(ngramMax, count - 1)
        while n >= ngramMin {
            // The needle is the last n tokens; search for an EARLIER occurrence (exclude the suffix itself).
            let needleStart = count - n
            var i = count - n - 1
            while i >= 0 {
                if matches(tokens, at: i, needleStart: needleStart, length: n) {
                    let start = i + n
                    if start < count {
                        let end = min(start + numDraftTokens, count)
                        return Array(tokens[start..<end])
                    }
                }
                i -= 1
            }
            n -= 1
        }
        return []
    }

    /// TREE variant (B2-aggressive): propose a TREE of continuations — branch where the matched suffix recurred
    /// with DIFFERENT next tokens. v1 forks only at depth 1 (the highest-value divergence point), each branch
    /// then extends linearly. Branch 0 is the most-recent occurrence's continuation, so `maxBranch == 1` flattens
    /// to EXACTLY `propose()` (the linear Track-A path — a pinned regression invariant). Nodes are emitted in
    /// DEPTH-MAJOR (BFS) order (required by the tree-RoPE geometry). Returns an empty tree when nothing recurs.
    public func proposeTree(over tokens: [Int], maxBranch: Int = 2, maxNodes: Int = 8) -> BASDraftTree {
        let count = tokens.count
        guard count >= 2 else { return BASDraftTree(nodes: []) }
        let mb = Swift.max(1, maxBranch)
        var n = Swift.min(ngramMax, count - 1)
        while n >= ngramMin {
            let needleStart = count - n
            // Prior occurrence start-positions, MOST-RECENT first (so branch 0 == propose()).
            var occ: [Int] = []
            var i = count - n - 1
            while i >= 0 {
                if matches(tokens, at: i, needleStart: needleStart, length: n) { occ.append(i) }
                i -= 1
            }
            if !occ.isEmpty {
                // Distinct next-tokens, most-recent first, up to `mb` branches → each branch is that occurrence's
                // continuation (capped at numDraftTokens).
                var branches: [[Int]] = []
                var seenNext = Set<Int>()
                for pos in occ {
                    let start = pos + n
                    guard start < count else { continue }
                    let nextTok = tokens[start]
                    if seenNext.contains(nextTok) { continue }
                    seenNext.insert(nextTok)
                    let end = Swift.min(start + numDraftTokens, count)
                    branches.append(Array(tokens[start..<end]))
                    if branches.count >= mb { break }
                }
                if !branches.isEmpty { return Self.buildTree(branches: branches, maxNodes: maxNodes) }
            }
            n -= 1
        }
        return BASDraftTree(nodes: [])
    }

    /// Interleave branch continuations into a DEPTH-MAJOR (BFS) node list bounded by `maxNodes`: depth 0 = each
    /// branch's first token (parent = root 0), depth d = each branch's d-th token (parent = that branch's prior
    /// node). BFS truncation keeps the tree balanced when the node budget runs out.
    static func buildTree(branches: [[Int]], maxNodes: Int) -> BASDraftTree {
        var nodes: [BASDraftTree.Node] = []
        var lastFlat = [Int](repeating: 0, count: branches.count)   // parent for the branch's next depth (0=root)
        let maxDepth = branches.map(\.count).max() ?? 0
        outer: for d in 0..<maxDepth {
            for b in 0..<branches.count where d < branches[b].count {
                if nodes.count >= maxNodes { break outer }
                let flat = nodes.count + 1                            // this node's flat index in [seed]+nodes
                nodes.append(.init(token: branches[b][d], parent: d == 0 ? 0 : lastFlat[b]))
                lastFlat[b] = flat
            }
        }
        return BASDraftTree(nodes: nodes)
    }

    /// Element-wise compare `tokens[i ..< i+length]` to the needle `tokens[needleStart ..< needleStart+length]`
    /// with early exit (avoids allocating sub-arrays in the hot scan).
    private func matches(_ tokens: [Int], at i: Int, needleStart: Int, length: Int) -> Bool {
        var k = 0
        while k < length {
            if tokens[i + k] != tokens[needleStart + k] { return false }
            k += 1
        }
        return true
    }
}
