// BASQwen35MTPSpecDecoder — K=1 MTP speculative decoding for the MAIN model (Qwen3.5-4B, GDN hybrid).
//
// The production Qwen3.5 lane has ZERO speculative decoding today (the vendored draft-model path fails closed on
// GDN's non-trimmable MambaCache; the shipped 1.46× greedy lane is Llama-only). Qwen3.5 ships its own 1-layer MTP
// (multi-token-prediction) head in the ORIGINAL checkpoint (stripped by mlx conversions — fetched separately via
// Tools/qwen35_fetch_mtp.py → qwen35_mtp_folded.safetensors, zero-centered norms PRE-FOLDED to plain (1+w)).
// Bench-proven at production precision (Tools/qwen35_mtp_gpu.py, Mac GPU 4-bit): 84 → 120.6 tok/s = 1.44×,
// live acceptance a≈0.88, greedy-identity 64/64.
//
// DESIGN — zero vendored-kernel changes (opt-in lane; V1/default paths untouched, ADR-014):
//   • 2-token verify forward `[next, draft]` through the PUBLIC `hiddenStatesWithCache` accessor — one weight
//     read for both tokens (the bandwidth amortization that pays for everything).
//   • GDN can't rollback (nonTrimmableCache) → SNAPSHOT-RESTORE: MLX arrays are immutable, so snapshotting a
//     MambaCache is just retaining its two array references (FREE); restore = assigning them back. FA layers use
//     KVCacheSimple.trim(2). On reject: restore + re-feed the accepted token (T=1) — at a≈0.88 the reject
//     penalty costs ≈(1−a)≈0.12 extra forwards/iter: speedup ≈ (1+a)/(1+f+(1−a)) ≈ 1.4×.
//   • GREEDY-ONLY, ADR-039 LOSSLESS bar: EVERY emitted token is, by construction, the trunk's own argmax from
//     the forward that produced it — a legitimate greedy decode. It is NOT asserted bit-identical to the serial
//     T=1 stream: the vendored GDN multi-token forward is not batch-invariant at fp16, so near-tie argmaxes can
//     legitimately break differently (measured: rare tie-flips, e.g. the 14/220 pair; same class the suffix
//     probe handles via its STRICT/LOSSLESS dual gate). Divergence-from-serial is reported as telemetry.
import Foundation
import BASRuntimeCore
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

public final class BASQwen35MTPSpecDecoder {

    public enum SpecError: Error { case missingWeights(String), notQwen35 }

    let model: Qwen35Model
    // MTP linears quantized 4-bit at init (device: 240MB fp16 ≈ 4.8ms/draft at ~50GB/s → 4-bit ≈ 1.2ms);
    // norms stay fp16 (pre-folded to plain).
    /// s == nil ⇒ UNQUANTIZED fp16 head (M3 A/B arm only — production stays 4-bit).
    struct QW { let w: MLXArray; let s: MLXArray?; let b: MLXArray? }
    let fc, qp, kp, vp, op, gw, uw, dw: QW
    let iln, pln, qn, kn, nE, nH, fnW: MLXArray
    let invFreq: MLXArray                      // rope table, computed ONCE
    // DRAFT SUB-HEAD (quality-neutral): drafts argmax over the FIRST 32K vocab rows only (BPE ids ≈ frequency
    // order; device full-head = ~6.4ms/draft at ~50GB/s vs ~0.8ms for 32K). A true-argmax outside 32K just makes
    // that draft wrong → rejected → emissions remain FULL-vocab trunk argmaxes (ADR-039 lossless, 满血).
    static let draftVocab = 32768
    let subHead: QW
    /// Deep-K chain: next-step embed rows gathered from a RESIDENT 8K fp16 table inside the ONE compiled chain
    /// graph (drafts restricted to the 8K most-frequent ids; misses just reject — lossless/满血 unchanged).
    private static let chainVocab = 8192
    private lazy var chainEmbed: MLXArray =
        model.embedding(MLXArray((0 ..< Self.chainVocab).map(Int32.init)))   // [8K, D] fp16 (deep-K only)
    /// Adaptive-K regime EMA (fused chain) — persists across turns like the decoder itself; 1.6 = optimistic
    /// cold start (K=3, settles within ~3 rounds of the FIRST turn only).
    var chainEmaL: Double = 1.6
    // MTP block KV (own stream; fixed-capacity, index-written like the trunk's spec assets)
    var mtpK: MLXArray
    var mtpV: MLXArray
    static let maxSeq = 2048  // MTP-stream KV bound (buffers 2×8MB fp16); production prompt+gen cap
    static let ah = 16, akv = 4, ahd = 256, rd = 64

    /// audit mlx-decode MED-1 (complete) — the MTP KV buffers are fixed `[maxSeq]`, and a draft at
    /// `pos` (a `width`-wide chain writes positions `pos … pos+width-1`) writes `mtpK[pos] = k`, so
    /// the positions MUST all stay `< maxSeq` or the write OVERRUNS the buffer. Every drafting lane
    /// (sampling / greedy / chain / compiled) checks this before calling `mtpForward`/`mtpForwardCompiled`
    /// and degrades to a plain trunk step when the stream is full (the model's own cache carries the
    /// longer context) instead of overrunning. Pure + Mac-testable. b81490202 fixed only the fused
    /// chain's draft WIDTH; this closes the per-position WRITE bound on every lane.
    static func mtpStreamHasRoom(pos: Int, width: Int = 1) -> Bool {
        pos >= 0 && pos + width <= maxSeq
    }
    static let ropeBase: Float = 10_000_000

