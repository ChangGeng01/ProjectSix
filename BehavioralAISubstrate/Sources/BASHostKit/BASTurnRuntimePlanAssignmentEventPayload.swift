// MARK: - BASTurnRuntimePlanAssignmentEventPayload
// chapter 四百四十一 / M1140 — POST-RADICAL Wave 12
//
// Typed Codable payload that lets the chapter 435
// `BASTurnRuntimePlanAssignmentLedger` flow through the
// chapter 428 unified event log。 Sibling to chapter 439
// `BASNativeStageDispatchEventPayload` — closes the OTHER
// half of the routed-dispatch replay surface (decisions
// CAPTURED;the dispatch payload covers decisions HONORED)。
//
// ## Why this exists (system entropy framing)
//
// chapters 435 + 439 + 440 closed the dispatch-side replay
// surface:
//   - chapter 435 captures `BASTurnRuntimePlan
//     AssignmentLedger` (scheduler decisions at probe time)
//   - chapter 439 ships `BASNativeStageDispatchEventPayload`
//     (decisions HONORED at executor)
//   - chapter 440 auto-emits dispatch events from the engine
//
// But the assignment ledger itself — the upstream evidence
// proving the M1102 `BASHardwareAwareScheduler` was
// CONSULTED — still lives ONLY in
// `BASTurnRuntimeEngine.lastAssignmentLedger` actor-isolated
// state。 Future replay (G8 SSM training,causal graph
// extraction,distributed audit) cannot reconstruct
// scheduler decisions from the event stream because they
// aren't on the stream — only the downstream HONOR
// outcomes are。
//
// `BASTurnRuntimePlanAssignmentEventPayload` is the typed
// payload that puts scheduler decisions ON the event
// stream。 Combined with M1087 `BASEventLogProjectors`
// pattern,downstream replay can reconstruct
// `BASTurnRuntimePlanAssignmentLedger` from
// `[BASEventLogEntry]` alone — the FULL routed-dispatch
// surface (capture → honor) is now event-replayable。
//
// ## What this ships (M1140)
//
//   - `BASTurnRuntimePlanAssignmentEventRecord` Sendable +
//     Codable + Equatable + Hashable struct (4 fields:
//     stageRawValue + hintBackingPriorityRawValue +
//     selectedBackingKindRawValue +
//     selectedKernelKeyDescriptor + sequenceIndex)
//   - `BASTurnRuntimePlanAssignmentEventPayload` Sendable
//     + Codable + Equatable + Hashable struct (4 fields:
//     turnID + records + recordCount +
//     acceleratedRecordCount + uniqueStageCount aggregates)
//   - `.from(ledger:)` factory bridges the in-memory ledger
//     to the typed payload
//   - `BASEventLogEntry.planAssignmentEvent(...)` factory
//   - `BASEventLogEntry.planAssignmentEventPayload`
//     reverse accessor
//   - Discriminator action tag matches
//     `BASEventPayloadKind.planAssignment.rawValue`
//   - `BASEventLogProjectors.projectPlanAssignmentEvents(_:)`
//     pure projector (sibling of 5 existing projectors)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed stage
//     rawvalue + named typed aggregates;no raw String
//     scheduler tags)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape;tests + audit + future replay
//     rebuilders all consume the same shape)
//   - chapter 三百九二 — replay-determinism (Codable via
//     sortedKeys JSON;sequenceIndex preserves ordering;
//     ledger → payload → ledger round-trip byte-stable)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payload + extension;no existing call
//     site touched)
//   - 红线 7 — hint-only (event log is observation,not
//     commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore
import BASMetalSubstrate

// MARK: - Per-record event payload mirror

