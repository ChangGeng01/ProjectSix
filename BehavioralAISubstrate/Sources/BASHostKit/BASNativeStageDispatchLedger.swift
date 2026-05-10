// MARK: - BASNativeStageDispatchLedger
// chapter 四百三十六 / M1120 — POST-RADICAL Wave 7
//
// Typed dispatch ledger recording the per-stage routing
// decisions `BASNativeStageExecutor.executePlanWith
// Assignments(...)` honored when running a plan against
// a `BASTurnRuntimePlanAssignmentLedger`。
//
// ## Why this exists (system entropy framing)
//
// chapter 435 (M1116-M1119) ships the assignment ledger
// (typed evidence that scheduler.assign() was called per
// stage)。 But the ledger is OBSERVATION ONLY — actual
// stage dispatch still walks the V1-mirror path inside
// BASRuntimeInternalDelegate。
//
// chapter 436 closes the gap:
// `BASNativeStageExecutor.executePlanWithAssignments(...)`
// reads the assignment ledger AND routes each stage's
// closure invocation through a typed `RoutedStageExecutor`
// closure that receives the chosen backing + kernel key
// for that stage。 Per-stage routing decisions are then
// captured into this typed dispatch ledger,proving the
// scheduler's decisions were actually HONORED at
// execution time (not just recorded)。
//
// **Without this typed surface,we'd have evidence of
// "scheduler decided X" but no evidence of "executor
// honored X"**。 With it,a single
// `dispatchLedger.honoredAssignmentCount > 0` check
// proves end-to-end ledger-driven dispatch fires。
//
// ## What this ships (M1120)
//
//   - `BASNativeStageExecutionRecord` Sendable + Codable
//     + Equatable + Hashable struct (5 fields:
//     stage / assignment / durationMs / sequenceIndex
//     / honoredAssignment Bool)
//   - `BASNativeStageDispatchLedger` Sendable + Codable
//     + Equatable + Hashable struct (records + 4 typed
//     aggregates:executionCount / honoredAssignmentCount
//     / unhonoredAssignmentCount / totalDurationMs)
//   - `.empty()` + `.unwired` sentinels
//   - `appending(_:)` immutable updater
//
// ## Why "honoredAssignment" boolean
//
// A stage may run via `executePlanWithAssignments(...)`
// even when no assignment was registered for it (the
// plan's stage isn't covered by the hint sidecar)。 In
// that case the stage executes via the default executor
// closure path — `honoredAssignment = false`。 When an
// assignment WAS available + the executor was invoked
// with it,`honoredAssignment = true`。 The aggregate
// count distinguishes "we routed N stages via the
// scheduler's decision" vs "we ran N stages with the
// fallback path"。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     records + named aggregates;no raw String routing
//     tags)
//   - chapter 二百一一 — single source-of-truth (one
//     dispatch ledger shape;tests + audit + future
//     event log payload all consume the same shape)
//   - chapter 三百九二 — replay-determinism (records are
//     Sendable + Codable;sequenceIndex preserves order
//     across replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (executor still default-empty;V1 dispatch path
//     unchanged for non-opt-in callers)
//   - 红线 7 — hint-only (dispatch ledger is observation
//     of routing decisions,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

/// Per-stage record of an execution dispatch decision。
/// One record per stage executed by
/// `BASNativeStageExecutor.executePlanWithAssignments(...)`
/// regardless of whether an assignment was honored。
public struct BASNativeStageExecutionRecord:
    Equatable, Hashable, Codable, Sendable
{

    /// Stage that was executed (raw value of the typed
    /// `BASTurnRuntimeStage` for replay stability)。
    public let stageRawValue: String

    /// Assignment that drove the dispatch decision。
    /// `nil` when no assignment was registered for this
    /// stage (executor falls back to default path)。
    public let assignment:
        BASStageAcceleratorAssignment?

    /// Wall-clock duration of the stage execution in
    /// milliseconds。 Replay-stable when normalized。
    public let durationMs: Int

    /// 0-based sequence index of this record inside the
    /// dispatch ledger。 Pinned so replay sees the same
    /// ordering (chapter 三百九二)。
    public let sequenceIndex: Int

    /// Whether the executor honored a registered
    /// assignment for this stage。 `true` when
    /// `assignment != nil` AND the routed executor
    /// closure was invoked with it。 `false` when the
    /// stage fell through to the default executor。
    public let honoredAssignment: Bool

    public init(
        stageRawValue: String,
        assignment: BASStageAcceleratorAssignment?,
        durationMs: Int,
        sequenceIndex: Int,
        honoredAssignment: Bool
    ) {
        self.stageRawValue = stageRawValue
        self.assignment = assignment
        self.durationMs = max(0, durationMs)
        self.sequenceIndex = sequenceIndex
        self.honoredAssignment = honoredAssignment
    }
}

/// Typed Sendable + Codable dispatch ledger of all
/// per-stage execution dispatch decisions for a single
/// `executePlanWithAssignments(...)` invocation。
public struct BASNativeStageDispatchLedger:
    Equatable, Hashable, Codable, Sendable
{

    /// Per-stage execution records,in plan order。
    public let records: [BASNativeStageExecutionRecord]

    /// Total number of stages executed (= records.count)。
    public var executionCount: Int { records.count }

    /// Number of records where the executor honored a
    /// registered assignment — proves end-to-end
    /// ledger-driven dispatch fired for at least one
    /// stage。
    public var honoredAssignmentCount: Int {
        return records.filter {
            $0.honoredAssignment
        }.count
    }

    /// Number of records where the stage fell through
    /// to the default executor (no assignment in
    /// sidecar)。
    public var unhonoredAssignmentCount: Int {
        return records.filter {
            !$0.honoredAssignment
        }.count
    }

    /// Total wall-clock duration across all stages,
    /// milliseconds。 Used by future hardware-aware
    /// scheduler refinement to update cost estimates。
    public var totalDurationMs: Int {
        return records.reduce(0) {
            $0 + $1.durationMs
        }
    }

    public init(
        records: [BASNativeStageExecutionRecord] = []
    ) {
        self.records = records
    }

    /// Empty ledger for an `executePlanWithAssignments`
    /// call that had no plan steps to walk。
    public static let empty:
        BASNativeStageDispatchLedger =
        BASNativeStageDispatchLedger(records: [])

    /// Returns a new ledger with `record` appended
    /// (immutable update)。
    public func appending(
        _ record: BASNativeStageExecutionRecord
    ) -> BASNativeStageDispatchLedger {
        return BASNativeStageDispatchLedger(
            records: records + [record])
    }
}
