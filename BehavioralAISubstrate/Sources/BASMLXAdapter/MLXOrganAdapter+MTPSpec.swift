// MLXOrganAdapter+MTPSpec — the `.mtpSpec` generation pipeline (ship-cert wiring, ADR-014 opt-in).
//
// Mirrors `_generateModelFree`'s shape exactly: same prompt build (`_buildLMInput` — chat template + tokenize),
// same production EOS superset, same `BASOrganDraft` construction — only the decode loop differs
// (BASQwen35MTPSpecDecoder: K=1 MTP spec, sub-head draft, carry-forward reject; ADR-039 lossless — every emitted
// token is the trunk's own argmax). Device-certified: engaged 1.20-1.36× (real prompts), thermal-gated by the
// planner, a-telemetry folded into the acceptance profiler (the lane's 0.15 floor is LIVE, unlike the
// draft-model lane's cold-forever gap).
import Foundation
import BASOrgan

#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon
#endif

extension MLXOrganAdapter {
    #if canImport(MLXLLM)

    /// Sendable payload out of the container closure.
    fileprivate struct _MTPRaw: Sendable {
        let body: String
        let accepted: Int
        let rounds: Int
        let box: MTPDecoderBox
    }

    /// Full-pipeline `.mtpSpec` turn: template → tokenize → MTP spec decode (EOS-aware) → detokenize.
    /// Throws (e.g. `notQwen35`, missing weights) — the executor fail-closes to `_plainDraft`.
    func _generateMTPSpec(
        for request: BASOrganRequest, sampling: Bool = false
    ) async throws -> (draft: BASOrganDraft, accepted: Int, rounds: Int) {
        guard let container = _loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before an accelerated draft"))
        }
        guard let wURL = _resolveMTPWeightsURL() else {
            throw BASQwen35MTPSpecDecoder.SpecError.missingWeights("no MTP weights resolved (see _resolveMTPWeightsURL)")
        }
        let input = try await _buildLMInput(for: request, container: container)
        let params = _greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let maxTokens = params.maxTokens ?? 512
        let priorBox = mtpDecoderBox
        let raw: _MTPRaw = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec = try priorBox?.decoder
                ?? BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
            let eos = Self._productionEOSTokenIds(
                eosTokenId: ctx.tokenizer.eosTokenId, resolve: { ctx.tokenizer.convertTokenToId($0) })
            let promptIds = input.text.tokens.asArray(Int.self)
            let r = sampling
                ? dec.generateSpecSampling(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    temperature: Float(request.preset.temperature), topP: Float(request.preset.topP))
                : dec.generateSpec(prompt: promptIds, maxTokens: maxTokens, eosTokens: eos)
            return _MTPRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens),
                accepted: r.accepted, rounds: r.iterations, box: MTPDecoderBox(decoder: dec))
        }
        mtpDecoderBox = raw.box                                    // cache across turns (init quantizes ~300MB)
        let draft = _buildDraft(
            body: Self.applyMarkerPostprocessing(raw.body), request: request)
        return (draft, raw.accepted, raw.rounds)
    }
    /// Thermal throttle probe for the planner gate (cert finding: MTP is net-negative under serious+).
    nonisolated static func _thermalThrottled() -> Bool {
        let t = ProcessInfo.processInfo.thermalState
        return t == .serious || t == .critical
    }

    /// Public diagnostics: the URL default-ON resolution found (nil = lane not offered).
    public nonisolated func mtpResolvedWeightsURL() -> URL? { _resolveMTPWeightsURL() }

    /// Test/telemetry accessor: the profiler stat for the MTP lane (nil until first fold).
    /// Public like `mtpResolvedWeightsURL` — the device probe (separate module) reads it for the A/B verdict line.
    public func mtpProfilerStat() -> BASAcceptanceProfiler.Stat? {
        draftProfiler.stat(BASDecodeStrategy.mtpSpecID, .factual)
    }

    /// Test/telemetry accessor for the SAMPLING lane (draft() routes purpose .scoutDefault).
    public func mtpSamplingProfilerStat() -> BASAcceptanceProfiler.Stat? {
        draftProfiler.stat(BASDecodeStrategy.mtpSpecSamplingID, .scoutDefault)
    }
    #endif
}
