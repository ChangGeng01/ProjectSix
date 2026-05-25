// MARK: - BASAgentTraceLog
// chapter 九百五十九 / M3500 — Phase 1 close:event-sourced agent trace log
//
// Per Root Law 7 (可回放) every agent activity in a turn must be
// recordable + replayable。 This log captures the SEQUENCE of
// agent events per turn so a future replay can reconstruct what
// happened deterministically。
//
// Events captured per turn:
//   - `.deltaEmitted` — one per delta emitted by any seat
//   - `.mergeCompleted` — one per merge engine run (mergeID +
//     accepted/rejected counts)
//   - `.deltaApplied` — one per accepted delta's apply outcome
//     (success OR error code)
//
// ## Why a separate log type
//
// Could reuse `BASEventLogStorage` directly,but:
//   - That protocol is shaped for the broader L8 event log (intent,
//     emotion,riskBand,memoryRefs,stateBefore/AfterID,etc.) —
//     mostly nil for agent-trace events
//   - Agent trace events are per-turn (typically 4-32) and
//     short-lived (don't persist beyond replay window for most use
//     cases) — different retention semantics from the L8 log
//   - We can WRAP a `BASEventLogStorage` adapter behind this
//     interface in a follow-up chapter without breaking callers
//
// For ch 959 the log is an in-memory append-only actor。 Storage
// adapter is a Phase 2+ concern (ch 960 candidate)。
//
// ## Sendable + actor isolation
//
// The log is an actor so concurrent agents in a turn can safely
// append events without locking。 All read methods are also async
// (audit / replay callers go through actor isolation)。

import Foundation

/// One agent-trace event recorded during a turn。 Codable +
/// Sendable + Equatable for testability + future on-disk storage。
public struct BASAgentTraceEvent:
    Sendable, Equatable, Hashable, Codable
{
    /// Per-turn monotonic sequence number (assigned by the log,
    /// caller passes 0)。
    public let sequenceNumber: Int64

    /// Turn this event belongs to (mirrors BASAgentDelta.turnID-
    /// derived ref namespace)。
    public let turnID: String

    /// Wall-clock nanos at append time (NOT monotonic across
    /// processes — use sequenceNumber for ordering)。
    public let createdAtNanos: Int64

    /// Event kind discriminator。
    public let kind: BASAgentTraceEventKind

    /// Agent that emitted / was-subject-of this event。 Nil for
    /// merge-completed events (no single agent owns the merge)。
    public let agentID: String?

    /// Delta ID this event references (for deltaEmitted /
    /// deltaApplied)。 Nil for mergeCompleted。
    public let deltaID: String?

    /// JSON-encoded event-specific payload。 Format varies by
    /// kind:
    ///   - deltaEmitted: `{"target_ref":..,"confidence":..}`
    ///   - mergeCompleted: `{"merge_id":..,"accepted":N,
    ///                       "rejected":N}`
    ///   - deltaApplied: `{"applied":bool,"written_ref":..,
    ///                     "error":..}`
    public let payloadJson: String

    public init(
        sequenceNumber: Int64 = 0,
        turnID: String,
        createdAtNanos: Int64,
        kind: BASAgentTraceEventKind,
        agentID: String? = nil,
        deltaID: String? = nil,
        payloadJson: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.turnID = turnID
        self.createdAtNanos = createdAtNanos
        self.kind = kind
        self.agentID = agentID
        self.deltaID = deltaID
        self.payloadJson = payloadJson
    }
}

/// Event-kind discriminator for `BASAgentTraceEvent`。 Closed set
/// — bumping requires a forward-compat schema check on replay。
public enum BASAgentTraceEventKind: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// A seat emitted a `BASAgentDelta` (one per delta)
    case deltaEmitted = "delta_emitted"
    /// Merge engine ran and produced a `BASAgentMergeResult`
    case mergeCompleted = "merge_completed"
    /// Applier wrote (or failed to write) a delta to the graph
    case deltaApplied = "delta_applied"
}

