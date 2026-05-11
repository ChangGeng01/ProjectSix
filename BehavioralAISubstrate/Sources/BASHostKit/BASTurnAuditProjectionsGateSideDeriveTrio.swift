// MARK: - BASTurnAuditProjectionsGateSideDeriveTrio
// chapter 五百六 / M1403 — gate-side derive trio fold
//
// Folds 3 ForGate declarations + their inline derive
// calls (lines 1033-1060 in V1 monolith) into a single
// typed factory:
//
//   - abyssalPressureForGate (BASAbyssalPressureBudget
//     via .derive)
//   - humanAnchorSignalForGate (BASHumanAnchorSignal
//     via BASHumanAnchorProtocol.derive)
//   - unknownReserveForGate (BASUnknownReserve via
//     .derive)
//
// All three are INDEPENDENT derives at the same point in
// the coordinator pipeline — none depends on the others'
// outputs。 Safe to consolidate via shadow-rebinding
// pattern (matches chapter 478 PILOT)。
//
// HONEST SCOPE — chapter 五百六:
// =============================================================
// V1 byte-equality preserved via shadow-rebinding +
// identical compute order。 Stress-sweep dual mode
// canonical60 regression-guards the splice。

import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// Typed bundle holding 3 gate-side derive projections
/// from EBrainRuntimeCoordinator.runTurn(_:) at chapter
/// 506。
public struct BASTurnAuditProjectionsGateSideDeriveTrio:
    Hashable, Sendable
{

    /// L4 abyssal-pressure-budget derive for gate-side
    /// escalation。
    public let abyssalPressure: BASAbyssalPressure

    /// L5 human-anchor-signal derive for gate-side
    /// escalation。
    public let humanAnchorSignal: BASHumanAnchorSignal

    /// L4 unknown-reserve derive for gate-side
    /// assertion-ceiling cap。
    public let unknownReserve: BASUnknownReserve

    public init(
        abyssalPressure: BASAbyssalPressure,
        humanAnchorSignal: BASHumanAnchorSignal,
        unknownReserve: BASUnknownReserve
    ) {
        self.abyssalPressure = abyssalPressure
        self.humanAnchorSignal = humanAnchorSignal
        self.unknownReserve = unknownReserve
    }

    // MARK: - Static factory

    /// Compute all 3 typed gate-side derives in the SAME
    /// ORDER the coordinator monolith did (lines 1033-
    /// 1060 at chapter 505 baseline)。 Byte-equal by
    /// construction when consumed via shadow-rebinding。
    public static func compute(
        sessionID: String,
        hostID: String,
        riskLevel: BASBrainRiskLevel,
        permitMode: BASActionPermitMode,
        candidateCount: Int,
        uncertaintyLedger:
            BASUncertaintyLedger?,
        evidenceDebtCount: Int,
        defaultConfidenceFloorWhenNoUncertaintyLedger:
            Double
    ) -> BASTurnAuditProjectionsGateSideDeriveTrio {
        // Order matches coordinator lines 1033-1060。
        // Do NOT reorder — chapter 三百九二 replay-
        // determinism + V1 byte-equality both depend
        // on identical compute sequence。
        let abyssalPressure = BASAbyssalPressureBudget
            .derive(
                turnID: sessionID,
                riskLevel: riskLevel,
                uncertaintyLedger: uncertaintyLedger,
                evidenceDebtCount: evidenceDebtCount)
        let humanAnchorSignal = BASHumanAnchorProtocol
            .derive(
                anchorID:
                    "human-anchor-\(sessionID)",
                hostSummaryRef: hostID,
                riskLevel: riskLevel,
                permitMode: permitMode,
                candidateCount: candidateCount)
        let unknownReserve = BASUnknownReserve.derive(
            reserveID:
                "unknown-reserve-\(sessionID)",
            confidenceFloor: uncertaintyLedger?
                .confidenceFloor
                ?? defaultConfidenceFloorWhenNoUncertaintyLedger)
        return BASTurnAuditProjectionsGateSideDeriveTrio(
            abyssalPressure: abyssalPressure,
            humanAnchorSignal: humanAnchorSignal,
            unknownReserve: unknownReserve)
    }
}
