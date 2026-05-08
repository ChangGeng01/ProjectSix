// MARK: - BASMemoryMutationEventEmitter — chapter 四百二 / M944
//
// Phase 1 第四刀: typed event emitter that bridges existing
// `BASMemoryMutationWriter.apply(outcome:)` outcomes into typed
// `BASEventLogEntry` writes。Hosts using event-sourced storage
// call `emitter.emit(outcome:)` BEFORE `mutationWriter.apply(outcome:)`;
// the event-sourced store sees events on its own (via shared
// eventLog) and projects them;legacy stores are then mutated by
// the writer。Phase 2 / chapter 四百三 collapses this two-step
// flow into a single emit-then-project step。
//
// ## Why this exists
//
// `BASMemoryMutationWriter.apply(outcome:)` (M215) takes a
// `BASMemoryTieringReconciliationOutcome` and applies decisions
// directly to a `BASMemoryAtomStore`。Pre-M944 the path was:
//
//   reconciler.evaluate(...)  →  outcome
//   mutationWriter.apply(outcome:)  →  store mutates
//   ⊙ event log NEVER sees these mutations ⊙
//
// Post-M944 hosts can run:
//
//   reconciler.evaluate(...)  →  outcome
//   emitter.emit(outcome:)  →  events appended to log
//   mutationWriter.apply(outcome:)  →  legacy store mutates
//
// And event-sourced stores see the events on their own。This is
// additive: pre-M944 hosts that don't use the emitter see zero
// behavior change。
//
// ## Per-transition mapping
//
//   - `.hold(...)` → SKIPPED (no event)。Atom state unchanged。
//   - `.promote(_, to, _)` / `.demote(_, to, _)` → tierChange event
//   - `.quarantineSuggest(_, _)` → governanceChange to .quarantined
//   - `.evictSuggest(_, _)` → remove event
//
// ## Doctrine pins held
//
//   - All M941-M943 doctrine pins
//   - chapter 二百一一 — emitter is the typed bridge,not a parallel
//     mutation path
//   - chapter 三百九二 — emit order matches outcome.decisions order
//     so replay produces same projection

import Foundation
import BASRuntimeCore

// MARK: - Emitter

public actor BASMemoryMutationEventEmitter {

    // MARK: - Outcome surface

    public struct EmitOutcome: Sendable, Equatable {
        /// Number of decisions that produced an appended event。
        public let appended: Int
        /// Number of decisions that produced no event (e.g.
        /// `.hold` — atom state unchanged)。
        public let skipped: Int
        /// Decisions where event append returned `wasNew=false`
        /// (idempotent retry detection)。
        public let duplicateAppendsSkipped: Int
        /// Per-event payloads emitted (in declaration order)。
        public let payloads: [BASMemoryAtomEventPayload]

        public init(
            appended: Int,
            skipped: Int,
            duplicateAppendsSkipped: Int,
            payloads: [BASMemoryAtomEventPayload]
        ) {
            self.appended = appended
            self.skipped = skipped
            self.duplicateAppendsSkipped =
                duplicateAppendsSkipped
            self.payloads = payloads
        }
    }

    // MARK: - Dependencies

    private let eventLog: any BASEventLogStorage
    private let sessionID: String
    private let clockMs: @Sendable () -> Int64
    private let eventIDFactory: @Sendable () -> String
    private let source: String

    // MARK: - Init

    public init(
        eventLog: any BASEventLogStorage,
        sessionID: String,
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) },
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        source: String = "memory-mutation-writer"
    ) {
        self.eventLog = eventLog
        self.sessionID = sessionID
        self.clockMs = clockMs
        self.eventIDFactory = eventIDFactory
        self.source = source
    }

    // MARK: - Emit

    /// Decompose `outcome` into typed events and append them in
    /// declaration order to the event log。Returns a typed
    /// summary。
    @discardableResult
    public func emit(
        outcome: BASMemoryTieringReconciliationOutcome
    ) async throws -> EmitOutcome {
        var appended = 0
        var skipped = 0
        var duplicate = 0
        var payloads: [BASMemoryAtomEventPayload] = []

        for decision in outcome.decisions {
            let atomID = decision.profile.atomID
            let payload: BASMemoryAtomEventPayload?
            switch decision.transition {
            case .hold:
                payload = nil
                skipped += 1
            case .promote(_, let to, _):
                payload = BASMemoryAtomEventPayload(
                    tierChange: atomID, newTier: to)
            case .demote(_, let to, _):
                payload = BASMemoryAtomEventPayload(
                    tierChange: atomID, newTier: to)
            case .quarantineSuggest:
                payload = BASMemoryAtomEventPayload(
                    governanceChange: atomID,
                    newStatus: .quarantined)
            case .evictSuggest:
                payload = BASMemoryAtomEventPayload(
                    remove: atomID)
            }
            if let p = payload {
                payloads.append(p)
                let entry = BASEventLogEntry.memoryAtomEvent(
                    eventID: eventIDFactory(),
                    timestampMs: clockMs(),
                    sessionID: sessionID,
                    sequenceNumber: 0,
                    payload: p,
                    source: source)
                let res = try await eventLog.append(entry)
                if res.wasNew {
                    appended += 1
                } else {
                    duplicate += 1
                }
            }
        }
        return EmitOutcome(
            appended: appended,
            skipped: skipped,
            duplicateAppendsSkipped: duplicate,
            payloads: payloads)
    }
}
