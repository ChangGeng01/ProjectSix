// MARK: - BASNativeStageDispatchEventPayload
// chapter 四百三十九 / M1132 — POST-RADICAL Wave 10
//
// Typed Codable payload that lets the chapter 436
// `BASNativeStageDispatchLedger` flow through the
// chapter 428 unified event log。 Bridges the chapter
// 437 + 438 end-to-end routed dispatch path with
// Phase B's typed event-payload backbone so dispatch
// decisions become replay-able events。
//
// ## Why this exists (system entropy framing)
//
// chapters 435-438 shipped end-to-end scheduler-driven
// dispatch:
//   - chapter 435 captures `BASTurnRuntimePlan
//     AssignmentLedger` (decisions captured)
//   - chapter 436 ships `BASNativeStageDispatchLedger`
//     (decisions honored at executor)
//   - chapter 437 wires engine → delegate → executor
//     end-to-end
//   - chapter 438 adds host-injection seam
//
// But the dispatch ledger lives ONLY in `BASTurnRuntime
// Engine.lastDispatchLedger` actor-isolated state。
// Future replay (G8 SSM training,causal graph
// extraction,distributed audit) cannot reconstruct
// dispatch decisions from the event stream because
// they aren't on the stream。
//
// `BASNativeStageDispatchEventPayload` is the typed
// payload that puts dispatch decisions ON the event
// stream。 Combined with the M1087 BASEventLogProjectors
// pattern,downstream replay can reconstruct the
// `BASNativeStageDispatchLedger` from
// `[BASEventLogEntry]` alone。
//
// ## What this ships (M1132-M1133)
//
//   - `BASNativeStageDispatchEventPayload` Sendable +
//     Codable + Equatable + Hashable struct (5 fields:
//     turnID + records (mirror of execution records) +
//     executionCount + honoredAssignmentCount +
//     unhonoredAssignmentCount + totalDurationMs)
//   - `BASNativeStageDispatchEventRecord` Sendable +
//     Codable + Equatable + Hashable struct (5 fields:
//     stageRawValue + selectedBackingKindRawValue +
//     selectedKernelKeyDescriptor + durationMs +
//     honoredAssignment Bool)
//   - `.from(ledger:turnID:)` factory bridges the
//     in-memory ledger to the typed payload
//   - `BASEventLogEntry.nativeStageDispatchEvent(...)`
//     factory
//   - `BASEventLogEntry.nativeStageDispatchEventPayload`
//     reverse accessor
//   - Discriminator action tag matches
//     `BASEventPayloadKind.nativeStageDispatch.rawValue`
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     stage rawvalue + named typed aggregates;no raw
//     String dispatch tags)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape;tests + audit + future replay
//     rebuilders all consume the same shape)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;sequenceIndex preserves
//     order;ledger → payload → ledger round-trip is
//     byte-stable)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payload + extension;no existing call
//     site touched)
//   - 红线 7 — hint-only (event log is observation,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

// MARK: - Per-record event payload mirror

