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
        deliberationLoopEnabled: Bool = false,
        // chapter 一千零四十二 / ADR-020 Step 4 Commit 3 — OPT-IN evidence
        // ledger (and write-back sink) threaded through to the
        // coordinator so a host can supply RESOLVED evidence that
        // reaches the P1.5a seam and WITHHOLDS the loop's own added
        // caution (floored at the loop-off baseline, never below). Both
        // default nil → the coordinator slot stays nil → the seam sees
        // an empty ledger → the full increment is added → byte-equal
        // with the pre-Step-4 host path (红线 7). Mirrors exactly how
        // `deliberationLoopEnabled` is threaded.
        evidenceLedger: BASEvidenceLedger? = nil,
        resolvedEvidenceSink:
            (@Sendable ([BASEvidenceAtom]) -> Void)? = nil,
        // chapter 一千零四十三 / ADR-018 P2 — OPT-IN ShadowTrial N→N+1
        // feedback carriers threaded through to the coordinator. All
        // default false/nil → the coordinator slots stay default →
        // byte-equal with the pre-P2 host path (红线 7). Mirrors exactly
        // how `evidenceLedger` is threaded. Dormant in Commit 1.
        shadowTrialFeedbackEnabled: Bool = false,
        pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil,
        resolvedTrialSink:
            (@Sendable ([BASShadowTrialRecord]) -> Void)? = nil,
        // chapter 一百八十六 / ADR-019 P1.5b — OPT-IN SSM caution operator,
        // threaded onto the coordinator alongside `deliberationLoopEnabled`.
        // Default false → the coordinator's flag stays false → the L11 SSM
        // seam is dormant → byte-equal (红线 7 + ADR-014). A host sets this
        // true to let the CPU-deterministic temporal-caution operator RAISE
        // L11 caution (verdict-gated, raise-only) on genuinely-uncertain turns.
        ssmCautionOperatorEnabled: Bool = false
    ) -> BASEBrainTurnResult {
        makeEBrainTurn(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: deviceStateOverride,
            now: now,
            deliberationLoopEnabled: deliberationLoopEnabled,
            evidenceLedger: evidenceLedger,
            resolvedEvidenceSink: resolvedEvidenceSink,
            shadowTrialFeedbackEnabled: shadowTrialFeedbackEnabled,
            pendingTrialLedgerIn: pendingTrialLedgerIn,
            resolvedTrialSink: resolvedTrialSink,
            ssmCautionOperatorEnabled: ssmCautionOperatorEnabled
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
        now: Date = .now,
        // ch 1039 / ADR-018 P1 — OPT-IN deliberation loop, threaded onto
        // the coordinator this async surface builds (via buildCoordinator).
        // Default false → single pass (byte-equal, 红线 7 + ADR-014).
        // Mirrors exactly how the sync `buildEBrainTurn(...)` →
        // `makeEBrainTurn(...)` path threads it. Before this, the
        // runtime-mode surface had NO such parameter and buildCoordinator
        // defaulted the coordinator's flag to false, so this async path
        // could NEVER run the deliberation loop — a real activation gap.
        // By construction the loop IS consequential when set (the
        // runtime-mode path uses the SAME real
        // BASHostRuntimeEBrainLoopService + coordinator.runTurn as the sync
        // path, where ch1039/ch1041 prove the on/off divergence). NOTE: the
        // on-effect could not be exercised by a direct XCTest of THIS async
        // surface — a faithful test needs an `async` test method (the func
        // is async) seeded via `startSession`, and on this toolchain
        // `async test + startSession` crashes with SIGBUS (the same bucket
        // pinned in BASSignalTenIntegrationTestTriageDoctrine; empirically
        // re-confirmed). The activation is proven transitively through the
        // sync-path tests that exercise the identical coordinator wiring.
        deliberationLoopEnabled: Bool = false,
        // chapter 一百八十六 / ADR-019 P1.5b — OPT-IN SSM caution operator,
        // threaded onto the coordinator this async surface builds (via
        // buildCoordinator). Default false → coordinator flag false → the L11
        // SSM seam is dormant → byte-equal (红线 7 + ADR-014). Mirrors exactly
        // how `deliberationLoopEnabled` is threaded here. Before this, the
        // runtime-mode surface had NO such parameter and buildCoordinator
        // defaulted the coordinator's flag to false, so this async path could
        // NEVER enable the operator — the same activation gap noted above for
        // the deliberation flag. Like that flag, the async on-effect can't be
        // exercised by a direct XCTest (async test + startSession SIGBUSes per
        // BASSignalTenIntegrationTestTriageDoctrine); it is proven transitively
        // by the sync-path BASSSMCautionOperatorRunTurnTests, which exercise
        // the identical coordinator wiring.
        ssmCautionOperatorEnabled: Bool = false
    ) async -> BASEBrainTurnResult {
        let coordinator = buildCoordinator(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            now: now,
            deliberationLoopEnabled: deliberationLoopEnabled,
            ssmCautionOperatorEnabled: ssmCautionOperatorEnabled
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
            // V2 engine path — wraps coordinator + emits M991 lifecycle
            // envelopes。 As of ADR-033 Step 3b `engine.runTurn` reads the
            // mode: `.nativeV2` dispatches `runWithPlan` (native executors),
            // `.stressSweepDual` takes the single V1 pass。 In BOTH cases the
            // returned `BASEBrainTurnResult` is byte-equal to the V1 path
            // (runWithPlan returns the same coordinator.runTurn value)。
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
        now: Date,
        // ch 1039 / ADR-018 P1 — OPT-IN deliberation loop. Default false →
        // single pass (byte-equal, 红线 7). Threaded onto BOTH the
        // triSelfService (ch1040 ADR-019 reversibility-tilt) and the
        // coordinator init below, exactly as the sync `makeEBrainTurn(...)`
        // path does, so this async surface activates the same loop.
        deliberationLoopEnabled: Bool = false,
        // chapter 一百八十六 / ADR-019 P1.5b — OPT-IN SSM caution operator,
        // threaded onto the coordinator init below. The SSM seam is purely an
        // L11 risk-card raise in runTurn, so — unlike `deliberationLoopEnabled`
        // — it is NOT threaded onto triSelfService (no reversibility-tilt
        // analogue). Default false → seam dormant → byte-equal (红线 7 + ADR-014).
        ssmCautionOperatorEnabled: Bool = false
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
                    hostConstitution: resolvedConstitution,
                    // chapter 一千零四十一 / ADR-019 — opt-in reversibility-
                    // tilt. Default-false elsewhere → byte-equal. Mirrors
                    // the sync `makeEBrainTurn(...)` wiring.
                    deliberationLoopEnabled: deliberationLoopEnabled
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
                    hostConstitution: resolvedConstitution,
                    turnRecordedAt: now
                ),
            policyLineage:
                configuration.runtimePolicyLineage,
            hostRhythmProfile:
                constitutionService
                    .projectRhythm(from: resolvedConstitution),
            hostConstitution: resolvedConstitution,
            hostConstitutionVault: resolvedVault,
            hostVersionTree: configuration.hostVersionTree,
            hostForgetRequest: configuration.hostForgetRequest,
            // ch 1039 / ADR-018 P1 — thread the opt-in deliberation flag
            // onto the coordinator the async runtime-mode surface uses.
            // Default false (every existing caller omits it) → the
            // coordinator's own default false → the runTurn loop body +
            // P1.5a caution seam stay dormant → byte-equal (红线 7).
            deliberationLoopEnabled: deliberationLoopEnabled,
            // chapter 一百八十六 / ADR-019 P1.5b — thread the SSM caution
            // operator flag onto the coordinator the async runtime-mode
            // surface uses. Default false → the coordinator's own default
            // false → the L11 SSM seam stays dormant → byte-equal (红线 7).
            ssmCautionOperatorEnabled: ssmCautionOperatorEnabled
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
        deliberationLoopEnabled: Bool = false,
        // chapter 一千零四十二 / ADR-020 Step 4 Commit 3 — OPT-IN evidence
        // ledger + write-back sink, threaded onto the coordinator
        // alongside `deliberationLoopEnabled`. Both default nil → the
        // coordinator slot stays nil → byte-equal (红线 7).
        evidenceLedger: BASEvidenceLedger? = nil,
        resolvedEvidenceSink:
            (@Sendable ([BASEvidenceAtom]) -> Void)? = nil,
        // chapter 一千零四十三 / ADR-018 P2 — OPT-IN ShadowTrial N→N+1
        // feedback carriers, threaded onto the coordinator alongside the
        // ch1042 evidence carriers. All default false/nil → the
        // coordinator slots stay default → byte-equal (红线 7). Dormant
        // in Commit 1.
        shadowTrialFeedbackEnabled: Bool = false,
        pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil,
        resolvedTrialSink:
            (@Sendable ([BASShadowTrialRecord]) -> Void)? = nil,
        // chapter 一百八十六 / ADR-019 P1.5b — OPT-IN SSM caution operator,
        // threaded onto the coordinator the sync host path builds. Default
        // false → coordinator flag false → L11 SSM seam dormant → byte-equal
        // (红线 7 + ADR-014). Mirrors exactly how `deliberationLoopEnabled`
        // is threaded onto the coordinator below.
        ssmCautionOperatorEnabled: Bool = false
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
                hostConstitution: resolvedConstitution,
                turnRecordedAt: now
            ),
            policyLineage: configuration.runtimePolicyLineage,
            hostRhythmProfile: constitutionService.projectRhythm(from: resolvedConstitution),
            hostConstitution: resolvedConstitution,
            hostConstitutionVault: resolvedVault,
            hostVersionTree: configuration.hostVersionTree,
            hostForgetRequest: configuration.hostForgetRequest,
            deliberationLoopEnabled: deliberationLoopEnabled,
            // chapter 一千零四十二 / ADR-020 Step 4 Commit 3 — activate the
            // floored caution-withholding seam in production: a host-
            // supplied `evidenceLedger` now reaches the coordinator slot
            // the P1.5a seam reads. nil (default) → empty ledger at the
            // seam → full increment → byte-equal (红线 7).
            evidenceLedger: evidenceLedger,
            resolvedEvidenceSink: resolvedEvidenceSink,
            // chapter 一千零四十三 / ADR-018 P2 — thread the ShadowTrial
            // N→N+1 feedback carriers onto the coordinator. All
            // default false/nil → the coordinator slots stay default →
            // nothing in runTurn reads them yet → byte-equal (红线 7).
            // Dormant in Commit 1.
            shadowTrialFeedbackEnabled: shadowTrialFeedbackEnabled,
            pendingTrialLedgerIn: pendingTrialLedgerIn,
            resolvedTrialSink: resolvedTrialSink,
            // chapter 一百八十六 / ADR-019 P1.5b — activate the SSM caution
            // operator in production: the host-supplied flag reaches the
            // coordinator slot the L11 SSM seam reads. false (default) → seam
            // dormant → byte-equal (红线 7).
            ssmCautionOperatorEnabled: ssmCautionOperatorEnabled
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
