// MARK: - BASRuntimeAuditEmissionSummary
// chapter 四百四 / M967 — 系统熵 reduction 第二章 第五刀
//
// Phase 2 entropy chapter 四百四 fifth cut:typed payload
// summary that V2 actor's `.complete` BASTurnRuntimeAuditEnvelope
// serializes into its `payloadJson` field。Ports the M932 LLM
// Engine's complete-event payload pattern (verdictID +
// verdictLevel + ticketCount + auditID + traceID) to the V2
// runtime engine surface。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit:
//
//   > V1 runTurn has 67 *ForAudit locals scattered across
//   > 1850 LOC。 V2 actor centralizes them into typed
//   > namespace structs (kunlun / abyssal / etc.)。Final
//   > emission collapses to a single audit envelope with
//   > stable JSON summary。
//
// `BASRuntimeAuditEmissionSummary` is the typed JSON shape
// the `.complete` envelope serializes。Stable sorted-keys
// encoding pins M892 byte-stability。Future V2 actor stages
// populate this struct from their accumulated frame builder。
//
// ## What this ships (M967)
//
//   - `BASRuntimeAuditEmissionSummary` Codable Sendable
//     Equatable struct with 6 typed fields:
//       * traceID
//       * verdictLevelRaw
//       * permitModeRaw
//       * ticketCount
//       * auditID
//       * runMode
//   - `payloadJson()` method producing the sorted-keys
//     stable JSON string ready for `BASTurnRuntimeAuditEnvelope
//     .payloadJson`
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四 doctrine pins
//   - chapter 一百八十五 anti-magic-number — field names typed
//   - chapter 三百九二 (M892) replay-determinism — sorted-key
//     encoding produces byte-stable JSON for same input
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed payload struct that V2 actor's complete-envelope
/// serializes。Mirrors M932 LLM Engine's complete-event
/// pattern。
public struct BASRuntimeAuditEmissionSummary:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Required fields

    /// Stable trace identifier joining this turn's audit
    /// rows together (same as runtime trace's sessionID-
    /// derived turnID per M953/M954)。
    public let traceID: String

    /// Sovereign verdict level (raw string per
    /// `BASSovereignVerdictLevel.rawValue` typed enum)。
    public let verdictLevelRaw: String

    /// Final permit mode (raw string per
    /// `BASActionPermitMode.rawValue` typed enum)。
    public let permitModeRaw: String

    /// Number of update tickets emitted this turn。
    public let ticketCount: Int

    /// Stable audit ID assigned by L14 sovereign verdict
    /// path (chapter 一百三 schema-versioned ID)。
    public let auditID: String

    /// Run mode this turn executed in (raw string per
    /// `BASEBrainRunMode.rawValue`)。
    public let runMode: String

    /// chapter 四百六 / M989 — count of populated audit-
    /// projection slots across the V2 aggregator bundle (kunlun
    /// + abyssal + cthulhu + tribunal + riskCalibration)。 0
    /// when no aggregator was supplied or all namespaces empty。
    public let auditProjectionsPopulatedSlotCount: Int

    // MARK: - Init

    public init(
        traceID: String,
        verdictLevelRaw: String,
        permitModeRaw: String,
        ticketCount: Int,
        auditID: String,
        runMode: String,
        auditProjectionsPopulatedSlotCount: Int = 0
    ) {
        self.traceID = traceID
        self.verdictLevelRaw = verdictLevelRaw
        self.permitModeRaw = permitModeRaw
        self.ticketCount = max(0, ticketCount)
        self.auditID = auditID
        self.runMode = runMode
        self.auditProjectionsPopulatedSlotCount =
            max(0, auditProjectionsPopulatedSlotCount)
    }

    // MARK: - Stable JSON encoding

    /// Produce the sorted-keys JSON string ready to populate
    /// `BASTurnRuntimeAuditEnvelope.payloadJson` on the
    /// `.complete` event。Returns nil only if encoding fails
    /// (should never happen for this Codable struct;included
    /// for defensive symmetry)。
    ///
    /// Replay-determinism (chapter 三百九二):same input fields
    /// → same output JSON bytes via `.sortedKeys` formatting。
    public func payloadJson() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
