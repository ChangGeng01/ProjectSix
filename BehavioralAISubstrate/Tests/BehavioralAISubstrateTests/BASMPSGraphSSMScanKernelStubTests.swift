// MARK: - BASMPSGraphSSMScanKernelStubTests
// chapter 四百九十六 / M1361-M1362 — ssmScan kernel stub tests

import XCTest
@testable import BASMetalSubstrate

final class BASMPSGraphSSMScanKernelStubTests: XCTestCase {

    // MARK: - 1) Key contract

    func testKeyMatchesContract() {
        let stub = BASMPSGraphSSMScanKernelStub()
        XCTAssertEqual(stub.key.operation, .ssmScan)
        XCTAssertEqual(stub.key.dataType, .float32)
        XCTAssertEqual(stub.key.backingKind,
                       .metalBuffer)
        XCTAssertEqual(stub.operation, .ssmScan)
    }

    // MARK: - 2) Implementation status flag

    func testImplementationStatusIsStubIdentityScan() {
        let stub = BASMPSGraphSSMScanKernelStub()
        XCTAssertEqual(stub.implementationStatus,
                       .stubIdentityScan)
        XCTAssertFalse(stub.implementationStatus
            .isProductionReady)
        XCTAssertFalse(
            BASMPSGraphSSMScanKernelStub.isProductionReady)
    }

    // MARK: - 3) Implementation status enum exhaustiveness

    func testImplementationStatusAllCasesIsExpected() {
        let cases = BASSSMScanKernelImplementationStatus
            .allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.stubIdentityScan))
        XCTAssertTrue(cases
            .contains(.metalShaderProduction))
        XCTAssertTrue(cases
            .contains(.mlxBridgeProduction))
        XCTAssertTrue(cases
            .contains(.coremlMlProgramProduction))
    }

    // MARK: - 4) isProductionReady gate

    func testProductionReadyGatePerStatus() {
        for status in
            BASSSMScanKernelImplementationStatus.allCases
        {
            switch status {
            case .stubIdentityScan:
                XCTAssertFalse(status.isProductionReady)
            case .metalShaderProduction,
                 .mlxBridgeProduction,
                 .coremlMlProgramProduction:
                XCTAssertTrue(status.isProductionReady)
            }
        }
    }

    // MARK: - 5) Identity scan returns inputs verbatim

    func testIdentityScanReturnsInputsVerbatim() async throws {
        let stub = BASMPSGraphSSMScanKernelStub()
        // Build a 3-element float32 input
        let values: [Float] = [1.0, 2.0, 3.0]
        let payload = values.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let descriptor = BASTensorDescriptor(
            shape: [3],
            strides: [1],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "stub-test")
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        let outputs = try await stub.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.descriptors, [descriptor])
        XCTAssertEqual(outputs.payloads, [payload])
        XCTAssertEqual(outputs.executionNanos, 0)
    }

    // MARK: - 6) Type mismatch throws

    func testDataTypeMismatchThrows() async {
        let stub = BASMPSGraphSSMScanKernelStub()
        let descriptor = BASTensorDescriptor(
            shape: [3],
            strides: [1],
            dataType: .int32,
            backingKind: .metalBuffer,
            rankTag: "mismatch-test")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        do {
            _ = try await stub.evaluate(inputs: inputs)
            XCTFail("expected dataTypeMismatch throw")
        } catch let error as BASKernelError {
            guard
                case .dataTypeMismatch(
                    expected: let expected,
                    actual: let actual) = error
            else {
                XCTFail(
                    "wrong BASKernelError case: \(error)")
                return
            }
            XCTAssertEqual(expected, .float32)
            XCTAssertEqual(actual, .int32)
        } catch {
            XCTFail(
                "unexpected error: \(error)")
        }
    }

    // MARK: - 7) Codable round-trip on status enum

    func testStatusCodableRoundTrip() throws {
        let status: BASSSMScanKernelImplementationStatus =
            .metalShaderProduction
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(
            BASSSMScanKernelImplementationStatus.self,
            from: data)
        XCTAssertEqual(decoded, status)
    }
}
