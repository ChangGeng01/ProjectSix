// MARK: - BASRoutedAtomLifecycleRecording
// chapter 八百 / M2651-M2655 — L8 atom-lifecycle recording activation
//
// Opt-in recorder that pairs the L8 atom-lifecycle bridge
// (chapter 七百八十三 — `BASAtomLifecycleBridge.transition`) with
// the L8 storage adapter (chapter 七百八十九 + 七百九十二)。
//
// ## Two entry points,one shared store contract
//
// 1. `recordTransition(...)` — pure record-keeping。 Takes raw
//    transition bytes (from / to / action / outcome) the caller
//    has already computed,builds a `BASAtomLifecycleEvent`,
//    persists via the host-supplied store。 Works on ALL platforms
//    because it does NOT touch the Rust bridge directly。
//
// 2. `transitionAndRecord(...)` — composite。 Invokes the Rust
//    bridge AND writes the event in one call。 Platform-gated to
//    iOS / macOS (matches the underlying bridge's gate)。 Returns
//    BOTH the event and the bridge Result so callers can keep
//    using the state-machine outcome downstream。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — `BASAtomLifecycleBridge.transition`
// keeps being the pure / sync hot path。 No call site is forced
// to take a store。 The recorder is purely additive,opt-in。
//
// ADR-014 OPT-IN — host supplies the `BASAtomLifecycleStore`
// conformer (InMemory reference impl OR SQLite-backed) per the
// chapter 七百五十四 「addressable seam」 pattern。
//
// Schema 023 column shape preserved (see `BASAtomLifecycleEvent`):
// every recorded event carries the full transition byte tuple +
// outcome + recordedAtMs + optional actorRef。

import Foundation
import BASRuntimeCore

public enum BASRoutedAtomLifecycleRecording {

    // MARK: - Pure recorder (all platforms)

    /// Persist one atom-lifecycle event。 Caller has already
    /// computed the transition bytes — this entry point neither
    /// invokes the Rust bridge nor runs the state machine。
    ///
    /// Use this on platforms WITHOUT the Rust XCFramework (Linux /
    /// watchOS) when the host's Swift fallback computed the
    /// transition,or on iOS / macOS for hosts that prefer to
    /// separate bridge invocation from persistence concerns。
    ///
    /// - Parameters:
    ///   - eventID / atomID / sessionID: identity fields
    ///   - fromPhaseByte / toPhaseByte / actionByte: schema-023
    ///     transition bytes (0..4 phase / 0..3 action)
    ///   - outcome: 0=advanced / 1=rejected_illegal /
    ///     2=rejected_terminal (matches Rust contract)
    ///   - store: any conformer of `BASAtomLifecycleStore`
    ///   - nowMs: epoch ms written to recorded_at_ms
    ///   - actorRef: optional foreign-key to the driving actor
    ///     (sovereign / reducer / GC)
    ///
    /// - Returns: the persisted event
    /// - Throws: if the store rejects the append (e.g。 duplicate
    ///   eventID)
    @discardableResult
    public static func recordTransition(
        eventID: String,
        atomID: String,
        sessionID: String,
        fromPhaseByte: UInt8,
        toPhaseByte: UInt8,
        actionByte: UInt8,
        outcome: Int32,
        store: BASAtomLifecycleStore,
        nowMs: Int64,
        actorRef: String? = nil
    ) async throws -> BASAtomLifecycleEvent {
        let event = BASAtomLifecycleEvent(
            eventID: eventID,
            atomID: atomID,
            sessionID: sessionID,
            fromPhaseByte: fromPhaseByte,
            toPhaseByte: toPhaseByte,
            actionByte: actionByte,
            outcome: outcome,
            recordedAtMs: nowMs,
            actorRef: actorRef)
        return try await store.appendEvent(event)
    }

    // MARK: - Composite (iOS / macOS only)

    #if os(iOS) || os(macOS)

    /// Result returned by `transitionAndRecord`。 Pairs the
    /// persisted event with the Rust bridge's state-machine
    /// Result so callers can inspect both without re-invoking
    /// the bridge。
    public struct ComposedResult: Sendable {
        public let event: BASAtomLifecycleEvent
        public let bridgeResult: BASAtomLifecycleBridge.Result
        public init(
            event: BASAtomLifecycleEvent,
            bridgeResult: BASAtomLifecycleBridge.Result
        ) {
            self.event = event
            self.bridgeResult = bridgeResult
        }
    }

    /// Invoke the Rust atom-lifecycle bridge for the requested
    /// transition AND persist the result as a `BASAtomLifecycleEvent`
    /// via the host-supplied store。
    ///
    /// The bridge is invoked FIRST so the recorded event reflects
    /// the actual state-machine decision (including illegal /
    /// terminal rejections,which still produce an event row with
    /// the from-phase == to-phase per schema 023's audit-of-
    /// attempts invariant)。
    ///
    /// When the bridge returns Result(outcome: -1, ...) (invalid
    /// byte input),no event is recorded and the function throws
    /// `RecordingError.invalidTransitionByte`。 Stores stay clean。
    ///
    /// - Parameters: see `recordTransition` plus
    ///   - currentPhaseByte / actionByte: passed straight through
    ///     to `BASAtomLifecycleBridge.transition`
    ///
    /// - Returns: ComposedResult with both the persisted event
    ///   AND the bridge's Result (so callers can compose further)
    @discardableResult
    public static func transitionAndRecord(
        eventID: String,
        atomID: String,
        sessionID: String,
        currentPhaseByte: UInt8,
        actionByte: UInt8,
        store: BASAtomLifecycleStore,
        nowMs: Int64,
        actorRef: String? = nil
    ) async throws -> ComposedResult {
        let bridgeResult = BASAtomLifecycleBridge.transition(
            currentPhaseByte: currentPhaseByte,
            actionByte: actionByte)
        if bridgeResult.outcome < 0 {
            throw RecordingError.invalidTransitionByte(
                phase: currentPhaseByte, action: actionByte)
        }
        // For rejected transitions (outcome 1 or 2),the state
        // machine leaves the phase unchanged。 The bridge encodes
        // this by returning nextPhaseByte == currentPhaseByte。
        // Schema 023 records the ATTEMPT (so audit shows the
        // refused action),not just successful advances。
        let toPhase = bridgeResult.advanced
            ? bridgeResult.nextPhaseByte
            : currentPhaseByte
        let event = try await recordTransition(
            eventID: eventID,
            atomID: atomID,
            sessionID: sessionID,
            fromPhaseByte: currentPhaseByte,
            toPhaseByte: toPhase,
            actionByte: actionByte,
            outcome: bridgeResult.outcome,
            store: store,
            nowMs: nowMs,
            actorRef: actorRef)
        return ComposedResult(event: event, bridgeResult: bridgeResult)
    }

    #endif  // os(iOS) || os(macOS)

    // MARK: - Errors

    public enum RecordingError: Error, Equatable, Sendable {
        /// Bridge returned outcome=-1 (invalid byte in / out of
        /// range)。 Carries the offending input bytes for debug。
        case invalidTransitionByte(phase: UInt8, action: UInt8)
    }
}
