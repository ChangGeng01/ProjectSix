// BASQwen35DFlashDecoder — M1 Gate-b: the DFlash block-diffusion drafter (z-lab Qwen3.5-4B-DFlash,
// 0.6B/6-layer) ported onto our production loop mechanics (FRONTIER_2026H2 M1; Gate-a PASS Mac:
// accept-len 3.2-6.2 per 16-block on this exact target, drafter 4-bit ≈ zero acceptance cost).
//
// Algorithm (pinned by 3-impl cross-validation — z-lab torch+mlx, bstnxbt, Aryagm):
//   • block = [anchor] + 15×mask(248077), embedded via the TARGET's table (checkpoint has no embed).
//   • h_ctx = rmsNorm_hidden(fc(concat of 8 target layer-OUTPUT taps [1,5,9,13,17,21,25,29])) —
//     computed once per cycle for the NEW rows only, KV-projected per drafter layer and APPENDED
//     to a growing per-layer ctx-KV cache (rows = every stream token before the current anchor).
//   • per layer: Q from block only; K/V = [ctx-cache ; block]; RoPE ctx@rowPos, q+block@blockPos;
//     sliding layers (0-4) causal-within-block, full layer (5) bidirectional; ONE forward, 15 drafts
//     via the target lm-head family (our 32K quantized sub-head — a wrong draft just rejects; the
//     emission stream stays the trunk's own argmaxes, ADR-039 lossless / 满血).
//   • verify = ONE trunk forward over [pending ++ 15 drafts] with taps captured — the SAME
//     pending/snapshot-restore/packed-cumprod-readback mechanics as generateSpecKFused (GDN
//     non-trimmable ⇒ snapshot-restore + pending carry; no crop, no capture-replay needed).
//
// Device economics note: the verify is T≥16 ⇒ always the qmm regime on the phone (the qmv cliff is
// paid ONCE per ~4-7 accepted tokens instead of never — amortized; Gate-c measures the net).
import Foundation
#if canImport(MLXLLM)
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

public final class BASQwen35DFlashDecoder {

    public enum DFlashError: Error { case missingWeights(String) }

    static let blockSize = 16
    static let maskToken: Int32 = 248077
    static let tapLayers = [1, 5, 9, 13, 17, 21, 25, 29]
    static let nLayers = 6, nHeads = 32, nKV = 8, hd = 128, hidden = 2560
    static let slidingLayers = 5                       // layers 0-4 sliding, layer 5 full
    static let ropeBase: Float = 10_000_000
    /// Draft head rows. UNLIKE the MTP lane (per-LINK head reads ⇒ 32K sub-head mandatory), the
    /// DFlash head runs once per 16-token CYCLE — the full quantized vocab (248320×2560 q4 ≈318MB
    /// ≈20MB/token amortized) is affordable and avoids sub-head acceptance loss on rarer tokens.
    let draftVocab: Int

    struct QW { let w: MLXArray; let s: MLXArray; let b: MLXArray? }
    struct Layer {
        let qp, kp, vp, op, gw, uw, dw: QW
        let iln, pln, qn, kn: MLXArray
    }

    let model: Qwen35Model
    let fcW: QW
    let hiddenNorm: MLXArray
    let finalNorm: MLXArray
    let layers: [Layer]
    let subHead: QW
    // Drafter ctx-KV cache: per layer, rows for every stream token before the current anchor.
    var ctxK: [MLXArray?] = Array(repeating: nil, count: nLayers)
    var ctxV: [MLXArray?] = Array(repeating: nil, count: nLayers)
    var ctxLen = 0                                     // == absolute stream position covered

    public init(model: Qwen35Model, draftWeightsURL: URL, draftVocab: Int = 248320) throws {
        self.model = model
        self.draftVocab = draftVocab
        let a = try MLX.loadArrays(url: draftWeightsURL)
        func need(_ k: String) throws -> MLXArray {
            guard let t = a[k] else { throw DFlashError.missingWeights(k) }
            return t.asType(.float16)
        }
        // Drafter norms are HF-plain (model_type qwen3) — used RAW (no +1 shift, unlike the
        // vendored target's zero-centered sanitize; the Python reference loads them as-is).
        func q4(_ k: String) throws -> QW {
            let (wq, sc, bi) = MLX.quantized(try need(k), groupSize: 64, bits: 4)
            return QW(w: wq, s: sc, b: bi)
        }
        fcW = try q4("fc.weight")
        hiddenNorm = try need("hidden_norm.weight")
        finalNorm = try need("norm.weight")
        var ls: [Layer] = []
        for i in 0 ..< Self.nLayers {
            let p = "layers.\(i)."
            ls.append(Layer(
                qp: try q4(p + "self_attn.q_proj.weight"),
                kp: try q4(p + "self_attn.k_proj.weight"),
                vp: try q4(p + "self_attn.v_proj.weight"),
                op: try q4(p + "self_attn.o_proj.weight"),
                gw: try q4(p + "mlp.gate_proj.weight"),
                uw: try q4(p + "mlp.up_proj.weight"),
                dw: try q4(p + "mlp.down_proj.weight"),
                iln: try need(p + "input_layernorm.weight"),
                pln: try need(p + "post_attention_layernorm.weight"),
                qn: try need(p + "self_attn.q_norm.weight"),
                kn: try need(p + "self_attn.k_norm.weight")))
        }
        layers = ls
        let subRows = model.embedding(MLXArray((0 ..< draftVocab).map(Int32.init)))
        let (hw, hs, hb) = MLX.quantized(subRows, groupSize: 64, bits: 4)
        subHead = QW(w: hw, s: hs, b: hb)
    }

