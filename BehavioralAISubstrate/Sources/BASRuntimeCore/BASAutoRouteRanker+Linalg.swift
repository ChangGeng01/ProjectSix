// MARK: - BASAutoRouteRanker+Linalg
// God-object extraction (audit ch1040, WS1): the Linalg domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - Softmax routing (chapter 七百九 第四刀)
    //
    // Measured M-series wins (tournament 七百九 第三刀):
    // softmax is dominated by exp() per-element cost,scalar
    // and SIMD perform within ±5%。 Always use scalar — keeps
    // the dispatch simple,zero regret in practice。
    public static func softmax(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [],
                choice: .rustSoftmaxScalar)
        }
        var out = [Float](
            repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_softmax(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out,
                choice: .rustSoftmaxScalar)
        }
        #endif
        // Swift fallback
        var m = x[0]
        for v in x { if v > m { m = v } }
        var sum: Float = 0
        for (i, v) in x.enumerated() {
            let e = expf(v - m)
            out[i] = e
            sum += e
        }
        if sum > 0 {
            for i in 0..<out.count { out[i] /= sum }
        }
        return BASAutoRouteResult(
            value: out, choice: .swiftNaive)
    }

    // MARK: - LayerNorm routing (chapter 七百九 第四刀)
    //
    // Measured M-series wins:
    //   dim < 128 → Rust naive (no SIMD overhead)
    //   dim ≥ 128 → Rust affine SIMD (1.2-1.9x over naive)
    //
    // Affine variant takes γ + β。 For "plain" LayerNorm
    // (γ=1, β=0) the affine SIMD path still wins above the
    // threshold — only its loop structure changes,not the math。
    public static func layerNormChoice(
        dim: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        if dim < thresholds.layerNormSIMDMinDim {
            return .rustLayerNormNaive
        }
        return .rustLayerNormAffineSIMD
    }

    /// Plain LayerNorm (γ=1,β=0)。 Routes between Rust naive
    /// + Rust affine SIMD (with implicit γ=1, β=0)。
    public static func layerNorm(
        _ x: [Float], eps: Float = 1e-5,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [],
                choice: .rustLayerNormNaive)
        }
        let choice = layerNormChoice(
            dim: x.count, thresholds: thresholds)
        var out = [Float](
            repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc: Int32
        switch choice {
        case .rustLayerNormAffineSIMD:
            let gamma = [Float](
                repeating: 1.0, count: x.count)
            let beta = [Float](
                repeating: 0.0, count: x.count)
            rc = x.withUnsafeBufferPointer { xp in
                gamma.withUnsafeBufferPointer { gp in
                    beta.withUnsafeBufferPointer { bp in
                        out.withUnsafeMutableBufferPointer
                            { op in
                            bas_ranker_layer_norm_affine_simd(
                                xp.baseAddress, x.count,
                                gp.baseAddress, gamma.count,
                                bp.baseAddress, beta.count,
                                op.baseAddress, op.count,
                                eps)
                        }
                    }
                }
            }
        default:
            rc = x.withUnsafeBufferPointer { xp in
                out.withUnsafeMutableBufferPointer { op in
                    bas_ranker_layer_norm(
                        xp.baseAddress, x.count,
                        op.baseAddress, op.count, eps)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: choice)
        }
        #endif
        // Fallback: Swift naive
        var sum: Float = 0
        for v in x { sum += v }
        let mean = sum / Float(x.count)
        var vsum: Float = 0
        for v in x {
            let d = v - mean
            vsum += d * d
        }
        let variance = vsum / Float(x.count)
        let invStd = 1.0 / (variance + eps).squareRoot()
        for i in 0..<x.count {
            out[i] = (x[i] - mean) * invStd
        }
        return BASAutoRouteResult(
            value: out, choice: .swiftNaive)
    }


    // MARK: - MatMul routing (chapter 七百八 第三刀)
    //
    // Measured M-series wins (BASChapter708MatMulTournamentTests):
    //   8x8x8       → Rust naive   (Metal ~250x slower)
    //   32x32x32    → Rust blocked (Metal still 14x slower)
    //   128x128x128 → Metal       (2x faster than Rust blocked)
    //   512x512x512 → Metal       (18x faster than Rust blocked)
    //
    // Crossover at M*N*K ≈ 262 144 (= 64³)。 Below uses Rust。
    // Within Rust:naive wins for tiny (≤ 8³),blocked above。
    public static func matMulChoice(
        shape: BASMatMulShape,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        let prod = shape.workProduct
        // chapter 八百七十一 split-flip (refactored at chapter
        // 八百七十一.5 / M3025 to read threshold from
        // BASAutoRouteThresholds for per-device configurability):
        //   prod ≥ thresholds.matMulMPSGraphActorMinProduct
        //     → MPSGraph actor (default 16M = 256³,where Mac
        //        mini measured MPSGraph warm wins 1.07-1.38× at
        //        256³+)
        //   prod ≥ thresholds.matMulMetalMinProduct + < the above
        //     → MSL custom kernel (.metalMatMulMPSGraph legacy
        //        enum,1.89× faster than MPSGraph at 128³)
        //   prod < 262144 → Rust paths win
        //
        // The 16M default sits exactly at 256³ where MPSGraph
        // first wins by a narrow margin。 iPhone/iPad with
        // different MPSGraph overhead can raise this via the
        // thresholds init parameter without touching the ranker
        // (agent A 6th-pass review HIGH-1)。
        if prod >= thresholds.matMulMPSGraphActorMinProduct {
            return .metalMatMulMPSGraphActor
        }
        if prod >= thresholds.matMulMetalMinProduct {
            return .metalMatMulMPSGraph  // routes to MSL despite name
        }
        if prod < 8_192 {
            return .rustMatMulNaive
        }
        return .rustMatMulBlocked
    }

    // MARK: - Attention routing (chapter 七百七 第三刀)
    //
    // Pure-policy helper — returns the CHOICE the router would
    // pick at this shape。 The actual Swift dispatcher lives on
    // BASCognitiveBrain because it needs the actor's memoized
    // Metal pipeline state。 Hosts compose like this:
    //
    //   let choice = BASAutoRouteRanker.attentionChoice(
    //       shape: BASAttentionShape(...), thresholds: ...)
    //   switch choice {
    //   case .swiftCPUAttention: …call CPU path…
    //   case .metalFlashAttention: …call Metal flashAttention…
    //   default: …
    //   }
    //
    // Auto-routed `brain.attentionAuto(...)` does this internally。
    public static func attentionChoice(
        shape: BASAttentionShape,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        // Tiny workloads → CPU wins because Metal pipeline
        // dispatch overhead (~150 μs) dominates the compute。
        if shape.workProduct
            < thresholds.attentionMetalMinProduct
        {
            return .swiftCPUAttention
        }
        // chapter 八百七十 / M3016 FLIP — chapter 八百六十九 measured
        // MPSGraph (warm) at 2.31-3.09× faster than scaled_dot_product
        // AND FlashAttention at production shapes:
        //
        //   Shape (M, N, D)   std ns      Flash ns    MPSGraph(warm)
        //   (32, 64, 32)      1,105,000   1,081,500   477,334  ← MPS 2.31×
        //   (32, 256, 32)     3,266,125   3,449,334   1,057,250 ← MPS 3.09×
        //
        // Cache cold→warm speedup is 30.48× (the kernel + executable
        // cache must be SHARED across calls — per-call new kernel
        // loses the speedup)。 Chapter 八百七十 wires that sharing
        // through BASCognitiveBrain (kernel + cache stored props,
        // lazy-init,actor-isolated)。
        //
        // CONSTRAINT — MPSGraph requires shape.Dv == shape.D。 For
        // Dv ≠ D shapes,fall back to .metalStandardAttention (NOT
        // .metalFlashAttention — chapter 八百六十八 measured FA as
        // 1.07-1.10× slower than std,routing fallback to slower
        // option is wrong)。
        //
        // The fallback gate happens HERE in the ranker rather than
        // in the brain because the choice IS what gets routed —
        // brain just executes the ranker's pick。 Caller code is
        // simpler this way (single switch, no second branch on
        // shape.Dv at the brain layer)。
        if shape.Dv != shape.D {
            return .metalStandardAttention
        }
        return .metalMPSGraphAttention
    }

    /// CPU reference attention — pure-function。 Provides the
    /// fallback when Metal isn't available + the slow-but-
    /// correct ground truth for cross-impl byte-equality tests。
    public static func cpuAttention(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int
    ) -> [Float] {
        let invSqrtD = 1.0 / Float(D).squareRoot()
        var out = [Float](repeating: 0, count: M * Dv)
        for i in 0..<M {
            var scaled = [Float](
                repeating: 0, count: N)
            var maxScore: Float = -.infinity
            for kk in 0..<N {
                var dot: Float = 0
                for d in 0..<D {
                    dot += q[i * D + d]
                        * k[kk * D + d]
                }
                scaled[kk] = dot * invSqrtD
                if scaled[kk] > maxScore {
                    maxScore = scaled[kk]
                }
            }
            var expSum: Float = 0
            var exps = [Float](repeating: 0, count: N)
            for kk in 0..<N {
                exps[kk] = exp(scaled[kk] - maxScore)
                expSum += exps[kk]
            }
            for j in 0..<Dv {
                var acc: Float = 0
                for kk in 0..<N {
                    acc += (exps[kk] / expSum)
                        * v[kk * Dv + j]
                }
                out[i * Dv + j] = acc
            }
        }
        return out
    }
}
