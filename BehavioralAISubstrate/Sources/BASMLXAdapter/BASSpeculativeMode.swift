import Foundation

/// Speculative-decoding mode for `MLXOrganAdapter` (结构大重构 / speculative decode).
///
/// A draft small model proposes K tokens per round and the large target model verifies them in one forward
/// pass — accepting a proposed token only when it matches what the target would have produced. The vendored
/// `MLXLMCommon.SpeculativeTokenIterator` (mlx-swift-lm 3.31.3) implements the decoder; this enum selects the
/// BAS-side lane.
///
/// ## Default: `.greedy`, triple-gated (operator-elected 2026-06-11)
/// The adapter `init` defaults `speculativeDecoding: .greedy` (`MLXOrganAdapter.swift` init) — flipped from
/// `.off` when the operator acted on the dual-device greedy `enable` cert (`Docs/SPEC_DECODE_CERT_RESULTS.md`,
/// "Action: greedy speculative decoding is now default-on (gated, byte-identical fallback)"). Three fail-closed
/// gates keep the flip byte-safe:
///   1. REQUEST gate — speculation engages only when the request's `temperature == 0` (a scout 0.1 / core 0.7
///      request is NEVER converted to greedy; it takes the single-model path unchanged).
///   2. MEMORY gate — the curated draft loads only if dual residency fits the budget
///      (`BASMLXMemoryBudget.dualResidencyFits`); no fit ⇒ no draft ⇒ single-model.
///   3. `.sampling` is NEVER auto-engaged (certified `doNotEnable` — see below).
/// When any gate declines, the streaming/draft path is the exact pre-speculative single-model code —
/// byte-identical fallback by construction. Where greedy DOES engage, the accepted stream is token-identical
/// to greedy target-only decoding (see Correctness lanes). Hosts can still elect `.off` explicitly for the
/// unconditional pre-speculative path. 红线 7: speculative decoding lives entirely in the MLX reasoning lane
/// and never enters the byte-deterministic Rust+SQL spine.
///
/// ## Correctness lanes (亏的不要 / R1)
/// - `.greedy` — temperature==0. The vendored acceptance is EXACT token-equality, so at argmax the accepted
///   stream is **token-identical to greedy target-only decoding**: provable byte-identity plus a latency win.
/// - `.sampling` — temperature>0. Exact-equality acceptance is NOT distribution-preserving for stochastic
///   sampling; the honest lane needs Leviathan rejection sampling (accept with prob `min(1, p/q)`, else resample
///   the normalized residual `(p−q)₊`) — **distribution-equivalent, not bytewise**. This lane is never the
///   default because the current device cert says `doNotEnable` at the default draft length; a host/probe must
///   explicitly construct the adapter with `.sampling`.
public enum BASSpeculativeMode: String, Sendable, Equatable, Codable, CaseIterable {
    /// Single-model decoding — byte-identical to the pre-speculative path。 Host-electable opt-out
    /// (the adapter default is `.greedy` since the 2026-06-11 cert-backed flip;gates fall back here)。
    case off

    /// Greedy (temperature==0) speculative decoding — token-identical to greedy target-only decoding.
    case greedy

    /// Sampling (temperature>0) speculative decoding with rejection sampling — distribution-equivalent
    /// (statistical, not bytewise). Phase 2.
    case sampling
}
