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
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

public final class BASQwen35MTPSpecDecoder {

    public enum SpecError: Error { case missingWeights(String), notQwen35 }

    private let model: Qwen35Model
    // MTP linears quantized 4-bit at init (device: 240MB fp16 ≈ 4.8ms/draft at ~50GB/s → 4-bit ≈ 1.2ms);
    // norms stay fp16 (pre-folded to plain).
    private struct QW { let w, s: MLXArray; let b: MLXArray? }
    private let fc, qp, kp, vp, op, gw, uw, dw: QW
    private let iln, pln, qn, kn, nE, nH, fnW: MLXArray
    private let invFreq: MLXArray                      // rope table, computed ONCE
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
        func q4(_ k: String) throws -> QW {
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

    private func mm(_ x: MLXArray, _ w: QW) -> MLXArray {
        quantizedMatmul(x, w.w, scales: w.s, biases: w.b, transpose: true, groupSize: 64, bits: 4)
    }

    private func rope(_ t: MLXArray, pos: Int) -> MLXArray {
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

    /// K=1 MTP speculative greedy decode with CARRY-FORWARD REJECT: certain-but-uncommitted tokens ride a
    /// `pending` queue into the NEXT verify forward (the vendored T-cost curve is flat: T=1 14.9ms vs T=4 16.6ms,
    /// so re-feeding pending costs ~nothing) — no separate refeed forward on reject. Token stream is
    /// greedy-identical by construction (every emission is a trunk argmax).
    /// Test-only: force every draft to be wrong (isolates reject-path bookkeeping; identity must STILL hold).
    public var forceRejectForDiagnostics = false

    public func generateSpec(prompt: [Int], maxTokens: Int) -> Run {
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        var hLast = h0[0, h0.dim(1) - 1]
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count
        var pending: [Int] = [argmaxLast(model.logits(fromHidden: h0))]
        var d = argmaxLast(model.logits(
            fromHidden: mtpForward(
                embedNext: model.embedding(MLXArray([Int32(pending[0])]))[0], hidden: hLast, pos: hLastPos)
                .expandedDimensions(axes: [0, 1])))
        if forceRejectForDiagnostics { d = 0 }
        eval(MLXArray(Int32(d)))
        let t0 = Date()
        var out: [Int] = []
        var accepted = 0, iters = 0
        while out.count < maxTokens {
            // pending-cap safety: commit a long reject run without a draft (rare at a≈0.86)
            if pending.count >= 4 {
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
                d = argmaxLast(model.logits(
                    fromHidden: mtpForward(
                        embedNext: model.embedding(MLXArray([Int32(t)]))[0], hidden: hLast, pos: hLastPos)
                        .expandedDimensions(axes: [0, 1])))
                continue
            }
            var snapshots: [(ArraysCache, MLXArray?, MLXArray?)] = []
            for c in cache where c is ArraysCache {
                let m = c as! ArraysCache
                snapshots.append((m, m[0], m[1]))
            }
            let input = pending + [d]
            let T = input.count
            let h2 = model.hiddenStatesWithCache(
                MLXArray(input.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
            let lg = model.logits(fromHidden: h2)                     // [1, T, V]
            let trueD = argMax(lg[0, T - 2], axis: -1).item(Int.self) // truth for d's slot
            iters += 1
            if trueD == d {
                accepted += 1
                let em = argMax(lg[0, T - 1], axis: -1).item(Int.self)
                out.append(trueD)
                if out.count < maxTokens { out.append(em) }
                trunkLen += T                                          // committed (pending + d in state)
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [em]
            } else {
                for (m, s0, s1) in snapshots { m[0] = s0; m[1] = s1 }
                for c in cache where !(c is ArraysCache) { _ = c.trim(T) }
                out.append(trueD)
                hLast = h2[0, T - 2]                                   // hidden after the last CERTAIN token
                hLastPos = trunkLen + T - 2                            // its absolute position (state rolled back)
                pending.append(trueD)
            }
            d = argmaxLast(model.logits(
                fromHidden: mtpForward(
                    embedNext: model.embedding(MLXArray([Int32(pending.last!)]))[0], hidden: hLast, pos: hLastPos)
                    .expandedDimensions(axes: [0, 1])))
            if forceRejectForDiagnostics { d = 0 }
            eval(MLXArray(Int32(d)))
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0), accepted: accepted, iterations: iters)
    }
}
