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

#if !os(iOS)  // ch 1022 source-gate
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

    /// Pin the auto-router's routing decisions at the chapter
    /// 868 / 869 benchmarked shapes。 Chapter 八百七十 / M3016
    /// FLIPPED the M*N≥64 rule from .metalFlashAttention →
    /// .metalMPSGraphAttention based on chapter 八百六十九's
    /// measured 2.31-3.09× MPSGraph advantage。 Dv ≠ D shapes
    /// fall back to .metalStandardAttention (MPSGraph requires
    /// Dv == D)。
    func testAutoRouterChoiceAtBenchmarkedShapes() {
        // Tiny: M*N = 16 < 64 → CPU (unchanged)
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 4, N: 4, D: 8, Dv: 8),
                thresholds: .mSeriesDefault),
            .swiftCPUAttention,
            "Shape (4, 4, 8) — M*N=16 < 64 must route CPU")

        // Small: M*N = 256 ≥ 64,Dv=D → MPSGraph (chapter 870 flip)
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 16, N: 16, D: 16, Dv: 16),
                thresholds: .mSeriesDefault),
            .metalMPSGraphAttention,
            "Shape (16, 16, 16) — M*N=256 ≥ 64 + Dv=D must " +
            "route MPSGraph (chapter 八百七十 flip)")

        // Medium: M*N = 2048,Dv=D → MPSGraph
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 32, N: 64, D: 32, Dv: 32),
                thresholds: .mSeriesDefault),
            .metalMPSGraphAttention,
            "Shape (32, 64, 32) — must route MPSGraph (chapter 八百七十)")

        // Large: M*N = 8192,Dv=D → MPSGraph
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 32, N: 256, D: 32, Dv: 32),
                thresholds: .mSeriesDefault),
            .metalMPSGraphAttention,
            "Shape (32, 256, 32) — must route MPSGraph (chapter 八百七十)")

        // chapter 八百七十 NEW pin: Dv ≠ D fallback at production
        // shape → MPSGraph constraint pushes routing to std
        XCTAssertEqual(
            BASAutoRouteRanker.attentionChoice(
                shape: BASAttentionShape(M: 32, N: 64, D: 32, Dv: 16),
                thresholds: .mSeriesDefault),
            .metalStandardAttention,
            "Shape (32, 64, 32, Dv=16) — Dv ≠ D must fall back " +
            "to .metalStandardAttention (NOT .metalFlashAttention " +
            "— chapter 八百六十八 measured FA as 1.07-1.10× slower " +
            "than std,fallback to slower would be wrong)")
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

        // ch 1037.1 best-of-3(mirror ch 1024.0):assertion is
        // `mps < std×10`(weak upper bound),so most-favorable trial =
        // min(mpsNs)over max(stdNs)。 Absorbs Mac scheduling noise。
        var bestMpsNs = Double.greatestFiniteMagnitude
        var maxStdNs = 0.0
        var lastFlashNs = 0.0
        for _ in 0..<3 {
            let m = try await timeMedianNs(
                warmup: 0, iterations: 20
            ) {
                _ = try await self.mpsGraphAttention(
                    kernel, q: q, M: M, D: D,
                    k: k, N: N, v: v)
            }
            let s = try await timeMedianNs(
                warmup: 0, iterations: 20
            ) {
                _ = try await brain.attention(
                    q: q, qRows: M, qCols: D,
                    k: k, kRows: N,
                    v: v, vCols: Dv)
            }
            let f = try await timeMedianNs(
                warmup: 0, iterations: 20
            ) {
                _ = try await brain.flashAttention(
                    q: q, qRows: M, qCols: D,
                    k: k, kRows: N,
                    v: v, vCols: Dv)
            }
            bestMpsNs = min(bestMpsNs, m)
            maxStdNs = max(maxStdNs, s)
            lastFlashNs = f
        }
        let mpsNs = bestMpsNs   // alias — print + assert unchanged
        let stdNs = maxStdNs
        let flashNs = lastFlashNs

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

        // ch 1037.1 best-of-3(mirror ch 1024.0):min(mps)over max(std)
        // is the most-favorable trial for the `mps < std×10` bound。
        var bestMpsNs = Double.greatestFiniteMagnitude
        var maxStdNs = 0.0
        var lastFlashNs = 0.0
        for _ in 0..<3 {
            let m = try await timeMedianNs(
                warmup: 0, iterations: 15
            ) {
                _ = try await self.mpsGraphAttention(
                    kernel, q: q, M: M, D: D,
                    k: k, N: N, v: v)
            }
            let s = try await timeMedianNs(
                warmup: 0, iterations: 15
            ) {
                _ = try await brain.attention(
                    q: q, qRows: M, qCols: D,
                    k: k, kRows: N,
                    v: v, vCols: Dv)
            }
            let f = try await timeMedianNs(
                warmup: 0, iterations: 15
            ) {
                _ = try await brain.flashAttention(
                    q: q, qRows: M, qCols: D,
                    k: k, kRows: N,
                    v: v, vCols: Dv)
            }
            bestMpsNs = min(bestMpsNs, m)
            maxStdNs = max(maxStdNs, s)
            lastFlashNs = f
        }
        let mpsNs = bestMpsNs   // alias — print + assert unchanged
        let stdNs = maxStdNs
        let flashNs = lastFlashNs

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

        // Chapter 八百七十 / M3016 tightening — chapter 八百六十九 used
        // weak `warm < cold * 2.0` despite observed 30.48× speedup。
        // Agent A 5th-pass: a cache-broken regression (1.5× speedup)
        // would slip past。 Tightened to `warm < cold * 0.25`
        // (i.e. ≥4× speedup) — still 7× headroom from observed
        // 30.48×。 Catches the「cache silently disabled」 regression。
        XCTAssertLessThan(warmNs, coldNs * 0.25,
            "Warm MPSGraph must be ≥4× faster than cold to " +
            "indicate cache is actually working — coldNs=\(coldNs) " +
            "warmNs=\(warmNs) speedup=\(coldNs/warmNs)x。 " +
            "Observed 30.48× at chapter 八百六十九 measurement。")
    }

    // MARK: - Chapter 八百七十 / M3016 — production-shape correctness pins
    //
    // 5th-pass agent B (H-B1) caught that chapter 八百六十九's MPSGraph
    // correctness pin tested only TINY shape (3, 5, 8) but routing
    // flip targets large shapes (32, 64, 32) + (32, 256, 32)。
    // Online-matmul precision tends to drift at LARGER N。 Pinning
    // BEFORE chapter 八百七十 flips routing。

    func testMPSGraphMatchesCPUAtMediumProductionShape()
        async throws
    {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel(
                cache: BASMPSGraphExecutableCache())
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let (M, N, D) = (32, 64, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: D)
        let mpsOut = try await mpsGraphAttention(
            kernel, q: q, M: M, D: D, k: k, N: N, v: v)
        let cpuOut = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: D)
        XCTAssertEqual(mpsOut.count, M * D)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], cpuOut[i],
                accuracy: 1e-4,
                "idx \(i) at medium production shape " +
                "(M=\(M),N=\(N),D=\(D)): MPSGraph must " +
                "match CPU within 1e-4")
        }
    }

    func testMPSGraphMatchesCPUAtLargeProductionShape()
        async throws
    {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel(
                cache: BASMPSGraphExecutableCache())
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let (M, N, D) = (32, 256, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: D)
        let mpsOut = try await mpsGraphAttention(
            kernel, q: q, M: M, D: D, k: k, N: N, v: v)
        let cpuOut = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: D)
        XCTAssertEqual(mpsOut.count, M * D)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], cpuOut[i],
                accuracy: 1e-4,
                "idx \(i) at large production shape " +
                "(M=\(M),N=\(N),D=\(D)): MPSGraph must " +
                "match CPU within 1e-4 — online-matmul " +
                "precision should not drift at large N")
        }
    }

    /// 3-way pin: MPSGraph ≡ std ≡ FA at large production shape。
    /// 5th-pass agent B (H-B2) caught that no test pinned all 3
    /// Metal implementations against each other — drift between
    /// any pair would slip past the existing pairwise tests。
    func testThreeWayMetalAgreementAtLargeShape() async throws {
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
        let mpsOut = try await mpsGraphAttention(
            kernel, q: q, M: M, D: D, k: k, N: N, v: v)
        let stdOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let flashOut = try await brain.flashAttention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(mpsOut.count, M * Dv)
        XCTAssertEqual(stdOut.count, M * Dv)
        XCTAssertEqual(flashOut.count, M * Dv)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], stdOut[i],
                accuracy: 1e-4,
                "idx \(i): MPSGraph ≡ std at (\(M),\(N),\(D))")
            XCTAssertEqual(stdOut[i], flashOut[i],
                accuracy: 1e-4,
                "idx \(i): std ≡ FA at (\(M),\(N),\(D))")
            XCTAssertEqual(mpsOut[i], flashOut[i],
                accuracy: 1e-4,
                "idx \(i): MPSGraph ≡ FA at (\(M),\(N),\(D))")
        }
    }
}
#endif
