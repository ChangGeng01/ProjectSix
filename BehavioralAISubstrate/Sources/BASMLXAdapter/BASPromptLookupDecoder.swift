#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLLM
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
        // trim-rewindable. A carry-forward lane (BASTrunkCheckpoint snapshot-restore + carry-forward
        // reject) routes them. Its first device cert was byte-identical only 1/5
        // (prompt-lookup-20260713-162414.log) — an ADR-039 violation that gated it OFF.
        //
        // ROOT-CAUSED + FIXED (commit 0187edada, cert-logs/gdn-fp32-state-ON-5of5-20260713.log):
        // the divergence was the GDN RECURRENT STATE being cast back to bf16 (7-mantissa) between
        // tokens, so a chunked multi-token verify rounded differently than sequential decode.
        // Keeping the state in float32 (GatedDelta.swift:296-300, BAS_GDN_FP32_STATE=1 — the
        // kernel supports it natively) makes chunked == sequential EXACTLY → byte-identical 5/5 on
        // device. So the lane is CORRECT under fp32 state; it stays opt-in only because its
        // end-to-end win is ~1.03x (low n-gram acceptance on Qwen3.5), not because it is broken.
        //
        // FOOTGUN CLOSED: the two flags are separate (fp32 state is read deep in GatedDelta, carry-
        // forward here). Setting ONLY BAS_GDN_CARRYFORWARD=1 would route the carry-forward lane over
        // the still-bf16 state = the broken 1/5 control. So carry-forward now REQUIRES fp32 state
        // too: BAS_GDN_CARRYFORWARD=1 without BAS_GDN_FP32_STATE=1 fails closed to plain (an
        // investigator gets the correct 5/5 path or nothing, never the misleading broken one).
        guard canTrimPromptCache(cache) else {
            let gdnCarryForwardEnabled =
                ProcessInfo.processInfo.environment["BAS_GDN_CARRYFORWARD"] == "1"
            let gdnFP32StateEnabled =
                ProcessInfo.processInfo.environment["BAS_GDN_FP32_STATE"] == "1"
            // The carry-forward lane routes ONLY Qwen35's GDN composition, and it must drive the
            // trunk through the SAME concrete forward the byte-identical MTP lane uses
            // (`hiddenStatesWithCache` → the inner Qwen35TextModelInner), NOT the protocol
            // `callAsFunction(_:cache:state:)` whose LMOutput.State handling is what made the
            // generic loop diverge from sequential plain on device. Any non-Qwen35 or state-
            // carrying model fails closed.
            // P2-sweep footgun close: carry-forward is byte-correct ONLY with fp32 recurrent
            // state (see the block above). Require BOTH flags — carry-forward without fp32 is the
            // broken bf16 control, so fail closed to plain rather than route it.
            guard gdnCarryForwardEnabled, gdnFP32StateEnabled,
                  BASTrunkCheckpoint.compositionSupported(cache),
                  let qwen = model as? Qwen35Model else {
                throw DecodeError.nonTrimmableCache
            }
            return try generateCarryForward(
                input: input, model: qwen, parameters: parameters, drafter: drafter,
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
        model: Qwen35Model,
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

        // ---- Prefill: whole prompt in ONE `hiddenStatesWithCache` call — byte-for-byte the same
        // primer the certified generatePlain/MTP lanes use (NOT model.prepare's chunked windows).
        // `pendingFeed` = the emitted-but-not-yet-fed token that seeds the next verify forward. ----
        let promptIDs = input.text.tokens
        let h0 = model.hiddenStatesWithCache(
            promptIDs.expandedDimensions(axis: 0), cache: cache)
        let firstToken = sampler.sample(logits: model.logits(fromHidden: h0)[0, h0.dim(1) - 1])
        eval(firstToken)
        let firstT = firstToken.item(Int.self)
        if eosTokenIds.contains(firstT) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0) }
        rolling.append(firstT)
        out.append(firstT)
        var pendingFeed: [Int] = [firstT]

        // ---- Speculative rounds (carry-forward). ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? K
            guard remaining > 0 else { break }
            let effK = adaptiveK ? Swift.max(1, Swift.min(K, Int(emaAccept.rounded()) + 1)) : K
            let rawDraft = drafter.propose(over: rolling)
            let numDraft = Swift.min(rawDraft.count, Swift.min(effK, Swift.max(0, remaining - 1)))
            let draft = Array(rawDraft.prefix(numDraft))
            rounds += 1
            proposed += numDraft

            // Snapshot ONLY when there is something to reject (numDraft > 0).
            let checkpoint: BASTrunkCheckpoint? = numDraft > 0 ? BASTrunkCheckpoint(cache: cache) : nil
            let feed = pendingFeed + draft
            let verifyStart = feed.count - (numDraft + 1)
            // THE fix: the concrete inner-model forward (hiddenStatesWithCache), NOT the protocol
            // callAsFunction — the state-free forward the byte-identical MTP lane is built on.
            let h = model.hiddenStatesWithCache(
                MLXArray(feed.map { Int32($0) }).expandedDimensions(axis: 0), cache: cache)
            let verifyLogits = model.logits(fromHidden: h)[0, verifyStart...]
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