    /// `headFP16` — M3 A/B arm: keep the native MTP linears + draft sub-head UNQUANTIZED fp16
    /// (≈3× draft bandwidth vs the production 4-bit; the A/B asks whether quantizing the head
    /// costs acceptance). Default false = the certified production decoder, bit-unchanged.
    public init(model: Qwen35Model, mtpWeightsURL: URL, headFP16: Bool = false) throws {
        self.model = model
        let a = try MLX.loadArrays(url: mtpWeightsURL)
        func need(_ k: String) throws -> MLXArray {
            guard let t = a[k] else { throw SpecError.missingWeights(k) }
            return t
        }
        func q4(_ k: String) throws -> QW {
            if headFP16 { return QW(w: try need(k), s: nil, b: nil) }
            let (wq, sc, bi) = MLX.quantized(try need(k), groupSize: 64, bits: 4)
            return QW(w: wq, s: sc, b: bi)
        }
        fc = try q4("mtp_fc_weight")
        qp = try q4("mtp_layers_0_self_attn_q_proj_weight")
        kp = try q4("mtp_layers_0_self_attn_k_proj_weight")
        vp = try q4("mtp_layers_0_self_attn_v_proj_weight")
        op = try q4("mtp_layers_0_self_attn_o_proj_weight")
        gw = try q4("mtp_layers_0_mlp_gate_proj_weight")
        uw = try q4("mtp_layers_0_mlp_up_proj_weight")
        dw = try q4("mtp_layers_0_mlp_down_proj_weight")
        iln = try need("mtp_layers_0_input_layernorm_weight")
        pln = try need("mtp_layers_0_post_attention_layernorm_weight")
        qn = try need("mtp_layers_0_self_attn_q_norm_weight")
        kn = try need("mtp_layers_0_self_attn_k_norm_weight")
        nE = try need("mtp_pre_fc_norm_embedding_weight")
        nH = try need("mtp_pre_fc_norm_hidden_weight")
        fnW = try need("mtp_norm_weight")
        invFreq = MLXArray(stride(from: 0, to: Self.rd, by: 2).map {
            powf(Self.ropeBase, -Float($0) / Float(Self.rd))
        })
        let subRows = model.embedding(MLXArray((0 ..< Self.draftVocab).map(Int32.init)))   // [32K, D] fp16
        if headFP16 {
            subHead = QW(w: subRows, s: nil, b: nil)
        } else {
            let (hw, hs, hb) = MLX.quantized(subRows, groupSize: 64, bits: 4)
            subHead = QW(w: hw, s: hs, b: hb)
        }
        // chainEmbed moved to a lazy property (experimental deep-K only) — production K=1 skips its 42MB.
        mtpK = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
        mtpV = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
    }

    /// Draft-only argmax over the 32K sub-head (returns a GPU-resident scalar; no sync).
    func draftArgmax(_ y: MLXArray) -> MLXArray {
        argMax(mm(y.expandedDimensions(axis: 0), subHead)[0], axis: -1)
    }

    // MARK: - MTP forward (draft hidden for ONE step; own KV stream at `pos`)

    func rms(_ x: MLXArray, _ w: MLXArray? = nil) -> MLXArray {
        var y = x * rsqrt(mean(x.asType(.float32) * x.asType(.float32), axis: -1, keepDims: true) + 1e-6)
            .asType(.float16)
        if let w { y = y * w }
        return y
    }

    func mm(_ x: MLXArray, _ w: QW) -> MLXArray {
        guard let s = w.s else { return matmul(x, w.w.transposed(1, 0)) }   // fp16 A/B arm
        return quantizedMatmul(x, w.w, scales: s, biases: w.b, transpose: true, groupSize: 64, bits: 4)
    }

    func rope(_ t: MLXArray, pos: Int) -> MLXArray {
        // NeoX partial rotary: first 64 of 256 dims, base 1e7. t: [H, 256].
        let half = Self.rd / 2
        let ang = (Float(pos) * invFreq).asType(.float16)
        let cosA = cos(ang), sinA = sin(ang)
        let tr = t[0..., 0 ..< Self.rd]
        let tp = t[0..., Self.rd...]
        let x1 = tr[0..., 0 ..< half], x2 = tr[0..., half...]
        return concatenated(
            [concatenated([x1 * cosA - x2 * sinA, x1 * sinA + x2 * cosA], axis: -1), tp], axis: -1)
    }

