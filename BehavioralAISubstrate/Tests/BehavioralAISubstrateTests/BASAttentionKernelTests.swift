// MARK: - BASAttentionKernelTests
// chapter 四百五十三 / M1190 — POST-SWEEP REAL EXECUTION

import XCTest
import Foundation
@testable import BASMetalSubstrate

final class BASAttentionKernelTests: XCTestCase {

    // MARK: - Helpers

    private func makeInputs(
        Q: [Float], seqQ: Int,
        K: [Float], seqK: Int,
        V: [Float],
        dim: Int
    ) -> BASKernelInputs {
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [seqQ, dim],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqK, dim],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqK, dim],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                Q.withUnsafeBufferPointer {
                    Data(buffer: $0) },
                K.withUnsafeBufferPointer {
                    Data(buffer: $0) },
                V.withUnsafeBufferPointer {
                    Data(buffer: $0) }
            ])
    }

    // MARK: - CPU identity attention

    /// Q=K=V=identity-like single-token (seqQ=seqK=1)。
    /// softmax of single-element row is [1.0]。
    /// output = 1.0 · V = V。
    func testCPUSingleTokenIsIdentity() async throws {
        let cpu = BASAttentionKernel()
        let Q: [Float] = [1, 0, 0, 0]
        let K: [Float] = [1, 0, 0, 0]
        let V: [Float] = [5, 6, 7, 8]
        let outputs = try await cpu.evaluate(
            inputs: makeInputs(
                Q: Q, seqQ: 1,
                K: K, seqK: 1,
                V: V,
                dim: 4))
        let result = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        // softmax([row]) = [1.0] (single element)
        // output = 1.0 · V = V
        XCTAssertEqual(result.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(
                result[i], V[i], accuracy: 1e-5,
                "single-token attention output[\(i)]" +
                " must equal V[\(i)]")
        }
    }

    // MARK: - CPU uniform-key produces uniform attention

    /// Q has 1 query;K has 2 identical rows;the
    /// attention weights must be uniform [0.5, 0.5];
    /// output = 0.5 * V[0] + 0.5 * V[1]。
    func testCPUUniformKeyProducesUniformAttention() async throws {
        let cpu = BASAttentionKernel()
        let Q: [Float] = [1, 2]              // (1, 2)
        let K: [Float] = [
            1, 0,
            1, 0
        ]                                     // (2, 2) — identical keys
        let V: [Float] = [
            3, 4,
            5, 6
        ]                                     // (2, 2)
        let expected: [Float] = [4, 5]       // (0.5·3+0.5·5, 0.5·4+0.5·6)
        let outputs = try await cpu.evaluate(
            inputs: makeInputs(
                Q: Q, seqQ: 1,
                K: K, seqK: 2,
                V: V,
                dim: 2))
        let result = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        XCTAssertEqual(result.count, 2)
        for i in 0..<2 {
            XCTAssertEqual(
                result[i], expected[i],
                accuracy: 1e-5,
                "uniform-K attention output[\(i)]")
        }
    }

    // MARK: - CPU dominant-key concentrates attention

    /// Q strongly aligned with K[0] (Q·K[0] >> Q·K[1])
    /// → attention nearly [1, 0] → output ≈ V[0]。
    func testCPUDominantKeyConcentrates() async throws {
        let cpu = BASAttentionKernel()
        let Q: [Float] = [10, 0]
        let K: [Float] = [
            10, 0,
            0, 10
        ]
        let V: [Float] = [
            100, 200,
            300, 400
        ]
        let outputs = try await cpu.evaluate(
            inputs: makeInputs(
                Q: Q, seqQ: 1,
                K: K, seqK: 2,
                V: V,
                dim: 2))
        let result = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        // softmax(Q·K^T / sqrt(2)) = softmax([100/sqrt(2), 0])
        // First weight is overwhelmingly close to 1
        // → output ≈ V[0] = [100, 200]
        XCTAssertEqual(
            result[0], 100, accuracy: 0.1,
            "dominant K[0] should drive output toward" +
            " V[0]")
        XCTAssertEqual(
            result[1], 200, accuracy: 0.1)
    }

    // MARK: - GPU construction

    func testGPUKernelConstructsOrSkips() async throws {
        do {
            let kernel =
                try BASMPSGraphAttentionKernel()
            XCTAssertEqual(
                kernel.key.operation, .attention)
            XCTAssertEqual(
                kernel.key.backingKind, .metalBuffer)
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - GPU/CPU agreement

    /// GPU and CPU attention paths must produce
    /// equivalent output within tolerance。 softmax +
    /// matMul composition more numerically sensitive
    /// than plain matMul,so 1e-4 absolute tolerance。
    func testGPUMatchesCPUAttention() async throws {
        let gpu: BASMPSGraphAttentionKernel
        do {
            gpu = try BASMPSGraphAttentionKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let cpu = BASAttentionKernel()
        // 4×4 attention over 3 query, 5 key tokens
        let Q: [Float] = [
            0.5, 1.0, -0.5, 0.3,
            -1.0, 0.5, 2.0, 0.0,
            1.5, -0.5, 0.25, -1.0
        ]
        let K: [Float] = [
            0.0, 1.0, 0.5, -0.5,
            1.0, 0.5, -1.0, 0.0,
            -0.5, 0.0, 1.0, 1.0,
            0.25, -0.25, 0.5, -0.5,
            -1.0, 1.0, 0.0, 0.5
        ]
        let V: [Float] = [
            1.0, 2.0, 3.0, 4.0,
            5.0, 6.0, 7.0, 8.0,
            -1.0, -2.0, -3.0, -4.0,
            0.5, 1.5, 2.5, 3.5,
            -0.5, -1.5, -2.5, -3.5
        ]
        let inputs = makeInputs(
            Q: Q, seqQ: 3,
            K: K, seqK: 5,
            V: V,
            dim: 4)
        let cpuOut = try await cpu.evaluate(
            inputs: inputs)
        let gpuOut = try await gpu.evaluate(
            inputs: inputs)
        let cpuF = cpuOut.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        let gpuF = gpuOut.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        XCTAssertEqual(cpuF.count, gpuF.count)
        for i in 0..<cpuF.count {
            XCTAssertEqual(
                cpuF[i], gpuF[i], accuracy: 1e-4,
                "attention[\(i)] CPU=\(cpuF[i])" +
                " GPU=\(gpuF[i])")
        }
    }
}
