// chapter 四百八十四 / M1312
import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMetalSubstrateFrameEnvelopeAdoptionsTests:
    XCTestCase
{
    private func header() -> BASFrameEnvelopeHeader {
        BASFrameEnvelopeHeader(
            schemaVersion: "1.0.0",
            correlationID: "t1",
            producer: "test",
            emittedAtMs: 0)
    }

    func testSecondFrameEnvelopeAdoption() {
        let body = BASKernelInvocationResultBody(
            kernelKey: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .metalBuffer),
            executionNanos: 100,
            outputElementCount: 4)
        let frame: BASKernelCorrectnessTraceFrame =
            BASFrameEnvelope(
                header: header(), body: body)
        XCTAssertEqual(
            frame.header.correlationID, "t1")
    }

    func testThirdFrameEnvelopeAdoption() {
        let body = BASSchedulerAssignmentResultBody(
            chosenBacking: .metalBuffer,
            kernelKeyAssigned: true,
            costScore: 1.0)
        let frame: BASSchedulerDecisionTraceFrame =
            BASFrameEnvelope(
                header: header(), body: body)
        XCTAssertEqual(
            frame.body.chosenBacking, .metalBuffer)
    }

    func testFourthFrameEnvelopeAdoption() {
        let body = BASKernelRegistryDispatchResultBody(
            dispatchedKeyCount: 3,
            fallbackCount: 0,
            durationMs: 5)
        let frame: BASCacheObservationTraceFrame =
            BASFrameEnvelope(
                header: header(), body: body)
        XCTAssertEqual(
            frame.body.dispatchedKeyCount, 3)
    }
}
