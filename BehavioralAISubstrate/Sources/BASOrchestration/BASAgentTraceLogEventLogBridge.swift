// MARK: - BASAgentTraceLogEventLogBridge
// chapter 九百八十四 / M3625 — Cross-Module Integration Arc ch2
//
// Closes ch 982.5 META-REVIEW cross-module Gap 6:**BASAgentTraceLog
// is in-memory only — does NOT use BASRoutedEventLogStorage** per
// ch 953 plan section 8 (Trace / Replay Engine reuses
// BASRoutedEventLogStorage)。
//
// ## The gap
//
// Per Root Law 7 (可回放),every agent observation / proposal /
// delta / reject reason MUST be replayable from the event-sourced
// log。 The plan section 8 specifically calls out reusing
// `BASRoutedEventLogStorage` (`Sources/BASMemory/
// BASRoutedEventLogStorage.swift`) for this。 But ch 959 shipped
// `BASAgentTraceLog` as a NEW in-memory actor with no link to
// the existing event-log storage layer。 The ring-buffer at
// `BASAgentTraceLog` line 122-194 caps at 10K events and drops
// oldest — long sessions lose early trace events permanently,
// and there's NO persistent / durable trace store。 Both the
// `BASEventLogStorage` protocol (BASRuntimeCore) + its routed
// implementation (BASMemory) sit there ready to receive these
// events,but no wire connects them。
//
// ## What this bridge does
//
// Provides a write-through fan-out adapter:
//
//   1. `recordEvent(...)` — append one event to BOTH the in-mem
//      trace log AND the durable event-log storage。 Synchronous
//      semantics:caller awaits both writes。 If the event-log
//      write throws,the trace-log write still succeeded (the
//      bridge does NOT roll back the trace log)。
//   2. `flush(...)` — batch-copy a turn's trace events into
//      the event-log storage at turn-end。 Useful when the host
//      doesn't want per-event latency。
//
// Per discipline:
//   - Additive (red-line 7) — existing `BASAgentTraceLog` callers
//     unchanged。 No new protocol forced onto the dispatcher。
//   - ADR-014 OPT-IN — bridge construction is opt-in,callers
//     who don't use the bridge see byte-equal pre-Phase-0 behavior
//   - Pure-fn `synthesizeEventLogEntry(...)` — same input
//     `BASAgentTraceEvent` always produces byte-equal
//     `BASEventLogEntry` (modulo caller-supplied
//     `timestampMs` / `sessionID`)
//
// ## Synthesis — BASAgentTraceEvent → BASEventLogEntry
//
// Field mapping (lossless within agent-trace semantics):
//
//   | trace event              | event log entry                  |
//   |--------------------------|----------------------------------|
//   | sequenceNumber + turnID  | eventID (synthesized stable hash)|
//   | createdAtNanos / 1e6     | timestampMs                      |
//   | turnID                   | turnRef                          |
//   | (constant)               | kind = .substrateAudit           |
//   | agentID                  | source = "agentFabric.<agentID>" |
//   | (constant)               | riskBand = .unknown              |
//   | (constant)               | confidence = 0.0 (observability) |
//   | kind + agentID + deltaID | actions = [<encoded>]            |
//   | payloadJson              | payloadJson (verbatim,           |
//   |                          | preserves U+001F refs ch 982.5)  |
//   | deltaID,if non-nil        | memoryRefs = [deltaID]           |
//
// `eventID` is synthesized as
// `"agentTrace.<turnID>.<sequenceNumber>"` — stable + unique per
// (turn,seq) pair。 Idempotent re-flush returns `wasNew=false`
// from the underlying storage's eventID uniqueness check。

import Foundation
import BASMemory
import BASRuntimeCore

