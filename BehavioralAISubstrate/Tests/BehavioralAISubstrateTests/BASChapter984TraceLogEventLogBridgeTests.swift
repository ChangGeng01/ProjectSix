// MARK: - BASChapter984TraceLogEventLogBridgeTests
// chapter 九百八十四 / M3625 — Cross-Module Integration Arc ch2
//
// Closes ch 982.5 META-REVIEW cross-module Gap 6:BASAgentTraceLog
// was in-memory only — does NOT use BASRoutedEventLogStorage per
// ch 953 plan section 8 (Trace / Replay Engine reuses
// BASRoutedEventLogStorage)。
//
// Tests pin the integration:
//   1. `synthesizeEventLogEntry(...)` is deterministic
//   2. `recordEvent(...)` writes to BOTH trace log AND event-log
//   3. `flush(...)` is idempotent across re-runs
//   4. U+001F sentinel in payloadJson survives bridge
//   5. Empty agentID → "agentFabric.merge" source convention
//   6. Multiple events accumulate per turn correctly
//   7. eventID uniqueness across (turnID,sequenceNumber) pairs

import XCTest
@testable import BASOrchestration
@testable import BASMemory
@testable import BASRuntimeCore

final class BASChapter984TraceLogEventLogBridgeTests: XCTestCase {

    // MARK: - Pure-fn synthesis tests

    func testSynthesize_DeltaEmittedEvent() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 1,
            turnID: "t.42",
            createdAtNanos: 1_234_567_000_000,
            kind: .deltaEmitted,
            agentID: "planner.1",
            deltaID: "delta.t42.planner.1",
            payloadJson: "{\"x\":1}")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "sess.1")
        XCTAssertEqual(entry.eventID, "agentTrace.t.42.1")
        XCTAssertEqual(entry.timestampMs, 1_234_567)
        XCTAssertEqual(entry.kind, .substrateAudit)
        XCTAssertEqual(entry.sessionID, "sess.1")
        XCTAssertEqual(entry.source, "agentFabric.planner.1")
        XCTAssertEqual(entry.turnRef, "t.42")
        XCTAssertEqual(entry.memoryRefs, ["delta.t42.planner.1"])
        XCTAssertEqual(entry.payloadJson, "{\"x\":1}")
        XCTAssertTrue(entry.actions.contains(
            "agentTrace.kind=delta_emitted"))
        XCTAssertTrue(entry.actions.contains(
            "agentTrace.agent=planner.1"))
        XCTAssertTrue(entry.actions.contains(
            "agentTrace.delta=delta.t42.planner.1"))
    }

    func testSynthesize_MergeCompletedHasNoAgent() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 5,
            turnID: "t.42",
            createdAtNanos: 1_000_000_000,
            kind: .mergeCompleted,
            agentID: nil,
            deltaID: nil,
            payloadJson: "{}")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "sess.1")
        XCTAssertEqual(entry.source, "agentFabric.merge",
            "ch 984: nil agentID → 'agentFabric.merge' source")
        XCTAssertTrue(entry.memoryRefs.isEmpty)
        XCTAssertFalse(entry.actions.contains {
            $0.hasPrefix("agentTrace.agent=")
        }, "ch 984: nil agentID → NO 'agentTrace.agent=' action")
    }

    func testCRITICAL_Synthesize_U001F_PayloadSurvives() {
        // The exact ch 981.9 / 982.5 sentinel pattern
        let event = BASAgentTraceEvent(
            sequenceNumber: 1,
            turnID: "t.42",
            createdAtNanos: 1_000_000,
            kind: .deltaEmitted,
            agentID: "external.alpha",
            deltaID: "d.1",
            payloadJson:
                "{\"ref\":\"host-root=h1\\u001Fper-agent=a1\"}")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "sess.1")
        XCTAssertEqual(entry.payloadJson,
            "{\"ref\":\"host-root=h1\\u001Fper-agent=a1\"}",
            "ch 984 CRITICAL: U+001F sentinel in payload MUST " +
            "survive bridge synthesis verbatim (closes ch 982.5 " +
            "concern that bridge could corrupt the carefully-" +
            "escaped sentinel)")
    }

    func testSynthesize_IsDeterministic() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 7,
            turnID: "t.x",
            createdAtNanos: 999_000,
            kind: .deltaApplied,
            agentID: "risk.1",
            deltaID: "d.7",
            payloadJson: "{}")
        let e1 = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "s")
        let e2 = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "s")
        XCTAssertEqual(e1.eventID, e2.eventID)
        XCTAssertEqual(e1.timestampMs, e2.timestampMs)
        XCTAssertEqual(e1.actions, e2.actions,
            "ch 984: synthesize MUST be deterministic — " +
            "Root Law 7 可回放")
    }

    func testSynthesize_Int64MaxNanosSaturates() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 1,
            turnID: "t",
            createdAtNanos: Int64.max,
            kind: .deltaEmitted,
            agentID: nil,
            deltaID: nil,
            payloadJson: "")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "s")
        XCTAssertEqual(entry.timestampMs, Int64.max / 1_000_000,
            "ch 984: Int64.max nanos MUST saturate at " +
            "Int64.max/1e6 ms (avoid integer overflow)")
    }

    // MARK: - recordEvent integration

    func testRecordEvent_WritesToBothLogs() async throws {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.1")
        let event = BASAgentTraceEvent(
            turnID: "t.1",
            createdAtNanos: 1_000_000,
            kind: .deltaEmitted,
            agentID: "scout.1",
            deltaID: "d.1",
            payloadJson: "{\"a\":1}")
        let (traceSeq, logResult) = try await bridge
            .recordEvent(event)
        XCTAssertGreaterThan(traceSeq, 0)
        XCTAssertTrue(logResult.wasNew)
        let traceEvents = await trace.events(forTurn: "t.1")
        XCTAssertEqual(traceEvents.count, 1,
            "ch 984: recordEvent MUST write to trace log")
        let logEntries = await memEventLog
            .events(forSession: "sess.1")
        XCTAssertEqual(logEntries.count, 1,
            "ch 984: recordEvent MUST write to event log")
    }

    // MARK: - flush integration

    func testFlush_IsIdempotent() async throws {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.1")
        // Pre-populate the trace log
        _ = await trace.append(BASAgentTraceEvent(
            turnID: "t.1",
            createdAtNanos: 1_000,
            kind: .deltaEmitted,
            agentID: "a.1",
            deltaID: "d.1",
            payloadJson: "{}"))
        _ = await trace.append(BASAgentTraceEvent(
            turnID: "t.1",
            createdAtNanos: 2_000,
            kind: .mergeCompleted,
            agentID: nil,
            deltaID: nil,
            payloadJson: "{}"))

        let firstFlush = try await bridge.flush(forTurn: "t.1")
        XCTAssertEqual(firstFlush, 2,
            "ch 984: first flush writes both events as new")

        let secondFlush = try await bridge.flush(forTurn: "t.1")
        XCTAssertEqual(secondFlush, 0,
            "ch 984: second flush MUST be idempotent — " +
            "eventID uniqueness rejects duplicates")
    }

    func testFlush_AccumulatesAcrossTurns() async throws {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.1")
        // Turn 1
        _ = await trace.append(BASAgentTraceEvent(
            turnID: "t.1", createdAtNanos: 1,
            kind: .deltaEmitted, agentID: "a",
            deltaID: "d.1", payloadJson: "{}"))
        // Turn 2
        _ = await trace.append(BASAgentTraceEvent(
            turnID: "t.2", createdAtNanos: 2,
            kind: .deltaEmitted, agentID: "a",
            deltaID: "d.2", payloadJson: "{}"))
        // Flush each independently
        let t1 = try await bridge.flush(forTurn: "t.1")
        let t2 = try await bridge.flush(forTurn: "t.2")
        XCTAssertEqual(t1, 1)
        XCTAssertEqual(t2, 1)
        let allEntries = await memEventLog
            .events(forSession: "sess.1")
        XCTAssertEqual(allEntries.count, 2,
            "ch 984: per-turn flush accumulates in event log")
    }

    // MARK: - End-to-end:dispatcher trace + bridge flush

    func testE2E_BridgePreservesAllTraceEvents()
        async throws
    {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.1")
        // Simulate 5 events from a turn
        for i in 1...5 {
            _ = await trace.append(BASAgentTraceEvent(
                turnID: "t.42",
                createdAtNanos: Int64(i * 1_000_000),
                kind: i == 3 ? .mergeCompleted
                    : .deltaEmitted,
                agentID: i == 3 ? nil : "agent.\(i)",
                deltaID: i == 3 ? nil : "d.\(i)",
                payloadJson: "{\"i\":\(i)}"))
        }
        let count = try await bridge.flush(forTurn: "t.42")
        XCTAssertEqual(count, 5,
            "ch 984 E2E: all 5 trace events MUST land in event log")
        let entries = await memEventLog
            .events(forSession: "sess.1")
        XCTAssertEqual(entries.count, 5)
        // EventIDs unique per (turn,seq) pair
        let ids = Set(entries.map { $0.eventID })
        XCTAssertEqual(ids.count, 5,
            "ch 984 E2E: eventIDs MUST be unique across turn's seqs")
    }
}

