// MARK: - BASTurnRuntimePlanAssignmentLedger
// chapter 四百三十五 / M1117 — POST-RADICAL scheduler integration
//
// Typed ledger recording the per-stage scheduler decisions
// `BASTurnRuntimeEngine.runWithPlan(...)` made for a single
// turn,when the configuration carried a hint sidecar +
// kernel registry + ANE capability。 Surfaced via the engine's
// `lastPlanAssignmentLedger` accessor so tests + audit
// consumers can prove the M1102 BASHardwareAwareScheduler
// is genuinely being consulted at dispatch time。
//
// ## Why this exists (system entropy framing)
//
// Phase F shipped:
//   - M1102 BASHardwareAwareScheduler actor (cost-based
//     routing + 5-case rationale)
//   - M1104 BASStagePlanAcceleratorHints sidecar
//
// Both were ADDITIVE — no production runtime path actually
// consulted the scheduler。 chapter 434 shipped the safety
// substrate;chapter 435 closes the loop by ACTUALLY calling
// `scheduler.assign(hint:capability:thermal:)` per stage
// step inside `runWithPlan(...)` when the configuration
// carries all 3 prerequisites (hints + registry + capability)。
//
// The assignment ledger is the typed evidence surface that
// proves the wiring fired:
//   - One `BASTurnRuntimeStageAssignmentRecord` per stage
//     step that had a hint registered
//   - Carries the stage,the hint that was fed,the
//     scheduler's typed assignment,the cost score
//
// Without this typed surface,the wiring would be invisible
// — observers couldn't tell whether the scheduler was
// actually consulted。 With it,a single
// `engine.lastPlanAssignmentLedger().recordCount > 0` check
// proves the wiring fires。
//
// ## What this ships (M1117)
//
//   - `BASTurnRuntimeStageAssignmentRecord` Sendable +
//     Codable + Equatable + Hashable struct (4 fields:
//     stage / hint / assignment / sequenceIndex)
//   - `BASTurnRuntimePlanAssignmentLedger` Sendable +
//     Codable + Equatable + Hashable struct (records +
//     turnID + sweptStageCount aggregate)
//   - `.empty` static convenience for "no scheduler
//     consultation happened this turn"
//   - `appending(_:)` immutable updater
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     records + named aggregates,no raw String tags)
//   - chapter 二百一一 — single source-of-truth (one
//     ledger shape;tests + audit consumers + future
//     event log payload all consume the same shape)
//   - chapter 三百九二 — replay-determinism (records
//     are Sendable + Codable;sequenceIndex preserves
//     order across replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (ledger is observation only;V1 dispatch path
//     untouched)
//   - 红线 7 — hint-only (assignments are routing
//     observations,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

/// Per-stage record of a scheduler decision。 One record
/// per stage step in the plan that had a hint registered
/// in the configuration's `stagePlanHints` sidecar。
public struct BASTurnRuntimeStageAssignmentRecord:
    Equatable, Hashable, Codable, Sendable
{

    /// Stage the scheduler ran for。 Mirrors the plan
    /// step's stage rawvalue。
    public let stageRawValue: String

    /// Hint that was fed to the scheduler — caller-
    /// provided in the configuration's sidecar。
    public let hint: BASStageAcceleratorHint

    /// Typed assignment the scheduler returned。
    public let assignment:
        BASStageAcceleratorAssignment

    /// 0-based sequence index of this record inside
    /// the ledger。 Pinned so replay sees the same
    /// ordering (chapter 三百九二)。
    public let sequenceIndex: Int

    public init(
        stageRawValue: String,
        hint: BASStageAcceleratorHint,
        assignment: BASStageAcceleratorAssignment,
        sequenceIndex: Int
    ) {
        self.stageRawValue = stageRawValue
        self.hint = hint
        self.assignment = assignment
        self.sequenceIndex = sequenceIndex
    }
}

/// Typed Sendable + Codable ledger of all per-stage
/// scheduler decisions for a single turn。 Captured by
/// `BASTurnRuntimeEngine.runWithPlan(...)` when the
/// configuration carries hints + registry + capability;
/// `.empty` otherwise。
public struct BASTurnRuntimePlanAssignmentLedger:
    Equatable, Hashable, Codable, Sendable
{

    /// Turn ID this ledger binds to。
    public let turnID: String

    /// Per-stage assignment records,in plan order。
    public let records:
        [BASTurnRuntimeStageAssignmentRecord]

    /// Number of stages the scheduler was consulted
    /// for。 Equals `records.count`;pre-computed for
    /// fast assertion checks。
    public var recordCount: Int { records.count }

    /// Number of records whose assignment chose a
    /// non-CPU backing — proves the scheduler routed
    /// at least one stage to an accelerator。
    public var acceleratedRecordCount: Int {
        return records.filter {
            $0.assignment.selectedBackingKind !=
                .cpuBytes
        }.count
    }

    /// Number of distinct stages observed (de-
    /// duplicated by stageRawValue)。
    public var uniqueStageCount: Int {
        return Set(records.map { $0.stageRawValue })
            .count
    }

    public init(
        turnID: String,
        records:
            [BASTurnRuntimeStageAssignmentRecord]
    ) {
        self.turnID = turnID
        self.records = records
    }

    /// Empty ledger for a turn where the scheduler was
    /// not consulted (configuration missing hints,
    /// registry,or capability)。
    public static func empty(
        turnID: String
    ) -> BASTurnRuntimePlanAssignmentLedger {
        return BASTurnRuntimePlanAssignmentLedger(
            turnID: turnID, records: [])
    }

    /// Default empty ledger with empty turnID — used
    /// before any `runWithPlan(...)` call has captured
    /// a real ledger。
    public static let unwired:
        BASTurnRuntimePlanAssignmentLedger =
        BASTurnRuntimePlanAssignmentLedger(
            turnID: "", records: [])

    /// Returns a new ledger with `record` appended
    /// (immutable update)。
    public func appending(
        _ record: BASTurnRuntimeStageAssignmentRecord
    ) -> BASTurnRuntimePlanAssignmentLedger {
        return BASTurnRuntimePlanAssignmentLedger(
            turnID: turnID,
            records: records + [record])
    }
}
