// MARK: - BASEventLogReplayBundle
// chapter 四百四十二 / M1145 — POST-RADICAL Wave 13
//
// Typed Sendable + Equatable bundle aggregating all 6
// typed payload kinds projected from a single
// `[BASEventLogEntry]` slice。 Sibling to chapter 428's
// turn-scoped `BASEventLogTurnProjection` (which only
// covers the original 4 payload kinds);this bundle is
// stream-scoped + carries the 2 new kinds shipped at
// chapters 439 + 441 + 444 (nativeStageDispatch +
// planAssignment + nativeStagePerStep) so downstream
// replay consumers (G8 SSM training,causal graph
// extraction,distributed audit) read once and consume
// each of 7 kinds directly。
//
// ## Why this exists (system entropy framing)
//
// Wave 11 (chapter 440) auto-emitted dispatch events to
// the unified event log;Wave 12 (chapter 441) auto-
// emitted plan-assignment events。 Both were ADDITIVE
// extensions to the chapter 428 5-kind unified event
// log (memoryAtom / turnLifecycle / parallelStage /
// permitEscalation,plus the 2 new kinds = 6 total)。
//
// But the existing turn-scoped `BASEventLogTurnProjection`
// (chapter 428) only carries 4 fields。 Replay consumers
// that want to rebuild the FULL substrate state from
// the event stream alone — including chapter 437 routed
// dispatch decisions + chapter 435 scheduler captures —
// have to call 2 extra projectors separately and stitch
// the results。
//
// `BASEventLogReplayBundle` ships ONE typed value-type
// that aggregates ALL 6 projector outputs from a single
// pure call:
//
//   let bundle = BASEventLogProjectors.projectAllPayloadKinds(
//       events)
//   // bundle.memoryAtomEvents,bundle.turnLifecycleEvents,
//   // bundle.parallelStageEvents,bundle.permitEscalationEvents,
//   // bundle.nativeStageDispatchEvents,bundle.planAssignmentEvents
//
// This is purely additive — `BASEventLogTurnProjection`
// remains for backward compatibility,but new replay
// callers should prefer the 6-kind bundle。
//
// ## What this ships (M1145)
//
//   - `BASEventLogReplayBundle` Sendable + Equatable +
//     Hashable struct (6 typed array fields:
//     memoryAtomEvents + turnLifecycleEvents +
//     parallelStageEvents + permitEscalationEvents +
//     nativeStageDispatchEvents + planAssignmentEvents)
//   - `totalEventCount` aggregate accessor (sum across
//     all 6 kinds)
//   - `BASEventLogProjectors.projectAllPayloadKinds(_:)`
//     pure factory:single-pass call returning the
//     bundle from `[BASEventLogEntry]`
//   - `.empty` static convenience for empty input
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     6-field bundle;no untyped dictionaries or arrays
//     of mixed payloads)
//   - chapter 二百一一 — single source-of-truth (one
//     bundle shape;all replay consumers consume the
//     same shape)
//   - chapter 三百九二 — replay-determinism (each
//     projector preserves sequenceNumber ordering;
//     bundle is deterministic in input → output)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive bundle + factory;no existing call site
//     touched;BASEventLogTurnProjection retained)
//   - 红线 7 — hint-only (event log projection is
//     observation,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy

// MARK: - Bundle struct

