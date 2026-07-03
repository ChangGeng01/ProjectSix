import Foundation

/// The explicit decode strategy a turn should run — chosen by the single planner
/// (`BASDecodeLanePolicy.decodeStrategy(...)`) from purpose + preset + capabilities + acceptance profile.
/// Replaces the overloaded `electAccelerated` Bool and the scattered `shouldSpeculate` / `shouldUsePromptLookup`
/// / `shouldUseSaguaro` gates with ONE typed decision. The adapter EXECUTES the returned strategy and makes no
/// further routing choice ("strategy brain" vs "execution hands"). Pure (BASOrgan) → host-testable.
///
/// ★ Byte invariant: every accelerated lane emits ONLY the target model's argmax (ADR-039) — the drafter changes
/// the acceptance rate, never a byte. So the strategy changes LATENCY (and which lane runs), never the output
/// tokens: `.plain` and any accelerated strategy produce token-identical greedy output for the same request.
public enum BASDecodeStrategy: Sendable, Equatable {
    /// Single-model autoregressive @1×. The ONLY valid strategy at temperature > 0, or when no accelerator is
    /// available / eligible / paying off. Executed via `MLXOrganAdapter._plainDraft`.
    case plain
    /// Draft-model speculative decode (vendored greedy spec, argmax-equality accept). `numDraftTokens` = the
    /// profiler-warm-started K. Executed via `_draftSpeculative`.
    case draftModelSpec(numDraftTokens: Int)
    /// Model-free single-sequence n-gram over the current turn — `BASPromptLookupDrafter`. `k` = warm-started
    /// draft length. Executed via `_generateModelFree`.
    case promptLookup(k: Int)
    /// Model-free cross-turn suffix index (prior turns + current) — `BASCrossTurnDrafter`; its corpus ⊇ the
    /// current sequence, so it weakly dominates `promptLookup`. `k` = warm-started length. Via `_generateModelFree`.
    case suffixLookup(k: Int)
    /// CoreAI Mamba draft ∥ MLX target (Saguaro). `numDraftTokens` = warm-started K. Via the Saguaro executor path.
    case saguaro(numDraftTokens: Int)
    /// Qwen3.5's own MTP head as the drafter (K=1, sub-head draft argmax, carry-forward reject) — the MAIN
    /// model's ONLY spec lane (no same-tokenizer sibling exists; the vendored draft path fails closed on GDN).
    /// Device-certified 30.1 tok/s vs plain 20.3 (bracketed, a=0.85, ADR-039 lossless). Executed via
    /// `BASQwen35MTPSpecDecoder` behind an OPT-IN weights URL (default nil = lane never offered = byte-equal).
    case mtpSpec
    /// Measure-only (AB harnesses / device probes). NEVER returned by the production planner — it documents that
    /// the measure lanes exist outside the production decision surface.
    case probeOnly

    /// Canonical profiler `sourceID`s for the model-BACKED lanes (the model-free ones live on
    /// `BASDraftSourceChoice`). The acceptance profiler is keyed by these so each lane learns independently.
    public static let draftModelID = "draft-model"
    public static let saguaroID = "saguaro"
    public static let mtpSpecID = "mtp-qwen35"
}
