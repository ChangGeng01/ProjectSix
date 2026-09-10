// MARK: - BASEventLogProjectors — chapter 四百二十八 / M1087
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B 第四刀。 Pure-function
// projectors that fold `[BASEventLogEntry]` into typed
// summaries downstream consumers can read directly。
//
// ## Why this exists (system entropy framing)
//
// Phase B 第二+三刀 (M1085 + M1086) shipped 3 typed
// payloads — `BASTurnLifecycleEventPayload`,
// `BASParallelStageEventPayload`,
// `BASPermitEscalationEventPayload` — that ride the
// unified `BASEventLog`。 But downstream consumers
// (BASRuntimeAuditEmissionSummary,
// BASTurnRuntimeStageLedger,
// BASPermitEscalationLedger) expect their pre-existing
// shapes,not a stream of event entries。 Without the
// projector layer,switching consumers from "in-memory
// ledger" to "event log replay" requires rewriting every
// reader site。
//
// `BASEventLogProjectors` is the bridge:given a slice
// of events,fold into the legacy summary shape so
// readers don't have to change。 4 named projectors:
//
//   - `projectMemoryAtomEvents(_:) -> [BASMemoryAtomEventPayload]`
//   - `projectTurnLifecycleEvents(_:) -> [BASTurnLifecycleEventPayload]`
//   - `projectParallelStageEvents(_:) -> [BASParallelStageEventPayload]`
//   - `projectPermitEscalationEvents(_:) -> [BASPermitEscalationEventPayload]`
//
// Each projector is a pure function over the input
// slice — no actor state,no I/O,deterministic ordering
// (stable on `sequenceNumber`)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     projector functions per payload kind)
//   - chapter 二百一一 — single source-of-truth (one
//     projector pathway;callers don't open the JSON
//     payload directly)
//   - chapter 三百九二 — replay-determinism (sort by
//     sequenceNumber → same input slice produces same
//     output sequence)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (pure functions over read-only inputs)
//   - 红线 7 — hint-only (projection is observation,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy

/// Pure-function projectors that fold
/// `[BASEventLogEntry]` slices into typed payload
/// arrays downstream consumers can read directly。
public enum BASEventLogProjectors {

    // MARK: - Memory atom events

    /// Filter the input slice for memory-atom events
    /// (`BASEventPayloadKind.memoryAtom`),decode each
    /// `payloadJson` into the typed M941
    /// `BASMemoryAtomEventPayload`,and return in
    /// sequence-number-sorted order。
    ///
    /// Entries that don't carry a memory-atom payload,
    /// or whose payload is malformed,are silently
    /// skipped (forward-compat;legacy entries decode
    /// to nil)。
    public static func projectMemoryAtomEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASMemoryAtomEventPayload] {
        return entries
            .filter { $0.hasPayloadKind(.memoryAtom) }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap { $0.memoryAtomEventPayload }
    }

    // MARK: - Turn lifecycle events

    /// Project the M1085 turn lifecycle payloads from
    /// the input slice in sequence-number-sorted
    /// order。
    public static func projectTurnLifecycleEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASTurnLifecycleEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.turnLifecycle)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.turnLifecycleEventPayload
            }
    }

    // MARK: - Parallel stage events

    /// Project the M1085 parallel-stage payloads from
    /// the input slice in sequence-number-sorted
    /// order。
    public static func projectParallelStageEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASParallelStageEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.parallelStage)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.parallelStageEventPayload
            }
    }

    // MARK: - Permit escalation events

    /// Project the M1086 permit escalation payloads
    /// from the input slice in sequence-number-sorted
    /// order。
    public static func projectPermitEscalationEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASPermitEscalationEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.permitEscalation)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.permitEscalationEventPayload
            }
    }

    // MARK: - Combined turn-scoped projection

    /// Convenience:filter the input slice for events
    /// belonging to a specific turn (`turnRef ==
    /// turnID`),then project all 4 payload kinds in
    /// one pass。 Returns a typed bundle so callers
    /// can read each kind without re-filtering。
    public static func projectTurn(
        _ turnID: String,
        from entries: [BASEventLogEntry]
    ) -> BASEventLogTurnProjection {
        let scoped = entries.filter {
            $0.turnRef == turnID
        }
        return BASEventLogTurnProjection(
            turnID: turnID,
            memoryAtomEvents:
                projectMemoryAtomEvents(scoped),
            turnLifecycleEvents:
                projectTurnLifecycleEvents(scoped),
            parallelStageEvents:
                projectParallelStageEvents(scoped),
            permitEscalationEvents:
                projectPermitEscalationEvents(scoped))
    }
}

// MARK: - Combined turn-scoped projection bundle

/// Typed Sendable + Equatable bundle returned by
/// `BASEventLogProjectors.projectTurn(...)`。 Carries
/// all 4 payload-kind projections for a single turn
/// so callers (Phase E scheduler probe + future SSM
/// trainer + causal graph extractor) read once and
/// consume each kind directly。
public struct BASEventLogTurnProjection:
    Equatable, Sendable, Hashable, Codable
{

    public let turnID: String
    public let memoryAtomEvents:
        [BASMemoryAtomEventPayload]
    public let turnLifecycleEvents:
        [BASTurnLifecycleEventPayload]
    public let parallelStageEvents:
        [BASParallelStageEventPayload]
    public let permitEscalationEvents:
        [BASPermitEscalationEventPayload]

    public init(
        turnID: String,
        memoryAtomEvents:
            [BASMemoryAtomEventPayload],
        turnLifecycleEvents:
            [BASTurnLifecycleEventPayload],
        parallelStageEvents:
            [BASParallelStageEventPayload],
        permitEscalationEvents:
            [BASPermitEscalationEventPayload]
    ) {
        self.turnID = turnID
        self.memoryAtomEvents = memoryAtomEvents
        self.turnLifecycleEvents = turnLifecycleEvents
        self.parallelStageEvents = parallelStageEvents
        self.permitEscalationEvents =
            permitEscalationEvents
    }

    /// Total event count across all 4 kinds for this
    /// turn (cheap sanity assertion for tests)。
    public var totalEventCount: Int {
        return memoryAtomEvents.count
            + turnLifecycleEvents.count
            + parallelStageEvents.count
            + permitEscalationEvents.count
    }
}