/// Typed Sendable + Equatable bundle returned by
/// `BASEventLogProjectors.projectAllPayloadKinds(_:)`。
/// Carries all 6 payload-kind projections from a single
/// event-log slice so replay consumers (Phase E
/// scheduler probe,future SSM trainer,causal graph
/// extractor,distributed audit) read once and consume
/// each kind directly without re-filtering。
public struct BASEventLogReplayBundle:
    Equatable, Sendable, Hashable, Codable
{

    /// M941 chapter 四百二 memory-atom mutation events
    /// in sequence-number-sorted order。
    public let memoryAtomEvents:
        [BASMemoryAtomEventPayload]

    /// M1085 chapter 四百二十八 turn lifecycle events
    /// (turn:start / turn:complete envelopes) in
    /// sequence-number-sorted order。
    public let turnLifecycleEvents:
        [BASTurnLifecycleEventPayload]

    /// M1085 chapter 四百二十八 parallel-stage fan-out
    /// events in sequence-number-sorted order。
    public let parallelStageEvents:
        [BASParallelStageEventPayload]

    /// M1086 chapter 四百二十八 permit escalation events
    /// in sequence-number-sorted order。
    public let permitEscalationEvents:
        [BASPermitEscalationEventPayload]

    /// M1132 chapter 四百三十九 native-stage dispatch
    /// events (decisions HONORED at executor) in
    /// sequence-number-sorted order。
    public let nativeStageDispatchEvents:
        [BASNativeStageDispatchEventPayload]

    /// M1140 chapter 四百四十一 plan-assignment events
    /// (decisions CAPTURED at scheduler probe time) in
    /// sequence-number-sorted order。
    public let planAssignmentEvents:
        [BASTurnRuntimePlanAssignmentEventPayload]

    /// M1153 chapter 四百四十四 per-step dispatch events
    /// (one entry per stage step,sibling of the per-
    /// turn nativeStageDispatchEvents)。 Empty unless
    /// the host opted in via direct emission。
    public let nativeStagePerStepEvents:
        [BASNativeStagePerStepEventPayload]

    /// Construct the 7-kind bundle。
    ///
    /// **`nativeStagePerStepEvents` default**:Defaults
    /// to `[]` for backward compatibility with chapter
    /// 442 pre-`nativeStagePerStep`-kind call sites
    /// (which constructed the bundle with 6 arguments
    /// before chapter 444 added the 7th kind)。 New
    /// call sites should pass an explicit value when
    /// they have per-step data on hand。
    public init(
        memoryAtomEvents: [BASMemoryAtomEventPayload],
        turnLifecycleEvents: [BASTurnLifecycleEventPayload],
        parallelStageEvents: [BASParallelStageEventPayload],
        permitEscalationEvents:
            [BASPermitEscalationEventPayload],
        nativeStageDispatchEvents:
            [BASNativeStageDispatchEventPayload],
        planAssignmentEvents:
            [BASTurnRuntimePlanAssignmentEventPayload],
        nativeStagePerStepEvents:
            [BASNativeStagePerStepEventPayload] = []
    ) {
        self.memoryAtomEvents = memoryAtomEvents
        self.turnLifecycleEvents = turnLifecycleEvents
        self.parallelStageEvents = parallelStageEvents
        self.permitEscalationEvents = permitEscalationEvents
        self.nativeStageDispatchEvents =
            nativeStageDispatchEvents
        self.planAssignmentEvents = planAssignmentEvents
        self.nativeStagePerStepEvents =
            nativeStagePerStepEvents
    }

    /// Empty bundle for an event log slice that contained
    /// no typed-payload entries (e.g. only legacy
    /// pre-typed events,or a fresh storage)。 All 7
    /// arrays empty。
    public static let empty: BASEventLogReplayBundle =
        BASEventLogReplayBundle(
            memoryAtomEvents: [],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [],
            nativeStagePerStepEvents: [])

    /// Total event count across all 7 typed payload
    /// kinds。 Cheap sanity assertion for tests + replay
    /// consumers that want to verify the bundle is
    /// fully populated。
    public var totalEventCount: Int {
        return memoryAtomEvents.count
            + turnLifecycleEvents.count
            + parallelStageEvents.count
            + permitEscalationEvents.count
            + nativeStageDispatchEvents.count
            + planAssignmentEvents.count
            + nativeStagePerStepEvents.count
    }

    /// Per-kind event count map。 Useful for replay
    /// audit logs that want to print a breakdown without
    /// hand-coding 7 lines。 Keys match
    /// `BASEventPayloadKind.rawValue` for easy matching
    /// against the discriminator action tag。
    public var perKindEventCount: [String: Int] {
        return [
            BASEventPayloadKind.memoryAtom.rawValue:
                memoryAtomEvents.count,
            BASEventPayloadKind.turnLifecycle.rawValue:
                turnLifecycleEvents.count,
            BASEventPayloadKind.parallelStage.rawValue:
                parallelStageEvents.count,
            BASEventPayloadKind.permitEscalation.rawValue:
                permitEscalationEvents.count,
            BASEventPayloadKind
                .nativeStageDispatch.rawValue:
                nativeStageDispatchEvents.count,
            BASEventPayloadKind.planAssignment.rawValue:
                planAssignmentEvents.count,
            BASEventPayloadKind
                .nativeStagePerStep.rawValue:
                nativeStagePerStepEvents.count
        ]
    }

    // MARK: - chapter 四百四十三 / M1149 — bundle composition

    /// Returns a NEW bundle whose 6 typed arrays are
    /// the concatenation of `self` and `other` (per
    /// kind,in input order)。 Immutable update;does
    /// NOT mutate either operand。
    ///
    /// Use this when accumulating replay events across
    /// multiple sessions or storage backends:fetch one
    /// session,build a bundle,fetch the next,merge,
    /// etc。 Per-kind events keep the order they had in
    /// each source bundle (which is sequenceNumber-
    /// sorted within each source session via the M1145
    /// projector pattern)。
    ///
    /// Note:cross-session events do NOT get re-sorted
    /// — sequenceNumber is per-session-monotonic only,
    /// not globally。 For globally-time-ordered output,
    /// pass entries to `projectAcrossAllSessions(from:
    /// sinceTimestampMs:limit:)` which uses storage's
    /// `(timestampMs ASC, sequenceNumber ASC)` global
    /// ordering before projection (M1149)。
    public func merging(
        _ other: BASEventLogReplayBundle
    ) -> BASEventLogReplayBundle {
        return BASEventLogReplayBundle(
            memoryAtomEvents:
                memoryAtomEvents + other.memoryAtomEvents,
            turnLifecycleEvents:
                turnLifecycleEvents +
                    other.turnLifecycleEvents,
            parallelStageEvents:
                parallelStageEvents +
                    other.parallelStageEvents,
            permitEscalationEvents:
                permitEscalationEvents +
                    other.permitEscalationEvents,
            nativeStageDispatchEvents:
                nativeStageDispatchEvents +
                    other.nativeStageDispatchEvents,
            planAssignmentEvents:
                planAssignmentEvents +
                    other.planAssignmentEvents,
            nativeStagePerStepEvents:
                nativeStagePerStepEvents +
                    other.nativeStagePerStepEvents)
    }

    /// Combine an arbitrary list of bundles into one。
    /// Equivalent to `bundles.reduce(.empty) { $0
    /// .merging($1) }` but spelled out so the intent
    /// is obvious at the call site。 Empty input
    /// returns `.empty`。 Single-element input returns
    /// the input bundle (no copy needed but typed
    /// signature returns a fresh value)。
    ///
    /// Determinism (chapter 三百九二):output is
    /// deterministic in input bundle order — same
    /// inputs in same order yield byte-equal output。
    public static func combining(
        _ bundles: [BASEventLogReplayBundle]
    ) -> BASEventLogReplayBundle {
        return bundles.reduce(
            BASEventLogReplayBundle.empty
        ) { acc, b in
            acc.merging(b)
        }
    }
}

