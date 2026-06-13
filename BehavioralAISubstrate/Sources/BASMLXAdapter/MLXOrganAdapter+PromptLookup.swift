import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// Universal prompt-lookup speculative decode entry for `MLXOrganAdapter` (Track A). Runs the BAS-owned
/// `BASPromptLookupDecoder` (greedy, byte-identical, no draft model) and an apples-to-apples baseline (the SAME
/// decoder with a null drafter = pure single-model greedy), so the probe can compare TOKEN sequences directly
/// (true byte-identity) and timing (speedup) without detokenization fragility. Does NOT touch the production
/// decode path — the probe calls this directly. Observation-only (红线 7), MLX reasoning lane.
extension MLXOrganAdapter {

    /// Paired prompt-lookup vs single-model-greedy result for one prompt.
    public struct PromptLookupAB: Sendable {
        public let specTokens: [Int]
        public let specMs: Double
        public let baseTokens: [Int]
        public let baseMs: Double
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
    }

    /// A drafter that never proposes (ngram longer than any short generation) → the decoder degrades to pure
    /// single-model greedy, the byte-identity + timing baseline.
    static var nullDrafter: BASPromptLookupDrafter {
        BASPromptLookupDrafter(ngramMin: 100_000, ngramMax: 100_000, numDraftTokens: 1)
    }

    /// The byte-safety routing gate for the host-electable prompt-lookup production path (the MECHANISM end of
    /// the doctrine→mechanism contract; the DOCTRINE end is `BASDecodeLanePolicy.promptLookupEligible(for:)` in
    /// BASOrgan). Pure + framework-free + host-testable (no container) — mirrors `requestEligibleForSpeculation`.
    ///
    /// Prompt-lookup runs ONLY when the host elected it AND the request is ALREADY greedy (`temperature == 0`):
    /// prompt-lookup byte-identity is a GREEDY property — its argmax-equality accept is valid only at temp 0, so
    /// a scout (0.1) / core (0.7) request must NEVER be routed through it (that would change the output). The
    /// purpose→`elect` decision stays host-side so this adapter keeps NO BASOrgan-policy coupling (same split as
    /// `requestEligibleForSpeculation`, which keys on `temperature`, not on a BASOrgan enum).
    public nonisolated static func shouldUsePromptLookup(
        elect: Bool, request: BASOrganRequest
    ) -> Bool {
        elect && request.preset.temperature == 0
    }

    /// Generate the same prompt under prompt-lookup (spec) and the null-drafter baseline, in ONE container pass.
    public func promptLookupAB(
        for request: BASOrganRequest,
        drafter: BASPromptLookupDrafter,
        adaptiveK: Bool = true
    ) async throws -> PromptLookupAB {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before promptLookupAB"))
        }
        // Build the LMInput exactly as the single-model path does (identical prompt tokenization).
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let null = Self.nullDrafter

        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })

            let sSpec = DispatchTime.now().uptimeNanoseconds
            let spec = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: drafter, eosTokenIds: eos,
                adaptiveK: adaptiveK)
            let specMs = Double(DispatchTime.now().uptimeNanoseconds &- sSpec) / 1_000_000

            let sBase = DispatchTime.now().uptimeNanoseconds
            let base = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: null, eosTokenIds: eos)
            let baseMs = Double(DispatchTime.now().uptimeNanoseconds &- sBase) / 1_000_000

            return PromptLookupAB(
                specTokens: spec.tokens, specMs: specMs,
                baseTokens: base.tokens, baseMs: baseMs,
                rounds: spec.rounds, proposed: spec.proposed, accepted: spec.accepted)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Host-electable PRODUCTION decode via the universal prompt-lookup speculative decoder (Track A).
    ///
    /// **ADR-014: DEFAULT-OFF.** Existing call sites are unchanged — a host opts a turn in by calling THIS method
    /// with `electPromptLookup = true` (typically `BASDecodeLanePolicy.promptLookupEligible(for: purpose)`,
    /// computed host-side so this adapter stays free of BASOrgan-policy coupling). Nothing routes here by default,
    /// so adopting it changes no bytes until a host elects a turn.
    ///
    /// **Fail-closed + byte-safe routing:** runs the prompt-lookup decoder ONLY when `shouldUsePromptLookup`
    /// holds (elected AND greedy, temp 0); every other case falls back to `draft(_:)`, byte-identical to today.
    /// On the prompt-lookup path the emitted tokens are token-identical to greedy single-model decode
    /// (`BASPromptLookupDecoder`'s construction; device-proven 5/5), and the body is the vendor's canonical
    /// final-output detokenization `tokenizer.decode(tokenIds:)` (Evaluate.swift:1405) → byte-identical text for
    /// byte-identical tokens. `completionMetrics` is honestly `nil` (the prompt-lookup loop emits no
    /// `GenerateCompletionInfo`; the probe owns the timing A/B).
    public func respondPromptLookup(
        for request: BASOrganRequest,
        electPromptLookup: Bool,
        drafter: BASPromptLookupDrafter = BASPromptLookupDrafter()
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        #if canImport(MLXLLM)
        // Fail-closed: not elected OR not greedy → the EXACT normal path (byte-equal, ADR-014).
        guard Self.shouldUsePromptLookup(elect: electPromptLookup, request: request) else {
            return try await draft(request)
        }
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before respondPromptLookup"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)

        let rawBody: String = try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            let result = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params,
                drafter: drafter, eosTokenIds: eos, adaptiveK: true)
            return ctx.tokenizer.decode(tokenIds: result.tokens)
        }
        let body = Self.applyMarkerPostprocessing(rawBody)   // M256, same as draft(_:)

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
