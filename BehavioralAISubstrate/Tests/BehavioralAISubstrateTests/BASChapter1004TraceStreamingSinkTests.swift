// MARK: - BASChapter1004TraceStreamingSinkTests
// chapter 一千零四 / M3725 — `recordEvent` scaffold close via
// `BASAgentTraceStreamingSink` protocol + reference impl
//
// Pre-ch-1004 state (per Docs/SCAFFOLD_VS_WIRED.md ch 996
// inventory + forward-closure item #5):
//   - `BASAgentTraceLogEventLogBridge.recordEvent(...)` shipped
//     at ch 984 as per-event write-through
//   - But production paths invoked `flush(forTurn:)` at turn-end
//   - No documented protocol for hosts wanting per-event
//     streaming subscription
//   - Hosts wanting Kafka publisher / websocket fanout /
//     observability stream had to invent integration on top of
//     the bridge — no contract, no reference impl
//
// Ch 1004 ships the protocol + reference impl + bridge
// integration that closes the gap。
//
// Tests pin:
//   1. Sink receives event when recordEvent(streamingTo:) called
//   2. Stamped event in sink has correct sequenceNumber
//   3. Sink receives eventLogResult (wasNew + assignedSeq)
//   4. Multiple recordEvent calls accumulate in buffering sink
//   5. CRITICAL: sink throwing does NOT roll back the bridge
//      writes (best-effort notification semantics)
//   6. Buffering sink snapshot returns sorted accumulation
//   7. Buffering sink clear() resets the buffer

import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter1004TraceStreamingSinkTests: XCTestCase {

    // MARK: - Test fixtures

    private func makeBridge() async -> (
        bridge: BASAgentTraceLogEventLogBridge,
        traceLog: BASAgentTraceLog,
        eventLog: BASInMemoryEventLogStorage
    ) {
        let traceLog = BASAgentTraceLog()
        let eventLog = BASInMemoryEventLogStorage()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog,
            eventLog: eventLog,
            sessionID: "ch1004.test")
        return (bridge, traceLog, eventLog)
    }

    private static func makeEvent(
        turnID: String = "t-1",
        seqHint: Int64 = 0,
        agentID: String? = "ch1004.scout"
    ) -> BASAgentTraceEvent {
        BASAgentTraceEvent(
            sequenceNumber: seqHint,
            turnID: turnID,
            createdAtNanos: 1000,
            kind: .deltaEmitted,
            agentID: agentID,
            deltaID: "delta.\(turnID).scout.1",
            payloadJson: "{}")
    }

    // MARK: - 1. Sink receives event

    func testCRITICAL_Sink_ReceivesEvent() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        let event = Self.makeEvent()
        _ = try await bridge.recordEvent(
            event, streamingTo: sink)
        let count = await sink.count()
        XCTAssertEqual(count, 1,
            "ch 1004 CRITICAL: sink MUST receive exactly 1 " +
            "notification per recordEvent(streamingTo:) call")
    }

    // MARK: - 2. Stamped event has correct sequenceNumber

    func test_StampedEvent_HasCorrectSequence() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        let event = Self.makeEvent()
        let result = try await bridge.recordEvent(
            event, streamingTo: sink)
        let snapshot = await sink.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(
            snapshot[0].event.sequenceNumber, result.traceSeq,
            "ch 1004: sink event MUST have the bridge-assigned " +
            "sequenceNumber (matches what landed in event log)")
    }

    // MARK: - 3. Sink receives eventLogResult

    func test_Sink_ReceivesEventLogResult() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        let event = Self.makeEvent()
        _ = try await bridge.recordEvent(
            event, streamingTo: sink)
        let snapshot = await sink.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertTrue(snapshot[0].wasNew,
            "ch 1004: first recordEvent MUST set wasNew=true " +
            "(unique eventID)")
        // sequenceNumber is monotonic-from-zero per session
        // (in-memory storage starts at 0, persistent at >0)
        XCTAssertGreaterThanOrEqual(
            snapshot[0].assignedSequenceNumber, 0,
            "ch 1004: assignedSequenceNumber MUST be ≥0 " +
            "(in-memory storage assigns starting at 0)")
    }

    // MARK: - 4. Multiple records accumulate

    func test_MultipleRecords_Accumulate() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        for i in 0..<5 {
            let event = Self.makeEvent(
                turnID: "t-\(i)",
                seqHint: Int64(i))
            _ = try await bridge.recordEvent(
                event, streamingTo: sink)
        }
        let count = await sink.count()
        XCTAssertEqual(count, 5,
            "ch 1004: 5 recordEvent calls MUST produce 5 sink " +
            "entries in order")
    }

    // MARK: - 5. CRITICAL — sink throw does NOT roll back writes

    /// A sink that always throws when receiving。 Tests the
    /// best-effort semantics:bridge writes complete BEFORE
    /// the sink is notified,so a throw doesn't undo them。
    private struct ThrowingSink: BASAgentTraceStreamingSink {
        struct SinkError: Error {}
        func receive(
            _ event: BASAgentTraceEvent,
            eventLogResult: (
                wasNew: Bool,
                assignedSequenceNumber: Int64)
        ) async throws {
            throw SinkError()
        }
    }

    func testCRITICAL_SinkThrow_DoesNotRollBackBridgeWrites()
        async throws
    {
        let (bridge, traceLog, eventLog) = await makeBridge()
        let throwingSink = ThrowingSink()
        let event = Self.makeEvent()
        // Expect throw from sink
        do {
            _ = try await bridge.recordEvent(
                event, streamingTo: throwingSink)
            XCTFail("ch 1004: throwing sink MUST propagate error")
        } catch is ThrowingSink.SinkError {
            // expected
        }
        // BUT the bridge writes MUST have completed before the
        // sink notification — verify trace log AND event log
        // both have the record。
        let traceEvents = await traceLog.events(
            forTurn: event.turnID)
        XCTAssertEqual(traceEvents.count, 1,
            "ch 1004 CRITICAL: sink throw MUST NOT roll back " +
            "trace-log write (best-effort notification semantics)")
        // Event log: count check via session events readback
        let eventLogEvents = await eventLog
            .events(forSession: "ch1004.test")
        XCTAssertGreaterThanOrEqual(eventLogEvents.count, 1,
            "ch 1004 CRITICAL: sink throw MUST NOT roll back " +
            "event-log write either")
    }

    // MARK: - 6. Snapshot returns accumulated order

    func test_Snapshot_PreservesInsertOrder() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        for i in 0..<3 {
            let event = Self.makeEvent(turnID: "t-\(i)")
            _ = try await bridge.recordEvent(
                event, streamingTo: sink)
        }
        let snapshot = await sink.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot[0].event.turnID, "t-0")
        XCTAssertEqual(snapshot[1].event.turnID, "t-1")
        XCTAssertEqual(snapshot[2].event.turnID, "t-2")
    }

    // MARK: - 7. Clear resets buffer

    func test_Clear_ResetsBuffer() async throws {
        let (bridge, _, _) = await makeBridge()
        let sink = BASAgentTraceBufferingSink()
        let event = Self.makeEvent()
        _ = try await bridge.recordEvent(
            event, streamingTo: sink)
        var count = await sink.count()
        XCTAssertEqual(count, 1)
        await sink.clear()
        count = await sink.count()
        XCTAssertEqual(count, 0,
            "ch 1004: clear() MUST empty the buffer")
    }
}