// MARK: - Projector extension

extension BASEventLogProjectors {

    /// Project ALL 6 typed payload kinds from the input
    /// slice in a single pass。 Returns
    /// `BASEventLogReplayBundle` carrying each kind in
    /// sequence-number-sorted order。 Pure function — no
    /// I/O,no actor isolation。
    ///
    /// Sibling to `projectTurn(_:from:)` (chapter 428,
    /// 4-kind turn-scoped);this is the 6-kind
    /// stream-scoped variant for replay consumers
    /// (G8 SSM training,causal graph extraction,
    /// distributed audit) that need the full payload-
    /// kind surface from chapters 439 + 441。
    public static func projectAllPayloadKinds(
        _ entries: [BASEventLogEntry]
    ) -> BASEventLogReplayBundle {
        return BASEventLogReplayBundle(
            memoryAtomEvents:
                projectMemoryAtomEvents(entries),
            turnLifecycleEvents:
                projectTurnLifecycleEvents(entries),
            parallelStageEvents:
                projectParallelStageEvents(entries),
            permitEscalationEvents:
                projectPermitEscalationEvents(entries),
            nativeStageDispatchEvents:
                projectNativeStageDispatchEvents(entries),
            planAssignmentEvents:
                projectPlanAssignmentEvents(entries),
            nativeStagePerStepEvents:
                projectNativeStagePerStepEvents(entries))
    }

    // MARK: - chapter 四百四十三 / M1149 — cross-session factory

    /// Async factory that pulls events ACROSS ALL
    /// sessions from a `BASEventLogStorage` and projects
    /// the 6-kind bundle in one call。 Uses the
    /// protocol's `events(sinceTimestampMs:limit:)`
    /// global accessor (chapter 四百二 / M941),which
    /// returns events sorted by `(timestampMs ASC,
    /// sequenceNumber ASC)` — globally time-ordered
    /// across sessions。
    ///
    /// Use this when replay consumers (G8 SSM training,
    /// causal graph extraction,distributed audit) need
    /// the full event log without filtering by session
    /// — e.g. the host runs multiple concurrent
    /// sessions and downstream wants a unified replay。
    ///
    /// `since: 0` (default) means "all-time";callers
    /// scope to a window via `since: cutoffMs`。
    /// `limit: Int.max` (default) means "everything";
    /// callers cap memory via `limit: maxRecords`。
    ///
    /// Determinism (chapter 三百九二):output is
    /// deterministic for a given storage state at
    /// call time。 Concurrent appends during the call
    /// may or may not be reflected (storage actor
    /// isolation determines snapshot semantics)。
    public static func projectAcrossAllSessions(
        from storage: any BASEventLogStorage,
        sinceTimestampMs since: Int64 = 0,
        limit: Int = Int.max
    ) async -> BASEventLogReplayBundle {
        let entries = await storage.events(
            sinceTimestampMs: since,
            limit: limit)
        return projectAllPayloadKinds(entries)
    }
}
