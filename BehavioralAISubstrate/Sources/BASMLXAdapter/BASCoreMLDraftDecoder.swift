#if canImport(MLXLLM) && canImport(CoreML)
import Foundation
import MLX
import MLXLMCommon

/// B2 hybrid — greedy speculative decode with a **Core ML ANE draft** verified by the **MLX target**.
///
/// Structurally identical to `BASPromptLookupDecoder` on the TARGET side (prefill → verify [seed]+draft in ONE
/// forward → accept-longest-argmax-prefix → emit the target's argmax → `trimPromptCache(numDraft - acc)`), so the
/// emitted stream is TOKEN-identical to single-model greedy decode (the ADR-039 property) REGARDLESS of the draft
/// — a wrong/quantization-diverged draft only lowers acceptance (speedup), never changes a byte. The ONLY new
/// part is the draft KV RESYNC: the `BASCoreMLDraftSession` proposes K tokens (K+1 ANE forwards so every proposal
/// has its K/V written) and, after the target's verdict, commits the correction (1 ANE forward). Net per round:
/// K+2 cheap ANE draft forwards + 1 expensive MLX target forward, committing `acc+1` tokens.
///
/// Honest gate (the silent-corruption trap): a broken RESYNC stays byte-identical but collapses acceptance to ~0.
/// `Result.accepted / Result.rounds` is the ONLY detector — certify on a draft≈target config where acceptance
/// must approach the proposal length, NOT on byte-identity alone.
@available(iOS 18.0, macOS 15.0, *)
public struct BASCoreMLDraftDecoder {

    public struct Result: Sendable {
        public let tokens: [Int]
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
        public let aneMs: Double      // total wall time in draft propose+commit (the ANE/Core ML half)
        public let gpuMs: Double      // total wall time in target verify+eval (the MLX/GPU half)
    }

    enum DecodeError: Error { case nonTrimmableCache }

    public static func generate(
        input: LMInput,
        model: any LanguageModel,
        parameters: GenerateParameters,
        draft: BASCoreMLDraftSession,
        eosTokenIds: Set<Int>,
        numDraftTokens K: Int = 4
    ) throws -> Result {
        var cache = model.newCache(parameters: parameters)
        guard canTrimPromptCache(cache) else { throw DecodeError.nonTrimmableCache }
        let sampler = parameters.sampler()
        let maxTokens = parameters.maxTokens

        let promptTokens = input.text.tokens.asArray(Int.self)
        var out = [Int]()
        var rounds = 0, proposed = 0, accepted = 0
        var aneNanos: UInt64 = 0, gpuNanos: UInt64 = 0

        // ---- Prefill the TARGET and take the FIRST generated token in BOTH prepare cases. `.logits` already
        // computed it; `.tokens` deferred the prompt tail — feed it in one forward to get the first token (the
        // draft needs `out=[t0]` to sync its KV, so we cannot defer the first token into the loop). ----
        var y: LMInput.Text
        var state: LMOutput.State?
        switch try model.prepare(input, cache: cache, windowSize: parameters.prefillStepSize) {
        case .tokens(let toks):
            let r = model(LMInput.Text(tokens: toks.tokens)[text: .newAxis], cache: cache, state: state)
            state = r.state
            let token = sampler.sample(logits: r.logits[0..., -1, 0...])
            eval(token)
            let t = token.item(Int.self)
            if eosTokenIds.contains(t) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0, aneMs: 0, gpuMs: 0) }
            out.append(t)
            y = .init(tokens: token)
        case .logits(let result):
            state = result.state
            let token = sampler.sample(logits: result.logits[0..., -1, 0...])
            eval(token)
            let t = token.item(Int.self)
            if eosTokenIds.contains(t) { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0, aneMs: 0, gpuMs: 0) }
            out.append(t)
            y = .init(tokens: token)
        }
        guard let first = out.first else { return Result(tokens: out, rounds: 0, proposed: 0, accepted: 0, aneMs: 0, gpuMs: 0) }

        // ---- Prefill the DRAFT KV to the same committed prefix: prompt tokens + the first emitted token. ----
        // If the prompt + the first token already fills the draft window, run pure target-greedy (no draft).
        let canDraft = (promptTokens.count + 1) < draft.maxSeqCount
        if canDraft { try draft.prefill(promptTokens + [first]) }

        // ---- Speculative rounds. ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? K
            guard remaining > 0 else { break }

            // Draft window guard: keep room for the K proposals + the commit forward; near MAX_SEQ → stop drafting.
            let windowRoom = canDraft ? (draft.remainingWindow() - 2) : 0
            let numDraft = Swift.max(0, Swift.min(K, Swift.min(remaining - 1, windowRoom)))
            let seed = out.last ?? first
            let tProp = DispatchTime.now().uptimeNanoseconds
            let draftTokens = numDraft > 0 ? try draft.propose(seed: seed, k: numDraft) : []
            aneNanos &+= DispatchTime.now().uptimeNanoseconds &- tProp
            rounds += 1
            proposed += draftTokens.count

            // Verify [y] + draft in ONE TARGET forward (VERBATIM from BASPromptLookupDecoder).
            let tVer = DispatchTime.now().uptimeNanoseconds
            let verifyTokens: MLXArray = draftTokens.isEmpty
                ? y.tokens
                : concatenated([y.tokens, MLXArray(draftTokens.map { Int32($0) })])
            let verifyInput = LMInput.Text(tokens: verifyTokens)
            let verifyStart = verifyInput.tokens.dim(0) - (draftTokens.count + 1)
            let result = model(verifyInput[text: .newAxis], cache: cache, state: state)
            state = result.state
            let verifyLogits = result.logits[0..., verifyStart..., 0...].squeezed(axis: 0)
            let mainTokens = sampler.sample(logits: verifyLogits)
            eval(mainTokens)
            let mainList = mainTokens.asArray(Int.self)
            gpuNanos &+= DispatchTime.now().uptimeNanoseconds &- tVer

            // Accept the longest matching prefix; always emit the target's argmax (byte-identity by construction).
            var acc = 0
            while acc < draftTokens.count && mainList[acc] == draftTokens[acc] { acc += 1 }
            accepted += acc

            var stop = false
            for i in 0...acc {          // acc accepted + the correction/bonus token
                let t = mainList[i]
                if eosTokenIds.contains(t) { stop = true; break }   // stop-before-EOS (terminator not emitted)
                out.append(t)
                if let m = maxTokens, out.count >= m { stop = true; break }
            }
            // Rewind the TARGET cache for the rejected drafts (verbatim).
            _ = trimPromptCache(cache, numTokens: draftTokens.count - acc)
            // RESYNC the DRAFT KV: commit acc accepted + the correction (one ANE forward) — unless we stopped.
            if stop { break }
            if canDraft && numDraft > 0 {
                let tCom = DispatchTime.now().uptimeNanoseconds
                try draft.commit(acc: acc, correction: mainList[acc])
                aneNanos &+= DispatchTime.now().uptimeNanoseconds &- tCom
            }
            // Next round seeds from the last emitted token.
            y = .init(tokens: MLXArray([Int32(out.last ?? 0)]))
        }
        return Result(tokens: out, rounds: rounds, proposed: proposed, accepted: accepted,
                      aneMs: Double(aneNanos) / 1_000_000, gpuMs: Double(gpuNanos) / 1_000_000)
    }
}
#endif
