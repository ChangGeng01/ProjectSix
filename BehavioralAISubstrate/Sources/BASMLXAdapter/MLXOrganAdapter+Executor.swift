import Foundation
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

extension MLXOrganAdapter {

    /// Execute a planned `BASDecodeStrategy` — the "execution hands" (DecodePlan S3). Each arm dispatches to an
    /// EXISTING byte-identity path (the S1 helpers / the kernels), so the OUTPUT is identical to the legacy inline
    /// routing — only WHICH lane runs differs. The "strategy brain" is `BASDecodeLanePolicy.decodeStrategy(...)`;
    /// this method makes no further decision. Every arm emits the target's argmax (ADR-039) → token-identical to
    /// plain greedy for the same request.
    ///
    /// `purpose` + `sessionID` close two gap-audit holes (查缺补漏 T2/T3) WITHOUT changing per-turn output:
    ///   • T2 — model-free lanes fold their acceptance telemetry into `draftProfiler` (the fold runs AFTER the
    ///     generate, so it cannot affect the current turn; it only makes the planner's NEXT model-free lane choice
    ///     adaptive — and every lane is byte-identical, so a different choice changes latency, not bytes). Without
    ///     this the profiler was permanently COLD in production and the router never learned.
    ///   • T3 — when a `sessionID` is supplied (the `draft(_:purpose:sessionID:)` overload), `.suffixLookup` seeds
    ///     its drafter from the cross-turn corpus and folds this turn back in, so the device-gated cross-turn win
    ///     (1.07–1.41×) is actually reachable. `sessionID == nil` (the single-shot entries) keeps the empty-store
    ///     path → byte-identical to prompt-lookup, exactly as before.
    /// NOTE — the `.draftModelSpec` lane does NOT fold telemetry: `_draftSpeculative` consumes only a chunk stream +
    /// `GenerateCompletionInfo` and never surfaces per-round accept stats, so the draft-MODEL `emaAccepted` (the
    /// `minDraftModelAccepted=2.7` gate) cannot learn from here. It is currently MOOT (no draft model is deployed);
    /// making the 2.7 gate live needs spec-accept-stat plumbing out of MLX generate (deferred follow-up).
    func _execute(
        _ strategy: BASDecodeStrategy, for request: BASOrganRequest,
        purpose: BASDecodeLanePolicy.Purpose, sessionID: String? = nil
    ) async throws -> BASOrganDraft {
        #if canImport(MLXLLM)
        switch strategy {
        case .plain:
            return try await _plainDraft(request)

        case .draftModelSpec:
            // `_draftSpeculative` uses the adapter's configured `numDraftTokens`; the strategy's K is advisory.
            return try await _draftSpeculative(request)

        case .promptLookup(let k):
            let g = try await _generateModelFree(
                for: request, drafter: BASPromptLookupDrafter(numDraftTokens: k))
            // T2: online telemetry → the router learns prompt-lookup's net acceptance for this purpose.
            draftProfiler = draftProfiler.observing(
                sourceID: BASDraftSourceChoice.promptLookupID, purpose: purpose,
                accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
            return _modelFreeDraft(body: g.body, request: request)

        case .suffixLookup(let k):
            // T3: seed from the session corpus when present; nil session → empty store = byte-identical to
            // prompt-lookup (the BASCrossTurnDrafter empty-store parity anchor).
            let prior = sessionID.map { crossTurnStore.tokens(session: $0) } ?? []
            let g = try await _generateModelFree(
                for: request, drafter: BASCrossTurnDrafter(priorTokens: prior, numDraftTokens: k))
            // Carry THIS turn (prompt + generated) into the corpus for the next turn's cross-turn draft.
            // HOST CONTRACT (footgun): accumulate via a stable sessionID and do NOT re-send chat history in
            // request.context, else the re-rendered prompt re-contains prior turns → duplicate appends + premature
            // FIFO eviction. (A store-level synced cursor mirroring BASCrossTurnDrafter.synced is the eventual fix.)
            if let sid = sessionID {
                crossTurnStore.append(session: sid, contentsOf: g.promptTokens + g.genTokens)
            }
            // T2: online telemetry for the cross-turn lane.
            draftProfiler = draftProfiler.observing(
                sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: purpose,
                accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
            return _modelFreeDraft(body: g.body, request: request)

        case .saguaro:
            throw BASOrganError.providerUnavailable(
                reason: "saguaro strategy requires an injected CoreAI speculator — use respondCoreAIMambaSaguaro(speculator:)")

        case .probeOnly:
            // Measure-only sentinel; the production planner never returns it. Fail-closed to plain.
            return try await _plainDraft(request)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}
