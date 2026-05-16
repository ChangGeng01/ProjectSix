// MARK: - BASMetalSSMScanKernelCrossValidationTests
// chapter 六百七十八 / M2091 第三刀 — cross-validation PROOF
//                                    tests asserting REAL GPU
//                                    kernel output matches
//                                    the CPU reference to
//                                    MAE ≤ 1e-5 on shared
//                                    fixtures。
//
// This is THE numerical-correctness proof for the chapter
// 六百七十七 / M2085 MSL kernel:if BASMetalSSMScanKernel
// agrees with BASSSMScanCPUReference on multiple non-trivial
// fixtures within 1e-5 mean absolute error,we've proven
// the MSL implementation is mathematically correct。
//
// Canonical Python reference fixture cross-validation lands
// at chapter 六百八十 / M2097-M2100。 This M2091 suite
// validates GPU ↔ CPU agreement INTERNALLY (both sides
// substrate-authored)。

import XCTest
@testable import BASMetalSubstrate

final class BASMetalSSMScanKernelCrossValidationTests:
    XCTestCase
{

    typealias Ref = BASSSMScanCPUReference

    /// Mean absolute error tolerance between GPU + CPU
    /// outputs。 Mamba selective-scan recurrence + exp()
    /// + multiplication chains accumulate small FMA-
    /// reordering differences;1e-5 is generous enough to
    /// allow these while still catching real divergence。
    private let maeToleranceFloat32: Float = 1e-5

    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - Deterministic pseudo-random helper

    /// LCG-based deterministic pseudo-random sequence in
    /// [-1.0, 1.0]。 Used so cross-validation fixtures
    /// don't depend on system RNG。
    private func deterministicFloats(
        count: Int, seed: UInt32
    ) -> [Float] {
        var rng: UInt32 = seed
        var out = [Float](repeating: 0.0, count: count)
        for i in 0..<count {
            // Numerical Recipes LCG constants
            rng = rng &* 1664525 &+ 1013904223
            // Map to [-1, 1]
            let unit = Float(rng) / Float(UInt32.max)
            out[i] = unit * 2.0 - 1.0
        }
        return out
    }

    // MARK: - Cross-validation harness

    private func crossValidate(
        B: Int,
        L: Int,
        D: Int,
        seed: UInt32,
        deltaSeedOffset: UInt32 = 7,
        aSeedOffset: UInt32 = 11,
        bSeedOffset: UInt32 = 13,
        cSeedOffset: UInt32 = 17,
        line: UInt = #line
    ) async throws {
        let shape = BASSSMScanShape(
            B: UInt32(B), L: UInt32(L), D: UInt32(D))
        let n = shape.elementCount

        let x = deterministicFloats(
            count: n, seed: seed)
        // Keep delta SMALL (typical Mamba range
        // softplus(-4) ≈ 0.018) to avoid overflow in
        // exp() — A is negative,delta * A in [-1, 0]
        // typical range yields stable exp()。
        let deltaRaw = deterministicFloats(
            count: n,
            seed: seed &+ deltaSeedOffset)
        let delta = deltaRaw.map { (($0 + 1.0) * 0.5) * 0.5 }
            // map [-1,1] → [0, 0.5]
        let A = deterministicFloats(
            count: D, seed: seed &+ aSeedOffset)
            .map { $0 - 1.0 }   // shift to [-2, 0]
        let bArr = deterministicFloats(
            count: n, seed: seed &+ bSeedOffset)
        let cArr = deterministicFloats(
            count: n, seed: seed &+ cSeedOffset)

        // CPU reference
        let yCPU = try Ref.scan(
            x: x, delta: delta, A: A,
            B: bArr, C: cArr,
            shape: shape)

        // GPU kernel
        let kernel = try BASMetalSSMScanKernel()
        let descBLD = BASTensorDescriptor.contiguous(
            shape: [B, L, D],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [D],
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
                floatsToData(bArr),
                floatsToData(cArr)
            ])
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let yGPU = bytesToFloats(outputs.payloads[0])

        // Compute MAE
        XCTAssertEqual(
            yCPU.count, yGPU.count,
            "GPU vs CPU output element-count mismatch",
            line: line)
        guard yCPU.count == yGPU.count else { return }
        var totalAbsError: Float = 0.0
        var maxAbsError: Float = 0.0
        for i in 0..<yCPU.count {
            let e = abs(yCPU[i] - yGPU[i])
            totalAbsError += e
            maxAbsError = max(maxAbsError, e)
        }
        let mae = totalAbsError / Float(yCPU.count)
        XCTAssertLessThanOrEqual(
            mae, maeToleranceFloat32,
            "MAE \(mae) exceeds tolerance " +
            "\(maeToleranceFloat32) for fixture " +
            "(B=\(B), L=\(L), D=\(D), seed=\(seed))。 " +
            "maxAbs=\(maxAbsError)",
            line: line)
    }

    // MARK: - Cross-validation fixtures

    func testCrossValidateB1L1D1Seed42() async throws {
        try skipUnlessMetal()
        try await crossValidate(B: 1, L: 1, D: 1, seed: 42)
    }

    func testCrossValidateB1L4D4Seed123() async throws {
        try skipUnlessMetal()
        try await crossValidate(B: 1, L: 4, D: 4, seed: 123)
    }

    func testCrossValidateB2L8D8Seed777() async throws {
        try skipUnlessMetal()
        try await crossValidate(B: 2, L: 8, D: 8, seed: 777)
    }

    func testCrossValidateB3L16D16Seed31337() async throws {
        try skipUnlessMetal()
        try await crossValidate(
            B: 3, L: 16, D: 16, seed: 31337)
    }

    func testCrossValidateB4L32D32SeedDeadbeef() async throws {
        try skipUnlessMetal()
        try await crossValidate(
            B: 4, L: 32, D: 32, seed: 0xDEAD_BEEF)
    }

    func testCrossValidateLongSequenceB1L128D8() async throws {
        try skipUnlessMetal()
        try await crossValidate(
            B: 1, L: 128, D: 8, seed: 0xCAFE)
    }

    func testCrossValidateNarrowChannelB8L16D1() async throws {
        try skipUnlessMetal()
        try await crossValidate(
            B: 8, L: 16, D: 1, seed: 0xBABE)
    }

    func testCrossValidateLargeChannelB1L4D64() async throws {
        try skipUnlessMetal()
        try await crossValidate(
            B: 1, L: 4, D: 64, seed: 0xF00D)
    }

    // MARK: - Determinism PROOF — same fixture twice yields
    // byte-equal GPU output

    func testGPUDispatchIsDeterministic() async throws {
        try skipUnlessMetal()

        let kernel = try BASMetalSSMScanKernel()
        let shape = BASSSMScanShape(B: 2, L: 4, D: 4)
        let n = shape.elementCount
        let x = deterministicFloats(count: n, seed: 100)
        let delta = deterministicFloats(count: n, seed: 101)
            .map { abs($0) * 0.5 }
        let A = deterministicFloats(count: 4, seed: 102)
            .map { -abs($0) }
        let bArr = deterministicFloats(count: n, seed: 103)
        let cArr = deterministicFloats(count: n, seed: 104)

        let descBLD = BASTensorDescriptor.contiguous(
            shape: [2, 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [4],
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
                floatsToData(bArr),
                floatsToData(cArr)
            ])
        let out1 = try await kernel.evaluate(inputs: inputs)
        let out2 = try await kernel.evaluate(inputs: inputs)
        XCTAssertEqual(
            out1.payloads[0], out2.payloads[0],
            "GPU kernel output must be bit-stable across " +
            "two evaluations of the same input")
    }

    // MARK: - Helpers

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
