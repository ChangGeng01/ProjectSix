import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainPowerClockService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainPowerClockService: BASPowerClockServicing {
    let prefersPureLocal: Bool
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy

    func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        let hint = riskHint ?? .low
        let wakeIntentTuning = tuning.wakeIntent
        let urgencyDetected = wakeIntentTuning.containsUrgency(taskPing)
        let reflectiveCueDetected = wakeIntentTuning.containsReflectiveCue(taskPing)
        let deepLoopCueDetected = wakeIntentTuning.containsDeepLoopCue(taskPing)
        let stateTransitionTuning = tuning.stateTransitions
        let guardedBudgetRequired = stateTransitionTuning.requiresGuardedBudget(
            boundaryMode: currentBrain.boundaryMode,
            calibrationStatus: currentBrain.calibrationStatus,
            riskFlags: currentBrain.riskFlags,
            retrievalTags: currentBrain.retrievalTags
        )
        let budgetTuning = tuning.budget
        let runModeContext = BASEBrainRuntimeSynthesisPolicy.BASRunModeTransitionContext(
            riskLevel: hint,
            thermalLevel: deviceState.thermalLevel,
            foregroundState: deviceState.foregroundState,
            batteryLevel: deviceState.batteryLevel,
            guardedBudgetRequired: guardedBudgetRequired,
            requiresRecovery: currentBrain.requiresRecovery,
            requiresQuarantine: currentBrain.requiresQuarantine,
            urgencyDetected: urgencyDetected,
            reflectiveCueDetected: reflectiveCueDetected,
            deepLoopCueDetected: deepLoopCueDetected
        )
        let runMode = stateTransitionTuning.resolvedRunMode(
            for: runModeContext,
            wakeIntent: wakeIntentTuning
        )
        let runModeBudgetProfile = budgetTuning.runModeProfile(
            for: runMode,
            maintenance: tuning.maintenance
        )
        let protectedFloorsActive = budgetTuning.usesProtectedFloors(
            boundaryMode: currentBrain.boundaryMode,
            calibrationStatus: currentBrain.calibrationStatus
        )

        let loops = runModeBudgetProfile.maxLoops
        let loopFloor = protectedFloorsActive
            ? (runModeBudgetProfile.protectedLoopFloor ?? budgetTuning.protectedLoopFloor)
            : (runModeBudgetProfile.standardLoopFloor ?? budgetTuning.standardLoopFloor)

        let candidates = runModeBudgetProfile.maxCandidates
        let precision = runModeBudgetProfile.precisionProfile
        let unstableBudgetActive = budgetTuning.unstableBudgetCalibrationStatuses.contains(currentBrain.calibrationStatus)
        let resolvedPrecision: BASRuntimePrecisionProfile = unstableBudgetActive
            ? budgetTuning.unstablePrecisionProfile
            : precision

        let thermalGuard = budgetTuning.thermalGuardLevel(for: deviceState.thermalLevel)

        let throttlePenaltyThermalLevels =
            runModeBudgetProfile.throttlePenaltyThermalLevels ?? budgetTuning.throttlePenaltyThermalLevels
        let throttlePenaltyActive = throttlePenaltyThermalLevels.contains(deviceState.thermalLevel)
        let guardedLoops = throttlePenaltyActive
            ? max(1, loops - (runModeBudgetProfile.throttleLoopPenalty ?? budgetTuning.throttleLoopPenalty))
            : loops
        let unstableLoopIncrementRiskLevels =
            runModeBudgetProfile.unstableLoopIncrementRiskLevels ?? budgetTuning.unstableLoopIncrementRiskLevels
        let unstableLoopIncrement = unstableBudgetActive && unstableLoopIncrementRiskLevels.contains(hint)
            ? (runModeBudgetProfile.unstableLoopIncrement ?? budgetTuning.unstableLoopIncrement)
            : 0
        let resolvedLoops = max(loopFloor, guardedLoops + unstableLoopIncrement)
        let guardedCandidates = throttlePenaltyActive
            ? max(1, candidates - (runModeBudgetProfile.throttleCandidatePenalty ?? budgetTuning.throttleCandidatePenalty))
            : candidates
        let candidateFloor = protectedFloorsActive
            ? (runModeBudgetProfile.protectedCandidateFloor ?? budgetTuning.protectedCandidateFloor)
            : (runModeBudgetProfile.standardCandidateFloor ?? budgetTuning.standardCandidateFloor)
        let resolvedCandidates = min(
            runModeBudgetProfile.candidateCountCap ?? budgetTuning.maxCandidateCount,
            max(candidateFloor, guardedCandidates)
        )
        let retrievalDepth = runModeBudgetProfile.retrievalDepth
        let preliminaryBudget = BASBudgetFrame(
            runMode: runMode,
            maxLoops: resolvedLoops,
            maxCandidates: resolvedCandidates,
            maxDecodeTokens: unstableBudgetActive
                ? (runModeBudgetProfile.unstableDecodeTokens ?? budgetTuning.unstableDecodeTokens)
                : (runModeBudgetProfile.defaultDecodeTokens ?? budgetTuning.standardDecodeTokens),
            retrievalDepth: retrievalDepth,
            precisionProfile: resolvedPrecision,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: thermalGuard,
            maintenanceAllowed: false,
            // Leave lease identity/timing empty here so the coordinator can derive
            // a stable lease from the runtime trace instead of a fresh UUID/Date.now.
            leaseID: nil,
            leaseExpiresAt: nil,
            maintenanceClass: .none
        )
        let maintenanceAllowed = scheduleMaintenance(deviceState: deviceState, budget: preliminaryBudget)
        let maintenanceClass = maintenanceAllowed
            ? (runModeBudgetProfile.scheduledMaintenanceClass ?? tuning.maintenance.activeRunModeClass)
            : (runModeBudgetProfile.deferredMaintenanceClass ?? tuning.maintenance.restrictedRunModeClass)
        return BASBudgetFrame(
            runMode: preliminaryBudget.runMode,
            maxLoops: preliminaryBudget.maxLoops,
            maxCandidates: preliminaryBudget.maxCandidates,
            maxDecodeTokens: preliminaryBudget.maxDecodeTokens,
            retrievalDepth: preliminaryBudget.retrievalDepth,
            precisionProfile: preliminaryBudget.precisionProfile,
            deviceRoute: routeDevice(deviceState: deviceState, budget: preliminaryBudget),
            thermalGuardLevel: preliminaryBudget.thermalGuardLevel,
            maintenanceAllowed: maintenanceAllowed,
            leaseID: preliminaryBudget.leaseID,
            leaseExpiresAt: preliminaryBudget.leaseExpiresAt,
            maintenanceClass: maintenanceClass
        )
    }

    func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute {
        let runModeProfile = tuning.budget.runModeProfile(
            for: budget.runMode,
            maintenance: tuning.maintenance
        )
        return runModeProfile.resolvedDeviceRoute(
            npuAvailable: deviceState.npuAvailable,
            prefersPureLocal: prefersPureLocal
        )
    }

    func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool {
        let runModeProfile = tuning.budget.runModeProfile(
            for: budget.runMode,
            maintenance: tuning.maintenance
        )
        guard runModeProfile.maintenanceSupported ?? false else {
            return false
        }
        guard !tuning.maintenance.blockedForegroundStates.contains(deviceState.foregroundState) else {
            return false
        }
        guard tuning.maintenance.allowedThermalLevels.contains(deviceState.thermalLevel) else {
            return false
        }
        let batteryFloor = runModeProfile.maintenanceBatteryFloor ?? tuning.maintenance.standardBatteryFloor
        return deviceState.batteryLevel > batteryFloor
    }
}