    /// draft hidden [D] from (embed(next) [D], trunk post-norm hidden [D]); writes this step's K/V at `pos`.
    ///
    /// ⚠️ KEEP the hand-rolled body — a fusedLink delegation was TRIED and REVERTED (全面修复 2026-07-04):
    /// the lean MLXFast/SDPA numerics (G1 cos 0.993→0.966) cost the SAMPLING lane ~0.13 acceptance on
    /// device (a 0.72→0.59 < its 0.60 break-even floor ⇒ the lane would self-gate OFF). Temperature
    /// sampling's min(1,p/q) is far more sensitive to q drift than greedy argmax (the chain lanes keep
    /// lean fusedLink — F1 proves draft-argmax exactness there). This fat body is the REFERENCE numerics
    /// the sampling lane's floor and measured 1.05× were calibrated against.
    func mtpForward(embedNext: MLXArray, hidden: MLXArray, pos: Int) -> MLXArray {
        let u = mm(concatenated([rms(embedNext, nE), rms(hidden, nH)]).expandedDimensions(axis: 0), fc)[0]
        let h = rms(u, iln)
        let qpo = mm(h.expandedDimensions(axis: 0), qp)[0].reshaped(Self.ah, 2 * Self.ahd)
        var q = qpo[0..., 0 ..< Self.ahd]
        let gate = qpo[0..., Self.ahd...].reshaped(-1)
        var k = mm(h.expandedDimensions(axis: 0), kp)[0].reshaped(Self.akv, Self.ahd)
        let v = mm(h.expandedDimensions(axis: 0), vp)[0].reshaped(Self.akv, Self.ahd)
        q = rope(rms(q, qn), pos: pos)
        k = rope(rms(k, kn), pos: pos)
        mtpK[pos] = k
        mtpV[pos] = v
        let kk = mtpK[0 ..< (pos + 1)].asType(.float32)   // [p+1, 4, 256]
        let vv = mtpV[0 ..< (pos + 1)].asType(.float32)
        // GQA scores: q [16,256] vs kv heads repeated 4×
        let kkR = repeated(kk, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)  // [16, p+1, 256]
        let vvR = repeated(vv, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)
        let sc = matmul(q.asType(.float32).expandedDimensions(axis: 1), kkR.transposed(0, 2, 1))
            * powf(Float(Self.ahd), -0.5)                 // [16, 1, p+1]
        let out = matmul(softmax(sc, axis: -1), vvR).reshaped(-1).asType(.float16) * sigmoid(gate)
        var y = u + mm(out.expandedDimensions(axis: 0), op)[0]
        let z = rms(y, pln)
        let zz = z.expandedDimensions(axis: 0)
        y = y + mm(silu(mm(zz, gw)) * mm(zz, uw), dw)[0]
        return rms(y, fnW)
    }

    /// ⚠️ SUPERSEDED by the fused chain (BASQwen35MTPSpecDecoder+FusedChain.swift) — kept for the probe-era
    /// BAS_MTP_K sequential baseline only; do NOT extend. The qmv T≥6 cliff (not this code) was the real
    /// historical deep-K killer.
    /// COMPILED fixed-shape draft — used ONLY by the deep-K chain (generateSpecK), where per-step Swift
    /// graph-build/launch (~43ms/draft measured on device, sequential-dependent so it can't hide in verify
    /// bubbles) dwarfs the fixed-shape full-buffer-attention penalty (~5ms) that made this a NET LOSS for K=1.
    private lazy var compiledDraft: @Sendable ([MLXArray]) -> [MLXArray] = {
        let idx = MLXArray((0 ..< Self.maxSeq).map { Float16($0) })
        let scale = MLXArray(Float16(powf(Float(Self.ahd), -0.5)))
        return compile { [self] args in
            let emb = args[0], hid = args[1], pos = args[2], kb = args[3], vb = args[4]
            let u = mm(concatenated([rms(emb, nE), rms(hid, nH)]).expandedDimensions(axis: 0), fc)[0]
            let h = rms(u, iln)
            let qpo = mm(h.expandedDimensions(axis: 0), qp)[0].reshaped(Self.ah, 2 * Self.ahd)
            var q = qpo[0..., 0 ..< Self.ahd]
            let gate = qpo[0..., Self.ahd...].reshaped(-1)
            var k = mm(h.expandedDimensions(axis: 0), kp)[0].reshaped(Self.akv, Self.ahd)
            let v = mm(h.expandedDimensions(axis: 0), vp)[0].reshaped(Self.akv, Self.ahd)
            q = rms(q, qn); k = rms(k, kn)
            let ang = (pos.asType(.float32) * invFreq).asType(.float16)
            let cosA = cos(ang), sinA = sin(ang)
            let half = Self.rd / 2
            func rope(_ t: MLXArray) -> MLXArray {
                let tr = t[0..., 0 ..< Self.rd]
                let tp = t[0..., Self.rd...]
                let x1 = tr[0..., 0 ..< half], x2 = tr[0..., half...]
                return concatenated(
                    [concatenated([x1 * cosA - x2 * sinA, x1 * sinA + x2 * cosA], axis: -1), tp], axis: -1)
            }
            q = rope(q); k = rope(k)
            let oh = (idx .== pos).asType(.float16).reshaped(Self.maxSeq, 1, 1)
            let kbN = kb * (1 - oh) + oh * k.expandedDimensions(axis: 0)
            let vbN = vb * (1 - oh) + oh * v.expandedDimensions(axis: 0)
            let kk = repeated(kbN, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)
            let vv = repeated(vbN, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)
            var sc = matmul(q.expandedDimensions(axis: 1), kk.transposed(0, 2, 1)) * scale
            let mask = (idx .<= pos).reshaped(1, 1, Self.maxSeq)
            sc = which(mask, sc.asType(.float32), MLXArray(Float(-1e30)))
            let w = softmax(sc, axis: -1).asType(.float16)
            let out = matmul(w, vv).reshaped(-1) * sigmoid(gate)
            var y = u + mm(out.expandedDimensions(axis: 0), op)[0]
            let z = rms(y, pln)
            let zz = z.expandedDimensions(axis: 0)
            y = y + mm(silu(mm(zz, gw)) * mm(zz, uw), dw)[0]
            return [rms(y, fnW), kbN, vbN]
        }
    }()

