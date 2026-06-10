import Foundation

/// Speculative-decoding mode for `MLXOrganAdapter` (结构大重构 / speculative decode).
///
/// A draft small model proposes K tokens per round and the large target model verifies them in one forward
/// pass — accepting a proposed token only when it matches what the target would have produced. The vendored
/// `MLXLMCommon.SpeculativeTokenIterator` (mlx-swift-lm 3.31.3) implements the decoder; this enum selects the
/// BAS-side lane.
///
/// ## ADR-014 OPT-IN
/// `.off` is the default everywhere (the adapter `init` defaults `speculativeDecoding: .off` and `draftModel:
/// nil`). With it off, the streaming/draft path is the exact pre-speculative single-model code — byte-identical
/// to today, by construction. 红线 7 / observation-only: speculative decoding lives entirely in the MLX
/// reasoning lane and never enters the byte-deterministic Rust+SQL spine.
///
/// ## Correctness lanes (亏的不要 / R1)
/// - `.greedy` — temperature==0. The vendored acceptance is EXACT token-equality, so at argmax the accepted
///   stream is **token-identical to greedy target-only decoding**: provable byte-identity plus a latency win.
/// - `.sampling` — temperature>0. Exact-equality acceptance is NOT distribution-preserving for stochastic
///   sampling; the honest lane needs Leviathan rejection sampling (accept with prob `min(1, p/q)`, else resample
///   the normalized residual `(p−q)₊`) — **distribution-equivalent, not bytewise**. Wired in Phase 2; until
///   then `MLXOrganAdapter.shouldSpeculate` keeps `.sampling` OFF (falls back to single-model rather than
///   silently running the distribution-altering argmax path).
public enum BASSpeculativeMode: String, Sendable, Equatable, Codable, CaseIterable {
    /// Single-model decoding — byte-identical to the pre-speculative path (the ADR-014 default).
    case off

    /// Greedy (temperature==0) speculative decoding — token-identical to greedy target-only decoding.
    case greedy

    /// Sampling (temperature>0) speculative decoding with rejection sampling — distribution-equivalent
    /// (statistical, not bytewise). Phase 2.
    case sampling
}
