// MARK: - BASChapter711ActivationTournamentTests
// chapter 七百十一 第三刀 / M2228
//
// Tournament across (Swift naive,Rust scalar,Rust SIMD) for
// each activation × dim。 Same pattern as chapter 七百九
// softmax/layer_norm tournaments — CPU-only,since at typical
// per-row activation sizes (dim 64-2048) the Metal pipeline
// dispatch overhead would dwarf the actual compute。
//
// Use this output to pick the .geluSIMDMinDim + .siluSIMDMinDim
// crossovers in chapter 七百十一 第四刀 BASAutoRouteThresholds。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter711ActivationTournamentTests:
    XCTestCase
{
    /// Chapter 八百七十九 / M3080 — print-only archive skip per
    /// chapter 709/712 pattern。 Activation tournaments don't
    /// have asserted-bench replacement yet。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 八百七十九 archive skip — print-only" +
            " activation tournament without asserted-bench" +
            " replacement yet。")
    }

    private func makeVec(_ n: Int) -> [Float] {
        return (0..<n).map { i in
            Float((i % 64)) * 0.05 - 0.4
        }
    }

    // MARK: - Swift baselines (NIST-style oracle paths)

    private static let invSqrt2: Float = 0.70710678118654752
    private static let sqrt2OverPi: Float = 0.7978845608028654
    private static let geluCubicCoeff: Float = 0.044715

    /// Abramowitz & Stegun 7.1.26 erf — same coefficients as the
    /// Rust impl,so the comparison is apples-to-apples (not
    /// HW erf vs A&S)。
    private static func erfApprox(_ x: Float) -> Float {
        let p: Float = 0.3275911
        let a1: Float = 0.254829592
        let a2: Float = -0.284496736
        let a3: Float = 1.421413741
        let a4: Float = -1.453152027
        let a5: Float = 1.061405429
        let sign: Float = x < 0 ? -1.0 : 1.0
        let ax = abs(x)
        let t: Float = 1.0 / (1.0 + p * ax)
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t
        let poly = a1 * t + a2 * t2 + a3 * t3
            + a4 * t4 + a5 * t5
        return sign * (1.0 - poly * expf(-(ax * ax)))
    }

    private func geluExactSwift(
        _ x: [Float], _ out: inout [Float]
    ) {
        for i in 0..<x.count {
            let v = x[i]
            out[i] = 0.5 * v * (1.0
                + Self.erfApprox(v * Self.invSqrt2))
        }
    }

    private func geluTanhApproxSwift(
        _ x: [Float], _ out: inout [Float]
    ) {
        for i in 0..<x.count {
            let v = x[i]
            let cube = v * v * v
            let inner = Self.sqrt2OverPi
                * (v + Self.geluCubicCoeff * cube)
            out[i] = 0.5 * v * (1.0 + tanhf(inner))
        }
    }

    private func siluSwift(
        _ x: [Float], _ out: inout [Float]
    ) {
        for i in 0..<x.count {
            let v = x[i]
            let sig: Float = 1.0 / (1.0 + expf(-v))
            out[i] = v * sig
        }
    }

    // MARK: - GELU exact tournament

    private func geluExactTournament(dim: Int) {
        let x = makeVec(dim)
        var outSwift = [Float](repeating: 0, count: dim)
        var outScalar = [Float](repeating: 0, count: dim)
        var outSimd = [Float](repeating: 0, count: dim)
        var sink: Float = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 100, rounds: 3, iterations: 500,
            contestants: [
                ("Swift naive", {
                    self.geluExactSwift(x, &outSwift)
                    sink = sink + outSwift[0]
                }),
                ("Rust scalar", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outScalar
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_gelu_exact(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outScalar[0]
                }),
                ("Rust SIMD", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outSimd
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_gelu_exact_simd(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outSimd[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print(
            "BENCH gelu_exact(dim=\(dim)) — winner: "
            + winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = sink
    }

    func testGeluExactDim16()   { geluExactTournament(dim: 16) }
    func testGeluExactDim64()   { geluExactTournament(dim: 64) }
    func testGeluExactDim256()  { geluExactTournament(dim: 256) }
    func testGeluExactDim1024() { geluExactTournament(dim: 1024) }
    func testGeluExactDim4096() { geluExactTournament(dim: 4096) }

    // MARK: - GELU tanh-approx tournament

    private func geluTanhTournament(dim: Int) {
        let x = makeVec(dim)
        var outSwift = [Float](repeating: 0, count: dim)
        var outScalar = [Float](repeating: 0, count: dim)
        var outSimd = [Float](repeating: 0, count: dim)
        var sink: Float = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 100, rounds: 3, iterations: 500,
            contestants: [
                ("Swift naive", {
                    self.geluTanhApproxSwift(x, &outSwift)
                    sink = sink + outSwift[0]
                }),
                ("Rust scalar", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outScalar
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_gelu_tanh_approx(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outScalar[0]
                }),
                ("Rust SIMD", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outSimd
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_gelu_tanh_approx_simd(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outSimd[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print(
            "BENCH gelu_tanh(dim=\(dim)) — winner: "
            + winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = sink
    }

    func testGeluTanhDim16()   { geluTanhTournament(dim: 16) }
    func testGeluTanhDim64()   { geluTanhTournament(dim: 64) }
    func testGeluTanhDim256()  { geluTanhTournament(dim: 256) }
    func testGeluTanhDim1024() { geluTanhTournament(dim: 1024) }
    func testGeluTanhDim4096() { geluTanhTournament(dim: 4096) }

    // MARK: - SiLU tournament

    private func siluTournament(dim: Int) {
        let x = makeVec(dim)
        var outSwift = [Float](repeating: 0, count: dim)
        var outScalar = [Float](repeating: 0, count: dim)
        var outSimd = [Float](repeating: 0, count: dim)
        var sink: Float = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 100, rounds: 3, iterations: 500,
            contestants: [
                ("Swift naive", {
                    self.siluSwift(x, &outSwift)
                    sink = sink + outSwift[0]
                }),
                ("Rust scalar", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outScalar
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_silu(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outScalar[0]
                }),
                ("Rust SIMD", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outSimd
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_silu_simd(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outSimd[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print(
            "BENCH silu(dim=\(dim)) — winner: "
            + winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = sink
    }

    func testSiluDim16()   { siluTournament(dim: 16) }
    func testSiluDim64()   { siluTournament(dim: 64) }
    func testSiluDim256()  { siluTournament(dim: 256) }
    func testSiluDim1024() { siluTournament(dim: 1024) }
    func testSiluDim4096() { siluTournament(dim: 4096) }
}