// MARK: - In-memory test event log

/// Minimal Sendable BASEventLogStorage for tests。 Production code
/// uses BASRoutedEventLogStorage which is FFI-backed and not
/// trivially instantiable in unit-test scope。
private actor MemEventLog: BASEventLogStorage {
    private var entries: [String: BASEventLogEntry] = [:]
    private var nextSeq: Int64 = 0

    func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        if entries[entry.eventID] != nil {
            return (
                wasNew: false,
                assignedSequenceNumber:
                    entries[entry.eventID]!.sequenceNumber)
        }
        nextSeq += 1
        var stamped = entry
        stamped = BASEventLogEntry(
            eventID: entry.eventID,
            timestampMs: entry.timestampMs,
            kind: entry.kind,
            sessionID: entry.sessionID,
            sequenceNumber: nextSeq,
            source: entry.source,
            turnRef: entry.turnRef,
            rawInputDigest: entry.rawInputDigest,
            intent: entry.intent,
            emotion: entry.emotion,
            riskBand: entry.riskBand,
            project: entry.project,
            memoryRefs: entry.memoryRefs,
            stateBeforeID: entry.stateBeforeID,
            stateAfterID: entry.stateAfterID,
            actions: entry.actions,
            confidence: entry.confidence,
            payloadJson: entry.payloadJson)
        entries[entry.eventID] = stamped
        return (wasNew: true, assignedSequenceNumber: nextSeq)
    }

    func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        entries.values
            .filter { $0.sessionID == sessionID }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        entries.values
            .filter { $0.timestampMs >= since }
            .sorted {
                ($0.timestampMs, $0.sequenceNumber) <
                ($1.timestampMs, $1.sequenceNumber)
            }
            .prefix(limit)
            .map { $0 }
    }

    var totalCount: Int { get async { entries.count } }

    @discardableResult
    func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int {
        let before = entries.count
        entries = entries.filter { $0.value.timestampMs >= cutoff }
        return before - entries.count
    }
}
