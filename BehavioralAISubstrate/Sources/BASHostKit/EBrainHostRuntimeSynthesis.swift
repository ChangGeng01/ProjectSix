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

private extension BASHostCurrentBrain {
    func applyingControlPlaneDisposition(
        _ disposition: BASHostConfiguration.ControlPlaneExecutionDisposition,
        reasonCodes: [String]
    ) -> BASHostCurrentBrain {
        guard disposition != .normal else {
            return self
        }

        func orderedUnique(_ values: [String]) -> [String] {
            var seen = Set<String>()
            return values.filter { seen.insert($0).inserted }
        }

        var updated = self
        let laneConstraint = disposition == .quarantine
            ? "brain-bootstrap-quarantine"
            : "brain-bootstrap-recovery"
        let laneTag = disposition == .quarantine ? "quarantine" : "recovery"
        let annotatedReasons = reasonCodes.map { "\($0)" }

        updated.activeConstraints = orderedUnique(
            updated.activeConstraints
                + [laneConstraint]
                + annotatedReasons
        )
        updated.retrievalTags = orderedUnique(
            updated.retrievalTags
                + [laneTag]
                + annotatedReasons
        )
        if updated.verificationSummary.isEmpty {
            updated.verificationSummary = "control-plane:\(laneTag)"
        } else if !updated.verificationSummary.contains("control-plane:\(laneTag)") {
            updated.verificationSummary += " | control-plane:\(laneTag)"
        }

        return updated
    }

    var hasEvidenceCaveatLoad: Bool {
        riskFlags.contains(.evidenceCaveatLoad) || retrievalTags.contains("evidence_caveat")
    }

    var hasProtectiveBoundary: Bool {
        boundaryMode == .localOnlyProtective
    }

    var requiresRecovery: Bool {
        activeConstraints.contains("brain-bootstrap-recovery") || retrievalTags.contains("recovery")
    }

    var requiresQuarantine: Bool {
        activeConstraints.contains("brain-bootstrap-quarantine") || retrievalTags.contains("quarantine")
    }

    var isCalibrationUnstable: Bool {
        calibrationStatus == .watch || calibrationStatus == .drifting
    }

    var hasTrustDriftSignals: Bool {
        riskFlags.contains(.lowTrustLoad) ||
            riskFlags.contains(.retrievalInstability) ||
            riskFlags.contains(.externalRefreshGuardTriggered) ||
            riskFlags.contains(.observationOnlyQuarantine) ||
            hasEvidenceCaveatLoad
    }

    func hostGuardrailPressure(
        using tuning: BASEBrainRuntimeSynthesisPolicy
    ) -> Double {
        let pressureTuning = tuning.guardrailPressure
        var pressure = 0.0
        if hasProtectiveBoundary { pressure += pressureTuning.protectiveBoundaryIncrement }
        if calibrationStatus == .watch { pressure += pressureTuning.calibrationWatchIncrement }
        if calibrationStatus == .drifting { pressure += pressureTuning.calibrationDriftingIncrement }
        pressure += min(
            pressureTuning.boundaryConstraintCap,
            Double(boundaryConstraints.count) * pressureTuning.boundaryConstraintUnit
        )
        pressure += min(
            pressureTuning.calibrationAlertCap,
            Double(calibrationAlerts.count) * pressureTuning.calibrationAlertUnit
        )
        pressure += min(
            pressureTuning.failureGuardCap,
            Double(failureGuardCount) * pressureTuning.failureGuardUnit
        )
        pressure += min(
            pressureTuning.riskFlagCap,
            Double(riskFlags.count) * pressureTuning.riskFlagUnit
        )
        return min(pressureTuning.maximumPressure, pressure)
    }
}

private struct BASHostRuntimeEBrainPowerClockService: BASPowerClockServicing {
    let prefersPureLocal: Bool
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy

    func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        let hint = riskHint ?? .low
        let urgencyDetected = BASHostRuntimeEBrainPromptAnalyzer.containsUrgency(taskPing)
        let reflectiveCueDetected = BASHostRuntimeEBrainPromptAnalyzer.containsReflectiveCue(taskPing)
        let deepLoopCueDetected = BASHostRuntimeEBrainPromptAnalyzer.containsDeepLoopCue(taskPing)
        let guardedBudgetRequired = currentBrain.hasProtectiveBoundary || currentBrain.hasTrustDriftSignals
        let wakeIntentTuning = tuning.wakeIntent
        let stateTransitionTuning = tuning.stateTransitions
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

        let loops = runModeBudgetProfile.maxLoops
        let loopFloor = currentBrain.hasProtectiveBoundary
            ? (runModeBudgetProfile.protectedLoopFloor ?? budgetTuning.protectedLoopFloor)
            : (runModeBudgetProfile.standardLoopFloor ?? budgetTuning.standardLoopFloor)

        let candidates = runModeBudgetProfile.maxCandidates
        let precision = runModeBudgetProfile.precisionProfile
        let resolvedPrecision: BASRuntimePrecisionProfile = currentBrain.isCalibrationUnstable
            ? budgetTuning.unstablePrecisionProfile
            : precision

        let thermalGuard: BASThermalGuardLevel = switch deviceState.thermalLevel {
        case .nominal:
            .nominal
        case .warm:
            .watch
        case .hot:
            .throttle
        case .critical:
            .emergency
        }

        let guardedLoops = thermalGuard == .throttle
            ? max(1, loops - (runModeBudgetProfile.throttleLoopPenalty ?? budgetTuning.throttleLoopPenalty))
            : loops
        let unstableLoopIncrement = currentBrain.isCalibrationUnstable && hint < .high
            ? (runModeBudgetProfile.unstableLoopIncrement ?? budgetTuning.unstableLoopIncrement)
            : 0
        let resolvedLoops = max(loopFloor, guardedLoops + unstableLoopIncrement)
        let guardedCandidates = thermalGuard == .throttle
            ? max(1, candidates - (runModeBudgetProfile.throttleCandidatePenalty ?? budgetTuning.throttleCandidatePenalty))
            : candidates
        let candidateFloor = currentBrain.hasProtectiveBoundary
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
            maxDecodeTokens: currentBrain.isCalibrationUnstable
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

private struct BASHostRuntimeEBrainHostConstitutionService: BASHostConstitutionServicing {
    let configuration: BASHostConfiguration
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy

    func resolveConstitution(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostConstitution {
        if let hostConstitution = configuration.hostConstitution {
            return hostConstitution
        }

        return BASHostConstitution(
            hostID: hostID,
            activeVersion: "\(configuration.workflowBehavior.hostNamespace).v1",
            identityLattice: BASIdentityLattice(
                coreTags: [configuration.workflowBehavior.hostNamespace, currentBrain.roleID],
                stageTags: [request.workflowProfile.rawValue],
                continuityScore: 0.88,
                conflictPoints: orderedUnique(
                    currentBrain.activeConstraints
                        + currentBrain.calibrationAlerts.map(\.rawValue)
                ),
                stableCenter: currentBrain.boundaryHeadline
            ),
            valueAxes: BASValueAxisSet(
                axes: ["stability", "locality", "clarity"],
                relativeWeights: [0.94, configuration.prefersPureLocal ? 0.91 : 0.72, 0.78],
                conflictRules: ["risk_over_speed", "boundary_over_comfort"],
                updateThreshold: 0.75
            ),
            goalSpine: BASGoalSpine(
                goals: currentBrain.dominantGoals,
                hierarchy: [:],
                priorityOrder: currentBrain.dominantGoals,
                conflictPairs: currentBrain.riskFlags.map(\.rawValue),
                stageState: request.workflowProfile.rawValue
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: orderedUnique(
                    currentBrain.activeConstraints
                        + currentBrain.boundaryConstraints.map(\.rawValue)
                        + [currentBrain.boundaryHeadline]
                ),
                softCaution: currentBrain.calibrationAlerts.map(\.rawValue),
                confirmRequired: request.riskLevel == .high ? ["high_risk_confirmation"] : [],
                restrictedMemoryDomains: configuration.prefersPureLocal ? ["cold_memory.review_required"] : [],
                restrictedToolDomains: configuration.prefersPureLocal ? ["remote_write"] : []
            ),
            relationGravity: BASRelationGravityMap(
                nodes: [currentBrain.relationshipBoundary],
                edgeTypes: [currentBrain.boundaryMode.rawValue],
                gravityWeights: [1.0],
                communicationModes: [tonePreference],
                highConsequenceLinks: request.riskLevel == .high ? [currentBrain.relationshipBoundary] : []
            ),
            rhythmCanopy: BASRhythmCanopy(
                activeWindows: configuration.hostRhythmProfile.activeWindows,
                focusWindows: configuration.hostRhythmProfile.highFocusWindows,
                lowEnergyWindows: configuration.hostRhythmProfile.lowEnergyWindows,
                reminderTolerance: configuration.hostRhythmProfile.preferredInteractionStyle,
                cadencePreferences: configuration.hostRhythmProfile.sensitivityPeriods
            ),
            styleGenome: BASStyleGenome(
                density: densityPreference,
                warmth: warmthPreference,
                structureBias: structureBias,
                brevityBias: brevityBias,
                metaphorBias: 0.22,
                comparisonBias: comparisonBias,
                revisionStyle: currentBrain.identityPosture.rawValue
            ),
            routineSkeleton: BASRoutineSkeleton(
                workflowTemplates: request.title.map { [$0] } ?? [],
                taskDecompositionModes: [currentBrain.workflowTitle],
                reminderPatterns: [configuration.prefersPureLocal ? "local-first" : "connected"],
                planningCadences: [request.workflowProfile.rawValue]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "review_required",
                toolReadScope: configuration.prefersPureLocal ? "local_only" : "mixed",
                toolWriteScope: "confirm_required",
                syncScope: configuration.prefersPureLocal ? "local_only" : "approved_sync",
                sensitiveDomainRules: currentBrain.activeConstraints
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "\(currentBrain.workflowTitle) host protocol remains active and bounded.",
                currentPhase: request.workflowProfile.rawValue,
                continuityLinks: ["\(configuration.workflowBehavior.hostNamespace).bootstrap"],
                unresolvedTensions: currentBrain.riskFlags.map(\.rawValue)
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: currentBrain.boundaryConstraints.map(\.rawValue),
                emotionalPollutionZones: currentBrain.calibrationAlerts.map(\.rawValue),
                escalationRules: currentBrain.riskFlags.map(\.rawValue),
                exploitationShields: ["no_risk_bypass", "no_unreviewed_rewrite"]
            )
        )
    }

    func projectProfile(
        from constitution: BASHostConstitution,
        riskThresholds: BASHostRiskThresholds
    ) -> BASHostProfile {
        constitution.projectedHostProfile(riskThresholds: riskThresholds)
    }

    func projectRhythm(
        from constitution: BASHostConstitution
    ) -> BASHostRhythmProfile {
        constitution.projectedHostRhythmProfile()
    }

    func stageChange(
        candidate: BASHostChangeCandidate,
        on constitution: BASHostConstitution
    ) -> BASHostConstitution {
        constitution.staged(with: candidate)
    }

    func approve(
        candidate: BASHostChangeCandidate,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.approving(candidate)
    }

    func freeze(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.freezing(versionID: versionID)
    }

    func thaw(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.thawing(versionID: versionID)
    }

    func rollback(
        versionTree: BASHostVersionTree,
        to versionID: String
    ) -> BASHostVersionTree {
        versionTree.rollingBack(to: versionID)
    }

    func executeForget(
        request: BASForgetRequest,
        on constitution: BASHostConstitution
    ) -> BASForgetRequest {
        request.executingCanonicalCascade()
    }

    func applyForget(
        request: BASForgetRequest,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.applyingForget(request)
    }

    func stageMigration(
        contract: BASHostDeviceMigrationContract,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.stagingMigration(contract)
    }

    func approveMigration(
        on vault: BASHostConstitutionVault,
        targetDeviceID: String?
    ) -> BASHostConstitutionVault {
        vault.approvingMigration(targetDeviceID: targetDeviceID)
    }

    func synchronizeVault(
        on vault: BASHostConstitutionVault,
        deviceID: String,
        propagatedRequestIDs: [String],
        synchronizedAt: Date
    ) -> BASHostConstitutionVault {
        vault.synchronizingDevice(
            deviceID,
            propagatedRequestIDs: propagatedRequestIDs,
            synchronizedAt: synchronizedAt
        )
    }

    private var tonePreference: String {
        "\(warmthPreference)_\(densityPreference)"
    }

    private var warmthPreference: String {
        switch request.workflowProfile {
        case .primary:
            "grounded"
        case .comparative:
            "warm"
        case .reflective:
            "calm"
        }
    }

    private var densityPreference: String {
        switch request.workflowProfile {
        case .primary:
            "clear"
        case .comparative:
            "high"
        case .reflective:
            "dense"
        }
    }

    private var structureBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.78
        case .comparative:
            0.94
        case .reflective:
            0.88
        }
    }