    /// ⚠️ SUPERSEDED by the fused lazy chain — kept as the compile-approach record; do NOT extend.
    /// WHOLE-CHAIN compiled draft (K unrolled in ONE graph → ONE submission per iteration): each step =
    /// MTP block → 4-bit sub-head argmax (8K rows) → gather next embed from the resident table. Outputs
    /// [d0..d4] + updated KV. Fixes the measured 43ms/step sequential-submission wall.
    private lazy var compiledChain5: @Sendable ([MLXArray]) -> [MLXArray] = {
        let idx = MLXArray((0 ..< Self.maxSeq).map { Float16($0) })
        let scale = MLXArray(Float16(powf(Float(Self.ahd), -0.5)))
        return compile { [self] args in
            let e0 = args[0], h0 = args[1], pos0 = args[2]
            var kb = args[3], vb = args[4]
            var e = e0, h = h0
            var ds: [MLXArray] = []
            for j in 0 ..< 5 {
                let pos = pos0 + Float16(j)
                let u = mm(concatenated([rms(e, nE), rms(h, nH)]).expandedDimensions(axis: 0), fc)[0]
                let hh = rms(u, iln)
                let qpo = mm(hh.expandedDimensions(axis: 0), qp)[0].reshaped(Self.ah, 2 * Self.ahd)
                var q = qpo[0..., 0 ..< Self.ahd]
                let gate = qpo[0..., Self.ahd...].reshaped(-1)
                var k = mm(hh.expandedDimensions(axis: 0), kp)[0].reshaped(Self.akv, Self.ahd)
                let v = mm(hh.expandedDimensions(axis: 0), vp)[0].reshaped(Self.akv, Self.ahd)
                q = rms(q, qn); k = rms(k, kn)
                let ang = (pos.asType(.float32) * invFreq).asType(.float16)
                let cosA = cos(ang), sinA = sin(ang)
                let half = Self.rd / 2
                func rope(_ t: MLXArray) -> MLXArray {
                    let tr = t[0..., 0 ..< Self.rd]
                    let tp = t[0..., Self.rd...]
                    let x1 = tr[0..., 0 ..< half], x2 = tr[0..., half...]
                    return concatenated(
                        [concatenated([x1 * cosA - x2 * sinA, x1 * sinA + x2 * cosA], axis: -1), tp], axis: -1)
                }
                q = rope(q); k = rope(k)
                let oh = (idx .== pos).asType(.float16).reshaped(Self.maxSeq, 1, 1)
                kb = kb * (1 - oh) + oh * k.expandedDimensions(axis: 0)
                vb = vb * (1 - oh) + oh * v.expandedDimensions(axis: 0)
                let kk = repeated(kb, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)
                let vv = repeated(vb, count: Self.ah / Self.akv, axis: 1).transposed(1, 0, 2)
                var sc = matmul(q.expandedDimensions(axis: 1), kk.transposed(0, 2, 1)) * scale
                let mask = (idx .<= pos).reshaped(1, 1, Self.maxSeq)
                sc = which(mask, sc.asType(.float32), MLXArray(Float(-1e30)))
                let w = softmax(sc, axis: -1).asType(.float16)
                let out = matmul(w, vv).reshaped(-1) * sigmoid(gate)
                var y = u + mm(out.expandedDimensions(axis: 0), op)[0]
                let z = rms(y, pln)
                let zz = z.expandedDimensions(axis: 0)
                y = y + mm(silu(mm(zz, gw)) * mm(zz, uw), dw)[0]
                y = rms(y, fnW)
                // in-graph draft: 8K-constrained sub-head argmax + embed gather for the next step
                let lg = mm(y.expandedDimensions(axis: 0), subHead)[0][0 ..< Self.chainVocab]
                let dj = argMax(lg, axis: -1)
                ds.append(dj)
                e = chainEmbed[dj]
                h = y
            }
            return ds + [kb, vb]
        }
    }()

    /// Chain-step draft via the compiled graph (deep-K path only).
    private func mtpForwardCompiled(embedNext: MLXArray, hidden: MLXArray, pos: Int) -> MLXArray {
        let r = compiledDraft([embedNext, hidden, MLXArray([Float16(pos)]), mtpK, mtpV])
        mtpK = r[1]
        mtpV = r[2]
        return r[0]
    }

    public func resetMTPStream() {
        mtpK = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
        mtpV = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
    }

    // MARK: - Generation (plain vs spec share prefill + emission bookkeeping for identity comparison)

    public struct Run {
        public let tokens: [Int]
        public let decodeSeconds: Double
        public let accepted: Int
        public let iterations: Int
        /// 缝5 (2026-07-06 audit): TRUE proposed-draft-token count. The profiler's emaHitRate is
        /// accepted/proposed — folding rounds as "proposed" put the fused lane's hit-rate on a
        /// 0-3 scale in the same ledger as the model-free lanes' ≤1 scale (three currencies, one
        /// floor). 0 = the lane predates the field / proposes nothing (plain).
        public let proposed: Int
        /// B3 trace early-exit: non-nil iff the stop rule fired this run (fused lane, opt-in).
        public let traceExit: BASTraceExitTelemetry?

        init(tokens: [Int], decodeSeconds: Double, accepted: Int, iterations: Int,
             proposed: Int = 0, traceExit: BASTraceExitTelemetry? = nil) {
            self.tokens = tokens
            self.decodeSeconds = decodeSeconds
            self.accepted = accepted
            self.iterations = iterations
            self.proposed = proposed
            self.traceExit = traceExit
        }
    }

