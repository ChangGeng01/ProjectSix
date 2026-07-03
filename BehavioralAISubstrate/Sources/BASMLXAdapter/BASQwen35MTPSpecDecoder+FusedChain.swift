// BASQwen35MTPSpecDecoder+FusedChain — the deep-K draft chain rebuilt as ONE lazy graph (the sustained-30
// lever: under the thermal power cap the SoC is bytes-bound, so E[tok]/trunk-read is the 1:1 sustained
// multiplier — K=1 ships 1.85, the chain statistics measured E[tok]≈3.35 at K=5 on device).
//
// Why the previous deep-K attempts lost (campaign record) and what this one changes:
//   • naive per-link chain (43ms/step device): fresh Swift graph build + per-link submission gaps.
//   • per-step compiled (12.6ms/step Mac): K separate compiled submissions.
//   • whole-chain compile (Mac 0.45×, reverted, never device-tested): fixed-shape tax — each link rewrote
//     BOTH full [2048,4,256] KV buffers through a one-hot blend and materialized `repeated` GQA copies
//     (~50MB traffic/link), because compile demands static shapes.
//   THIS lane: NO compile at all. Recon (vendored mlx 0.31.1, compile.cpp/transforms.cpp) established that
//   lazy chaining pays no per-call boundary eval — one eval schedules the whole K-link graph in a single
//   CPU pass with pipelined command buffers (iPhone commits every 20 ops — tune MLX_MAX_OPS_PER_BUFFER).
//   Lazy = dynamic shapes are legal, so each link attends a DYNAMIC slice of committed KV + the chain's own
//   in-flight k/v (no buffer rewrite, no `repeated`: MLXFast.scaledDotProductAttention handles GQA natively).
//   The chain's k/v are committed to mtpK/mtpV in ONE batched range-write per round — bit-identical
//   post-round state to the sequential path (which writes every link's slot pre-verify).
//
// ADR-039 unchanged: emissions are read EXCLUSIVELY from the trunk's own argmax vector `am` (the accepted
// prefix equals the drafts by definition of the match test, so drafts never need a readback at all).
import Foundation
#if canImport(MLXLLM)
import MLX          // MLXFast (scaledDotProductAttention et al.) lives inside the MLX module in this vendor
import MLXNN
import MLXLLM
import MLXLMCommon

extension BASQwen35MTPSpecDecoder {

    /// One chain link: the MTP block with attention over `baseK/baseV` (committed slice, shared across the
    /// chain) ++ this chain's earlier links ++ self. Math mirrors `mtpForward` exactly (same rms/rope/gate);
    /// `fp32Scores` reproduces the production K=1 lane's fp32 QKᵀ+softmax semantics (acceptance was
    /// measured there; fp16 scores only shift tie-breaks — acceptance-, never correctness-relevant).
    /// Returns (draft hidden, k, v) — k/v are NOT scattered here (the round batch-commits them).
    func fusedLink(
        embedNext: MLXArray, hidden: MLXArray, pos: Int,
        baseK: MLXArray, baseV: MLXArray, chainK: [MLXArray], chainV: [MLXArray],
        fp32Scores: Bool
    ) -> (y: MLXArray, k: MLXArray, v: MLXArray) {
        let u = mm(concatenated([rms(embedNext, nE), rms(hidden, nH)]).expandedDimensions(axis: 0), fc)[0]
        let h = rms(u, iln)
        let qpo = mm(h.expandedDimensions(axis: 0), qp)[0].reshaped(Self.ah, 2 * Self.ahd)
        var q = qpo[0..., 0 ..< Self.ahd]
        let gate = qpo[0..., Self.ahd...].reshaped(-1)
        var k = mm(h.expandedDimensions(axis: 0), kp)[0].reshaped(Self.akv, Self.ahd)
        let v = mm(h.expandedDimensions(axis: 0), vp)[0].reshaped(Self.akv, Self.ahd)
        q = rope(rms(q, qn), pos: pos)
        k = rope(rms(k, kn), pos: pos)
        // keys/values seen by this link: committed [0..<pos0] ++ chain links ++ self — the exact set the
        // sequential path sees after its own scatter (mtpK[pos]=k then slice [0..<pos+1]).
        let ks = concatenated([baseK] + chainK.map { $0.expandedDimensions(axis: 0) }
                              + [k.expandedDimensions(axis: 0)], axis: 0)      // [S, 4, 256]
        let vs = concatenated([baseV] + chainV.map { $0.expandedDimensions(axis: 0) }
                              + [v.expandedDimensions(axis: 0)], axis: 0)
        let dt: DType = fp32Scores ? .float32 : .float16
        let qq = q.asType(dt).reshaped(1, Self.ah, 1, Self.ahd)                 // [1, 16, 1, 256]
        let kk = ks.asType(dt).transposed(1, 0, 2).expandedDimensions(axis: 0)  // [1, 4, S, 256]
        let vv = vs.asType(dt).transposed(1, 0, 2).expandedDimensions(axis: 0)
        let attn = MLXFast.scaledDotProductAttention(
            queries: qq, keys: kk, values: vv, scale: powf(Float(Self.ahd), -0.5), mask: .none)
        let out = attn.reshaped(-1).asType(.float16) * sigmoid(gate)            // [4096]
        var y = u + mm(out.expandedDimensions(axis: 0), op)[0]
        let z = rms(y, pln)
        let zz = z.expandedDimensions(axis: 0)
        y = y + mm(silu(mm(zz, gw)) * mm(zz, uw), dw)[0]
        return (rms(y, fnW), k, v)
    }

