// MARK: - BASMPSGraphMatMulKernelTests
// chapter 四百四十七 / M1166 — POST-SWEEP RADICAL EXECUTION

import XCTest
import Foundation
@testable import BASMetalSubstrate

/// PROOF tests for the M1165 real MPS GPU-dispatching
/// matMul kernel。 Validates byte-level numerical
/// correctness AND proves the substrate is actually
/// dispatching compute through Metal (not just wearing
/// a Metal-shaped hat over a CPU loop)。
///
/// **Skip semantics**:if `MTLCreateSystemDefaultDevice()`
/// returns nil (iOS Simulator without Metal,or any
/// environment where Metal is unavailable),the kernel
/// init throws `.frameworkUnavailable`,which these
/// tests catch + skip via `XCTSkip`。 On real M-series
/// macOS / iOS device the tests run and verify。
final class BASMPSGraphMatMulKernelTests: XCTestCase {

    // MARK: - Construction probe

    /// On Metal-enabled platforms the kernel constructs
    /// successfully + reports its expected key。 On
    /// platforms without Metal it throws
    /// `.frameworkUnavailable` cleanly。
    func testKernelConstructsOrSkipsCleanly() async throws {
        do {
            let kernel =
                try BASMPSGraphMatMulKernel()
            XCTAssertEqual(
                kernel.key.operation, .matMul)
            XCTAssertEqual(
                kernel.key.dataType, .float32)
            XCTAssertEqual(
                kernel.key.backingKind, .metalBuffer)
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable on this platform" +
                " (\(framework));MPS kernel tests" +
                " skipped — would run on real" +
                " M-series macOS / iOS hardware")
        }
    }

    // MARK: - 2×2 known-result GPU dispatch

    /// **THE CRITICAL TEST** — proves bytes actually
    /// flow CPU → MTLBuffer → MPS shader → MTLBuffer
    /// → CPU and produce the expected matrix-multiply
    /// result。
    ///
    /// Input:
    ///   A = [[1, 2], [3, 4]] (row-major)
    ///   B = [[5, 6], [7, 8]] (row-major)
    /// Expected output:
    ///   C = A · B
    ///     = [[1·5 + 2·7, 1·6 + 2·8],
    ///        [3·5 + 4·7, 3·6 + 4·8]]
    ///     = [[19, 22],
    ///        [43, 50]]
    func testTwoByTwoMatMulProducesExpectedBytes() async throws {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel =
                try BASMPSGraphMatMulKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let aValues: [Float] = [1, 2, 3, 4]
        let bValues: [Float] = [5, 6, 7, 8]
        let expectedC: [Float] = [19, 22, 43, 50]
        let aData = aValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let bData = bValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let descA = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let descB = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let inputs = BASKernelInputs(
            descriptors: [descA, descB],
            payloads: [aData, bData])
        let outputs = try await kernel
            .evaluate(inputs: inputs)
        // 1 output descriptor + payload
        XCTAssertEqual(outputs.descriptors.count, 1)
        XCTAssertEqual(outputs.payloads.count, 1)
        // Output descriptor sanity
        let outDesc = outputs.descriptors[0]
        XCTAssertEqual(outDesc.shape, [2, 2])
        XCTAssertEqual(outDesc.dataType, .float32)
        XCTAssertEqual(
            outDesc.backingKind, .metalBuffer,
            "GPU kernel outputs to .metalBuffer slot" +
            " (sibling differentiation from CPU stub)")
        // Decode result payload + verify byte-equal to
        // expected
        let resultData = outputs.payloads[0]
        XCTAssertEqual(
            resultData.count, expectedC.count * 4,
            "result byte count = 4 elements × 4 bytes" +
            " (Float32)")
        let resultFloats = resultData
            .withUnsafeBytes { rawBuffer -> [Float] in
                let typed = rawBuffer.bindMemory(
                    to: Float.self)
                return Array(typed)
            }
        XCTAssertEqual(
            resultFloats.count, expectedC.count)
        for (i, expected) in expectedC.enumerated() {
            // GPU IEEE Float32 must equal CPU IEEE
            // Float32 for these small integer-valued
            // inputs (no rounding error possible)
            XCTAssertEqual(
                resultFloats[i], expected,
                "result[\(i)] mismatch:got" +
                " \(resultFloats[i]),expected" +
                " \(expected) — bytes did not flow" +
                " correctly through GPU dispatch")
        }
        // executionNanos must be > 0 (GPU dispatch
        // measurably took some wall-clock time)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0,
            "GPU dispatch must report non-zero" +
            " executionNanos")
    }

    // MARK: - 3×4 · 4×2 non-square known result

    /// Non-square shape proves the kernel handles
    /// arbitrary (M, K, N) — not just 2×2。 Catches a
    /// regression where someone hardcoded square
    /// assumptions in the MPSMatrixDescriptor wiring。
    func testNonSquareMatMul() async throws {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        // A is 3×4
        let aValues: [Float] = [
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12
        ]
        // B is 4×2
        let bValues: [Float] = [
            1, 2,
            3, 4,
            5, 6,
            7, 8
        ]
        // Expected C is 3×2 = A · B
        // Row 0: [1·1+2·3+3·5+4·7, 1·2+2·4+3·6+4·8]
        //      = [50, 60]
        // Row 1: [5·1+6·3+7·5+8·7, 5·2+6·4+7·6+8·8]
        //      = [114, 140]
        // Row 2: [9·1+10·3+11·5+12·7, 9·2+10·4+11·6+12·8]
        //      = [178, 220]
        let expectedC: [Float] = [
            50, 60,
            114, 140,
            178, 220
        ]
        let aData = aValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let bData = bValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let descA = BASTensorDescriptor.contiguous(
            shape: [3, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let descB = BASTensorDescriptor.contiguous(
            shape: [4, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let inputs = BASKernelInputs(
            descriptors: [descA, descB],
            payloads: [aData, bData])
        let outputs = try await kernel
            .evaluate(inputs: inputs)
        let resultData = outputs.payloads[0]
        let resultFloats = resultData
            .withUnsafeBytes { rawBuffer -> [Float] in
                let typed = rawBuffer.bindMemory(
                    to: Float.self)
                return Array(typed)
            }
        XCTAssertEqual(
            outputs.descriptors[0].shape, [3, 2])
        XCTAssertEqual(
            resultFloats.count, expectedC.count)
        for (i, expected) in expectedC.enumerated() {
            XCTAssertEqual(
                resultFloats[i], expected,
                "non-square[\(i)] mismatch:got" +
                " \(resultFloats[i]),expected" +
                " \(expected)")
        }
    }

    // MARK: - GPU vs CPU byte-equality

    /// **REPLAY-DETERMINISM ANCHOR** — GPU and CPU
    /// MUST produce byte-equal output for the same
    /// IEEE Float32 inputs。 This proves the chapter
    /// 三百九二 replay-determinism doctrine holds
    /// across CPU/GPU dispatch boundary。
    func testGPUOutputByteEqualsCPUOutput() async throws {
        let gpuKernel: BASMPSGraphMatMulKernel
        do {
            gpuKernel =
                try BASMPSGraphMatMulKernel()
        } catch BASKernelError
            .frameworkUnavailable(let framework)
        {
            try XCTSkipIf(true,
                "Metal unavailable (\(framework))")
            return
        }
        let cpuKernel = BASMatMulKernel()
        // 4×4 random-ish inputs
        let aValues: [Float] = [
            0.5, 1.5, -2.5, 3.0,
            4.0, -1.0, 0.25, 2.75,
            -3.5, 6.0, 1.125, -0.5,
            7.0, -2.0, 4.5, 0.0
        ]
        let bValues: [Float] = [
            1.0, 0.5, -1.5, 2.0,
            -0.25, 3.0, 1.5, -1.0,
            2.5, -0.5, 0.75, 1.25,
            -1.0, 1.5, -0.5, 0.25
        ]
        let aData = aValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let bData = bValues.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        // CPU kernel uses cpuBytes backing
        let descA_cpu = BASTensorDescriptor.contiguous(
            shape: [4, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let descB_cpu = BASTensorDescriptor.contiguous(
            shape: [4, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let cpuOutputs = try await cpuKernel
            .evaluate(inputs: BASKernelInputs(
                descriptors: [descA_cpu, descB_cpu],
                payloads: [aData, bData]))
        // GPU kernel uses cpuBytes input descriptors
        // too (the upload to MTLBuffer happens inside
        // the kernel's actor context)
        let gpuOutputs = try await gpuKernel
            .evaluate(inputs: BASKernelInputs(
                descriptors: [descA_cpu, descB_cpu],
                payloads: [aData, bData]))
        let cpuFloats = cpuOutputs.payloads[0]
            .withUnsafeBytes { rawBuffer -> [Float] in
                Array(rawBuffer.bindMemory(
                    to: Float.self))
            }
        let gpuFloats = gpuOutputs.payloads[0]
            .withUnsafeBytes { rawBuffer -> [Float] in
                Array(rawBuffer.bindMemory(
                    to: Float.self))
            }
        XCTAssertEqual(
            cpuFloats.count, gpuFloats.count)
        for i in 0..<cpuFloats.count {
            // IEEE Float32 ops with these small
            // bounded magnitudes should produce
            // byte-equal results across CPU + GPU。
            // If GPU ever introduces fused-multiply-
            // add reordering that differs from CPU
            // ordering,this test would surface it +
            // we'd need to relax to XCTAssertEqual
            // with accuracy tolerance。
            XCTAssertEqual(
                cpuFloats[i], gpuFloats[i],
                "CPU[\(i)]=\(cpuFloats[i])," +
                " GPU[\(i)]=\(gpuFloats[i]):" +
                " GPU+CPU must agree byte-equal for" +
                " IEEE Float32 IEEE arithmetic")
        }
    }
}
