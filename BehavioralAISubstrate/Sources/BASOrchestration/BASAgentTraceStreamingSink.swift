// MARK: - BASAgentTraceStreamingSink
// chapter 一千零四 / M3725 — closes `recordEvent` scaffold per
// `Docs/SCAFFOLD_VS_WIRED.md` forward-closure item #5
//
// ## The scaffold condition
//
// `BASAgentTraceLogEventLogBridge.recordEvent(...)` shipped at
// ch 984 as a per-event write-through API,but no in-substrate
// caller used it — production paths invoked `flush(forTurn:)`
// at turn-end instead。 The `recordEvent` API was reserved for
// "future per-event hosts" per ch 996 doctrine。
//
// What was MISSING:no documented protocol for hosts wanting
// to subscribe to per-event notifications。 A host implementing
// a streaming consumer (Kafka publisher,websocket fanout,
// observability stream) had to invent its own integration on top
// of the bridge — there was no contract for "tell me as each
// event happens"。
//
// ## What ch 1004 ships
//
// 1. `BASAgentTraceStreamingSink` protocol — single method
//    `receive(_:eventLogResult:)` that hosts implement to get
//    per-event notifications。
// 2. `BASAgentTraceBufferingSink` actor — reference impl that
//    buffers events for inspection (test fixture + starting
//    point for hosts)。
// 3. `BASAgentTraceLogEventLogBridge.recordEvent(_:streamingTo:)`
//    overload — calls the existing recordEvent path + notifies
//    the sink with the stamped event + write result。
//
// ## Discipline
//
// - Additive only (red-line 7) — existing recordEvent + flush
//   callers byte-equal unchanged。
// - ADR-014 OPT-IN — hosts must explicitly pass a sink。
// - Sink throwing does NOT roll back the recordEvent write
//   (matches the bridge's existing fan-out semantics where
//   eventLog throw leaves trace-log write intact)。 The sink
//   is best-effort notification,not a transactional barrier。
//
// ## Why this is the right closure scope
//
// Per ch 996 doctrine: "host's per-event log consumer wires it
// into a streaming sink"。 The closure ships:
//   - the protocol (so hosts have a contract)
//   - the reference impl (so hosts have a starting point)
//   - the bridge integration (so hosts have a wire-up point)
//
// The substrate does NOT mandate that production code switch
// from flush → per-event-stream — that's a per-host architectural
// decision (perf trade-off + ordering trade-off)。 Both paths
// remain first-class。

import Foundation
import BASMemory

/// Host-implemented sink for per-event streaming notifications。
/// Each call to `BASAgentTraceLogEventLogBridge
/// .recordEvent(_:streamingTo:)` fires `receive(...)` after the
/// trace-log + event-log writes complete。
///
/// Implementations MUST be Sendable (cross-actor delivery)。
/// Implementations SHOULD be idempotent for the same `event` —
/// retries / duplicates are possible if the caller's outer scope
/// re-invokes recordEvent。
public protocol BASAgentTraceStreamingSink: Sendable {

    /// Notify the sink that one trace event was recorded。
    /// Called AFTER both the trace log + event log writes
    /// complete。 The `event` is stamped with the trace log's
    /// assigned sequence number。
    ///
    /// - Parameters:
    ///   - event: the recorded event (sequenceNumber populated)
    ///   - eventLogResult: outcome of the event-log write
    ///     — `wasNew=false` means the event-log already had
    ///     this eventID (idempotent re-record)
    func receive(
        _ event: BASAgentTraceEvent,
        eventLogResult: (
            wasNew: Bool, assignedSequenceNumber: Int64)
    ) async throws
}

/// Reference sink that buffers received events in memory。
/// Production hosts implement their own sink (Kafka publisher,
/// websocket fanout,observability stream)。 This one exists for
/// tests + as a starting-point template for host implementors。
///
/// Thread-safe via actor isolation。 Buffer grows unbounded —
/// callers wanting bounded retention should implement their own
/// sink with a ring-buffer or LRU eviction policy。
public actor BASAgentTraceBufferingSink:
    BASAgentTraceStreamingSink
{
    public struct ReceivedEntry: Sendable {
        public let event: BASAgentTraceEvent
        public let wasNew: Bool
        public let assignedSequenceNumber: Int64
    }

    private var buffer: [ReceivedEntry] = []

    public init() {}

    public func receive(
        _ event: BASAgentTraceEvent,
        eventLogResult: (
            wasNew: Bool, assignedSequenceNumber: Int64)
    ) async throws {
        buffer.append(ReceivedEntry(
            event: event,
            wasNew: eventLogResult.wasNew,
            assignedSequenceNumber:
                eventLogResult.assignedSequenceNumber))
    }

    /// Snapshot of all received entries since creation。 Useful
    /// for test inspection — production hosts typically don't
    /// snapshot (they consume + flush downstream)。
    public func snapshot() -> [ReceivedEntry] { buffer }

    /// Total events received so far。
    public func count() -> Int { buffer.count }

    /// Clear the buffer。 Idempotent。
    public func clear() { buffer.removeAll() }
}

// MARK: - Bridge integration

extension BASAgentTraceLogEventLogBridge {

    /// Record an event with streaming-sink notification。
    /// Wraps `recordEvent(_:)` — same trace-log + event-log
    /// fan-out semantics — then notifies the supplied sink。
    ///
    /// Sink notification happens AFTER both bridge writes
    /// complete and is best-effort:if the sink throws,the
    /// bridge writes are NOT rolled back (matches the
    /// bridge's existing eventLog-throw-doesn't-roll-back-
    /// traceLog semantics)。
    ///
    /// Returns the same tuple as `recordEvent(_:)` so callers
    /// can chain。
    @discardableResult
    public func recordEvent(
        _ event: BASAgentTraceEvent,
        streamingTo sink: any BASAgentTraceStreamingSink
    ) async throws -> (
        traceSeq: Int64, eventLogResult: (
            wasNew: Bool, assignedSequenceNumber: Int64))
    {
        let result = try await recordEvent(event)
        // Build the stamped event for the sink — same shape the
        // bridge's internal synthesis sees,so the sink receives
        // exactly what landed in the event log。
        let stamped = BASAgentTraceEvent(
            sequenceNumber: result.traceSeq,
            turnID: event.turnID,
            createdAtNanos: event.createdAtNanos,
            kind: event.kind,
            agentID: event.agentID,
            deltaID: event.deltaID,
            payloadJson: event.payloadJson)
        try await sink.receive(
            stamped,
            eventLogResult: result.eventLogResult)
        return result
    }
}
