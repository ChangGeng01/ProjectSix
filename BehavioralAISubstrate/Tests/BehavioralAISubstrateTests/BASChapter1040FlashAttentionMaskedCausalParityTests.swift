// MARK: - BASChapter1040FlashAttentionMaskedCausalParityTests
// chapter 一千零四十 / ADR-019 consequential wiring
//
// PARITY GATE for the newly-wired FlashAttention masked + causal
// GPU paths。
//
// Chapter 七百五 第一刀 shipped three MSL kernels in
// BASFlashAttention.metal:
//
//   - flash_attention_forward          (unmasked — wired @ ch 707)
//   - flash_attention_forward_masked   (additive boolean mask)
//   - flash_attention_forward_causal   (implicit lower-triangular)
//
// …but only the unmasked path had a Swift entry point。 This
// chapter wires `dispatch(...mask:)` + `dispatchCausal(...)` on
// BASMetalFlashAttentionDispatcher。 The HARD RULE for shipping
// GPU dispatch is GPU-vs-CPU PARITY — no unverified kernel ships。
// These tests are that gate。
//
// ## CPU reference lives HERE, not in BASAttentionKernel.swift
//
// The unmasked CPU reference is BASAutoRouteRanker.cpuAttention
// (BASRuntimeCore)。 The masked + causal references are NOT yet in
// the substrate — another agent owns BASAttentionKernel.swift — so
// the slow-but-correct ground truth for masked / causal lives in
// this test file。 Both mirror the EXACT online-softmax semantics
// the .metal kernels implement:
//
//   - masked: mask[i*N + j] != 0  ⇒ key j excluded from row i
//   - causal: j > i               ⇒ key j excluded from row i
//   - a fully-excluded row ⇒ all-zero output row (matches the
//     kernel's `l_i <= 0 → write 0` branch)
//
// ## Tolerance
//
// MAE ≤ 1e-3 — the SAME float32 band the unmasked flash parity
// test (BASChapter707FlashAttentionTests) asserts cell-wise。 The
// tiled online-softmax accumulates in a different order than the
// CPU two-pass softmax,so exact equality is not expected;1e-3 is
// the established cross-impl float32 agreement bar。
//
// ## GPU-gated
//
// XCTSkip on hosts without the Metal framework or without a GPU —
// matches the BASMetalKernelLibraryLoaderTests V2-path gating。 On
// a GPU-enabled Apple host the kernels run for real。

import XCTest
@testable import BASRuntimeCore
@testable import BASMetalSubstrate
#if canImport(Metal)
import Metal
#endif

