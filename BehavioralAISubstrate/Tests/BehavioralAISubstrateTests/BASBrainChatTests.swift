// ch1048 / v1.0 §11 — proofs for BASBrainChat (the governed brain.chat entry).
//
// Verifies the facade curates a REAL turn result (from the stub coordinator) into the §11 response
// shape, honors effort (receipt) + transcript (rendered view) at the facade boundary, and is
// transparent (the executor runs the host's real pipeline). The effort-receipt rule is tested as a
// pure function; the request mapping onto the existing pipeline request is tested directly.

import XCTest
import Foundation
@testable import BASHostKit
import BASOrgan
import BASRuntimeCore

final class BASBrainChatTests: XCTestCase {

    private let recorded = Date(timeIntervalSince1970: 1_700_000_000)

    private func request(effort: BASEffortLevel = .balanced,
                         transcript: BASTranscriptMode = .summary) -> BASBrainChatRequest {
        BASBrainChatRequest(hostID: "stub.host", message: "hello",
                            effort: effort, transcript: transcript,
                            deviceState: BASCoordinatorTestStubs.nominalDeviceState,
                            recordedAt: recorded)
    }

    private func acceptedTrace(_ id: String) -> BASProcessTrace {
        BASProcessTrace(callID: id, purpose: .plan, agentRef: "planner", verifierRef: nil,
                        inputRefs: [], contractDigestHex: "d", providerID: "det",
                        inputTokens: 5, outputTokens: 7, producedAt: recorded,
                        traceID: id, verdict: .accepted)
    }

    // The facade curates a REAL turn result into the 6 spec outputs.
    func testChatCuratesRealTurnIntoSpecResponse() async throws {
        let coord = BASCoordinatorTestStubs.makeStub()
        let req = request(transcript: .off)
        let expected = coord.runTurn(req.toTurnRequest())              // a real BASEBrainTurnResult
        let chat = BASBrainChat(executor: { _ in expected })           // inject the real result
        let resp = try await chat.chat(req)

        XCTAssertEqual(resp.surface, expected.actionPermit.mode, "surface = the permit-selected kind")
        XCTAssertEqual(resp.actionPermit, expected.actionPermit)
        XCTAssertEqual(resp.updateTickets, expected.updateTickets)
        XCTAssertEqual(resp.sovereignVerdict, expected.sovereignVerdict)
        XCTAssertEqual(resp.effortReceipt.requested, .balanced)
        XCTAssertNil(resp.processTraceRef, "no traces wired → nil ref")
        XCTAssertTrue(resp.transcriptLines.isEmpty, "transcript .off → empty process view")
    }

    // transcript is honored at the facade boundary: traces → rendered lines + a processTraceRef.
    func testTranscriptAndTraceRefHonored() async throws {
        let coord = BASCoordinatorTestStubs.makeStub()
        let req = request(transcript: .summary)
        let expected = coord.runTurn(req.toTurnRequest())
        let traces = [acceptedTrace("tr1"), acceptedTrace("tr2")]
        let chat = BASBrainChat(executor: { _ in expected }, traceProvider: { _ in traces })
        let resp = try await chat.chat(req)
        XCTAssertEqual(resp.processTraceRef, "tr1", "ref = the first governed-call trace")
        XCTAssertFalse(resp.transcriptLines.isEmpty, "summary of 2 traces renders ≥1 line")
    }

    // The effort-receipt rule (pure): granted when a lease exists; else downgraded to guarded.
    func testEffortReceiptRule() {
        let granted = BASBrainChat.effortReceipt(requested: .deep, leaseGranted: true)
        XCTAssertEqual(granted.requested, .deep)
        XCTAssertEqual(granted.applied, .deep)
        XCTAssertNil(granted.overrideReason)
        XCTAssertFalse(granted.wasOverridden)

        let down = BASBrainChat.effortReceipt(requested: .deep, leaseGranted: false)
        XCTAssertEqual(down.applied, .guarded)
        XCTAssertEqual(down.overrideReason, "no_run_lease")
        XCTAssertTrue(down.wasOverridden)
    }

    // The request maps onto the existing pipeline request (the fields runTurn consumes today).
    func testRequestMapsToTurnRequest() {
        let req = BASBrainChatRequest(hostID: "h1", message: "hello there",
                                      deviceState: BASCoordinatorTestStubs.nominalDeviceState,
                                      recordedAt: recorded)
        let turn = req.toTurnRequest()
        XCTAssertEqual(turn.userInput, "hello there")
        XCTAssertEqual(turn.hostID, "h1")
        XCTAssertEqual(turn.recordedAt, recorded)
    }

    // The facade is transparent: it runs the host's executor exactly once per chat.
    func testExecutorRunsOncePerChat() async throws {
        let coord = BASCoordinatorTestStubs.makeStub()
        let req = request()
        let expected = coord.runTurn(req.toTurnRequest())
        let counter = CallCounter()
        let chat = BASBrainChat(executor: { _ in counter.bump(); return expected })
        _ = try await chat.chat(req)
        _ = try await chat.chat(req)
        XCTAssertEqual(counter.value, 2)
    }

    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock(); private var n = 0
        func bump() { lock.lock(); n += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    }
}
