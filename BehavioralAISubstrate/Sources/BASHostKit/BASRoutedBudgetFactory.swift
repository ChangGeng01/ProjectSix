// MARK: - BASRoutedBudgetFactory
// chapter 五百十 / M1419 — typed factory for routedBudget
// construction (BASBudgetFrame fold)
//
// Folds the inline 25-line BASBudgetFrame construction
// at coordinator line 713-737 into a typed pure-function
// factory call。 Threads 16 fields verbatim from
// plannedBudget;takes the 2 powerClockService-computed
// fields (deviceRoute + maintenanceAllowed) as direct
// inputs so the helper visibility is unchanged。
//
// HONEST SCOPE — chapter 五百十:
// =============================================================
// Pure-function factory — produces identical
// BASBudgetFrame given the same inputs。 V1 byte-equality
// preserved by construction (no field reordering,no
// computation change)。 Stress-sweep dual mode regression-
// guards the splice。

import Foundation
import BASRuntimeCore

/// Typed pure-function factory for the per-turn
/// routedBudget construction that the coordinator
/// performs after powerClockService planning + risk-
/// hint normalization。
public enum BASRoutedBudgetFactory {

    /// Construct the routed BASBudgetFrame from the
    /// planned budget + the 2 powerClockService-computed
    /// values (deviceRoute + maintenanceAllowed)。
    ///
    /// Threads schemaVersion + runMode + maxLoops +
    /// maxCandidates + maxDecodeTokens + retrievalDepth
    /// + precisionProfile + thermalGuardLevel + leaseID
    /// + leaseExpiresAt + maintenanceClass + wakeIntentID
    /// + allowedHeads + policyBundleVersion +
    /// policyDecisionIDs verbatim from plannedBudget。
    public static func routedBudget(
        plannedBudget: BASBudgetFrame,
        deviceRoute: BASDeviceRoute,
        maintenanceAllowed: Bool
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            schemaVersion: plannedBudget.schemaVersion,
            runMode: plannedBudget.runMode,
            maxLoops: plannedBudget.maxLoops,
            maxCandidates: plannedBudget.maxCandidates,
            maxDecodeTokens:
                plannedBudget.maxDecodeTokens,
            retrievalDepth:
                plannedBudget.retrievalDepth,
            precisionProfile:
                plannedBudget.precisionProfile,
            deviceRoute: deviceRoute,
            thermalGuardLevel:
                plannedBudget.thermalGuardLevel,
            maintenanceAllowed: maintenanceAllowed,
            leaseID: plannedBudget.leaseID,
            leaseExpiresAt:
                plannedBudget.leaseExpiresAt,
            maintenanceClass:
                plannedBudget.maintenanceClass,
            wakeIntentID: plannedBudget.wakeIntentID,
            allowedHeads: plannedBudget.allowedHeads,
            policyBundleVersion:
                plannedBudget.policyBundleVersion,
            policyDecisionIDs:
                plannedBudget.policyDecisionIDs)
    }
}
