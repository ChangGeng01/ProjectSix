import Foundation

/// What decode lanes are physically available for a turn — filled by the adapter from its own loaded state so the
/// planner stays pure (BASOrgan, MLX-free). The planner only ever returns a strategy whose capability bit is set.
public struct BASDecodeCapabilities: Sendable, Equatable {
    /// A valid same-family draft model is loaded AND speculation is live (the `shouldSpeculate` precondition).
    public let draftModelLoaded: Bool
    /// 缝6 (2026-07-06 audit): the draft-model lane's TWO protective gates were structurally inert —
    /// `_draftSpeculative` surfaces no accept telemetry (the 2.7 break-even floor stays cold forever)
    /// and `topTokenEntropy` is nil at every production call site (the 3.0-bit gate never evaluates).
    /// A host loading a draft model would route greedy free-form straight into the device-measured
    /// 0.88× LOSS with both guards armed on paper. Until accept-stat plumbing exists this stays
    /// false and the planner refuses the lane BY CONSTRUCTION (the honest negative, enforced).
    public let draftModelTelemetryAvailable: Bool
    /// A CoreAI Mamba speculator is injected / available for the Saguaro lane.
    public let saguaroAvailable: Bool
    /// The main model is loaded, so the model-free (prompt-lookup / cross-turn) loop can run.
    public let modelFreeAvailable: Bool

    /// Qwen3.5's own MTP head is loaded (opt-in weights URL provided + main model is Qwen3.5) — enables the
    /// `.mtpSpec` lane. Default false everywhere ⇒ existing hosts byte-equal (ADR-014).
    public let mtpHeadLoaded: Bool

