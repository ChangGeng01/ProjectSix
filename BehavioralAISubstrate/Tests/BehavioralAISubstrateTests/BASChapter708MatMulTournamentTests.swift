// MARK: - BASChapter708MatMulTournamentTests
// chapter 七百八 第二刀 / M2212
//
// DEPRECATED post chapter 八百七十八 / M3070 — superseded by
// `BASChapter871MatMul5WayBenchmarkTests` (5-way includes the
// true MPSGraph actor path,not just MSL — fixes the naming-
// legacy that chapter 七百八 baked in) + `BASChapter871BrainMPSGraphMatMulParityTests`
// (asserted bounds + fence-post + cache reuse pins)。 This file's
// 4 tests are print-only。 Same archive-candidate policy as
// chapter 707 attention tournament — keep as live-data reference
// until ~N stable CI runs of the chapter 871 asserted bench
// confirm replacement is robust。
//
// Empirically measures which MatMul implementation wins at
// each shape:
//   - Rust naive (reference)
//   - Rust cache-blocked
//   - Rust SIMD cache-blocked
//   - Metal MPSGraph
//
// Output drives the chapter-七百八-第三刀 auto-router thresholds。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter708MatMulTournamentTests:
    XCTestCase
{

    /// Chapter 八百七十八.5 / M3076 — deprecation-skip per chapter
    /// 707 pattern。 Chapter 871 has asserted-bench replacement
    /// (BASChapter871MatMul5WayBenchmarkTests + parity tests)。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 八百七十八.5 deprecation skip — " +
            "superseded by BASChapter871MatMul5WayBenchmarkTests" +
            " + BASChapter871BrainMPSGraphMatMulParityTests。")
    }

    /// Generate deterministic pseudo-random matrices for the
    /// tournament。 Same seed → same matrices,so re-runs are
    /// stable。
    private func makeMatrices(
        m: Int, n: Int, k: Int
    ) -> (a: [Float], b: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let a = (0..<(m * k)).map { _ in next() }
        let b = (0..<(k * n)).map { _ in next() }
        return (a, b)
    }

    private func tournamentAt(
        M: Int, N: Int, K: Int, iterations: Int
    ) async throws {
        let (a, b) = makeMatrices(m: M, n: N, k: K)
        var cNaive = [Float](repeating: 0, count: M * N)
        var cBlocked = [Float](repeating: 0, count: M * N)
        var cSimd = [Float](repeating: 0, count: M * N)
        var sinkNaive: Float = 0
        var sinkBlocked: Float = 0
        var sinkSimd: Float = 0
        var sinkMetal: Float = 0

        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()

        // Warm Metal
        for _ in 0..<3 {
            let _ = try await brain.matmul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        }

        // Rust naive
        let naiveStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cNaive.withUnsafeMutableBufferPointer
                        { cp in
                        bas_ranker_matmul_naive(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
            sinkNaive = sinkNaive + cNaive[0]
        }
        let naiveEnd =
            DispatchTime.now().uptimeNanoseconds
        let naiveNs =
            Double(naiveEnd - naiveStart)
                / Double(iterations)

        // Rust blocked
        let blockedStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cBlocked.withUnsafeMutableBufferPointer
                        { cp in
                        bas_ranker_matmul_blocked(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
            sinkBlocked = sinkBlocked + cBlocked[0]
        }
        let blockedEnd =
            DispatchTime.now().uptimeNanoseconds
        let blockedNs =
            Double(blockedEnd - blockedStart)
                / Double(iterations)

        // Rust SIMD blocked
        let simdStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cSimd.withUnsafeMutableBufferPointer
                        { cp in
                        bas_ranker_matmul_simd_blocked(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
            sinkSimd = sinkSimd + cSimd[0]
        }
        let simdEnd =
            DispatchTime.now().uptimeNanoseconds
        let simdNs =
            Double(simdEnd - simdStart)
                / Double(iterations)

        // Metal MPSGraph
        let metalStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let cMetal = try await brain.matmul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
            sinkMetal = sinkMetal + cMetal[0]
        }
        let metalEnd =
            DispatchTime.now().uptimeNanoseconds
        let metalNs =
            Double(metalEnd - metalStart)
                / Double(iterations)

        // Decide winner
        var winner = "Rust naive"
        var winnerNs = naiveNs
        if blockedNs < winnerNs {
            winner = "Rust blocked"
            winnerNs = blockedNs
        }
        if simdNs < winnerNs {
            winner = "Rust SIMD blocked"
            winnerNs = simdNs
        }
        if metalNs < winnerNs {
            winner = "Metal MPSGraph"
            winnerNs = metalNs
        }

        print(String(
            format:
            "BENCH matmul(%dx%dx%d) — winner: %@\n" +
            "  Rust naive        = %10.1f ns/iter\n" +
            "  Rust blocked      = %10.1f ns/iter\n" +
            "  Rust SIMD blocked = %10.1f ns/iter\n" +
            "  Metal MPSGraph    = %10.1f ns/iter",
            M, N, K, winner as NSString,
            naiveNs, blockedNs, simdNs, metalNs))

        _ = sinkNaive
        _ = sinkBlocked
        _ = sinkSimd
        _ = sinkMetal
    }

    func testMatMul8x8x8() async throws {
        try await tournamentAt(
            M: 8, N: 8, K: 8, iterations: 1000)
    }

    func testMatMul32x32x32() async throws {
        try await tournamentAt(
            M: 32, N: 32, K: 32, iterations: 200)
    }

    func testMatMul128x128x128() async throws {
        try await tournamentAt(
            M: 128, N: 128, K: 128, iterations: 30)
    }

    func testMatMul512x512x512() async throws {
        try await tournamentAt(
            M: 512, N: 512, K: 512, iterations: 5)
    }
}
