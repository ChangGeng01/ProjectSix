// MARK: - BASKernelDispatchTraceFrameTests
// chapter 四百八十一 / M1302

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelDispatchTraceFrameTests: XCTestCase {

    private func sampleResult() -> BASKernelInvocationResult {
        BASKernelInvocationResult(
            success: true,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .matMul,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 1500,
                outputElementCount: 4),
            diagnostics: [])
    }

    func testTypealiasResolvesToBASFrameEnvelope() {
        let frame: BASKernelDispatchTraceFrame =
            BASFrameEnvelope.dispatchTrace(
                from: sampleResult(),
                correlationID: "turn-test",
                emittedAtMs: 1_700_000_000_000)
        XCTAssertEqual(
            frame.header.correlationID, "turn-test")
        XCTAssertEqual(
            frame.body.kernelKey.operation, .matMul)
    }

    func testFactoryProducesExpectedHeader() {
        let frame = BASFrameEnvelope.dispatchTrace(
            from: sampleResult(),
            correlationID: "session-42",
            producer: "test.producer",
            emittedAtMs: 1234)
        XCTAssertEqual(
            frame.header.schemaVersion, "1.0.0")
        XCTAssertEqual(
            frame.header.correlationID, "session-42")
        XCTAssertEqual(
            frame.header.producer, "test.producer")
        XCTAssertEqual(
            frame.header.emittedAtMs, 1234)
    }

    func testFrameRoundTripsViaJSON() throws {
        let original = BASFrameEnvelope.dispatchTrace(
            from: sampleResult(),
            correlationID: "round-trip",
            emittedAtMs: 1_700_000_000_000)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchTraceFrame.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testFirstBASFrameEnvelopeAdoptionMilestone() {
        // M1300 BASKernelInvocationResult     = 1st BASResult
        // M1301 BASNeuralOpCard                = 1st BASCard
        // M1302 BASKernelDispatchTraceFrame    = 1st BASFrameEnvelope
        let frame: BASKernelDispatchTraceFrame =
            BASFrameEnvelope(
                header: BASFrameEnvelopeHeader(
                    schemaVersion: "1.0.0",
                    correlationID: "milestone",
                    producer: "test",
                    emittedAtMs: 0),
                body: BASKernelInvocationResultBody(
                    kernelKey: BASKernelKey(
                        operation: .softmax,
                        dataType: .float32,
                        backingKind: .metalBuffer),
                    executionNanos: 0,
                    outputElementCount: 0))
        XCTAssertEqual(
            frame.header.correlationID, "milestone")
    }
}
