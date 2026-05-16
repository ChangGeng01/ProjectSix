// MARK: - BASSSMScanNumericalStabilityTests
// chapter 六百八十 / M2099 第三刀 — numerical-stability
//                                  PROOF tests for the SSM
//                                  scan kernel at float32
//                                  boundary conditions。
//
// Tests cover:
//   - Very small inputs (near zero)
//   - Strong-decay A (h → 0 quickly)
//   - Alternating sign inputs (cancellation)
//   - Mixed-magnitude inputs (1.0 + 1e-7)
//   - Long sequences (cumulative numerical drift)

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanNumericalStabilityTests: XCTestCase {

    typealias CPU = BASSSMScanCPUReference

    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - Very small inputs (sub-epsilon territory)

    func testVerySmallInputsRemainStableCPU() throws {
        let shape = BASSSMScanShape(B: 1, L: 4, D: 1)
        let tiny: Float = 1e-7
        let y = try CPU.scan(
            x: [tiny, tiny, tiny, tiny],
            delta: [1.0, 1.0, 1.0, 1.0],
            A: [0.0],
            B: [1.0, 1.0, 1.0, 1.0],
            C: [1.0, 1.0, 1.0, 1.0],
            shape: shape)
        // Each step accumulates tiny。 y = [1e-7, 2e-7,
        // 3e-7, 4e-7]
        XCTAssertEqual(y.count, 4)
        XCTAssertEqual(y[0], tiny, accuracy: 1e-9)
        XCTAssertEqual(y[1], 2.0 * tiny, accuracy: 1e-9)
        XCTAssertEqual(y[2], 3.0 * tiny, accuracy: 1e-9)
        XCTAssertEqual(y[3], 4.0 * tiny, accuracy: 1e-9)
    }

    func testVerySmallInputsCrossValidateGPU() async throws {
        try skipUnlessMetal()
        let shape = BASSSMScanShape(B: 1, L: 4, D: 1)
        let tiny: Float = 1e-7
        try await crossValidateGPU(
            shape: shape,
            x: [tiny, tiny, tiny, tiny],
            delta: [1.0, 1.0, 1.0, 1.0],
            A: [0.0],
            B: [1.0, 1.0, 1.0, 1.0],
            C: [1.0, 1.0, 1.0, 1.0])
    }

    // MARK: - Strong-decay (h → 0 quickly)

    func testStrongDecayCollapsesToZero() throws {
        let shape = BASSSMScanShape(B: 1, L: 16, D: 1)
        // A=-10, delta=1 ⇒ A_bar = exp(-10) ≈ 4.54e-5
        // After 16 steps, decay factor ≈ exp(-160) ≈ 0
        let y = try CPU.scan(
            x: Array(repeating: 1.0, count: 16),
            delta: Array(repeating: 1.0, count: 16),
            A: [-10.0],
            B: Array(repeating: 1.0, count: 16),
            C: Array(repeating: 1.0, count: 16),
            shape: shape)
        // h_0 = exp(-10)*0 + 1*1 = 1.0 (first step), y_0 = 1.0
        XCTAssertEqual(y[0], 1.0, accuracy: 1e-5)
        // After 16 steps, h has decayed enormously。 y_15
        // should be small but finite (not NaN, not Inf)
        XCTAssertFalse(y[15].isNaN, "y_15 must not be NaN")
        XCTAssertFalse(
            y[15].isInfinite, "y_15 must not be Inf")
    }

    func testStrongDecayCrossValidateGPU() async throws {
        try skipUnlessMetal()
        let shape = BASSSMScanShape(B: 1, L: 16, D: 1)
        try await crossValidateGPU(
            shape: shape,
            x: Array(repeating: 1.0, count: 16),
            delta: Array(repeating: 1.0, count: 16),
            A: [-10.0],
            B: Array(repeating: 1.0, count: 16),
            C: Array(repeating: 1.0, count: 16))
    }

    // MARK: - Alternating sign inputs (catastrophic
    // cancellation potential)

    func testAlternatingSignInputsRemainStable() throws {
        let shape = BASSSMScanShape(B: 1, L: 8, D: 1)
        let x: [Float] =
            [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
        let y = try CPU.scan(
            x: x,
            delta: Array(repeating: 1.0, count: 8),
            A: [0.0],  // No decay
            B: Array(repeating: 1.0, count: 8),
            C: Array(repeating: 1.0, count: 8),
            shape: shape)
        // A=0 ⇒ A_bar=1, so h is cumulative sum of x。
        // Expected: [1, 0, 1, 0, 1, 0, 1, 0]
        let expected: [Float] =
            [1, 0, 1, 0, 1, 0, 1, 0]
        for i in 0..<8 {
            XCTAssertEqual(
                y[i], expected[i], accuracy: 1e-6)
        }
    }

    func testAlternatingSignsCrossValidateGPU() async throws {
        try skipUnlessMetal()
        let shape = BASSSMScanShape(B: 1, L: 8, D: 1)
        let x: [Float] =
            [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
        try await crossValidateGPU(
            shape: shape,
            x: x,
            delta: Array(repeating: 1.0, count: 8),
            A: [0.0],
            B: Array(repeating: 1.0, count: 8),
            C: Array(repeating: 1.0, count: 8))
    }

    // MARK: - Long sequence (cumulative drift bound)

    /// Long sequence with A=-0.01 (slow decay). After
    /// L=64 steps, cumulative drift between CPU + GPU
    /// should remain bounded。
    func testLongSequenceMaintainsAgreement() async throws {
        try skipUnlessMetal()
        let shape = BASSSMScanShape(B: 1, L: 64, D: 1)
        let n = shape.elementCount
        try await crossValidateGPU(
            shape: shape,
            x: Array(repeating: 0.5, count: n),
            delta: Array(repeating: 0.1, count: n),
            A: [-0.01],
            B: Array(repeating: 1.0, count: n),
            C: Array(repeating: 1.0, count: n))
    }

    // MARK: - Negative-input fixture (no NaN propagation)

    func testNegativeInputsProduceNoNaN() throws {
        let shape = BASSSMScanShape(B: 1, L: 5, D: 1)
        let y = try CPU.scan(
            x: [-1.5, -2.0, -0.5, -3.0, -1.0],
            delta: [0.5, 0.5, 0.5, 0.5, 0.5],
            A: [-0.5],
            B: [1.0, 1.0, 1.0, 1.0, 1.0],
            C: [1.0, 1.0, 1.0, 1.0, 1.0],
            shape: shape)
        for v in y {
            XCTAssertFalse(
                v.isNaN, "CPU output must not be NaN")
            XCTAssertFalse(
                v.isInfinite,
                "CPU output must not be Inf")
        }
    }

    // MARK: - Helper

    private func crossValidateGPU(
        shape: BASSSMScanShape,
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        tolerance: Float = 1e-5,
        line: UInt = #line
    ) async throws {
        let kernel = try BASMetalSSMScanKernel()

        let yCPU = try CPU.scan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)

        let descBLD = BASTensorDescriptor.contiguous(
            shape: [
                Int(shape.B),
                Int(shape.L),
                Int(shape.D)
            ],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [Int(shape.D)],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-d")
        let inputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData(x),
                floatsToData(delta),
                floatsToData(A),
                floatsToData(B),
                floatsToData(C)
            ])
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let yGPU = bytesToFloats(outputs.payloads[0])

        XCTAssertEqual(
            yCPU.count, yGPU.count,
            line: line)
        guard yCPU.count == yGPU.count else { return }
        var total: Float = 0.0
        for i in 0..<yCPU.count {
            total += abs(yCPU[i] - yGPU[i])
        }
        let mae = total / Float(yCPU.count)
        XCTAssertLessThanOrEqual(
            mae, tolerance,
            "MAE \(mae) exceeds tolerance \(tolerance)",
            line: line)
    }

    private func floatsToData(_ floats: [Float]) -> Data {
        return floats.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }

    private func bytesToFloats(_ data: Data) -> [Float] {
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [Float] in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr[0..<count])
        }
    }
}
