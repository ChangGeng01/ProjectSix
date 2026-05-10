// MARK: - BASEventLogReplayBundle
// chapter 四百四十二 / M1145 — POST-RADICAL Wave 13
//
// Typed Sendable + Equatable bundle aggregating all 6
// typed payload kinds projected from a single
// `[BASEventLogEntry]` slice。 Sibling to chapter 428's
// turn-scoped `BASEventLogTurnProjection` (which only
// covers the original 4 payload kinds);this bundle is
// stream-scoped + carries the 2 new kinds shipped at
// chapters 439 + 441 (nativeStageDispatch +
// planAssignment) so downstream replay consumers (G8
// SSM training,causal graph extraction,distributed
// audit) read once and consume each of 6 kinds directly。
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
    Equatable, Sendable, Hashable
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

    public init(
        memoryAtomEvents: [BASMemoryAtomEventPayload],
        turnLifecycleEvents: [BASTurnLifecycleEventPayload],
        parallelStageEvents: [BASParallelStageEventPayload],
        permitEscalationEvents:
            [BASPermitEscalationEventPayload],
        nativeStageDispatchEvents:
            [BASNativeStageDispatchEventPayload],
        planAssignmentEvents:
            [BASTurnRuntimePlanAssignmentEventPayload]
    ) {
        self.memoryAtomEvents = memoryAtomEvents
        self.turnLifecycleEvents = turnLifecycleEvents
        self.parallelStageEvents = parallelStageEvents
        self.permitEscalationEvents = permitEscalationEvents
        self.nativeStageDispatchEvents =
            nativeStageDispatchEvents
        self.planAssignmentEvents = planAssignmentEvents
    }

    /// Empty bundle for an event log slice that contained
    /// no typed-payload entries (e.g. only legacy
    /// pre-typed events,or a fresh storage)。 All 6
    /// arrays empty。
    public static let empty: BASEventLogReplayBundle =
        BASEventLogReplayBundle(
            memoryAtomEvents: [],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])

    /// Total event count across all 6 typed payload
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
    }

    /// Per-kind event count map。 Useful for replay
    /// audit logs that want to print a breakdown without
    /// hand-coding 6 lines。 Keys match
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
                planAssignmentEvents.count
        ]
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
                projectPlanAssignmentEvents(entries))
    }
}
