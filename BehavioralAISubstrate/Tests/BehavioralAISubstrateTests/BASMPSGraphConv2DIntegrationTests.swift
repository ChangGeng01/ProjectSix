// MARK: - BASMPSGraphConv2DIntegrationTests
// chapter 四百七十九 / M1294
//
// 7th MPSGraph kernel numerical-correctness PROOF。
// Coverage: 6-of-8 → 7-of-8 BASNeuralOp。

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphConv2DIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Build NHWC conv2D inputs。
    private func makeConv2DInputs(
        input: [Float],
        weights: [Float],
        n: Int, h: Int, w: Int, cin: Int,
        hk: Int, wk: Int, cout: Int
    ) -> BASKernelInputs {
        precondition(input.count == n * h * w * cin)
        precondition(weights.count == hk * wk * cin * cout)
        let descIn = BASTensorDescriptor(
            shape: [n, h, w, cin],
            strides: [h * w * cin * 4,
                      w * cin * 4,
                      cin * 4,
                      4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-4-tensor")
        let descW = BASTensorDescriptor(
            shape: [hk, wk, cin, cout],
            strides: [wk * cin * cout * 4,
                      cin * cout * 4,
                      cout * 4,
                      4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-4-tensor")
        return BASKernelInputs(
            descriptors: [descIn, descW],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(input),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(weights)
            ])
    }

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphConv2DKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - 1×1 identity convolution

    /// 1×1 conv with identity weights:output equals
    /// input (modulo NHWC layout)。
    /// input shape:[1, 2, 2, 1]
    /// weights shape:[1, 1, 1, 1] = [[1.0]]
    /// output shape:[1, 2, 2, 1]
    func testConv2DOneByOneIdentityKernel() async throws {
        let kernel: BASMPSGraphConv2DKernel
        do {
            kernel = try BASMPSGraphConv2DKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // input: 2×2 image with single channel
        let inputData: [Float] = [1, 2, 3, 4]
        let weights: [Float] = [1.0]
        let inputs = makeConv2DInputs(
            input: inputData,
            weights: weights,
            n: 1, h: 2, w: 2, cin: 1,
            hk: 1, wk: 1, cout: 1)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [1, 2, 2, 1],
            "1x1 valid conv preserves spatial dims")
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, inputData[idx], accuracy: 1e-4,
                "identity 1x1 conv output[\(idx)] must" +
                " equal input[\(idx)]")
        }
    }

    // MARK: - 2×2 sum kernel

    /// 2×2 conv with weights all 1s ⇒ output = sum of
    /// input window。 For input = [[[[1,2,3]]]] (1×1×3×1)
    /// — wait,need spatial 2×2 input。 Let's do:
    /// input shape:[1, 2, 2, 1]
    /// input data: [[1, 2], [3, 4]] flat = [1,2,3,4]
    /// weights:[1, 1, 1, 1] (2×2×1×1) all ones
    /// output shape:[1, 1, 1, 1]
    /// output:1 + 2 + 3 + 4 = 10
    func testConv2DSumKernel() async throws {
        let kernel: BASMPSGraphConv2DKernel
        do {
            kernel = try BASMPSGraphConv2DKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeConv2DInputs(
            input: [1, 2, 3, 4],
            weights: [1, 1, 1, 1],
            n: 1, h: 2, w: 2, cin: 1,
            hk: 2, wk: 2, cout: 1)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [1, 1, 1, 1])
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 1)
        XCTAssertEqual(result[0], 10, accuracy: 1e-4,
            "2x2 ones-kernel over [[1,2],[3,4]] = 10")
    }

    // MARK: - Reports execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphConv2DKernel
        do {
            kernel = try BASMPSGraphConv2DKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeConv2DInputs(
            input: [1, 2, 3, 4],
            weights: [1.0],
            n: 1, h: 2, w: 2, cin: 1,
            hk: 1, wk: 1, cout: 1)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(outputs.executionNanos, 0)
    }
}
