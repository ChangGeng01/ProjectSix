// MARK: - BASChapter707AttentionTournamentTests
// chapter 七百七 第二刀 / M2207
//
// DEPRECATED post chapter 八百七十八 / M3070 — superseded by
// `BASChapter868FlashAttentionAssertedBenchmarkTests` which has
// ASSERTED bounds (≥2× over Swift,≤1.4×/1.3× FA vs std)。 This
// file's 4 tests are print-only (zero XCTAssert) so consume CI
// time without catching regressions。 Kept in tree as the live-
// data reference layer below the asserted layer per chapter 868
// `testChapter707TournamentStillReachable` pin。 Consider
// archiving in a future cleanup chapter once the chapter 868
// asserted bench has been stable across N CI runs (currently
// stable for ~10 runs as of chapter 877)。
//
// Empirically measures which attention implementation wins at
// each (M, N, D) configuration:
//
//   - Swift CPU reference (slow but always correct)
//   - Metal standard scaled_dot_product_attention
//   - Metal FlashAttention tiled
//
// The harness reports per-iter wall-clock per implementation
// per shape so the chapter-七百七-第三刀 auto-router can encode
// the crossover thresholds。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter707AttentionTournamentTests:
    XCTestCase
{

    /// Swift CPU reference — naive O(M*N*D) implementation。
    /// Used as the "always correct, but slow" contestant in
    /// the tournament + as the verification ground truth。
    private func cpuAttention(
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

    /// Tournament at a single shape。 Prints per-impl timings
    /// + winner。
    private func attentionTournament(
        M: Int, N: Int, D: Int, Dv: Int,
        iterations: Int
    ) async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        var sinkCPU: Float = 0
        var sinkStd: Float = 0
        var sinkFlash: Float = 0

        // Warm Metal pipelines
        for _ in 0..<5 {
            let _ = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            let _ = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        // CPU reference timing
        let cpuStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let o = cpuAttention(
                q: q, M: M, D: D,
                k: k, N: N,
                v: v, Dv: Dv)
            sinkCPU = sinkCPU + o[0]
        }
        let cpuEnd = DispatchTime.now().uptimeNanoseconds
        let cpuMs =
            Double(cpuEnd - cpuStart) / 1_000_000

        // Metal standard
        let stdStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let o = try await brain.attention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            sinkStd = sinkStd + o[0]
        }
        let stdEnd = DispatchTime.now().uptimeNanoseconds
        let stdMs =
            Double(stdEnd - stdStart) / 1_000_000

        // Metal FlashAttention
        let flashStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let o = try await brain.flashAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            sinkFlash = sinkFlash + o[0]
        }
        let flashEnd =
            DispatchTime.now().uptimeNanoseconds
        let flashMs =
            Double(flashEnd - flashStart) / 1_000_000

        let cpuPerIter = cpuMs * 1_000_000 / Double(iterations)
        let stdPerIter =
            stdMs * 1_000_000 / Double(iterations)
        let flashPerIter =
            flashMs * 1_000_000 / Double(iterations)

        var winner = "CPU"
        var winnerMs = cpuPerIter
        if stdPerIter < winnerMs {
            winner = "Metal std"
            winnerMs = stdPerIter
        }
        if flashPerIter < winnerMs {
            winner = "Metal Flash"
            winnerMs = flashPerIter
        }

        print(String(
            format:
            "BENCH attention(M=%d,N=%d,D=%d) — winner: %@\n" +
            "  CPU         = %8.1f ns/iter\n" +
            "  Metal std   = %8.1f ns/iter\n" +
            "  Metal Flash = %8.1f ns/iter",
            M, N, D, winner as NSString,
            cpuPerIter, stdPerIter, flashPerIter))
        _ = sinkCPU
        _ = sinkStd
        _ = sinkFlash
    }

    // MARK: - Tournaments at multiple shapes

    func testAttentionTournamentTiny() async throws {
        try await attentionTournament(
            M: 4, N: 4, D: 8, Dv: 8, iterations: 200)
    }

    func testAttentionTournamentSmall() async throws {
        try await attentionTournament(
            M: 16, N: 16, D: 16, Dv: 16, iterations: 100)
    }

    func testAttentionTournamentMediumSequence() async throws {
        try await attentionTournament(
            M: 32, N: 64, D: 32, Dv: 32, iterations: 50)
    }

    func testAttentionTournamentLargeSequence() async throws {
        try await attentionTournament(
            M: 32, N: 256, D: 32, Dv: 32, iterations: 20)
    }
}
