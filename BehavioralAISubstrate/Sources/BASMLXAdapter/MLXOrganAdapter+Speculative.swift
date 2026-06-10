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

    /// Actor-isolated speculative streaming body. Precondition (asserted by `shouldSpeculate`): a draft container
    /// is loaded and the mode is live. Greedy lane only in Phase 0/1.
    func _streamDraftSpeculative(
        _ request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(
                    "loadModel(progressHandler:) before speculative streamDraft(_:)"))
        }
        guard let draftContainer = self._loadedDraftContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(
                    "loadDraftModel(progressHandler:) before speculative streamDraft(_:)"))
        }

        // Build the LMInput exactly as the single-model ChatSession path does (same system instructions + user
        // prompt) so the prompt tokenization is identical — only the decoder differs.
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
        //                target-only decoding (bytewise-provable).
        //  • .sampling — preset temperature → Leviathan rejection sampling → distribution-equivalent to
        //                target-only sampling (statistical, device-cert-pending).
        let params: GenerateParameters
        let acceptance: SpeculativeAcceptanceStrategy
        switch speculativeDecoding {
        case .sampling:
            params = self._generateParameters(
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
        let draftBox = try await draftContainer.perform { ctx in
            DraftModelBox(ctx.model)
        }

        // Drive the vendored speculative generate inside the main container's serial-access closure. `input`
        // (non-Sendable LMInput) is transferred via the `perform(nonSendable:)` overload; the returned
        // AsyncStream<Generation> is Sendable and drives the SpeculativeTokenIterator lazily.
        let stream = try await mainContainer.perform(
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
}
