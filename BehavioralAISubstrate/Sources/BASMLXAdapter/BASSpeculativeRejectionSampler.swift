import Foundation

/// ⚠️ QUARANTINED (Tier-C consolidation, 2026-06-21): NOT wired into any production decode path — the only
/// references are this definition + its host tests (`BASSpeculativeSamplingDistributionTests`). It is the
/// host-verified SPECIFICATION of the sampling lane (mirrored by the vendored MLX `SpeculativeTokenIterator`
/// `.rejectionSampling`), kept for the distribution proof + correctness reference. The SHIPPED decode lane is the
/// greedy, byte-identical `BASPromptLookupDecoder`; do not enable this sampling lane without re-certifying the MLX port.
///
/// 结构大重构 — Phase 2: the pure (framework-free) Leviathan speculative-sampling decision rule.
///
/// This is the SPECIFICATION + host-verifiable core of the sampling lane. The vendored MLX
/// `SpeculativeTokenIterator` (`.rejectionSampling` strategy, Phase 2 patch) implements the SAME math on-GPU; it
/// cannot import this module (the vendor can't depend on BAS), so the two are kept in lockstep by mirroring the
/// rule here and proving it host-side, then certifying the MLX port produces an equivalent distribution on device.
///
/// ## The rule (Leviathan et al. 2023 / Chen et al. 2023)
/// A draft token `x` was sampled from the draft distribution `q`. The target distribution is `p`. Accept `x`
/// with probability `min(1, p(x)/q(x))`. On rejection, emit a fresh token sampled from the normalized residual
/// `(p − q)₊ / Σ(p − q)₊`. This makes the emitted token's distribution EXACTLY `p` — i.e. speculative sampling is
/// **distribution-equivalent** to sampling from the target alone (the proof: P(emit y) = q(y)·min(1,p(y)/q(y)) +
/// (1 − α)·residual(y) = p(y), where α is the overall acceptance mass).
///
/// ## Honesty (亏的不要 / R1)
/// This is distribution-equivalence, NOT bytewise identity: a sampling run is reproducible only under a fixed
/// seed, and even then is not token-identical to target-only-with-the-same-seed (the random draws are consumed
/// differently). The greedy lane (`BASSpeculativeMode.greedy`) is the bytewise-identical one; this lane trades
/// that for a latency win at temperature > 0 while preserving the output distribution.
public enum BASSpeculativeRejectionSampler {

    /// Accept a drafted token under the rule `accept iff u ≤ min(1, p/q)`, with `u ~ Uniform[0,1)`.
    ///
    /// - Parameters:
    ///   - targetProb: `p(x)` — the target model's probability of the drafted token.
    ///   - draftProb: `q(x)` — the draft model's probability of the token it drafted (> 0 by construction; it
    ///     sampled `x`). A non-positive `q` is a numerical degenerate handled by accepting (ratio → ∞ ⇒ min = 1).
    ///   - uniform: a draw from `Uniform[0,1)`.
    public static func accepts(targetProb: Double, draftProb: Double, uniform: Double) -> Bool {
        guard draftProb > 0 else { return true }
        return uniform <= min(1.0, targetProb / draftProb)
    }

    /// The normalized residual distribution `(p − q)₊ / Σ(p − q)₊` to sample from on rejection.
    ///
    /// If the residual mass is non-positive (a numerical edge where `q` dominates `p` everywhere the residual is
    /// nonzero), falls back to the normalized target `p` — still a valid draw from a target-consistent
    /// distribution, never a crash or a zero vector.
    public static func residual(target: [Double], draft: [Double]) -> [Double] {
        precondition(target.count == draft.count, "target/draft distributions must have equal support")
        var residual = [Double](repeating: 0, count: target.count)
        var mass = 0.0
        for i in 0..<target.count {
            let d = max(0, target[i] - draft[i])
            residual[i] = d
            mass += d
        }
        guard mass > 0 else { return normalized(target) }
        for i in 0..<residual.count { residual[i] /= mass }
        return residual
    }

    /// Sample an index from a (assumed-normalized) distribution by inverse-CDF on a `Uniform[0,1)` draw.
    /// Robust to tiny normalization error: always returns the last index if `uniform` overshoots the CDF.
    public static func sampleIndex(distribution: [Double], uniform: Double) -> Int {
        var cumulative = 0.0
        for i in 0..<distribution.count {
            cumulative += distribution[i]
            if uniform < cumulative { return i }
        }
        return max(0, distribution.count - 1)
    }

    /// Normalize a non-negative vector to sum 1 (uniform fallback if the input sums to ≤ 0).
    public static func normalized(_ x: [Double]) -> [Double] {
        let sum = x.reduce(0, +)
        guard sum > 0 else {
            let n = max(1, x.count)
            return [Double](repeating: 1.0 / Double(n), count: x.count)
        }
        return x.map { $0 / sum }
    }
}
