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
            let trace = Self._traceExitConfigFromEnv(
                resolve: { ctx.tokenizer.convertTokenToId($0) },
                encode: { ctx.tokenizer.encode(text: $0) })
            let r = sampling
                ? dec.generateSpecSampling(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    temperature: Float(request.preset.temperature), topP: Float(request.preset.topP))
                : dec.generateSpecKFused(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    k: Self.mtpProductionK, tCap: Self.mtpProductionTCap, adaptiveK: true,
                    traceExit: trace)
            if let te = r.traceExit {
                print("📊 trace-exit fired reason=\(te.reason.rawValue) think=\(te.thinkTokensAtExit) out=\(te.outCountAtExit)/\(maxTokens)")
            }
            return _MTPRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens),
                accepted: r.accepted, rounds: r.iterations, box: MTPDecoderBox(decoder: dec))
        }
        mtpDecoderBox = raw.box                                    // cache across turns (init quantizes ~300MB)
        let draft = _buildDraft(
            body: Self.applyMarkerPostprocessing(raw.body), request: request)
        return (draft, raw.accepted, raw.rounds)
    }
    /// PRODUCTION deep-K election (2026-07-03, the fused-chain campaign): the greedy `.mtpSpec` lane runs the
    /// FUSED chain with ADAPTIVE K ≤ 3 — endurance-cert finding: chain acceptance is workload-dependent
    /// (real prose a/iter≈1.0 ⇒ fixed K=3 is 0.90×; synthetic/thinking 2.05+ ⇒ 1.51×, cold 31.0). The
    /// per-round EMA controller settles prose at K=1 (the certified 1.20-1.36× regime) and rides K=3 on
    /// high-overlap workloads — never worse than the certified K=1 lane by construction.
    static let mtpProductionK = 3
    /// Verify-width cap: keeps EVERY trunk forward in the qmv regime. Phone-class GPUs flip the MLP-9728 /
    /// lm_head-248K matmuls qmv→qmm at T ≥ 6 (`get_qmv_batch_limit` — verify measured 119ms/round vs ~50);
    /// Mac 'd'-arch limit is 12+ (its T-curve is linear to 11, measured). THE historical deep-K device killer.
    #if os(iOS)
    static let mtpProductionTCap = 5
    #else
    static let mtpProductionTCap = 12
    #endif

    /// 会话→加速lane — the fused decode over an EXPLICIT message transcript (the stateless session
    /// path): identical to `_generateMTPSpec` except the prompt is the caller's multi-turn transcript
    /// (same Chat.Message → UserInput machinery as ChatSession ⇒ zero template drift).
    func _generateMTPSpecFromMessages(
        _ transcript: [(role: String, text: String)], for request: BASOrganRequest
    ) async throws -> (draft: BASOrganDraft, accepted: Int, rounds: Int) {
        guard let container = _loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before an accelerated draft"))
        }
        guard let wURL = _resolveMTPWeightsURL() else {
            throw BASQwen35MTPSpecDecoder.SpecError.missingWeights("no MTP weights resolved")
        }
        let input = try await Self._prepareTranscript(transcript, container: container)
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
            let trace = Self._traceExitConfigFromEnv(
                resolve: { ctx.tokenizer.convertTokenToId($0) },
                encode: { ctx.tokenizer.encode(text: $0) })
            let r = dec.generateSpecKFused(
                prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                k: Self.mtpProductionK, tCap: Self.mtpProductionTCap, adaptiveK: true,
                traceExit: trace)
            if let te = r.traceExit {
                print("📊 trace-exit fired reason=\(te.reason.rawValue) think=\(te.thinkTokensAtExit) out=\(te.outCountAtExit)/\(maxTokens)")
            }
            return _MTPRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens),
                accepted: r.accepted, rounds: r.iterations, box: MTPDecoderBox(decoder: dec))
        }
        mtpDecoderBox = raw.box
        let draft = _buildDraft(
            body: Self.applyMarkerPostprocessing(raw.body), request: request)
        return (draft, raw.accepted, raw.rounds)
    }

    /// `sending`-annotated transcript prepare (the `_buildLMInput` pattern — the LMInput must cross
    /// into `container.perform(nonSendable:)`).
    static func _prepareTranscript(
        _ transcript: [(role: String, text: String)], container: ModelContainer
    ) async throws -> sending LMInput {
        try await container.prepare(input: UserInput(chat: MLXOrganAdapter.chatMessages(from: transcript)))
    }

    /// B3 trace early-exit config (ADR-014: env-armed, default OFF). Token ids resolved from the LIVE
    /// tokenizer with Qwen3.5-family fallbacks (`<think>`=248068, `</think>`=248069, `\n`=198, `\n\n`=271
    /// — verified against the mlx-community 4-bit tokenizer 2026-07-04; the MLX chat template does NOT
    /// pre-open think blocks — the model emits the markers itself — and the policy is marker-gated so a
    /// no-think generation is untouched). Knobs: BAS_TRACE_EXIT=1 (arm), _TAU millinats (default 300),
    /// _WINDOW (8), _MIN (24), _RESERVE (32), _BUDGET_ONLY=1 (entropy rule off, budget guard only).
    nonisolated static func _traceExitConfigFromEnv(
        resolve: (String) -> Int?, encode: (String) -> [Int]
    ) -> BASTraceExitConfig? {
        let env = ProcessInfo.processInfo.environment
        guard env["BAS_TRACE_EXIT"] == "1" else { return nil }
        let open = resolve("<think>") ?? 248068
        let close = resolve("</think>") ?? 248069
        let nl = encode("\n").last ?? 198
        let nl2 = encode("\n\n").last ?? 271
        var tau: Int? = env["BAS_TRACE_EXIT_TAU"].flatMap(Int.init) ?? 300
        if env["BAS_TRACE_EXIT_BUDGET_ONLY"] == "1" { tau = nil }
        let closeSeq = [nl, close, nl2]
        // Reserve clamp (review MEDIUM-2): the loop observes AFTER emit, so a reserve below
        // closeSequence+1 lets emit() exhaust the budget before the guard can ever fire —
        // the edge knob value would silently disable the exact artifact-fix the guard exists for.
        let reserve = max(env["BAS_TRACE_EXIT_RESERVE"].flatMap(Int.init) ?? 32, closeSeq.count + 1)
        return BASTraceExitConfig(
            thinkOpenToken: open, thinkCloseToken: close,
            closeSequence: closeSeq, boundaryTokens: [nl, nl2],
            minThinkTokens: env["BAS_TRACE_EXIT_MIN"].flatMap(Int.init) ?? 24,
            entropyWindow: env["BAS_TRACE_EXIT_WINDOW"].flatMap(Int.init) ?? 8,
            entropyThresholdMillinats: tau,
            answerReserveTokens: reserve)
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
