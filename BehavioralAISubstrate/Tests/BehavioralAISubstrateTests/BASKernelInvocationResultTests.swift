// MARK: - BASKernelInvocationResultTests
// chapter 四百八十一 / M1300
//
// PROOF tests for the FIRST BASResult<Body> typealias
// migration in the substrate。 Closes the generic-
// primitive adoption gap beyond just BASBundle。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelInvocationResultTests: XCTestCase {

    // MARK: - Typealias resolves

    func testTypealiasResolvesToBASResult() {
        let body = BASKernelInvocationResultBody(
            kernelKey: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .metalBuffer),
            executionNanos: 1000,
            outputElementCount: 16)
        let result: BASKernelInvocationResult =
            BASResult(
                success: true, body: body,
                diagnostics: [])
        XCTAssertTrue(result.success)
        XCTAssertEqual(
            result.body.kernelKey.operation, .matMul)
    }

    // MARK: - Convenience accessors

    func testExecutionMicrosecondsConverts() {
        let result = BASKernelInvocationResult(
            success: true,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .softmax,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 2_500_000,
                outputElementCount: 100),
            diagnostics: [])
        XCTAssertEqual(
            result.executionMicroseconds, 2500.0,
            accuracy: 0.001)
    }

    func testHasErrorReflectsSuccessAndDiagnostics() {
        let success = BASKernelInvocationResult(
            success: true,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .matMul,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 100,
                outputElementCount: 4),
            diagnostics: [])
        XCTAssertFalse(success.hasError)

        let failedFlag = BASKernelInvocationResult(
            success: false,
            body: success.body,
            diagnostics: [])
        XCTAssertTrue(failedFlag.hasError)

        let successWithDiagnostics =
            BASKernelInvocationResult(
                success: true,
                body: success.body,
                diagnostics: ["warning:slow-dispatch"])
        XCTAssertTrue(
            successWithDiagnostics.hasError,
            "diagnostic warnings count as error" +
            " observation regardless of success flag")
    }

    // MARK: - .from(outputs:kernelKey:) factory

    func testFromFactoryComputesElementCount() {
        let descA = BASTensorDescriptor(
            shape: [4, 4],
            strides: [16, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descB = BASTensorDescriptor(
            shape: [2, 3],
            strides: [12, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let outputs = BASKernelOutputs(
            descriptors: [descA, descB],
            payloads: [
                Data(count: 64),
                Data(count: 24)
            ],
            executionNanos: 5_000_000)
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .metalBuffer)
        let result = BASResult.from(
            outputs: outputs, kernelKey: key)
        XCTAssertEqual(
            result.body.outputElementCount, 16 + 6,
            "elementCount sums across all output" +
            " descriptors")
        XCTAssertEqual(
            result.body.executionNanos, 5_000_000)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.diagnostics.isEmpty)
    }

    // MARK: - Codable round trip

    func testResultRoundTripsViaJSON() throws {
        let original = BASKernelInvocationResult(
            success: true,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .attention,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 12345,
                outputElementCount: 256),
            diagnostics: ["info:cache-hit"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelInvocationResult.self, from: data)
        XCTAssertEqual(decoded, original,
            "Codable round-trip (chapter 三百九二)")
    }

    // MARK: - First BASResult adoption milestone

    func testFirstBASResultAdoptionMilestone() {
        // M1281 BASKernelDispatchOutcomeBundle    = 1st BASBundle
        // M1286 BASMPSGraphKernelCoverageBundle   = 2nd BASBundle
        // M1297 BASMPSGraphCacheObservationBundle = 3rd BASBundle
        // M1300 BASKernelInvocationResult          = 1st BASResult
        let body = BASKernelInvocationResultBody(
            kernelKey: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .metalBuffer),
            executionNanos: 0,
            outputElementCount: 0)
        let _: BASKernelInvocationResult = BASResult(
            success: true, body: body, diagnostics: [])
        // Compile-time check passes:typealias resolves
        XCTAssertTrue(
            true,
            "M1300:first BASResult<Body> adoption" +
            " milestone reached")
    }
}