    func argmaxLast(_ logits: MLXArray) -> Int {
        // logits [1, T, V] → argmax of the LAST row
        let last = logits[0, logits.dim(1) - 1]
        return argMax(last, axis: -1).item(Int.self)
    }

    /// Plain greedy decode (the A/B baseline; identical bookkeeping to the spec loop).
    /// With the defaults this is TOKEN-IDENTICAL to the historical probe loop (no EOS, no policy —
    /// the A/B baselines pin it). `eosTokens`/`traceExit` make it the PRODUCTION thermal fallback
    /// for session lanes (缝1, 2026-07-06): at serious+ the certified design is plain decode, but
    /// capped turns must keep the B3 answer guarantee — so the plain loop carries the same
    /// BASTraceExitPolicy + packed argmax+entropy readback as the fused lane. Force-close here is
    /// simpler than fused (no verify round in flight to unwind): inject the close sequence into the
    /// output and feed it together with the pending token in ONE multi-token forward (same lossless
    /// forward class — every emitted token remains the trunk's own argmax, ADR-039).
    public func generatePlain(
        prompt: [Int], maxTokens: Int, eosTokens: Set<Int> = [],
        traceExit: BASTraceExitConfig? = nil
    ) -> Run {
        let cache = model.newCache(parameters: nil)
        // Primed-in-think scan over the PROMPT — identical to the fused lane's (:128): template
        // variants pre-open `<think>`, so the policy must start in-think or the budget guard is dead.
        var tracePolicy: BASTraceExitPolicy? = traceExit.map { cfg in
            let lastOpen = prompt.lastIndex(of: cfg.thinkOpenToken)
            let lastClose = prompt.lastIndex(of: cfg.thinkCloseToken)
            let primed = lastOpen.map { oi in lastClose.map { $0 < oi } ?? true } ?? false
            return BASTraceExitPolicy(config: cfg, primedInThink: primed)
        }
        var traceTel: BASTraceExitTelemetry? = nil
        var out: [Int] = []
        var hitEOS = false
        func emit(_ tok: Int) -> Bool {
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < maxTokens
        }
        // Packed argmax+entropy single readback while the policy is live (the fused lane's
        // determinism idiom — every emitted token carries entropy, or none do after the latch).
        func argmaxAndEntropy(_ lastRow: MLXArray) -> (tok: Int, ent: Int?) {
            guard tracePolicy != nil, !(tracePolicy?.closed ?? true) else {
                return (argMax(lastRow, axis: -1).item(Int.self), nil)
            }
            let lf = lastRow.asType(.float32)
            let pr = softmax(lf, axis: -1)
            let ent = -(pr * log(pr + 1e-9)).sum(keepDims: false)
            let packed = concatenated([argMax(lastRow, axis: -1).reshaped([1]).asType(.int32),
                                       (ent * 1000).asType(.int32).reshaped([1])])
            let host = packed.asArray(Int32.self)
            return (Int(host[0]), Int(host[1]))
        }
        var h = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var (tok, ent) = argmaxAndEntropy(model.logits(fromHidden: h)[0, h.dim(1) - 1])
        let t0 = Date()
        var feed: [Int] = [tok]                   // emitted-but-not-yet-fed tokens
        var stop = !emit(tok)                     // first generated token included (production semantics)
        while !stop && !hitEOS {
            if tracePolicy != nil, let cfg = traceExit,
               case .close(let reason)? = tracePolicy?.observe(
                   token: tok, entropyMillinats: ent, outCount: out.count, maxTokens: maxTokens) {
                tracePolicy?.markForcedClose()
                traceTel = BASTraceExitTelemetry(
                    reason: reason, thinkTokensAtExit: tracePolicy?.thinkTokens ?? 0,
                    outCountAtExit: out.count)
                for t in cfg.closeSequence where !stop { stop = !emit(t) }
                if stop { break }                 // budget died mid-injection
                feed += cfg.closeSequence         // pending token + injected close: ONE forward below
            }
            h = model.hiddenStatesWithCache(
                MLXArray(feed.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
            (tok, ent) = argmaxAndEntropy(model.logits(fromHidden: h)[0, h.dim(1) - 1])
            feed = [tok]
            stop = !emit(tok)
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: 0,
                   iterations: out.count, traceExit: traceTel)
    }

    /// Generalized K-deep MTP speculative decode (chained GPU-resident drafts, ONE verify forward of
    /// T = pending+K, prefix-accept, carry-forward). SUSTAINED-throughput lever: under the thermal power cap the
    /// objective is BYTES/TOKEN — E[tok]/iter grows with K while the trunk is still read ONCE per iter
    /// (measured chain acceptance: a2..a4 = 1.0, depth-5 survival 0.91 on the golden trajectory).
    public func generateSpecK(prompt: [Int], maxTokens: Int, k: Int) -> Run {
        precondition(k >= 1)
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var hLast = h0[0, h0.dim(1) - 1]
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count
        var pending: [Int] = [argmaxLast(model.logits(fromHidden: h0))]
        func draftChain() -> [MLXArray] {
            // audit mlx-decode MED-1: no room for a k-wide chain in the MTP KV buffer ⇒ no draft
            // (the caller plain-steps on an empty ds). Prevents mtpForwardCompiled writing out of bounds.
            guard Self.mtpStreamHasRoom(pos: hLastPos, width: k) else { return [] }
            if k == 5 {
                let r = compiledChain5([
                    model.embedding(MLXArray([Int32(pending.last!)]))[0], hLast,
                    MLXArray([Float16(hLastPos)]), mtpK, mtpV,
                ])
                mtpK = r[5]; mtpV = r[6]
                return Array(r[0 ..< 5])
            }
            var ds: [MLXArray] = []
            var y = hLast
            var e = model.embedding(MLXArray([Int32(pending.last!)]))[0]
            for j in 0 ..< k {
                y = mtpForwardCompiled(embedNext: e, hidden: y, pos: hLastPos + j)
                let dj = draftArgmax(y)
                ds.append(dj)
                if j + 1 < k { e = model.embedding(dj.reshaped([1]))[0] }
            }
            return ds
        }
        var ds = draftChain()
        let t0 = Date()
        var out: [Int] = []
        var acceptedTok = 0, iters = 0, proposedTok = 0
        while out.count < maxTokens {
            // audit mlx-decode MED-1: an empty ds means the MTP buffer is full — plain-step (the
            // verify path below assumes ds has exactly k elements, so it must NOT run empty).
            if pending.count >= 6 || ds.isEmpty {
                var hp = model.hiddenStatesWithCache(
                    MLXArray([Int32(pending[0])]).expandedDimensions(axis: 0), cache: cache)
                for p in pending.dropFirst() {
                    hp = model.hiddenStatesWithCache(
                        MLXArray([Int32(p)]).expandedDimensions(axis: 0), cache: cache)
                }
                trunkLen += pending.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let t = argmaxLast(model.logits(fromHidden: hp))
                out.append(t); pending = [t]
                ds = draftChain()
                continue
            }
            let checkpoint = BASTrunkCheckpoint(cache: cache)   // 案1: the ONE snapshot owner
            let P = pending.count
            let T = P + k
            var parts: [MLXArray] = [MLXArray(pending.map(Int32.init))]
            parts.append(contentsOf: ds.map { $0.reshaped([1]).asType(.int32) })
            let input = concatenated(parts).expandedDimensions(axis: 0)
            let h2 = model.hiddenStatesWithCache(input, cache: cache)
            let lg = model.logits(fromHidden: h2)
            let am = argMax(lg[0], axis: -1)                       // [T]
            var evalSet: [MLXArray] = [am]; evalSet.append(contentsOf: ds)
            eval(evalSet)                                          // the ONE gpu sync
            let dv = ds.map { $0.item(Int.self) }
            iters += 1
            proposedTok += dv.count   // gaps-recon 2026-07-11: TRUE drafted-token count (see Run below)
            // prefix-accept: d[j]'s slot truth = am[P-1+j]
            var L = 0
            while L < k && am[P - 1 + L].item(Int.self) == dv[L] { L += 1 }
            acceptedTok += L
            // emissions: truths am[P-1 .. P-1+min(L, k-1)] — L accepted (== drafts) + correction (if L<k)
            // full accept (L==k): also the bonus token after d[k-1]
            var emitted: [Int] = []
            if L == k {
                for j in 0 ..< k { emitted.append(dv[j]) }
                emitted.append(am[T - 1].item(Int.self))           // bonus
            } else {
                for j in 0 ..< L { emitted.append(dv[j]) }
                emitted.append(am[P - 1 + L].item(Int.self))       // correction
            }
            for e in emitted where out.count < maxTokens { out.append(e) }
            if L == k {
                trunkLen += T
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [emitted.last!]
            } else {
                guard checkpoint.restore(cache: cache, trimming: T) else {
                    BASDiagnosticLog.emit("[spec] trim under-returned — fail-close (emitted tokens are all trunk argmaxes)")
                    break
                }
                hLast = h2[0, P - 1 + L]                            // hidden after the last CORRECT fed token
                hLastPos = trunkLen + P - 1 + L
                pending.append(contentsOf: emitted)
            }
            ds = draftChain()
        }
        // gaps-reconciliation NEW finding (2026-07-11, adversarial-verify byproduct): this lane
        // reported proposed:iters while drafting k tokens per verify round — accepted (≤k/round)
        // could EXCEED proposed, inverting the profiler's emaHitRate contract (缝5) if anyone ever
        // wired this diagnostic lane. Report the true drafted count (plain-step rounds draft 0).
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0),
                   accepted: acceptedTok, iterations: iters, proposed: proposedTok)
    }

