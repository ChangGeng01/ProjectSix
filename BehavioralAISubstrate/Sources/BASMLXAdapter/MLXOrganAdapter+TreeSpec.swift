import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// ⚠️ QUARANTINED (Tier-C consolidation, 2026-06-21): measure-only A/B harness (`BAS_PL_TREE` probe). The tree
/// lane it exercises is ~0.76× on device and is never selected by the production router; this exists purely to
/// produce the parity (`treeTokens == linearTokens`) + marginal-speedup datum. Production decode never calls it.
///
/// Tree-structured prompt-lookup entry for `MLXOrganAdapter` (B2-aggressive). Runs `BASTreeSpecDecoder` (tree) and
/// the SHIPPED linear `BASPromptLookupDecoder` in ONE container pass and compares TOKEN sequences — tree MUST be
/// token-identical to linear (which is proven token-identical to greedy), so `treeTokens == linearTokens` is the
/// byte-identity parity gate; `linearMs / treeMs` is the marginal speedup of the tree over the linear lane.
/// Observation-only, greedy lane; does NOT touch production decode.
extension MLXOrganAdapter {

    public struct TreeSpecAB: Sendable {
        public let treeTokens: [Int]
        public let treeMs: Double
        public let linearTokens: [Int]
        public let linearMs: Double
        public let rounds: Int
        public let proposedNodes: Int
        public let acceptedTokens: Int
        public let maxPathLen: Int
    }

    public func treeSpecAB(
        for request: BASOrganRequest,
        drafter: any BASUniversalDraftSource,
        maxBranch: Int = 2,
        maxNodes: Int = 8
    ) async throws -> TreeSpecAB {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before treeSpecAB"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)

        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })

            let sTree = DispatchTime.now().uptimeNanoseconds
            let tree = try BASTreeSpecDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: drafter,
                eosTokenIds: eos, maxBranch: maxBranch, maxNodes: maxNodes)
            let treeMs = Double(DispatchTime.now().uptimeNanoseconds &- sTree) / 1_000_000

            let sLin = DispatchTime.now().uptimeNanoseconds
            let lin = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: drafter, eosTokenIds: eos)
            let linMs = Double(DispatchTime.now().uptimeNanoseconds &- sLin) / 1_000_000

            return TreeSpecAB(
                treeTokens: tree.tokens, treeMs: treeMs,
                linearTokens: lin.tokens, linearMs: linMs,
                rounds: tree.rounds, proposedNodes: tree.proposedNodes,
                acceptedTokens: tree.acceptedTokens, maxPathLen: tree.maxPathLen)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}