/// Typed Codable + Sendable mirror of
/// `BASTurnRuntimeStageAssignmentRecord` for event-log
/// round-trip。 The legacy struct holds nested typed
/// `BASStageAcceleratorHint` + `BASStageAcceleratorAssignment`;
/// the event-log shape carries hintOperationRawValue +
/// hintBatchSize + hintSequenceLength +
/// selectedBackingKindRawValue +
/// selectedKernelKeyDescriptor as wire-friendly fields。
public struct BASTurnRuntimePlanAssignmentEventRecord:
    Equatable, Hashable, Codable, Sendable
{

    /// Stage rawvalue (matches `BASTurnRuntimeStage.rawValue`)。
    public let stageRawValue: String

    /// `BASNeuralOp.rawValue` of the hint that was fed to
    /// the scheduler (caller-provided op classification)。
    public let hintOperationRawValue: String

    /// Caller's batch size for the stage tensor inputs。
    /// Used by the scheduler to check against
    /// `BASANECapability.maxBatchSize`。
    public let hintBatchSize: Int

    /// Caller's sequence length for the stage tensor
    /// inputs (or 1 for non-sequential ops)。
    public let hintSequenceLength: Int

    /// `BASTensorBackingKind.rawValue` the scheduler
    /// returned (post-cost-evaluation chosen backing)。
    public let selectedBackingKindRawValue: String

    /// `BASKernelKey.wireFormIdentifier` when assignment
    /// had a kernel key;`""` for CPU fallback。
    public let selectedKernelKeyDescriptor: String

    /// 0-based sequence index of this record inside the
    /// ledger。 Pinned so replay sees the same ordering
    /// (chapter 三百九二)。
    public let sequenceIndex: Int

    public init(
        stageRawValue: String,
        hintOperationRawValue: String,
        hintBatchSize: Int,
        hintSequenceLength: Int,
        selectedBackingKindRawValue: String,
        selectedKernelKeyDescriptor: String,
        sequenceIndex: Int
    ) {
        self.stageRawValue = stageRawValue
        self.hintOperationRawValue =
            hintOperationRawValue
        self.hintBatchSize = max(0, hintBatchSize)
        self.hintSequenceLength =
            max(0, hintSequenceLength)
        self.selectedBackingKindRawValue =
            selectedBackingKindRawValue
        self.selectedKernelKeyDescriptor =
            selectedKernelKeyDescriptor
        self.sequenceIndex = max(0, sequenceIndex)
    }
}

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a per-turn plan-assignment ledger summary。
public struct BASTurnRuntimePlanAssignmentEventPayload:
    Equatable, Hashable, Codable, Sendable
{

    /// Turn ID this entry binds to。 Mirrors
    /// `BASTurnRuntimePlanAssignmentLedger.turnID`。
    public let turnID: String

    /// Per-stage records mirror of
    /// `BASTurnRuntimePlanAssignmentLedger.records`。
    public let records:
        [BASTurnRuntimePlanAssignmentEventRecord]

    /// Pre-computed at emit time so consumers don't need
    /// to re-scan `records`。 Mirrors
    /// `BASTurnRuntimePlanAssignmentLedger.recordCount`。
    public let recordCount: Int

    /// Mirrors `BASTurnRuntimePlanAssignmentLedger
    /// .acceleratedRecordCount` — number of records whose
    /// scheduler chose a non-CPU backing。
    public let acceleratedRecordCount: Int

    /// Mirrors `BASTurnRuntimePlanAssignmentLedger
    /// .uniqueStageCount` — number of distinct stages
    /// observed (de-duplicated by stageRawValue)。
    public let uniqueStageCount: Int

    public init(
        turnID: String,
        records:
            [BASTurnRuntimePlanAssignmentEventRecord],
        recordCount: Int,
        acceleratedRecordCount: Int,
        uniqueStageCount: Int
    ) {
        self.turnID = turnID
        self.records = records
        self.recordCount = max(0, recordCount)
        self.acceleratedRecordCount =
            max(0, acceleratedRecordCount)
        self.uniqueStageCount = max(0, uniqueStageCount)
    }

    /// Convenience:build the payload from a typed
    /// `BASTurnRuntimePlanAssignmentLedger` value。 Used
    /// by `BASTurnRuntimeEngine.runWithPlan(...)` to
    /// auto-emit captured assignments via the unified
    /// event log。
    public static func from(
        ledger: BASTurnRuntimePlanAssignmentLedger
    ) -> BASTurnRuntimePlanAssignmentEventPayload {
        let records = ledger.records.map { rec in
            BASTurnRuntimePlanAssignmentEventRecord(
                stageRawValue: rec.stageRawValue,
                hintOperationRawValue:
                    rec.hint.operation.rawValue,
                hintBatchSize: rec.hint.batchSize,
                hintSequenceLength:
                    rec.hint.sequenceLength,
                selectedBackingKindRawValue:
                    rec.assignment.selectedBackingKind
                        .rawValue,
                selectedKernelKeyDescriptor:
                    rec.assignment.selectedKernelKey?
                        .wireFormIdentifier ?? "",
                sequenceIndex: rec.sequenceIndex)
        }
        return BASTurnRuntimePlanAssignmentEventPayload(
            turnID: ledger.turnID,
            records: records,
            recordCount: ledger.recordCount,
            acceleratedRecordCount:
                ledger.acceleratedRecordCount,
            uniqueStageCount: ledger.uniqueStageCount)
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a per-turn
    /// plan-assignment ledger payload。
    public static func planAssignmentEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASTurnRuntimePlanAssignmentEventPayload,
        source: String? = "hardware-aware-scheduler"
    ) -> BASEventLogEntry {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json: String?
        if let data = try? encoder.encode(payload) {
            json = String(data: data, encoding: .utf8)
        } else {
            json = nil
        }
        return BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            source: source,
            turnRef: payload.turnID,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: [],
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: [
                BASEventPayloadKind
                    .planAssignment.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the
    /// `BASTurnRuntimePlanAssignmentEventPayload` if this
    /// entry is a plan-assignment event。
    public var planAssignmentEventPayload:
        BASTurnRuntimePlanAssignmentEventPayload?
    {
        guard hasPayloadKind(.planAssignment) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASTurnRuntimePlanAssignmentEventPayload.self,
            from: data)
    }
}

// MARK: - Projector extension

extension BASEventLogProjectors {

    /// Project the M1140 plan-assignment payloads from
    /// the input slice in sequence-number-sorted order。
    /// Sibling to the 5 existing projectors (memoryAtom /
    /// turnLifecycle / parallelStage / permitEscalation /
    /// nativeStageDispatch)。
    public static func projectPlanAssignmentEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASTurnRuntimePlanAssignmentEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.planAssignment)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.planAssignmentEventPayload
            }
    }
}
