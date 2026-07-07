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
        let proposed: Int
        let box: MTPDecoderBox
        var thermalFallback: Bool = false
        var traceExitReason: String? = nil
        var traceThinkTokens: Int? = nil
    }

    /// Full-pipeline `.mtpSpec` turn: template → tokenize → MTP spec decode (EOS-aware) → detokenize.
    /// Throws (e.g. `notQwen35`, missing weights) — the executor fail-closes to `_plainDraft`.
    func _generateMTPSpec(
        for request: BASOrganRequest, sampling: Bool = false
    ) async throws -> (draft: BASOrganDraft, accepted: Int, rounds: Int, proposed: Int) {
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
        let diffProbe = _armedDifficultyProbe(requestCapped: request.maxOutputTokens != nil)
        let probeReport = Self._ProbeReportBox()
        let seedChainEmaL = restoredChainEmaL            // P0: actor read before the closure
        let raw: _MTPRaw = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec: BASQwen35MTPSpecDecoder
            if let prior = priorBox?.decoder {
                dec = prior
            } else {
                dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                // P0: seed the regime EMA from the persisted/carried value (nil unless
                // BAS_PROFILER_PERSIST=1 ⇒ off = cold 1.6 default, byte-equal today).
                if let seed = seedChainEmaL { dec.chainEmaL = seed }
            }
            let eos = Self._productionEOSTokenIds(
                eosTokenId: ctx.tokenizer.eosTokenId, resolve: { ctx.tokenizer.convertTokenToId($0) })
            let promptIds = input.text.tokens.asArray(Int.self)
            let trace = Self._traceExitConfig(
                resolve: { ctx.tokenizer.convertTokenToId($0) },
                encode: { ctx.tokenizer.encode(text: $0) },
                requestCapped: request.maxOutputTokens != nil, maxTokens: maxTokens)
            let r = sampling
                ? dec.generateSpecSampling(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    temperature: Float(request.preset.temperature), topP: Float(request.preset.topP))
                : dec.generateSpecKFused(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    k: Self.mtpProductionK, tCap: Self.mtpProductionTCap, adaptiveK: true,
                    traceExit: trace,
                    postPrefillBudget: Self._probeBudgetHook(diffProbe, planned: maxTokens,
                                                             reportInto: probeReport))
            if let te = r.traceExit {
                print("📊 trace-exit fired reason=\(te.reason.rawValue) think=\(te.thinkTokensAtExit) out=\(te.outCountAtExit)/\(maxTokens)")
            }
            return _MTPRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens),
                accepted: r.accepted, rounds: r.iterations, proposed: r.proposed,
                box: MTPDecoderBox(decoder: dec),
                traceExitReason: r.traceExit?.reason.rawValue,
                traceThinkTokens: r.traceExit?.thinkTokensAtExit)
        }
        mtpDecoderBox = raw.box                                    // cache across turns (init quantizes ~300MB)
        let laneName = sampling ? "mtpSpecSampling" : "mtpSpec"
        let draft = _buildDraft(
            body: Self.applyMarkerPostprocessing(raw.body), request: request)
            .withDecodeAttribution(BASDecodeAttribution(
                requestID: request.requestID, context: nil,
                plannedLane: laneName, executedLane: laneName,
                traceExitReason: raw.traceExitReason, traceThinkTokens: raw.traceThinkTokens,
                diffProbe: probeReport.report.map {
                    .armed(pSuccess: $0.pSuccess, planned: $0.planned, refined: $0.refined)
                } ?? .off))
        return (draft, raw.accepted, raw.rounds, raw.proposed)
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
    ) async throws -> (draft: BASOrganDraft, accepted: Int, rounds: Int, proposed: Int) {
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
        let diffProbe = _armedDifficultyProbe(requestCapped: request.maxOutputTokens != nil)
        let probeReport = Self._ProbeReportBox()
        // 缝8b (2026-07-06 audit): the 2-slot decode governor was acquired only on the POOLED
        // route — the default-on capped-fused class ran ungoverned past the jetsam-margin cap
        // (135MB from the limit at 8-wide) that justified the governor.
        await acquireSessionDecodeSlot()
        defer { releaseSessionDecodeSlot() }
        let seedChainEmaL = restoredChainEmaL            // P0: actor read before the closure
        let raw: _MTPRaw = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec: BASQwen35MTPSpecDecoder
            if let prior = priorBox?.decoder {
                dec = prior
            } else {
                dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                // P0: seed the regime EMA from the persisted/carried value (nil unless
                // BAS_PROFILER_PERSIST=1 ⇒ off = cold 1.6 default, byte-equal today).
                if let seed = seedChainEmaL { dec.chainEmaL = seed }
            }
            let eos = Self._productionEOSTokenIds(
                eosTokenId: ctx.tokenizer.eosTokenId, resolve: { ctx.tokenizer.convertTokenToId($0) })
            let promptIds = input.text.tokens.asArray(Int.self)
            let trace = Self._traceExitConfig(
                resolve: { ctx.tokenizer.convertTokenToId($0) },
                encode: { ctx.tokenizer.encode(text: $0) },
                requestCapped: request.maxOutputTokens != nil, maxTokens: maxTokens)
            // 缝1 (2026-07-06 audit): the session lanes bypassed the planner's certified serious+→plain
            // gate — the fused loop's adaptedK only clamps K=1 (calibrated for fair). At serious+ run
            // PLAIN in transcript-land (route class unchanged ⇒ no transcript orphaning), keeping the
            // B3 answer guarantee on capped turns via the plain loop's traceExit support. B2 budget
            // refinement is deliberately NOT consulted under thermal (no upshifts while throttled).
            let r: BASQwen35MTPSpecDecoder.Run
            let thermalFallback = MLXOrganAdapter._thermalThrottled()
            if thermalFallback {
                r = dec.generatePlain(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos, traceExit: trace)
                print("📊 session-thermal fallback=plain out=\(r.tokens.count)/\(maxTokens)")
            } else {
                r = dec.generateSpecKFused(
                    prompt: promptIds, maxTokens: maxTokens, eosTokens: eos,
                    k: Self.mtpProductionK, tCap: Self.mtpProductionTCap, adaptiveK: true,
                    traceExit: trace,
                    postPrefillBudget: Self._probeBudgetHook(diffProbe, planned: maxTokens,
                                                             reportInto: probeReport))
            }
            if let te = r.traceExit {
                print("📊 trace-exit fired reason=\(te.reason.rawValue) think=\(te.thinkTokensAtExit) out=\(te.outCountAtExit)/\(maxTokens)")
            }
            return _MTPRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens),
                accepted: r.accepted, rounds: r.iterations, proposed: r.proposed,
                box: MTPDecoderBox(decoder: dec), thermalFallback: thermalFallback,
                traceExitReason: r.traceExit?.reason.rawValue,
                traceThinkTokens: r.traceExit?.thinkTokensAtExit)
        }
        mtpDecoderBox = raw.box
        if raw.thermalFallback { sessionThermalFallbackCount += 1 }
        let draft = _buildDraft(
            body: Self.applyMarkerPostprocessing(raw.body), request: request)
            .withDecodeAttribution(BASDecodeAttribution(
                requestID: request.requestID, context: nil,
                plannedLane: "sessionFused",
                executedLane: raw.thermalFallback ? "plain" : "sessionFused",
                failCloseReason: raw.thermalFallback ? "thermal" : nil,
                traceExitReason: raw.traceExitReason, traceThinkTokens: raw.traceThinkTokens,
                diffProbe: probeReport.report.map {
                    .armed(pSuccess: $0.pSuccess, planned: $0.planned, refined: $0.refined)
                } ?? .off))
        return (draft, raw.accepted, raw.rounds, raw.proposed)
    }

    /// `sending`-annotated transcript prepare (the `_buildLMInput` pattern — the LMInput must cross
    /// into `container.perform(nonSendable:)`).
    static func _prepareTranscript(
        _ transcript: [(role: String, text: String)], container: ModelContainer
    ) async throws -> sending LMInput {
        try await container.prepare(input: UserInput(chat: MLXOrganAdapter.chatMessages(from: transcript)))
    }

    /// B3 trace early-exit config — PROMOTED 2026-07-04 (two-Air A/B: think −79%, quality 6/6 vs
    /// control 0/6 all-think-no-answer; co-gate quality suite = the promotion validator).
    ///
    /// Arming (效率环 wire): a request that carries an EXPLICIT decode cap (the effort loop's
    /// maxDecodeTokens dial {64,160,384,1024} → request.maxOutputTokens) arms the policy in
    /// production — "you asked for a budget; an answer must fit inside it". Un-capped turns
    /// (adapter's 512 default) stay unarmed. BAS_TRACE_EXIT=1 force-arms (probe), BAS_TRACE_EXIT_OFF=1
    /// is the ADR-014 kill-switch (beats everything).
    ///
    /// Reserve scales with the cap (device A/B miss: reserve-32 at cap-128 truncated the verbose 4B's
    /// answers → ≤160-token caps reserve 48). Token ids resolved from the LIVE tokenizer with
    /// Qwen3.5-family fallbacks (`<think>`=248068, `</think>`=248069, `\n`=198, `\n\n`=271 — verified
    /// 2026-07-04; templates that PRE-OPEN think are handled by the policy's primed-in-think scan).
    /// Knobs: _TAU millinats (300), _WINDOW (8), _MIN (24), _RESERVE (cap-scaled), _BUDGET_ONLY=1.
    nonisolated static func _traceExitConfig(
        resolve: (String) -> Int?, encode: (String) -> [Int],
        requestCapped: Bool, maxTokens: Int,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> BASTraceExitConfig? {
        guard env["BAS_TRACE_EXIT_OFF"] != "1" else { return nil }          // kill-switch
        guard env["BAS_TRACE_EXIT"] == "1" || requestCapped else { return nil }
        let open = resolve("<think>") ?? 248068
        let close = resolve("</think>") ?? 248069
        let nl = encode("\n").last ?? 198
        let nl2 = encode("\n\n").last ?? 271
        var tau: Int? = env["BAS_TRACE_EXIT_TAU"].flatMap(Int.init) ?? 300
        if env["BAS_TRACE_EXIT_BUDGET_ONLY"] == "1" { tau = nil }
        let closeSeq = [nl, close, nl2]
        // Cap-scaled reserve; the clamp (review MEDIUM-2) keeps the budget guard alive: the loop
        // observes AFTER emit, so a reserve below closeSequence+1 could never fire.
        let scaled = maxTokens <= 160 ? 48 : 32
        let reserve = max(env["BAS_TRACE_EXIT_RESERVE"].flatMap(Int.init) ?? scaled, closeSeq.count + 1)
        return BASTraceExitConfig(
            thinkOpenToken: open, thinkCloseToken: close,
            closeSequence: closeSeq, boundaryTokens: [nl, nl2],
            minThinkTokens: env["BAS_TRACE_EXIT_MIN"].flatMap(Int.init) ?? 24,
            entropyWindow: env["BAS_TRACE_EXIT_WINDOW"].flatMap(Int.init) ?? 8,
            entropyThresholdMillinats: tau,
            answerReserveTokens: reserve)
    }

    /// B2 — build the post-prefill budget hook for the fused lane. The hidden-state read is ONE
    /// small host sync (hidden-dim floats) after prefill; the refinement is bounded ±1 tier so
    /// the probe REFINES the effort plan, never overrules it.
    /// 可解释性①: the hook's decision, captured for the turn line (armed-and-AGREED is now
    /// distinguishable from never-armed — the audit's exact complaint).
    final class _ProbeReportBox: @unchecked Sendable {
        var report: (pSuccess: Double, planned: Int, refined: Int)?
    }
    nonisolated static func _probeBudgetHook(
        _ probe: BASDifficultyProbe?, planned: Int, reportInto box: _ProbeReportBox? = nil
    ) -> ((MLXArray) -> Int)? {
        guard let probe else { return nil }
        return { hLast in
            let h = hLast.asType(.float32).asArray(Float.self)
            guard let p = try? probe.successProbability(hidden: h) else { return planned }
            var refined = probe.refinedBudget(planned: planned, pSuccess: p)
            // 缝8c (2026-07-06 audit): difficulty and thermal never saw each other — a hard
            // question under throttle got MORE budget exactly when the device needs less. Under
            // throttle the probe may only downshift (B3's budget guard still protects the tail).
            if refined > planned, MLXOrganAdapter._thermalThrottled() { refined = planned }
            box?.report = (p, planned, refined)
            if refined != planned {
                print(String(format: "📊 diff-probe p_success=%.2f budget %d→%d", p, planned, refined))
            }
            return refined
        }
    }

    /// B2 — difficulty-probe weights resolution (env override → Documents → the Mac dev path).
    nonisolated static func _resolveDiffProbeURL() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let p = env["BAS_DIFF_PROBE_WEIGHTS"] { return URL(fileURLWithPath: p) }
        if let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("probe_weights.json"),
            FileManager.default.fileExists(atPath: d.path) { return d }
        let tmp = URL(fileURLWithPath: "/tmp/gdn_coreai/probe_weights.json")
        return FileManager.default.fileExists(atPath: tmp.path) ? tmp : nil
    }

    /// B2 — the armed probe. PROMOTED 2026-07-06 (the B3 arming shape): arms in PRODUCTION on
    /// budget-capped requests whenever weights resolve (the effort loop's turns), because the
    /// refinement is bounded ±1 tier AND the B3 budget guard protects the answer tail on any
    /// downshift (the composition the device co-gate validates). BAS_DIFF_PROBE=1 force-arms
    /// un-capped turns (probes); BAS_DIFF_PROBE_OFF=1 is the ADR-014 kill-switch.
    func _armedDifficultyProbe(requestCapped: Bool) -> BASDifficultyProbe? {
        let env = ProcessInfo.processInfo.environment
        guard env["BAS_DIFF_PROBE_OFF"] != "1" else { return nil }
        guard env["BAS_DIFF_PROBE"] == "1" || requestCapped else { return nil }
        if !diffProbeResolved {
            diffProbeResolved = true
            diffProbeBox = Self._resolveDiffProbeURL().flatMap { try? BASDifficultyProbe(weightsURL: $0) }
        }
        return diffProbeBox
    }

    /// 案5: process memory headroom (bytes until the jetsam cap) — the DecodeContext / pressure
    /// ladder feed. nil off-iOS (macOS has no per-process jetsam semantics).
    nonisolated static func _memoryHeadroomBytes() -> Int? {
        #if os(iOS)
        let a = os_proc_available_memory()
        return a > 0 ? Int(a) : nil
        #else
        return nil
        #endif
    }

    /// 案5: assemble the per-turn decode context ONCE (thermal sampled here; the fused chain's
    /// per-round re-read stays as the certified in-flight escape hatch).
    nonisolated static func _decodeContext(
        purpose: BASDecodeLanePolicy.Purpose, request: BASOrganRequest
    ) -> BASDecodeContext {
        BASDecodeContext(
            purpose: purpose, temperature: request.preset.temperature,
            maxOutputTokens: request.maxOutputTokens,
            thermalThrottled: _thermalThrottled(),
            memoryHeadroomBytes: _memoryHeadroomBytes())
    }

    /// Thermal throttle probe for the planner gate (cert finding: MTP is net-negative under serious+).
    nonisolated static func _thermalThrottled() -> Bool {
        // Test/probe seam — can only FORCE the conservative direction, never defeat the gate.
        if ProcessInfo.processInfo.environment["BAS_THERMAL_FORCE"] == "1" { return true }
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
