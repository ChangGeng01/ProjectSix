import Foundation

/// B2-aggressive — a candidate TREE for tree-structured prompt-lookup speculative decoding (the training-free
/// successor to linear `BASPromptLookupDrafter`). Instead of one linear K-token draft, a tree branches where the
/// n-gram lookup found multiple distinct continuations; the whole tree is verified in ONE target forward (custom
/// tree attention mask) and the longest root-to-leaf path whose every token is the target's greedy argmax is
/// accepted — more tokens per forward than linear, still TOKEN-identical to greedy.
///
/// Pure value type (no MLX) so the intricate ancestry / depth-major-flatten / mask geometry is host-testable —
/// that geometry is the only place tree-decode can silently diverge from greedy.
public struct BASDraftTree: Sendable, Equatable {

    /// One proposed node. `parent` is the FLATTENED index (into `[seed] + nodes`) of its parent — so the root
    /// seed is flat index 0, the first proposal is flat index 1 with `parent == 0`, etc. Nodes are stored in
    /// DEPTH-MAJOR (BFS) order: all depth-1 nodes, then all depth-2, … This is load-bearing — it makes each
    /// depth level a CONTIGUOUS flat range, which lets the vendor patch apply one scalar-offset RoPE per level
    /// (the fast kernel has no per-token position param) and keeps byte-identity.
    public struct Node: Sendable, Equatable {
        public let token: Int
        public let parent: Int
        public init(token: Int, parent: Int) { self.token = token; self.parent = parent }
    }

    /// Proposals only (the root seed is implicit at flat index 0). Empty = no speculation (degenerates to a
    /// single-token greedy step, like linear prompt-lookup with no match).
    public let nodes: [Node]

    public init(nodes: [Node]) { self.nodes = nodes }

    /// The flattened verify sequence (`S = 1 + nodes.count` long), the per-node ancestor sets (self ∪ proper
    /// ancestors, over flat indices — what each node may attend to), the per-node depth, and the contiguous
    /// per-depth flat ranges for tree RoPE. Validates the depth-major + parent-precedes-child invariants.
    public func flatten(seed: Int) -> Flattened {
        var tokens = [seed]
        tokens.reserveCapacity(nodes.count + 1)
        var depth = [0]                     // flat 0 (root) is depth 0
        var ancestors: [Set<Int>] = [[0]]   // root attends only itself
        for (k, node) in nodes.enumerated() {
            let flat = k + 1
            precondition(node.parent >= 0 && node.parent < flat,
                "BASDraftTree: parent (\(node.parent)) must be an EARLIER flat index than the child (\(flat))")
            tokens.append(node.token)
            let d = depth[node.parent] + 1
            depth.append(d)
            precondition(d >= depth[flat - 1],
                "BASDraftTree: nodes must be DEPTH-MAJOR (BFS) — node \(flat) depth \(d) < previous \(depth[flat - 1])")
            ancestors.append(ancestors[node.parent].union([flat]))
        }
        // Contiguous per-depth ranges (depth is non-decreasing by the BFS invariant just asserted).
        var segments: [(range: Range<Int>, depth: Int)] = []
        var start = 0
        while start < tokens.count {
            let d = depth[start]
            var end = start + 1
            while end < tokens.count && depth[end] == d { end += 1 }
            segments.append((start..<end, d))
            start = end
        }
        return Flattened(tokens: tokens, ancestorSets: ancestors, depth: depth, ropeSegments: segments)
    }

    public struct Flattened: Sendable, Equatable {
        public let tokens: [Int]                                  // [seed] + node tokens, length S
        public let ancestorSets: [Set<Int>]                       // flat i → {self ∪ proper ancestors}
        public let depth: [Int]                                   // flat i → tree depth (root = 0)
        public let ropeSegments: [(range: Range<Int>, depth: Int)]

        public static func == (l: Flattened, r: Flattened) -> Bool {
            l.tokens == r.tokens && l.ancestorSets == r.ancestorSets && l.depth == r.depth
                && l.ropeSegments.count == r.ropeSegments.count
                && zip(l.ropeSegments, r.ropeSegments).allSatisfy { $0.range == $1.range && $0.depth == $1.depth }
        }
    }
}