    /// K=1 MTP speculative greedy decode with CARRY-FORWARD REJECT: certain-but-uncommitted tokens ride a
    /// `pending` queue into the NEXT verify forward (the vendored T-cost curve is flat: T=1 14.9ms vs T=4 16.6ms,
    /// so re-feeding pending costs ~nothing) — no separate refeed forward on reject. Token stream is
    /// greedy-identical by construction (every emission is a trunk argmax).
    /// Test-only: force every draft to be wrong (isolates reject-path bookkeeping; identity must STILL hold).
    public var forceRejectForDiagnostics = false

    // MARK: - LOSSLESS SPEC-SAMPLING (temperature > 0) — the production-preset lane (scout 0.1 / core 0.7)
    //
    // Standard rejection-sampling speculative decoding (Leviathan/Chen): draft d ~ q, accept with
    // min(1, p(d)/q(d)); on reject emit r ~ normalize(max(0, p − q)). The OUTPUT distribution is exactly p —
    // the target's production sampling distribution — for ANY draft q (q only affects SPEED via the acceptance
    // rate). p replicates the vendored TopPSampler transform bit-for-bit: top-p masks the UN-tempered
    // log-softmax, temperature divides after, categorical normalizes (Evaluate.swift:263-298).

    /// Testable core: given target logits (full vocab), draft logprobs (sub-vocab), the sampled draft id and
    /// u ~ U(0,1), return (accepted, residualLogits) where residualLogits are `log(max(0, p − q))` over the FULL
    /// vocab (−inf where zero) ready for `categorical`. Pure function of its inputs (unit-tested exactly).
    static func samplingVerdict(
        targetLogits: MLXArray, draftLogprobsSub: MLXArray, draftVocab: Int,
        temperature: Float, topP: Float, draftId: Int, u: Float
    ) -> (accepted: Bool, residualLogits: MLXArray) {
        var lp = logSoftmax(targetLogits.asType(.float32))
        if topP > 0 && topP < 1 {                       // vendored applyTopP (mask BEFORE temperature)
            let sortedIndices = argSort(lp, axis: -1)
            let sortedLp = takeAlong(lp, sortedIndices, axis: -1)
            let cum = cumsum(exp(sortedLp), axis: -1)
            let filtered = MLX.where(cum .> (1 - topP), sortedLp, MLXArray(-Float.infinity))
            lp = putAlong(lp, sortedIndices, values: filtered, axis: -1)
        }
        let p = softmax(lp * (1 / temperature), axis: -1)                 // full-vocab target distribution
        let q = softmax(draftLogprobsSub.asType(.float32) * (1 / temperature), axis: -1)  // sub-vocab draft dist
        let pd = p[draftId].item(Float.self)
        let qd = q[draftId].item(Float.self)
        if qd > 0, u < min(1, pd / max(qd, 1e-30)) {
            return (true, MLXArray(0))
        }
        // residual = max(0, p − q) over full vocab (q occupies the first `draftVocab` ids)
        var residual = p
        let head = maximum(p[0 ..< draftVocab] - q, MLXArray(Float(0)))
        residual = concatenated([head, p[draftVocab...]], axis: -1)
        return (false, log(residual + 1e-30))
    }

