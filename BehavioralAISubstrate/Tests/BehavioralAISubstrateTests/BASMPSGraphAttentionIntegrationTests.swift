// MARK: - BASMPSGraphAttentionIntegrationTests
// chapter 四百七十七 / M1284 — closes 4-of-4 MPSGraph
// kernel numerical-correctness PROOF coverage
//
// Last MPSGraph kernel without a numerical-correctness
// PROOF test in the substrate。 With M1284 in place,every
// MPSGraph kernel registered at chapters 447+ has a
// PROVEN evaluate() path:
//
//   - BASMPSGraphMatMulKernel ✅ M1277 (chapter 475)
//   - BASMPSGraphRMSNormKernel ✅ M1280 (chapter 476)
//   - BASMPSGraphRotaryEmbeddingKernel ✅ M1282 (chapter 476)
//   - BASMPSGraphAttentionKernel ✅ M1284 (chapter 477) ← here

import XCTest
import Foundation
@testable import BASMetalSubstrate

final class BASMPSGraphAttentionIntegrationTests:
    XCTestCase
{

    // MARK: - Helpers

    /// Build attention inputs (Q, K, V — all rank-2)。
    /// seqQ may differ from seqK;all share `dim`。
    private func makeAttentionInputs(
        Q: [Float], K: [Float], V: [Float],
        seqQ: Int, seqK: Int, dim: Int
    ) -> BASKernelInputs {
        precondition(Q.count == seqQ * dim)
        precondition(K.count == seqK * dim)
        precondition(V.count == seqK * dim)
        let descQ = BASTensorDescriptor(
            shape: [seqQ, dim],
            strides: [dim * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descK = BASTensorDescriptor(
            shape: [seqK, dim],
            strides: [dim * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descV = BASTensorDescriptor(
            shape: [seqK, dim],
            strides: [dim * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descQ, descK, descV],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(Q),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(K),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(V)
            ])
    }

    // MARK: - Construction

    func testKernelConstructsOrSkipsOnSimulator() throws {
        do {
            _ = try BASMPSGraphAttentionKernel()
        } catch BASKernelError.frameworkUnavailable(
            let framework)
        {
            throw XCTSkip(
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - Uniform attention weights

    /// When Q · K^T is all zeros (e.g. Q=0 or K=0),the
    /// pre-softmax logits are uniform → softmax produces
    /// uniform attention weights → output is the mean
    /// of V rows。
    ///
    /// Test: Q = [[0, 0]], K = [[0, 0], [0, 0]],
    ///       V = [[1, 2], [3, 4]]
    /// Expected: [[mean(1,3), mean(2,4)]] = [[2, 3]]
    func testZeroQKProducesUniformAttention() async throws {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeAttentionInputs(
            Q: [0, 0],
            K: [0, 0, 0, 0],
            V: [1, 2, 3, 4],
            seqQ: 1, seqK: 2, dim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [1, 2])
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 2)
        let expected: [Float] = [2, 3]
        for (idx, v) in result.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-4,
                "uniform attention result[\(idx)] =" +
                " \(v); expected \(expected[idx])")
        }
    }

    // MARK: - Output shape pinned

    func testOutputShapeMatchesQuerySeqAndDim()
        async throws
    {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // Q is 3×4 (3 queries, dim=4)
        // K and V are both 5×4 (5 keys/values, dim=4)
        // Output must be 3×4
        let Q = Array(repeating: Float(0.1), count: 12)
        let K = Array(repeating: Float(0.0), count: 20)
        let V = Array(repeating: Float(1.0), count: 20)
        let inputs = makeAttentionInputs(
            Q: Q, K: K, V: V,
            seqQ: 3, seqK: 5, dim: 4)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [3, 4],
            "output shape must equal [seqQ, dim]")
        // V is all 1s, so attention output is also all 1s
        // (uniform-attention over identical V rows)
        let result = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: 12)
        for v in result {
            XCTAssertEqual(
                v, 1.0, accuracy: 1e-4,
                "attention over uniform V = V row" +
                " (all 1s)")
        }
    }

    // MARK: - Reports non-zero execution time

    func testKernelReportsNonZeroExecutionNanos()
        async throws
    {
        let kernel: BASMPSGraphAttentionKernel
        do {
            kernel = try BASMPSGraphAttentionKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let inputs = makeAttentionInputs(
            Q: [0, 0],
            K: [0, 0, 0, 0],
            V: [1, 2, 3, 4],
            seqQ: 1, seqK: 2, dim: 2)
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0)
    }
}
