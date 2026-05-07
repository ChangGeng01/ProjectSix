// MARK: - BASEventReplayRunner — chapter 三百五四 / M841
//
// Phase P1 G1 第三刀: typed event replay primitive。Closes the
// "replay tool" piece of the G1 deliverable from chapter 三百五三 /
// M840 roadmap。
//
// ## Why this exists
//
// Once the event log is populated (BASEventLog.swift +
// BASSQLiteEventLogStorage.swift),the foundational use case is
// **replay**: walk events in order through a typed reducer to
// rebuild some derived state。
//
// G2 (M842) will consume this to populate `BASUserState` (S_t) by
// folding events through `BASUserStateReducer`。Future P2 G8 (Mamba
// SSM training) consumes this to build training input sequences。
//
// This file defines the replay primitive in **reducer-generic** form
// — caller supplies the reducer closure + initial state,replay
// engine handles iteration + ordering invariants。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — replay is read-only,doesn't mutate
//     event log,doesn't update runtime weights
//   - 红线 7 hint-only — derived state from replay is observation/
//     hint material;substrate decisions independent
//   - chapter 二百一一 single-source-of-truth: ONE replay primitive,
//     all consumers (G2 reducer / G8 SSM training / G9 causal graph)
//     route through this
//   - chapter 一百八十五 anti-magic-number: batch sizes, default
//     limits all named typed constants
//
// ## Non-goals
//
//   - Backward replay (reverse-time fold) — not needed for current
//     consumers;could be added as future API
//   - Cross-process distributed replay — single-process only
//   - Retry / resume semantics — fold is one-shot;caller checkpoints
//     intermediate state if needed for very long replays

import Foundation

// MARK: - Replay range typed selector

/// Typed selector for which events the replay runner reads。
public enum BASEventReplayRange: Sendable, Equatable {
    /// Replay every event for a single session,sequence-ordered。
    case singleSession(sessionID: String)
    /// Replay every event with `timestampMs >= since`,bounded by
    /// `limit` rows ordered `(timestampMs ASC, sequenceNumber ASC)`。
    case sinceTimestamp(sinceMs: Int64, limit: Int)
}

// MARK: - Replay result

/// Typed bundle returned from a replay fold operation。
public struct BASEventReplayResult<State: Sendable>: Sendable {
    /// The final folded state after walking all events。
    public let finalState: State
    /// Number of events actually consumed (after range filter)。
    public let eventsConsumed: Int
    /// Number of events that were skipped because the reducer
    /// returned `nil` for them (caller-defined "ignore this event"
    /// semantics)。
    public let eventsSkipped: Int
    /// Sequence number of the LAST event consumed for the dominant
    /// session,or nil if no events consumed。Useful for resume
    /// pointers in checkpointed pipelines。
    public let lastConsumedSequence: Int64?

    public init(
        finalState: State,
        eventsConsumed: Int,
        eventsSkipped: Int,
        lastConsumedSequence: Int64?
    ) {
        self.finalState = finalState
        self.eventsConsumed = eventsConsumed
        self.eventsSkipped = eventsSkipped
        self.lastConsumedSequence = lastConsumedSequence
    }
}

// MARK: - Replay runner

/// Stateless replay engine。Caller passes a typed reducer + initial
/// state + replay range;runner reads events from the typed
/// `BASEventLogStorage` and folds them sequentially。
public enum BASEventReplayRunner {

    /// Default cap on `sinceTimestamp` replays when caller doesn't
    /// specify。Prevents accidental full-table scans on large logs。
    /// Chapter 一百八十五 anti-magic-number — named constant。
    public static let defaultSinceTimestampLimit: Int = 100_000

    /// Replay events through `reducer` to produce a final state。
    ///
    /// - Parameters:
    ///   - storage: typed event log storage to read from
    ///   - range: typed selector for which events to read
    ///   - initial: starting state (S_0)
    ///   - reducer: pure-function fold step. Returns the next
    ///     state given `(prior, event)`。If reducer returns `nil`,
    ///     event is treated as "skip" (eventsSkipped++,state
    ///     unchanged)。
    /// - Returns: typed result bundle with final state +
    ///   consumed/skipped counts + last sequence number
    public static func replay<State: Sendable>(
        storage: any BASEventLogStorage,
        range: BASEventReplayRange,
        initial: State,
        reducer: @Sendable (State, BASEventLogEntry) -> State?
    ) async -> BASEventReplayResult<State> {
        let events: [BASEventLogEntry]
        switch range {
        case .singleSession(let sessionID):
            events = await storage.events(
                forSession: sessionID)
        case .sinceTimestamp(let since, let limit):
            events = await storage.events(
                sinceTimestampMs: since,
                limit: max(0, limit))
        }
        var state = initial
        var consumed = 0
        var skipped = 0
        var lastSeq: Int64? = nil
        for event in events {
            if let next = reducer(state, event) {
                state = next
                consumed += 1
                lastSeq = event.sequenceNumber
            } else {
                skipped += 1
            }
        }
        return BASEventReplayResult(
            finalState: state,
            eventsConsumed: consumed,
            eventsSkipped: skipped,
            lastConsumedSequence: lastSeq)
    }

    /// Convenience: replay every event in a single session through
    /// the reducer。Equivalent to
    /// `replay(...,range: .singleSession(sessionID:),...)`。
    public static func replaySession<State: Sendable>(
        storage: any BASEventLogStorage,
        sessionID: String,
        initial: State,
        reducer: @Sendable (State, BASEventLogEntry) -> State?
    ) async -> BASEventReplayResult<State> {
        await replay(
            storage: storage,
            range: .singleSession(sessionID: sessionID),
            initial: initial,
            reducer: reducer)
    }
}
