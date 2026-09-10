// MARK: - BASNativeStagePerStepEventPayload
// chapter 四百四十四 / M1153 — POST-RADICAL Wave 15
//
// Per-stage-step event payload — sibling of chapter 439's
// per-turn `BASNativeStageDispatchEventPayload`。 Where
// the per-turn payload carries `[BASNativeStageDispatch
// EventRecord]` aggregating ALL stages a turn dispatched,
// the per-step payload carries ONE stage's record per
// event entry。 Enables fine-grained causal graph
// extraction (chapter 442 future-cut item #3):
// downstream can attribute entropy reduction or latency
// regression at the stage level without unbundling the
// per-turn aggregate。
//
// ## Why this exists (system entropy framing)
//
// Wave 11 (chapter 440) auto-emits ONE
// BASNativeStageDispatchEvent per turn carrying the full
// dispatch ledger。 This is great for replay
// reconstruction (one event = one ledger) but makes
// stage-level causal analysis harder:to reason about
// "stage X's contribution to turn Y's energy", consumers
// have to pull the per-turn event,unwrap the records
// array,find the matching stageRawValue。
//
// chapter 442 future-cut #3:per-stage event payload
// (one entry per stage step,not per turn)。 Shipped at
// chapter 444:
//   - Each stage step gets its own typed event entry
//   - Carries 1 record's worth of data + the parent
//     turnID + step sequence index for replay ordering
//   - Same shape semantics as chapter 439 records
//     (stageRawValue + selectedBackingKindRawValue +
//     selectedKernelKeyDescriptor + durationMs +
//     honoredAssignment) — replay rebuilders can fold
//     per-step events back into a per-turn payload via
//     turnID grouping
//
// **Sibling,not replacement**:per-turn dispatch event
// (chapter 439) remains the primary auto-emit path
// because it groups all stages of a turn into 1 entry
// (cheap for replay)。 Per-step events are an OPT-IN
// projection consumers can request when they need
// stage-level granularity。 Engine does NOT auto-emit
// per-step events at chapter 444 — that would 5×-10×
// the event log volume per turn。 Hosts that want
// per-step granularity opt-in via direct
// `BASEventLogEntry.nativeStagePerStepEvent(...)` calls
// from their stage executor implementations。
//
// ## What this ships (M1153)
//
//   - `BASNativeStagePerStepEventPayload` Sendable +
//     Codable + Equatable + Hashable struct (8 fields:
//     turnID + stageRawValue + stepSequenceIndex +
//     selectedBackingKindRawValue +
//     selectedKernelKeyDescriptor + durationMs +
//     honoredAssignment + assignmentRationaleRawValue)
//   - `.from(record:turnID:stepSequenceIndex:assignmentRationale:)`
//     factory bridging from chapter 439's per-turn
//     `BASNativeStageDispatchEventRecord`
//   - `BASEventLogEntry.nativeStagePerStepEvent(...)`
//     factory + reverse accessor
//   - `BASEventPayloadKind.nativeStagePerStep` case
//     (rawvalue `"native-stage-per-step-event"`)
//   - `BASEventLogProjectors.projectNativeStagePerStepEvents(_:)`
//     pure projector
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     8-field record;no untyped JSON blobs;
//     assignmentRationaleRawValue carries chapter 432
//     rationale enum)
//   - chapter 二百一一 — single source-of-truth (per-
//     step is a SIBLING of per-turn,both reference the
//     same `BASNativeStageExecutionRecord` shape;not
//     parallel implementations)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;stepSequenceIndex preserves
//     within-turn ordering;turnID groups for replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive payload + extension;engine does
//     NOT auto-emit per-step events;chapter 439 per-
//     turn auto-emit unchanged)
//   - 红线 7 — hint-only (event log is observation,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents ONE stage step's dispatch outcome
/// (sibling of chapter 439's per-turn payload which
/// aggregates all stages)。
public struct BASNativeStagePerStepEventPayload:
    Equatable, Hashable, Codable, Sendable
{

    /// Parent turn ID — replay groups per-step events
    /// by turnID to reconstruct the per-turn aggregate。
    public let turnID: String

    /// Stage rawvalue (matches `BASTurnRuntimeStage.rawValue`)。
    public let stageRawValue: String

    /// 0-based sequence index of this step inside the
    /// parent turn。 Pinned so replay sees the same
    /// ordering (chapter 三百九二)。
    public let stepSequenceIndex: Int

    /// `BASTensorBackingKind.rawValue` when assignment
    /// honored;`""` (empty string) when stage fell
    /// through to fallback executor (no assignment)。
    public let selectedBackingKindRawValue: String

    /// `BASKernelKey.wireFormIdentifier` when assignment
    /// had a kernel key;`""` for CPU fallback or no
    /// assignment。
    public let selectedKernelKeyDescriptor: String

    /// Wall-clock duration of the stage execution in
    /// milliseconds。
    public let durationMs: Int

    /// Whether the executor honored a registered
    /// assignment for this stage。
    public let honoredAssignment: Bool

    /// `BASAssignmentRationale.rawValue` for the
    /// assignment that drove this step's dispatch (or
    /// `""` when no rationale was attached, e.g.
    /// fallback path)。
    public let assignmentRationaleRawValue: String

    public init(
        turnID: String,
        stageRawValue: String,
        stepSequenceIndex: Int,
        selectedBackingKindRawValue: String,
        selectedKernelKeyDescriptor: String,
        durationMs: Int,
        honoredAssignment: Bool,
        assignmentRationaleRawValue: String
    ) {
        self.turnID = turnID
        self.stageRawValue = stageRawValue
        self.stepSequenceIndex =
            max(0, stepSequenceIndex)
        self.selectedBackingKindRawValue =
            selectedBackingKindRawValue
        self.selectedKernelKeyDescriptor =
            selectedKernelKeyDescriptor
        self.durationMs = max(0, durationMs)
        self.honoredAssignment = honoredAssignment
        self.assignmentRationaleRawValue =
            assignmentRationaleRawValue
    }

    /// Convenience:build the payload from chapter 439's
    /// per-turn `BASNativeStageDispatchEventRecord`
    /// shape。 Used by hosts that already have per-turn
    /// records on hand and want to emit per-step events
    /// for fine-grained causal-graph extraction。
    public static func from(
        record: BASNativeStageDispatchEventRecord,
        turnID: String,
        stepSequenceIndex: Int,
        assignmentRationaleRawValue: String = ""
    ) -> BASNativeStagePerStepEventPayload {
        return BASNativeStagePerStepEventPayload(
            turnID: turnID,
            stageRawValue: record.stageRawValue,
            stepSequenceIndex: stepSequenceIndex,
            selectedBackingKindRawValue:
                record.selectedBackingKindRawValue,
            selectedKernelKeyDescriptor:
                record.selectedKernelKeyDescriptor,
            durationMs: record.durationMs,
            honoredAssignment: record.honoredAssignment,
            assignmentRationaleRawValue:
                assignmentRationaleRawValue)
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a per-stage-
    /// step dispatch payload。
    public static func nativeStagePerStepEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASNativeStagePerStepEventPayload,
        source: String? = "native-stage-executor"
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
                    .nativeStagePerStep.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the
    /// `BASNativeStagePerStepEventPayload` if this
    /// entry is a native-stage per-step event。
    public var nativeStagePerStepEventPayload:
        BASNativeStagePerStepEventPayload?
    {
        guard hasPayloadKind(.nativeStagePerStep)
        else { return nil }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASNativeStagePerStepEventPayload.self,
            from: data)
    }
}

// MARK: - Projector extension

extension BASEventLogProjectors {

    /// Project the M1153 per-step dispatch payloads
    /// from the input slice in sequence-number-sorted
    /// order。 Sibling to the chapter 439 per-turn
    /// projector;same-turn step events sort by
    /// sequenceNumber within the turn (which mirrors
    /// stepSequenceIndex when emission is monotonic)。
    public static func projectNativeStagePerStepEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASNativeStagePerStepEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.nativeStagePerStep)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.nativeStagePerStepEventPayload
            }
    }
}
