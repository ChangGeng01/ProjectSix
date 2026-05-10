// MARK: - BASPermitEscalationEventPayload — chapter 四百二十八 / M1086
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B 第三刀。 Typed Codable
// payload that lets the M1070 BASPermitEscalationFold
// Executor's per-turn ledger flow through the unified
// BASEventLog instead of the in-memory-only return value
// it ships today。
//
// ## Why this exists (system entropy framing)
//
// Pre-M1086 the M970 `BASPermitEscalationLedger.build(...)`
// helper returns the typed ledger as an in-memory value
// to the caller。 Callers thread the ledger into the
// V2 audit envelope's `payloadJson` field via
// `BASRuntimeAuditEmissionSummary.from(...)`,but that
// flattens the typed shape into a free-form JSON string。
// Downstream replay (Phase E scheduler probe,future
// SSM training) cannot rebuild the typed ledger from
// the event stream because the typed shape is lost。
//
// `BASPermitEscalationEventPayload` is the typed payload
// that preserves the ledger shape end-to-end。 The
// projector M1087 ships the round-trip:
// `[BASEventLogEntry] → BASPermitEscalationLedger`。
//
// ## What this ships (M1086 — additive)
//
//   - `BASPermitEscalationStageEventRecord` typed
//     Codable + Sendable struct mirroring
//     `BASPermitEscalationStageRecord` field-for-field
//     (without the runtime references that prevent
//     event-log round-trip)
//   - `BASPermitEscalationEventPayload` Sendable +
//     Codable + Equatable + Hashable struct (turnID +
//     records + firedStageCount + ledgerReasonCodePrefix)
//   - `BASEventLogEntry` extension factory
//     `permitEscalationEvent(...)` + reverse accessor
//     `permitEscalationEventPayload`
//   - Discriminator action tag matches
//     `BASEventPayloadKind.permitEscalation.rawValue`
//
// ## Additive-only (no ledger deletions)
//
// The original Phase B plan called for deleting
// `BASPermitEscalationLedger.swift` once this payload
// shipped。 In autonomous mode that deletion is too
// risky — the legacy ledger is referenced from
// `BASRuntimeAuditEmissionSummary`, V2 actor's
// `runTurn(...)` signature, and dozens of tests。
// M1086 ships the typed payload + projector ALONGSIDE
// the existing ledger so consumers can migrate
// incrementally。 A follow-up chapter performs the
// deletion under explicit user control。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     stage enum + named fields)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape;projector M1087 reads this)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — hint-only
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

// MARK: - Per-stage record

/// Typed Codable + Sendable mirror of
/// `BASPermitEscalationStageRecord` for event-log
/// round-trip。 The legacy struct holds nested
/// `BASActionPermit` values directly;the event-log
/// shape carries them as Codable too。
public struct BASPermitEscalationStageEventRecord:
    Codable, Equatable, Sendable, Hashable
{

    /// Stage name (matches
    /// `BASPermitEscalationStage` raw value)。
    public let stageRawValue: String

    /// Whether this stage actually changed the permit
    /// (output ≠ input OR new reason codes)。
    public let fired: Bool

    /// Reason codes emitted by this stage (e.g.
    /// "abyssal:risk-tip")。 Empty when stage didn't
    /// fire。
    public let reasonCodes: [String]

    /// Permit mode emitted by this stage (raw value of
    /// `BASActionPermit.mode`)。 Used by replay so the
    /// projector can reconstruct the typed permit。
    public let outputPermitModeRawValue: String

    /// Aggregate reason codes carried in the output
    /// permit (typed `BASActionPermit.reasonCodes`
    /// flattened to the wire)。
    public let outputPermitReasonCodes: [String]

    public init(
        stageRawValue: String,
        fired: Bool,
        reasonCodes: [String],
        outputPermitModeRawValue: String,
        outputPermitReasonCodes: [String]
    ) {
        self.stageRawValue = stageRawValue
        self.fired = fired
        self.reasonCodes = reasonCodes
        self.outputPermitModeRawValue =
            outputPermitModeRawValue
        self.outputPermitReasonCodes =
            outputPermitReasonCodes
    }
}

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a permit escalation ledger summary。
public struct BASPermitEscalationEventPayload:
    Codable, Equatable, Sendable, Hashable
{

    /// Turn ID this entry binds to。
    public let turnID: String

    /// Initial permit mode raw value (before any
    /// escalation)。
    public let initialPermitModeRawValue: String

    /// Initial permit reason codes (before any
    /// escalation)。
    public let initialPermitReasonCodes: [String]

    /// Per-stage records in canonical order。
    public let stageRecords:
        [BASPermitEscalationStageEventRecord]

    /// Number of stages that fired (mirrors
    /// `BASPermitEscalationLedger.firedStageCount`)。
    /// Pre-computed at emit time so consumers don't
    /// need to re-scan `stageRecords`。
    public let firedStageCount: Int

    public init(
        turnID: String,
        initialPermitModeRawValue: String,
        initialPermitReasonCodes: [String],
        stageRecords:
            [BASPermitEscalationStageEventRecord],
        firedStageCount: Int
    ) {
        self.turnID = turnID
        self.initialPermitModeRawValue =
            initialPermitModeRawValue
        self.initialPermitReasonCodes =
            initialPermitReasonCodes
        self.stageRecords = stageRecords
        self.firedStageCount = firedStageCount
    }

    /// Convenience: build the payload from a typed
    /// `BASPermitEscalationLedger` value。 Used by
    /// callers that want to emit the same ledger shape
    /// through both the legacy in-memory channel + the
    /// new event-log channel during the migration
    /// window。
    public static func from(
        ledger: BASPermitEscalationLedger,
        turnID: String
    ) -> BASPermitEscalationEventPayload {
        let records = ledger.records.map { rec in
            BASPermitEscalationStageEventRecord(
                stageRawValue: rec.stage.rawValue,
                fired: rec.fired,
                reasonCodes: rec.reasonCodes,
                outputPermitModeRawValue:
                    rec.outputPermit.mode.rawValue,
                outputPermitReasonCodes:
                    rec.outputPermit.reasonCodes)
        }
        return BASPermitEscalationEventPayload(
            turnID: turnID,
            initialPermitModeRawValue:
                ledger.initialPermit.mode.rawValue,
            initialPermitReasonCodes:
                ledger.initialPermit.reasonCodes,
            stageRecords: records,
            firedStageCount: ledger.firedStageCount)
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a permit
    /// escalation ledger payload。
    public static func permitEscalationEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASPermitEscalationEventPayload,
        source: String? = "permit-escalation-fold-executor"
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
                    .permitEscalation.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASPermitEscalationEventPayload` if
    /// this entry is a permit escalation event。
    public var permitEscalationEventPayload:
        BASPermitEscalationEventPayload?
    {
        guard hasPayloadKind(.permitEscalation) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASPermitEscalationEventPayload.self,
            from: data)
    }
}