    /// K-link fused chain — ONE lazy graph, zero host syncs, zero compile boundaries. Inter-link handoff is
    /// GPU-resident: 32K sub-head argmax → the model's own QUANTIZED embed gather (full-vocab in-graph; the
    /// 42MB fp16 chainEmbed table of the compiled attempt is gone). Returns GPU draft ids + the links' k/v.
    func fusedChain(
        k: Int, firstToken: Int, hidden: MLXArray, pos0: Int, fp32Scores: Bool = true
    ) -> (ds: [MLXArray], ks: [MLXArray], vs: [MLXArray]) {
        let baseK = mtpK[0 ..< pos0]                    // committed slice, built ONCE, shared by all links
        let baseV = mtpV[0 ..< pos0]
        var e = model.embedding(MLXArray([Int32(firstToken)]))[0]
        var h = hidden
        var ds: [MLXArray] = [], ks: [MLXArray] = [], vs: [MLXArray] = []
        let dbgC = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_DEBUG"] == "1"
        for j in 0 ..< k {
            if dbgC { print("[fused-dbg] link \(j) build pos=\(pos0 + j)"); fflush(stdout) }
            let (y, kj, vj) = fusedLink(
                embedNext: e, hidden: h, pos: pos0 + j,
                baseK: baseK, baseV: baseV, chainK: ks, chainV: vs, fp32Scores: fp32Scores)
            ks.append(kj); vs.append(vj)
            let dj = draftArgmax(y)                                   // GPU scalar
            ds.append(dj)
            if j + 1 < k { e = model.embedding(dj.reshaped([1]))[0] } // in-graph full-vocab gather
            h = y
        }
        return (ds, ks, vs)
    }

