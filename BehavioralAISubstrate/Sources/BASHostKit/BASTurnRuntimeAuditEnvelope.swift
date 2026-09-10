// MARK: - BASTurnRuntimeAuditEnvelope — chapter 四百四 / M963
// 系统熵 reduction 第二章 第一刀
//
// Phase 2 entropy chapter 四百四 entry — single audit channel
// for V2 actor's runTurn rewrite。Pins the M932
// `BASLLMExtractionEngine` start/complete event-emission
// pattern as a typed primitive that V2 actor stages will
// adopt。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit:
//
//   > Audit-projection entropy: 67 distinct *ForAudit /
//   > *ForGate locals scattered across 1850 LOC of runTurn。
//   > V1 has no per-turn lifecycle channel comparable to
//   > M932's llm-engine:start / llm-engine:complete event
//   > pair。Adding it would set up V2 actor to centralize
//   > audit emission。
//
// V1 runTurn does NOT emit `turn:start` / `turn:complete`
// lifecycle events on the event log。M932 LLM Extraction
// Engine does — proven pattern。M963 ports the pattern as
// a typed envelope V2 actor adopts directly。
//
// ## What this ships
//
//   - `BASTurnRuntimeAuditEnvelope` Codable Sendable struct
//   - `Phase` enum: `.start` / `.complete`
//   - `payloadJson` field for stable JSON summary on
//     `.complete`(verdictID + verdictLevel + permitMode +
//     ticketCount + auditID + traceID — sorted-key encoding
//     for byte-stable replay per M892)
//   - Convenience init for each phase
//
// ## Doctrine pins held
//
//   - All chapter 四百三 doctrine pins
//   - chapter 一百八十五 anti-magic-number — phase enum + key
//     constants typed
//   - chapter 三百九二 replay-determinism — sorted-key JSON
//     encoding pinned
//   - ADR-014 OPT-IN — V1 runTurn untouched;V2 actor adopts

import Foundation

/// Typed envelope for V2 runtime engine's per-turn lifecycle
/// audit emission。Each turn produces ONE `.start` envelope
/// and ONE `.complete` envelope on the wired event log。
public struct BASTurnRuntimeAuditEnvelope:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Phase

    /// 2-case typed phase。Each turn emits both phases
    /// exactly once。
    public enum Phase: String, Codable, Sendable,
        Equatable, Hashable, CaseIterable
    {
        /// Emitted at the very top of `runTurn`,before any
        /// servicing。Pins the turn's identity and inputs。
        case start
        /// Emitted after the result is fully assembled,just
        /// before return。Pins the verdict + permit + audit
        /// summary。
        case complete
    }

    // MARK: - Required identity

    public let phase: Phase
    public let turnID: String
    public let sessionID: String
    public let timestampMs: Int64
    public let sequenceNumber: Int

    // MARK: - Optional payload

    /// Stable JSON summary of the turn's outputs (typically
    /// only populated on `.complete`)。Encoded with
    /// sorted-keys output formatting per M892 byte-stability。
    public let payloadJson: String?

    // MARK: - Init

    public init(
        phase: Phase,
        turnID: String,
        sessionID: String,
        timestampMs: Int64,
        sequenceNumber: Int,
        payloadJson: String? = nil
    ) {
        self.phase = phase
        self.turnID = turnID
        self.sessionID = sessionID
        self.timestampMs = timestampMs
        self.sequenceNumber = sequenceNumber
        self.payloadJson = payloadJson
    }

    // MARK: - Convenience constructors

    /// Build a `.start` envelope at the top of runTurn。
    public static func start(
        turnID: String,
        sessionID: String,
        timestampMs: Int64,
        sequenceNumber: Int = 0
    ) -> BASTurnRuntimeAuditEnvelope {
        BASTurnRuntimeAuditEnvelope(
            phase: .start,
            turnID: turnID,
            sessionID: sessionID,
            timestampMs: timestampMs,
            sequenceNumber: sequenceNumber)
    }

    /// Build a `.complete` envelope after result assembly。
    public static func complete(
        turnID: String,
        sessionID: String,
        timestampMs: Int64,
        sequenceNumber: Int = 1,
        payloadJson: String? = nil
    ) -> BASTurnRuntimeAuditEnvelope {
        BASTurnRuntimeAuditEnvelope(
            phase: .complete,
            turnID: turnID,
            sessionID: sessionID,
            timestampMs: timestampMs,
            sequenceNumber: sequenceNumber,
            payloadJson: payloadJson)
    }

    // MARK: - chapter 一百八十五 anti-magic-number — eventID prefix

    /// Stable eventID prefix used by V2 actor when appending
    /// these envelopes to a `BASEventLogStorage`。Format:
    /// `turn-<phase>-<sessionID>-<timestampMs>-<sequenceNumber>`
    /// (per M940 collision-fix pattern in M932 LLM Engine)。
    public var eventIDSuggestion: String {
        "turn-\(phase.rawValue)-\(sessionID)-" +
        "\(timestampMs)-\(sequenceNumber)"
    }

    // MARK: - chapter 四百六 v2 / M994 — typed action tag

    /// chapter 一百八十五 anti-magic-number — typed prefix for
    /// the canonical action tag this envelope appends to
    /// `BASEventLogEntry.actions` when V2 actor writes it to
    /// the event log。Pinned constant so audit consumers can
    /// grep without assuming string format。
    public static let eventLogActionTagPrefix: String = "turn-"

    /// Canonical action tag string for this envelope's phase。
    /// `.start` → `"turn-start"`,`.complete` → `"turn-complete"`。
    /// V2 actor uses this accessor instead of inlining the
    /// strings (chapter 一百八十五)。 Audit consumers grep these
    /// tags to filter event-log entries for V2 lifecycle
    /// events。
    public var eventLogActionTag: String {
        BASTurnRuntimeAuditEnvelope
            .eventLogActionTagPrefix +
            phase.rawValue
    }
}