public actor BASAgentTraceLogEventLogBridge {

    /// audit M-l / orchestration MED-4: `recordEvent` appends to the traceLog FIRST, then the
    /// durable eventLog. If the eventLog throws, the traceLog write already committed and the bare
    /// rethrow HID that partial state — a caller could not tell whether the traceLog was written,
    /// and a naive retry double-writes it. This carries the orphaned traceSeq so the partial commit
    /// is EXPLICIT and reconcilable (the eventLog is missing the event at this traceSeq).
    public struct PartialWriteError: Error, Sendable, CustomStringConvertible {
        public let orphanedTraceSeq: Int64
        public let underlying: any Error
        public var description: String {
            "BASAgentTraceLogEventLogBridge: traceLog committed at seq \(orphanedTraceSeq) but the "
                + "eventLog write failed (\(underlying)) — the durable log is missing this event; "
                + "reconcile rather than blindly retry (retry re-appends the traceLog)."
        }
    }

    private let traceLog: BASAgentTraceLog
    private let eventLog: any BASEventLogStorage
    private let sessionID: String

    public init(
        traceLog: BASAgentTraceLog,
        eventLog: any BASEventLogStorage,
        sessionID: String
    ) {
        self.traceLog = traceLog
        self.eventLog = eventLog
        self.sessionID = sessionID
    }

    /// Append one event to BOTH the trace log + the event-log
    /// storage。 Returns the assigned sequence numbers from each。
    /// If the event-log write throws,the trace-log write still
    /// succeeded — the bridge does NOT roll back。
    @discardableResult
    public func recordEvent(
        _ event: BASAgentTraceEvent
    ) async throws -> (
        traceSeq: Int64, eventLogResult: (
            wasNew: Bool, assignedSequenceNumber: Int64))
    {
        let traceSeq = await traceLog.append(event)
        // Build a stamped event (with assigned seq) for synthesis
        // so the eventID is stable + the timestamp is preserved。
        let stamped = BASAgentTraceEvent(
            sequenceNumber: traceSeq,
            turnID: event.turnID,
            createdAtNanos: event.createdAtNanos,
            kind: event.kind,
            agentID: event.agentID,
            deltaID: event.deltaID,
            payloadJson: event.payloadJson)
        let logEntry = Self.synthesizeEventLogEntry(
            traceEvent: stamped, sessionID: sessionID)
        // audit M-l / orchestration MED-4: the traceLog is already committed at `traceSeq`. If the
        // durable write fails, surface the orphaned seq instead of a bare rethrow that hides it.
        let result: (wasNew: Bool, assignedSequenceNumber: Int64)
        do {
            result = try await eventLog.append(logEntry)
        } catch {
            throw PartialWriteError(orphanedTraceSeq: traceSeq, underlying: error)
        }
        return (traceSeq: traceSeq, eventLogResult: result)
    }

    /// Batch-flush all events for a turn from the trace log into
    /// the event-log storage。 Idempotent — re-flushing produces
    /// `wasNew=false` outcomes (eventIDs are deterministic per
    /// (turn,seq))。 Useful when the host buffers per-event writes
    /// for latency reasons。
    ///
    /// Returns the count of (was-new) writes to the event log。
    /// Does NOT modify the trace log。
    ///
    /// **Concurrency contract** (chapter 九百九十六.7 META-REVIEW
    /// Round-16 HIGH-2 disclosure):this method takes a
    /// SNAPSHOT of `traceLog.events(forTurn:)` once + iterates
    /// with per-event `await eventLog.append(...)` calls。
    /// Between the snapshot and any iteration step,OTHER tasks
    /// may call `traceLog.append` or `recordEvent` for the same
    /// turn — those late events will NOT be in this flush。 They
    /// land in the trace log normally + can be picked up by a
    /// subsequent `flush(forTurn:)` call。 But if the host calls
    /// flush at turn-end then immediately tears down the bridge,
    /// late events are silently dropped from the event log。
    ///
    /// **Caller contract**:invoke `flush(forTurn:)` ONLY after
    /// all seats for the given turn have completed emitting。
    /// The dispatcher's own emission path completes synchronously
    /// within `dispatchTurn(...)` so this is satisfied by calling
    /// flush AFTER `dispatchTurn`。 Custom watchers / late
    /// emissions outside the dispatcher path are the host's
    /// responsibility to sequence。
    @discardableResult
    public func flush(
        forTurn turnID: String
    ) async throws -> Int {
        let events = await traceLog.events(forTurn: turnID)
        var newWrites = 0
        for event in events {
            let logEntry = Self.synthesizeEventLogEntry(
                traceEvent: event, sessionID: sessionID)
            let result = try await eventLog.append(logEntry)
            if result.wasNew { newWrites += 1 }
        }
        return newWrites
    }

    /// Pure-fn synthesis of one BASEventLogEntry from one
    /// BASAgentTraceEvent。 Public for testing — production code
    /// goes through `recordEvent` / `flush`。 Deterministic given
    /// input + sessionID。
    public static func synthesizeEventLogEntry(
        traceEvent: BASAgentTraceEvent,
        sessionID: String
    ) -> BASEventLogEntry {
        let eventID =
            "agentTrace.\(traceEvent.turnID)" +
            ".\(traceEvent.sequenceNumber)"
        let source: String?
        if let agentID = traceEvent.agentID {
            source = "agentFabric.\(agentID)"
        } else {
            source = "agentFabric.merge"
        }
        // Actions:encode kind + agentID + deltaID compactly
        var actions: [String] = [
            "agentTrace.kind=\(traceEvent.kind.rawValue)",
        ]
        if let agentID = traceEvent.agentID {
            actions.append("agentTrace.agent=\(agentID)")
        }
        if let deltaID = traceEvent.deltaID {
            actions.append("agentTrace.delta=\(deltaID)")
        }
        let memoryRefs: [String]
        if let deltaID = traceEvent.deltaID {
            memoryRefs = [deltaID]
        } else {
            memoryRefs = []
        }
        // Nanos → millis,saturating at Int64.max boundary
        let timestampMs: Int64
        if traceEvent.createdAtNanos == Int64.max {
            timestampMs = Int64.max / 1_000_000
        } else {
            timestampMs = traceEvent.createdAtNanos / 1_000_000
        }
        return BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            source: source,
            turnRef: traceEvent.turnID,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: memoryRefs,
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: actions,
            confidence: 0.0,
            payloadJson: traceEvent.payloadJson)
    }
}
