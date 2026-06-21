import Foundation

/// What decode lanes are physically available for a turn — filled by the adapter from its own loaded state so the
/// planner stays pure (BASOrgan, MLX-free). The planner only ever returns a strategy whose capability bit is set.
public struct BASDecodeCapabilities: Sendable, Equatable {
    /// A valid same-family draft model is loaded AND speculation is live (the `shouldSpeculate` precondition).
    public let draftModelLoaded: Bool
    /// A CoreAI Mamba speculator is injected / available for the Saguaro lane.
    public let saguaroAvailable: Bool
    /// The main model is loaded, so the model-free (prompt-lookup / cross-turn) loop can run.
    public let modelFreeAvailable: Bool

    public init(draftModelLoaded: Bool, saguaroAvailable: Bool, modelFreeAvailable: Bool) {
        self.draftModelLoaded = draftModelLoaded
        self.saguaroAvailable = saguaroAvailable
        self.modelFreeAvailable = modelFreeAvailable
    }
}

extension BASDecodeLanePolicy {

    /// THE single decode-strategy decision (Option-3): from purpose + temperature + capabilities + acceptance
    /// profile, pick the one explicit `BASDecodeStrategy` a turn should run. Pure + host-testable; the adapter
    /// merely executes the result. Replaces the `electAccelerated` Bool + the scattered greedy-gate predicates.
    ///
    /// Precedence (safest-first):
    /// 1. `temperature != 0` → `.plain` — the hard byte-safety gate (argmax-equality accept is valid ONLY at temp 0).
    /// 2. draft-model spec is a candidate for ANY greedy turn with a draft model loaded (byte-identical, NOT
    ///    purpose-gated — preserves the legacy `draft()`, which spec'd regardless of elect).
    /// 3. model-free (prompt-lookup / cross-turn) + saguaro are added ONLY for eligible purposes
    ///    (`promptLookupEligible`); the model-free pick reuses `source(for:profiler:)` so `BASDraftSourceRouterTests`
    ///    still pins it. Non-eligible purpose with no draft model → `.plain`.
    /// 4. drop lanes whose smoothed hit-rate is below `minHitRate` (`worthSpeculating`); if none remain → `.plain`.
    /// 5. pick the highest measured `emaAccepted`; ties / cold lanes resolve by capability priority
    ///    (draftModel > saguaro > model-free — a model-backed draft is the safer cold-start default).
    /// 6. attach the profiler's warm-started K for the winning lane.
    public static func decodeStrategy(
        purpose: Purpose,
        temperature: Double,
        capabilities: BASDecodeCapabilities,
        profiler: BASAcceptanceProfiler,
        numDraftTokens: Int = 4,
        minHitRate: Double = 0.05
    ) -> BASDecodeStrategy {
        guard Self.isGreedyByteSafe(temperature: temperature) else { return .plain }

        // Candidate lanes in cold-start priority order (model-backed first), each with its profiler ID.
        var candidates: [(strategy: BASDecodeStrategy, id: String)] = []

        // draft-model spec is a VALID accelerator for ANY greedy turn (byte-identical, no per-round scan tax), so it
        // is NOT purpose-gated — matching the legacy `draft()`, which spec'd regardless of elect (Option-3: select any
        // valid accelerator; plain only when none is).
        if capabilities.draftModelLoaded {
            candidates.append((
                .draftModelSpec(numDraftTokens: profiler.recommendedK(
                    sourceID: BASDecodeStrategy.draftModelID, purpose: purpose, cap: numDraftTokens)),
                BASDecodeStrategy.draftModelID))
        }

        // model-free + saguaro pay a per-round scan / carry purpose-specific value → gated to eligible purposes only.
        if promptLookupEligible(for: purpose) {
            if capabilities.saguaroAvailable {
                candidates.append((
                    .saguaro(numDraftTokens: profiler.recommendedK(
                        sourceID: BASDecodeStrategy.saguaroID, purpose: purpose, cap: numDraftTokens)),
                    BASDecodeStrategy.saguaroID))
            }
            if capabilities.modelFreeAvailable {
                // Reuse the existing model-free router (it applies its own hit-floor) for prompt-lookup vs cross-turn.
                switch source(for: purpose, profiler: profiler, minHitRate: minHitRate) {
                case .promptLookup:
                    candidates.append((
                        .promptLookup(k: profiler.recommendedK(
                            sourceID: BASDraftSourceChoice.promptLookupID, purpose: purpose, cap: numDraftTokens)),
                        BASDraftSourceChoice.promptLookupID))
                case .suffixAutomaton:
                    candidates.append((
                        .suffixLookup(k: profiler.recommendedK(
                            sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: purpose, cap: numDraftTokens)),
                        BASDraftSourceChoice.suffixAutomatonID))
                case .none:
                    break
                }
            }
        }

        // Drop lanes not worth the per-round scan tax (cold → kept; the model-free pick already passed its own floor).
        let viable = candidates.filter {
            profiler.worthSpeculating(sourceID: $0.id, purpose: purpose, minHitRate: minHitRate)
        }
        guard let first = viable.first else { return .plain }

        // Highest measured emaAccepted wins; strict `>` keeps the earlier (higher-priority) lane on ties / cold (0).
        var best = first
        var bestScore = profiler.stat(first.id, purpose)?.emaAccepted ?? 0
        for cand in viable.dropFirst() {
            let score = profiler.stat(cand.id, purpose)?.emaAccepted ?? 0
            if score > bestScore { best = cand; bestScore = score }
        }
        return best.strategy
    }
}
