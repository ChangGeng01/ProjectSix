// MARK: - BASMPSGraphRMSNormIntegrationTests
// chapter 四百七十六 / M1280
//
// Sibling of M1277 BASMPSGraphMatMulIntegrationTests —
// extends the "MPSGraph kernels actually compute correctly"
// PROOF to BASMPSGraphRMSNormKernel。
//
// Before M1280:RMSNorm kernel registered (M1098 / chapter
// 447) + numerically validated never。 After M1280:numerically
// validated against hand-computed reference outputs。

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphRMSNormIntegrationTests: XCTestCase {

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework)) —" +
                " test skipped")
        }
    }

    // MARK: - 2x2 RMSNorm numerical correctness

    /// Hand-computed reference:
    /// x = [[2, 0], [0, 2]], weight = [1, 1], eps = 1e-6
    /// Row 0:rms = sqrt(mean(4, 0) + eps) ≈ sqrt(2)
    ///        y[0] = x[0] / rms * w ≈ [1.4142, 0]
    /// Row 1:rms = sqrt(mean(0, 4) + eps) ≈ sqrt(2)
    ///        y[1] = x[1] / rms * w ≈ [0, 1.4142]
    /// Expected = [1.4142, 0, 0, 1.4142] (row-major)
    func testKernelComputes2x2RMSNormCorrectly() async
        throws
    {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = BASCanonicalKernelInputBuilders
            .rmsNorm(
                input: [2, 0, 0, 2],
                gamma: [1, 1],
                batchSeq: 2,
                hiddenDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [2, 2])
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        let expected: [Float] = [
            2 / Float(2.0).squareRoot(),
            0,
            0,
            2 / Float(2.0).squareRoot()
        ]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-4,
                "rmsNorm result[\(idx)] = \(v);" +
                " expected \(expected[idx])")
        }
    }

    // MARK: - Identity weight preserves direction

    /// When weight = [1, 1, ..., 1], rmsNorm just rescales
    /// rows to RMS=1。 Verify for a 3-D row:
    /// x = [3, 4, 0] → rms = sqrt(25/3) ≈ 2.8868
    /// y = [3/2.8868, 4/2.8868, 0]
    ///   ≈ [1.0392, 1.3856, 0]
    func testKernelHandles3DIdentityWeight() async throws {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = BASCanonicalKernelInputBuilders
            .rmsNorm(
                input: [3, 4, 0],
                gamma: [1, 1, 1],
                batchSeq: 1,
                hiddenDim: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 3)
        let rms = (Float(25.0) / Float(3.0))
            .squareRoot()
        let expected: [Float] = [
            3 / rms, 4 / rms, 0
        ]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-4,
                "result[\(idx)] = \(v); expected" +
                " \(expected[idx])")
        }
    }

    // MARK: - Scaled weight scales output

    /// rmsNorm with weight = [2, 2] doubles the output。
    /// Use x = [[1, 1]] → rms = 1 → y_base = [1, 1] →
    /// y_scaled = [2, 2]。
    func testKernelHonorsWeightScaling() async throws {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = BASCanonicalKernelInputBuilders
            .rmsNorm(
                input: [1, 1],
                gamma: [2, 2],
                batchSeq: 1,
                hiddenDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 2)
        let expected: [Float] = [2, 2]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-4)
        }
    }

    // MARK: - Reports non-zero execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = BASCanonicalKernelInputBuilders
            .rmsNorm(
                input: [1, 2, 3, 4],
                gamma: [1, 1],
                batchSeq: 2,
                hiddenDim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0)
    }
}
