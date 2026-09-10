import Foundation

/// B2-aggressive — the additive attention mask for a flattened draft tree. Pure grid logic (host-testable): the
/// only place a wrong ancestry walk silently contaminates a node's logits → a wrong-but-believed-greedy token.
///
/// Shape `[S, cacheOffset + S]` (S = flattened tree length). The prefix columns `0..<cacheOffset` are all 0 —
/// every node attends the full committed KV prefix (causally valid). The tree columns `cacheOffset + j` are 0 iff
/// flat key `j` is in node `i`'s ancestor set (self ∪ proper ancestors), else a large-negative FINITE sentinel
/// (NOT literal -inf: every row has ≥1 zero, but a finite fill matches the kernel's `scores + mask` then fp32
/// softmax numerics and can't NaN). One zero per ancestor → exactly `depth(i)+1` zeros in each row's tree block.
public enum BASTreeAttentionMask {

    /// A large-negative additive sentinel safe for fp16 (representable, dominates any logit). Matches the
    /// magnitude vendor masks use for masked positions.
    public static let maskedFill: Float = -1e4

    /// The pure `[S][cacheOffset + S]` additive grid. Row `i` (query node), column `c` (key):
    ///   c < cacheOffset                → 0 (committed prefix, always visible)
    ///   c = cacheOffset + j, j ∈ anc[i] → 0; else `maskedFill`.
    public static func grid(
        ancestorSets: [Set<Int>], cacheOffset: Int, neg: Float = maskedFill
    ) -> [[Float]] {
        let s = ancestorSets.count
        let width = cacheOffset + s
        var rows = [[Float]](repeating: [Float](repeating: 0, count: width), count: s)
        for i in 0..<s {
            let anc = ancestorSets[i]
            for j in 0..<s where !anc.contains(j) {
                rows[i][cacheOffset + j] = neg
            }
        }
        return rows
    }
}
#if canImport(MLXLLM)
import MLX

public extension BASTreeAttentionMask {
    /// Materialize the grid as an `MLXArray` of `dtype` (MUST equal the hidden-state dtype — a dtype mismatch
    /// changes the SDPA codepath), shaped `[1, 1, S, cacheOffset+S]` for broadcast over GQA heads.
    static func mlxMask(
        ancestorSets: [Set<Int>], cacheOffset: Int, dtype: DType, neg: Float = maskedFill
    ) -> MLXArray {
        let s = ancestorSets.count
        let width = cacheOffset + s
        var flat = [Float](repeating: 0, count: s * width)
        for i in 0..<s {
            let anc = ancestorSets[i]
            let base = i * width
            for j in 0..<s where !anc.contains(j) { flat[base + cacheOffset + j] = neg }
        }
        return MLXArray(flat, [1, 1, s, width]).asType(dtype)
    }
}
#endif
