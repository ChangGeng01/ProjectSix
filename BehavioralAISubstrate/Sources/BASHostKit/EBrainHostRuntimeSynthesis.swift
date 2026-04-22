import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

extension BASHostRiskLevel {
    var eBrainRiskLevel: BASBrainRiskLevel {
        switch self {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }
}

extension BASHostRuntime {
    public func buildEBrainTurn(
        request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState? = nil,
        now: Date = .now
    ) -> BASEBrainTurnResult {
        makeEBrainTurn(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: deviceStateOverride,
            now: now
        )
    }

    func makeEBrainTurn(
        for request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState?,
        now: Date
    ) -> BASEBrainTurnResult {
        let enforcedCurrentBrain = currentBrain.applyingControlPlaneDisposition(
            configuration.controlPlaneExecutionDisposition,
            reasonCodes: configuration.controlPlaneReasonCodes
        )
        let deviceState = deviceStateOverride
            ?? vitalMonitor?.currentDeviceState(now: now)
            ?? configuration.defaultDeviceState
        let resolvedHostID = "\(configuration.workflowBehavior.hostNamespace).\(request.workflowProfile.rawValue)"
        let constitutionService = BASHostRuntimeEBrainHostConstitutionService(
            configuration: configuration,
            request: request,
            currentBrain: enforcedCurrentBrain,
            tuning: configuration.runtimeTuning
        )
        let resolvedConstitution = constitutionService.resolveConstitution(
            hostID: resolvedHostID,
            contextFrame: nil,
            riskCard: nil
        )
        let resolvedVault = configuration.hostConstitutionVault?
            .reconciling(
                constitutionSnapshot: resolvedConstitution,
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )
            ?? resolvedConstitution.vaultSnapshot(
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: BASHostRuntimeEBrainPowerClockService(
                prefersPureLocal: configuration.prefersPureLocal,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning
            ),
            hostProfileService: BASHostRuntimeEBrainHostProfileService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                constitutionService: constitutionService
            ),
            contextService: BASHostRuntimeEBrainContextService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: resolvedConstitution
            ),
            decomposeService: BASHostRuntimeEBrainDecomposeService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                projection: projection,
                hostConstitution: resolvedConstitution
            ),
            memoryService: BASHostRuntimeEBrainMemoryService(
                projection: projection,
                currentBrain: enforcedCurrentBrain,
                hostConstitution: resolvedConstitution
            ),
            neuralCoreService: BASHostRuntimeEBrainNeuralCoreService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: resolvedConstitution
            ),
            loopService: BASHostRuntimeEBrainLoopService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: resolvedConstitution
            ),
            triSelfService: BASHostRuntimeEBrainTriSelfService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: resolvedConstitution
            ),
            riskService: BASHostRuntimeEBrainRiskService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: resolvedConstitution
            ),
            actionService: BASHostRuntimeEBrainActionService(
                hostConstitution: resolvedConstitution
            ),
            evolutionService: BASHostRuntimeEBrainEvolutionService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                hostConstitution: resolvedConstitution
            ),
            policyLineage: configuration.runtimePolicyLineage,
            hostRhythmProfile: constitutionService.projectRhythm(from: resolvedConstitution),
            hostConstitution: resolvedConstitution,
            hostConstitutionVault: resolvedVault,
            hostVersionTree: configuration.hostVersionTree,
            hostForgetRequest: configuration.hostForgetRequest
        )

        return coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: request.prompt,
                deviceState: deviceState,
                hostID: resolvedHostID,
                recordedAt: now,
                riskHint: request.riskLevel.eBrainRiskLevel,
                feedbackEvent: nil,
                activeKillSwitches: request.activeKillSwitches
            )
        )
    }
}
