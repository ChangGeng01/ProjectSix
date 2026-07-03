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
//   • GREEDY-ONLY (argmax verify ⇒ token stream identical to plain greedy — byte-safe by construction; the
//     identity is asserted by BASQwen35MTPSpecTests and the device probe).
import Foundation
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

public final class BASQwen35MTPSpecDecoder {

    public enum SpecError: Error { case missingWeights(String), notQwen35 }

    private let model: Qwen35Model
    // MTP head weights (fp16, norms pre-folded to plain)
    private let fc, qp, kp, vp, op, gw, uw, dw: MLXArray
    private let iln, pln, qn, kn, nE, nH, fnW: MLXArray
    // MTP block KV (own stream; fixed-capacity, index-written like the trunk's spec assets)
    private var mtpK: MLXArray
    private var mtpV: MLXArray
    private static let maxSeq = 1024
    private static let ah = 16, akv = 4, ahd = 256, rd = 64
    private static let ropeBase: Float = 10_000_000

    public init(model: Qwen35Model, mtpWeightsURL: URL) throws {
        self.model = model
        let a = try MLX.loadArrays(url: mtpWeightsURL)
        func need(_ k: String) throws -> MLXArray {
            guard let t = a[k] else { throw SpecError.missingWeights(k) }
            return t
        }
        fc = try need("mtp_fc_weight")
        qp = try need("mtp_layers_0_self_attn_q_proj_weight")
        kp = try need("mtp_layers_0_self_attn_k_proj_weight")
        vp = try need("mtp_layers_0_self_attn_v_proj_weight")
        op = try need("mtp_layers_0_self_attn_o_proj_weight")
        gw = try need("mtp_layers_0_mlp_gate_proj_weight")
        uw = try need("mtp_layers_0_mlp_up_proj_weight")
        dw = try need("mtp_layers_0_mlp_down_proj_weight")
        iln = try need("mtp_layers_0_input_layernorm_weight")
        pln = try need("mtp_layers_0_post_attention_layernorm_weight")
        qn = try need("mtp_layers_0_self_attn_q_norm_weight")
        kn = try need("mtp_layers_0_self_attn_k_norm_weight")
        nE = try need("mtp_pre_fc_norm_embedding_weight")
        nH = try need("mtp_pre_fc_norm_hidden_weight")
        fnW = try need("mtp_norm_weight")
        mtpK = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
        mtpV = MLXArray.zeros([Self.maxSeq, Self.akv, Self.ahd], dtype: .float16)
    }

    // MARK: - MTP forward (draft hidden for ONE step; own KV stream at `pos`)

    private func rms(_ x: MLXArray, _ w: MLXArray? = nil) -> MLXArray {
        var y = x * rsqrt(mean(x.asType(.float32) * x.asType(.float32), axis: -1, keepDims: true) + 1e-6)
            .asType(.float16)
        if let w { y = y * w }
        return y
    }

    private func rope(_ t: MLXArray, pos: Int) -> MLXArray {
        // NeoX partial rotary: first 64 of 256 dims, base 1e7. t: [H, 256].
        let half = Self.rd / 2
        let inv = MLXArray(stride(from: 0, to: Self.rd, by: 2).map {
            powf(Self.ropeBase, -Float($0) / Float(Self.rd))
        })
        let ang = (Float(pos) * inv).asType(.float16)
        let cosA = cos(ang), sinA = sin(ang)
        let tr = t[0..., 0 ..< Self.rd]
        let tp = t[0..., Self.rd...]
        let x1 = tr[0..., 0 ..< half], x2 = tr[0..., half...]
        return concatenated(
            [concatenated([x1 * cosA - x2 * sinA, x1 * sinA + x2 * cosA], axis: -1), tp], axis: -1)
    }