    public init(draftModelLoaded: Bool, saguaroAvailable: Bool, modelFreeAvailable: Bool,
                mtpHeadLoaded: Bool = false, draftModelTelemetryAvailable: Bool = false) {
        self.mtpHeadLoaded = mtpHeadLoaded
        self.draftModelLoaded = draftModelLoaded
        self.saguaroAvailable = saguaroAvailable
        self.modelFreeAvailable = modelFreeAvailable
        self.draftModelTelemetryAvailable = draftModelTelemetryAvailable
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
        minDraftModelAccepted: Double = 2.7,
        // ReSpec ENTROPY GATE (telemetry-free never-worse safety for the draft-MODEL lane). The `minDraftModelAccepted`
        // floor above only bites once the profiler has a stat — but `_draftSpeculative` surfaces no accept stats, so in
        // production that lane is permanently COLD and the floor is INERT (gap-audit finding) → free-form would route to
        // the measured 0.88× LOSS. A high next-token entropy ⇒ novel/free-form region ⇒ a model-free-equivalent
        // acceptance ⇒ drafting loses; so when an entropy estimate is supplied the draft-MODEL lane is dropped above
        // `maxDraftModelEntropyBits` EVEN WHEN COLD — turning the free-form regime from 0.88×-loss into ~1.0×
        // (never-worse). `topTokenEntropy == nil` (not fed) ⇒ NOT gated ⇒ behaviour unchanged. Bits = log2 of the
        // target's next-token softmax; the default ≈3.0 bits (top token < ~1/8 mass) is a calibration starting point.
        topTokenEntropy: Double? = nil,
        maxDraftModelEntropyBits: Double = 3.0,
        // MTP lane's OWN floor (checklist trap #1: NEVER reuse the 2.7 draft-model floor). COLLAPSE
        // detection only (0.15): the fused production lane runs an ADAPTIVE-K controller that owns the
        // break-even internally (prose → K=1, the certified 1.20-1.36× regime; high-overlap → K=3) — a
        // break-even floor HERE would misread the K=1 regime's a/iter ∈ [0,1] as sub-par and exile the
        // whole lane to plain, forfeiting the certified K=1 win (the 2026-07-03 fixed-K=3 cert failure).
        // 0.15 still catches wiring-break collapse in both scales.
        minMTPAccepted: Double = 0.15,
        // SAMPLING lane's break-even floor (device A/B 2026-07-03, the draft-model 0.88× lesson applied — a
        // cost-aware gate, not purpose-blind routing). Physics from the greedy device bracket (30.1/25.7 at
        // a=0.85): per-round cost ≈1.58× a plain step ⇒ break-even a* = 0.58. Device-measured acceptance is
        // WORKLOAD-dependent: short prose a≈0.34-0.47 → 0.78-0.93× LOSS; length-matched essays a=0.62-0.68 →
        // 1.05× (physics-consistent: 1.65/1.58). Floor 0.60 = the break-even line: cold engages (learns its a
        // in 1-2 turns), sub-break-even workloads gate to plain, high-overlap ones keep the lane. STICKY BY
        // DESIGN: a gated lane folds no new observations, so it does NOT self-un-gate on a workload shift —
        // conservative at the boundary (forfeits a ~1.05× marginal win to avoid re-probing into a 0.78× loss);
        // a fresh profiler (new session) re-probes. Distribution-losslessness is unconditional either way —
        // this floor is purely a SPEED gate.
        minMTPSamplingAccepted: Double = 0.60,
        // THERMAL GATE (ship-cert finding 2026-07-03): under `serious+` throttle the MTP lane measured NET
        // NEGATIVE on real prompts (0.52-0.62× — down-clocked GPU inflates the fixed draft overhead while real-
        // text a≈0.63) → drop to plain when the host reports throttling. Default false = unchanged.
        thermalThrottled: Bool = false
    ) -> BASDecodeStrategy {
        guard Self.isGreedyByteSafe(temperature: temperature) else {
            // SAMPLING lane (temperature > 0 — the substrate's production presets): rejection-sampling verify is
            // DISTRIBUTION-lossless (unit-proven), so the MTP lane may engage; same thermal gate + own floor via
            // its profiler stream. All other speculation stays plain (byte/distribution safety per lane).
            if capabilities.mtpHeadLoaded && !thermalThrottled {
                if let s = profiler.stat(BASDecodeStrategy.mtpSpecSamplingID, purpose),
                   s.emaAccepted < minMTPSamplingAccepted {
                    return .plain
                }
                return .mtpSpecSampling
            }
            return .plain
        }

        // Candidate lanes in cold-start priority order (model-backed first), each with its profiler ID.
        var candidates: [(strategy: BASDecodeStrategy, id: String)] = []

        // MTP (the main model's own head) — highest priority when present: device-certified 1.48× at a=0.85,
        // purpose-INDEPENDENT (free-form a is as high as echo — unlike the draft-model lane), near-model-free
        // cost ⇒ NOT entropy-gated (checklist trap #3: the entropy gate exists for the COSTLY draft-model lane;
        // gating MTP would exile it from its best regime).
        if capabilities.mtpHeadLoaded && !thermalThrottled {
            candidates.append((.mtpSpec, BASDecodeStrategy.mtpSpecID))
        }

        // draft-model spec is a VALID accelerator for ANY greedy turn (byte-identical, no per-round scan tax), so it
        // is NOT purpose-gated — matching the legacy `draft()`, which spec'd regardless of elect (Option-3: select any
        // valid accelerator; plain only when none is).
        // 缝6: BOTH bits required — a loaded draft model with no accept telemetry is a lane whose
        // break-even floor can never bite (the June device verdict: free-form 0.88× net loss).
        if capabilities.draftModelLoaded && capabilities.draftModelTelemetryAvailable {
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
        // The COSTLY model-backed draft lanes (a real draft forward / token ⇒ cost `f`); the entropy gate applies to
        // both. Model-free lanes (prompt-lookup / cross-turn, `f`≈0) are never entropy-gated — a miss costs ~nothing.
        let costlyDraftLanes: Set<String> = [BASDecodeStrategy.draftModelID, BASDecodeStrategy.saguaroID]
        let viable = candidates.filter { cand in
            guard profiler.worthSpeculating(sourceID: cand.id, purpose: purpose, minHitRate: minHitRate)
            else { return false }
            // (a) telemetry-FREE entropy safety — drop any COSTLY draft lane in a high-entropy (novel/free-form)
            //     region EVEN WHEN COLD, so the never-worse guarantee holds without per-lane accept telemetry.
            if costlyDraftLanes.contains(cand.id), let h = topTokenEntropy, h > maxDraftModelEntropyBits {
                return false
            }
            // (b) draft-MODEL learned-acceptance floor — bites only once a stat exists (below break-even ⇒ drop).
            if cand.id == BASDecodeStrategy.draftModelID,
               let s = profiler.stat(cand.id, purpose), s.emaAccepted < minDraftModelAccepted {
                return false
            }
            // (c) MTP lane's OWN floor (accept-stats ARE surfaced by BASQwen35MTPSpecDecoder — the cold-forever
            //     gap of the draft-model lane does not apply here).
            if cand.id == BASDecodeStrategy.mtpSpecID,
               let s = profiler.stat(cand.id, purpose), s.emaAccepted < minMTPAccepted {
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
