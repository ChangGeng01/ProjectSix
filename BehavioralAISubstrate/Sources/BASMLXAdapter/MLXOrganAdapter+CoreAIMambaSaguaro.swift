import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// Saguaro two-stream spec-decode entry for `MLXOrganAdapter` (Track E): the MLX Llama-3.2-3B TARGET verifies a
/// CoreAI Mamba (Llamba-1B) DRAFT injected as the framework-free `BASSaguaroDraft` protocol (the module seam —
/// BASMLXAdapter stays free of a BASAppleAdapters dependency; the device probe constructs the concrete
/// `BASSaguaroSpeculator` and passes it here). Byte-identical to single-model greedy by construction (the target's
/// argmax decides every token; a wrong draft only lowers acceptance). Observation-only (红线 7).
///
/// This is the SERIAL loop (R2: `ComputeStream` can't span CoreAI+MLX, so ANE∥GPU overlap is a separate
/// device-measured add-on). The async Saguaro loop runs inside `ModelContainer.perform(nonSendable:)`'s async
/// closure, on the container's isolation — serial draft→verify, which is the product.
extension MLXOrganAdapter {

    /// Paired Saguaro (spec) vs single-model-greedy (K=0 baseline) result for one prompt.
    public struct SaguaroAB: Sendable {
        public let specTokens: [Int]
        public let specMs: Double
        public let baseTokens: [Int]
        public let baseMs: Double
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
        public let draftMs: Double     // CoreAI/ANE half of the spec run
        public let targetMs: Double    // MLX/GPU half of the spec run
    }

    /// The byte-safety routing gate (MECHANISM end; the DOCTRINE end is `BASDecodeLanePolicy.saguaroEligible`).
    /// Saguaro byte-identity is a GREEDY property (the target's argmax-equality accept is valid only at temp 0),
    /// so it runs ONLY when the host elected it AND the request is already greedy. Pure + host-testable. Mirrors
    /// `shouldUsePromptLookup`.
    public nonisolated static func shouldUseSaguaro(elect: Bool, request: BASOrganRequest) -> Bool {
        elect && request.preset.temperature == 0
    }

    /// Generate the same prompt under Saguaro (spec, K) and the null/K=0 baseline (pure target greedy), in ONE
    /// container pass, so the probe can compare TOKEN sequences (true byte-identity) + timing. `draft` is the
    /// CoreAI Mamba speculator (as a protocol). Does NOT touch the production decode path.
    public func saguaroAB(
        for request: BASOrganRequest,
        draft: BASSaguaroDraft,
        numDraftTokens K: Int = 4
    ) async throws -> SaguaroAB {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before saguaroAB"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let maxTokens = request.maxOutputTokens ?? params.maxTokens ?? 256   // loop needs a definite cap

        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            let promptTokens = input.text.tokens.asArray(Int.self)

            // SPEC (K): fresh draft state + a fresh target cache.
            draft.reset()
            let specTarget = try BASSaguaroMLXTarget(
                model: ctx.model, input: input, parameters: params, eosTokenIds: eos)
            let sSpec = DispatchTime.now().uptimeNanoseconds
            let spec = try await BASSaguaroLoop.generate(
                promptTokens: promptTokens, draft: draft, target: specTarget,
                eosTokenIds: eos, maxTokens: maxTokens, numDraftTokens: K)
            let specMs = Double(DispatchTime.now().uptimeNanoseconds &- sSpec) / 1_000_000

            // BASELINE (K=0): the SAME loop, pure target greedy (draft never invoked) → byte-identity reference.
            let baseTarget = try BASSaguaroMLXTarget(
                model: ctx.model, input: input, parameters: params, eosTokenIds: eos)
            let sBase = DispatchTime.now().uptimeNanoseconds
            let base = try await BASSaguaroLoop.generate(
                promptTokens: promptTokens, draft: draft, target: baseTarget,
                eosTokenIds: eos, maxTokens: maxTokens, numDraftTokens: 0)
            let baseMs = Double(DispatchTime.now().uptimeNanoseconds &- sBase) / 1_000_000

            return SaguaroAB(
                specTokens: spec.tokens, specMs: specMs,
                baseTokens: base.tokens, baseMs: baseMs,
                rounds: spec.rounds, proposed: spec.proposed, accepted: spec.accepted,
                draftMs: spec.draftMs, targetMs: spec.targetMs)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Host-electable PRODUCTION decode via the serial Saguaro lane (Track E). **ADR-014: DEFAULT-OFF** — nothing
    /// routes here unless a host opts a turn in with `electSaguaro = true` (typically
    /// `BASDecodeLanePolicy.saguaroEligible(for: purpose)`, computed host-side so this adapter keeps no
    /// BASOrgan-policy coupling). The `speculator` (CoreAI Mamba draft) is INJECTED — the adapter can't construct
    /// a BASAppleAdapters type, and the host owns the draft's lifecycle/loading.
    ///
    /// **Fail-closed + byte-safe:** runs Saguaro ONLY when `shouldUseSaguaro` holds (elected AND greedy, temp 0);
    /// every other case falls back to `draft(_:)`, byte-identical to today. On the Saguaro path the emitted tokens
    /// are token-identical to greedy single-model decode (the target's argmax decides every token), terminating
    /// EOS excluded. `completionMetrics` is honestly `nil` (the loop emits no `GenerateCompletionInfo`).
    public func respondCoreAIMambaSaguaro(
        for request: BASOrganRequest,
        speculator: BASSaguaroDraft,
        electSaguaro: Bool,
        numDraftTokens K: Int = 4
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        #if canImport(MLXLLM)
        // Fail-closed: not elected OR not greedy → the EXACT normal path (byte-equal, ADR-014).
        guard Self.shouldUseSaguaro(elect: electSaguaro, request: request) else {
            return try await draft(request)
        }
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before respondCoreAIMambaSaguaro"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let maxTokens = request.maxOutputTokens ?? params.maxTokens ?? 256

        let rawBody: String = try await mainContainer.perform(nonSendable: input) { ctx, input in
            // Production parity: stop on the model's chat terminators too (the superset the production stream uses).
            var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            for name in ["<|eot_id|>", "<|end_of_text|>", "<|im_end|>", "</s>"] {
                if let id = ctx.tokenizer.convertTokenToId(name) { eos.insert(id) }
            }
            let promptTokens = input.text.tokens.asArray(Int.self)
            speculator.reset()
            let target = try BASSaguaroMLXTarget(
                model: ctx.model, input: input, parameters: params, eosTokenIds: eos)
            let result = try await BASSaguaroLoop.generate(
                promptTokens: promptTokens, draft: speculator, target: target,
                eosTokenIds: eos, maxTokens: maxTokens, numDraftTokens: K)
            return ctx.tokenizer.decode(tokenIds: result.tokens)
        }
        let body = Self.applyMarkerPostprocessing(rawBody)

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter.estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID),
            completionMetrics: nil)
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}