#if !os(iOS)  // ch 1022 source-gate: Mac dev-box GPU parity
final class BASChapter1040FlashAttentionMaskedCausalParityTests:
    XCTestCase
{

    // MARK: - Shared tolerance (matches unmasked flash parity)

    /// Same float32 cross-impl band the chapter-707 unmasked flash
    /// parity test uses (`accuracy: 1e-3`)。
    private static let parityTolerance: Float = 1e-3

    // MARK: - Deterministic input fixture

    private func makeInputs(
        M: Int, N: Int, D: Int, Dv: Int,
        seed initialSeed: UInt32 = 0xC0FFEE
    ) -> (q: [Float], k: [Float], v: [Float]) {
        var seed = initialSeed
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }
        return (q, k, v)
    }

    // MARK: - CPU references (ground truth)

    /// Masked CPU attention。 `mask` is row-major `[M × N]`;a
    /// non-zero byte at `mask[i*N + j]` EXCLUDES key j from query
    /// row i's softmax。 A row that excludes every key produces an
    /// all-zero output row (matches the kernel)。
    private func cpuMaskedAttention(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int,
        mask: [UInt8]
    ) -> [Float] {
        return cpuAttentionWithPredicate(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv
        ) { i, j in mask[i * N + j] != 0 }
    }

    /// Causal CPU attention — key j excluded from row i when
    /// `j > i` (lower-triangular)。 No mask buffer。
    private func cpuCausalAttention(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int
    ) -> [Float] {
        return cpuAttentionWithPredicate(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv
        ) { i, j in j > i }
    }

    /// Shared online-softmax CPU reference parameterized by an
    /// `isExcluded(queryRow, keyCol)` predicate。 Two-pass softmax
    /// (max → exp-sum) over the INCLUDED keys only — the math the
    /// masked / causal .metal kernels converge to。 Mirrors
    /// BASAutoRouteRanker.cpuAttention for the no-exclusion case。
    private func cpuAttentionWithPredicate(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int,
        isExcluded: (Int, Int) -> Bool
    ) -> [Float] {
        let invSqrtD = 1.0 / Float(D).squareRoot()
        var out = [Float](repeating: 0, count: M * Dv)
        for i in 0..<M {
            var scaled = [Float](repeating: 0, count: N)
            var included = [Bool](repeating: false, count: N)
            var maxScore: Float = -.infinity
            for kk in 0..<N {
                if isExcluded(i, kk) {
                    included[kk] = false
                    continue
                }
                included[kk] = true
                var dot: Float = 0
                for d in 0..<D {
                    dot += q[i * D + d] * k[kk * D + d]
                }
                scaled[kk] = dot * invSqrtD
                if scaled[kk] > maxScore {
                    maxScore = scaled[kk]
                }
            }
            var expSum: Float = 0
            var exps = [Float](repeating: 0, count: N)
            for kk in 0..<N where included[kk] {
                exps[kk] = exp(scaled[kk] - maxScore)
                expSum += exps[kk]
            }
            // Fully-excluded row → zeros (kernel's l_i<=0 branch)。
            guard expSum > 0 else { continue }
            for j in 0..<Dv {
                var acc: Float = 0
                for kk in 0..<N where included[kk] {
                    acc += (exps[kk] / expSum) * v[kk * Dv + j]
                }
                out[i * Dv + j] = acc
            }
        }
        return out
    }

    // MARK: - GPU dispatcher helper (V2 loader)

    /// Build a dispatcher backed by a V2 (real-compile) loader,or
    /// skip the test when no GPU / Metal is available。
    private func makeDispatcherOrSkip() throws
        -> BASMetalFlashAttentionDispatcher
    {
        #if !canImport(Metal)
        throw XCTSkip("Metal unavailable on this host")
        #else
        if MTLCreateSystemDefaultDevice() == nil {
            throw XCTSkip("No GPU available on this host")
        }
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        return BASMetalFlashAttentionDispatcher(loader: loader)
        #endif
    }

    /// Mean-absolute-error between two equal-length arrays。
    private func meanAbsError(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        precondition(a.count == b.count)
        guard !a.isEmpty else { return 0 }
        var sum: Float = 0
        for i in 0..<a.count { sum += abs(a[i] - b[i]) }
        return sum / Float(a.count)
    }

    // MARK: - PARITY: masked GPU vs masked CPU

    /// GPU `flash_attention_forward_masked` vs the masked CPU
    /// reference on a deterministic shape with a non-trivial mask
    /// (some keys excluded per row,no row fully excluded)。 MAE
    /// must fall within the unmasked-flash float32 band。
    func testMaskedFlashMatchesCPUReference() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (3, 4, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)

        // Mask: exclude one distinct key per row;every row keeps
        // ≥ 3 keys → no fully-excluded (degenerate) row。
        //   row 0 excludes key 1, row 1 excludes key 2,
        //   row 2 excludes key 3。
        var mask = [UInt8](repeating: 0, count: M * N)
        mask[0 * N + 1] = 1
        mask[1 * N + 2] = 1
        mask[2 * N + 3] = 1

        let gpu = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv,
            mask: mask)
        let cpu = cpuMaskedAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv,
            mask: mask)

        XCTAssertEqual(gpu.count, cpu.count)
        let mae = meanAbsError(gpu, cpu)
        XCTAssertLessThanOrEqual(
            mae, Self.parityTolerance,
            "masked GPU vs CPU MAE \(mae) exceeds tolerance " +
            "\(Self.parityTolerance)。 gpu=\(gpu) cpu=\(cpu)")
        // Per-cell guard too — a single diverged cell that an
        // averaged MAE could mask would still fire here。
        for idx in 0..<cpu.count {
            XCTAssertEqual(
                gpu[idx], cpu[idx],
                accuracy: Self.parityTolerance,
                "masked cell \(idx) diverges: gpu=\(gpu[idx]) " +
                "cpu=\(cpu[idx])")
        }
    }

    /// H2(大审计立即层,2026-07-08)——行首 tile 全 mask 的 NaN 中毒回归。
    /// B_C=32:N=40 且每行 key 0..31 全排除 ⇒ 第一个 KV tile 全 -INF ⇒
    /// 旧内核 `alpha=exp(-INF-(-INF))=NaN` 污染 l_i,整行静默输出 0;
    /// 正确答案是对 key 32..39 的注意力(CPU 参照)。守卫修后必须 parity。
    func testLeadingFullyMaskedTileDoesNotPoisonRow() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (3, 40, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)

        // 每行排除前 32 个 key(恰好第一个完整 tile),保留 32..39。
        var mask = [UInt8](repeating: 0, count: M * N)
        for i in 0..<M {
            for j in 0..<32 { mask[i * N + j] = 1 }
        }

        let gpu = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv,
            mask: mask)
        let cpu = cpuMaskedAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv,
            mask: mask)

        XCTAssertEqual(gpu.count, cpu.count)
        // 先证输出非零(旧内核在此全 0)再证逐格 parity。
        let gpuMagnitude = gpu.reduce(Float(0)) { $0 + abs($1) }
        XCTAssertGreaterThan(
            gpuMagnitude, 0,
            "行首全 mask tile 后整行输出 0 —— NaN 中毒(H2)")
        for idx in 0..<cpu.count {
            XCTAssertEqual(
                gpu[idx], cpu[idx],
                accuracy: Self.parityTolerance,
                "leading-masked-tile cell \(idx) diverges: " +
                "gpu=\(gpu[idx]) cpu=\(cpu[idx])")
        }
    }

    /// All-zero mask ⇒ masked path MUST equal the unmasked path
    /// (the mask excludes nothing)。 Cross-checks the masked
    /// kernel against the ALREADY-GATED unmasked kernel,not just
    /// the CPU reference。
    func testMaskedWithAllZeroMaskEqualsUnmasked() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (3, 4, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)
        let zeroMask = [UInt8](repeating: 0, count: M * N)

        let masked = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv,
            mask: zeroMask)
        let unmasked = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv)

        XCTAssertEqual(masked.count, unmasked.count)
        let mae = meanAbsError(masked, unmasked)
        XCTAssertLessThanOrEqual(
            mae, Self.parityTolerance,
            "all-zero-mask masked path should equal unmasked " +
            "path — MAE \(mae) > \(Self.parityTolerance)")
    }

    // MARK: - PARITY: causal GPU vs causal CPU

    /// GPU `flash_attention_forward_causal` vs the causal CPU
    /// reference (square M == N so the triangle is well-defined)。
    func testCausalFlashMatchesCPUReference() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (5, 5, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)

        let gpu = try await dispatcher.dispatchCausal(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let cpu = cpuCausalAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv)

        XCTAssertEqual(gpu.count, cpu.count)
        let mae = meanAbsError(gpu, cpu)
        XCTAssertLessThanOrEqual(
            mae, Self.parityTolerance,
            "causal GPU vs CPU MAE \(mae) exceeds tolerance " +
            "\(Self.parityTolerance)。 gpu=\(gpu) cpu=\(cpu)")
        for idx in 0..<cpu.count {
            XCTAssertEqual(
                gpu[idx], cpu[idx],
                accuracy: Self.parityTolerance,
                "causal cell \(idx) diverges: gpu=\(gpu[idx]) " +
                "cpu=\(cpu[idx])")
        }
    }

    /// Causal kernel MUST equal the masked kernel fed an explicit
    /// lower-triangular mask — two independent GPU paths that
    /// should converge,a second cross-check beyond the CPU ref。
    func testCausalEqualsExplicitTriangularMask() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (5, 5, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)

        // Explicit causal mask: exclude (i, j) where j > i。
        var triMask = [UInt8](repeating: 0, count: M * N)
        for i in 0..<M {
            for j in 0..<N where j > i {
                triMask[i * N + j] = 1
            }
        }

        let causal = try await dispatcher.dispatchCausal(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv)
        let maskedTri = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv,
            mask: triMask)

        XCTAssertEqual(causal.count, maskedTri.count)
        let mae = meanAbsError(causal, maskedTri)
        XCTAssertLessThanOrEqual(
            mae, Self.parityTolerance,
            "causal kernel should equal explicit-triangular " +
            "masked kernel — MAE \(mae) > \(Self.parityTolerance)")
    }

    // MARK: - Host-side validation guards

    /// Masked dispatch with a wrong-length mask must throw the
    /// typed maskShapeMismatch BEFORE any GPU dispatch — the
    /// host-side bound that backs the in-shader read guard。
    func testMaskedWrongLengthMaskThrows() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (3, 4, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)
        let shortMask = [UInt8](repeating: 0, count: M * N - 1)
        do {
            _ = try await dispatcher.dispatch(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N, v: v, vCols: Dv,
                mask: shortMask)
            XCTFail("wrong-length mask must throw")
        } catch BASMetalFlashAttentionDispatcherError
            .maskShapeMismatch
        {
            // expected
        }
    }

    /// Causal dispatch still enforces the head-dim cap (host-side
    /// guard that backs the in-shader D_MAX early-out)。
    func testCausalHeadDimCapThrows() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let D = 128 // > dMax (64)
        let q = [Float](repeating: 0.1, count: 1 * D)
        let k = [Float](repeating: 0.1, count: 1 * D)
        let v = [Float](repeating: 0.1, count: 1 * D)
        do {
            _ = try await dispatcher.dispatchCausal(
                q: q, qRows: 1, qCols: D,
                k: k, kRows: 1, v: v, vCols: D)
            XCTFail("causal head-dim cap must throw")
        } catch BASMetalFlashAttentionDispatcherError
            .maxHeadDimExceeded
        {
            // expected
        }
    }

    /// Memoization: after a causal + masked dispatch the
    /// dispatcher should report BOTH pipelines memoized (lazy
    /// build happened + cached)。
    func testMaskedAndCausalPipelinesMemoize() async throws {
        let dispatcher = try makeDispatcherOrSkip()
        let (M, N, D, Dv) = (2, 3, 8, 8)
        let (q, k, v) = makeInputs(M: M, N: N, D: D, Dv: Dv)
        let zeroMask = [UInt8](repeating: 0, count: M * N)

        let preMasked = await dispatcher.hasMemoizedMaskedPipeline
        let preCausal = await dispatcher.hasMemoizedCausalPipeline
        XCTAssertFalse(preMasked, "masked pipeline pre-dispatch")
        XCTAssertFalse(preCausal, "causal pipeline pre-dispatch")

        _ = try await dispatcher.dispatch(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv, mask: zeroMask)
        _ = try await dispatcher.dispatchCausal(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N, v: v, vCols: Dv)

        let postMasked = await dispatcher.hasMemoizedMaskedPipeline
        let postCausal = await dispatcher.hasMemoizedCausalPipeline
        XCTAssertTrue(postMasked, "masked pipeline memoized")
        XCTAssertTrue(postCausal, "causal pipeline memoized")
    }
}
#endif
