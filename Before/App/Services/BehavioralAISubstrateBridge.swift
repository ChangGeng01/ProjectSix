import Foundation
import BASAdmin
import BASMemory
import BASPolicy
import BASRuntimeCore

enum BehavioralAISubstrateBridge {
    static func runtimeContext(from export: DecisionTestingRuntimeExport) -> BASRuntimeContext {
        let adaptationMatrix = export.runtimeSnapshot.executionProfile.adaptationMatrix
        let primaryKind = export.recentTraces.first?.kind ?? .quick
        let strategy = adaptationMatrix.strategy(for: primaryKind)

        return BASRuntimeContext(
            taskKind: taskKind(from: export.recentTraces.first?.kind),
            gear: runtimeGear(from: adaptationMatrix.runtimeGear),
            deviceProfile: BASDeviceProfile(
                modelName: adaptationMatrix.deviceClass.rawValue,
                memoryMB: memoryMB(for: adaptationMatrix.deviceClass),
                batteryLevel: 1.0,
                lowPowerMode: adaptationMatrix.environmentClass == .lowPower,
                thermalState: adaptationMatrix.environmentClass.rawValue
            ),
            privacyMode: .localOnly,
            riskLevel: riskLevel(from: currentRiskBand(in: export)),
            networkAvailable: false,
            budget: BASExecutionBudget(
                contextTokens: strategy.contextBudget,
                outputTokens: strategy.outputCharacterBudget,
                retrievalItems: strategy.retrievalItemBudget,
                toolCalls: strategy.toolCallBudget,
                timeBudgetMs: strategy.timeBudgetMs
            )
        )
    }

    static func roleProfile(from currentBrainState: CurrentBrainState?) -> BASRoleProfile? {
        guard let currentBrainState else { return nil }
        return BASRoleProfile(
            name: currentBrainState.identityProfile.role.title,
            posture: posture(from: currentBrainState.identityProfile.posture),
            initiative: initiative(from: currentBrainState.identityProfile.initiative),
            confidenceCeiling: currentBrainState.identityProfile.confidenceCeiling,
            roleBoundaryPreset: currentBrainState.identityProfile.relationshipBoundary
        )
    }

    static func brainSnapshot(
        from currentBrainState: CurrentBrainState?
    ) -> BASCurrentBrainState? {
        guard let currentBrainState else { return nil }

        return BASCurrentBrainState(
            mode: currentBrainState.mode.rawValue,
            dominantGoals: currentBrainState.dominantGoal.map { [$0] } ?? [],
            activeConstraints: currentBrainState.activeConstraints,
            reactionWeights: BASReactionWeights(
                warmth: currentBrainState.brainState.reactionWeights.warmDirectTone,
                directness: currentBrainState.brainState.reactionWeights.tradeoffClarityBias,
                brevity: currentBrainState.brainState.reactionWeights.briefLanguage,
                actionBias: currentBrainState.brainState.reactionWeights.interruptiveActionBias
            ),
            activeTemplateIDs: currentBrainState.activeTemplateIDs.compactMap(UUID.init(uuidString:)),
            recentFailurePatternIDs: currentBrainState.failureGuardIDs.compactMap(UUID.init(uuidString:)),
            retrievalTags: currentBrainState.brainState.retrievalTags,
            verificationSnapshot: currentBrainState.verificationSnapshot.fingerprint
        )
    }

    static func consoleSnapshot(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> BASConsoleSnapshot {
        let flightDeck = export.flightDeck
        let runtimeContext = runtimeContext(from: export)
        let brainSnapshot = brainSnapshot(from: currentBrainState)

        return BASConsoleSnapshot(
            generatedAt: export.generatedAt,
            overallSummary: "Behavioral substrate score \(flightDeck.overallScore)/100 across \(flightDeck.layerReports.count) layers.",
            runtimeSummary: "Route \(export.summary.activeProvider.title) • gear \(runtimeContext.gear.rawValue) • requests \(export.summary.totalRequests) • attempts \(export.summary.totalProviderAttempts)",
            brainSummary: brainSummary(
                currentBrainState: currentBrainState,
                roleProfile: roleProfile(from: currentBrainState),
                brainSnapshot: brainSnapshot
            ),
            reports: flightDeck.layerReports.map { report in
                BASLayerReport(
                    layer: map(report.layer),
                    health: map(report.health),
                    score: Double(report.score),
                    summary: report.headline,
                    blockers: report.blockers
                )
            },
            blockerSummary: flightDeck.dominantBlockers,
            isPureLocal: flightDeck.isPureLocalClosedLoop
        )
    }

    private static func taskKind(from kind: DecisionIntelligenceTraceKind?) -> BASTaskKind {
        switch kind {
        case .quick, .reminder:
            .chat
        case .balance:
            .plan
        case .mirror:
            .retrieve
        case nil:
            .chat
        }
    }

    private static func runtimeGear(from gear: DecisionRuntimeGear) -> BASRuntimeGear {
        switch gear {
        case .low:
            .low
        case .balanced:
            .balanced
        case .high:
            .high
        }
    }

    private static func memoryMB(for deviceClass: DecisionDevicePerformanceClass) -> Int {
        switch deviceClass {
        case .simulator:
            8192
        case .memoryConstrainedPhone:
            4096
        case .balancedPhone:
            6144
        case .fullPhone:
            8192
        }
    }

    private static func riskLevel(from riskLevel: InterventionRiskLevel) -> BASRiskLevel {
        switch riskLevel {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }

    private static func currentRiskBand(in export: DecisionTestingRuntimeExport) -> InterventionRiskLevel {
        if let currentBrain = export.recentTraces.first?.brainState,
           currentBrain.boundaryPolicy.riskLevel == .high {
            return .high
        }
        if export.recentTraces.contains(where: { $0.kind == .mirror }) {
            return .medium
        }
        return .low
    }

    private static func posture(from posture: DecisionIdentityPosture) -> BASRolePosture {
        switch posture {
        case .reflective:
            .observe
        case .coaching:
            .coach
        case .protective:
            .guardian
        }
    }

    private static func initiative(from initiative: DecisionIdentityInitiative) -> BASRoleInitiative {
        switch initiative {
        case .passive:
            .passive
        case .guided:
            .balanced
        case .assertive:
            .assertive
        }
    }

    private static func map(_ layer: DecisionSystemLayer) -> BASLayerKind {
        switch layer {
        case .runtime:
            .runtime
        case .data:
            .data
        case .memory:
            .memory
        case .safety:
            .security
        case .orchestration:
            .orchestration
        case .observability:
            .observability
        case .evaluation:
            .evaluation
        case .delivery:
            .delivery
        }
    }

    private static func map(_ health: DecisionSystemLayerHealth) -> BASLayerHealth {
        switch health {
        case .strong:
            .healthy
        case .watch:
            .warning
        case .critical:
            .blocker
        }
    }

    private static func brainSummary(
        currentBrainState: CurrentBrainState?,
        roleProfile: BASRoleProfile?,
        brainSnapshot: BASCurrentBrainState?
    ) -> String? {
        guard let currentBrainState, let roleProfile, let brainSnapshot else { return nil }
        return "\(roleProfile.name) • \(currentBrainState.boundaryPolicy.mode.rawValue) • \(currentBrainState.calibrationState.status.rawValue) • fingerprint \(brainSnapshot.verificationSnapshot)"
    }
}