    private var brevityBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.72
        case .comparative:
            0.34
        case .reflective:
            0.41
        }
    }

    private var comparisonBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.28
        case .comparative:
            0.92
        case .reflective:
            0.56
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainHostProfileService: BASHostProfileServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let constitutionService: any BASHostConstitutionServicing

    func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        let constitution = constitutionService.resolveConstitution(
            hostID: hostID,
            contextFrame: contextFrame,
            riskCard: riskCard
        )
        return constitutionService.projectProfile(
            from: constitution,
            riskThresholds: BASHostRiskThresholds(
                caution: tuning.hostThresholds.caution,
                protective: tuning.hostThresholds.protective,
                block: tuning.hostThresholds.block
            )
        )
    }

    func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        let baseCap = min(confidence, currentBrain.confidenceCeiling)
        guard let riskCard else { return baseCap }

        let modeCap: Double = switch riskCard.riskLevel {
        case .low: 1.0
        case .medium: 0.72
        case .high: 0.42
        case .extreme: 0.20
        }
        let calibrationCap: Double = switch currentBrain.calibrationStatus {
        case .stable: 1.0
        case .watch: 0.85
        case .drifting: 0.70
        }
        let taskCap: Double = switch taskType {
        case .highConsequence, .highPressure, .manipulationRisk:
            0.78
        default:
            1.0
        }

        return min(
            baseCap,
            modeCap,
            calibrationCap,
            taskCap,
            max(0.20, 1 - currentBrain.hostGuardrailPressure(using: tuning))
        )
    }

    func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        BASHostVersion(
            versionID: versionID,
            changedFields: ["tonePreference", "longTermGoals"],
            reason: "host runtime rollback",
            rollbackRef: profile.activeVersion,
            approvedByPolicy: true
        )
    }
}