/// Actor-isolated append-only trace log for one or more turns。
/// All methods are `async`;callers MUST await。 Append-only — no
/// delete API by design (per Root Law 7 the trace IS the audit
/// surface)。 Future retention controls can land in ch 960+ by
/// wrapping a `BASEventLogStorage` adapter (which has
/// `purgeEventsOlderThan` per ch 397)。
public actor BASAgentTraceLog {

    /// Storage:in-memory `Vec`-like array,bounded by caller's
    /// `BASAgentTraceLogConfig.maxEvents` (ch 956.11 H2-style
    /// DoS bound)。 When cap is hit,oldest events are dropped
    /// (ring-buffer semantics — newest events are most useful
    /// for live debug;older events go to an optional persistent
    /// sink in a future chapter)。
    private var events: [BASAgentTraceEvent] = []

    /// Per-turn next sequence number。 ALWAYS starts at 1 per turn
    /// (sequence is per-turn scoped,not global)。
    private var nextSeqByTurn: [String: Int64] = [:]

    /// chapter 九百五十九 / M3500 — bounded log to prevent
    /// unbounded growth on long sessions per ch 956.11 H2
    /// DoS-bound discipline。
    public let maxEvents: Int

    public init(maxEvents: Int = 10_000) {
        precondition(maxEvents > 0, "maxEvents must be positive")
        self.maxEvents = maxEvents
    }

    /// Append one event。 Assigns a per-turn monotonic
    /// `sequenceNumber` if caller passed 0,otherwise honors the
    /// caller's value (used by replay paths that need to preserve
    /// original sequence)。
    @discardableResult
    public func append(_ event: BASAgentTraceEvent) -> Int64 {
        let assignedSeq: Int64
        if event.sequenceNumber == 0 {
            let next = (nextSeqByTurn[event.turnID] ?? 0) + 1
            nextSeqByTurn[event.turnID] = next
            assignedSeq = next
        } else {
            assignedSeq = event.sequenceNumber
            let curr = nextSeqByTurn[event.turnID] ?? 0
            if assignedSeq > curr {
                nextSeqByTurn[event.turnID] = assignedSeq
            }
        }
        let stamped = BASAgentTraceEvent(
            sequenceNumber: assignedSeq,
            turnID: event.turnID,
            createdAtNanos: event.createdAtNanos,
            kind: event.kind,
            agentID: event.agentID,
            deltaID: event.deltaID,
            payloadJson: event.payloadJson)
        events.append(stamped)
        // Ring-buffer trim:drop oldest when cap exceeded。
        if events.count > maxEvents {
            let drop = events.count - maxEvents
            events.removeFirst(drop)
        }
        return assignedSeq
    }

    /// Return all events for a given turn,ordered by sequenceNumber。
    public func events(forTurn turnID: String)
    -> [BASAgentTraceEvent] {
        events.filter { $0.turnID == turnID }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    /// All events currently in the log (across turns),ordered
    /// by append time。 Used by tests + audit dumps。
    public func allEvents() -> [BASAgentTraceEvent] { events }

    /// Total event count。
    public var count: Int { events.count }

    /// Distinct turn IDs the log has events for。
    public func turnIDs() -> Set<String> {
        Set(events.map { $0.turnID })
    }
}

// MARK: - Helper builders (deterministic payloads)

public enum BASAgentTraceEventBuilder {

    /// Build a `.deltaEmitted` event for a delta a seat just emitted。
    public static func deltaEmitted(
        turnID: String,
        delta: BASAgentDelta,
        nowNanos: Int64
    ) -> BASAgentTraceEvent {
        let payload =
            "{\"target_ref\":\"\(delta.targetObjectRef.eForJ())\"," +
            "\"confidence\":" +
            "\(String(format: "%.6f", delta.confidence))}"
        return BASAgentTraceEvent(
            turnID: turnID,
            createdAtNanos: nowNanos,
            kind: .deltaEmitted,
            agentID: delta.agentID,
            deltaID: delta.deltaID,
            payloadJson: payload)
    }

    /// Build a `.mergeCompleted` event from a merge result。
    public static func mergeCompleted(
        turnID: String,
        result: BASAgentMergeResult,
        nowNanos: Int64
    ) -> BASAgentTraceEvent {
        let payload =
            "{\"merge_id\":\"\(result.mergeID.eForJ())\"," +
            "\"accepted\":\(result.acceptedDeltaIDs.count)," +
            "\"rejected\":\(result.rejectedDeltaIDs.count)}"
        return BASAgentTraceEvent(
            turnID: turnID,
            createdAtNanos: nowNanos,
            kind: .mergeCompleted,
            agentID: nil,
            deltaID: nil,
            payloadJson: payload)
    }

    /// Build a `.deltaApplied` event from an applier outcome。
    public static func deltaApplied(
        turnID: String,
        outcome: BASAgentDeltaApplicationOutcome,
        nowNanos: Int64
    ) -> BASAgentTraceEvent {
        let payload =
            "{\"applied\":\(outcome.applied)," +
            "\"written_ref\":\"\(outcome.writtenRef.eForJ())\"," +
            "\"error\":\"\(outcome.errorReason.eForJ())\"}"
        return BASAgentTraceEvent(
            turnID: turnID,
            createdAtNanos: nowNanos,
            kind: .deltaApplied,
            agentID: nil,  // unknown without the original delta
            deltaID: outcome.deltaID,
            payloadJson: payload)
    }
}

// MARK: - JSON escape helper (file-scope — same pattern as seats)

private extension String {
    /// Minimal JSON-string escape — same as the seat-file
    /// helpers。 Per ch 956.11 we use `eForJ` so the function
    /// name doesn't collide with the other seat extensions when
    /// future refactors consolidate them。
    func eForJ() -> String {
        var out = ""
        out.reserveCapacity(self.count)
        for ch in self {
            switch ch {
            case "\\": out.append("\\\\")
            case "\"": out.append("\\\"")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            default: out.append(ch)
            }
        }
        return out
    }
}