    func mm(_ x: MLXArray, _ w: QW) -> MLXArray {
        quantizedMatmul(x, w.w, scales: w.s, biases: w.b, transpose: true, groupSize: 64, bits: 4)
    }
    private func rms(_ x: MLXArray, _ w: MLXArray) -> MLXArray {
        MLXFast.rmsNorm(x, weight: w, eps: 1e-6)
    }
    private func rope(_ t: MLXArray, offset: Int) -> MLXArray {
        // t: [L, H, hd] → RoPE over full head_dim (theta 1e7, non-traditional), positions offset..
        MLXFast.RoPE(t.transposed(1, 0, 2), dimensions: Self.hd, traditional: false,
                     base: Self.ropeBase, scale: 1, offset: offset).transposed(1, 0, 2)
    }

    public func resetStream() {
        ctxK = Array(repeating: nil, count: Self.nLayers)
        ctxV = Array(repeating: nil, count: Self.nLayers)
        ctxLen = 0
    }

    /// Fuse NEW target-tap rows and append their K/V to every drafter layer's ctx cache.
    /// `taps`: 8×[1, T, 2560] from the trunk forward; rows `fromRow ..< toRow` are new AND REAL —
    /// rows for rejected drafts must never enter ctx (their features were computed from WRONG
    /// input tokens; the correction token re-enters via pending and gets its row next cycle).
    func appendCtx(taps: [MLXArray], fromRow: Int, toRow: Int) {
        guard fromRow < toRow else { return }
        let slices = taps.map { $0[0, fromRow ..< toRow] }             // 8×[S_new, 2560]
        let hCtx = rms(mm(concatenated(slices, axis: -1), fcW), hiddenNorm)   // [S_new, 2560]
        let sNew = hCtx.dim(0)
        for l in 0 ..< Self.nLayers {
            let L = layers[l]
            var k = mm(hCtx, L.kp).reshaped(sNew, Self.nKV, Self.hd)
            k = rope(rms(k, L.kn), offset: ctxLen)
            let v = mm(hCtx, L.vp).reshaped(sNew, Self.nKV, Self.hd)
            ctxK[l] = ctxK[l].map { concatenated([$0, k], axis: 0) } ?? k
            ctxV[l] = ctxV[l].map { concatenated([$0, v], axis: 0) } ?? v
        }
        ctxLen += sNew
    }

    /// ONE drafter forward: block [anchor]+15 masks at absolute positions blockStart..+15 →
    /// 15 GPU-resident draft ids (sub-head argmax; positions 1..15 of the block).
    func draftBlock(anchor: MLXArray, blockStart: Int) -> MLXArray {
        let ids = concatenated([anchor.reshaped([1]).asType(.int32),
                                MLXArray(Array(repeating: Self.maskToken, count: Self.blockSize - 1))])
        var h = model.embedding(ids)                                   // [16, 2560]
        let ctxT = ctxLen
        // Additive mask [16, ctx+16]: ctx fully visible; block causal for sliding layers.
        let zerosCtx = MLXArray.zeros([Self.blockSize, ctxT], dtype: .float32)
        let blockCausal = MLX.triu(MLXArray.full([Self.blockSize, Self.blockSize],
                                                 values: MLXArray(-Float.infinity)), k: 1)
            .asType(.float32)
        let slidingMask = concatenated([zerosCtx, blockCausal], axis: 1)
        for (l, L) in layers.enumerated() {
            let x = rms(h, L.iln)
            var q = mm(x, L.qp).reshaped(Self.blockSize, Self.nHeads, Self.hd)
            q = rope(rms(q, L.qn), offset: blockStart)
            var kB = mm(x, L.kp).reshaped(Self.blockSize, Self.nKV, Self.hd)
            kB = rope(rms(kB, L.kn), offset: blockStart)
            let vB = mm(x, L.vp).reshaped(Self.blockSize, Self.nKV, Self.hd)
            let K = ctxK[l].map { concatenated([$0, kB], axis: 0) } ?? kB
            let V = ctxV[l].map { concatenated([$0, vB], axis: 0) } ?? vB
            let qq = q.asType(.float32).transposed(1, 0, 2).expandedDimensions(axis: 0)
            let kk = K.asType(.float32).transposed(1, 0, 2).expandedDimensions(axis: 0)
            let vv = V.asType(.float32).transposed(1, 0, 2).expandedDimensions(axis: 0)
            let mask: MLXFast.ScaledDotProductAttentionMaskMode =
                l < Self.slidingLayers ? .array(slidingMask) : .none
            let attn = MLXFast.scaledDotProductAttention(
                queries: qq, keys: kk, values: vv,
                scale: powf(Float(Self.hd), -0.5), mask: mask)[0]      // [32, 16, 128]
            let o = attn.transposed(1, 0, 2).reshaped(Self.blockSize, -1).asType(.float16)
            h = h + mm(o, L.op)
            let z = rms(h, L.pln)
            h = h + mm(silu(mm(z, L.gw)) * mm(z, L.uw), L.dw)
        }
        let logits = mm(rms(h, finalNorm), subHead)                    // [16, 32K]
        return argMax(logits[1...], axis: -1).asType(.int32)           // [15]
    }

