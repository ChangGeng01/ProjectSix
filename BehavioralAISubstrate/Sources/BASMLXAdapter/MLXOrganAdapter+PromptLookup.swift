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
}
