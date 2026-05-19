// MARK: - BASMetalAttentionTests
// 主线 全面 开发: Metal single-head scaled dot-product
// attention kernel。 Pins:
//   - Self-attention on uniform inputs → uniform output
//   - Known small attention result matches CPU reference
//   - softmax numerical stability (large scaled scores)
//   - Shape validation throws

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASMetalAttentionTests: XCTestCase {

    // CPU reference implementation for comparison。 Same
    // algorithm as the MSL kernel — used to verify GPU
    // output within float32 tolerance。
    private func cpuAttention(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int
    ) -> [Float] {
        let invSqrtD = 1.0 / sqrtf(Float(D))
        var out = [Float](repeating: 0, count: M * Dv)
        for i in 0..<M {
            // scaled scores
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
            // softmax denominator
            var expSum: Float = 0
            var exps = [Float](
                repeating: 0, count: N)
            for kk in 0..<N {
                exps[kk] = expf(
                    scaled[kk] - maxScore)
                expSum += exps[kk]
            }
            // weighted sum
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

    // MARK: - Self-attention on identity-like inputs

    func testAttentionUniformOutputs() async throws {
        // When all keys are identical AND all values
        // are identical,attention output = the value
        // (uniform softmax weights × identical V →
        // identical V)。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let M = 2
        let N = 3
        let D = 4
        let Dv = 2
        let q = [Float](
            repeating: 0.5, count: M * D)
        let k = [Float](
            repeating: 0.5, count: N * D)
        let v: [Float] = [
            1.0, 2.0,  // row 0
            1.0, 2.0,  // row 1
            1.0, 2.0,  // row 2
        ]
        let out = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(out.count, M * Dv)
        for i in 0..<M {
            XCTAssertEqual(
                out[i * Dv + 0], 1.0,
                accuracy: 1e-4)
            XCTAssertEqual(
                out[i * Dv + 1], 2.0,
                accuracy: 1e-4)
        }
    }

    // MARK: - GPU vs CPU reference parity

    func testAttentionMatchesCPUReference() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // Deterministic pseudo-random inputs
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525
                &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let M = 3
        let N = 4
        let D = 8
        let Dv = 5
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }
        let gpuOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let cpuOut = cpuAttention(
            q: q, M: M, D: D,
            k: k, N: N,
            v: v, Dv: Dv)
        XCTAssertEqual(gpuOut.count, cpuOut.count)
        for idx in 0..<gpuOut.count {
            XCTAssertEqual(gpuOut[idx], cpuOut[idx],
                accuracy: 1e-4,
                "GPU attention output cell \(idx)" +
                " diverges from CPU reference")
        }
    }

    // MARK: - Softmax numerical stability

    func testAttentionNumericalStabilityLargeScores()
        async throws
    {
        // Large-magnitude inputs would overflow naive
        // softmax。 Max-subtract trick (in both the
        // MSL kernel + CPU reference) prevents this。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let M = 1, N = 3, D = 4, Dv = 2
        let q: [Float] = [10, 10, 10, 10]
        let k: [Float] = [
            10, 10, 10, 10,
            10, 10, 10, 10,
            10, 10, 10, 10,
        ]
        let v: [Float] = [
            0.5, 1.5,
            0.5, 1.5,
            0.5, 1.5,
        ]
        let out = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        // All key/value rows are identical → uniform
        // softmax → output = first row of V
        XCTAssertEqual(out[0], 0.5, accuracy: 1e-4)
        XCTAssertEqual(out[1], 1.5, accuracy: 1e-4)
        for v in out {
            XCTAssertFalse(v.isNaN,
                "Large-magnitude inputs must not" +
                " produce NaN (softmax max-subtract" +
                " stabilizes)")
        }
    }

    // MARK: - Shape validation

    func testAttentionShapeMismatchQ() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.attention(
                q: [1.0, 2.0],  // size 2,but shape says 2x2 = 4
                qRows: 2, qCols: 2,
                k: [1, 2, 3, 4], kRows: 2,
                v: [5, 6, 7, 8], vCols: 2)
            XCTFail("Q size mismatch must throw")
        } catch BASMetalAttentionDispatcherError
            .shapeMismatch
        {
            // expected
        }
    }

    func testAttentionShapeMismatchK() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.attention(
                q: [1, 2, 3, 4],
                qRows: 2, qCols: 2,
                k: [1, 2, 3],  // size 3,but shape says 2x2 = 4
                kRows: 2,
                v: [5, 6, 7, 8], vCols: 2)
            XCTFail("K size mismatch must throw")
        } catch BASMetalAttentionDispatcherError
            .shapeMismatch
        {
            // expected
        }
    }

    func testAttentionZeroDimensionThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.attention(
                q: [], qRows: 0, qCols: 2,
                k: [1, 2, 3, 4], kRows: 2,
                v: [5, 6, 7, 8], vCols: 2)
            XCTFail("Zero qRows must throw")
        } catch BASMetalAttentionDispatcherError
            .zeroDimension
        {
            // expected
        }
    }

    func testAttentionNoMetalLoaderThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()  // no Metal
        do {
            _ = try await brain.attention(
                q: [1, 2], qRows: 1, qCols: 2,
                k: [1, 2], kRows: 1,
                v: [3], vCols: 1)
            XCTFail("No loader must throw")
        } catch BASMetalAttentionDispatcherError
            .libraryUnavailable
        {
            // expected
        }
    }
}