private struct BASHostRuntimeEBrainContextService: BASContextServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        let manipulationHints = BASHostRuntimeEBrainPromptAnalyzer.manipulationHints(in: userInput)
        let contextTuning = tuning.context
        let trustInstability = currentBrain.hasTrustDriftSignals ? contextTuning.trustInstabilityIncrement : 0
        let guardedPressure = currentBrain.hasProtectiveBoundary ? contextTuning.guardedPressureIncrement : 0
        let taskType = taskType(for: userInput, manipulationHints: manipulationHints)
        let emotionalLoad = min(
            1,
            (request.riskLevel == .high
                ? contextTuning.emotionalLoadHighRisk
                : (request.workflowProfile == .reflective
                    ? contextTuning.emotionalLoadReflective
                    : contextTuning.emotionalLoadDefault))
                + (currentBrain.calibrationStatus == .drifting ? contextTuning.emotionalLoadDriftingIncrement : 0)
        )
        let timePressure = min(
            1,
            (request.kind == .reopen
                ? contextTuning.timePressureReopen
                : (BASHostRuntimeEBrainPromptAnalyzer.containsUrgency(userInput)
                    ? contextTuning.timePressureUrgent
                    : contextTuning.timePressureDefault))
                + guardedPressure
        )
        let relationPattern = resolvedRelationPattern()
        let ambiguityScore = min(
            1,
            (request.workflowProfile == .comparative
                ? contextTuning.ambiguityComparative
                : contextTuning.ambiguityDefault)
                + trustInstability
        )
        let consequenceLevel = min(
            1,
            (request.riskLevel == .high
                ? contextTuning.consequenceHigh
                : (request.riskLevel == .medium
                    ? contextTuning.consequenceMedium
                    : contextTuning.consequenceLow))
                + guardedPressure
        )
        let roleGeometry = buildRoleGeometry(
            userInput: userInput,
            relationPattern: relationPattern
        )
        let enrichedManipulationHints = orderedUnique(
            manipulationHints
                + ((roleGeometry.map { isAuthorityRelation($0.relationClass) } ?? false) ? ["authority_pressure"] : [])
        )
        let hostRelevance = min(
            1.0,
            max(
                0.4,
                Double(hostContext.longTermGoals.count) * 0.2
                    + constitutionGoalRelevanceIncrement()
                    + constitutionRelationRelevanceIncrement()
                    + presenceRelationRelevanceIncrement(for: roleGeometry?.relationClass)
            )
        )
        let sceneType = resolvedSceneType(
            userInput: userInput,
            taskType: taskType,
            manipulationHints: enrichedManipulationHints,
            consequenceLevel: consequenceLevel
        )
        let powerGradient = buildPowerGradient(
            roleGeometry: roleGeometry,
            manipulationHints: enrichedManipulationHints,
            consequenceLevel: consequenceLevel
        )
        let emotionalWeather = buildEmotionalWeather(
            userInput: userInput,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure
        )
        let urgencyTruth = buildUrgencyTruth(
            userInput: userInput,
            timePressure: timePressure,
            consequenceLevel: consequenceLevel
        )
        let consequenceHorizon = buildConsequenceHorizon(
            relationClass: roleGeometry?.relationClass,
            consequenceLevel: consequenceLevel,
            hostRelevance: hostRelevance
        )
        let manipulationTrace = buildManipulationTrace(
            userInput: userInput,
            manipulationHints: enrichedManipulationHints,
            roleGeometry: roleGeometry,
            urgencyTruth: urgencyTruth
        )
        let hostResonance = buildHostResonance(
            hostContext: hostContext,
            relationClass: roleGeometry?.relationClass,
            hostRelevance: hostRelevance
        )
        let continuityAnchor = buildContinuityAnchor(
            relationClass: roleGeometry?.relationClass,
            sceneType: sceneType
        )
        let routeHint = buildRouteHint(
            budget: budget,
            taskType: taskType,
            consequenceLevel: consequenceLevel,
            manipulationTrace: manipulationTrace,
            urgencyTruth: urgencyTruth,
            powerGradient: powerGradient,
            hostRelevance: hostRelevance
        )
        let confidenceBand = buildConfidenceBand(
            roleGeometry: roleGeometry,
            urgencyTruth: urgencyTruth,
            ambiguityScore: ambiguityScore,
            manipulationHints: enrichedManipulationHints
        )
        return BASContextFrame(
            utterance: userInput,
            taskType: taskType,
            sceneType: sceneType,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: relationPattern,
            ambiguityScore: ambiguityScore,
            consequenceLevel: consequenceLevel,
            manipulationHints: orderedUnique(enrichedManipulationHints + currentBrain.riskFlags.map(\.rawValue)),
            hostRelevance: hostRelevance,
            roleGeometry: roleGeometry,
            powerGradient: powerGradient,
            emotionalWeather: emotionalWeather,
            urgencyTruth: urgencyTruth,
            consequenceHorizon: consequenceHorizon,
            manipulationTrace: manipulationTrace,
            hostResonance: hostResonance,
            continuityAnchor: continuityAnchor,
            routeHint: routeHint,
            confidenceBand: confidenceBand
        )
    }

    private func taskType(for userInput: String, manipulationHints: [String]) -> BASContextTaskType {
        if !manipulationHints.isEmpty || currentBrain.hasTrustDriftSignals {
            return .manipulationRisk
        }
        if request.riskLevel == .high {
            return request.kind == .reopen ? .highPressure : .highConsequence
        }
        switch request.workflowProfile {
        case .primary:
            return .task
        case .comparative:
            return .choice
        case .reflective:
            return .chat
        }
    }

    private func resolvedSceneType(
        userInput: String,
        taskType: BASContextTaskType,
        manipulationHints: [String],
        consequenceLevel: Double
    ) -> BASContextSceneType {
        if request.riskLevel == .high && consequenceLevel > 0.7 &&
            (BASHostRuntimeEBrainPromptAnalyzer.containsUrgency(userInput) || request.kind == .reopen) {
            return .highPressureConflict
        }
        if manipulationHints.isEmpty == false {
            return .manipulationRisk
        }
        return BASContextSceneType.defaultValue(for: taskType)
    }

    private func buildRoleGeometry(
        userInput: String,
        relationPattern: String
    ) -> BASRoleGeometry? {
        let relationClass = detectedRelationClass(in: userInput, relationPattern: relationPattern)
        guard relationClass.isEmpty == false else {
            return nil
        }

        var asymmetryFlags: [String] = []
        if highConsequenceRelations.contains(relationClass) {
            asymmetryFlags.append("high_consequence_relation")
        }
        if isAuthorityRelation(relationClass) {
            asymmetryFlags.append("authority_relation")
        }
        if request.riskLevel == .high {
            asymmetryFlags.append("high_risk_context")
        }

        return BASRoleGeometry(
            actors: orderedUnique(["host", relationClass]),
            roleTypes: orderedUnique(["host", roleType(for: relationClass)]),
            relationClass: relationClass,
            asymmetryFlags: asymmetryFlags,
            intimacyDistance: intimacyDistance(for: relationClass)
        )
    }

    private func buildPowerGradient(
        roleGeometry: BASRoleGeometry?,
        manipulationHints: [String],
        consequenceLevel: Double
    ) -> BASPowerGradient? {
        guard let roleGeometry else {
            return nil
        }

        let authorityPressure = manipulationHints.contains("authority_pressure") || isAuthorityRelation(roleGeometry.relationClass)
        let highConsequence = roleGeometry.asymmetryFlags.contains("high_consequence_relation")
        let baseStrength = (highConsequence ? 0.58 : 0.28)
            + (authorityPressure ? 0.14 : 0)
            + (request.riskLevel == .high ? 0.10 : 0)
            + min(0.12, consequenceLevel * 0.12)

        return BASPowerGradient(
            direction: authorityPressure || highConsequence ? "external_over_host" : "balanced",
            strength: min(1, baseStrength),
            sources: orderedUnique(
                ["request_context"]
                    + (highConsequence ? ["relationship_gravity"] : [])
                    + (authorityPressure ? ["authority"] : [])
            ),
            confidence: authorityPressure || highConsequence ? 0.82 : 0.56
        )
    }

    private func buildEmotionalWeather(
        userInput: String,
        emotionalLoad: Double,
        timePressure: Double
    ) -> BASEmotionalWeather {
        var dominantTones: [String] = []
        if timePressure > 0.7 {
            dominantTones.append("pressured")
        }
        if userInput.lowercased().contains("explain yourself") {
            dominantTones.append("defensive")
        }
        if dominantTones.isEmpty {
            dominantTones.append(request.workflowProfile == .reflective ? "reflective" : "focused")
        }

        return BASEmotionalWeather(
            dominantTones: dominantTones,
            intensity: emotionalLoad,
            volatility: min(1, emotionalLoad * 0.7 + timePressure * 0.2),
            pressureCoupling: min(1, (emotionalLoad + timePressure) / 2),
            judgmentDistortionRisk: min(1, emotionalLoad * 0.55 + timePressure * 0.35)
        )
    }

    private func buildUrgencyTruth(
        userInput: String,
        timePressure: Double,
        consequenceLevel: Double
    ) -> BASUrgencyTruth {
        let normalized = userInput.lowercased()
        let explicitUrgencyMarkers = ["now", "right now", "immediately", "urgent", "asap"]
        let statedUrgency = explicitUrgencyMarkers.contains(where: normalized.contains) ? max(0.82, timePressure) : timePressure
        let inferredUrgency = min(
            1,
            max(
                statedUrgency,
                consequenceLevel * 0.62 + (request.kind == .reopen ? 0.20 : 0)
            )
        )
        let authenticityScore = request.riskLevel == .high ? 0.82 : min(0.74, inferredUrgency)
        let canDelay = !(request.kind == .reopen || (statedUrgency > 0.75 && inferredUrgency > 0.70))

        return BASUrgencyTruth(
            statedUrgency: statedUrgency,
            inferredUrgency: inferredUrgency,
            authenticityScore: authenticityScore,
            canDelay: canDelay,
            windowDecay: min(1, inferredUrgency * 0.88)
        )
    }

    private func buildConsequenceHorizon(
        relationClass: String?,
        consequenceLevel: Double,
        hostRelevance: Double
    ) -> BASConsequenceHorizon {
        let impactScope = relationClass.map { "relationship:\($0)" } ?? "local"
        let reversibility = max(0.08, 1 - consequenceLevel)
        return BASConsequenceHorizon(
            impactScope: impactScope,
            reversibility: reversibility,
            publicPrivateDomain: request.surface == .application ? "private" : "mixed",
            shortTermRisk: consequenceLevel,
            longTermTrace: min(1, consequenceLevel * 0.72 + hostRelevance * 0.18)
        )
    }

    private func buildManipulationTrace(
        userInput: String,
        manipulationHints: [String],
        roleGeometry: BASRoleGeometry?,
        urgencyTruth: BASUrgencyTruth
    ) -> BASManipulationTrace? {
        let normalized = userInput.lowercased()
        let highLeverageRelation = roleGeometry.flatMap { geometry in
            let relation = geometry.relationClass
            return highConsequenceRelations.contains(where: { $0 == relation }) ? relation : nil
        }
        let shamePressure = normalized.contains("explain yourself") ? 0.54 : 0
        let confidence = min(
            1,
            Double(manipulationHints.count) * 0.22
                + (highLeverageRelation == nil ? 0 : 0.18)
                + (urgencyTruth.statedUrgency > 0.75 ? 0.18 : 0)
        )

        guard manipulationHints.isEmpty == false || shamePressure > 0 || highLeverageRelation != nil else {
            return nil
        }

        return BASManipulationTrace(
            traceID: "trace.\(request.kind.rawValue).\(request.workflowProfile.rawValue)",
            signals: orderedUnique(manipulationHints + (shamePressure > 0 ? ["shame_pressure"] : [])),
            gaslightPrecursor: manipulationHints.contains("history_rewrite"),
            shamePressure: shamePressure,
            authorityMask: roleGeometry.map { isAuthorityRelation($0.relationClass) } ?? false,
            timeCoercion: urgencyTruth.statedUrgency,
            relationalLeverage: highLeverageRelation.map { [$0] } ?? [],
            confidence: max(0.32, confidence)
        )
    }

    private func buildHostResonance(
        hostContext: BASHostProfile,
        relationClass: String?,
        hostRelevance: Double
    ) -> BASHostResonance {
        let relatedGoals = orderedUnique(
            hostContext.longTermGoals
                + (hostConstitution?.goalSpine.priorityOrder ?? [])
                + (hostConstitution?.goalSpine.goals ?? [])
        )
        let touchedBoundaries = orderedUnique(
            currentBrain.boundaryConstraints.map(\.rawValue)
                + hostContext.noGoZones
                + [currentBrain.boundaryHeadline]
        )
        let relationRefs = orderedUnique(
            hostConstitution?.relationGravity.highConsequenceLinks ?? []
                + hostContext.relationshipRefs
                + (relationClass.map { [$0] } ?? [])
        )
        let vulnerabilityFlags = orderedUnique(
            currentBrain.activeConstraints
                + currentBrain.riskFlags.map(\.rawValue)
        )

        return BASHostResonance(
            relatedGoals: relatedGoals,
            touchedBoundaries: touchedBoundaries,
            highConsequenceRelationRefs: relationRefs,
            rhythmStateRef: hostConstitution?.narrativeLoom.currentPhase ?? request.workflowProfile.rawValue,
            vulnerabilityGuardFlags: vulnerabilityFlags,
            intensity: hostRelevance
        )
    }

    private func buildContinuityAnchor(
        relationClass: String?,
        sceneType: BASContextSceneType
    ) -> BASContinuityAnchor {
        let relationArc = relationClass ?? currentBrain.relationshipBoundary
        return BASContinuityAnchor(
            anchorID: "l6.\(request.kind.rawValue).\(relationArc)",
            linkedTurns: orderedUnique(
                [request.kind.rawValue, request.workflowProfile.rawValue]
                    + (hostConstitution?.narrativeLoom.continuityLinks ?? [])
            ),
            sceneArc: "\(sceneType.rawValue):\(relationArc)",
            escalationPattern: request.kind == .reopen ? "reopen_escalation" : nil,
            unresolvedThreads: hostConstitution?.narrativeLoom.unresolvedTensions ?? []
        )
    }

    private func buildRouteHint(
        budget: BASBudgetFrame,
        taskType: BASContextTaskType,
        consequenceLevel: Double,
        manipulationTrace: BASManipulationTrace?,
        urgencyTruth: BASUrgencyTruth,
        powerGradient: BASPowerGradient?,
        hostRelevance: Double
    ) -> BASContextRouteHint {
        let manipulationConfidence = manipulationTrace?.confidence ?? 0
        let needGuard = request.riskLevel == .high
            || manipulationConfidence > 0.55
            || (powerGradient?.strength ?? 0) > 0.65
            || (urgencyTruth.canDelay == false && consequenceLevel > 0.7)
        let needDoublePath = taskType == .choice || consequenceLevel > 0.72
        let needMirror = request.workflowProfile == .reflective || (manipulationTrace?.confidence ?? 0) > 0.45
        let needMemory = request.kind == .reopen || hostRelevance > 0.62
        let preferredMode: String = if needGuard {
            "guarded"
        } else if needDoublePath {
            "comparative"
        } else if needMirror || budget.runMode == .reflect {
            "mirrored"
        } else {
            "direct"
        }

        return BASContextRouteHint(
            preferredMode: preferredMode,
            needMemory: needMemory,
            needMirror: needMirror,
            needDoublePath: needDoublePath,
            needGuard: needGuard,
            sovereignHintLevel: needGuard && consequenceLevel > 0.72 ? "elevated" : "normal"
        )
    }

    private func buildConfidenceBand(
        roleGeometry: BASRoleGeometry?,
        urgencyTruth: BASUrgencyTruth,
        ambiguityScore: Double,
        manipulationHints: [String]
    ) -> Double {
        let roleConfidence = roleGeometry == nil ? 0.06 : 0.18
        let urgencyConfidence = urgencyTruth.statedUrgency > 0.7 ? 0.12 : 0.05
        let manipulationConfidence = manipulationHints.isEmpty ? 0.04 : 0.10
        return min(
            0.92,
            max(
                0.24,
                0.40 + roleConfidence + urgencyConfidence + manipulationConfidence - (ambiguityScore * 0.14)
            )
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func resolvedRelationPattern() -> String {
        guard let hostConstitution else {
            return currentBrain.relationshipBoundary
        }

        let relationMarkers = hostConstitution.relationGravity.highConsequenceLinks.map {
            "high_consequence:\($0)"
        }
        let parts = orderedUnique([currentBrain.relationshipBoundary] + relationMarkers)
        return parts.joined(separator: "|")
    }

    private func constitutionGoalRelevanceIncrement() -> Double {
        guard let hostConstitution else { return 0 }

        let goalCount = hostConstitution.goalSpine.priorityOrder.count + hostConstitution.goalSpine.goals.count
        return min(0.24, Double(goalCount) * 0.04)
    }

    private func constitutionRelationRelevanceIncrement() -> Double {
        guard let hostConstitution else { return 0 }
        return hostConstitution.relationGravity.highConsequenceLinks.isEmpty ? 0 : 0.14
    }

    private func presenceRelationRelevanceIncrement(for relationClass: String?) -> Double {
        guard let relationClass else { return 0 }
        if highConsequenceRelations.contains(where: { $0 == relationClass }) {
            return 0.18
        }
        return isAuthorityRelation(relationClass) ? 0.10 : 0
    }

    private var highConsequenceRelations: [String] {
        orderedUnique(
            (hostConstitution?.relationGravity.highConsequenceLinks ?? [])
                + (hostConstitution?.relationGravity.nodes ?? [])
        )
    }

    private func detectedRelationClass(
        in userInput: String,
        relationPattern: String
    ) -> String {
        let tokens = Set(BASHostRuntimeEBrainPromptAnalyzer.tokenized(userInput))
        if let matchedRelation = highConsequenceRelations.first(where: { tokens.contains($0.lowercased()) }) {
            return matchedRelation
        }
        if let explicitAuthority = ["manager", "boss", "lead", "director", "client", "partner"].first(where: {
            tokens.contains($0)
        }) {
            return explicitAuthority
        }
        if let leadRelation = highConsequenceRelations.first {
            return leadRelation
        }
        if relationPattern.isEmpty == false {
            return relationPattern.components(separatedBy: "|").first ?? currentBrain.relationshipBoundary
        }
        return currentBrain.relationshipBoundary
    }

    private func roleType(for relationClass: String) -> String {
        isAuthorityRelation(relationClass) ? "authority_peer" : "relationship_peer"
    }

    private func isAuthorityRelation(_ relationClass: String) -> Bool {
        ["manager", "boss", "lead", "director", "teacher", "parent", "client"].contains(relationClass.lowercased())
    }

    private func intimacyDistance(for relationClass: String) -> Double {
        switch relationClass.lowercased() {
        case "partner", "parent":
            0.18
        case "manager", "boss", "lead", "director", "client":
            0.56
        default:
            0.42
        }
    }
}

private struct BASHostRuntimeEBrainDecomposeService: BASDecomposeServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let projection: BASBrainProjection
    let hostConstitution: BASHostConstitution?

    func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        let baseGoals = currentBrain.dominantGoals.isEmpty ? ["Keep the next move bounded."] : currentBrain.dominantGoals
        let facts = orderedUnique([
            "Host request: \(request.prompt)",
            "Workflow: \(currentBrain.workflowTitle)"
        ] + (request.detail.map { ["Detail: \($0)"] } ?? []) + constitutionFacts())
        let goals = orderedUnique(baseGoals + constitutionGoalLines())
        let emotions = inferredEmotions(from: contextFrame)
        let unknowns = inferredUnknowns()
        let contradictions = checkContradiction(
            contextFrame: contextFrame,
            decomposeFrame: BASDecomposeFrame()
        )
        let factShards = buildFactShards(from: facts)
        let claimShards = buildClaimShards(contextFrame: contextFrame)
        let goalSpineLocal = buildGoalSpineLocal(
            from: goals,
            contradictions: contradictions
        )
        let unknownRecords = buildUnknownRecords(from: unknowns)
        let contradictionRecords = buildContradictionRecords(from: contradictions)
        let pressureVectors = buildPressureVectors(contextFrame: contextFrame)
        let manipulationPatterns = buildManipulationPatterns(contextFrame: contextFrame)
        let boundaryTouches = buildBoundaryTouches(
            contextFrame: contextFrame,
            contradictions: contradictionRecords,
            manipulationPatterns: manipulationPatterns
        )
        let mirrorDraft = buildMirrorDraft(
            contextFrame: contextFrame,
            facts: facts,
            goals: goals,
            unknowns: unknowns,
            pressureVectors: pressureVectors,
            boundaryTouches: boundaryTouches
        )
        let canonicalFrame = buildCanonicalFrame(
            facts: facts,
            goals: goals,
            unknowns: unknowns,
            contradictionRecords: contradictionRecords,
            pressureVectors: pressureVectors,
            manipulationPatterns: manipulationPatterns,
            boundaryTouches: boundaryTouches
        )

        return BASDecomposeFrame(
            facts: facts,
            goals: goals,
            emotions: emotions,
            unknowns: unknowns,
            contradictions: contradictions,
            pressureSignals: orderedUnique(
                pressureVectors.map(legacyPressureSignal(for:))
                    + (contextFrame.manipulationHints.contains("time_pressure") ? ["time_pressure"] : [])
            ),
            manipulationSignals: orderedUnique(
                contextFrame.manipulationHints
                    + manipulationPatterns.map(legacyManipulationSignal(for:))
            ),
            mirrorText: mirrorDraft.summary,
            factShards: factShards,
            claimShards: claimShards,
            goalSpineLocal: goalSpineLocal,
            unknownRecords: unknownRecords,
            contradictionRecords: contradictionRecords,
            pressureVectors: pressureVectors,
            manipulationPatterns: manipulationPatterns,
            boundaryTouches: boundaryTouches,
            mirrorDraft: mirrorDraft,
            canonicalFrame: canonicalFrame
        )
    }

    func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        if let summary = decomposeFrame.mirrorDraft?.summary, summary.isEmpty == false {
            return summary
        }
        if let hostConstitution,
           let leadRelation = hostConstitution.relationGravity.highConsequenceLinks.first {
            return "The host is asking for a \(currentBrain.workflowTitle.lowercased()) pass, and the system should keep \(leadRelation) context visible while staying bounded before acting."
        }
        return "The host is asking for a \(currentBrain.workflowTitle.lowercased()) pass, but the system should keep the next move bounded before acting."
    }

    func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        let referenceTerms = currentBrain.activeConstraints
            + currentBrain.boundaryConstraints.map(\.rawValue)
            + currentBrain.calibrationAlerts.map { $0.rawValue }
        var contradictions = referenceTerms.filter { constraint in
            let normalizedConstraint = constraint.lowercased()
            return BASHostRuntimeEBrainPromptAnalyzer.tokenized(request.prompt).contains {
                normalizedConstraint.contains($0)
            }
        }
        if request.riskLevel >= .high && currentBrain.hasEvidenceCaveatLoad {
            contradictions.append("evidence strength conflicts with action urgency")
        }
        if contextFrame.timePressure > 0.75 && currentBrain.hasProtectiveBoundary {
            contradictions.append("timing pressure conflicts with bounded action")
        }
        return orderedUnique(contradictions)
    }

    private func inferredEmotions(from contextFrame: BASContextFrame) -> [String] {
        if request.riskLevel == .high {
            return currentBrain.calibrationStatus == .drifting ? ["elevated_pressure", "trust_drift"] : ["elevated_pressure"]
        }
        if contextFrame.taskType == .choice {
            return ["uncertainty"]
        }
        if request.workflowProfile == .reflective {
            return ["reflective"]
        }
        return ["focused"]
    }

    private func inferredUnknowns() -> [String] {
        var unknowns: [String] = []
        if projection.records.isEmpty {
            unknowns.append("No governed records were loaded for this turn.")
        }
        if request.riskLevel >= .medium {
            unknowns.append("Need more evidence before any irreversible move.")
        }
        if request.workflowProfile == .comparative {
            unknowns.append("The best tradeoff is not fully resolved yet.")
        }
        if currentBrain.calibrationStatus == .drifting {
            unknowns.append("Calibration drift suggests the turn should keep more uncertainty visible.")
        }
        if currentBrain.hasEvidenceCaveatLoad {
            unknowns.append("Evidence remains caveated, so the turn should keep uncertainty explicit.")
        }
        return unknowns
    }

    private func constitutionFacts() -> [String] {
        guard let hostConstitution else { return [] }

        var facts: [String] = []
        if hostConstitution.narrativeLoom.currentPhase.isEmpty == false {
            facts.append("Constitution phase: \(hostConstitution.narrativeLoom.currentPhase)")
        }
        if hostConstitution.relationGravity.highConsequenceLinks.isEmpty == false {
            facts.append(
                "High-consequence relations: \(hostConstitution.relationGravity.highConsequenceLinks.joined(separator: ", "))"
            )
        }
        if hostConstitution.goalSpine.stageState.isEmpty == false {
            facts.append("Goal spine stage: \(hostConstitution.goalSpine.stageState)")
        }
        return facts
    }

    private func constitutionGoalLines() -> [String] {
        guard let hostConstitution else { return [] }

        let goalLines = hostConstitution.goalSpine.priorityOrder + hostConstitution.goalSpine.goals
        return orderedUnique(goalLines).map { "Honor constitution goal: \($0)" }
    }

    private func buildFactShards(
        from facts: [String]
    ) -> [BASFactShard] {
        facts.enumerated().map { index, fact in
            BASFactShard(
                shardID: "fact-\(index + 1)",
                text: fact,
                status: .reported,
                sourceKind: sourceKind(for: fact),
                certainty: sourceKind(for: fact) == .systemInference ? 0.62 : 0.84,
                timeScope: "current_turn"
            )
        }
    }

    private func buildClaimShards(
        contextFrame: BASContextFrame
    ) -> [BASClaimShard] {
        var claims: [BASClaimShard] = [
            BASClaimShard(
                claimID: "claim-command-1",
                text: request.prompt,
                claimType: .command,
                supportLevel: 0.92,
                sourceKind: .currentInput,
                sourceRef: "prompt"
            )
        ]
        if let detail = request.detail, detail.isEmpty == false {
            claims.append(
                BASClaimShard(
                    claimID: "claim-detail-1",
                    text: detail,
                    claimType: .factClaim,
                    supportLevel: 0.66,
                    sourceKind: .sessionDetail,
                    sourceRef: "detail"
                )
            )
        }
        if contextFrame.taskType == .manipulationRisk {
            claims.append(
                BASClaimShard(
                    claimID: "claim-risk-1",
                    text: "Current turn contains coercive or authority-shaped steering pressure.",
                    claimType: .accusation,
                    supportLevel: 0.57,
                    sourceKind: .systemInference,
                    sourceRef: "context.analysis"
                )
            )
        }
        return claims
    }

    private func buildGoalSpineLocal(
        from goals: [String],
        contradictions: [String]
    ) -> BASGoalSpineLocal? {
        guard goals.isEmpty == false else { return nil }
        let surfaceGoals = Array(goals.prefix(2))
        let midGoals = goals.count > 2 ? [goals[2]] : surfaceGoals
        let deepFallback = hostConstitution?.goalSpine.priorityOrder.first
            ?? currentBrain.dominantGoals.first
            ?? "Keep the next move bounded."
        return BASGoalSpineLocal(
            surfaceGoals: orderedUnique(surfaceGoals),
            midGoals: orderedUnique(midGoals),
            deepGoals: [deepFallback],
            conflicts: contradictions,
            hostAlignmentScore: hostConstitution == nil ? 0.71 : 0.84
        )
    }

    private func buildUnknownRecords(
        from unknowns: [String]
    ) -> [BASUnknownRecord] {
        unknowns.enumerated().map { index, unknown in
            BASUnknownRecord(
                unknownID: "unknown-\(index + 1)",
                kind: unknownKind(for: unknown),
                summary: unknown,
                sourceKind: .systemInference,
                blocking: true
            )
        }
    }

    private func buildContradictionRecords(
        from contradictions: [String]
    ) -> [BASContradictionRecord] {
        contradictions.enumerated().map { index, contradiction in
            BASContradictionRecord(
                nodeID: "contradiction-\(index + 1)",
                kind: contradictionKind(for: contradiction),
                summary: contradiction,
                refs: ["prompt", "constraints"],
                severity: request.riskLevel == .high ? 0.78 : 0.63,
                unresolved: true
            )
        }
    }

    private func buildPressureVectors(
        contextFrame: BASContextFrame
    ) -> [BASPressureVector] {
        var vectors: [BASPressureVector] = []
        if contextFrame.timePressure > 0.45 {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-time",
                    kind: .time,
                    direction: .compressing,
                    strength: contextFrame.timePressure,
                    authenticity: max(0.55, contextFrame.timePressure),
                    sourceRef: "context.timePressure"
                )
            )
        }
        if contextFrame.relationPattern.contains("high_consequence")
            || hostConstitution?.relationGravity.highConsequenceLinks.isEmpty == false {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-relationship",
                    kind: .relationship,
                    direction: .leveraging,
                    strength: max(0.58, contextFrame.hostRelevance),
                    authenticity: 0.78,
                    sourceRef: "context.relationPattern"
                )
            )
        }
        if contextFrame.consequenceLevel > 0.45 || request.riskLevel >= .medium {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-consequence",
                    kind: .consequence,
                    direction: .amplifying,
                    strength: max(contextFrame.consequenceLevel, request.riskLevel == .high ? 0.82 : 0.58),
                    authenticity: 0.73,
                    sourceRef: "request.riskLevel"
                )
            )
        }
        if currentBrain.hasProtectiveBoundary || currentBrain.failureGuardCount > 0 {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-responsibility",
                    kind: .responsibility,
                    direction: .constraining,
                    strength: min(1, 0.46 + (Double(currentBrain.failureGuardCount) * 0.08)),
                    authenticity: 0.86,
                    sourceRef: "currentBrain.guardrails"
                )
            )
        }
        return vectors
    }

    private func buildManipulationPatterns(
        contextFrame: BASContextFrame
    ) -> [BASManipulationPattern] {
        orderedUnique(contextFrame.manipulationHints).enumerated().map { index, hint in
            BASManipulationPattern(
                patternID: "manipulation-\(index + 1)",
                kind: manipulationKind(for: hint),
                summary: hint,
                refs: ["context.manipulationHints"],
                confidence: hint == "authority_pressure" ? 0.76 : max(0.58, contextFrame.timePressure)
            )
        }
    }

    private func legacyPressureSignal(
        for vector: BASPressureVector
    ) -> String {
        switch vector.kind {
        case .time:
            "time_pressure"
        case .relationship:
            "relationship_pressure"
        case .shame:
            "shame_pressure"
        case .consequence:
            "consequence_pressure"
        case .resource:
            "resource_pressure"
        case .responsibility:
            "responsibility_pressure"
        }
    }

    private func legacyManipulationSignal(
        for pattern: BASManipulationPattern
    ) -> String {
        switch pattern.kind {
        case .gaslightPrecursor:
            "history_rewrite"
        case .shame:
            "shame_pressure"
        case .authorityMask:
            "authority_pressure"
        case .coerciveUrgency:
            "time_pressure"
        case .relationalLeverage:
            "relational_leverage"
        }
    }

    private func buildBoundaryTouches(
        contextFrame: BASContextFrame,
        contradictions: [BASContradictionRecord],
        manipulationPatterns: [BASManipulationPattern]
    ) -> [BASBoundaryTouch] {
        var touches: [BASBoundaryTouch] = []
        if currentBrain.boundaryConstraints.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-host",
                    domain: .host,
                    level: contextFrame.consequenceLevel > 0.7 ? .breachRisk : .approach,
                    summary: "Host boundary constraints are active for this turn.",
                    refs: currentBrain.boundaryConstraints.map(\.rawValue)
                )
            )
        }
        if currentBrain.hasProtectiveBoundary || contradictions.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-system",
                    domain: .system,
                    level: contradictions.isEmpty ? .brush : .approach,
                    summary: "System guardrails should stay visible before committing.",
                    refs: contradictions.map(\.summary)
                )
            )
        }
        if request.riskLevel >= .high && manipulationPatterns.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-sovereign",
                    domain: .sovereign,
                    level: .approach,
                    summary: "High-risk steering pressure is nearing sovereign review territory.",
                    refs: manipulationPatterns.map(\.summary)
                )
            )
        }
        return touches
    }

    private func buildMirrorDraft(
        contextFrame: BASContextFrame,
        facts: [String],
        goals: [String],
        unknowns: [String],
        pressureVectors: [BASPressureVector],
        boundaryTouches: [BASBoundaryTouch]
    ) -> BASMirrorDraft {
        let mode: BASMirrorMode = request.riskLevel >= .high || boundaryTouches.isEmpty == false ? .hard : .soft
        let leadPressure = pressureVectors.first?.kind.rawValue ?? "pressure"
        let leadGoal = goals.first ?? "keep the next move bounded"
        let leadRelation = hostConstitution?.relationGravity.highConsequenceLinks.first
            ?? contextFrame.relationPattern

        let summary: String
        if mode == .hard {
            summary = "This turn carries \(leadPressure) around \(leadRelation), and the system should mirror the pressure, keep \(leadGoal.lowercased()) visible, and check missing facts before committing."
        } else {
            summary = "This turn is asking for a \(currentBrain.workflowTitle.lowercased()) pass, so the system should keep \(leadGoal.lowercased()) visible before acting."
        }

        return BASMirrorDraft(
            draftID: "mirror-1",
            mode: mode,
            summary: summary,
            calibrationPoints: Array(facts.prefix(2)),
            omittedSpeculations: unknowns,
            toneGuard: mode == .hard ? "calibration_before_commit" : "gentle_calibration"
        )
    }

    private func buildCanonicalFrame(
        facts: [String],
        goals: [String],
        unknowns: [String],
        contradictionRecords: [BASContradictionRecord],
        pressureVectors: [BASPressureVector],
        manipulationPatterns: [BASManipulationPattern],
        boundaryTouches: [BASBoundaryTouch]
    ) -> BASCanonicalCognitiveFrame {
        let routeHint: String
        if request.riskLevel >= .high || boundaryTouches.contains(where: { $0.domain == .sovereign }) {
            routeHint = "mirror_before_commit"
        } else if unknowns.isEmpty == false {
            routeHint = "clarify_unknowns"
        } else {
            routeHint = "bounded_continue"
        }

        return BASCanonicalCognitiveFrame(
            ccfID: "ccf-1",
            stableFacts: facts,
            activeGoals: goals,
            activeUnknowns: unknowns,
            keyPressures: orderedUnique(pressureVectors.map { $0.kind.rawValue }),
            keyContradictions: contradictionRecords.map(\.summary),
            manipulationWatch: orderedUnique(manipulationPatterns.map { $0.kind.rawValue }),
            boundaryWatch: boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" },
            routeHint: routeHint
        )
    }

    private func sourceKind(
        for fact: String
    ) -> BASDecomposeSourceKind {
        if fact.hasPrefix("Host request:") {
            return .currentInput
        }
        if fact.hasPrefix("Detail:") {
            return .sessionDetail
        }
        if fact.hasPrefix("Workflow:") {
            return .workflowState
        }
        if fact.hasPrefix("Constitution ")
            || fact.hasPrefix("High-consequence relations:")
            || fact.hasPrefix("Goal spine stage:") {
            return .hostConstitution
        }
        return .systemInference
    }

    private func unknownKind(
        for unknown: String
    ) -> BASUnknownKind {
        let normalized = unknown.lowercased()
        if normalized.contains("permission") || normalized.contains("authorized") {
            return .unresolvedPermission
        }
        if normalized.contains("constraint") {
            return .missingConstraint
        }
        if normalized.contains("role") || normalized.contains("other side") {
            return .missingRole
        }
        if normalized.contains("ambig") || normalized.contains("uncertain") {
            return .ambiguity
        }
        return .missingFact
    }

    private func contradictionKind(
        for contradiction: String
    ) -> BASContradictionKind {
        let normalized = contradiction.lowercased()
        if normalized.contains("history") {
            return .historical
        }
        if normalized.contains("evidence") || normalized.contains("support") {
            return .evidential
        }
        if normalized.contains("role") || normalized.contains("boundary") {
            return .role
        }
        return .textual
    }

    private func manipulationKind(
        for hint: String
    ) -> BASManipulationKind {
        let normalized = hint.lowercased()
        if normalized.contains("gaslight") {
            return .gaslightPrecursor
        }
        if normalized.contains("shame") {
            return .shame
        }
        if normalized.contains("authority") {
            return .authorityMask
        }
        if normalized.contains("relation") {
            return .relationalLeverage
        }
        return .coerciveUrgency
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainMemoryService: BASMemoryServicing {
    let projection: BASBrainProjection
    let currentBrain: BASHostCurrentBrain
    let hostConstitution: BASHostConstitution?

    func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        let recordAtoms = projection.records.prefix(budget.retrievalDepth).map(memoryAtom(from:))
        let eventAtoms = projection.recentEvents.prefix(max(0, budget.retrievalDepth - recordAtoms.count)).map(memoryAtom(from:))
        let atoms = Array(recordAtoms) + Array(eventAtoms)

        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: orderedUnique(
                projection.records.prefix(budget.retrievalDepth).flatMap { [$0.kind.rawValue, $0.sourceType] }
                    + projection.recentEvents.flatMap(\.tags)
                    + currentBrain.retrievalTags
                    + [currentBrain.boundaryMode.rawValue]
                    + currentBrain.riskFlags.map(\.rawValue)
                    + constitutionRetrievalTags()
            ),
            conflictRefs: atoms.filter(\.frozen).map(\.memoryID),
            activeHostVersion: hostContext.activeVersion
        )
    }

    func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        atom.frozen ? .frozen : atom.promotionState
    }

    func freeze(memoryID: String) -> Bool {
        projection.records.contains { $0.id.uuidString == memoryID && $0.sensitivity == .high }
    }

    private func memoryAtom(from record: BASGovernedMemory) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: record.id.uuidString,
            summary: record.content,
            contentType: contentType(for: record.tier),
            source: record.sourceType,
            timestamp: record.lastConfirmedAt ?? .now,
            confidence: record.confidence,
            emotionalWeight: record.kind == .semantic ? 0.55 : 0.22,
            riskRelevance: record.sensitivity == .high ? 0.82 : 0.38,
            hostRelevance: record.kind == .profile ? 0.88 : 0.54,
            conflictFingerprint: record.id.uuidString,
            promotionState: promotionState(for: record.governanceStatus),
            frozen: record.governanceStatus == .archived
        )
    }

    private func memoryAtom(from event: BASEventRecord) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: event.id.uuidString,
            summary: event.content,
            contentType: .hot,
            source: event.entrySourceID ?? "event",
            timestamp: event.timestamp,
            confidence: 0.72,
            emotionalWeight: event.kind == .semantic ? 0.55 : 0.20,
            riskRelevance: event.kind == .situational ? 0.48 : 0.28,
            hostRelevance: 0.52,
            conflictFingerprint: event.id.uuidString,
            promotionState: .candidate,
            frozen: false
        )
    }

    private func contentType(for tier: BASMemoryTier) -> BASMemoryAtomContentType {
        switch tier {
        case .hot:
            .hot
        case .warm:
            .warm
        case .cold:
            .cold
        }
    }

    private func promotionState(for status: BASMemoryGovernanceStatus) -> BASPromotionState {
        switch status {
        case .candidate:
            .candidate
        case .governed:
            .admitted
        case .archived:
            .frozen
        case .quarantined, .rejected:
            .retired
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func constitutionRetrievalTags() -> [String] {
        guard let hostConstitution else { return [] }

        var tags: [String] = []
        if hostConstitution.goalSpine.stageState.isEmpty == false {
            tags.append("constitution_goal_stage:\(hostConstitution.goalSpine.stageState)")
        }
        tags += hostConstitution.relationGravity.highConsequenceLinks.map {
            "constitution_relation_high_consequence:\($0)"
        }
        if hostConstitution.consentLattice.memoryPromotionScope.isEmpty == false {
            tags.append("constitution_memory_promotion:\(hostConstitution.consentLattice.memoryPromotionScope)")
        }
        return tags
    }
}

private struct BASHostRuntimeEBrainNeuralCoreService: BASNeuralCoreServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func synthesize(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASNeuralCoreFrame {
        let morph = resolvedMorph(
            budgetFrame: budgetFrame,
            contextFrame: contextFrame
        )
        let organMap = BASNeuralOrganMap(
            morph: morph,
            activeOrgans: activeOrgans(for: morph),
            precisionMap: activeOrgans(for: morph).map { organ in
                BASNeuralOrganPrecision(
                    organ: organ,
                    tier: precisionTier(
                        for: organ,
                        morph: morph,
                        precisionProfile: budgetFrame.precisionProfile
                    )
                )
            },
            routingPolicy: routingPolicy(for: morph),
            leaseRef: budgetFrame.leaseID,
            sovereignConstraints: activeKillSwitches.map(\.rawValue),
            headGuarantees: headGuarantees(for: morph)
        )
        let tissueState = BASLatentTissueState(
            scoutState: organMap.activeOrgans.contains(.scoutStrip) ? "task:\(contextFrame.taskType.rawValue)" : nil,
            cortexState: organMap.activeOrgans.contains(.coreCortex) ? "facts:\(decomposeFrame.facts.count)" : nil,
            simuState: organMap.activeOrgans.contains(.simuRing) ? "profile:\(request.workflowProfile.rawValue)" : nil,
            criticState: organMap.activeOrgans.contains(.criticBlade) ? "alerts:\(currentBrain.calibrationAlerts.count)" : nil,
            riskState: organMap.activeOrgans.contains(.riskSpine) ? "risk:\(request.riskLevel.rawValue)" : nil,
            permitState: organMap.activeOrgans.contains(.permitKnot) ? "kills:\(activeKillSwitches.count)" : nil,
            memoryCodecState: organMap.activeOrgans.contains(.memoryCodecRidge) ? "atoms:\(memoryBundle.atoms.count)" : nil,
            hostModState: organMap.activeOrgans.contains(.hostModulationMesh) ? "tone:\(hostProfile.tonePreference)" : nil,
            toolIntentState: organMap.activeOrgans.contains(.toolIntentMesh) ? "intent:bounded" : nil,
            consistencyState: organMap.activeOrgans.contains(.consistencyLattice) ? "stable" : nil,
            stubState: organMap.activeOrgans.contains(.stubCore) ? "stub_ready" : nil
        )
        var degradedReasonCodes: [String] = []
        if morph == .guard && currentBrain.hasProtectiveBoundary {
            degradedReasonCodes.append("host.protective_boundary")
        }
        if morph == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }
        if morph == .stub {
            degradedReasonCodes.append("runtime.stub_only")
        }
        return BASNeuralCoreFrame(
            organMap: organMap,
            tissueState: tissueState,
            degradedReasonCodes: degradedReasonCodes
        )
    }

    func materializeRiskBindings(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding] {
        BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                let riskTuning = tuning.risk
                switch score {
                case ..<riskTuning.mediumThreshold:
                    return .low
                case ..<riskTuning.highThreshold:
                    return .medium
                case ..<riskTuning.extremeThreshold:
                    return .high
                default:
                    return .extreme
                }
            }
        )
    }

    func materializeToolIntent(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        guard var envelope = BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: actionPermit
        ) else {
            return nil
        }

        guard let hostConstitution else {
            return envelope
        }

        let restrictedDomains = constitutionRestrictedToolDomains(in: hostConstitution)
        if restrictedDomains.isEmpty == false {
            envelope.blockedDomains = orderedUnique(envelope.blockedDomains + restrictedDomains)
            let blocked = Set(envelope.blockedDomains)
            envelope.requestedDomains = envelope.requestedDomains.filter { blocked.contains($0) == false }
            envelope.reasonCodes = orderedUnique(
                envelope.reasonCodes + ["constitution.tool_domain_restricted"]
            )
        }

        if hostConstitution.consentLattice.toolWriteScope == "confirm_required" {
            envelope.requireSecondCheck = true
            envelope.reasonCodes = orderedUnique(
                envelope.reasonCodes + ["constitution.tool_write_scope.confirm_required"]
            )
        }

        return envelope
    }

    private func resolvedMorph(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame
    ) -> BASNeuralMorph {
        switch budgetFrame.runMode {
        case .dormant, .pulse, .sentinel:
            return .scout
        case .engage, .reflect:
            if request.workflowProfile == .comparative || (contextFrame.taskType == .choice && budgetFrame.maxCandidates > 1) {
                return .compare
            }
            return .engage
        case .deepLoop:
            return .deepLoop
        case .guard:
            return .guard
        case .recovery:
            return .rollbackRebuild
        case .quarantine:
            return .quarantine
        case .lockdown:
            return .stub
        }
    }

    private func activeOrgans(
        for morph: BASNeuralMorph
    ) -> [BASNeuralOrgan] {
        switch morph {
        case .scout:
            return [.scoutStrip, .riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .engage:
            return [.coreCortex, .hostModulationMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .compare:
            return [.coreCortex, .simuRing, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .deepLoop:
            return [.coreCortex, .simuRing, .criticBlade, .riskSpine, .permitKnot, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .guard:
            return [.coreCortex, .criticBlade, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .stub:
            return [.riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .quarantine:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        case .rollbackRebuild:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        }
    }

    private func routingPolicy(
        for morph: BASNeuralMorph
    ) -> BASNeuralRoutingPolicy {
        switch morph {
        case .scout:
            return .scoutProbe
        case .engage:
            return .conversationalBalance
        case .compare:
            return .comparativeFanout
        case .deepLoop:
            return .deepLoopConvergence
        case .guard:
            return .protectiveThrottle
        case .stub:
            return .stubOnly
        case .quarantine:
            return .quarantineIsolation
        case .rollbackRebuild:
            return .rollbackRecovery
        }
    }

    private func headGuarantees(
        for morph: BASNeuralMorph
    ) -> [String] {
        switch morph {
        case .scout:
            return ["risk_binding", "stub_ready"]
        case .engage:
            return ["host_modulation", "stub_ready"]
        case .compare:
            return ["frontier_projection", "risk_binding", "stub_ready"]
        case .deepLoop:
            return ["frontier_projection", "counterfactual_projection", "critique_projection", "risk_binding", "stub_ready"]
        case .guard:
            return ["risk_binding", "permit_gate", "stub_ready"]
        case .stub:
            return ["risk_binding", "stub_ready"]
        case .quarantine:
            return ["risk_binding", "memory_isolation", "stub_ready"]
        case .rollbackRebuild:
            return ["recovery_rebuild", "risk_binding", "stub_ready"]
        }
    }

    private func precisionTier(
        for organ: BASNeuralOrgan,
        morph: BASNeuralMorph,
        precisionProfile: BASRuntimePrecisionProfile
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return .full
        case .riskSpine, .permitKnot:
            return precisionProfile == .full ? .full : .protected
        case .tissueRouter, .consistencyLattice:
            return morph == .guard || morph == .stub || morph == .quarantine ? .protected : .balanced
        case .simuRing, .criticBlade:
            return morph == .deepLoop ? .protected : .balanced
        case .scoutStrip:
            return .minimal
        case .coreCortex:
            switch precisionProfile {
            case .minimal:
                return .minimal
            case .balanced:
                return .balanced
            case .protected:
                return .protected
            case .full:
                return .full
            }
        case .memoryCodecRidge, .hostModulationMesh:
            return .balanced
        case .toolIntentMesh:
            return .minimal
        }
    }

    private func constitutionRestrictedToolDomains(
        in hostConstitution: BASHostConstitution
    ) -> [String] {
        orderedUnique(
            hostConstitution.boundaryVeil.restrictedToolDomains
                + hostConstitution.consentLattice.sensitiveDomainRules
        )
    }

    private func orderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainLoopService: BASLoopServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        let directConfidence = min(
            currentBrain.confidenceCeiling,
            request.riskLevel == .high ? 0.42 : 0.72
        )
        let guardrailPressure = currentBrain.hostGuardrailPressure(using: tuning)
        let directCostBoost = guardrailPressure + min(
            tuning.guardrailPressure.failureGuardCap,
            Double(currentBrain.failureGuardCount) * tuning.guardrailPressure.failureGuardUnit
        )
        let direct = BASCandidatePath(
            candidateID: "path.direct",
            title: directTitle,
            actionSummary: "Move directly with the host's current workflow and minimal friction.",
            requiredEvidence: request.riskLevel >= .medium ? ["Confirm the missing facts first."] : [],
            expectedBenefit: request.workflowProfile == .primary ? 0.82 : 0.64,
            expectedCost: min(1, (request.riskLevel == .high ? 0.70 : 0.28) + directCostBoost),
            reversibility: max(0.12, (request.riskLevel == .high ? 0.34 : 0.74) - guardrailPressure * 0.35),
            confidence: directConfidence
        )
        let bounded = BASCandidatePath(
            candidateID: "path.bounded",
            title: boundedTitle,
            actionSummary: "Slow the decision down, keep the boundary visible, and ask for the next safest move.",
            requiredEvidence: ["Clarify one missing fact before committing."],
            expectedBenefit: min(1, (request.riskLevel == .high ? 0.86 : 0.74) + guardrailPressure * 0.25),
            expectedCost: 0.32,
            reversibility: min(1, 0.86 + guardrailPressure * 0.10),
            confidence: min(currentBrain.confidenceCeiling + 0.18, 0.84)
        )
        let reflective = BASCandidatePath(
            candidateID: "path.reflective",
            title: "Mirror the pressure before committing",
            actionSummary: "Name the tradeoff and the pressure signal before acting.",
            requiredEvidence: ["Keep the unknowns visible."],
            expectedBenefit: 0.70,
            expectedCost: 0.26,
            reversibility: 0.91,
            confidence: min(currentBrain.confidenceCeiling + 0.12, 0.78)
        )

        return Array([direct, bounded, reflective].prefix(budget.maxCandidates))
    }

    func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem] {
        return candidates.map { candidate in
            let highConsequenceRelations = constitutionHighConsequenceRelations()
            return BASForecastItem(
                candidateID: candidate.candidateID,
                shortTermOutcome: candidate.candidateID == "path.direct"
                    ? "Fast movement with thinner safety margin."
                    : "More friction, but a clearer next step.",
                midTermOutcome: candidate.candidateID == "path.direct"
                    ? "Higher chance of avoidable rework."
                    : "Better odds of a bounded decision that matches host intent.",
                worstCase: candidate.candidateID == "path.direct"
                    ? directWorstCase(highConsequenceRelations: highConsequenceRelations)
                    : "The host feels slowed down more than expected.",
                uncertainty: candidate.candidateID == "path.direct" ? 0.58 : 0.34,
                affectedRelations: orderedUnique(
                    [memoryBundle.activeHostVersion ?? "host.current"] + highConsequenceRelations
                )
            )
        }
    }

    func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        return candidates.map { candidate in
            let baseSeverity = candidate.candidateID == "path.direct" && hostContext.noGoZones.count > 1 ? 0.72 : 0.40
            return BASCritiqueItem(
                candidateID: candidate.candidateID,
                critiqueType: critiqueType(for: candidate),
                critiqueText: critiqueText(for: candidate),
                severity: min(1, baseSeverity + constitutionCritiqueSeverityIncrement(for: candidate))
            )
        }
    }

    func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame {
        let candidates = proposePaths(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: budget
        )
        let forecasts = forecast(
            candidates: candidates,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle
        )
        let critiques = critique(
            candidates: candidates,
            forecasts: forecasts,
            hostContext: BASHostProfile(hostID: memoryBundle.activeHostVersion ?? "host.runtime")
        )
        return BASThoughtFrame(
            stepIndex: min(
                budget.maxLoops,
                max(
                    1,
                    request.riskLevel == .high || currentBrain.isCalibrationUnstable
                        ? min(3, budget.maxLoops)
                        : 1
                )
            ),
            decomposeRef: "hostkit.decompose",
            memoryRefs: memoryBundle.atoms.map(\.memoryID),
            candidates: candidates,
            forecasts: forecasts,
            critiques: critiques,
            stabilityScore: max(0.36, (request.riskLevel == .high ? 0.68 : 0.84) - currentBrain.hostGuardrailPressure(using: tuning) * 0.20),
            stopReason: request.riskLevel == .high || currentBrain.calibrationStatus == .drifting
                ? .riskConverged
                : .candidateStable
        )
    }

    private var directTitle: String {
        switch request.workflowProfile {
        case .primary:
            "Direct host answer"
        case .comparative:
            "Choose the strongest path now"
        case .reflective:
            "Reflect without adding extra structure"
        }
    }

    private var boundedTitle: String {
        switch request.riskLevel {
        case .high:
            "Delay and hold the boundary"
        case .medium:
            "Compare before committing"
        case .low:
            "Answer with one bounded next step"
        }
    }

    private func critiqueType(for candidate: BASCandidatePath) -> BASCritiqueType {
        if candidate.candidateID == "path.direct" && request.riskLevel == .high {
            return .boundaryConflict
        }
        if candidate.candidateID == "path.direct" {
            return .evidenceGap
        }
        return .emotionalBias
    }

    private func critiqueText(for candidate: BASCandidatePath) -> String {
        if candidate.candidateID == "path.direct" && request.riskLevel == .high {
            return "Direct movement is too likely to outrun the active boundary."
        }
        if candidate.candidateID == "path.direct",
           let relationSummary = constitutionHighConsequenceRelationSummary() {
            return "The direct path risks outrunning the high-consequence relation around \(relationSummary)."
        }
        if candidate.candidateID == "path.direct" && currentBrain.hasProtectiveBoundary {
            return "The direct path conflicts with the host's protective boundary mode."
        }
        if candidate.candidateID == "path.direct" {
            return "The direct path still has thin evidence."
        }
        return "This path is safer, but it adds friction."
    }

    private func constitutionCritiqueSeverityIncrement(
        for candidate: BASCandidatePath
    ) -> Double {
        guard candidate.candidateID == "path.direct",
              let hostConstitution else {
            return 0
        }

        var increment = 0.0
        if hostConstitution.relationGravity.highConsequenceLinks.isEmpty == false {
            increment += 0.16
        }
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            increment += 0.08
        }
        return min(0.28, increment)
    }

    private func constitutionHighConsequenceRelationSummary() -> String? {
        let links = constitutionHighConsequenceRelations()
        guard links.isEmpty == false else { return nil }
        return links.joined(separator: ", ")
    }

    private func constitutionHighConsequenceRelations() -> [String] {
        hostConstitution?.relationGravity.highConsequenceLinks ?? []
    }

    private func directWorstCase(highConsequenceRelations: [String]) -> String {
        guard highConsequenceRelations.isEmpty == false else {
            return "The turn overshoots the boundary."
        }

        return "The turn overshoots the boundary and distorts context around \(highConsequenceRelations.joined(separator: ", "))."
    }

    private func constitutionPrefersBoundedAction(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        let descriptors = hostConstitution.goalSpine.priorityOrder
            + hostConstitution.goalSpine.goals
            + hostConstitution.goalSpine.conflictPairs
        return descriptors.contains { descriptor in
            let normalized = descriptor.lowercased()
            return normalized.contains("bounded")
                || normalized.contains("compare")
                || normalized.contains("reflect")
                || normalized.contains("review")
                || normalized.contains("protect")
                || normalized.contains("slow")
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainTriSelfService: BASTriSelfServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let triSelfTuning = tuning.triSelf
        let evaluatedScores = thoughtFrame.candidates.map { candidate -> (score: BASTriSelfScore, vetoReasonCodes: [String]) in
            let initiativeLift = currentBrain.identityInitiative == .assertive ? triSelfTuning.assertiveInitiativeLift : 0
            let idScore = candidate.expectedBenefit
                - candidate.expectedCost * triSelfTuning.idCostWeight
                + initiativeLift
                + constitutionCandidateBoost(for: candidate)
            let egoScore = candidate.reversibility * triSelfTuning.egoReversibilityWeight
                + min(candidate.confidence, currentBrain.confidenceCeiling) * triSelfTuning.egoConfidenceWeight
            let superegoPenalty = candidate.candidateID == "path.direct" && (request.riskLevel == .high || currentBrain.hasProtectiveBoundary)
                ? triSelfTuning.directPathSuperegoPenalty
                : 0
            let superegoScore = max(0, candidate.reversibility - superegoPenalty - constitutionSuperegoPenalty(for: candidate))
            let candidateVetoReasonCodes = vetoReasonCodes(for: candidate)
            let postureWeights: BASEBrainRuntimeSynthesisPolicy.TriSelfWeightProfile = switch currentBrain.identityPosture {
            case .reflective:
                triSelfTuning.reflectiveWeights
            case .coaching:
                triSelfTuning.coachingWeights
            case .protective:
                triSelfTuning.protectiveWeights
            }
            let mergedScore = max(
                0,
                (idScore * postureWeights.id)
                    + (egoScore * postureWeights.ego)
                    + (superegoScore * postureWeights.superego)
            )
            let score = BASTriSelfScore(
                candidateID: candidate.candidateID,
                idScore: idScore,
                egoScore: egoScore,
                superegoScore: superegoScore,
                mergedScore: mergedScore,
                veto: !candidateVetoReasonCodes.isEmpty
            )
            return (score, candidateVetoReasonCodes)
        }

        let scores = evaluatedScores.map { $0.score }
        let aggregatedVetoReasonCodes = unique(
            evaluatedScores
                .filter { $0.score.veto }
                .flatMap { $0.vetoReasonCodes }
        )
        let nonVetoScores = scores.filter { !$0.veto }
        let selectedScore: BASTriSelfScore?
        if let preferredScore = nonVetoScores.max(by: isLowerMergedScore(_:_:)) {
            selectedScore = preferredScore
        } else {
            selectedScore = scores.max(by: isLowerMergedScore(_:_:))
        }

        let selectedCandidate = thoughtFrame.candidates.first {
            $0.candidateID == selectedScore?.candidateID
        } ?? thoughtFrame.candidates.first ?? BASCandidatePath(
            candidateID: "path.empty",
            title: "No candidate available",
            actionSummary: "Keep the turn bounded until a valid candidate exists.",
            expectedBenefit: 0,
            expectedCost: 0,
            reversibility: 1,
            confidence: 0
        )

        let mergedChoice = BASMergedChoice(
            candidateID: selectedCandidate.candidateID,
            title: selectedCandidate.title,
            actionSummary: selectedCandidate.actionSummary,
            vetoApplied: !aggregatedVetoReasonCodes.isEmpty,
            vetoReasonCodes: aggregatedVetoReasonCodes
        )

        return (scores, mergedChoice)
    }

    private func vetoReasonCodes(for candidate: BASCandidatePath) -> [String] {
        guard candidate.candidateID == "path.direct" else { return [] }

        var reasons: [String] = []
        if request.riskLevel == .high {
            reasons.append("triself.high_risk_direct_path")
        }
        if currentBrain.hasProtectiveBoundary {
            reasons.append("triself.protective_boundary")
        }
        if currentBrain.calibrationStatus == .drifting {
            reasons.append("triself.calibration_drifting")
        }

        guard !reasons.isEmpty else { return [] }
        return ["triself.superego_veto"] + reasons
    }

    private func constitutionSuperegoPenalty(
        for candidate: BASCandidatePath
    ) -> Double {
        guard candidate.candidateID == "path.direct", let hostConstitution else {
            return 0
        }

        let confirmPenalty = hostConstitution.boundaryVeil.confirmRequired.isEmpty ? 0.0 : 0.08
        let hardNoGoPenalty = hostConstitution.boundaryVeil.hardNoGo.isEmpty ? 0.0 : 0.05
        let stabilityWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["stability", "safety", "care", "relationship", "privacy"]
        )
        let valueAxisPenalty = stabilityWeight >= hostConstitution.valueAxes.updateThreshold ? 0.09 : 0.0
        let conflictPenalty = hostConstitution.valueAxes.conflictRules.contains {
            let normalized = $0.lowercased()
            return normalized.contains("over_speed") || normalized.contains("over_haste")
        } ? 0.05 : 0.0
        let boundedGoalPenalty = constitutionPrefersBoundedAction(in: hostConstitution) ? 0.05 : 0.0
        let relationPenalty = constitutionHasHighConsequenceRelations(in: hostConstitution) ? 0.06 : 0.0

        return min(
            0.34,
            confirmPenalty + hardNoGoPenalty + valueAxisPenalty + conflictPenalty + boundedGoalPenalty + relationPenalty
        )
    }

    private func constitutionCandidateBoost(
        for candidate: BASCandidatePath
    ) -> Double {
        guard let hostConstitution else {
            return 0
        }

        var boost = 0.0
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            switch candidate.candidateID {
            case "path.bounded":
                boost += 0.10
            case "path.reflective":
                boost += 0.05
            default:
                break
            }
        }
        if constitutionHasHighConsequenceRelations(in: hostConstitution) {
            switch candidate.candidateID {
            case "path.bounded":
                boost += 0.08
            case "path.reflective":
                boost += 0.04
            default:
                break
            }
        }

        return boost
    }

    private func constitutionAxisWeight(
        in hostConstitution: BASHostConstitution,
        matching protectedAxes: Set<String>
    ) -> Double {
        zip(hostConstitution.valueAxes.axes, hostConstitution.valueAxes.relativeWeights)
            .reduce(0) { partialResult, pair in
                let axis = pair.0.lowercased()
                let weight = pair.1
                return protectedAxes.contains(axis) ? max(partialResult, weight) : partialResult
            }
    }

    private func constitutionPrefersBoundedAction(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        let descriptors = hostConstitution.goalSpine.priorityOrder
            + hostConstitution.goalSpine.goals
            + hostConstitution.goalSpine.conflictPairs
        return descriptors.contains { descriptor in
            let normalized = descriptor.lowercased()
            return normalized.contains("bounded")
                || normalized.contains("compare")
                || normalized.contains("reflect")
                || normalized.contains("review")
                || normalized.contains("protect")
                || normalized.contains("slow")
        }
    }

    private func constitutionHasHighConsequenceRelations(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        !hostConstitution.relationGravity.highConsequenceLinks.isEmpty
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func isLowerMergedScore(
        _ lhs: BASTriSelfScore,
        _ rhs: BASTriSelfScore
    ) -> Bool {
        lhs.mergedScore < rhs.mergedScore
    }
}

