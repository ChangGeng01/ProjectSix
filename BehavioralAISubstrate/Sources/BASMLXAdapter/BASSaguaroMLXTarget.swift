// MARK: - BASSaguaroMLXTarget
//
// The TARGET/verifier half of the Saguaro loop: wraps an MLX language model (Llama-3.2-3B) and implements the
// framework-free `BASSaguaroTarget` protocol (BASOrgan) in token-level `Int` terms. The prefill + verify blocks
// are lifted VERBATIM from the already-on-device-certified `BASCoreMLDraftDecoder` (prefill :51-74, verify
// :99-112) and `BASPromptLookupDecoder` (identical) — the only change is returning plain `[Int]` so the loop
// stays pure. Byte-identity is the target's argmax by construction (ADR-039).
//
// `#if canImport(MLXLLM)`. Single serialized executor (the MLX cache/state are mutated in place per call).

#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLMCommon
import BASOrgan   // BASSaguaroTarget

public final class BASSaguaroMLXTarget: BASSaguaroTarget {

    public enum TargetError: Error { case nonTrimmableCache }

    private let model: any LanguageModel
    private let input: LMInput
    private let sampler: any LogitSampler
    private let prefillStepSize: Int
    private let eosTokenIds: Set<Int>
    private var cache: [KVCache]
    private var state: LMOutput.State?

    /// Construct over the prompt `input` (already tokenized / chat-templated by the caller). Greedy sampler from
    /// `parameters` (temperature 0 ⇒ ArgMax) keeps the byte-identity property.
    public init(
        model: any LanguageModel,
        input: LMInput,
        parameters: GenerateParameters,
        eosTokenIds: Set<Int>
    ) throws {
        self.model = model
        self.input = input
        self.sampler = parameters.sampler()
        self.prefillStepSize = parameters.prefillStepSize
        self.eosTokenIds = eosTokenIds
        let c = model.newCache(parameters: parameters)
        // ADR-039: the spec-decode rewind requires an UNCONDITIONALLY trimmable cache. canTrimPromptCache only
        // checks offset==0 at construction; a RotatingKVCache (maxKVSize != nil) flips isTrimmable→false once it
        // fills past maxCacheSize, after which trimRejected silently no-ops and desyncs the target cache from the
        // committed prefix — breaking byte-identity mid-run. Reject it up front (fail-closed) rather than corrupt.
        guard c.allSatisfy({ !($0 is RotatingKVCache) }), canTrimPromptCache(c) else {
            throw TargetError.nonTrimmableCache
        }
        self.cache = c
    }

    /// Prime the cache over the prompt, return the first committed token (both prepare cases). Verbatim
    /// BASCoreMLDraftDecoder.swift:56-74.
    public func prefill() throws -> (firstToken: Int, isEOS: Bool) {
        switch try model.prepare(input, cache: cache, windowSize: prefillStepSize) {
        case .tokens(let toks):
            let r = model(LMInput.Text(tokens: toks.tokens)[text: .newAxis], cache: cache, state: state)
            state = r.state
            let token = sampler.sample(logits: r.logits[0..., -1, 0...])
            eval(token)
            let t = token.item(Int.self)
            return (t, eosTokenIds.contains(t))
        case .logits(let result):
            state = result.state
            let token = sampler.sample(logits: result.logits[0..., -1, 0...])
            eval(token)
            let t = token.item(Int.self)
            return (t, eosTokenIds.contains(t))
        }
    }

    /// One target forward over `[seed] + draft`; return the target argmax at each of `draft.count + 1` positions.
    /// Verbatim BASCoreMLDraftDecoder.swift:99-112 (the verify/argmax block), returning `[Int]`.
    public func verify(committedLast seed: Int, draft: [Int]) throws -> [Int] {
        let verifyTokens: MLXArray = draft.isEmpty
            ? MLXArray([Int32(seed)])
            : concatenated([MLXArray([Int32(seed)]), MLXArray(draft.map { Int32($0) })])
        let verifyInput = LMInput.Text(tokens: verifyTokens)
        let verifyStart = verifyInput.tokens.dim(0) - (draft.count + 1)
        let result = model(verifyInput[text: .newAxis], cache: cache, state: state)
        state = result.state
        let verifyLogits = result.logits[0..., verifyStart..., 0...].squeezed(axis: 0)
        let mainTokens = sampler.sample(logits: verifyLogits)
        eval(mainTokens)
        return mainTokens.asArray(Int.self)
    }

    /// Rewind the target cache for the rejected drafts (verbatim BASCoreMLDraftDecoder.swift:127).
    public func trimRejected(_ rejected: Int) {
        guard rejected > 0 else { return }
        _ = trimPromptCache(cache, numTokens: rejected)
    }
}
#endif