/// Typed Codable + Sendable mirror of
/// `BASNativeStageExecutionRecord` for event-log
/// round-trip。 The legacy struct holds nested typed
/// `BASStageAcceleratorAssignment?`;the event-log
/// shape carries selectedBackingKindRawValue +
/// selectedKernelKeyDescriptor as wire-friendly
/// String fields。
public struct BASNativeStageDispatchEventRecord:
    Equatable, Hashable, Codable, Sendable
{

    /// Stage rawvalue (matches `BASTurnRuntimeStage.rawValue`)。
    public let stageRawValue: String

    /// `BASTensorBackingKind.rawValue` when assignment
    /// honored;`""` (empty string) when stage fell
    /// through to fallback executor (no assignment)。
    public let selectedBackingKindRawValue: String

    /// `BASKernelKey.wireFormIdentifier` when
    /// assignment had a kernel key;`""` when CPU
    /// fallback or no assignment。
    public let selectedKernelKeyDescriptor: String

    /// Wall-clock duration of the stage execution in
    /// milliseconds。
    public let durationMs: Int

    /// Whether the executor honored a registered
    /// assignment for this stage。
    public let honoredAssignment: Bool

    public init(
        stageRawValue: String,
        selectedBackingKindRawValue: String,
        selectedKernelKeyDescriptor: String,
        durationMs: Int,
        honoredAssignment: Bool
    ) {
        self.stageRawValue = stageRawValue
        self.selectedBackingKindRawValue =
            selectedBackingKindRawValue
        self.selectedKernelKeyDescriptor =
            selectedKernelKeyDescriptor
        self.durationMs = max(0, durationMs)
        self.honoredAssignment = honoredAssignment
    }
}

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a native-stage dispatch ledger summary。
public struct BASNativeStageDispatchEventPayload:
    Equatable, Hashable, Codable, Sendable
{

    /// Turn ID this entry binds to。
    public let turnID: String

    /// Per-stage records mirror of
    /// `BASNativeStageDispatchLedger.records`。
    public let records:
        [BASNativeStageDispatchEventRecord]

    /// Pre-computed at emit time so consumers don't
    /// need to re-scan `records`。 Mirrors
    /// `BASNativeStageDispatchLedger.executionCount`。
    public let executionCount: Int

    /// Mirrors `BASNativeStageDispatchLedger
    /// .honoredAssignmentCount`。
    public let honoredAssignmentCount: Int

    /// Mirrors `BASNativeStageDispatchLedger
    /// .unhonoredAssignmentCount`。
    public let unhonoredAssignmentCount: Int

    /// Mirrors `BASNativeStageDispatchLedger
    /// .totalDurationMs`。
    public let totalDurationMs: Int

    public init(
        turnID: String,
        records: [BASNativeStageDispatchEventRecord],
        executionCount: Int,
        honoredAssignmentCount: Int,
        unhonoredAssignmentCount: Int,
        totalDurationMs: Int
    ) {
        self.turnID = turnID
        self.records = records
        self.executionCount = max(0, executionCount)
        self.honoredAssignmentCount =
            max(0, honoredAssignmentCount)
        self.unhonoredAssignmentCount =
            max(0, unhonoredAssignmentCount)
        self.totalDurationMs = max(0, totalDurationMs)
    }

    /// Convenience:build the payload from a typed
    /// `BASNativeStageDispatchLedger` value。 Used by
    /// callers that want to emit the same ledger shape
    /// through both the in-memory channel + the new
    /// event-log channel during the migration window。
    public static func from(
        ledger: BASNativeStageDispatchLedger,
        turnID: String
    ) -> BASNativeStageDispatchEventPayload {
        let records = ledger.records.map { rec in
            BASNativeStageDispatchEventRecord(
                stageRawValue: rec.stageRawValue,
                selectedBackingKindRawValue:
                    rec.assignment?.selectedBackingKind
                        .rawValue ?? "",
                selectedKernelKeyDescriptor:
                    rec.assignment?.selectedKernelKey?
                        .wireFormIdentifier ?? "",
                durationMs: rec.durationMs,
                honoredAssignment: rec.honoredAssignment)
        }
        return BASNativeStageDispatchEventPayload(
            turnID: turnID,
            records: records,
            executionCount: ledger.executionCount,
            honoredAssignmentCount:
                ledger.honoredAssignmentCount,
            unhonoredAssignmentCount:
                ledger.unhonoredAssignmentCount,
            totalDurationMs: ledger.totalDurationMs)
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a native-
    /// stage dispatch ledger payload。
    public static func nativeStageDispatchEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASNativeStageDispatchEventPayload,
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
                    .nativeStageDispatch.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASNativeStageDispatchEventPayload`
    /// if this entry is a native-stage dispatch event。
    public var nativeStageDispatchEventPayload:
        BASNativeStageDispatchEventPayload?
    {
        guard hasPayloadKind(.nativeStageDispatch) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASNativeStageDispatchEventPayload.self,
            from: data)
    }
}

// MARK: - Projector extension

extension BASEventLogProjectors {

    /// Project the M1132 native-stage dispatch payloads
    /// from the input slice in sequence-number-sorted
    /// order。 Sibling to the 4 chapter 428 projectors。
    public static func projectNativeStageDispatchEvents(
        _ entries: [BASEventLogEntry]
    ) -> [BASNativeStageDispatchEventPayload] {
        return entries
            .filter {
                $0.hasPayloadKind(.nativeStageDispatch)
            }
            .sorted {
                $0.sequenceNumber < $1.sequenceNumber
            }
            .compactMap {
                $0.nativeStageDispatchEventPayload
            }
    }
}
