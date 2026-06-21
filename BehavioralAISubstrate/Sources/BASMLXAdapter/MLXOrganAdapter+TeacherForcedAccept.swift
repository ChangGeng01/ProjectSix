// MARK: - MLXOrganAdapter+TeacherForcedAccept — Gate-2 draft-α measurement (no rewind shim, no ANE)
//
// Measures speculative-decode acceptance α of a same-vocab draft against this adapter's target WITHOUT running real
// spec decode: for greedy argmax-equality accept, the accepted prefix is always the target's own greedy sequence T,
// so per-position TEACHER-FORCED agreement (draft argmax == T[i] | true prefix) equals the real-rollout accept event.
// So α = ONE draft prefill+readout forward over `prompt + T`, fed to `BASAcceptanceBlockReducer` (BASOrgan, host-tested).
//
// Two public entry points (the probe loads a target adapter + a draft adapter and pairs them):
//   • TARGET adapter: `greedyReferenceTokens(for:)` → the true greedy token sequence T (+ its prompt tokens).
//   • DRAFT adapter:  `teacherForcedAgreement(promptTokens:referenceTokens:)` → per-position agreement with T.
// Same-vocab only (Gate 2): T's token ids must be valid in the draft's vocab — true for a same-family draft (Llama-1B
// vs Llama-3B). Cross-vocab would need an id map (deferred; only resurfaces if a same-vocab draft first wins free-form).

#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLMCommon
import BASOrgan

extension MLXOrganAdapter {

    /// TARGET-side: greedy-decode `request` and return the produced token sequence T (the byte-identity reference) plus
    /// the chat-templated prompt tokens. Reuses the exact production greedy path (`_generateModelFree` with the null
    /// drafter = pure single-token greedy), so T is the genuine target argmax sequence.
    public func greedyReferenceTokens(
        for request: BASOrganRequest
    ) async throws -> (promptTokens: [Int], tokens: [Int]) {
        let g = try await _generateModelFree(
            for: request, drafter: Self.nullDrafter,
            notLoadedHint: "loadModel(progressHandler:) before greedyReferenceTokens(for:)")
        return (g.promptTokens, g.genTokens)
    }

    /// DRAFT-side: teacher-force THIS adapter's model over `promptTokens + referenceTokens` in ONE forward and return,
    /// for each reference token, whether the draft's greedy argmax (conditioned on the true prefix) matches it.
    /// `agreement[i] == true` ⇔ a real spec round would accept `referenceTokens[i]`. Feed the result to
    /// `BASAcceptanceBlockReducer.reduce(agreement:k:)` for the block-K acceptance statistics.
    public func teacherForcedAgreement(
        promptTokens: [Int], referenceTokens: [Int]
    ) async throws -> [Bool] {
        guard let container = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason("loadModel(progressHandler:) before teacherForcedAgreement(...)"))
        }
        let promptLen = promptTokens.count
        let n = referenceTokens.count
        guard promptLen > 0, n > 0 else { return [] }
        let seq = promptTokens + referenceTokens
        // Greedy sampler (temp 0 ⇒ ArgMax) — the byte-identity-relevant decision rule.
        let params = self._greedyParameters(for: .greedyDeterministic, maxOutputTokens: nil)

        return await container.perform { ctx in
            let cache = ctx.model.newCache(parameters: params)
            let sampler = params.sampler()
            // ONE forward over the full sequence → per-position logits [1, seq, vocab].
            let tokens = MLXArray(seq.map { Int32($0) })
            let r = ctx.model(LMInput.Text(tokens: tokens)[text: .newAxis], cache: cache, state: nil)
            // logits at positions [promptLen-1 .. promptLen-1+n) predict referenceTokens[0..<n] (the j-th logits row
            // is the distribution over position j+1 given seq[0...j]).
            let predLogits = r.logits[0..., (promptLen - 1) ..< (promptLen - 1 + n), 0...].squeezed(axis: 0)
            let predicted = sampler.sample(logits: predLogits)
            eval(predicted)
            let preds = predicted.asArray(Int.self)
            return zip(preds, referenceTokens).map { $0 == $1 }
        }
    }
}
#endif
