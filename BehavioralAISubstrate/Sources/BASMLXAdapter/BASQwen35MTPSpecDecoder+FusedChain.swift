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
import BASOrgan
#if canImport(MLXLLM)
import MLX          // MLXFast (scaledDotProductAttention et al.) lives inside the MLX module in this vendor
import MLXNN
import MLXLLM
import MLXLMCommon


/// 案4 (2026-07-06 decode-OS audit, CAUTIOUS version) — the trunk-draft provider contract for
/// the ONE certified verify kernel (`generateSpecKFused`'s loop). One dispatch per ROUND, never
/// per token; drafts stay GPU-resident (no readback inside a provider). Contract obligations:
///   • `draft` must leave any provider-private state SELF-MASKING beyond `pos0 + k` — a rejected
///     round is rolled back by the NEXT round's pos0, not by a callback (the MTP slot-slice rule).
///   • `preferredK` owns the regime policy INCLUDING the per-round thermal read (the in-flight
///     escape hatch the cert measured — a frozen per-turn snapshot loses the mid-turn K=1 clamp).
///   • `observe` folds the accepted length for regime learning (may persist across turns).
/// Per the critic's veto: the SAMPLING lane, generateSpecK/compiled* (frozen numerics anchors),
/// and DFlash (closed honest-negative) are NOT providers — this contract serves greedy
/// prefix-accept sources only; per-lane numerics stay per-lane.
protocol BASTrunkDraftProvider: AnyObject {
    /// Regime width for the next round (≥1); thermal-aware, EMA-driven.
    func preferredK() -> Int
    /// Provider-state position bound (e.g. the MTP stream's KV capacity).
    func maxDraftWidth(pos0: Int) -> Int
    /// ONE fused drafting dispatch: k GPU-resident ids anchored at (firstToken, hidden@pos0).
    func draft(k: Int, firstToken: Int, hidden: MLXArray, pos0: Int) -> [MLXArray]
    /// Fold the round's accepted prefix length (regime learning).
    func observe(acceptedLen: Int)
}

/// The production MTP fused-chain provider — the exact `adaptedK`/`draftAndCommit` bodies that
/// lived inline in the loop, relocated verbatim. Regime EMA persists on the DECODER (cached
/// across turns via MTPDecoderBox), same as before.
final class BASQwen35ChainDraftProvider: BASTrunkDraftProvider {
    private let dec: BASQwen35MTPSpecDecoder
    private let k: Int
    private let adaptiveK: Bool
    private let fp32Scores: Bool
    init(decoder: BASQwen35MTPSpecDecoder, k: Int, adaptiveK: Bool, fp32Scores: Bool) {
        self.dec = decoder
        self.k = k
        self.adaptiveK = adaptiveK
        self.fp32Scores = fp32Scores
    }
    func preferredK() -> Int {
        guard adaptiveK else { return k }
        // THERMAL TIER (cert take-4): at `fair` the downclocked GPU makes chain overhead
        // net-negative (0.91-0.99×) while K=1 held ~1.2× — force K=1; `serious+` is gated to
        // plain upstream (planner / session thermal fallback). Nominal: EMA-driven K ∈ {1,2,3}.
        if ProcessInfo.processInfo.thermalState != .nominal { return 1 }
        return dec.chainEmaL >= 1.6 ? min(k, 3) : dec.chainEmaL >= 0.9 ? min(k, 2) : 1
    }
    func maxDraftWidth(pos0: Int) -> Int {
        BASQwen35MTPSpecDecoder.maxSeq - 1 - pos0
    }
    func draft(k kEff: Int, firstToken: Int, hidden: MLXArray, pos0: Int) -> [MLXArray] {
        let (ds, ks, vs) = dec.fusedChain(
            k: kEff, firstToken: firstToken, hidden: hidden, pos0: pos0, fp32Scores: fp32Scores)
        // Batched slot commit — post-round mtpK/mtpV state is bit-identical to the sequential
        // path's per-link scatters (stale higher slots masked by the [0..<pos0] slice, same as ever).
        dec.mtpK[pos0 ..< pos0 + kEff] = stacked(ks, axis: 0)
        dec.mtpV[pos0 ..< pos0 + kEff] = stacked(vs, axis: 0)
        return ds
    }
    func observe(acceptedLen: Int) {
        guard adaptiveK else { return }
        dec.chainEmaL = 0.6 * dec.chainEmaL + 0.4 * Double(acceptedLen)
    }
}

