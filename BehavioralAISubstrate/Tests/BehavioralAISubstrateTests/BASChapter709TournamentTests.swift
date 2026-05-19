// MARK: - BASChapter709TournamentTests
// chapter 七百九 第三刀 / M2218
//
// Measures Swift naive vs Rust scalar vs Rust SIMD per dim
// for softmax + layer_norm。 No Metal contestant here:the
// substrate has Metal softmax + layernorm kernels but at small
// dims they're dwarfed by GPU pipeline overhead — chapter
// 七百九 第四刀 router stays CPU-only for these primitives at
// reasonable per-row sizes。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

import BASRustMemoryTrackerBinary

final class BASChapter709TournamentTests: XCTestCase {

    private func makeVec(_ n: Int) -> [Float] {
        return (0..<n).map { i in
            Float((i % 64)) * 0.05 - 0.4
        }
    }

    // MARK: - Softmax

    private func softmaxSwiftNaive(
        _ x: [Float], _ out: inout [Float]
    ) {
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
    }

    private func softmaxTournament(dim: Int) {
        let x = makeVec(dim)
        var outSwift = [Float](repeating: 0, count: dim)
        var outRustScalar = [Float](
            repeating: 0, count: dim)
        var outRustSimd = [Float](
            repeating: 0, count: dim)
        var sink: Float = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 100, rounds: 3, iterations: 500,
            contestants: [
                ("Swift naive", {
                    self.softmaxSwiftNaive(
                        x, &outSwift)
                    sink = sink + outSwift[0]
                }),
                ("Rust scalar", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outRustScalar
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_softmax(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outRustScalar[0]
                }),
                ("Rust SIMD", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outRustSimd
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_softmax_simd(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count)
                        }
                    }
                    sink = sink + outRustSimd[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print("BENCH softmax(dim=\(dim)) — winner: " +
            winner.label)
        for s in res.summaries {
            print("  " + s.formatted)
        }
        _ = sink
    }

    func testSoftmaxDim16() { softmaxTournament(dim: 16) }
    func testSoftmaxDim64() { softmaxTournament(dim: 64) }
    func testSoftmaxDim256() { softmaxTournament(dim: 256) }
    func testSoftmaxDim1024() {
        softmaxTournament(dim: 1024)
    }

    // MARK: - LayerNorm

    private func layerNormSwiftNaive(
        _ x: [Float], _ out: inout [Float], eps: Float
    ) {
        let n = x.count
        var sum: Float = 0
        for v in x { sum += v }
        let mean = sum / Float(n)
        var varSum: Float = 0
        for v in x {
            let d = v - mean
            varSum += d * d
        }
        let variance = varSum / Float(n)
        let invStd = 1.0 / (variance + eps).squareRoot()
        for i in 0..<n {
            out[i] = (x[i] - mean) * invStd
        }
    }

    private func layerNormTournament(dim: Int) {
        let x = makeVec(dim)
        let gamma = [Float](repeating: 1.0, count: dim)
        let beta = [Float](repeating: 0.0, count: dim)
        var outSwift = [Float](
            repeating: 0, count: dim)
        var outRustNaive = [Float](
            repeating: 0, count: dim)
        var outRustWelford = [Float](
            repeating: 0, count: dim)
        var outRustAffine = [Float](
            repeating: 0, count: dim)
        var sink: Float = 0
        let eps: Float = 1e-5

        let res = BASBenchmarkHarness.tournament(
            warmup: 100, rounds: 3, iterations: 500,
            contestants: [
                ("Swift naive", {
                    self.layerNormSwiftNaive(
                        x, &outSwift, eps: eps)
                    sink = sink + outSwift[0]
                }),
                ("Rust naive", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outRustNaive
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_layer_norm(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count,
                                eps)
                        }
                    }
                    sink = sink + outRustNaive[0]
                }),
                ("Rust Welford", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        outRustWelford
                            .withUnsafeMutableBufferPointer
                                { op in
                            bas_ranker_layer_norm_welford(
                                xp.baseAddress, dim,
                                op.baseAddress, op.count,
                                eps)
                        }
                    }
                    sink = sink + outRustWelford[0]
                }),
                ("Rust affine SIMD", {
                    let _ = x.withUnsafeBufferPointer
                        { xp in
                        gamma.withUnsafeBufferPointer
                            { gp in
                            beta.withUnsafeBufferPointer
                                { bp in
                                outRustAffine
                                    .withUnsafeMutableBufferPointer
                                        { op in
                                    bas_ranker_layer_norm_affine_simd(
                                        xp.baseAddress, dim,
                                        gp.baseAddress, gamma.count,
                                        bp.baseAddress, beta.count,
                                        op.baseAddress, op.count,
                                        eps)
                                }
                            }
                        }
                    }
                    sink = sink + outRustAffine[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print(
            "BENCH layer_norm(dim=\(dim)) — winner: " +
            winner.label)
        for s in res.summaries {
            print("  " + s.formatted)
        }
        _ = sink
    }

    func testLayerNormDim16() { layerNormTournament(dim: 16) }
    func testLayerNormDim64() { layerNormTournament(dim: 64) }
    func testLayerNormDim256() {
        layerNormTournament(dim: 256)
    }
    func testLayerNormDim1024() {
        layerNormTournament(dim: 1024)
    }
}
