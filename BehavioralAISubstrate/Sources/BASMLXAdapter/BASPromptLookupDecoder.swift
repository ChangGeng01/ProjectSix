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
        drafter: any BASUniversalDraftSource,
        eosTokenIds: Set<Int>,
        adaptiveK: Bool = false
    ) throws -> Result {
        // Local mutable binding so a STATEFUL source (e.g. the cross-turn `BASCrossTurnDrafter`) can advance its
        // index across rounds via the `mutating` `propose`; the stateless `BASPromptLookupDrafter` is unaffected.
        var drafter = drafter
        // ADR-039: the per-round rewind (`trimPromptCache`) must be lossless. A stock RotatingKVCache (sliding-window
        // models, e.g. Gemma) CANNOT be rewound — `trim` is scalar bookkeeping over a rotated/rebuilt ring, so it
        // desyncs the committed prefix (device-measured byte_identical=1/8 on Gemma-4-E4B). So instead of the stock
        // cache we drive the verify lane with `BASWindowMaskedCache.verifyCache(...)`, which swaps each sliding
        // RotatingKVCache for an APPEND-ONLY window-masked cache (window enforced by the mask, not eviction): one
        // update path ⇒ verify-K == K-singles bit-identical, and `trim` is a clean `offset -= n`. Full-attention
        // caches are left untouched, so Llama/Qwen stay byte-unchanged. The guard below now PASSES for swapped Gemma
        // (no RotatingKVCache remains) and still fail-closes on any non-trimmable cache we couldn't swap.
        let cache = BASWindowMaskedCache.verifyCache(for: model, parameters: parameters)
        guard cache.allSatisfy({ !($0 is RotatingKVCache) }) else {
            throw DecodeError.nonTrimmableCache
        }
        // P1-b (2026-07-13): GDN/hybrid targets (Qwen3.5 — ArraysCache linear layers) are NOT
        // trim-rewindable, which until now fail-closed the whole model-free family off the
        // production quality default. But the MTP lane already proved the alternative rollback
        // on these exact models: BASTrunkCheckpoint snapshot-restore (retaining the GDN slot
        // references is FREE) + carry-forward reject (uncommitted tokens ride into the next
        // verify forward — the T-cost curve is flat, so no separate re-feed pass). Route those
        // compositions to the carry-forward loop; the certified trimmable loop below is
        // byte-for-byte untouched for Llama/Gemma-class caches.
        guard canTrimPromptCache(cache) else {
            guard BASTrunkCheckpoint.compositionSupported(cache) else {
                throw DecodeError.nonTrimmableCache
            }
            return try generateCarryForward(
                input: input, model: model, parameters: parameters, drafter: drafter,
                eosTokenIds: eosTokenIds, adaptiveK: adaptiveK, cache: cache)
        }
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

    /// P1-b (2026-07-13) — the GDN/hybrid (ArraysCache) lane: prompt-lookup speculation for targets whose
    /// recurrent state cannot be trim-rewound (Qwen3.5's Gated-DeltaNet layers). Numerics:
    /// - Rollback = `BASTrunkCheckpoint` (the 案1 mechanism the MTP/fused lanes device-certified on this
    ///   exact model): capture retains the GDN slot references pre-round (FREE), restore reassigns them and
    ///   trims the attention layers by the full fed width.
    /// - Reject economics = CARRY-FORWARD (the MTP K=1 lesson): tokens that are emitted-but-uncommitted
    ///   after a restore ride a pending queue into the NEXT verify forward instead of paying a re-feed
    ///   pass — the verify T-cost curve is flat (T=1 14.9ms vs T=4 16.6ms), so a reject costs ~nothing.
    /// - Byte-identity: causal forward ⇒ logits at position i depend only on fed prefix ≤ i, so every
    ///   emission is the trunk's own argmax exactly as in the trimmable loop; the rejected suffix can
    ///   never contaminate an emitted position.
    /// Fail-closed: a model whose `prepare`/forward carries `LMOutput.State` is REFUSED (unknown state
    /// lives outside the cache and would not be restored); a cold-ArraysCache round never snapshots
    /// (it runs draft-free, which commits the pending feed and warms the slots).
    private static func generateCarryForward(
        input: LMInput,
        model: any LanguageModel,
        parameters: GenerateParameters,
        drafter: any BASUniversalDraftSource,
        eosTokenIds: Set<Int>,
        adaptiveK: Bool,
        cache: [KVCache]
    ) throws -> Result {
        var drafter = drafter
        let sampler = parameters.sampler()
        let maxTokens = parameters.maxTokens
        let K = drafter.numDraftTokens

        var rolling = input.text.tokens.asArray(Int.self)
        var out = [Int]()
        var rounds = 0, proposed = 0, accepted = 0
        var emaAccept = Double(K)

        // ---- Prefill. `pendingFeed` = tokens NOT yet committed to the cache (fed next forward). ----
        var pendingFeed: [Int]
        switch try model.prepare(input, cache: cache, windowSize: parameters.prefillStepSize) {
        case .tokens(let toks):
            // Prompt tail left unfed — it becomes the first round's feed (never emitted).
            pendingFeed = toks.tokens.asArray(Int.self)
        case .logits(let result):
            guard result.state == nil else { throw DecodeError.nonTrimmableCache }
            let logits = result.logits[0..., -1, 0...]
            let token = sampler.sample(logits: logits)
            eval(token)
            let t = token.item(Int.self)
            if eosTokenIds.contains(t) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0) }
            rolling.append(t)
            out.append(t)
            pendingFeed = [t]
        }

        // ---- Speculative rounds (carry-forward). ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? K
            guard remaining > 0 else { break }
            let effK = adaptiveK ? Swift.max(1, Swift.min(K, Int(emaAccept.rounded()) + 1)) : K
            // A COLD ArraysCache (possible only on the first round of the `.tokens` prefill path)
            // cannot be snapshotted — run that round draft-free: it commits pendingFeed + warms the slots.
            let cold = cache.contains { ($0 as? ArraysCache).map { $0.state.isEmpty } ?? false }
            let rawDraft = cold ? [] : drafter.propose(over: rolling)
            let numDraft = Swift.min(rawDraft.count, Swift.min(effK, Swift.max(0, remaining - 1)))
            let draft = Array(rawDraft.prefix(numDraft))
            rounds += 1
            proposed += numDraft

            // Snapshot ONLY when there is something to reject (numDraft > 0 ⇒ cache is warm here).
            let checkpoint: BASTrunkCheckpoint? = numDraft > 0 ? BASTrunkCheckpoint(cache: cache) : nil
            let feed = pendingFeed + draft
            let verifyInput = LMInput.Text(tokens: MLXArray(feed.map { Int32($0) }))
            let verifyStart = feed.count - (numDraft + 1)
            let result = model(verifyInput[text: .newAxis], cache: cache, state: nil)
            guard result.state == nil else { throw DecodeError.nonTrimmableCache }
            let verifyLogits = result.logits[0..., verifyStart..., 0...].squeezed(axis: 0)
            let mainTokens = sampler.sample(logits: verifyLogits)
            eval(mainTokens)
            let mainList = mainTokens.asArray(Int.self)

            var acc = 0
            while acc < numDraft && mainList[acc] == draft[acc] { acc += 1 }
            accepted += acc
            emaAccept = 0.6 * emaAccept + 0.4 * Double(acc)

            var emittedThisRound: [Int] = []
            var stop = false
            for i in 0...acc {
                let t = mainList[i]
                if eosTokenIds.contains(t) { stop = true; break }
                out.append(t)
                rolling.append(t)
                emittedThisRound.append(t)
                if let m = maxTokens, out.count >= m { stop = true; break }
            }

            if acc == numDraft {
                // Full accept: the cache committed pendingFeed + every draft token; the only
                // uncommitted token is the correction/bonus (if emitted) — it seeds the next feed.
                pendingFeed = emittedThisRound.suffix(1).map { $0 }
            } else if let checkpoint {
                // Partial reject: the rejected suffix poisoned the recurrent state → restore the
                // GDN slots to pre-round and trim the attention layers by the FULL fed width.
                guard checkpoint.restore(cache: cache, trimming: feed.count) else {
                    // Fail-close (trim under-returned): everything emitted is a trunk argmax, so
                    // stopping early is safe; continuing on inconsistent state is not.
                    return Result(tokens: out, rounds: rounds, proposed: proposed, accepted: accepted)
                }
                // Everything fed this round is uncommitted again; the accepted prefix + correction
                // (== emittedThisRound) carries forward on top of the old pending feed.
                pendingFeed += emittedThisRound
            }
            if stop { break }
        }
        return Result(tokens: out, rounds: rounds, proposed: proposed, accepted: accepted)
    }
}
#endif
