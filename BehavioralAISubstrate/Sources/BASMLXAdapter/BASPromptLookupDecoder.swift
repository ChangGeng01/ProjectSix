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
    ///
    /// `adaptiveK` (default false → fixed K): shrink the proposed draft length toward 1 when recent acceptance
    /// is low, ramp back to the full K as it rises; a floor of 1 keeps cheaply probing so re-entering repetition
    /// is still detected. MEASURED (iPhone Air, UNIVERSAL_SSD_PROBE_RESULTS.md): this LIFTS the partial-repetition
    /// lanes (verify-claim 0.99×→1.23×, repetitive mean 1.39×→1.58×) but DOES NOT remove the free-form penalty
    /// (control stayed 0.91×→0.92×) — that cost is the per-round n-gram scan, not the K-width, so only lane-gating
    /// removes it (the hypothesis that adaptive-K erases the penalty was FALSIFIED). Byte-identity is unaffected.
    public static func generate(
        input: LMInput,
        model: any LanguageModel,
        parameters: GenerateParameters,
        drafter: BASPromptLookupDrafter,
        eosTokenIds: Set<Int>,
        adaptiveK: Bool = false
    ) throws -> Result {
        var cache = model.newCache(parameters: parameters)
        guard canTrimPromptCache(cache) else { throw DecodeError.nonTrimmableCache }
        let sampler = parameters.sampler()
        let maxTokens = parameters.maxTokens
        let K = drafter.numDraftTokens

        var rolling = input.text.tokens.asArray(Int.self)
        var out = [Int]()
        var rounds = 0, proposed = 0, accepted = 0
        // Adaptive-K state: EMA of accepted-per-round (start optimistic = full K so it speculates initially).
        var emaAccept = Double(K)

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
            // Stop-before-EOS: exclude the terminator from `out` so the emitted stream matches the vendor's
            // generatedTokenIds (which omits the stop token). Otherwise the EOS marker (e.g. <|eot_id|>)
            // detokenizes into the body, breaking text parity with the production path. (audit fix)
            if eosTokenIds.contains(t) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0) }
            rolling.append(t)
            out.append(t)
        }

        // ---- Speculative rounds. ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? K
            guard remaining > 0 else { break }
            // Adaptive K: floor 1, ramp toward K with the running acceptance EMA (fixed K when disabled).
            let effK = adaptiveK ? Swift.max(1, Swift.min(K, Int(emaAccept.rounded()) + 1)) : K
            // Free n-gram draft over the running sequence; keep room for the bonus token (remaining - 1).
            let rawDraft = drafter.propose(over: rolling)
            let numDraft = Swift.min(rawDraft.count, Swift.min(effK, Swift.max(0, remaining - 1)))
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
            emaAccept = 0.6 * emaAccept + 0.4 * Double(acc)   // adaptive-K signal (used only when adaptiveK)

            var stop = false
            for i in 0...acc {          // acc accepted draft tokens + the correction/bonus token
                let t = mainList[i]
                if eosTokenIds.contains(t) { stop = true; break }   // stop-before-EOS: terminator not emitted (audit fix)
                out.append(t)
                rolling.append(t)
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
