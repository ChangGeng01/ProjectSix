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
import BASOrchestration

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

    /// chapter 四百六 v2 / M996 — count of escalation stages
    /// that FIRED during the M384/M385/M406/M449/M450
    /// permit-escalation chain。 0 when no permit ledger was
    /// supplied OR when all 5 stages were identity-pass。
    /// Audit consumers grep this to filter turns where the
    /// composition entropy chain ran live。
    public let permitEscalationFiredStageCount: Int

    /// chapter 四百八 / M1004 — V2 stage execution metrics
    /// from the M1003 BASTurnRuntimeStageLedger。 0 fields
    /// when no stage ledger supplied (V1 delegation path)。
    public let stageCount: Int
    public let failedStageCount: Int
    public let totalStageDurationMs: Int

    /// chapter 四百九 / M1008 — V2 stage plan summary from
    /// the M1006 BASTurnRuntimeStagePlan + M1007 validation。
    /// 0 fields when no plan supplied (V1 delegation path)。
    /// Audit consumers grep `stagePlanIsCanonical == false`
    /// to filter turns running degraded plan variants。
    public let stagePlanStepCount: Int
    public let stagePlanIsCanonical: Bool

    /// chapter 四百十六 / M1034 — per-parallel-group dispatch
    /// summaries derived from the M1003 stage ledger via
    /// the M1032 .parallelDispatchSummaries() extension。
    /// Empty array when no stage ledger supplied (V1
    /// delegation path) OR when ledger has no fan-out
    /// records。 Audit consumers grep this for fan-out
    /// performance:max-of-N stage durations dominate fan-
    /// out wall-clock,sum-of-N is cost-accounting。
    public let parallelDispatchSummaries:
        [BASParallelStageDispatchSummary]

    // MARK: - Init

    public init(
        traceID: String,
        verdictLevelRaw: String,
        permitModeRaw: String,
        ticketCount: Int,
        auditID: String,
        runMode: String,
        auditProjectionsPopulatedSlotCount: Int = 0,
        permitEscalationFiredStageCount: Int = 0,
        stageCount: Int = 0,
        failedStageCount: Int = 0,
        totalStageDurationMs: Int = 0,
        stagePlanStepCount: Int = 0,
        stagePlanIsCanonical: Bool = false,
        parallelDispatchSummaries:
            [BASParallelStageDispatchSummary] = []
    ) {
        self.traceID = traceID
        self.verdictLevelRaw = verdictLevelRaw
        self.permitModeRaw = permitModeRaw
        self.ticketCount = max(0, ticketCount)
        self.auditID = auditID
        self.runMode = runMode
        self.auditProjectionsPopulatedSlotCount =
            max(0, auditProjectionsPopulatedSlotCount)
        self.permitEscalationFiredStageCount =
            max(0, permitEscalationFiredStageCount)
        self.stageCount = max(0, stageCount)
        self.failedStageCount = max(0, failedStageCount)
        self.totalStageDurationMs =
            max(0, totalStageDurationMs)
        self.stagePlanStepCount = max(0, stagePlanStepCount)
        self.stagePlanIsCanonical = stagePlanIsCanonical
        self.parallelDispatchSummaries =
            parallelDispatchSummaries
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

    // MARK: - chapter 四百六 / M993 — typed factory

    /// Build a summary from a V1 `BASEBrainTurnResult` + an
    /// optional `BASRuntimeAuditProjectionsBundle` + optional
    /// `BASPermitEscalationLedger`。 Pure function;same input
    /// → same summary (chapter 三百九二)。 V2 actor emission
    /// code drops from ~12 lines to 1 call。
    public static func from(
        result: BASEBrainTurnResult,
        auditProjections:
            BASRuntimeAuditProjectionsBundle? = nil,
        permitEscalationLedger:
            BASPermitEscalationLedger? = nil,
        stageLedger:
            BASTurnRuntimeStageLedger? = nil,
        stagePlan:
            BASTurnRuntimeStagePlan? = nil
    ) -> BASRuntimeAuditEmissionSummary {
        BASRuntimeAuditEmissionSummary(
            traceID: result.runtimeTrace.sessionID,
            verdictLevelRaw:
                result.sovereignVerdict?
                    .verdictLevel.rawValue ?? "unassigned",
            permitModeRaw:
                result.actionPermit.mode.rawValue,
            ticketCount: result.updateTickets.count,
            auditID:
                result.sovereignAuditEntry?
                    .auditID ?? "unassigned",
            runMode: result.budgetFrame.runMode.rawValue,
            auditProjectionsPopulatedSlotCount:
                auditProjections?.populatedSlotCount ?? 0,
            permitEscalationFiredStageCount:
                permitEscalationLedger?
                    .firedStageCount ?? 0,
            stageCount:
                stageLedger?.stageCount ?? 0,
            failedStageCount:
                stageLedger?.failedStageCount ?? 0,
            totalStageDurationMs:
                stageLedger?.totalDurationMs ?? 0,
            stagePlanStepCount:
                stagePlan?.stepCount ?? 0,
            stagePlanIsCanonical:
                stagePlan?.isCanonical ?? false,
            parallelDispatchSummaries:
                stageLedger?
                    .parallelDispatchSummaries() ?? [])
    }
}