    /// Deep-K MTP speculative decode on the fused chain (prefix-accept + carry-forward, EOS-aware,
    /// production emission semantics: the prefill argmax IS emitted). Single readback per round: the
    /// prefix-accept length L is computed IN-GRAPH (cumprod of the match vector) and comes back packed with
    /// the trunk argmax vector — replacing the 2K+2 `.item` shower of `generateSpecK`.
    public func generateSpecKFused(
        prompt: [Int], maxTokens: Int, eosTokens: Set<Int> = [], k: Int, fp32Scores: Bool = true
    ) -> Run {
        precondition(k >= 1)
        let dbgE = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_DEBUG"] == "1"
        if dbgE { print("[fused-dbg] entry, reset+prefill…"); fflush(stdout) }
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        if dbgE { print("[fused-dbg] prefill graph built, eval…"); fflush(stdout) }
        var hLast = h0[0, h0.dim(1) - 1]
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count
        var pending: [Int] = [argmaxLast(model.logits(fromHidden: h0))]
        var out: [Int] = []
        var acceptedTok = 0, iters = 0
        var hitEOS = false
        func emit(_ tok: Int) -> Bool {
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < maxTokens
        }
        // Verify width cap: T = pending + kEff ≤ 12. The Mac T-curve is LINEAR (15.6ms @T=1 → 29ms @T=11,
        // no qmv cliff on this trajectory), so unlike the K=1 lane there is NO bare-commit path — every
        // round verifies pending AND fresh drafts (the no-draft commit rounds were 1-token trunk passes,
        // 8/22 rounds at K=5 — the true deep-K killer after the refeed fix).
        let tCap = 12
        func draftAndCommit() -> [MLXArray] {
            // Clamp so chain positions stay inside the MTP KV bound (fp16-exact ≤ 2047 also holds).
            let kEff = max(1, min(k, tCap - pending.count, Self.maxSeq - 1 - hLastPos))
            let (ds, ks, vs) = fusedChain(
                k: kEff, firstToken: pending.last!, hidden: hLast, pos0: hLastPos, fp32Scores: fp32Scores)
            // Batched slot commit — post-round mtpK/mtpV state is bit-identical to the sequential path's
            // per-link scatters (stale higher slots masked by the [0..<pos0] slice, same as ever).
            mtpK[hLastPos ..< hLastPos + kEff] = stacked(ks, axis: 0)
            mtpV[hLastPos ..< hLastPos + kEff] = stacked(vs, axis: 0)
            return ds
        }
        let dbg = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_DEBUG"] == "1"
        var dbgSlow = 0, dbgChainMs = 0.0, dbgVerifyMs = 0.0
        _ = emit(pending[0])
        if dbg { print("[fused-dbg] prefill done, first chain…"); fflush(stdout) }
        var ds = draftAndCommit()
        if dbg { print("[fused-dbg] first chain built"); fflush(stdout) }
        let t0 = Date()
        while out.count < maxTokens && !hitEOS {
            if pending.count >= tCap - 1 {              // last-resort commit (pending alone fills the cap)
                // ONE multi-token forward (the sequential-lane one-token-at-a-time loop was the first
                // deep-K killer; the cap-6 no-draft round itself was the second — both retired, this
                // branch is nearly unreachable). Same forward class as the verify feed → same ADR-039
                // lossless family; the trunk argmax is still the trunk's own.
                dbgSlow += 1
                let hp = model.hiddenStatesWithCache(
                    MLXArray(pending.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                trunkLen += pending.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let t = argmaxLast(model.logits(fromHidden: hp))
                if !emit(t) { break }
                pending = [t]
                ds = draftAndCommit()
                continue
            }
            var snapshots: [(ArraysCache, MLXArray?, MLXArray?)] = []
            for c in cache where c is ArraysCache {
                let m = c as! ArraysCache
                snapshots.append((m, m[0], m[1]))
            }
            let P = pending.count
            let kNow = ds.count
            let T = P + kNow
            var parts: [MLXArray] = [MLXArray(pending.map(Int32.init))]
            parts.append(contentsOf: ds.map { $0.reshaped([1]).asType(.int32) })
            let input = concatenated(parts).expandedDimensions(axis: 0)
            let h2 = model.hiddenStatesWithCache(input, cache: cache)
            let lg = model.logits(fromHidden: h2)
            let am = argMax(lg[0], axis: -1).asType(.int32)            // [T] trunk argmaxes
            // In-graph prefix-accept: L = Σ cumprod(truth == draft). ONE readback carries [L, am].
            let dsVec = concatenated(ds.map { $0.reshaped([1]) }).asType(.int32)
            let truth = am[(P - 1) ..< (P - 1 + kNow)]
            let match = (truth .== dsVec).asType(.int32)
            let lAcc = cumprod(match, axis: 0).sum(keepDims: false)
            let packed = concatenated([lAcc.reshaped([1]), am])
            if dbg { print("[fused-dbg] round \(iters) pre-sync T=\(T) P=\(P)"); fflush(stdout) }
            let tv = dbg ? Date() : Date.distantPast
            let host = packed.asArray(Int32.self)                      // ⚠ the ONE gpu sync per round
            if dbg { dbgVerifyMs += Date().timeIntervalSince(tv) * 1000 }
            let L = Int(host[0])
            let amH = host.dropFirst().map(Int.init)                   // trunk argmaxes, host side
            iters += 1
            acceptedTok += L
            var emitted: [Int] = []
            if L == kNow {
                emitted = Array(amH[(P - 1) ..< (P - 1 + kNow)]) + [amH[T - 1]]   // drafts (== truths) + bonus
            } else {
                emitted = Array(amH[(P - 1) ..< (P - 1 + L)]) + [amH[P - 1 + L]]  // accepted + correction
            }
            var stop = false
            for e in emitted where !stop { stop = !emit(e) }
            if stop { break }
            if L == kNow {
                trunkLen += T
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [emitted.last!]
            } else {
                for (m, s0, s1) in snapshots { m[0] = s0; m[1] = s1 }
                for c in cache where !(c is ArraysCache) { _ = c.trim(T) }
                hLast = h2[0, P - 1 + L]
                hLastPos = trunkLen + P - 1 + L
                pending.append(contentsOf: emitted)
            }
            let tc = dbg ? Date() : Date.distantPast
            ds = draftAndCommit()
            if dbg { eval(ds); dbgChainMs += Date().timeIntervalSince(tc) * 1000 }
        }
        if dbg {
            print(String(format: "[fused-debug] slowPaths=%d chain=%.1fms/round verifySync=%.1fms/round iters=%d",
                         dbgSlow, dbgChainMs / Double(max(iters, 1)), dbgVerifyMs / Double(max(iters, 1)), iters))
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0),
                   accepted: acceptedTok, iterations: iters)
    }
}
#endif
