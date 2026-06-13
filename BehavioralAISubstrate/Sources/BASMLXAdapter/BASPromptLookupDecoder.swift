#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLMCommon

/// BAS-owned greedy speculative decode loop with a PROMPT-LOOKUP (n-gram) drafter — universal (any LLM, no
/// draft model), byte-identical to single-model greedy. Mirrors the vendored `SpeculativeTokenIterator`'s
/// `.argmaxEquality` accept/trim branch (`Evaluate.swift:913-998`) but the draft is a FREE n-gram lookup over
/// the running token sequence — so there is NO draft model and NO draft KV cache (only the main cache is
/// trimmed). Every EMITTED token is the main model's own argmax → output is token-identical to greedy
/// target-only decode (the ADR-039-safe property the probe verifies N/N).
public struct BASPromptLookupDecoder {

    /// Result of a full greedy generation: the tokens + the speculation telemetry (hit-rate = accepted/proposed,
    /// mean accepted length = accepted/rounds).
    public struct Result: Sendable {
        public let tokens: [Int]
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
    }

    enum DecodeError: Error { case nonTrimmableCache }

    /// Run greedy generation to `maxTokens`/EOS with prompt-lookup speculation. `eosTokenIds` stops generation.
    public static func generate(
        input: LMInput,
        model: any LanguageModel,
        parameters: GenerateParameters,
        drafter: BASPromptLookupDrafter,
        eosTokenIds: Set<Int>
    ) throws -> Result {
        var cache = model.newCache(parameters: parameters)
        guard canTrimPromptCache(cache) else { throw DecodeError.nonTrimmableCache }
        let sampler = parameters.sampler()
        let maxTokens = parameters.maxTokens
        let K = drafter.numDraftTokens

        var rolling = input.text.tokens.asArray(Int.self)
        var out = [Int]()
        var rounds = 0, proposed = 0, accepted = 0

        // ---- Prefill: prime the cache + take the first token (argmax of the final-position logits). ----
        var y: LMInput.Text
        var state: LMOutput.State?
        switch try model.prepare(input, cache: cache, windowSize: parameters.prefillStepSize) {
        case .tokens(let toks):
            y = toks
        case .logits(let result):
            let logits = result.logits[0..., -1, 0...]
            let token = sampler.sample(logits: logits)
            eval(token)
            y = .init(tokens: token)
            state = result.state
            let t = token.item(Int.self)
            rolling.append(t)
            out.append(t)
            if eosTokenIds.contains(t) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0) }
        }

        // ---- Speculative rounds. ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? K
            guard remaining > 0 else { break }
            // Free n-gram draft over the running sequence; keep room for the bonus token (remaining - 1).
            let rawDraft = drafter.propose(over: rolling)
            let numDraft = Swift.min(rawDraft.count, Swift.max(0, remaining - 1))
            let draft = Array(rawDraft.prefix(numDraft))
            rounds += 1
            proposed += numDraft

            // Verify [y] + draft in ONE forward.
            let verifyTokens: MLXArray
            if numDraft > 0 {
                verifyTokens = concatenated([y.tokens, MLXArray(draft.map { Int32($0) })])
            } else {
                verifyTokens = y.tokens
            }
            let verifyInput = LMInput.Text(tokens: verifyTokens)
            let verifyStart = verifyInput.tokens.dim(0) - (numDraft + 1)
            let result = model(verifyInput[text: .newAxis], cache: cache, state: state)
            state = result.state
            // Greedy argmax over every verify position in one op (no logit processors in the greedy probe lane).
            let verifyLogits = result.logits[0..., verifyStart..., 0...].squeezed(axis: 0)
            let mainTokens = sampler.sample(logits: verifyLogits)
            eval(mainTokens)
            let mainList = mainTokens.asArray(Int.self)

            // Accept the longest matching prefix; always emit the main model's token at `accepted`.
            var acc = 0
            while acc < numDraft && mainList[acc] == draft[acc] { acc += 1 }
            accepted += acc

            var stop = false
            for i in 0...acc {          // acc accepted draft tokens + the correction/bonus token
                let t = mainList[i]
                out.append(t)
                rolling.append(t)
                if eosTokenIds.contains(t) { stop = true; break }
                if let m = maxTokens, out.count >= m { stop = true; break }
            }
            // Rewind the main cache for the rejected drafts (only the main cache exists).
            _ = trimPromptCache(cache, numTokens: numDraft - acc)
            // Next round seeds from the last emitted token.
            y = .init(tokens: MLXArray([Int32(out.last ?? 0)]))
            if stop { break }
        }
        return Result(tokens: out, rounds: rounds, proposed: proposed, accepted: accepted)
    }
}
#endif
