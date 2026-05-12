// MARK: - BASTurnAuditProjectionsAbyssalThermalTrio
// chapter 五百六 / M1401 — cluster B fold continues
//
// Folds 3 ForAudit declarations + their inline derive
// calls (lines 1169-1185 in V1 monolith) into a single
// typed factory:
//
//   - abyssalRunModeForAudit (BASAbyssalRunMode)
//   - abyssBudgetForAudit (BASAbyssBudget)
//   - memoryTemperatureLayerForAudit
//     (BASMemoryTemperatureLayer)
//
// Each is a pure derive on BASCthulhuLayerProjections。
// Honest scope:matches the chapter 478 BASTurnAudit
// ProjectionsKunlunTrio pattern — typed factory with
// shadow-rebinding preserves byte-equality。
//
// HONEST SCOPE — chapter 五百六:
// =============================================================
// Continues cluster B fold per chapter 492 honest scope
// correction (66 ForAudit declarations remain at chapter
// 494)。 This fold reduces inline-construction LOC + 3
// declarations from the V1 monolith。 V1 byte-equality
// preserved via shadow-rebinding;stress-sweep dual mode
// canonical60 regression guard confirms zero divergence。

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed bundle holding the 3 abyssal+thermal audit
/// projections extracted from EBrainRuntimeCoordinator
/// .runTurn(_:) at chapter 506。 Replaces 3 separate
/// shadow-local `let *ForAudit` declarations with a
/// single typed factory call。
public struct BASTurnAuditProjectionsAbyssalThermalTrio:
    Codable, Hashable, Sendable
{

    /// L1 abyssal-run-mode projection from runMode。
    public let abyssalRunMode: BASAbyssalRunMode

    /// L1 abyss-budget projection from full budget frame
    /// + turnID。
    public let abyssBudget: BASAbyssBudget

    /// L8 memory-temperature-layer projection from
    /// runMode。
    public let memoryTemperatureLayer:
        BASMemoryTemperatureLayer

    public init(
        abyssalRunMode: BASAbyssalRunMode,
        abyssBudget: BASAbyssBudget,
        memoryTemperatureLayer:
            BASMemoryTemperatureLayer
    ) {
        self.abyssalRunMode = abyssalRunMode
        self.abyssBudget = abyssBudget
        self.memoryTemperatureLayer =
            memoryTemperatureLayer
    }

    // MARK: - Static factory

    /// Compute all 3 typed projections in the SAME
    /// ORDER the coordinator monolith did (lines
    /// 1169-1185 at chapter 505 baseline)。 Byte-equal
    /// by construction when consumed via shadow-
    /// rebinding。
    public static func compute(
        routedBudget: BASBudgetFrame,
        turnID: String
    ) -> BASTurnAuditProjectionsAbyssalThermalTrio {
        // Order matches coordinator lines 1169-1185。
        // Do NOT reorder — chapter 三百九二 replay-
        // determinism + V1 byte-equality both depend
        // on identical compute sequence。
        let abyssalRunMode = BASCthulhuLayerProjections
            .AbyssalRunMode
            .derive(from: routedBudget.runMode)
        let abyssBudget = BASCthulhuLayerProjections
            .AbyssBudget
            .derive(
                from: routedBudget,
                turnID: turnID)
        let memoryTemperatureLayer =
            BASCthulhuLayerProjections
                .MemoryTemperatureLayer
                .derive(from: routedBudget.runMode)
        return BASTurnAuditProjectionsAbyssalThermalTrio(
            abyssalRunMode: abyssalRunMode,
            abyssBudget: abyssBudget,
            memoryTemperatureLayer:
                memoryTemperatureLayer)
    }
}
