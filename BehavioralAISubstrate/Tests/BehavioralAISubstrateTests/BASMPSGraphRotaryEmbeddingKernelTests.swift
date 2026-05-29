// MARK: - BASMPSGraphRotaryEmbeddingKernelTests
// chapter 四百四十九 / M1174 — POST-SWEEP REAL EXECUTION

import XCTest
import Foundation
@testable import BASMetalSubstrate

final class BASMPSGraphRotaryEmbeddingKernelTests: XCTestCase {

    func testKernelConstructsOrSkipsCleanly() async throws {
        do {
            let kernel =
                try BASMPSGraphRotaryEmbeddingKernel()
            XCTAssertEqual(
                kernel.key.operation, .rotaryEmbedding)
            XCTAssertEqual(
                kernel.key.dataType, .float32)
            XCTAssertEqual(
                kernel.key.backingKind, .metalBuffer)
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
        }
    }

    /// ch 1034.1 — INTEGRATION:the canonical rank-2 builder must
    /// produce inputs the kernel ACCEPTS。 The rank-3 `rotaryEmbedding`
    /// builder does NOT(emits [seq,heads,headDim];kernel requires
    /// [seq,headDim])— ch 1034's endurance probe was the first call
    /// site to feed builder→kernel and hit `shapeMismatch`。 This pins
    /// that `rotaryEmbeddingRank2` → kernel works end-to-end,so the
    /// builder/kernel pair can never silently drift apart again。
    func testRotaryEmbeddingRank2BuilderFeedsKernel() async throws {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let seqLen = 4, headDim = 4, half = 2
        // cos=1 / sin=0 → identity rotation → output == input。
        let inputs = BASCanonicalKernelInputBuilders
            .rotaryEmbeddingRank2(
                input: [Float](repeating: 0.5,
                               count: seqLen * headDim),
                cosTable: [Float](repeating: 1.0,
                                  count: seqLen * half),
                sinTable: [Float](repeating: 0.0,
                                  count: seqLen * half),
                sequenceLength: seqLen, headDim: headDim)
        // Must NOT throw shapeMismatch(the ch 1034 builder/kernel bug)。
        let outputs = try await kernel.evaluate(inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1,
            "rotaryEmbedding kernel emits 1 output tensor")
        let outFloats = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                outputs.payloads[0],
                elementCount: seqLen * headDim)
        XCTAssertEqual(outFloats.count, seqLen * headDim)
        // Identity rotation:every output element equals input(0.5)。
        for v in outFloats {
            XCTAssertEqual(v, 0.5, accuracy: 1e-4,
                "cos=1/sin=0 is identity → output must equal input")
        }
    }

    /// Identity test:cos=1,sin=0 → output equals
    /// input (rotation by 0 angle is identity)。
    func testZeroAngleIsIdentity() async throws {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel =
                try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        // seqLen=2, headDim=4 (halfDim=2)
        let xValues: [Float] = [
            1.0, 2.0, 3.0, 4.0,
            5.0, 6.0, 7.0, 8.0
        ]
        let cosValues: [Float] = [
            1.0, 1.0,
            1.0, 1.0
        ]
        let sinValues: [Float] = [
            0.0, 0.0,
            0.0, 0.0
        ]
        let outputs = try await kernel.evaluate(
            inputs: BASKernelInputs(
                descriptors: [
                    BASTensorDescriptor.contiguous(
                        shape: [2, 4],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [2, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [2, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag)
                ],
                payloads: [
                    xValues.withUnsafeBufferPointer {
                        Data(buffer: $0) },
                    cosValues.withUnsafeBufferPointer {
                        Data(buffer: $0) },
                    sinValues.withUnsafeBufferPointer {
                        Data(buffer: $0) }
                ]))
        let resultFloats = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        XCTAssertEqual(
            resultFloats.count, xValues.count)
        // cos=1, sin=0 → no rotation:output == input
        for (i, exp) in xValues.enumerated() {
            XCTAssertEqual(
                resultFloats[i], exp, accuracy: 1e-6,
                "identity rotation must preserve input")
        }
    }

    /// 90° rotation:cos=0,sin=1 → pair (x0, x1)
    /// becomes (-x1, x0)。
    func testNinetyDegreeRotation() async throws {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel =
                try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        // seqLen=1, headDim=4 (halfDim=2): pairs
        // (x0,x1) and (x2,x3) — both rotated by 90°
        let xValues: [Float] = [3.0, 4.0, 5.0, 6.0]
        let cosValues: [Float] = [0.0, 0.0]
        let sinValues: [Float] = [1.0, 1.0]
        // Expected: pair (3,4) rotated by 90° → (-4, 3)
        //           pair (5,6) rotated by 90° → (-6, 5)
        let expected: [Float] = [-4.0, 3.0, -6.0, 5.0]
        let outputs = try await kernel.evaluate(
            inputs: BASKernelInputs(
                descriptors: [
                    BASTensorDescriptor.contiguous(
                        shape: [1, 4],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [1, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [1, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag)
                ],
                payloads: [
                    xValues.withUnsafeBufferPointer {
                        Data(buffer: $0) },
                    cosValues.withUnsafeBufferPointer {
                        Data(buffer: $0) },
                    sinValues.withUnsafeBufferPointer {
                        Data(buffer: $0) }
                ]))
        let resultFloats = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(
                resultFloats[i], exp, accuracy: 1e-5,
                "90° rotation[\(i)]:got" +
                " \(resultFloats[i]),expected \(exp)")
        }
    }

    /// GPU vs CPU agreement on realistic-ish input。
    func testGPUAgreesWithCPURotary() async throws {
        let gpu: BASMPSGraphRotaryEmbeddingKernel
        do {
            gpu = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let cpu = BASRotaryEmbeddingKernel()
        // seqLen=4, headDim=8 (halfDim=4)
        let xValues: [Float] = [
            0.5, 1.5, -2.5, 3.0, 4.0, -1.0, 0.25, 2.75,
            -3.5, 6.0, 1.125, -0.5, 7.0, -2.0, 4.5, 0.0,
            0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8,
            -0.1, -0.2, -0.3, -0.4, -0.5, -0.6, -0.7, -0.8
        ]
        // Position-frequency tables for seqLen=4,
        // halfDim=4 — pre-computed sin/cos values
        let cosValues: [Float] = [
            1.0, 1.0, 1.0, 1.0,
            0.5403023, 0.9950042, 0.9999500, 0.9999995,
            -0.4161468, 0.9800666, 0.9998000, 0.9999980,
            -0.9899925, 0.9551940, 0.9995501, 0.9999955
        ]
        let sinValues: [Float] = [
            0.0, 0.0, 0.0, 0.0,
            0.8414710, 0.0998334, 0.0099998, 0.0010000,
            0.9092974, 0.1986693, 0.0199987, 0.0019999,
            0.1411200, 0.2955202, 0.0299955, 0.0029999
        ]
        let descX = BASTensorDescriptor.contiguous(
            shape: [4, 8], dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let descTable = BASTensorDescriptor.contiguous(
            shape: [4, 4], dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let inputs = BASKernelInputs(
            descriptors: [descX, descTable, descTable],
            payloads: [
                xValues.withUnsafeBufferPointer {
                    Data(buffer: $0) },
                cosValues.withUnsafeBufferPointer {
                    Data(buffer: $0) },
                sinValues.withUnsafeBufferPointer {
                    Data(buffer: $0) }
            ])
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
                cpuF[i], gpuF[i], accuracy: 1e-5,
                "rotary[\(i)] CPU=\(cpuF[i]) GPU=\(gpuF[i])")
        }
    }
}
