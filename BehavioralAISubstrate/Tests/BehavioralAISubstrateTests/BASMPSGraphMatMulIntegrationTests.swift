// MARK: - BASMPSGraphMatMulIntegrationTests
// chapter 四百七十五 / M1277
//
// FIRST test in the substrate where an MPSGraph kernel
// runs with REAL inputs and produces a measurable output。
//
// Chapter 474 M1273 wired BASKernelRegistryDispatchExecutor。
// M1274 proved the full chain composes end-to-end via
// EchoKernel test fixtures。 But no test had ever actually
// run BASMPSGraphMatMulKernel.evaluate() with non-trivial
// inputs。 M1277 closes that gap:
//
//   - Constructs BASMPSGraphMatMulKernel via init() throws
//   - Builds inputs for [[1,2],[3,4]] · [[5,6],[7,8]]
//     via M1276 BASCanonicalKernelInputBuilders.matMul
//   - Calls kernel.evaluate(inputs:) on the real Metal
//     device (Apple Silicon macOS lane)
//   - Decodes output as Float array
//   - Asserts numerical correctness:
//       [[1,2],[3,4]] · [[5,6],[7,8]] = [[19,22],[43,50]]
//
// Test is gated:
//   - XCTSkipUnless succeeded kernel construction (Metal
//     unavailable on simulator without GPU)
//   - Otherwise compares Float32 outputs within IEEE
//     tolerance (1e-5)

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphMatMulIntegrationTests: XCTestCase {

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework)) —" +
                " test skipped on this environment")
        }
    }

    // MARK: - 2x2 matMul numerical correctness

    func testKernelComputes2x2MatMulCorrectly() async
        throws
    {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // [[1,2],[3,4]] × [[5,6],[7,8]] = [[19,22],[43,50]]
        let a: [Float] = [1, 2, 3, 4]
        let b: [Float] = [5, 6, 7, 8]
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(a: a, b: b, M: 2, K: 2, N: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1,
            "matMul produces exactly 1 output")
        XCTAssertEqual(
            outputs.descriptors[0].shape, [2, 2],
            "output shape is [M, N]")
        XCTAssertEqual(
            outputs.descriptors[0].dataType, .float32)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        let expected: [Float] = [19, 22, 43, 50]
        XCTAssertEqual(result.count, expected.count)
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-5,
                "result[\(idx)] = \(v); expected" +
                " \(expected[idx])")
        }
    }

    // MARK: - 2x3 × 3x4 → 2x4 rectangular matMul

    func testKernelComputesRectangular2x3x4MatMul() async
        throws
    {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // A: 2×3 = [[1,2,3],[4,5,6]]
        // B: 3×4 = [[1,0,0,1],[0,1,0,1],[0,0,1,1]]
        // C: 2×4 = [[1,2,3,6],[4,5,6,15]]
        let a: [Float] = [1, 2, 3, 4, 5, 6]
        let b: [Float] = [
            1, 0, 0, 1,
            0, 1, 0, 1,
            0, 0, 1, 1
        ]
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(a: a, b: b, M: 2, K: 3, N: 4)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 8)
        let expected: [Float] = [
            1, 2, 3, 6,
            4, 5, 6, 15
        ]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-5,
                "result[\(idx)] = \(v); expected" +
                " \(expected[idx])")
        }
    }

    // MARK: - Identity matMul as sanity

    func testKernelHandlesIdentityCorrectly() async throws {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // A: 3×3 random, I: 3×3 identity → A·I = A
        let a: [Float] = [
            1.5, 2.25, 3.125,
            4.0625, -0.5, 7.75,
            0, 100, -50.5
        ]
        let identity: [Float] = [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1
        ]
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(a: a, b: identity, M: 3, K: 3, N: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 9)
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, a[idx], accuracy: 1e-5,
                "A·I[\(idx)] = \(v); expected \(a[idx])")
        }
    }

    // MARK: - Reports execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(
                a: [1, 2, 3, 4],
                b: [5, 6, 7, 8],
                M: 2, K: 2, N: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0,
            "executionNanos must be > 0 for a real" +
            " GPU dispatch (M1102 scheduler tunes" +
            " estimatedLatencyMs from this signal)")
    }
}
