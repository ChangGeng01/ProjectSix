// MARK: - BASMPSGraphRotaryEmbeddingIntegrationTests
// chapter 四百七十六 / M1282
//
// Sibling of M1277 (matMul) + M1280 (rmsNorm) — extends
// "MPSGraph kernels actually compute correctly" PROOF
// coverage to BASMPSGraphRotaryEmbeddingKernel。
//
// Rotary positional embedding formula (per RoPE):
//   For each (s, i) where i < headDim/2:
//     y[s, 2i]   = x[s, 2i]   * cos[s, i]
//                - x[s, 2i+1] * sin[s, i]
//     y[s, 2i+1] = x[s, 2i]   * sin[s, i]
//                + x[s, 2i+1] * cos[s, i]
//
// Test inputs:
//   x = [[1, 0], [0, 1]] (seq=2, headDim=2)
// Identity rotation (cos=1, sin=0 for every position)
// should leave x unchanged。 90° rotation (cos=0, sin=1)
// rotates [a, b] → [-b, a]。

import XCTest
import Foundation
@testable import BASMetalSubstrate

final class BASMPSGraphRotaryEmbeddingIntegrationTests:
    XCTestCase
{

    // MARK: - Helpers

    /// Build rank-2 rotary inputs matching the kernel's
    /// actual signature (x: [seq, headDim]; cos/sin:
    /// [seq, headDim/2])。 M1276
    /// `BASCanonicalKernelInputBuilders.rotaryEmbedding`
    /// produces rank-3 input (with heads dim) — this
    /// helper feeds the rank-2 single-head case the
    /// kernel actually consumes。
    private func makeRotaryInputs(
        x: [Float],
        cos: [Float],
        sin: [Float],
        seqLen: Int,
        headDim: Int
    ) -> BASKernelInputs {
        let half = headDim / 2
        precondition(x.count == seqLen * headDim)
        precondition(cos.count == seqLen * half)
        precondition(sin.count == seqLen * half)
        let descX = BASTensorDescriptor(
            shape: [seqLen, headDim],
            strides: [headDim * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descCos = BASTensorDescriptor(
            shape: [seqLen, half],
            strides: [half * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descSin = BASTensorDescriptor(
            shape: [seqLen, half],
            strides: [half * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descX, descCos, descSin],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(x),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(cos),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(sin)
            ])
    }

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - Identity rotation preserves input

    /// cos=1, sin=0 ⇒ rotation matrix is identity。
    /// Output should equal input。
    func testIdentityRotationPreservesInput() async throws
    {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let x: [Float] = [1, 2, 3, 4]
        let cos: [Float] = [1, 1]  // seq=2, half=1
        let sin: [Float] = [0, 0]
        let inputs = makeRotaryInputs(
            x: x, cos: cos, sin: sin,
            seqLen: 2, headDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [2, 2])
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, x[idx], accuracy: 1e-4,
                "identity rotation must preserve" +
                " input[\(idx)] = \(x[idx]); got \(v)")
        }
    }

    // MARK: - 90° rotation matches hand-computed reference

    /// cos=0, sin=1 ⇒ 90° rotation [a, b] → [-b, a]
    /// Test x = [[1, 0], [0, 1]]
    /// Expected:
    ///   row 0:[1, 0] → [-0, 1] = [0, 1]
    ///   row 1:[0, 1] → [-1, 0]
    /// Wait — for headDim=2, i=0 is the only pair:
    ///   y[s, 0] = x[s, 0]*cos - x[s, 1]*sin
    ///   y[s, 1] = x[s, 0]*sin + x[s, 1]*cos
    /// For cos=0, sin=1:
    ///   y[s, 0] = -x[s, 1]
    ///   y[s, 1] = x[s, 0]
    /// So [1, 0] → [0, 1] (y0=-0=0, y1=1)
    /// And [0, 1] → [-1, 0] (y0=-1, y1=0)
    func testNinetyDegreeRotationMatchesReference()
        async throws
    {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let x: [Float] = [1, 0, 0, 1]
        let cos: [Float] = [0, 0]
        let sin: [Float] = [1, 1]
        let inputs = makeRotaryInputs(
            x: x, cos: cos, sin: sin,
            seqLen: 2, headDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        let expected: [Float] = [0, 1, -1, 0]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-4,
                "result[\(idx)] = \(v); expected" +
                " \(expected[idx])")
        }
    }

    // MARK: - 4-dim rotary applies pair-wise

    /// headDim=4 → 2 rotation pairs。 With cos=[1,1] and
    /// sin=[0,0] (identity per pair) output equals input。
    func testFourDimIdentityRotationPreservesInput()
        async throws
    {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let x: [Float] = [1, 2, 3, 4]  // seq=1, headDim=4
        let cos: [Float] = [1, 1]      // seq=1, half=2
        let sin: [Float] = [0, 0]
        let inputs = makeRotaryInputs(
            x: x, cos: cos, sin: sin,
            seqLen: 1, headDim: 4)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, x[idx], accuracy: 1e-4)
        }
    }

    // MARK: - Reports non-zero execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let x: [Float] = [1, 0, 0, 1]
        let cos: [Float] = [1, 1]
        let sin: [Float] = [0, 0]
        let inputs = makeRotaryInputs(
            x: x, cos: cos, sin: sin,
            seqLen: 2, headDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0)
    }
}
