// MARK: - BASMPSGraphRMSNormKernelTests
// chapter 四百四十八 / M1170 — POST-SWEEP REAL EXECUTION

import XCTest
import Foundation
@testable import BASMetalSubstrate

/// PROOF tests for M1169 real MPSGraph-dispatching
/// rmsNorm kernel。 Validates the GPU computation
/// against the chapter 431 CPU reference implementation
/// for byte-equal (within IEEE Float32 tolerance) output。
///
/// **Skip semantics**:same as M1166 — if Metal is
/// unavailable, `XCTSkip` cleanly。
final class BASMPSGraphRMSNormKernelTests: XCTestCase {

    // MARK: - Construction probe

    func testKernelConstructsOrSkipsCleanly() async throws {
        do {
            let kernel =
                try BASMPSGraphRMSNormKernel()
            XCTAssertEqual(
                kernel.key.operation, .rmsNorm)
            XCTAssertEqual(
                kernel.key.dataType, .float32)
            XCTAssertEqual(
                kernel.key.backingKind, .metalBuffer)
            XCTAssertEqual(kernel.epsilon, 1e-6)
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
        }
    }

    // MARK: - Single-batch known-result

    /// Input: x = [[1, 2, 3, 4]], weight = [1, 1, 1, 1]
    /// mean of squares = (1 + 4 + 9 + 16) / 4 = 7.5
    /// rms = sqrt(7.5 + 1e-6) ≈ 2.7386127...
    /// output = x / rms (since weight is all 1)
    ///        ≈ [0.3651, 0.7303, 1.0954, 1.4606]
    func testSingleBatchRMSNorm() async throws {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel =
                try BASMPSGraphRMSNormKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let xValues: [Float] = [1, 2, 3, 4]
        let wValues: [Float] = [1, 1, 1, 1]
        let meanSquares: Float = (1 + 4 + 9 + 16) / 4
        let rms = (meanSquares + 1e-6).squareRoot()
        let expected: [Float] = xValues.map { $0 / rms }
        let xData = xValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let wData = wValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let descX = BASTensorDescriptor.contiguous(
            shape: [1, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let descW = BASTensorDescriptor.contiguous(
            shape: [4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let outputs = try await kernel.evaluate(
            inputs: BASKernelInputs(
                descriptors: [descX, descW],
                payloads: [xData, wData]))
        let resultFloats = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        XCTAssertEqual(
            resultFloats.count, expected.count)
        // Use accuracy tolerance — GPU may use FMA
        // reordering that produces slightly different
        // IEEE Float32 bits than the CPU scalar
        // sequential reduction。 1e-5 absolute tolerance
        // accommodates this without losing the byte-
        // level numerical correctness check。
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(
                resultFloats[i], exp,
                accuracy: 1e-5,
                "result[\(i)] = \(resultFloats[i])," +
                " expected \(exp);Δ=\(abs(resultFloats[i] - exp))")
        }
        XCTAssertEqual(
            outputs.descriptors[0].shape, [1, 4])
        XCTAssertEqual(
            outputs.descriptors[0].backingKind,
            .metalBuffer)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0)
    }

    // MARK: - Per-feature weight modulation

    /// Verify the weight tensor actually modulates the
    /// output per-feature。
    /// Input: x = [[2, 2, 2, 2]], weight = [1, 2, 3, 4]
    /// mean squares = 4; rms = sqrt(4 + eps) ≈ 2
    /// normalized x ≈ [1, 1, 1, 1]
    /// output ≈ [1*1, 1*2, 1*3, 1*4] = [1, 2, 3, 4]
    func testPerFeatureWeightModulation() async throws {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel =
                try BASMPSGraphRMSNormKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let xValues: [Float] = [2, 2, 2, 2]
        let wValues: [Float] = [1, 2, 3, 4]
        let expected: [Float] = [1, 2, 3, 4]
        let outputs = try await kernel.evaluate(
            inputs: BASKernelInputs(
                descriptors: [
                    BASTensorDescriptor.contiguous(
                        shape: [1, 4],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [4],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _1D.rankTag)
                ],
                payloads: [
                    xValues.withUnsafeBufferPointer {
                        Data(buffer: $0)
                    },
                    wValues.withUnsafeBufferPointer {
                        Data(buffer: $0)
                    }
                ]))
        let resultFloats = outputs.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(
                resultFloats[i], exp,
                accuracy: 1e-4)
        }
    }

    // MARK: - GPU vs CPU agreement on real-ish input

    /// **REPLAY-DETERMINISM ANCHOR** across CPU/GPU
    /// dispatch boundary for the rmsNorm op。 Note that
    /// rmsNorm is more numerically sensitive than
    /// matMul (sqrt + division amplify FMA-reordering
    /// effects),so this test uses a 1e-4 absolute
    /// tolerance instead of strict byte equality。
    func testGPUAgreesWithCPURMSNorm() async throws {
        let gpuKernel: BASMPSGraphRMSNormKernel
        do {
            gpuKernel =
                try BASMPSGraphRMSNormKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let cpuKernel = BASRMSNormKernel()
        // 2×8 input with mixed magnitudes
        let xValues: [Float] = [
            0.5, 1.5, -2.5, 3.0, 4.0, -1.0, 0.25, 2.75,
            -3.5, 6.0, 1.125, -0.5, 7.0, -2.0, 4.5, 0.0
        ]
        let wValues: [Float] = [
            1.0, 0.5, -1.5, 2.0,
            -0.25, 3.0, 1.5, -1.0
        ]
        let xData = xValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let wData = wValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [2, 8],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [8],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag)
            ],
            payloads: [xData, wData])
        let cpuOut = try await cpuKernel
            .evaluate(inputs: inputs)
        let gpuOut = try await gpuKernel
            .evaluate(inputs: inputs)
        let cpuFloats = cpuOut.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        let gpuFloats = gpuOut.payloads[0]
            .withUnsafeBytes { raw -> [Float] in
                Array(raw.bindMemory(to: Float.self))
            }
        XCTAssertEqual(
            cpuFloats.count, gpuFloats.count)
        for i in 0..<cpuFloats.count {
            // 1e-4 absolute tolerance accommodates
            // GPU FMA reordering for the sqrt+divide
            // sequence。 If tolerance ever needs to
            // grow significantly,that's a signal that
            // we need a different numerical strategy
            // (e.g. compute in Float32 but accumulate
            // in higher precision)。
            XCTAssertEqual(
                cpuFloats[i], gpuFloats[i],
                accuracy: 1e-4,
                "CPU[\(i)]=\(cpuFloats[i])," +
                " GPU[\(i)]=\(gpuFloats[i])," +
                " Δ=\(abs(cpuFloats[i] - gpuFloats[i]))")
        }
    }
}