private struct BASHostRuntimeEBrainRiskService: BASRiskServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        let riskTuning = tuning.risk
        let critiqueSeverity = thoughtFrame.critiques.map(\.severity).max() ?? 0
        let directCandidatePenalty = thoughtFrame.candidates.contains {
            $0.candidateID == "path.direct"
                && $0.reversibility < riskTuning.directCandidateLowReversibilityThreshold
        } ? riskTuning.directCandidatePenalty : 0
        let vetoPressure = triScores.contains(where: \.veto) ? riskTuning.vetoPressureIncrement : 0
        let constitutionSignals = constitutionGuardSignals(
            thoughtFrame: thoughtFrame,
            triScores: triScores
        )
        let presenceSignals = presenceRiskSignals(contextFrame: contextFrame)
        let totalRisk = min(
            1,
            (contextFrame.emotionalLoad * riskTuning.emotionalLoadWeight)
            + (contextFrame.timePressure * riskTuning.timePressureWeight)
            + (contextFrame.consequenceLevel * riskTuning.consequenceWeight)
            + (Double(contextFrame.manipulationHints.count) * riskTuning.manipulationHintWeight)
            + (critiqueSeverity * riskTuning.critiqueSeverityWeight)
            + directCandidatePenalty
            + currentBrain.hostGuardrailPressure(using: tuning)
            + vetoPressure
            + constitutionSignals.riskIncrement
            + presenceSignals.riskIncrement
        )
        let level: BASBrainRiskLevel = switch totalRisk {
        case ..<riskTuning.mediumThreshold:
            .low
        case ..<riskTuning.highThreshold:
            .medium
        case ..<riskTuning.extremeThreshold:
            .high
        default:
            .extreme
        }

        return BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: level,
            factors: riskFactors(
                for: contextFrame,
                thoughtFrame: thoughtFrame,
                constitutionFactorCodes: constitutionSignals.factorCodes,
                presenceFactorCodes: presenceSignals.factorCodes
            ),
            uncertainty: thoughtFrame.forecasts.map(\.uncertainty).max() ?? riskTuning.defaultForecastUncertainty,
            irreversibility: 1 - (thoughtFrame.candidates.map(\.reversibility).max() ?? riskTuning.defaultCandidateReversibility),
            manipulationStrength: max(
                min(1, Double(contextFrame.manipulationHints.count) * riskTuning.manipulationStrengthUnit),
                presenceSignals.manipulationStrength
            ),
            gsiScore: computeGSI(contextFrame: contextFrame, thoughtFrame: thoughtFrame),
            recommendedMode: recommendedMode(for: level, contextFrame: contextFrame)
        )
    }

    func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        let riskTuning = tuning.risk
        let presenceSignals = presenceRiskSignals(contextFrame: contextFrame)
        return min(
            1,
            Double(contextFrame.manipulationHints.count) * riskTuning.gsiHintWeight
                + (contextFrame.timePressure > riskTuning.gsiTimePressureThreshold ? riskTuning.gsiTimePressureIncrement : 0)
                + (currentBrain.hasTrustDriftSignals ? riskTuning.gsiTrustDriftIncrement : 0)
                + (currentBrain.calibrationAlerts.contains(BASMemory.BASCalibrationAlert.lowTrustLoad) ? riskTuning.gsiLowTrustAlertIncrement : 0)
                + presenceSignals.gsiIncrement
        )
    }

    func riskLevel(for score: Double) -> BASBrainRiskLevel {
        let riskTuning = tuning.risk
        switch score {
        case ..<riskTuning.mediumThreshold:
            return .low
        case ..<riskTuning.highThreshold:
            return .medium
        case ..<riskTuning.extremeThreshold:
            return .high
        default:
            return .extreme
        }
    }

    func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit) {
        let card = calibrateRisk(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: budget
        )
        let constitutionSignals = constitutionGuardSignals(
            thoughtFrame: thoughtFrame,
            triScores: triScores
        )
        let constitutionReasonCodes = constitutionSignals.reasonCodes
        let permit: BASActionPermit = switch card.riskLevel {
        case .low:
            BASActionPermit(
                mode: .answer,
                reasonCodes: ["risk.low"] + constitutionReasonCodes + uncertaintyReasonCodes,
                requireSecondCheck: false,
                outputLengthCap: 220,
                tonePolicy: "grounded_clear",
                templatePolicy: "direct_answer"
            )
        case .medium:
            BASActionPermit(
                mode: .compare,
                reasonCodes: ["risk.medium", "compare.paths"] + constitutionReasonCodes + uncertaintyReasonCodes + (currentBrain.hasProtectiveBoundary ? ["boundary.protective"] : []),
                requireSecondCheck: false,
                outputLengthCap: 240,
                tonePolicy: "structured_compare",
                templatePolicy: "two_path_compare"
            )
        case .high:
            BASActionPermit(
                mode: currentBrain.hasProtectiveBoundary ? .replace : .delay,
                reasonCodes: ["risk.high", "protective_delay"] + constitutionReasonCodes + protectiveReasonCodes,
                requireSecondCheck: true,
                outputLengthCap: 220,
                tonePolicy: "calm_protective",
                templatePolicy: currentBrain.hasProtectiveBoundary ? "replace_with_guarded_alternative" : "delay_with_alternative"
            )
        case .extreme:
            BASActionPermit.protectiveBlock(reasonCodes: ["risk.extreme", "protective_block"] + constitutionReasonCodes + protectiveReasonCodes)
        }
        return (card, permit)
    }

    private func riskFactors(
        for contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        constitutionFactorCodes: [String],
        presenceFactorCodes: [String]
    ) -> [String] {
        var factors: [String] = []
        if contextFrame.emotionalLoad > 0.6 { factors.append("emotion_high") }
        if contextFrame.timePressure > 0.6 { factors.append("time_pressure") }
        if contextFrame.consequenceLevel > 0.6 { factors.append("consequence_high") }
        if !contextFrame.manipulationHints.isEmpty { factors.append("manipulation_signals") }
        if thoughtFrame.critiques.contains(where: { $0.critiqueType == .boundaryConflict }) { factors.append("boundary_conflict") }
        if currentBrain.hasProtectiveBoundary { factors.append("host_protective_boundary") }
        if currentBrain.calibrationStatus == .drifting { factors.append("calibration_drifting") }
        if currentBrain.hasTrustDriftSignals { factors.append("trust_drift") }
        if currentBrain.hasEvidenceCaveatLoad { factors.append("evidence_caveat_load") }
        factors += constitutionFactorCodes
        factors += presenceFactorCodes
        return factors
    }

    private func presenceRiskSignals(
        contextFrame: BASContextFrame
    ) -> (
        riskIncrement: Double,
        factorCodes: [String],
        gsiIncrement: Double,
        manipulationStrength: Double
    ) {
        var riskIncrement = 0.0
        var gsiIncrement = 0.0
        var factorCodes: [String] = []
        var manipulationStrength = 0.0
        let manipulationConfidence = contextFrame.manipulationTrace?.confidence ?? 0
        let escalatoryPresence = manipulationConfidence > 0.55
            || (contextFrame.powerGradient?.strength ?? 0) > 0.65
            || contextFrame.routeHint?.needGuard == true

        if let powerGradient = contextFrame.powerGradient,
           powerGradient.strength > 0.6 {
            if escalatoryPresence {
                riskIncrement += min(0.06, 0.01 + (powerGradient.strength * 0.05))
                gsiIncrement += 0.05
            }
            factorCodes.append("presence_power_gradient")
        }
        if let urgencyTruth = contextFrame.urgencyTruth,
           urgencyTruth.canDelay == false,
           escalatoryPresence {
            riskIncrement += min(0.04, 0.01 + (urgencyTruth.inferredUrgency * 0.03))
            gsiIncrement += urgencyTruth.statedUrgency > 0.75 ? 0.05 : 0.02
            factorCodes.append("presence_urgency_locked")
        }
        if let manipulationTrace = contextFrame.manipulationTrace {
            if manipulationTrace.confidence > 0.55 {
                riskIncrement += min(0.06, manipulationTrace.confidence * 0.04 + manipulationTrace.timeCoercion * 0.02)
                gsiIncrement += min(0.14, manipulationTrace.confidence * 0.12)
            }
            manipulationStrength = max(manipulationStrength, manipulationTrace.confidence)
            factorCodes.append("presence_manipulation_trace")
        }
        if contextFrame.routeHint?.needGuard == true {
            riskIncrement += 0.03
            gsiIncrement += 0.05
            factorCodes.append("presence_route_guard")
        }

        return (
            min(0.16, riskIncrement),
            orderedUnique(factorCodes),
            min(0.24, gsiIncrement),
            min(1, manipulationStrength)
        )
    }

    private func constitutionGuardSignals(
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore]
    ) -> (riskIncrement: Double, factorCodes: [String], reasonCodes: [String]) {
        guard let hostConstitution,
              thoughtFrame.candidates.contains(where: { $0.candidateID == "path.direct" }) else {
            return (0, [], [])
        }

        let directScore = triScores.first(where: { $0.candidateID == "path.direct" })?.mergedScore ?? 0
        let stabilityWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["stability", "safety"]
        )
        let privacyWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["privacy", "locality"]
        )
        let confirmIncrement = hostConstitution.boundaryVeil.confirmRequired.isEmpty ? 0.0 : 0.08
        let valueAxisIncrement = max(stabilityWeight, privacyWeight) >= hostConstitution.valueAxes.updateThreshold ? 0.07 : 0.0
        let conflictIncrement = hostConstitution.valueAxes.conflictRules.contains {
            $0.lowercased().contains("over_speed")
        } ? 0.04 : 0.0
        let noGoIncrement = hostConstitution.boundaryVeil.hardNoGo.isEmpty ? 0.0 : 0.03
        let directPathBias = directScore > 0.6 ? 0.03 : 0.0

        var factorCodes: [String] = []
        var reasonCodes: [String] = []
        if confirmIncrement > 0 {
            factorCodes.append("constitution_confirm_required")
            reasonCodes.append("constitution.confirm_required")
        }
        if stabilityWeight >= hostConstitution.valueAxes.updateThreshold {
            factorCodes.append("constitution_value_axis_stability")
            reasonCodes.append("constitution.value_axis.stability")
        }
        if privacyWeight >= hostConstitution.valueAxes.updateThreshold {
            factorCodes.append("constitution_value_axis_privacy")
            reasonCodes.append("constitution.value_axis.privacy")
        }
        if conflictIncrement > 0 {
            factorCodes.append("constitution_conflict_rule")
            reasonCodes.append("constitution.conflict_rule")
        }
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            factorCodes.append("constitution_goal_priority_bounded")
            reasonCodes.append("constitution.goal_priority.bounded")
        }
        if constitutionHasHighConsequenceRelations(in: hostConstitution) {
            factorCodes.append("constitution_relation_high_consequence")
            reasonCodes.append("constitution.relation_high_consequence")
        }

        return (
            min(
                0.33,
                confirmIncrement
                    + valueAxisIncrement
                    + conflictIncrement
                    + noGoIncrement
                    + directPathBias
                    + (constitutionPrefersBoundedAction(in: hostConstitution) ? 0.05 : 0.0)
                    + (constitutionHasHighConsequenceRelations(in: hostConstitution) ? 0.06 : 0.0)
            ),
            orderedUnique(factorCodes),
            orderedUnique(reasonCodes)
        )
    }

    private func constitutionAxisWeight(
        in hostConstitution: BASHostConstitution,
        matching protectedAxes: Set<String>
    ) -> Double {
        zip(hostConstitution.valueAxes.axes, hostConstitution.valueAxes.relativeWeights)
            .reduce(0) { partialResult, pair in
                let axis = pair.0.lowercased()
                let weight = pair.1
                return protectedAxes.contains(axis) ? max(partialResult, weight) : partialResult
            }
    }

    private func constitutionPrefersBoundedAction(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        let descriptors = hostConstitution.goalSpine.priorityOrder
            + hostConstitution.goalSpine.goals
            + hostConstitution.goalSpine.conflictPairs
        return descriptors.contains { descriptor in
            let normalized = descriptor.lowercased()
            return normalized.contains("bounded")
                || normalized.contains("compare")
                || normalized.contains("reflect")
                || normalized.contains("review")
                || normalized.contains("protect")
                || normalized.contains("slow")
        }
    }

    private func constitutionHasHighConsequenceRelations(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        !hostConstitution.relationGravity.highConsequenceLinks.isEmpty
    }

    private func orderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func recommendedMode(
        for level: BASBrainRiskLevel,
        contextFrame: BASContextFrame
    ) -> BASActionPermitMode {
        switch level {
        case .low:
            .answer
        case .medium:
            currentBrain.hasProtectiveBoundary ? .delay : .compare
        case .high:
            currentBrain.hasProtectiveBoundary ? .replace : .delay
        case .extreme:
            contextFrame.manipulationHints.isEmpty ? .replace : .block
        }
    }

    private var protectiveReasonCodes: [String] {
        var reasons: [String] = []
        if currentBrain.hasProtectiveBoundary {
            reasons.append("boundary.protective")
        }
        if currentBrain.calibrationStatus == .drifting {
            reasons.append("calibration.drifting")
        }
        if currentBrain.hasTrustDriftSignals {
            reasons.append("trust.low")
        }
        reasons += uncertaintyReasonCodes
        return reasons
    }

    private var uncertaintyReasonCodes: [String] {
        currentBrain.hasEvidenceCaveatLoad ? ["evidence.caveat"] : []
    }
}

