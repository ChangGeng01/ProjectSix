// MARK: - BASTurnLifecycleEventPayload — chapter 四百二十八 / M1085
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B 第二刀。 Typed Codable
// payload that lets the V2 runtime engine's per-turn
// `BASTurnRuntimeAuditEnvelope.start` / `.complete`
// envelopes flow through the unified `BASEventLog` instead
// of the separate audit-emission channel they own today。
//
// ## Why this exists (system entropy framing)
//
// Pre-M1085 the V2 engine emits turn lifecycle envelopes
// via `BASEventLogStorage.appendTurnEnvelope(...)` (M995),
// which encodes the envelope into a typed
// `BASEventLogEntry` wired with `kind: .substrateAudit`。
// The envelope's `payloadJson` carries an UNTYPED JSON
// shape derived from `BASRuntimeAuditEmissionSummary` —
// downstream consumers must JSON-decode the free-form
// shape with no compile-time guidance。
//
// `BASTurnLifecycleEventPayload` is the typed Codable
// shape the M995 path SHOULD have shipped。 It encodes:
//   - phase (start / complete)
//   - turn / session / sequence identity
//   - permit-fired-stage count (mirrors what the
//     M996 `BASRuntimeAuditEmissionSummary` already
//     surfaces)
//   - stage execution count + total ms (mirrors the
//     M1004 `BASTurnRuntimeStageLedger` projection)
//   - canonical-plan flag (mirrors the M1008
//     `BASTurnRuntimeStagePlan` projection)
//
// Downstream consumers (Phase E scheduler probe,future
// SSM training,causal graph extraction) decode the
// typed payload directly — no more free-form JSON
// guesswork。
//
// ## What this ships (M1085)
//
//   - `BASTurnLifecyclePhase` enum (mirrors
//     `BASTurnRuntimeAuditEnvelope.Phase` so callers
//     can switch consumers without re-encoding)
//   - `BASTurnLifecycleEventPayload` Sendable + Codable
//     + Equatable + Hashable struct (8 fields)
//   - `BASEventLogEntry` extension factory
//     `turnLifecycleEvent(...)` + reverse accessor
//     `turnLifecycleEventPayload`
//   - Discriminator action tag matches
//     `BASEventPayloadKind.turnLifecycle.rawValue` so
//     the M1084 filter scan finds it。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     phase enum + named fields)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape;projector M1087 consumes this
//     same shape rather than re-decoding free-form
//     JSON)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payload + extension;no existing call
//     site touched)
//   - 红线 7 — hint-only (event log is observation,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

// MARK: - Phase enum (mirrors BASTurnRuntimeAuditEnvelope.Phase)

/// Typed phase discriminator for turn lifecycle events。
/// Mirrors `BASTurnRuntimeAuditEnvelope.Phase` so callers
/// can switch payload consumers without re-encoding。
public enum BASTurnLifecyclePhase:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Turn began (envelope emitted before any servicing
    /// or after V1's IDs are derived,depending on
    /// engine version)。
    case start = "start"

    /// Turn completed (envelope emitted after V1 returns,
    /// payload carries the audit summary projections)。
    case complete = "complete"
}

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a turn lifecycle envelope。
public struct BASTurnLifecycleEventPayload:
    Codable, Equatable, Sendable, Hashable
{

    /// Lifecycle phase for this entry。
    public let phase: BASTurnLifecyclePhase

    /// Turn ID this entry binds to。 Mirrors the
    /// `BASTurnRuntimeAuditEnvelope.turnID` field。
    public let turnID: String

    /// Session ID this entry binds to。
    public let sessionID: String

    /// Sequence number assigned by the engine actor on
    /// emission。 Replay relies on this for stable
    /// start-before-complete ordering per turn。
    public let sequenceNumber: Int

    /// Number of escalation stages fired during the
    /// turn (M996 BASPermitEscalationLedger projection)。
    /// Always 0 on `.start` payloads;populated on
    /// `.complete`。
    public let firedEscalationStageCount: Int

    /// Number of stages observed in the turn's stage
    /// ledger (M1004 BASTurnRuntimeStageLedger
    /// projection)。 0 on `.start`,populated on
    /// `.complete`。
    public let observedStageCount: Int

    /// Number of stages observed in the turn's stage
    /// plan (M1008 BASTurnRuntimeStagePlan projection)。
    /// 0 if no plan threaded through。
    public let stagePlanStepCount: Int

    /// Whether the stage plan was the canonical 18-stage
    /// plan (M1008 projection)。 false if a custom plan
    /// or no plan threaded through。
    public let stagePlanIsCanonical: Bool

    public init(
        phase: BASTurnLifecyclePhase,
        turnID: String,
        sessionID: String,
        sequenceNumber: Int,
        firedEscalationStageCount: Int = 0,
        observedStageCount: Int = 0,
        stagePlanStepCount: Int = 0,
        stagePlanIsCanonical: Bool = false
    ) {
        self.phase = phase
        self.turnID = turnID
        self.sessionID = sessionID
        self.sequenceNumber = sequenceNumber
        self.firedEscalationStageCount =
            firedEscalationStageCount
        self.observedStageCount = observedStageCount
        self.stagePlanStepCount = stagePlanStepCount
        self.stagePlanIsCanonical = stagePlanIsCanonical
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a turn
    /// lifecycle payload。 Caller passes 0 for
    /// `sequenceNumber` — storage assigns the actual
    /// sequence on append。
    ///
    /// Encodes the typed payload into `payloadJson` via
    /// JSONEncoder with sorted-keys output (chapter
    /// 三百九二 byte-stability)。
    public static func turnLifecycleEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASTurnLifecycleEventPayload,
        source: String? = "turn-runtime-engine",
        turnRef: String? = nil
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
            turnRef: turnRef ?? payload.turnID,
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
                    .turnLifecycle.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASTurnLifecycleEventPayload` if this
    /// entry is a turn lifecycle event。 Returns nil
    /// for entries that aren't turn lifecycle events
    /// or whose payload is malformed。
    public var turnLifecycleEventPayload:
        BASTurnLifecycleEventPayload?
    {
        guard hasPayloadKind(.turnLifecycle) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASTurnLifecycleEventPayload.self,
            from: data)
    }
}
