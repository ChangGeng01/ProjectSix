import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// 结构大重构 — speculative-decoding streaming path for `MLXOrganAdapter`.
///
/// Mirrors `MLXOrganAdapter+Streaming.swift` but drives the vendored speculative decoder
/// (`MLXLMCommon.generate(input:cache:parameters:context:draftModel:draftCache:numDraftTokens:)`,
/// `Evaluate.swift`) with the co-resident draft model. The prompt encoding is built EXACTLY as the single-model
/// path would (same system instructions + prompt → same `LMInput`); only the DECODER differs.
///
/// Greedy lane (Phase 0/1): `_greedyParameters` forces temperature 0, so the vendored exact-equality acceptance
/// is token-identical to greedy target-only decoding — provable byte-identity plus a latency win. The sampling
/// lane (Phase 2) reuses this path with the preset temperature once the rejection-sampling acceptance lands.
///
/// Observation-only (红线 7): this lives entirely in the MLX reasoning lane and never touches the
/// byte-deterministic spine.
extension MLXOrganAdapter {

    #if canImport(MLXLLM)
    /// `@unchecked Sendable` carrier that moves the non-Sendable draft `any LanguageModel` across the main
    /// container's `perform` boundary — the exact escape `ChatSession` uses (the vendor's `SendableBox` is
    /// `package`-scoped, invisible to this package). Sound because BOTH models live on this actor and inference
    /// serializes through it + each container's `SerialAccessContainer`; the weights are evaluated/immutable and
    /// never mutated concurrently.
    fileprivate final class DraftModelBox: @unchecked Sendable {
        let model: any LanguageModel
        init(_ model: any LanguageModel) { self.model = model }
    }
    #endif

    #if canImport(MLXLLM)
    /// Shared setup + decode for BOTH speculative entry points (streaming `_streamDraftSpeculative` and the
    /// non-streaming `_draftSpeculative`): container guards, ChatSession-identical prompt construction, lane
    /// parameter selection, the DraftModelBox transfer, and the vendored speculative `generate(...)` call.
    /// Returns the raw `AsyncStream<Generation>` for the caller to consume (yield chunks vs accumulate).
    private func _speculativeGenerationStream(
        for request: BASOrganRequest
    ) async throws -> AsyncStream<Generation> {
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(
                    "loadModel(progressHandler:) before speculative draft"))
        }
        guard let draftContainer = self._loadedDraftContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(
                    "loadDraftModel(progressHandler:) before speculative draft"))
        }

        // Build the LMInput exactly as the single-model ChatSession path does (same system instructions + user
        // prompt) so the prompt tokenization is identical — only the decoder differs. (Hardware-verified: the
        // n=50 greedy cert's bytewise identity would have failed on any prompt-construction drift.)
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty {
            messages.append(.system(instructions))
        }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(
            input: UserInput(chat: messages))

        // Choose the lane by mode:
        //  • .greedy   — temperature 0 → ArgMaxSampler → exact-equality acceptance → token-identical to greedy
        //                target-only decoding (bytewise-provable; n=50 dual-device hardware-verified).
        //  • .sampling — preset temperature with the PURE-TEMPERATURE envelope forced (`_samplingParameters`
        //                sets topP=1 — the rejection branch's exactness envelope) → Leviathan rejection
        //                sampling → distribution-equivalent (on-device dist-check verified; latency-certified
        //                doNotEnable, so this lane only runs on explicit host election).
        let params: GenerateParameters
        let acceptance: SpeculativeAcceptanceStrategy
        switch speculativeDecoding {
        case .sampling:
            params = self._samplingParameters(
                for: request.preset,
                maxOutputTokens: request.maxOutputTokens)
            acceptance = .rejectionSampling
        case .greedy, .off:
            params = self._greedyParameters(
                for: request.preset,
                maxOutputTokens: request.maxOutputTokens)
            acceptance = .argmaxEquality
        }
        let nDraft = self.numDraftTokens

        // Move the draft model handle across the main container's perform boundary (see DraftModelBox).
        let draftBox = await draftContainer.perform { ctx in
            DraftModelBox(ctx.model)
        }

        // Drive the vendored speculative generate inside the main container's serial-access closure. `input`
        // (non-Sendable LMInput) is transferred via the `perform(nonSendable:)` overload; the returned
        // AsyncStream<Generation> is Sendable and drives the SpeculativeTokenIterator lazily.
        return try await mainContainer.perform(
            nonSendable: input
        ) { mainContext, input in
            try MLXLMCommon.generate(
                input: input,
                cache: nil,
                parameters: params,
                context: mainContext,
                draftModel: draftBox.model,
                draftCache: nil,
                numDraftTokens: nDraft,
                acceptanceStrategy: acceptance)
        }
    }
    #endif

    /// Actor-isolated speculative streaming body. Precondition (asserted by `shouldSpeculate`): a draft container
    /// is loaded and the request is mode-eligible.
    func _streamDraftSpeculative(
        _ request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        let stream = try await _speculativeGenerationStream(for: request)
        var cumulative = ""
        for await item in stream {
            guard case let .chunk(delta) = item else { continue }
            cumulative += delta
            // Same marker-postprocessing contract as the single-model streaming path: `bodyDelta` stays raw,
            // `cumulativeBody` rewrites [NEEDS_VERIFICATION] → [NEEDS_PERMIT].
            let chunk = BASOrganDraftChunk(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                bodyDelta: delta,
                cumulativeBody:
                    MLXOrganAdapter.applyMarkerPostprocessing(
                        cumulative),
                producedAt: Date())
            continuation.yield(chunk)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Non-streaming speculative draft — the `draft(_:)` counterpart of `_streamDraftSpeculative`. Accumulates
    /// the speculative stream and captures the terminal `.info` (`GenerateCompletionInfo`) so the returned
    /// `BASOrganDraft` carries REAL prefill/decode metrics, exactly like the single-model `draft(_:)` path.
    /// The body construction mirrors `draft(_:)` field-for-field (marker postprocessing, token estimates,
    /// deterministic traceID) so callers can't tell which decoder produced the draft — except by latency.
    ///
    /// NOTE — `draftMultiTurn` is DELIBERATELY not speculative: its value is ChatSession KV-cache reuse across
    /// turns (only the new turn's tokens prefill). The speculative path builds fresh caches per call, so routing
    /// multi-turn through it would RE-PREFILL the whole conversation every turn — a net loss (亏的不要).
    func _draftSpeculative(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        #if canImport(MLXLLM)
        let stream = try await _speculativeGenerationStream(for: request)
        var rawBody = ""
        var completionInfo: GenerateCompletionInfo?
        for await item in stream {
            switch item {
            case .chunk(let delta): rawBody += delta
            case .info(let info): completionInfo = info
            default: break
            }
        }
        let body = Self.applyMarkerPostprocessing(rawBody)  // M256 — same contract as draft(_:)
        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(
                    from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID),
            completionMetrics: Self.completionMetrics(from: completionInfo))
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}
