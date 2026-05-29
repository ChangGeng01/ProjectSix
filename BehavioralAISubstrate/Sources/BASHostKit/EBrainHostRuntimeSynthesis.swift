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
        now: Date = .now,
        // ch 1039 / ADR-018 P1 — OPT-IN deliberation loop. Default
        // false → single pass (byte-equal, 红线 7 + ADR-014). A host
        // sets this true to let high-risk / calibration-drift turns
        // run budget-bounded refinement passes.
        deliberationLoopEnabled: Bool = false
    ) -> BASEBrainTurnResult {
        makeEBrainTurn(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: deviceStateOverride,
            now: now,
            deliberationLoopEnabled: deliberationLoopEnabled
        )
    }

    // MARK: - M2049 chapter 六百六十八 第一刀 — runtimeMode knob

    /// Phase K opt-in async surface threading `runtimeMode`
    /// through to the V2 engine。 Default `.v1ByteEqual`
    /// preserves M2032 behavior (direct coordinator.runTurn
    /// call,no engine wrapper)。 Non-default modes wrap
    /// the coordinator in `BASTurnRuntimeEngine` and call
    /// its `runTurn(_:)` — which currently delegates to V1
    /// for byte-equality but emits the M991 lifecycle
    /// envelopes (observable side-effect,not part of the
    /// returned `BASEBrainTurnResult` byte-equality contract)。
    ///
    /// Chapter 669 ships dual-mode stress-sweep tests
    /// asserting V1 and V2 paths produce byte-equal
    /// `BASEBrainTurnResult` under canonical60 + extended
    /// fixtures。 Chapter 670 wires the SampleHost
    /// `BAS_RUNTIME_MODE` env var to this param。 Chapter
    /// 674 (Phase L) flips the default to `.nativeV2`
    /// after 24h dual-mode 0-divergence gate clears。
    ///
    /// Hosts that don't opt in continue calling the
    /// existing synchronous `buildEBrainTurn(...)` —
    /// ADR-014 OPT-IN preserved。
    public func buildEBrainTurnWithRuntimeMode(
        request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState? = nil,
        runtimeMode: BASTurnRuntimeMode = .v1ByteEqual,
        now: Date = .now
    ) async -> BASEBrainTurnResult {
        let coordinator = buildCoordinator(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            now: now
        )
        let deviceState = deviceStateOverride
            ?? vitalMonitor?.currentDeviceState(now: now)
            ?? configuration.defaultDeviceState
        let resolvedHostID =
            "\(configuration.workflowBehavior.hostNamespace)" +
            ".\(request.workflowProfile.rawValue)"
        let turnRequest = BASEBrainTurnRequest(
            userInput: request.prompt,
            deviceState: deviceState,
            hostID: resolvedHostID,
            recordedAt: now,
            riskHint: request.riskLevel.eBrainRiskLevel,
            feedbackEvent: nil,
            activeKillSwitches: request.activeKillSwitches
        )
        switch runtimeMode {
        case .v1ByteEqual:
            // Direct coordinator path — byte-equal to
            // the synchronous `buildEBrainTurn(...)`。
            return coordinator.runTurn(turnRequest)
        case .nativeV2, .stressSweepDual:
            // V2 engine path — wraps coordinator + emits
            // M991 lifecycle envelopes。 Currently
            // delegates to coordinator.runTurn,so the
            // returned `BASEBrainTurnResult` is byte-
            // equal to the V1 path。 Phase L+ work makes
            // the engine paths diverge meaningfully。
            let engine = BASTurnRuntimeEngine(
                coordinator: coordinator,
                runtimeMode: runtimeMode)
            return await engine.runTurn(turnRequest)
        }
    }

    /// Coordinator-build extracted from `makeEBrainTurn`
    /// so the async opt-in path can reuse the exact same
    /// V1 service wiring (ADR-014 single-source-of-truth)。
    private func buildCoordinator(
        for request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        now: Date
    ) -> BASEBrainRuntimeCoordinator {
        let enforcedCurrentBrain = currentBrain
            .applyingControlPlaneDisposition(
                configuration.controlPlaneExecutionDisposition,
                reasonCodes: configuration.controlPlaneReasonCodes
            )
        let resolvedHostID =
            "\(configuration.workflowBehavior.hostNamespace)" +
            ".\(request.workflowProfile.rawValue)"
        let constitutionService =
            BASHostRuntimeEBrainHostConstitutionService(
                configuration: configuration,
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning
            )
        let resolvedConstitution =
            constitutionService.resolveConstitution(
                hostID: resolvedHostID,
                contextFrame: nil,
                riskCard: nil
            )
        let resolvedVault = configuration
            .hostConstitutionVault?
            .reconciling(
                constitutionSnapshot: resolvedConstitution,
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )
            ?? resolvedConstitution.vaultSnapshot(
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )
        return BASEBrainRuntimeCoordinator(
            powerClockService:
                BASHostRuntimeEBrainPowerClockService(
                    prefersPureLocal: configuration.prefersPureLocal,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning
                ),
            hostProfileService:
                BASHostRuntimeEBrainHostProfileService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    constitutionService: constitutionService
                ),
            contextService:
                BASHostRuntimeEBrainContextService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    hostConstitution: resolvedConstitution
                ),
            decomposeService:
                BASHostRuntimeEBrainDecomposeService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    projection: projection,
                    hostConstitution: resolvedConstitution
                ),
            memoryService:
                BASHostRuntimeEBrainMemoryService(
                    projection: projection,
                    currentBrain: enforcedCurrentBrain,
                    hostConstitution: resolvedConstitution
                ),
            neuralCoreService:
                BASHostRuntimeEBrainNeuralCoreService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    hostConstitution: resolvedConstitution
                ),
            loopService:
                BASHostRuntimeEBrainLoopService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    hostConstitution: resolvedConstitution
                ),
            triSelfService:
                BASHostRuntimeEBrainTriSelfService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    hostConstitution: resolvedConstitution
                ),
            riskService:
                BASHostRuntimeEBrainRiskService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    tuning: configuration.runtimeTuning,
                    hostConstitution: resolvedConstitution
                ),
            actionService:
                BASHostRuntimeEBrainActionService(
                    hostConstitution: resolvedConstitution
                ),
            evolutionService:
                BASHostRuntimeEBrainEvolutionService(
                    request: request,
                    currentBrain: enforcedCurrentBrain,
                    hostConstitution: resolvedConstitution
                ),
            policyLineage:
                configuration.runtimePolicyLineage,
            hostRhythmProfile:
                constitutionService
                    .projectRhythm(from: resolvedConstitution),
            hostConstitution: resolvedConstitution,
            hostConstitutionVault: resolvedVault,
            hostVersionTree: configuration.hostVersionTree,
            hostForgetRequest: configuration.hostForgetRequest
        )
    }

    func makeEBrainTurn(
        for request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState?,
        now: Date,
        // ch 1039 / ADR-018 P1 — OPT-IN deliberation loop. Default
        // false → single pass (byte-equal, 红线 7).
        deliberationLoopEnabled: Bool = false
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
                hostConstitution: resolvedConstitution,
                // chapter 一千零四十一 / ADR-019 — opt-in reversibility-
                // tilt. Sync host path only; default-false elsewhere →
                // byte-equal.
                deliberationLoopEnabled: deliberationLoopEnabled
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
            hostForgetRequest: configuration.hostForgetRequest,
            deliberationLoopEnabled: deliberationLoopEnabled
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
