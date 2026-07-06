import XCTest
import MLX
import MLXHuggingFace
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
@testable import BASMLXAdapter

/// Fused-chain gates (BAS_MTP_FUSED=1; heavy — loads Qwen3.5-4B):
/// F1 — chain fidelity: fused K-link chain vs the sequential mtpForward reference (same state, same inputs)
///      must produce the same draft ids (fp32 scores both sides; SDPA vs manual attention tolerance).
/// F2 — lossless family + speed: plain vs fused K=5 on the real model (acceptance sanity + Mac A/B tok/s).
final class BASMTPFusedChainTests: XCTestCase {

    struct R: Sendable {
        var fusedDs: [Int] = []
        var seqDs: [Int] = []
        var plainTok: [Int] = []
        var fusedTok: [Int] = []
        var plainSec = 0.0
        var fusedSec = 0.0
        var accepted = 0
        var iters = 0
    }

    /// Trunk verify-forward cost vs T (BAS_MTP_TCURVE=1): locates the qmv→qmm dispatch cliff that killed
    /// every deep-K attempt (get_qmv_batch_limit in vendored quantized.cpp — arch- and dim-dependent).
    func testTrunkTCurve() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_TCURVE"] == "1" else {
            throw XCTSkip("set BAS_MTP_TCURVE=1")
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: []),
            progressHandler: { _ in })
        let curve: [(Int, Double)] = try await container.perform { ctx -> [(Int, Double)] in
            guard let model = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            var rows: [(Int, Double)] = []
            for t in 1 ... 14 {
                let cache = model.newCache(parameters: nil)
                _ = model.hiddenStatesWithCache(
                    MLXArray((0 ..< 64).map { Int32(100 + $0) }).expandedDimensions(axis: 0), cache: cache)
                let input = MLXArray((0 ..< t).map { Int32(200 + $0) }).expandedDimensions(axis: 0)
                for _ in 0 ..< 3 {                                       // warmup
                    eval(argMax(model.logits(fromHidden: model.hiddenStatesWithCache(input, cache: cache))[0], axis: -1))
                    for c in cache where !(c is ArraysCache) { _ = c.trim(t) }
                }
                let t0 = Date()
                let reps = 20
                for _ in 0 ..< reps {
                    eval(argMax(model.logits(fromHidden: model.hiddenStatesWithCache(input, cache: cache))[0], axis: -1))
                    for c in cache where !(c is ArraysCache) { _ = c.trim(t) }
                }
                rows.append((t, Date().timeIntervalSince(t0) / Double(reps) * 1000))
            }
            return rows
        }
        for (t, ms) in curve { print(String(format: "=== TCURVE T=%2d  %.2f ms ===", t, ms)) }
    }

    func testFusedChainFidelityAndAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_FUSED"] == "1" else {
            throw XCTSkip("set BAS_MTP_FUSED=1 (needs /tmp/gdn_coreai/qwen35_mtp_folded.safetensors)")
        }
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: []),
            progressHandler: { _ in })
        let kK = Int(ProcessInfo.processInfo.environment["BAS_MTP_FUSED_K"] ?? "") ?? 5
        let r: R = try await container.perform { ctx -> R in
            guard let model = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
            var out = R()
            // ---- F1: fidelity — one chain from a REAL prefill state, fused vs sequential ----
            let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
            let cache = model.newCache(parameters: nil)
            let h0 = model.hiddenStatesWithCache(
                MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
            let hLast = h0[0, h0.dim(1) - 1]
            let pos0 = prompt.count - 1
            let first = dec.argmaxLast(model.logits(fromHidden: h0))
            dec.resetMTPStream()
            let fused = dec.fusedChain(k: kK, firstToken: first, hidden: hLast, pos0: pos0)
            eval(fused.ds)
            out.fusedDs = fused.ds.map { $0.item(Int.self) }
            // sequential reference — the EXACT production-lane ops (mtpForward scatters per link)
            dec.resetMTPStream()
            var e = model.embedding(MLXArray([Int32(first)]))[0]
            var y = hLast
            for j in 0 ..< kK {
                y = dec.mtpForward(embedNext: e, hidden: y, pos: pos0 + j)
                let dj = dec.draftArgmax(y)
                out.seqDs.append(dj.item(Int.self))
                if j + 1 < kK { e = model.embedding(dj.reshaped([1]))[0] }
            }
            // ---- F2: plain vs fused K=5 (fresh decode each; identity family + Mac A/B) ----
            let n = 64
            let plain = dec.generatePlain(prompt: prompt, maxTokens: n)
            let spec = dec.generateSpecKFused(prompt: prompt, maxTokens: n, k: kK)
            out.plainTok = plain.tokens; out.fusedTok = spec.tokens
            out.plainSec = plain.decodeSeconds; out.fusedSec = spec.decodeSeconds
            out.accepted = spec.accepted; out.iters = spec.iterations
            return out
        }
        print("=== F1 fused ds \(r.fusedDs) vs sequential ds \(r.seqDs) ===")
        // SDPA-vs-manual fp32 attention can tie-flip in principle; demand ≥4/5 id equality + first-link exact.
        XCTAssertEqual(r.fusedDs.first, r.seqDs.first, "first link must match the sequential reference exactly")
        let agree = zip(r.fusedDs, r.seqDs).filter(==).count
        XCTAssertGreaterThanOrEqual(agree, kK - 1, "fused chain diverged from the sequential reference")
        var div = -1
        for i in 0 ..< min(r.plainTok.count, r.fusedTok.count) where r.plainTok[i] != r.fusedTok[i] {
            div = i; break
        }
        let aPerIter = r.iters > 0 ? Double(r.accepted) / Double(r.iters) : 0
        let eTok = r.iters > 0 ? Double(r.fusedTok.count) / Double(r.iters) : 0
        print(String(format: "=== F2 PLAIN %.1f tok/s | FUSED-K%d %.1f tok/s = %.2fx | acc/iter=%.2f E[tok]/iter=%.2f | serial-div@%d ===",
                     Double(r.plainTok.count) / r.plainSec, kK,
                     Double(r.fusedTok.count) / r.fusedSec,
                     (Double(r.fusedTok.count) / r.fusedSec) / (Double(r.plainTok.count) / r.plainSec),
                     aPerIter, eTok, div))
        // Wiring-break detectors (trap #6: byte-identical-but-broken shows up here, not in bytes).
        XCTAssertGreaterThan(aPerIter, 1.2, "chain acceptance collapsed — fused wiring broke (golden ≈2.35 device)")
        XCTAssertGreaterThan(eTok, 2.0, "E[tok]/iter below deep-K value — chain not paying")
    }

    /// F3 — B3 trace early-exit end-to-end on a REAL reasoning trace (BAS_TRACE_EXIT_TEST=1):
    /// aggressive τ makes the entropy rule fire deterministically; asserts the full force-close path
    /// (policy → inject "\n</think>\n\n" → verify-round unwind → refeed → answer continues) and that
    /// the exited run never emits more than the control. Plumbing gate — QUALITY is judged on device.
    func testTraceExitForcedCloseOnRealTrace() async throws {
        guard ProcessInfo.processInfo.environment["BAS_TRACE_EXIT_TEST"] == "1" else {
            throw XCTSkip("set BAS_TRACE_EXIT_TEST=1 (heavy — loads Qwen3.5-4B)")
        }
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let input = try await container.prepare(input: UserInput(chat: [
            .user("How many prime numbers are there between 10 and 50? Think step by step.")]))
        struct TR: Sendable {
            var firedReason: String?
            var thinkAtExit = 0
            var closeID = 0
            var exitTok: [Int] = []
            var ctrlTok: [Int] = []
            var exitText = ""
        }
        let r: TR = try await container.perform(nonSendable: input) { ctx, input in
            guard let model = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
            let promptIds = input.text.tokens.asArray(Int.self)
            var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
            let open = ctx.tokenizer.convertTokenToId("<think>") ?? 248068
            let close = ctx.tokenizer.convertTokenToId("</think>") ?? 248069
            let nl = ctx.tokenizer.encode(text: "\n").last ?? 198
            let nl2 = ctx.tokenizer.encode(text: "\n\n").last ?? 271
            let cfg = BASTraceExitConfig(
                thinkOpenToken: open, thinkCloseToken: close,
                closeSequence: [nl, close, nl2], boundaryTokens: [nl, nl2],
                minThinkTokens: 8, entropyWindow: 4,
                entropyThresholdMillinats: 100_000,          // fire at the first post-min boundary
                answerReserveTokens: 16)
            var out = TR()
            out.closeID = close
            let a = dec.generateSpecKFused(prompt: promptIds, maxTokens: 160, eosTokens: eos,
                                           k: 3, tCap: 12, adaptiveK: true, traceExit: cfg)
            out.firedReason = a.traceExit?.reason.rawValue
            out.thinkAtExit = a.traceExit?.thinkTokensAtExit ?? 0
            out.exitTok = a.tokens
            out.exitText = ctx.tokenizer.decode(tokenIds: a.tokens)
            let b = dec.generateSpecKFused(prompt: promptIds, maxTokens: 160, eosTokens: eos,
                                           k: 3, tCap: 12, adaptiveK: true)
            out.ctrlTok = b.tokens
            return out
        }
        print("=== F3 fired=\(r.firedReason ?? "NO") think@exit=\(r.thinkAtExit) exit=\(r.exitTok.count)tok ctrl=\(r.ctrlTok.count)tok ===")
        print("=== F3 exit text: \(r.exitText.replacingOccurrences(of: "\n", with: "⏎")) ===")
        XCTAssertEqual(r.firedReason, "entropy",
                       "aggressive τ must fire the entropy rule on a real thinking trace (no fire ⇒ the model never opened <think> or plumbing broke)")
        guard let closeIdx = r.exitTok.firstIndex(of: r.closeID) else {
            return XCTFail("</think> was not injected into the stream")
        }
        XCTAssertGreaterThan(r.exitTok.count - closeIdx - 1, 0,
                             "an answer tail must continue after the forced close (refeed path)")
        XCTAssertLessThanOrEqual(r.exitTok.count, r.ctrlTok.count,
                                 "the exited run must never emit more than the control")
    }

    /// F4 — B2 difficulty probe e2e (BAS_DIFF_PROBE_TEST=1): real weights + real hidden states.
    /// Rank-order assertions (AUC 0.833 ⇒ per-example asserts would flake; ordering on the two
    /// EXTREME families — percent acc 1.00 vs 3d×3d mul acc 0.00 — is the robust contract).
    func testDifficultyProbeEndToEnd() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DIFF_PROBE_TEST"] == "1" else {
            throw XCTSkip("set BAS_DIFF_PROBE_TEST=1 (needs /tmp/gdn_coreai/probe_weights.json)")
        }
        let probe = try BASDifficultyProbe(
            weightsURL: URL(fileURLWithPath: "/tmp/gdn_coreai/probe_weights.json"))
        print("=== F4 probe heldout_auc=\(probe.heldoutAUC) dims=\(probe.w.count) ===")
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        func run(_ q: String) async throws -> (p: Double, budget: Int, tokens: Int) {
            let input = try await container.prepare(input: UserInput(chat: [.user(q)]))
            return try await container.perform(nonSendable: input) { ctx, input in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let ids = input.text.tokens.asArray(Int.self)
                var seenP = 0.0, seenBudget = 160
                let hook: (MLXArray) -> Int = { hLast in
                    let h = hLast.asType(.float32).asArray(Float.self)
                    seenP = (try? probe.successProbability(hidden: h)) ?? -1
                    seenBudget = probe.refinedBudget(planned: 160, pSuccess: seenP)
                    return seenBudget
                }
                let r = dec.generateSpecKFused(prompt: ids, maxTokens: 160, eosTokens: eos,
                                               k: 3, tCap: 12, adaptiveK: true,
                                               postPrefillBudget: hook)
                return (seenP, seenBudget, r.tokens.count)
            }
        }
        let easy = try await run("What is 25% of 320?")
        let hard = try await run("What is 847 multiplied by 693?")
        print(String(format: "=== F4 easy p=%.2f budget=%d tok=%d | hard p=%.2f budget=%d tok=%d ===",
                     easy.p, easy.budget, easy.tokens, hard.p, hard.budget, hard.tokens))
        XCTAssertGreaterThan(easy.p, hard.p, "probe must rank the easy prompt above the hard one")
        XCTAssertGreaterThanOrEqual(hard.budget, easy.budget, "budgets must follow the ranking")
        XCTAssertLessThanOrEqual(easy.tokens, easy.budget, "the refined budget must actually bind")
    }

    /// F5 — M1 Gate-b: the Swift DFlash port vs the Python reference (BAS_DFLASH_TEST=1).
    /// Reference (z-lab model_mlx.py, SAME target 4-bit + drafter q4, Mac): accept-len
    /// 5.02 / 3.29 / 6.24 / 3.57 on these four prompts. The Swift port adds the 32K sub-head
    /// (drafts outside just reject) so slight deltas are expected — the gate is the BAND
    /// (mean accept ≥ 2.5 across prompts = the port is faithful), plus e2e tok/s vs plain.
    func testDFlashSwiftPortGateB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DFLASH_TEST"] == "1" else {
            throw XCTSkip("set BAS_DFLASH_TEST=1 (heavy — loads Qwen3.5-4B + DFlash drafter)")
        }
        let dURL = URL(fileURLWithPath: "/tmp/gdn_coreai/dflash_draft/model.safetensors")
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let prompts = [
            "How many prime numbers are there between 10 and 50? Think step by step.",
            "Describe a quiet morning in a mountain village.",
            "What is 23 multiplied by 17? Show your reasoning.",
            "Explain what a tide pool is to a curious child.",
        ]
        struct R: Sendable {
            let accPerIter: Double; let eTok: Double; let dfTps: Double; let plainTps: Double
        }
        var accs: [Double] = []
        for q in prompts {
            let input = try await container.prepare(input: UserInput(chat: [.user(q)]))
            let r: R = try await container.perform(nonSendable: input) { ctx, input in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35DFlashDecoder(model: qwen, draftWeightsURL: dURL)
                let mtp = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let ids = input.text.tokens.asArray(Int.self)
                let run = dec.generateDFlash(prompt: ids, maxTokens: 256, eosTokens: eos)
                let plain = mtp.generatePlain(prompt: ids, maxTokens: 256)
                let a = run.iterations > 0 ? Double(run.accepted) / Double(run.iterations) : 0
                let e = run.iterations > 0 ? Double(run.tokens.count) / Double(run.iterations) : 0
                return R(accPerIter: a, eTok: e,
                         dfTps: Double(run.tokens.count) / max(run.decodeSeconds, 0.001),
                         plainTps: Double(plain.tokens.count) / max(plain.decodeSeconds, 0.001))
            }
            accs.append(r.accPerIter)
            print(String(format: "=== F5 %@ acc/cycle=%.2f E[tok]/cycle=%.2f dflash=%.1f plain=%.1f ratio=%.2fx ===",
                         String(q.prefix(40)), r.accPerIter, r.eTok, r.dfTps, r.plainTps,
                         r.dfTps / max(r.plainTps, 0.001)))
        }
        let mean = accs.reduce(0, +) / Double(accs.count)
        print(String(format: "=== F5 MEAN accept=%.2f (python-ref band 3.3-6.2) ===", mean))
        XCTAssertGreaterThan(mean, 2.5, "Swift port acceptance collapsed vs the Python reference — port bug")
    }

    /// F6 — B5 KV persistence gate (BAS_KV_PERSIST_TEST=1): snapshot a ~1.2K-token session cache,
    /// restore into a fresh cache, and measure (a) warm-restore vs cold-re-prefill TTFT and
    /// (b) 48-token greedy continuation fidelity vs the live cache (Q4 attention-KV is lossy;
    /// GDN state is stored raw so divergence should be attention-tie-break class only).
    func testKVPersistRoundtripAndTTFT() async throws {
        guard ProcessInfo.processInfo.environment["BAS_KV_PERSIST_TEST"] == "1" else {
            throw XCTSkip("set BAS_KV_PERSIST_TEST=1 (heavy — loads Qwen3.5-4B)")
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let story = String(repeating: "The expedition crossed the ridge before dawn, keeping the river to the east and the storm at their backs. ", count: 55)
        let input = try await container.prepare(input: UserInput(chat: [
            .user(story + "\n\nSummarize the expedition's route in one sentence.")]))
        struct R: Sendable {
            let histLen: Int; let coldMs: Double; let saveMs: Double; let restoreMs: Double
            let bytes: Int; let match: Int; let n: Int
        }
        let r: R = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let ids = input.text.tokens.asArray(Int.self)
            let url = URL(fileURLWithPath: "/tmp/gdn_coreai/kv_session_test.safetensors")
            func greedy(_ cache: [KVCache], seed: Int, n: Int) -> [Int] {
                var out: [Int] = []
                var tok = seed
                for _ in 0 ..< n {
                    let h = qwen.hiddenStatesWithCache(
                        MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache)
                    tok = argMax(qwen.logits(fromHidden: h)[0, 0], axis: -1).item(Int.self)
                    out.append(tok)
                }
                return out
            }
            // 1. cold prefill (the thing warm-restore replaces) + seed token
            let cache1 = qwen.newCache(parameters: nil)
            let t0 = Date()
            let h0 = qwen.hiddenStatesWithCache(
                MLXArray(ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache1)
            let seed = argMax(qwen.logits(fromHidden: h0)[0, h0.dim(1) - 1], axis: -1).item(Int.self)
            let coldMs = Date().timeIntervalSince(t0) * 1000
            // 2. snapshot BEFORE continuing (in-place buffer contract)
            let q4 = ProcessInfo.processInfo.environment["BAS_KV_PERSIST_Q4"] == "1"
            let tS = Date()
            let bytes = try BASSessionKVStore.save(cache: cache1, tokenCount: ids.count, to: url,
                                                   quantizeKV: q4)
            let saveMs = Date().timeIntervalSince(tS) * 1000
            // 3. live continuation (the fidelity reference)
            let live = greedy(cache1, seed: seed, n: 48)
            // 4. restore into a fresh cache (timed INCLUSIVE of GPU materialization)
            let cache2 = qwen.newCache(parameters: nil)
            let tR = Date()
            _ = try BASSessionKVStore.restore(into: cache2, from: url)
            for c in cache2 { eval(c.innerState()) }
            let restoreMs = Date().timeIntervalSince(tR) * 1000
            let warm = greedy(cache2, seed: seed, n: 48)
            let match = zip(live, warm).prefix(while: ==).count
            return R(histLen: ids.count, coldMs: coldMs, saveMs: saveMs, restoreMs: restoreMs,
                     bytes: bytes, match: match, n: 48)
        }
        print(String(format: "=== F6 hist=%dtok cold_prefill=%.0fms save=%.0fms restore=%.0fms (%.1fx) file=%.1fMB match=%d/%d ===",
                     r.histLen, r.coldMs, r.saveMs, r.restoreMs, r.coldMs / max(r.restoreMs, 0.001),
                     Double(r.bytes) / 1e6, r.match, r.n))
        XCTAssertGreaterThan(r.match, 24, "restored-cache continuation diverged early — persistence bug (Q4 tie-breaks tolerated)")
        XCTAssertLessThan(r.restoreMs, r.coldMs, "restore must beat cold re-prefill")
    }
}