    /// Lossless spec-sampling generation (production presets; distribution-equal to plain sampling, NOT
    /// byte-equal — sampling is stochastic). Carry-forward reject identical to the greedy lane.
    public func generateSpecSampling(
        prompt: [Int], maxTokens: Int, eosTokens: Set<Int>,
        temperature: Float, topP: Float
    ) -> Run {
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var hLast = h0[0, h0.dim(1) - 1]
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count

        func sampleTarget(_ logits: MLXArray) -> Int {   // EXACT production transform + categorical
            var lp = logSoftmax(logits.asType(.float32))
            if topP > 0 && topP < 1 {
                let si = argSort(lp, axis: -1)
                let sl = takeAlong(lp, si, axis: -1)
                let cum = cumsum(exp(sl), axis: -1)
                let filtered = MLX.where(cum .> (1 - topP), sl, MLXArray(-Float.infinity))
                lp = putAlong(lp, si, values: filtered, axis: -1)
            }
            return categorical(lp * (1 / temperature)).item(Int.self)
        }
        func draftSample() -> (id: Int, qLogprobsSub: MLXArray) {
            let y = mtpForward(
                embedNext: model.embedding(MLXArray([Int32(pendingTail)]))[0], hidden: hLast, pos: hLastPos)
            let subLogits = mm(y.expandedDimensions(axis: 0), subHead)[0]
            let qlp = logSoftmax(subLogits.asType(.float32))
            let id = categorical(qlp * (1 / temperature)).item(Int.self)
            return (id, qlp)
        }

        var pending: [Int] = [sampleTarget(model.logits(fromHidden: h0)[0, h0.dim(1) - 1])]
        var pendingTail: Int { pending.last! }
        let t0 = Date()
        var out: [Int] = []
        var accepted = 0, iters = 0
        var hitEOS = false
        func emit(_ tok: Int) -> Bool {
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < maxTokens
        }
        _ = emit(pending[0])
        while out.count < maxTokens && !hitEOS {
            // audit mlx-decode MED-1: when the MTP KV buffer is full (pos ≥ maxSeq), take the plain
            // trunk step instead of drafting — draftSample would write mtpK[hLastPos] out of bounds.
            if pending.count >= 4 || !Self.mtpStreamHasRoom(pos: hLastPos) {
                // ONE multi-token forward (全面修复 — see the K=1 lane's identical fix; distribution
                // semantics unchanged: the sample still comes from the trunk's own last-position logits).
                let hp = model.hiddenStatesWithCache(
                    MLXArray(pending.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                trunkLen += pending.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let t = sampleTarget(model.logits(fromHidden: hp)[0, hp.dim(1) - 1])
                if !emit(t) { break }
                pending = [t]
                continue
            }
            let checkpoint = BASTrunkCheckpoint(cache: cache)   // 案1: the ONE snapshot owner
            let (dId, qlp) = draftSample()
            let T = pending.count + 1
            let input = MLXArray((pending + [dId]).map(Int32.init)).expandedDimensions(axis: 0)
            let h2 = model.hiddenStatesWithCache(input, cache: cache)
            let lg = model.logits(fromHidden: h2)
            iters += 1
            let u = Float.random(in: 0 ..< 1)
            let verdict = Self.samplingVerdict(
                targetLogits: lg[0, T - 2], draftLogprobsSub: qlp, draftVocab: Self.draftVocab,
                temperature: temperature, topP: topP, draftId: dId, u: u)
            if verdict.accepted {
                accepted += 1
                let bonus = sampleTarget(lg[0, T - 1])              // genuine p-sample at the next position
                if emit(dId) { _ = emit(bonus) }
                trunkLen += T
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [bonus]
            } else {
                guard checkpoint.restore(cache: cache, trimming: T) else {
                    BASDiagnosticLog.emit("[spec] trim under-returned — fail-close (emitted tokens are all trunk argmaxes)")
                    break
                }
                let r = categorical(verdict.residualLogits).item(Int.self)   // r ~ normalize(max(0, p − q))
                _ = emit(r)
                hLast = h2[0, T - 2]
                hLastPos = trunkLen + T - 2
                pending.append(r)
            }
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: accepted, iterations: iters, proposed: iters)
    }

    /// Production entry: EOS-aware (stops BEFORE emitting an eos token — matching the plain lanes' semantics).
    public func generateSpec(prompt: [Int], maxTokens: Int, eosTokens: Set<Int>) -> Run {
        _generateSpec(prompt: prompt, maxTokens: maxTokens, eosTokens: eosTokens)
    }

    public func generateSpec(prompt: [Int], maxTokens: Int) -> Run {
        _generateSpec(prompt: prompt, maxTokens: maxTokens, eosTokens: [])
    }

    private func _generateSpec(prompt: [Int], maxTokens: Int, eosTokens: Set<Int>) -> Run {
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var hLast = h0[0, h0.dim(1) - 1]
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count
        var pending: [Int] = [argmaxLast(model.logits(fromHidden: h0))]
        // audit mlx-decode MED-1: guard every mtpForward draft with the KV-buffer bound. When full,
        // use a dummy (never verified — a full buffer always routes to the plain-cap branch below).
        var d = Self.mtpStreamHasRoom(pos: hLastPos)
            ? draftArgmax(mtpForward(
                embedNext: model.embedding(MLXArray([Int32(pending[0])]))[0], hidden: hLast, pos: hLastPos))
            : MLXArray(Int32(0))
        if forceRejectForDiagnostics { d = MLXArray(Int32(0)) }
        let t0 = Date()
        var out: [Int] = []
        var accepted = 0, iters = 0
        var hitEOS = false
        func emit(_ tok: Int) -> Bool {          // false = stop (eos hit or budget reached); eos NOT emitted
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < maxTokens
        }
        // FIRST generated token (the prefill argmax) is part of the stream (production semantics — the earlier
        // probe convention skipped it symmetrically in both arms; the wiring E2E caught the mismatch vs streaming).
        _ = emit(pending[0])
        while out.count < maxTokens && !hitEOS {
            // pending-cap safety: commit a long reject run without a draft (rare at a≈0.86).
            // audit mlx-decode MED-1: also plain-step when the MTP buffer is full (no room to draft).
            if pending.count >= 4 || !Self.mtpStreamHasRoom(pos: hLastPos) {
                // ONE multi-token forward (全面修复: the one-token-at-a-time loop here was deep-K killer #2 —
                // P×~16ms/refeed; same forward class as the verify feed ⇒ same ADR-039 lossless family).
                let hp = model.hiddenStatesWithCache(
                    MLXArray(pending.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                trunkLen += pending.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let t = argmaxLast(model.logits(fromHidden: hp))
                if !emit(t) { break }
                pending = [t]
                d = Self.mtpStreamHasRoom(pos: hLastPos)
                    ? draftArgmax(mtpForward(
                        embedNext: model.embedding(MLXArray([Int32(t)]))[0], hidden: hLast, pos: hLastPos))
                    : MLXArray(Int32(0))
                continue
            }
            let checkpoint = BASTrunkCheckpoint(cache: cache)   // 案1: the ONE snapshot owner
            let T = pending.count + 1
            let input = concatenated([
                MLXArray(pending.map(Int32.init)), d.reshaped([1]).asType(.int32),
            ]).expandedDimensions(axis: 0)
            let h2 = model.hiddenStatesWithCache(input, cache: cache)
            let lg = model.logits(fromHidden: h2)                     // [1, T, V]
            let am = argMax(lg[0], axis: -1)                          // [T] all-row argmaxes
            eval(am, d)                                               // the ONE gpu sync per iteration
            let dv = d.item(Int.self)
            let trueD = am[T - 2].item(Int.self)                      // truth for d's slot
            iters += 1
            if trueD == dv {
                accepted += 1
                let em = am[T - 1].item(Int.self)
                if emit(trueD) { _ = emit(em) }
                trunkLen += T                                          // committed (pending + d in state)
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [em]
            } else {
                guard checkpoint.restore(cache: cache, trimming: T) else {
                    BASDiagnosticLog.emit("[spec] trim under-returned — fail-close (emitted tokens are all trunk argmaxes)")
                    break
                }
                _ = emit(trueD)
                hLast = h2[0, T - 2]                                   // hidden after the last CERTAIN token
                hLastPos = trunkLen + T - 2                            // its absolute position (state rolled back)
                pending.append(trueD)
            }
            d = Self.mtpStreamHasRoom(pos: hLastPos)
                ? draftArgmax(mtpForward(
                    embedNext: model.embedding(MLXArray([Int32(pending.last!)]))[0], hidden: hLast, pos: hLastPos))
                : MLXArray(Int32(0))   // audit MED-1: full buffer ⇒ dummy (next iter plain-steps)
            if forceRejectForDiagnostics { d = MLXArray(Int32(0)) }
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: accepted, iterations: iters, proposed: iters)
    }
}
