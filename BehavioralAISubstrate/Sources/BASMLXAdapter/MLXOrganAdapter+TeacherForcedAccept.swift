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
import MLXLLM
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

    /// Real token count of `text` under the loaded tokenizer — for honest tok/s (vs the char-based
    /// `outputTokensEstimated`). Used by the Gate-2b speedup probe so spec-vs-plain rates compare real tokens, not a
    /// chars/4 heuristic biased differently on the two lanes' (different-length) bodies.
    public func tokenCount(of text: String) async -> Int {
        guard let container = self._loadedContainerForStreaming() else { return 0 }
        return await container.perform { ctx in ctx.tokenizer.encode(text: text).count }
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

    /// CGR offline-validation primitive (GDN-safe: ONE forward, plain `newCache`, no trim). Teacher-forces the
    /// model over (chat-templated prompt for `request`) + `answer`, and returns the model's softmax PROBABILITY of
    /// each `answer` token given the true prefix — i.e. its confidence in the correct answer WITHOUT thinking.
    /// The MIN across answer tokens is the "does this turn need thinking" signal: high ⇒ the model already knows
    /// (thinking is waste), low ⇒ it needs to reason. This tests whether the model's OWN confidence is a real
    /// difficulty signal — the thing the external surprise/length signals failed to be. (Append " /no_think" to
    /// the instruction to suppress the reasoning scaffold so the answer-slot prob is the direct-answer confidence.)
    public func teacherForcedAnswerConfidence(
        for request: BASOrganRequest, answer: String
    ) async throws -> [Float] {
        guard let container = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason("loadModel(progressHandler:) before teacherForcedAnswerConfidence(...)"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await container.prepare(input: UserInput(chat: messages))
        let promptTokens = input.text.tokens.asArray(Int.self)
        let params = self._greedyParameters(for: .greedyDeterministic, maxOutputTokens: nil)

        return await container.perform { ctx in
            let answerTokens = ctx.tokenizer.encode(text: answer)
            let promptLen = promptTokens.count, n = answerTokens.count
            guard promptLen > 0, n > 0 else { return [Float]() }
            let seq = promptTokens + answerTokens
            let cache = ctx.model.newCache(parameters: params)
            let toks = MLXArray(seq.map { Int32($0) })
            let r = ctx.model(LMInput.Text(tokens: toks)[text: .newAxis], cache: cache, state: nil)
            let predLogits = r.logits[0..., (promptLen - 1) ..< (promptLen - 1 + n), 0...].squeezed(axis: 0)
            eval(predLogits)
            let flat = predLogits.asArray(Float.self)
            let vocab = predLogits.dim(1)
            var probs = [Float]()
            for i in 0..<n {
                let base = i * vocab
                var mx = -Float.greatestFiniteMagnitude
                for j in 0..<vocab where flat[base + j] > mx { mx = flat[base + j] }
                var sum: Float = 0
                for j in 0..<vocab { sum += Foundation.exp(flat[base + j] - mx) }
                let tok = answerTokens[i]
                probs.append((tok >= 0 && tok < vocab) ? Foundation.exp(flat[base + tok] - mx) / sum : 0)
            }
            return probs
        }
    }

    /// Probe-D primitive: the model's FINAL hidden state at the last prompt token (the chat-templated `request`).
    /// One backbone forward (no generation, no LM head) — the feature a difference-of-means correctness/abstention
    /// probe is fit on. Returns [] if the loaded model isn't a Qwen35Model (the only one exposing the backbone).
    public func lastTokenHiddenState(for request: BASOrganRequest) async throws -> [Float] {
        guard let container = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason("loadModel(progressHandler:) before lastTokenHiddenState(for:)"))
        }
        var messages: [Chat.Message] = []
        let instr = Self.systemInstructions(for: request)
        if !instr.isEmpty { messages.append(.system(instr)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await container.prepare(input: UserInput(chat: messages))
        let promptTokens = input.text.tokens.asArray(Int.self)   // [Int] is Sendable across the perform boundary
        return await container.perform { ctx in
            guard let m = ctx.model as? Qwen35Model, !promptTokens.isEmpty else { return [Float]() }
            let toks = MLXArray(promptTokens.map { Int32($0) }).reshaped([1, -1])  // [1, seq]
            let hidden = m.finalHiddenStates(toks)             // [1, seq, hidden]
            let last = hidden[0, -1, 0...]                     // [hidden] — last prompt token
            eval(last)
            return last.asArray(Float.self)
        }
    }
}
#endif