extension BASQwen35MTPSpecDecoder {

    /// audit M-g — clamp the post-prefill probe budget. The B2 difficulty
    /// probe REFINES the decode budget after reading the prefill hidden
    /// state, but it must only ever spend LESS than the caller asked for:
    /// floor at 8 (a probe can't kill generation outright) and cap at the
    /// caller's `maxTokens` (a probe returning a large number must never
    /// let the decode overrun the caller's hard limit). Pure + testable.
    static func clampedProbeBudget(_ probe: Int, maxTokens: Int) -> Int {
        min(maxTokens, max(8, probe))
    }

    /// One chain link: the MTP block with attention over `baseK/baseV` (committed slice, shared across the
    /// chain) ++ this chain's earlier links ++ self. Math mirrors `mtpForward` exactly (same rms/rope/gate);
    /// `fp32Scores` reproduces the production K=1 lane's fp32 QKᵀ+softmax semantics (acceptance was
    /// measured there; fp16 scores only shift tie-breaks — acceptance-, never correctness-relevant).
    /// Returns (draft hidden, k, v) — k/v are NOT scattered here (the round batch-commits them).
    /// Lean norm/rope: MLXFast fused primitives (1 kernel each) instead of the hand-rolled compositions
    /// (~7 kernels per rms site, ~11 per rope site). On the iPhone the draft link is DISPATCH-bound
    /// (~0.3 ms/kernel → measured ~27 ms/link at ~75 kernels; the Mac GPU never showed it) — kernel COUNT,
    /// not FLOPs, is the wall. Semantics: rmsNorm(x,w,eps) == x·rsqrt(mean(x²)+ε)·w (weights pre-folded
    /// 1+w, matching `rms`); roPE(dims:64, traditional:false, base:1e7, offset:pos) == the hand-rolled
    /// NeoX rotate-half on the first 64 of 256 dims. fp32-vs-fp16 angle-table micro-diffs only move draft
    /// tie-breaks (acceptance-, never correctness-relevant; F1 gates it).
    private func leanRms(_ x: MLXArray, _ w: MLXArray) -> MLXArray {
        MLXFast.rmsNorm(x, weight: w, eps: 1e-6)
    }
    private func leanRope(_ t: MLXArray, pos: Int) -> MLXArray {
        MLXFast.RoPE(t.reshaped(t.dim(0), 1, Self.ahd), dimensions: Self.rd, traditional: false,
                     base: Self.ropeBase, scale: 1, offset: pos)
            .reshaped(t.dim(0), Self.ahd)
    }

