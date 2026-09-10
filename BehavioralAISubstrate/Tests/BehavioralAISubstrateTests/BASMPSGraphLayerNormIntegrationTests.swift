// MARK: - BASMPSGraphLayerNormIntegrationTests
// chapter 四百七十九 / M1293
//
// 6th MPSGraph kernel numerical-correctness PROOF。
// Coverage: 5-of-8 → 6-of-8 BASNeuralOp。

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphLayerNormIntegrationTests:
    XCTestCase
{

    // MARK: - Helpers

    private func makeLayerNormInputs(
        x: [Float],
        gamma: [Float],
        beta: [Float],
        batch: Int,
        hidden: Int
    ) -> BASKernelInputs {
        precondition(x.count == batch * hidden)
        precondition(gamma.count == hidden)
        precondition(beta.count == hidden)
        let descX = BASTensorDescriptor(
            shape: [batch, hidden],
            strides: [hidden * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descG = BASTensorDescriptor(
            shape: [hidden],
            strides: [4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-1-vector")
        let descB = BASTensorDescriptor(
            shape: [hidden],
            strides: [4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-1-vector")
        return BASKernelInputs(
            descriptors: [descX, descG, descB],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(x),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(gamma),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(beta)
            ])
    }

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - 2×2 identity gamma+beta

    /// x = [[2, 0], [0, 2]], gamma=[1,1], beta=[0,0]
    /// row 0:mean = 1, var = mean((2-1)², (0-1)²) = 1
    ///        stddev = sqrt(1 + 1e-5) ≈ 1
    ///        y = (x - 1) / 1 = [1, -1]
    /// row 1:mean = 1, var = 1, y = [-1, 1]
    /// Expected output = [1, -1, -1, 1]
    func testLayerNormIdentityGammaBeta() async throws {
        let kernel: BASMPSGraphLayerNormKernel
        do {
            kernel = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeLayerNormInputs(
            x: [2, 0, 0, 2],
            gamma: [1, 1],
            beta: [0, 0],
            batch: 2,
            hidden: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 4)
        let expected: [Float] = [1, -1, -1, 1]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-3,
                "layerNorm[\(idx)] = \(v); expected" +
                " \(expected[idx])")
        }
    }

    // MARK: - Beta shift

    /// gamma=[1,1], beta=[5, 5] shifts output by 5
    func testLayerNormBetaShift() async throws {
        let kernel: BASMPSGraphLayerNormKernel
        do {
            kernel = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeLayerNormInputs(
            x: [2, 0],
            gamma: [1, 1],
            beta: [5, 5],
            batch: 1,
            hidden: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 2)
        // mean = 1, var = 1, normalized = [1, -1]
        // gamma=1 → [1, -1], beta=5 → [6, 4]
        XCTAssertEqual(result[0], 6, accuracy: 1e-3)
        XCTAssertEqual(result[1], 4, accuracy: 1e-3)
    }

    // MARK: - Output sums to per-row beta sum

    /// LayerNorm-normalized rows have mean 0。 Adding beta
    /// shifts mean to sum(beta)/hidden。 Test sum invariant。
    func testLayerNormRowMeanEqualsBetaMean() async throws {
        let kernel: BASMPSGraphLayerNormKernel
        do {
            kernel = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeLayerNormInputs(
            x: [1, 2, 3, 4, 5, 6],
            gamma: [1, 1, 1],
            beta: [0, 0, 0],
            batch: 2,
            hidden: 3)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 6)
        // Each row's mean must be 0 (centered + zero beta)
        let row0Mean = (result[0] + result[1] + result[2])
            / 3.0
        let row1Mean = (result[3] + result[4] + result[5])
            / 3.0
        XCTAssertEqual(
            row0Mean, 0.0, accuracy: 1e-3,
            "row 0 mean must be 0 after layerNorm")
        XCTAssertEqual(
            row1Mean, 0.0, accuracy: 1e-3,
            "row 1 mean must be 0 after layerNorm")
    }

    // MARK: - Reports execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphLayerNormKernel
        do {
            kernel = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeLayerNormInputs(
            x: [1, 2, 3, 4],
            gamma: [1, 1],
            beta: [0, 0],
            batch: 2,
            hidden: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(outputs.executionNanos, 0)
    }

    // MARK: - ch 1034.2 canonical builder → kernel integration

    /// ch 1034.2 — the NEW `BASCanonicalKernelInputBuilders.layerNorm`
    /// must(a)produce inputs EQUAL to this file's proven hand-rolled
    /// `makeLayerNormInputs`,and(b)feed the kernel end-to-end with the
    /// known-correct result。 Closes the builder/kernel mismatch CLASS
    /// (ch 1034.1 fixed it for rope)— proving layerNorm's canonical
    /// builder matches its kernel(incl. the rank-1 gamma/beta shape
    /// that's the easiest place for a builder to drift)。
    func testCanonicalLayerNormBuilderMatchesKernel() async throws {
        let kernel: BASMPSGraphLayerNormKernel
        do {
            kernel = try BASMPSGraphLayerNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // Same fixture as testLayerNormIdentityGammaBeta:
        // x=[[2,0],[0,2]] gamma=[1,1] beta=[0,0] → [1,-1,-1,1]。
        let x: [Float] = [2, 0, 0, 2]
        let gamma: [Float] = [1, 1]
        let beta: [Float] = [0, 0]
        let canonical = BASCanonicalKernelInputBuilders
            .layerNorm(x: x, gamma: gamma, beta: beta,
                       batch: 2, hidden: 2)
        let handRolled = makeLayerNormInputs(
            x: x, gamma: gamma, beta: beta,
            batch: 2, hidden: 2)
        // (a)canonical builder == proven hand-rolled inputs。
        XCTAssertEqual(canonical, handRolled,
            "ch 1034.2: canonical layerNorm builder must match the " +
            "proven hand-rolled inputs(incl. rank-1 gamma/beta)")
        // (b)builder feeds the kernel + yields [1,-1,-1,1]。
        let outputs = try await kernel.evaluate(inputs: canonical)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(outputs.payloads[0], elementCount: 4)
        let expected: [Float] = [1, -1, -1, 1]
        for (idx, val) in result.enumerated() {
            XCTAssertEqual(val, expected[idx], accuracy: 1e-3,
                "ch 1034.2 layerNorm[\(idx)] = \(val);" +
                " expected \(expected[idx])")
        }
    }
}
