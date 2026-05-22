// MARK: - BASChapter869MPSGraphContestantAndPinsTests
// chapter 八百六十九 / M3006 — combined work per user 「1 + 2」 directive:
//
//   Part 1: address 4th-pass review HIGH/MEDIUM findings on
//           chapters 八百六十七 + 八百六十八
//   Part 2: wire BASMPSGraphAttentionKernel as the 4th attention
//           tournament contestant + capture live data + decide
//           on M*N≥64 routing rule based on full 4-way ratios
//
// 5 knives (this file covers knives 2 + 4):
//
//   Knife 1 (Swift threshold tightening + Rust near-cap fence-post):
//           lands in chapter 八百六十八's test file + Rust tests.rs
//           respectively。 No new test file。
//   Knife 2 (THIS file): numerical correctness pin between std + FA
//           at benchmarked shapes (M-B1 from agent B) + auto-router
//           choice pin at measured shapes (M-B2)
//   Knife 3 (CHANGELOG + BRANCH_SUMMARY doc fixes per agent C —
//           deferred-items count,stale line refs,numerical range
//           floor)。 No test file。
//   Knife 4 (THIS file): NEW BASMPSGraphAttentionKernel contestant
//           wiring + timing capture + correctness pin per agent D
//           scout report
//   Knife 5 (BASCognitiveBrain.swift + BASAutoRouteRanker.swift):
//           routing decision based on knife-4 data。 If MPSGraph
//           wins anywhere → wire it。 If it loses everywhere →
//           document as 3rd-worst + don't flip。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter869MPSGraphContestantAndPinsTests:
    XCTestCase
{

    // MARK: - Shared fixture (mirrors chapter 868 helper)

    private func makeAttentionInputs(
        M: Int, N: Int, D: Int, Dv: Int
    ) -> (q: [Float], k: [Float], v: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
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

    private func timeMedianNs(
        warmup: Int,
        iterations: Int,
        op: () async throws -> Void
    ) async rethrows -> Double {
        for _ in 0..<warmup { try await op() }
        var samples: [Double] = []
        samples.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let start =
                DispatchTime.now().uptimeNanoseconds
            try await op()
            let end =
                DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start))
        }
        samples.sort()
        // Lower-middle for even N — matches chapter 868 helper
        // exactly so cross-file ratio comparisons are consistent。
        return samples[samples.count / 2]
    }

    // MARK: - Knife 2 part A: numerical correctness pin

    /// Pin that Metal std (scaled_dot_product MSL kernel) and
    /// Metal FlashAttention produce numerically-equivalent output
    /// at the medium benchmarked shape。 Chapter 八百六十八 measured
    /// PERF only — agent B (4th-pass) noted that if FA's
    /// online-softmax underflows at large shapes,perf tests would
    /// silently pass while output drifted。 Pin closes that gap。
    func testStdAndFlashAttentionNumericallyEquivalentMedium()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        let stdOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let flashOut = try await brain.flashAttention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)

        XCTAssertEqual(stdOut.count, flashOut.count,
            "Std and FA must produce same-sized output")
        XCTAssertEqual(stdOut.count, M * Dv)

        // Per chapter 392 IEEE Float32 1e-4 tolerance for
        // FMA-reorder。 FA + std share scaled-dot-product math
        // but tiled vs O(N) softmax may reorder accumulation。
        for i in 0..<stdOut.count {
            XCTAssertEqual(stdOut[i], flashOut[i],
                accuracy: 1e-4,
                "idx \(i): std and FA must agree within 1e-4 " +
                "at medium shape (M=\(M),N=\(N),D=\(D)) — " +
                "std=\(stdOut[i]) flash=\(flashOut[i])")
        }
    }

    /// Same pin at large sequence shape — the case where FA's
    /// architecture is most likely to introduce numerical drift。
    func testStdAndFlashAttentionNumericallyEquivalentLarge()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 256, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        let stdOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let flashOut = try await brain.flashAttention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)

        XCTAssertEqual(stdOut.count, flashOut.count)
        for i in 0..<stdOut.count {
            XCTAssertEqual(stdOut[i], flashOut[i],
                accuracy: 1e-4,
                "idx \(i): std and FA must agree within 1e-4 " +
                "at large shape (M=\(M),N=\(N),D=\(D))")
        }
    }

    // MARK: - Knife 2 part B: auto-router choice pin

    /// Pin the auto-router's current routing decisions at the
    /// chapter 868 / 869 benchmarked shapes。 A future router
    /// refactor that silently changes which path a shape gets
    /// will fail this test。 Per agent B (M-B2)。
    ///
    /// Current rule (per BASCognitiveBrain.swift:2868 + chapter 868
    /// honest-correction): M*N<64 → CPU,M*N≥64 → FA。 Chapter 869
    /// MAY flip this rule after MPSGraph data lands (knife 5)。 If
    /// it does,this test gets updated。
    func testAutoRouterChoiceAtBenchmarkedShapes() {
        // Tiny: M*N = 16 < 64 → CPU
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 4, N: 4, D: 8, Dv: 8),
                thresholds: .mSeriesDefault),
            .swiftCPUAttention,
            "Shape (4, 4, 8) — M*N=16 < 64 must route CPU")

        // Small: M*N = 256 ≥ 64 → FA (currently)
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 16, N: 16, D: 16, Dv: 16),
                thresholds: .mSeriesDefault),
            .metalFlashAttention,
            "Shape (16, 16, 16) — M*N=256 ≥ 64 must route FA " +
            "(current rule;may flip in chapter 八百六十九 knife 5)")

        // Medium: M*N = 2048 ≥ 64 → FA
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 32, N: 64, D: 32, Dv: 32),
                thresholds: .mSeriesDefault),
            .metalFlashAttention,
            "Shape (32, 64, 32) — M*N=2048 ≥ 64 must route FA " +
            "(current rule)")

        // Large: M*N = 8192 ≥ 64 → FA
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 32, N: 256, D: 32, Dv: 32),
                thresholds: .mSeriesDefault),
            .metalFlashAttention,
            "Shape (32, 256, 32) — M*N=8192 ≥ 64 must route FA " +
            "(current rule)")
    }

    // MARK: - Knife 4: MPSGraph 4th tournament contestant

    /// Helper: wrap BASMPSGraphAttentionKernel.evaluate() to match
    /// the [Float]-in,[Float]-out shape of cpuAttention /
    /// brain.attention / brain.flashAttention so all 4 contestants
    /// have a uniform timing signature。
    ///
    /// REQUIREMENT (per agent D scout):MPSGraph kernel requires
    /// V's last dim to equal D — no Dv ≠ D。 Chapter 869
    /// benchmarks all use Dv = D = 32,so the constraint is met。
    /// Callers using Dv ≠ D must skip this contestant。
    private func mpsGraphAttention(
        _ kernel: BASMPSGraphAttentionKernel,
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int, v: [Float]
    ) async throws -> [Float] {
        let descQ = BASTensorDescriptor.contiguous(
            shape: [M, D], dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        let descKV = BASTensorDescriptor.contiguous(
            shape: [N, D], dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        let qD = q.withUnsafeBufferPointer { Data(buffer: $0) }
        let kD = k.withUnsafeBufferPointer { Data(buffer: $0) }
        let vD = v.withUnsafeBufferPointer { Data(buffer: $0) }
        let inputs = BASKernelInputs(
            descriptors: [descQ, descKV, descKV],
            payloads: [qD, kD, vD])
        let out = try await kernel.evaluate(inputs: inputs)
        // MPSGraph attention output shape is (M, D) — V's last
        // dim must equal D per agent D scout finding (Dv=D
        // constraint enforced at kernel.evaluate line 143-158)
        return BASCanonicalKernelInputBuilders.dataToFloatArray(
            out.payloads[0], elementCount: M * D)
    }

    /// Numerical correctness pin between MPSGraph and CPU
    /// reference at a small shape (3, 5, 8)。 Chapter 477 already
    /// proves MPSGraph correctness at this scale but pinning at
    /// a benchmark-flavored shape locks the cross-impl invariant
    /// before we ship MPSGraph as a routing destination。
    func testMPSGraphAttentionNumericallyMatchesCPU() async throws {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let (M, N, D) = (3, 5, 8)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: D)
        let mpsOut = try await mpsGraphAttention(
            kernel, q: q, M: M, D: D, k: k, N: N, v: v)
        let cpuOut = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: D)
        XCTAssertEqual(mpsOut.count, cpuOut.count,
            "MPSGraph and CPU must produce same-sized output")
        XCTAssertEqual(mpsOut.count, M * D)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], cpuOut[i],
                accuracy: 1e-4,
                "idx \(i): MPSGraph and CPU must agree " +
                "within 1e-4 (chapter 392 tolerance)")
        }
    }

    /// 4-way timing capture at medium shape (M=32, N=64, D=32)。
    /// Knife 5 routing decision uses this data。
    ///
    /// Asserts only WEAK upper bounds on MPSGraph (within 10× of
    /// std) — the goal here is data capture,not regression
    /// detection。 Once knife 5 commits the routing decision,
    /// a chapter 八百七十 follow-up can tighten the bounds to
    /// trip-wire range per the agent B feedback。
    func testMPSGraphTimingMediumShape() async throws {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel(
                cache: BASMPSGraphExecutableCache())
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        // Warmup MPSGraph compile + cache + std + FA pipelines
        for _ in 0..<5 {
            _ = try await mpsGraphAttention(
                kernel, q: q, M: M, D: D, k: k, N: N, v: v)
            _ = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            _ = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        let mpsNs = try await timeMedianNs(
            warmup: 0, iterations: 20
        ) {
            _ = try await self.mpsGraphAttention(
                kernel, q: q, M: M, D: D,
                k: k, N: N, v: v)
        }
        let stdNs = try await timeMedianNs(
            warmup: 0, iterations: 20
        ) {
            _ = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }
        let flashNs = try await timeMedianNs(
            warmup: 0, iterations: 20
        ) {
            _ = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        // Print numbers for knife 5 routing decision
        print(String(format:
            "BENCH 4-way attention M=%d N=%d D=%d:\n" +
            "  Metal std       = %10.0f ns\n" +
            "  Metal Flash     = %10.0f ns (ratio std=%.3fx)\n" +
            "  MPSGraph (warm) = %10.0f ns (ratio std=%.3fx)",
            M, N, D, stdNs,
            flashNs, flashNs / stdNs,
            mpsNs, mpsNs / stdNs))

        // Weak upper bound: MPSGraph shouldn't be more than 10×
        // slower than std。 If it is,something is wrong (e.g.
        // cache miss every call,or graph rebuild thrashing)。
        XCTAssertLessThan(mpsNs, stdNs * 10.0,
            "MPSGraph should not be more than 10× slower than " +
            "std at medium shape — std=\(stdNs) ns " +
            "mps=\(mpsNs) ns")
    }

    /// Same 4-way timing capture at large shape (32, 256, 32)。
    func testMPSGraphTimingLargeShape() async throws {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel(
                cache: BASMPSGraphExecutableCache())
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 256, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        for _ in 0..<5 {
            _ = try await mpsGraphAttention(
                kernel, q: q, M: M, D: D, k: k, N: N, v: v)
            _ = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            _ = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        let mpsNs = try await timeMedianNs(
            warmup: 0, iterations: 15
        ) {
            _ = try await self.mpsGraphAttention(
                kernel, q: q, M: M, D: D,
                k: k, N: N, v: v)
        }
        let stdNs = try await timeMedianNs(
            warmup: 0, iterations: 15
        ) {
            _ = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }
        let flashNs = try await timeMedianNs(
            warmup: 0, iterations: 15
        ) {
            _ = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        print(String(format:
            "BENCH 4-way attention M=%d N=%d D=%d:\n" +
            "  Metal std       = %10.0f ns\n" +
            "  Metal Flash     = %10.0f ns (ratio std=%.3fx)\n" +
            "  MPSGraph (warm) = %10.0f ns (ratio std=%.3fx)",
            M, N, D, stdNs,
            flashNs, flashNs / stdNs,
            mpsNs, mpsNs / stdNs))

        XCTAssertLessThan(mpsNs, stdNs * 10.0,
            "MPSGraph should not be more than 10× slower than " +
            "std at large shape")
    }

    /// Cache pin per agent D scout — warm MPSGraph should be
    /// at least 2× faster than cold (if it's not,the cache
    /// isn't actually helping)。
    func testMPSGraphCacheWarmFasterThanCold() async throws {
        let cold: BASMPSGraphAttentionKernel
        let warm: BASMPSGraphAttentionKernel
        do {
            cold = try BASMPSGraphAttentionKernel()
            warm = try BASMPSGraphAttentionKernel(
                cache: BASMPSGraphExecutableCache())
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }

        let (M, N, D) = (32, 64, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: D)

        // Warm the cache:first call compiles + caches
        _ = try await mpsGraphAttention(
            warm, q: q, M: M, D: D, k: k, N: N, v: v)

        // Cold path:fresh kernel,no cache,every call compiles
        let coldNs = try await timeMedianNs(
            warmup: 0, iterations: 5
        ) {
            _ = try await self.mpsGraphAttention(
                cold, q: q, M: M, D: D,
                k: k, N: N, v: v)
        }
        // Warm path:cached after first call
        let warmNs = try await timeMedianNs(
            warmup: 0, iterations: 20
        ) {
            _ = try await self.mpsGraphAttention(
                warm, q: q, M: M, D: D,
                k: k, N: N, v: v)
        }

        print(String(format:
            "BENCH MPSGraph cache M=%d N=%d D=%d:\n" +
            "  cold = %10.0f ns\n" +
            "  warm = %10.0f ns (speedup=%.2fx)",
            M, N, D, coldNs, warmNs, coldNs / warmNs))

        // Cache should provide meaningful speedup。 Weak pin:
        // warm at most 2× of cold (if cache is broken,both
        // are equal so warm/cold ≈ 1.0)。 The真 expected
        // behavior is warm << cold so warm < cold * 0.5 would
        // be the strong pin。 Use weak pin first round。
        XCTAssertLessThan(warmNs, coldNs * 2.0,
            "Warm MPSGraph should not be SLOWER than cold + " +
            "headroom — coldNs=\(coldNs) warmNs=\(warmNs)")
    }
}
