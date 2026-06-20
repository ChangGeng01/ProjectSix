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
    func _execute(_ strategy: BASDecodeStrategy, for request: BASOrganRequest) async throws -> BASOrganDraft {
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
            return _modelFreeDraft(body: g.body, request: request)

        case .suffixLookup(let k):
            // A single-turn entry has no cross-turn corpus → an empty store is byte-identical to prompt-lookup
            // (the BASCrossTurnDrafter empty-store parity anchor). Multi-turn seeding is the cross-turn entry's job.
            let g = try await _generateModelFree(
                for: request, drafter: BASCrossTurnDrafter(priorTokens: [], numDraftTokens: k))
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