    func fusedLink(
        embedNext: MLXArray, hidden: MLXArray, pos: Int,
        baseK: MLXArray, baseV: MLXArray, chainK: [MLXArray], chainV: [MLXArray],
        fp32Scores: Bool
    ) -> (y: MLXArray, k: MLXArray, v: MLXArray) {
        let u = mm(concatenated([leanRms(embedNext, nE), leanRms(hidden, nH)]).expandedDimensions(axis: 0), fc)[0]
        let h = leanRms(u, iln)
        let qpo = mm(h.expandedDimensions(axis: 0), qp)[0].reshaped(Self.ah, 2 * Self.ahd)
        var q = qpo[0..., 0 ..< Self.ahd]
        let gate = qpo[0..., Self.ahd...].reshaped(-1)
        var k = mm(h.expandedDimensions(axis: 0), kp)[0].reshaped(Self.akv, Self.ahd)
        let v = mm(h.expandedDimensions(axis: 0), vp)[0].reshaped(Self.akv, Self.ahd)
        q = leanRope(leanRms(q, qn), pos: pos)
        k = leanRope(leanRms(k, kn), pos: pos)
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
        let z = leanRms(y, pln)
        let zz = z.expandedDimensions(axis: 0)
        y = y + mm(silu(mm(zz, gw)) * mm(zz, uw), dw)[0]
        return (leanRms(y, fnW), k, v)
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
        prompt: [Int], maxTokens: Int, eosTokens: Set<Int> = [], k: Int, fp32Scores: Bool = true,
        tCap: Int = 12, adaptiveK: Bool = false, traceExit: BASTraceExitConfig? = nil,
        postPrefillBudget: ((MLXArray) -> Int)? = nil
    ) -> Run {
        precondition(k >= 1)
        let dbgE = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_DEBUG"] == "1"
        if dbgE { print("[fused-dbg] entry, reset+prefill…"); fflush(stdout) }
        // B3 trace early-exit (opt-in): armed only when a config is passed. Primed if the prompt
        // itself ends inside an open think block (template variants that pre-open `<think>`).
        var tracePolicy: BASTraceExitPolicy? = traceExit.map { cfg in
            let lastOpen = prompt.lastIndex(of: cfg.thinkOpenToken)
            let lastClose = prompt.lastIndex(of: cfg.thinkCloseToken)
            let primed = lastOpen.map { oi in lastClose.map { $0 < oi } ?? true } ?? false
            return BASTraceExitPolicy(config: cfg, primedInThink: primed)
        }
        var traceTel: BASTraceExitTelemetry? = nil
        resetMTPStream()
        let cache = model.newCache(parameters: nil)
        // 案1: entry composition guard — every layer must be snapshot-restorable or trimmable
        // (the fail-closed check the model-free lanes carry and the MTP lanes lacked). A vendor
        // or model change that introduces an unsupported cache refuses speculation up front
        // instead of corrupting state mid-generation; plain keeps the B3 contract.
        guard BASTrunkCheckpoint.compositionSupported(cache) else {
            print("[fused] unsupported cache composition — fail-close to plain")
            return generatePlain(prompt: prompt, maxTokens: maxTokens,
                                 eosTokens: eosTokens, traceExit: traceExit)
        }
        let h0 = model.hiddenStatesWithCache(
            MLXArray(prompt.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
        if dbgE { print("[fused-dbg] prefill graph built, eval…"); fflush(stdout) }
        var hLast = h0[0, h0.dim(1) - 1]
        // B2 探针路由器 — the post-prefill budget hook: the difficulty probe reads THIS hidden
        // state (the prefill the decode shares anyway — the observation is free) and may refine
        // the decode budget before the first token. nil = certified lane, byte-unchanged.
        let cap = postPrefillBudget.map {
            Self.clampedProbeBudget($0(hLast), maxTokens: maxTokens)
        } ?? maxTokens
        var hLastPos = prompt.count - 1
        var trunkLen = prompt.count
        let (t0Tok, t0Ent) = argmaxAndEntropy(model.logits(fromHidden: h0)[0, -1])
        var pending: [Int] = [t0Tok]
        var out: [Int] = []
        var acceptedTok = 0, iters = 0
        var proposedTok = 0
        var hitEOS = false
        func emit(_ tok: Int) -> Bool {
            if eosTokens.contains(tok) { hitEOS = true; return false }
            out.append(tok)
            return out.count < cap
        }
        // Verify width cap (now a parameter — PLATFORM-dependent): T = pending + kEff ≤ tCap.
        // Mac ('d' GPU arch): qmv batch limit 12+ → T-curve LINEAR to 11+ → tCap 12.
        // iPhone ('p' arch): get_qmv_batch_limit = 6 for the MLP(9728)/lm_head(248K) dims → T ≥ 6 flips
        // those matmuls qmv→qmm tile kernels → verify 119ms/round vs ~50 (device-split 2026-07-03, the
        // TRUE killer of every historical deep-K device run) → device callers pass tCap 5.
        //
        // ADAPTIVE K (endurance-cert finding 2026-07-03): chain acceptance is WORKLOAD-dependent — real
        // short prose a/iter ≈ 1.0 (fixed K=3 → 0.90×; per-link conditional acceptance ~0.35) vs synthetic/
        // thinking trajectories 2.05-2.69 (1.51×, cold 31.0). A per-round EMA of the accepted prefix L
        // steers kEff ∈ {1,2,3}: prose settles at K=1 (the certified 1.20-1.36× regime), high-overlap
        // workloads ride K=3. α=0.4 (the codebase EMA idiom); optimistic start (learns in 2-3 rounds).
        // PERSISTED across turns (instance property): the production decoder is cached across turns
        // (MTPDecoderBox), so the regime estimate must survive the call boundary — a local EMA re-paid
        // the 2-3-round optimistic learning tax EVERY 48-token turn (cert take-2: 1.08× < the K=1 1.20×).
        // 案4: the drafting side is a PROVIDER behind BASTrunkDraftProvider — the kernel below is
        // draft-source-agnostic; regime policy (thermal escape hatch + EMA) lives in the provider.
        let provider: BASTrunkDraftProvider = BASQwen35ChainDraftProvider(
            decoder: self, k: k, adaptiveK: adaptiveK, fp32Scores: fp32Scores)
        func draftAndCommit() -> [MLXArray] {
            // Clamp so chain positions stay inside the provider's KV bound (fp16-exact ≤ 2047 holds).
            let kEff = max(1, min(provider.preferredK(), tCap - pending.count,
                                  provider.maxDraftWidth(pos0: hLastPos)))
            return provider.draft(k: kEff, firstToken: pending.last!, hidden: hLast, pos0: hLastPos)
        }
        // Non-round emissions (prefill / refeed argmaxes) MUST carry entropy too — nil-entropy
        // tokens made the window's fill rhythm depend on ROUND STRUCTURE, which depends on the
        // cross-turn adaptive-K EMA ⇒ nondeterministic exit points between byte-identical prompts
        // (the device co-gate caught the identity violation 2026-07-06). One packed readback.
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
        // A .close verdict HERE is deferred — these paths have no verify round in flight to
        // unwind; the persisting condition refires within the next round.
        func observeCarrying(_ tok: Int, _ ent: Int?) {
            _ = tracePolicy?.observe(token: tok, entropyMillinats: ent,
                                     outCount: out.count, maxTokens: cap)
        }
        let dbg = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_DEBUG"] == "1"
        var dbgSlow = 0, dbgChainMs = 0.0, dbgVerifyMs = 0.0
        // TR-R0/R1 probe (BAS_TR_PROBE=1, observation-only — emissions untouched): extend the
        // packed readback with the ORDERED argtop-8 of every verify row, feed the recycling
        // adjacency, and score TR-hit vs MTP-hit on the SAME rows/truths. Charter:
        // Docs/DECODE_OS_AUDIT_2026-07-06.md TOKEN-RECYCLING 章程.
        let trProbe = ProcessInfo.processInfo.environment["BAS_TR_PROBE"] == "1"
        let trK = 8
        var trMatrix = BASTokenRecyclingMatrix(k: trK)
        var trStats = (rows: 0, trHits: [Int: Int](), mtpHits: [Int: Int](), linkRows: [Int: Int](),
                       trTop3Hits: 0, coveredRows: 0)
        _ = emit(pending[0])
        observeCarrying(pending[0], t0Ent)
        if dbg { print("[fused-dbg] prefill done, first chain…"); fflush(stdout) }
        var ds = draftAndCommit()
        if dbg { print("[fused-dbg] first chain built"); fflush(stdout) }
        let t0 = Date()
        while out.count < cap && !hitEOS {
            if pending.count >= tCap {                  // commit refeed (itself ≤ tCap ⇒ stays in the qmv regime)
                // ONE multi-token forward (the sequential-lane one-token-at-a-time loop was the first
                // deep-K killer; the cap-6 no-draft round itself was the second — both retired, this
                // branch is nearly unreachable). Same forward class as the verify feed → same ADR-039
                // lossless family; the trunk argmax is still the trunk's own.
                dbgSlow += 1
                let hp = model.hiddenStatesWithCache(
                    MLXArray(pending.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                trunkLen += pending.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let (t, tEnt) = argmaxAndEntropy(model.logits(fromHidden: hp)[0, -1])
                if !emit(t) { break }
                observeCarrying(t, tEnt)
                pending = [t]
                ds = draftAndCommit()
                continue
            }
            let checkpoint = BASTrunkCheckpoint(cache: cache)   // 案1: the ONE snapshot owner
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
            // B3 signal armed only while the policy can still fire — after the one-shot latch (forced
            // OR model self-close) the vocab-wide entropy reductions must stop (review MEDIUM-1: a long
            // answer would otherwise pay ~1MB fp32 softmax×T every remaining round for nothing).
            let traceActive = !(tracePolicy?.closed ?? true)
            var packedParts = [lAcc.reshaped([1]), am]
            if trProbe {
                // ORDERED top-8 per row, in-graph (argPartition → gather values → argSort of 8),
                // appended to the ONE readback: [T×8] int32 row-major most-likely-first, then the
                // kNow draft ids (row-input reconstruction needs them host-side, probe-only).
                let lf32 = lg[0].asType(.float32)                       // [T, V]
                let part = argPartition(lf32, kth: lf32.dim(1) - trK, axis: -1)
                let topIdx = part[0..., (lf32.dim(1) - trK)...]         // [T, 8] unordered
                let topVal = takeAlong(lf32, topIdx, axis: -1)          // [T, 8]
                let order = argSort(topVal, axis: -1)                   // ascending
                let ordered = takeAlong(topIdx, order, axis: -1)        // ascending by prob
                packedParts.append(ordered[0..., .stride(by: -1)].flattened().asType(.int32))
                packedParts.append(dsVec)
            }
            if traceActive {
                // Trunk next-token distribution entropy per row, packed as millinats so the
                // ONE-readback-per-round discipline holds (fp32 for stability; ~T×1MB, negligible).
                let lf = lg[0].asType(.float32)
                let pr = softmax(lf, axis: -1)
                let ent = -(pr * log(pr + 1e-9)).sum(axis: -1)
                packedParts.append((ent * 1000).asType(.int32))
            }
            let packed = concatenated(packedParts)
            if dbg { print("[fused-dbg] round \(iters) pre-sync T=\(T) P=\(P)"); fflush(stdout) }
            let tv = dbg ? Date() : Date.distantPast
            let host = packed.asArray(Int32.self)                      // ⚠ the ONE gpu sync per round
            if dbg { dbgVerifyMs += Date().timeIntervalSince(tv) * 1000 }
            let L = Int(host[0])
            // 案1 always-on invariant: L ∈ [0, kNow] bounds every emitted-row index below
            // (P-1+L ≤ T-1). A violation means a corrupt readback — fail-close, never emit from
            // out-of-range rows (everything already out is a trunk argmax; stopping is safe).
            guard L >= 0, L <= kNow else {
                print("[fused] INVARIANT violated: L=\(L) kNow=\(kNow) — fail-close")
                break
            }
            let amH = host[1 ... T].map(Int.init)                      // trunk argmaxes, host side
            var cursor = T + 1
            // audit M-g/M-i — UNPACK must mirror the PACK order above: the
            // trProbe block (flat[T×trK] + ds[kNow]) is packed BEFORE the
            // traceActive entropy[T]. Reading entH first (as this used to)
            // corrupted BOTH channels whenever trProbe + traceActive were on
            // together — entH sliced the top-k region while flat/ds sliced
            // the entropy region + overran. Read trProbe first, then entH.
            if trProbe {
                let flat = host[cursor ..< cursor + T * trK].map(Int.init)
                cursor += T * trK
                let dsH = host[cursor ..< cursor + kNow].map(Int.init)
                cursor += kNow
                // Row i's INPUT token: pending[i] for i<P, else the draft ds[i-P]; amH[i] = the
                // trunk's truth for the token FOLLOWING input[i].
                let inputTok: [Int] = pending + dsH
                // Score BEFORE observing this round (the matrix may only use PAST state):
                // link j (1-based) sits at row P-1+j-1; TR's counterfactual draft for that row is
                // M[input].top-1 — same row, same truth as MTP's draft j (apples-to-apples).
                for j in 1 ... kNow {
                    let row = P - 1 + (j - 1)
                    let truth = amH[row]
                    trStats.linkRows[j, default: 0] += 1
                    if j - 1 < L { trStats.mtpHits[j, default: 0] += 1 }
                    let proposal = trMatrix.proposeChain(from: inputTok[row], length: 1).first
                    if proposal != nil { trStats.coveredRows += 1 }
                    if proposal == truth { trStats.trHits[j, default: 0] += 1 }
                    let m3 = trMatrix.proposeBranches(from: inputTok[row], maxBranch: 3, depth: 1)
                        .compactMap { $0.first }
                    if m3.contains(truth) { trStats.trTop3Hits += 1 }
                }
                trStats.rows += kNow
                // Feed the adjacency with EVERY row's fresh top-k (recycling the verify's trash).
                for i in 0 ..< T {
                    trMatrix.observe(after: inputTok[i], topK: Array(flat[(i * trK) ..< (i * trK + trK)]))
                }
            }
            // traceActive entropy — packed LAST, so unpacked last (audit M-g/M-i).
            let entH: [Int]
            if traceActive {
                entH = host[cursor ..< cursor + T].map(Int.init)
                cursor += T
            } else { entH = [] }
            // The readback must be fully consumed — a mismatch means the PACK
            // and UNPACK layouts drifted apart again (the M-g/M-i bug).
            assert(cursor == host.count,
                   "fused readback layout drift: cursor \(cursor) != \(host.count)")
            iters += 1
            acceptedTok += L
            proposedTok += kNow
            provider.observe(acceptedLen: L)
            var emitted: [Int] = []
            if L == kNow {
                emitted = Array(amH[(P - 1) ..< (P - 1 + kNow)]) + [amH[T - 1]]   // drafts (== truths) + bonus
            } else {
                emitted = Array(amH[(P - 1) ..< (P - 1 + L)]) + [amH[P - 1 + L]]  // accepted + correction
            }
            var stop = false
            var closeAt = -1
            var closeReason: BASTraceExitPolicy.Reason? = nil
            for (i, e) in emitted.enumerated() {
                if !emit(e) { stop = true; break }
                // Row mapping: emitted[i] is drawn from the trunk distribution at input row P-1+i
                // (both branches emit consecutive rows; the full-accept bonus row is T-1 = P-1+kNow).
                if tracePolicy != nil,
                   case .close(let r)? = tracePolicy?.observe(
                       token: e, entropyMillinats: entH.isEmpty ? nil : entH[P - 1 + i],
                       outCount: out.count, maxTokens: cap) {
                    closeAt = i; closeReason = r
                    break
                }
            }
            if stop { break }
            if let reason = closeReason, let cfg = traceExit {
                // FORCE-CLOSE the think trace: inject "\n</think>\n\n", unwind this round's verify
                // forward entirely (snapshots + trim — the reject-branch mechanics), then rebuild the
                // stream state with ONE refeed of everything not in cache. Runs at most once per
                // generation (one-shot latch); the refeed may exceed tCap's qmv width — a single
                // qmm-regime forward per fire is accepted (correctness-identical forward class).
                // 缝5 (2026-07-06): the round credited the full prefix L, but emitted tokens past
                // closeAt are DISCARDED — return them so Run.accepted is exact (the old LOW-4
                // 'immaterial' skew still fed the profiler EMA the 0.15 collapse floor reads).
                acceptedTok -= max(0, L - min(closeAt + 1, L))
                tracePolicy?.markForcedClose()
                traceTel = BASTraceExitTelemetry(
                    reason: reason, thinkTokensAtExit: tracePolicy?.thinkTokens ?? 0,
                    outCountAtExit: out.count)
                for t in cfg.closeSequence where !stop { stop = !emit(t) }
                if stop { break }              // budget died mid-injection — no refeed to waste (review LOW-3)
                guard checkpoint.restore(cache: cache, trimming: T) else {
                    print("[spec] trim under-returned — fail-close (emitted tokens are all trunk argmaxes)")
                    break
                }
                let feed = pending + Array(emitted[0 ... closeAt]) + cfg.closeSequence
                let hp = model.hiddenStatesWithCache(
                    MLXArray(feed.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                trunkLen += feed.count
                hLast = hp[0, hp.dim(1) - 1]; hLastPos = trunkLen - 1
                let (t, tEnt) = argmaxAndEntropy(model.logits(fromHidden: hp)[0, -1])
                if !emit(t) { break }
                observeCarrying(t, tEnt)
                pending = [t]
                ds = draftAndCommit()
                continue
            }
            if L == kNow {
                trunkLen += T
                hLast = h2[0, T - 1]; hLastPos = trunkLen - 1
                pending = [emitted.last!]
            } else {
                guard checkpoint.restore(cache: cache, trimming: T) else {
                    print("[spec] trim under-returned — fail-close (emitted tokens are all trunk argmaxes)")
                    break
                }
                hLast = h2[0, P - 1 + L]
                hLastPos = trunkLen + P - 1 + L
                pending.append(contentsOf: emitted)
            }
            let tc = dbg ? Date() : Date.distantPast
            ds = draftAndCommit()
            if dbg { eval(ds); dbgChainMs += Date().timeIntervalSince(tc) * 1000 }
        }
        if trProbe, trStats.rows > 0 {
            let links = trStats.linkRows.keys.sorted()
            let per = links.map { j -> String in
                let n = max(1, trStats.linkRows[j] ?? 1)
                return String(format: "L%d tr=%.2f mtp=%.2f n=%d", j,
                              Double(trStats.trHits[j] ?? 0) / Double(n),
                              Double(trStats.mtpHits[j] ?? 0) / Double(n), n)
            }.joined(separator: " | ")
            print(String(format: "[tr-probe] rows=%d covered=%.2f top3=%.2f matrix=%d :: %@",
                         trStats.rows, Double(trStats.coveredRows) / Double(trStats.rows),
                         Double(trStats.trTop3Hits) / Double(trStats.rows),
                         trMatrix.coverage, per))
        }
        if dbg {
            print(String(format: "[fused-debug] slowPaths=%d chain=%.1fms/round verifySync=%.1fms/round iters=%d",
                         dbgSlow, dbgChainMs / Double(max(iters, 1)), dbgVerifyMs / Double(max(iters, 1)), iters))
        }
        return Run(tokens: out, decodeSeconds: Date().timeIntervalSince(t0),
                   accepted: acceptedTok, iterations: iters, proposed: proposedTok,
                   traceExit: traceTel)
    }
}
#endif
