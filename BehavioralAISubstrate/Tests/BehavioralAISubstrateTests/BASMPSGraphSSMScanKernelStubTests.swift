// MARK: - BASMPSGraphSSMScanKernelStubTests
// chapter 四百九十六 / M1361 — original stub tests
// chapter 六百八十一 / M2101 — REPURPOSED tests reflecting
//                              the CPU-bytes sibling
//                              contract (no longer
//                              identity-scan stub)

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphSSMScanKernelStubTests: XCTestCase {

    // MARK: - 1) Key contract (M2101 repurpose:cpuBytes)

    func testKeyMatchesCpuBytesContract() {
        let kernel = BASMPSGraphSSMScanKernelStub()
        XCTAssertEqual(kernel.key.operation, .ssmScan)
        XCTAssertEqual(kernel.key.dataType, .float32)
        XCTAssertEqual(kernel.key.backingKind, .cpuBytes,
            "chapter 681 / M2101 repurpose:key MOVED " +
            "from metalBuffer to cpuBytes to avoid " +
            "collision with BASMetalSSMScanKernel")
        XCTAssertEqual(kernel.operation, .ssmScan)
    }

    // MARK: - 2) Implementation status (M2101: flipped to
    // .cpuSwiftReferenceProduction)

    func testImplementationStatusIsCpuSwiftRef() {
        let kernel = BASMPSGraphSSMScanKernelStub()
        XCTAssertEqual(kernel.implementationStatus,
                       .cpuSwiftReferenceProduction)
        XCTAssertTrue(kernel.implementationStatus
            .isProductionReady,
            "chapter 681 / M2101:status is production-" +
            "ready after CPU reference delegation")
        XCTAssertTrue(
            BASMPSGraphSSMScanKernelStub.isProductionReady,
            "chapter 681 / M2101:class-level " +
            "isProductionReady flag flipped to true")
    }

    // MARK: - 3) Implementation status enum exhaustiveness

    func testImplementationStatusAllCasesIs5() {
        // chapter 681 / M2101 added 5th case
        // .cpuSwiftReferenceProduction
        let cases = BASSSMScanKernelImplementationStatus
            .allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.stubIdentityScan))
        XCTAssertTrue(cases.contains(
            .cpuSwiftReferenceProduction))
        XCTAssertTrue(cases
            .contains(.metalShaderProduction))
        XCTAssertTrue(cases
            .contains(.mlxBridgeProduction))
        XCTAssertTrue(cases
            .contains(.coremlMlProgramProduction))
    }

    // MARK: - 4) Production-readiness gate (M2101: CPU
    // sibling is production-ready)

    func testProductionReadyGatePerStatus() {
        for status in
            BASSSMScanKernelImplementationStatus.allCases
        {
            switch status {
            case .stubIdentityScan:
                XCTAssertFalse(status.isProductionReady)
            case .cpuSwiftReferenceProduction,
                 .metalShaderProduction,
                 .mlxBridgeProduction,
                 .coremlMlProgramProduction:
                XCTAssertTrue(status.isProductionReady)
            }
        }
    }

    // MARK: - 5) CPU sibling produces correct math (NOT
    // identity-scan)

    func testCpuSiblingProducesCorrectMath() async throws {
        let kernel = BASMPSGraphSSMScanKernelStub()

        // Use the canonical chapter 679 / fixture 02
        // expected_y = [2.5] for x=2.5, A=0, delta=1
        let descBLD = BASTensorDescriptor.contiguous(
            shape: [1, 1, 1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "ssm-scan-d")

        let inputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData([2.5]),
                floatsToData([1.0]),
                floatsToData([0.0]),
                floatsToData([1.0]),
                floatsToData([1.0])
            ])
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let y = bytesToFloats(outputs.payloads[0])
        XCTAssertEqual(y.count, 1)
        XCTAssertEqual(y[0], 2.5, accuracy: 1e-5)
    }

    // MARK: - 6) Wrong input count throws

    func testWrongInputCountThrows() async {
        let kernel = BASMPSGraphSSMScanKernelStub()
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

    // MARK: - 7) Data type mismatch throws

    func testDataTypeMismatchThrows() async {
        let kernel = BASMPSGraphSSMScanKernelStub()
        let int32Desc = BASTensorDescriptor(
            shape: [1, 1, 1],
            strides: [4, 4, 4],
            dataType: .int32,
            backingKind: .cpuBytes,
            rankTag: "mismatch-test")
        let f32Desc = BASTensorDescriptor.contiguous(
            shape: [1, 1, 1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "ssm-scan-bld")
        let dDesc = BASTensorDescriptor.contiguous(
            shape: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "ssm-scan-d")
        let inputs = BASKernelInputs(
            descriptors: [
                int32Desc, f32Desc, dDesc, f32Desc, f32Desc
            ],
            payloads: [
                Data(count: int32Desc.byteCount),
                floatsToData([1.0]),
                floatsToData([0.0]),
                floatsToData([1.0]),
                floatsToData([1.0])
            ])
        do {
            _ = try await kernel.evaluate(inputs: inputs)
            XCTFail("expected dataTypeMismatch throw")
        } catch let error as BASKernelError {
            guard case .dataTypeMismatch = error else {
                XCTFail("wrong BASKernelError:\(error)")
                return
            }
        } catch {
            XCTFail("unexpected error:\(error)")
        }
    }

    // MARK: - 8) Status enum Codable round-trip

    func testStatusCodableRoundTrip() throws {
        let status: BASSSMScanKernelImplementationStatus =
            .cpuSwiftReferenceProduction
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(
            BASSSMScanKernelImplementationStatus.self,
            from: data)
        XCTAssertEqual(decoded, status)
    }

    // MARK: - 9) Typealias bridge (M2101)

    func testCPUSSMScanKernelTypealias() {
        let viaTypealias = BASCPUSSMScanKernel()
        XCTAssertEqual(
            viaTypealias.key.backingKind, .cpuBytes)
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