private struct BASHostRuntimeEBrainActionService: BASActionServicing {
    func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        let explanationCodes = mergedExplanationCodes(permit: permit, choice: choice)

        switch permit.mode {
        case .answer:
            return BASRenderedOutput(
                mode: .answer,
                headline: choice.title,
                body: choice.actionSummary,
                alternativeActions: [],
                explanationCodes: explanationCodes
            )
        case .compare:
            return BASRenderedOutput(
                mode: .compare,
                headline: "Compare the two safest paths first",
                body: choice.actionSummary,
                alternativeActions: ["Name one tradeoff before acting."],
                explanationCodes: explanationCodes
            )
        case .delay:
            return BASRenderedOutput(
                mode: .delay,
                headline: "Delay the move and re-check the boundary",
                body: choice.actionSummary,
                alternativeActions: ["Gather one more fact.", "Return after the pressure cools."],
                explanationCodes: explanationCodes
            )
        case .block:
            return BASRenderedOutput(
                mode: .block,
                headline: "Do not take the direct high-risk path",
                body: "The current path is too likely to outrun the boundary, so the system is blocking direct release.",
                alternativeActions: ["Pause the action.", "Choose the safer bounded alternative."],
                explanationCodes: explanationCodes
            )
        case .replace:
            return BASRenderedOutput(
                mode: .replace,
                headline: "Replace the risky move with a safer next step",
                body: "The direct action is not permitted, so the system is switching to a safer bounded move.",
                alternativeActions: ["Use a lower-pressure template.", "Ask for one missing fact first."],
                explanationCodes: explanationCodes
            )
        }
    }

    private func mergedExplanationCodes(
        permit: BASActionPermit,
        choice: BASMergedChoice
    ) -> [String] {
        var seen = Set<String>()
        return (permit.reasonCodes + choice.vetoReasonCodes).filter { seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainEvolutionService: BASEvolutionServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        let protectiveWriteSuggestion: String? = if output.mode == .answer && !currentBrain.isCalibrationUnstable {
            nil
        } else {
            "Keep this turn in review before any warm or cold promotion."
        }
        let hostChangeCandidate: BASHostChangeCandidate? = if currentBrain.calibrationStatus == .drifting {
            BASHostChangeCandidate(
                candidateID: "candidate.\(UUID().uuidString.lowercased())",
                changeType: "review_host_gate_strength",
                proposedDelta: ["host_gate_strength"],
                evidenceRefs: ["calibration:drifting", "mode:\(output.mode.rawValue)"],
                cooldownUntil: .now.addingTimeInterval(1_800),
                confidence: output.mode == .answer ? 0.68 : 0.82,
                conflictRefs: output.explanationCodes,
                previewState: "review_only",
                approvalState: "pending"
            )
        } else {
            nil
        }
        return [
            BASUpdateTicket(
                ticketID: "ticket.\(UUID().uuidString.lowercased())",
                sessionRef: "\(request.kind.rawValue).\(request.workflowProfile.rawValue)",
                summary: output.body,
                memoryWriteSuggestion: protectiveWriteSuggestion,
                hostChangeCandidate: hostChangeCandidate,
                ruleCandidateRef: output.mode == .block ? "rule.protective_block" : nil,
                confidence: output.mode == .answer ? 0.62 : 0.80,
                conflictFlag: output.mode == .block || output.mode == .replace,
                requiresReview: true
            )
        ]
    }
}

