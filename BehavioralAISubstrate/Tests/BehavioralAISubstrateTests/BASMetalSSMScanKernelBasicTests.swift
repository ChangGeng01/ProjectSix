// MARK: - BASMetalSSMScanKernelBasicTests
// chapter 六百七十八 / M2089 第一刀 PROOF — basic structural
//                                       tests that the real
//                                       Metal SSM kernel
//                                       compiles + runs +
//                                       returns sane shapes
//                                       on macOS。
//
// Per-fixture numerical correctness PROOF (MAE ≤ 1e-5 vs
// reference values) lands at chapter 六百八十 / M2097-M2100。
// This M2089 suite is the COMPILE + DISPATCH smoke test —
// proving the actor wraps MSL → MTLLibrary → MTLPipelineState
// → dispatch flow successfully + the output bundle has the
// expected shape category。

import XCTest
@testable import BASMetalSubstrate

final class BASMetalSSMScanKernelBasicTests: XCTestCase {

    // MARK: - Skip protocol — Metal availability gate

    /// Skip the suite on platforms without a default Metal
    /// device (Linux,watchOS,iOS Simulator without GPU)。
    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - Construction PROOF

    func testCanInstantiateKernel() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()
        let key = kernel.key
        XCTAssertEqual(key.operation, .ssmScan)
        XCTAssertEqual(key.dataType, .float32)
        XCTAssertEqual(key.backingKind, .metalBuffer)
    }

    func testKeyMatchesBASMetalKernelProtocol() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()
        XCTAssertEqual(kernel.operation, .ssmScan)
    }

    // MARK: - Dispatch PROOF — sanity zero-state run

    /// Smoke test:run the kernel with x = [1,1,1,...]
    /// + delta = [0,0,0,...] + A = [-1,-1,...] + B = [1,...]
    /// + C = [1,...]。 Since delta == 0:
    ///   A_bar = exp(0 * A) = 1
    ///   B_bar = 0 * B = 0
    ///   h_t = 1 * h_{t-1} + 0 * x_t = h_{t-1}  (stays 0)
    ///   y_t = C * 0 = 0
    /// Expected output:all zeros。
    func testZeroDeltaProducesZeroOutput() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()

        let B = 1
        let L = 4
        let D = 3

        let inputs = try makeInputs(
            B: B, L: L, D: D,
            xValue: 1.0,
            deltaValue: 0.0,
            aValue: -1.0,
            bValue: 1.0,
            cValue: 1.0)

        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1)
        XCTAssertEqual(outputs.payloads.count, 1)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [B, L, D])

        let yFloats = bytesToFloats(outputs.payloads[0])
        XCTAssertEqual(yFloats.count, B * L * D)
        for v in yFloats {
            XCTAssertEqual(v, 0.0, accuracy: 1e-6)
        }
    }

    /// Smoke test:single time step (L=1) with A=0 + delta=1
    /// + B=1 + C=1 + x=2.5。 Expected:
    ///   A_bar = exp(1 * 0) = 1
    ///   B_bar = 1 * 1 = 1
    ///   h_0 = 1 * 0 + 1 * 2.5 = 2.5
    ///   y_0 = 1 * 2.5 = 2.5
    func testSingleStepIdentityScan() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()

        let inputs = try makeInputs(
            B: 1, L: 1, D: 1,
            xValue: 2.5,
            deltaValue: 1.0,
            aValue: 0.0,
            bValue: 1.0,
            cValue: 1.0)

        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let yFloats = bytesToFloats(outputs.payloads[0])
        XCTAssertEqual(yFloats.count, 1)
        XCTAssertEqual(yFloats[0], 2.5, accuracy: 1e-5)
    }

    // MARK: - Failure modes

    func testThrowsOnWrongInputCount() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()

        let bogus = BASKernelInputs(
            descriptors: [],
            payloads: [])
        do {
            _ = try await kernel.evaluate(inputs: bogus)
            XCTFail("expected throw")
        } catch let BASKernelError.shapeMismatch(reason) {
            XCTAssertTrue(reason.contains("5 inputs"))
        } catch {
            XCTFail("wrong error type:\(error)")
        }
    }

    // MARK: - Helpers

    private func makeInputs(
        B: Int, L: Int, D: Int,
        xValue: Float,
        deltaValue: Float,
        aValue: Float,
        bValue: Float,
        cValue: Float
    ) throws -> BASKernelInputs {
        let xfloats = Array(
            repeating: xValue, count: B * L * D)
        let dfloats = Array(
            repeating: deltaValue, count: B * L * D)
        let afloats = Array(
            repeating: aValue, count: D)
        let bfloats = Array(
            repeating: bValue, count: B * L * D)
        let cfloats = Array(
            repeating: cValue, count: B * L * D)

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

        return BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData(xfloats),
                floatsToData(dfloats),
                floatsToData(afloats),
                floatsToData(bfloats),
                floatsToData(cfloats)
            ])
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
