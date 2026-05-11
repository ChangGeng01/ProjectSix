// MARK: - BASMPSGraphSoftmaxIntegrationTests
// chapter 四百七十九 / M1292
//
// 5th MPSGraph kernel numerical-correctness PROOF。
// Extends matMul/rmsNorm/rotaryEmbedding/attention to
// softmax — brings coverage from 4-of-8 BASNeuralOp →
// 5-of-8。

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphSoftmaxIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeSoftmaxInputs(
        x: [Float],
        rows: Int,
        cols: Int
    ) -> BASKernelInputs {
        precondition(x.count == rows * cols)
        let desc = BASTensorDescriptor(
            shape: [rows, cols],
            strides: [cols * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [desc],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(x)
            ])
    }

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphSoftmaxKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - 1×3 sum-to-1 invariant

    /// softmax([0,0,0]) = [1/3, 1/3, 1/3]
    /// Sum must equal 1.0 within IEEE tolerance。
    func testSoftmaxUniformInputProducesUniformOutput()
        async throws
    {
        let kernel: BASMPSGraphSoftmaxKernel
        do {
            kernel = try BASMPSGraphSoftmaxKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeSoftmaxInputs(
            x: [0, 0, 0], rows: 1, cols: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 3)
        let expected: Float = 1.0 / 3.0
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected, accuracy: 1e-5,
                "softmax uniform[\(idx)] = \(v);" +
                " expected \(expected)")
        }
        let sum = result.reduce(0, +)
        XCTAssertEqual(
            sum, 1.0, accuracy: 1e-5,
            "softmax output must sum to 1")
    }

    // MARK: - 1×2 dominant-element case

    /// softmax([10, 0]) ≈ [0.99995, 0.00005]
    /// exp(10) / (exp(10) + exp(0))
    func testSoftmaxDominantElementProducesNearOneZero()
        async throws
    {
        let kernel: BASMPSGraphSoftmaxKernel
        do {
            kernel = try BASMPSGraphSoftmaxKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeSoftmaxInputs(
            x: [10, 0], rows: 1, cols: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 2)
        let e10 = Float(exp(Float(10.0)))
        let e0 = Float(exp(Float(0.0)))
        let denom = e10 + e0
        XCTAssertEqual(
            result[0], e10 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result[1], e0 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result.reduce(0, +), 1.0, accuracy: 1e-4)
    }

    // MARK: - 2×3 row-wise independence

    /// Each row's softmax is independent。 Test:
    /// row 0 = [1,0,0], row 1 = [0,0,1]
    /// row 0 softmax ≈ [0.576, 0.212, 0.212]
    /// row 1 softmax ≈ [0.212, 0.212, 0.576]
    func testSoftmaxRowWiseIndependence() async throws {
        let kernel: BASMPSGraphSoftmaxKernel
        do {
            kernel = try BASMPSGraphSoftmaxKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeSoftmaxInputs(
            x: [1, 0, 0, 0, 0, 1], rows: 2, cols: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 6)
        let e1 = Float(exp(Float(1.0)))
        let e0 = Float(exp(Float(0.0)))
        let denom = e1 + 2 * e0
        // Row 0: [e1/d, e0/d, e0/d]
        XCTAssertEqual(
            result[0], e1 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result[1], e0 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result[2], e0 / denom, accuracy: 1e-4)
        // Row 1: [e0/d, e0/d, e1/d]
        XCTAssertEqual(
            result[3], e0 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result[4], e0 / denom, accuracy: 1e-4)
        XCTAssertEqual(
            result[5], e1 / denom, accuracy: 1e-4)
        // Each row sums to 1
        let row0Sum = result[0] + result[1] + result[2]
        let row1Sum = result[3] + result[4] + result[5]
        XCTAssertEqual(row0Sum, 1.0, accuracy: 1e-4)
        XCTAssertEqual(row1Sum, 1.0, accuracy: 1e-4)
    }

    // MARK: - Reports non-zero execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphSoftmaxKernel
        do {
            kernel = try BASMPSGraphSoftmaxKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeSoftmaxInputs(
            x: [1, 2, 3], rows: 1, cols: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(outputs.executionNanos, 0)
    }
}