private enum BASHostRuntimeEBrainPromptAnalyzer {
    static func containsUrgency(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return ["now", "immediately", "urgent", "asap", "tonight", "must"].contains {
            normalized.contains($0)
        }
    }

    static func manipulationHints(in text: String) -> [String] {
        let normalized = text.lowercased()
        let rules: [(String, String)] = [
            ("now", "time_pressure"),
            ("immediately", "time_pressure"),
            ("must", "authority_pressure"),
            ("for your own good", "benevolent_control"),
            ("everyone says", "social_pressure"),
            ("you always", "history_rewrite")
        ]
        return rules.compactMap { normalized.contains($0.0) ? $0.1 : nil }
    }

    static func containsReflectiveCue(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return ["think", "reflect", "consider", "unclear", "confused", "compare"].contains {
            normalized.contains($0)
        }
    }

    static func containsDeepLoopCue(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"].contains {
            normalized.contains($0)
        }
    }

    static func tokenized(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
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
                hostConstitution: configuration.hostConstitution
            ),
            riskService: BASHostRuntimeEBrainRiskService(
                request: request,
                currentBrain: enforcedCurrentBrain,
                tuning: configuration.runtimeTuning,
                hostConstitution: configuration.hostConstitution
            ),
            actionService: BASHostRuntimeEBrainActionService(),
            evolutionService: BASHostRuntimeEBrainEvolutionService(
                request: request,
                currentBrain: enforcedCurrentBrain
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
