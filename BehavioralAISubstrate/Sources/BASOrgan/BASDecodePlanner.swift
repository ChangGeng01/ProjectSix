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
    /// 4. drop lanes not worth their COST: model-free below `minHitRate` (cheap → hit-rate floor); the draft-MODEL lane
    ///    below `minDraftModelAccepted` (a full draft forward/token ⇒ needs a NET-POSITIVE accepted-per-round floor —
    ///    Gate 2b: free-form a≈2 is a 0.88× LOSS). Cold lanes stay (to learn); if none remain → `.plain`.
    /// 5. pick the highest measured `emaAccepted`; ties / cold lanes resolve by capability priority
    ///    (draftModel > saguaro > model-free — a model-backed draft is the safer cold-start default).
    /// 6. attach the profiler's warm-started K for the winning lane.
    public static func decodeStrategy(
        purpose: Purpose,
        temperature: Double,
        capabilities: BASDecodeCapabilities,
        profiler: BASAcceptanceProfiler,
        numDraftTokens: Int = 4,
        minHitRate: Double = 0.05,
        // Net-positive accepted-per-round floor for the HIGH-COST draft-MODEL lane. On the A19 (1B draft vs 3B target,
        // K=4) the end-to-end break-even is ≈2.7 (Gate 2b: free-form a≈2 → 0.88× LOSS; reasoning a≈3 → 1.06×). Below
        // this the draft-model lane is a latency loss → fall back to plain. Model-free lanes (≈0 cost) keep `minHitRate`.
        minDraftModelAccepted: Double = 2.7
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

        // Drop lanes not worth their COST (cold → kept, to gather a measurement). Two floors by lane cost:
        //   • model-free (≈0 cost): the smoothed hit-rate `minHitRate` (its own router floor already applied above).
        //   • draft-MODEL (a full draft forward / token): a NET-POSITIVE accepted-per-round floor `minDraftModelAccepted`
        //     — below break-even it's a measured latency LOSS (Gate 2b free-form 0.88×), so fall back to plain. Cold (no
        //     stat) stays in to learn; once measured below break-even it drops out (e.g. free-form .scoutDefault).
        let viable = candidates.filter { cand in
            guard profiler.worthSpeculating(sourceID: cand.id, purpose: purpose, minHitRate: minHitRate)
            else { return false }
            if cand.id == BASDecodeStrategy.draftModelID,
               let s = profiler.stat(cand.id, purpose), s.emaAccepted < minDraftModelAccepted {
                return false
            }
            return true
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