    /// DFlash speculative decode — generateSpecKFused's loop with the block drafter.
    /// Emission semantics identical (prefill argmax emitted; every token = trunk argmax).
    public func generateDFlash(
        prompt: [Int], maxTokens: Int, eosTokens: Set<Int> = []
    ) -> BASQwen35MTPSpecDecoder.Run {
        resetStream()
        let cache = model.newCache(parameters: nil)
        let (h0, taps0) = model.hiddenStatesWithTaps(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0),
            cache: cache, tapLayers: Self.tapLayers)
        appendCtx(taps: taps0, fromRow: 0, toRow: prompt.count)
        var trunkLen = prompt.count
        var pending: [Int] = [argmaxLast(model.logits(fromHidden: h0))]
        var vBase = prompt.count                        // absolute position of pending[0]
        var out: [Int] = []
        var acceptedTok = 0, iters = 0, hitEOS = false
        func emit(_ tok: Int) -> Bool {
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < maxTokens
        }
        _ = emit(pending[0])
        let t0 = Date()
        while out.count < maxTokens && !hitEOS {
            // 1. Draft 15 from the block anchored at pending.last (position vBase+|pending|-1).
            let anchor = MLXArray(Int32(pending.last!))
            let ds = draftBlock(anchor: anchor, blockStart: vBase + pending.count - 1)
            // 2. Snapshot (GDN restore-by-reference; FA trim) — the MTP-lane mechanics verbatim.
            var snapshots: [(ArraysCache, MLXArray?, MLXArray?)] = []
            for c in cache where c is ArraysCache {
                let m = c as! ArraysCache
                snapshots.append((m, m[0], m[1]))
            }
            let P = pending.count
            let T = P + Self.blockSize - 1
            let input = concatenated([MLXArray(pending.map(Int32.init)), ds])
                .expandedDimensions(axis: 0)
            let (h2, taps) = model.hiddenStatesWithTaps(input, cache: cache, tapLayers: Self.tapLayers)
            let lg = model.logits(fromHidden: h2)
            let am = argMax(lg[0], axis: -1).asType(.int32)            // [T]
            let truth = am[(P - 1) ..< (P - 1 + Self.blockSize - 1)]
            let match = (truth .== ds).asType(.int32)
            let lAcc = cumprod(match, axis: 0).sum(keepDims: false)
            let packed = concatenated([lAcc.reshaped([1]), am])
            let host = packed.asArray(Int32.self)                      // the ONE sync per cycle
            let L = Int(host[0])
            let amH = host[1 ... T].map(Int.init)
            iters += 1
            acceptedTok += L
            var emitted: [Int] = []
            if L == Self.blockSize - 1 {
                emitted = Array(amH[(P - 1) ..< (P - 1 + L)]) + [amH[T - 1]]
            } else {
                emitted = Array(amH[(P - 1) ..< (P - 1 + L)]) + [amH[P - 1 + L]]
            }
            var stop = false
            for e in emitted where !stop { stop = !emit(e) }
            // 3. Drafter ctx: append taps for input rows not yet covered (positions ≥ ctxLen),
            // REAL rows only — full accept: all T inputs; reject: pending + accepted prefix
            // (row P-1+L carries the REJECTED draft's feature — excluded, re-fed next cycle).
            let validRows = L == Self.blockSize - 1 ? T : P + L
            appendCtx(taps: taps, fromRow: ctxLen - vBase, toRow: validRows)
            if stop { break }
            if L == Self.blockSize - 1 {
                trunkLen += T
                pending = [emitted.last!]
                vBase = trunkLen
            } else {
                for (m, s0, s1) in snapshots { m[0] = s0; m[1] = s1 }
                for c in cache where !(c is ArraysCache) { _ = c.trim(T) }
                pending.append(contentsOf: emitted)
                // vBase unchanged — pending still starts at the same absolute position.
            }
        }
        return BASQwen35MTPSpecDecoder.Run(
            tokens: out, decodeSeconds: Date().timeIntervalSince(t0),
            accepted: acceptedTok, iterations: iters)
    }

    func argmaxLast(_ logits: MLXArray) -> Int {
        argMax(logits[0, logits.dim(1) - 1], axis: -1).item(Int.self)
    }
}
#endif
