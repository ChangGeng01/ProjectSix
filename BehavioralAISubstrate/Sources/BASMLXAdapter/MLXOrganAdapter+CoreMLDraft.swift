import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif
#if canImport(CoreML)
import CoreML
#endif

/// B2 hybrid entry for `MLXOrganAdapter` (Track B2). Drives `BASCoreMLDraftDecoder` (MLX target verify + Core ML
/// ANE draft) and an apples-to-apples baseline (the SAME decoder with K=0 = pure single-model greedy), so the
/// probe compares TOKEN sequences directly (true token-identity) + timing (speedup) + acceptance telemetry — the
/// only detector of a broken draft RESYNC (a broken cache stays byte-identical but collapses acceptance).
/// Observation-only (红线 7), MLX reasoning lane; does NOT touch the production decode path.
#if canImport(MLXLLM) && canImport(CoreML)
extension MLXOrganAdapter {

    /// Paired hybrid vs single-model-greedy result for one prompt.
    public struct CoreMLDraftAB: Sendable {
        public let specTokens: [Int]
        public let specMs: Double
        public let baseTokens: [Int]
        public let baseMs: Double
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
        public let aneMs: Double   // spec: time in draft propose+commit (ANE/Core ML half)
        public let gpuMs: Double   // spec: time in target verify+eval (MLX/GPU half)
    }

    /// Generate the same prompt under the hybrid (Core ML ANE draft + MLX verify) and the K=0 baseline (pure
    /// MLX greedy), in ONE container pass. The caller owns the draft session lifecycle (load once, reuse across
    /// workloads); this resets it before each run.
    @available(iOS 18.0, macOS 15.0, *)
    public func coreMLDraftAB(
        for request: BASOrganRequest,
        draft: BASCoreMLDraftSession,
        numDraftTokens: Int = 4
    ) async throws -> CoreMLDraftAB {
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before coreMLDraftAB"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)

        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })

            draft.reset()
            let sSpec = DispatchTime.now().uptimeNanoseconds
            let spec = try BASCoreMLDraftDecoder.generate(
                input: input, model: ctx.model, parameters: params,
                draft: draft, eosTokenIds: eos, numDraftTokens: numDraftTokens)
            let specMs = Double(DispatchTime.now().uptimeNanoseconds &- sSpec) / 1_000_000

            // Baseline: SAME decoder, K=0 → pure single-model greedy (draft untouched) — the token-identity +
            // timing reference.
            draft.reset()
            let sBase = DispatchTime.now().uptimeNanoseconds
            let base = try BASCoreMLDraftDecoder.generate(
                input: input, model: ctx.model, parameters: params,
                draft: draft, eosTokenIds: eos, numDraftTokens: 0)
            let baseMs = Double(DispatchTime.now().uptimeNanoseconds &- sBase) / 1_000_000

            return CoreMLDraftAB(
                specTokens: spec.tokens, specMs: specMs,
                baseTokens: base.tokens, baseMs: baseMs,
                rounds: spec.rounds, proposed: spec.proposed, accepted: spec.accepted,
                aneMs: spec.aneMs, gpuMs: spec.gpuMs)
        }
    }
}
#endif
