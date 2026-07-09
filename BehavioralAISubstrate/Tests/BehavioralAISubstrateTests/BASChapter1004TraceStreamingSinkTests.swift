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
        // audit orchestration MED-4: the throw is now WRAPPED in SinkNotificationError (the writes
        // are durable; only the notification failed) — not a bare rethrow that looks like the write
        // itself failed and invites a double-writing retry.
        var seenTraceSeq: Int64 = -1
        do {
            _ = try await bridge.recordEvent(
                event, streamingTo: throwingSink)
            XCTFail("ch 1004: throwing sink MUST propagate error")
        } catch let err as BASAgentTraceLogEventLogBridge.SinkNotificationError {
            XCTAssertTrue(err.underlying is ThrowingSink.SinkError,
                "the sink's own error must be carried as .underlying")
            seenTraceSeq = err.committedTraceSeq
            XCTAssertEqual(err.committedResult.traceSeq, err.committedTraceSeq,
                "committedResult mirrors the carried fields")
        }
        // BUT the bridge writes MUST have completed before the
        // sink notification — verify trace log AND event log
        // both have the record。
        let traceEvents = await traceLog.events(
            forTurn: event.turnID)
        XCTAssertEqual(traceEvents.count, 1,
            "ch 1004 CRITICAL: sink throw MUST NOT roll back " +
            "trace-log write (best-effort notification semantics)")
        XCTAssertEqual(seenTraceSeq, traceEvents.first?.sequenceNumber,
            "the error's committedTraceSeq must equal the durably-committed trace seq")
        // Event log: count check via session events readback
        let eventLogEvents = await eventLog
            .events(forSession: "ch1004.test")
        XCTAssertGreaterThanOrEqual(eventLogEvents.count, 1,
            "ch 1004 CRITICAL: sink throw MUST NOT roll back " +
            "event-log write either")
    }

    // MARK: - 5b. MED-4 teeth — re-deliver from the error, no double-write

    /// audit orchestration MED-4: on a sink throw the caller must be able to RE-DELIVER the event
    /// to a sink using the error's carried committedResult — WITHOUT re-invoking recordEvent, which
    /// would append a duplicate (new traceSeq ⇒ new eventID ⇒ event-log dedup misses). This pins the
    /// no-duplicate recovery path the SinkNotificationError enables.
    func testMED4_SinkThrow_CarriesResultForDuplicateFreeReDelivery()
        async throws
    {
        let (bridge, traceLog, eventLog) = await makeBridge()
        let event = Self.makeEvent()
        let recovery = BASAgentTraceBufferingSink()

        do {
            _ = try await bridge.recordEvent(event, streamingTo: ThrowingSink())
            XCTFail("throwing sink must surface an error")
        } catch let err as BASAgentTraceLogEventLogBridge.SinkNotificationError {
            // Re-deliver to a HEALTHY sink from the carried state — no re-record.
            try await recovery.receive(
                err.stampedEvent, eventLogResult: err.committedResult.eventLogResult)
        }

        // The logs must still hold EXACTLY ONE copy — re-delivery did not touch the bridge.
        let traceEvents = await traceLog.events(forTurn: event.turnID)
        let eventCount = await eventLog.events(forSession: "ch1004.test").count
        let recovered = await recovery.snapshot()
        XCTAssertEqual(traceEvents.count, 1, "MED-4: re-delivery must NOT append a second trace-log row")
        XCTAssertEqual(eventCount, 1, "MED-4: re-delivery must NOT append a second event-log row")
        XCTAssertEqual(recovered.count, 1, "the recovery sink received the event exactly once")
        XCTAssertEqual(recovered.first?.event.sequenceNumber, traceEvents.first?.sequenceNumber,
            "the re-delivered event carries the bridge-assigned sequence (not the caller's seqHint)")
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

    // MARK: - audit orchestration LOW-2: concurrent recordEvent can't interleave the two writes

    func testLOW2_ConcurrentRecordEventsKeepEventLogInTraceOrder() async throws {
        let traceLog = BASAgentTraceLog()
        let gated = GatedAppendEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog, eventLog: gated, sessionID: "low2.test")
        let e1 = Self.makeEvent(turnID: "T", agentID: "a1")
        let e2 = Self.makeEvent(turnID: "T", agentID: "a2")

        // A enters recordEvent, holds the lane, and parks inside the FIRST event-log append.
        let ta = Task { _ = try? await bridge.recordEvent(e1) }
        await gated.waitUntilParked()
        // B attempts recordEvent while A holds the lane — with the lane it must wait for A.
        let tb = Task { _ = try? await bridge.recordEvent(e2) }
        await Task.yield()
        await gated.release()
        _ = await ta.value
        _ = await tb.value

        // The durable event log's append order must agree with the embedded trace sequence.
        let ids = await gated.appendedEventIDs()
        let traceSeqs = ids.map { Int($0.split(separator: ".").last ?? "") ?? -1 }
        XCTAssertEqual(traceSeqs.count, 2)
        XCTAssertEqual(traceSeqs, traceSeqs.sorted(),
            "event-log append order must be monotonic in trace seq — a reentrant interleave inverts it")
    }
}

/// Event-log double that parks the FIRST append so the two-write reentrancy window is forced open,
/// and records the eventIDs in append order.
private actor GatedAppendEventLog: BASEventLogStorage {
    private let inner = BASInMemoryEventLogStorage()
    private var order: [String] = []
    private var firstParked = false
    private var gate: CheckedContinuation<Void, Never>?
    private var parkedWaiter: CheckedContinuation<Void, Never>?
    private var didPark = false

    func append(_ entry: BASEventLogEntry) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
        if !firstParked {
            firstParked = true
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                gate = c; didPark = true
                parkedWaiter?.resume(); parkedWaiter = nil
            }
        }
        order.append(entry.eventID)
        return try await inner.append(entry)
    }
    func events(forSession sessionID: String) async -> [BASEventLogEntry] {
        await inner.events(forSession: sessionID)
    }
    func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] {
        await inner.events(sinceTimestampMs: since, limit: limit)
    }
    var totalCount: Int { get async { await inner.totalCount } }
    func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int {
        try await inner.pruneEventsBefore(timestampMs: cutoff)
    }
    func appendedEventIDs() -> [String] { order }
    func waitUntilParked() async {
        if didPark { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in parkedWaiter = c }
    }
    func release() { gate?.resume(); gate = nil }
}
