import Foundation

/// The Universal Draft Layer's source selection: which model-free draft SOURCE (if any) a turn should use, given
/// its purpose and the learned acceptance profile. Pure (BASOrgan) → host-testable; the adapter executes the
/// returned choice.
public enum BASDraftSourceChoice: String, Sendable, Equatable, CaseIterable {
    /// Fallback — plain autoregressive @1×. Used for non-eligible purposes (creative/scoutDefault) and when no
    /// source is paying off (hit-rate below floor): never pay the spec tax where nothing is accepted (亏的不要).
    case none
    /// Single-sequence n-gram (current turn only) — `BASPromptLookupDrafter`.
    case promptLookup
    /// Cross-turn suffix index (prior turns + current) — `BASCrossTurnDrafter`. Its corpus ⊇ the current
    /// sequence, so it weakly dominates prompt-lookup on acceptance.
    case suffixAutomaton

    /// Canonical `sourceID` strings the profiler is keyed by (must match the conforming drafters' `sourceID`).
    public static let promptLookupID = "prompt-lookup"
    public static let suffixAutomatonID = "suffix-automaton"
}

extension BASDecodeLanePolicy {

    /// Pick the best NET-POSITIVE model-free draft source for a purpose, given measured acceptance.
    ///
    /// - **Greedy-only invariant:** non-eligible purposes (`.creative`/`.scoutDefault`) → `.none` (plain AR @1×).
    ///   This carries the same gate as `promptLookupEligible` — a source is only ever chosen on a greedy (temp 0)
    ///   lane, where the argmax-equality accept is byte-valid.
    /// - **Pick-one (no tree-merge):** tree-verify measured a NET LOSS (0.76×) on-device, so the router never
    ///   returns a tree; it picks a single linear source.
    /// - **Cross-turn dominates:** cold-start prefers `.suffixAutomaton` (its corpus is a superset, so it can only
    ///   match more); warm, pick whichever has the higher measured `emaAccepted`.
    /// - **Hit-floor fallback:** if the chosen source's smoothed hit-rate is below `minHitRate`, return `.none`
    ///   (the per-round scan isn't being amortized — fall back to plain AR rather than pay it).
    public static func source(
        for purpose: Purpose,
        profiler: BASAcceptanceProfiler,
        minHitRate: Double = 0.05
    ) -> BASDraftSourceChoice {
        guard promptLookupEligible(for: purpose) else { return .none }

        let sa = profiler.stat(BASDraftSourceChoice.suffixAutomatonID, purpose)
        let pl = profiler.stat(BASDraftSourceChoice.promptLookupID, purpose)

        // Choose the candidate: cold (both unobserved) → the cross-turn superset; warm → higher measured acceptance
        // (ties go to cross-turn, the superset).
        let choice: BASDraftSourceChoice
        if sa == nil, pl == nil {
            choice = .suffixAutomaton
        } else if (sa?.emaAccepted ?? -1) >= (pl?.emaAccepted ?? -1) {
            choice = .suffixAutomaton
        } else {
            choice = .promptLookup
        }

        // Fallback if the chosen source has been observed and isn't worth it (don't pay the scan tax).
        let chosenID = choice == .suffixAutomaton
            ? BASDraftSourceChoice.suffixAutomatonID
            : BASDraftSourceChoice.promptLookupID
        if !profiler.worthSpeculating(sourceID: chosenID, purpose: purpose, minHitRate: minHitRate) {
            return .none
        }
        return choice
    }

    /// The FULL accelerated-entry routing decision: the greedy-only byte-safety gate composed with
    /// `source(for:profiler:)`. A non-greedy `temperature` forces `.none` (plain AR) regardless of purpose or
    /// profiler — the argmax-equality accept is byte-valid ONLY at temp 0, so this gate must never invert. Pure +
    /// host-testable so `respondAccelerated`'s gate is pinned by a unit test, not just by inspection of an inline
    /// ternary in the MLX-gated path.
    public static func acceleratedChoice(
        temperature: Double,
        purpose: Purpose,
        profiler: BASAcceptanceProfiler,
        minHitRate: Double = 0.05
    ) -> BASDraftSourceChoice {
        guard temperature == 0 else { return .none }
        return source(for: purpose, profiler: profiler, minHitRate: minHitRate)
    }
}