    /// draft hidden [D] from (embed(next) [D], trunk post-norm hidden [D]); writes this step's K/V at `pos`.
    func mtpForward(embedNext: MLXArray, hidden: MLXArray, pos: Int) -> MLXArray {
        let u = matmul(concatenated([rms(embedNext, nE), rms(hidden, nH)]), fc.T)
        let h = rms(u, iln)
        let qpo = matmul(h, qp.T).reshaped(Self.ah, 2 * Self.ahd)
        var q = qpo[0..., 0 ..< Self.ahd]
        let gate = qpo[0..., Self.ahd...].reshaped(-1)
        var k = matmul(h, kp.T).reshaped(Self.akv, Self.ahd)
        let v = matmul(h, vp.T).reshaped(Self.akv, Self.ahd)
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
        var y = u + matmul(out, op.T)
        let z = rms(y, pln)
        y = y + matmul(silu(matmul(z, gw.T)) * matmul(z, uw.T), dw.T)
        return rms(y, fnW)
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
    }

    private func argmaxLast(_ logits: MLXArray) -> Int {
        // logits [1, T, V] → argmax of the LAST row
        let last = logits[0, logits.dim(1) - 1]
        return argMax(last, axis: -1).item(Int.self)
    }

    /// Plain greedy decode (the A/B baseline; identical bookkeeping to the spec loop).
    public func generatePlain(prompt: [Int], maxTokens: Int) -> Run {
        let cache = model.newCache(parameters: nil)
        var h = model.hiddenStatesWithCache(MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var nxt = argmaxLast(model.logits(fromHidden: h))
        eval(MLXArray(Int32(nxt)))
        let t0 = Date()
        var out: [Int] = []
        while out.count < maxTokens {
            h = model.hiddenStatesWithCache(MLXArray([Int32(nxt)]).expandedDimensions(axis: 0), cache: cache)
            nxt = argmaxLast(model.logits(fromHidden: h))
            eval(MLXArray(Int32(nxt)))
            out.append(nxt)
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: 0, iterations: out.count)
    }

    /// K=1 MTP speculative greedy decode. Token stream is greedy-identical by construction (argmax verify).
    public func generateSpec(prompt: [Int], maxTokens: Int) -> Run {
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        var pos = prompt.count
        var h = model.hiddenStatesWithCache(MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var hLast = h[0, h.dim(1) - 1]
        var nxt = argmaxLast(model.logits(fromHidden: h))
        var d = argmaxLast(model.logits(
            fromHidden: mtpForward(embedNext: model.embedding(MLXArray([Int32(nxt)]))[0], hidden: hLast, pos: pos - 1)
                .expandedDimensions(axes: [0, 1])))
        eval(MLXArray(Int32(d)))
        let t0 = Date()
        var out: [Int] = []
        var accepted = 0, iters = 0
        while out.count < maxTokens {
            // snapshot: MambaCache = retain its 2 array refs (arrays are immutable → free); FA = trim-on-reject
            var snapshots: [(ArraysCache, MLXArray?, MLXArray?)] = []
            for c in cache {
                if let m = c as? ArraysCache { snapshots.append((m, m[0], m[1])) }
            }
            let h2 = model.hiddenStatesWithCache(
                MLXArray([Int32(nxt), Int32(d)]).expandedDimensions(axis: 0), cache: cache)
            let lg2 = model.logits(fromHidden: h2)             // [1, 2, V]
            let true2 = argMax(lg2[0, 0], axis: -1).item(Int.self)
            iters += 1
            if true2 == d {
                accepted += 1
                let em = argMax(lg2[0, 1], axis: -1).item(Int.self)
                out.append(true2)
                if out.count < maxTokens { out.append(em) }
                nxt = em
                hLast = h2[0, 1]
                pos += 2
            } else {
                for (m, s0, s1) in snapshots { m[0] = s0; m[1] = s1 }
                for c in cache where !(c is ArraysCache) { _ = c.trim(2) }
                let h1 = model.hiddenStatesWithCache(
                    MLXArray([Int32(nxt)]).expandedDimensions(axis: 0), cache: cache)
                out.append(true2)
                nxt = true2
                hLast = h1[0, 0]
                pos += 1
            }
            d = argmaxLast(model.logits(
                fromHidden: mtpForward(embedNext: model.embedding(MLXArray([Int32(nxt)]))[0], hidden: hLast, pos: pos - 1)
                    .expandedDimensions(axes: [0, 1])))
            eval(MLXArray(Int32(d)))
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: accepted, iterations: iters)
    }
}
