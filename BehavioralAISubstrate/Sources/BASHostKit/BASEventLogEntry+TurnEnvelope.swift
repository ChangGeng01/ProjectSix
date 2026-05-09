// MARK: - BASEventLogEntry+TurnEnvelope
// chapter 四百六 v2 / M995 — 系统熵 reduction
//
// Phase 2 entropy chapter 四百六 v2 third cut:typed extension
// adding `init(turnEnvelope:eventID:source:)` factory on
// BASEventLogEntry and `appendTurnEnvelope(...)` extension on
// any `BASEventLogStorage`。Reduces V2 actor's emission code
// from ~12 lines per envelope to 1 line。
//
// ## Why this exists (system entropy framing)
//
// V2 actor's emit{Start,Complete}Envelope methods construct
// a BASEventLogEntry inline with 9 fields populated from the
// envelope。Repeated boilerplate across both phases。 M995
// extracts the construction into a typed factory + storage
// extension。
//
// ## What this ships
//
//   - `BASEventLogEntry.init(turnEnvelope:eventID:source:)`
//     factory taking a BASTurnRuntimeAuditEnvelope and
//     producing the canonical event-log entry with action
//     tag / payload JSON / memoryRefs all wired correctly
//   - `BASEventLogStorage.appendTurnEnvelope(_:eventID:source:)`
//     async helper that builds the entry + appends it
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四/四百五/四百六 doctrine pins
//   - chapter 二百一一 — single emission pattern for envelopes
//   - chapter 三百九二 — same envelope → same byte-stable entry
//   - ADR-014 OPT-IN — additive

import Foundation
import BASRuntimeCore

extension BASEventLogEntry {

    /// Typed factory constructing a `BASEventLogEntry` from a
    /// V2 runtime envelope。Standardizes the V2 actor's
    /// emission shape — kind: `.substrateAudit`,actions:
    /// `[envelope.eventLogActionTag]`,payloadJson from the
    /// envelope,turnRef from envelope.turnID。
    public init(
        turnEnvelope envelope: BASTurnRuntimeAuditEnvelope,
        eventID: String,
        source: String = "turn-runtime-engine"
    ) {
        self.init(
            eventID: eventID,
            timestampMs: envelope.timestampMs,
            kind: .substrateAudit,
            sessionID: envelope.sessionID,
            sequenceNumber: 0,
            source: source,
            turnRef: envelope.turnID,
            actions: [envelope.eventLogActionTag],
            payloadJson: envelope.payloadJson)
    }
}

extension BASEventLogStorage {

    /// Convenience helper: build a typed event-log entry from
    /// the envelope and append it。Fire-and-forget;errors
    /// are silently dropped (V2 actor adopts the
    /// fire-and-forget contract for envelope emission so a
    /// transient log error doesn't fail the turn)。
    public func appendTurnEnvelope(
        _ envelope: BASTurnRuntimeAuditEnvelope,
        eventID: String,
        source: String = "turn-runtime-engine"
    ) async {
        let entry = BASEventLogEntry(
            turnEnvelope: envelope,
            eventID: eventID,
            source: source)
        _ = try? await self.append(entry)
    }
}
