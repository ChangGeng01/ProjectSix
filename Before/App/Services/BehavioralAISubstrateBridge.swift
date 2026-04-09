import Foundation

enum BehavioralAISubstrateBridge {
    struct RuntimeContext: Equatable, Sendable {
        let generatedAt: Date
        let activeProvider: String
        let fallbackProvider: String?
        let runtimeGear: String
        let environmentClass: String
        let deviceClass: String
        let languageMode: String
        let totalRequests: Int
        let totalProviderAttempts: Int
        let isPureLocalClosedLoop: Bool
    }

    struct BrainSnapshot: Equatable, Sendable {
        let generatedAt: Date
        let source: BrainStateUpdateSource
        let sourceSurface: DecisionIntentSourceSurface
        let mode: DecisionMode
        let riskLevel: InterventionRiskLevel
        let roleTitle: String
        let postureTitle: String
        let initiativeTitle: String
        let boundaryModeTitle: String
        let calibrationStatusTitle: String
        let evolutionCheckpointCount: Int
        let dominantGoal: String?
        let activeConstraints: [String]
        let activeTemplateIDs: [String]
        let failureGuardIDs: [String]
        let fingerprint: String
    }

    struct ConsoleSnapshot: Equatable, Sendable {
        let generatedAt: Date
        let runtimeContext: RuntimeContext
        let flightDeck: DecisionSystemFlightDeck
        let brainSnapshot: BrainSnapshot?
    }

    static func runtimeContext(from export: DecisionTestingRuntimeExport) -> RuntimeContext {
        let summary = export.summary
        let adaptationMatrix = export.runtimeSnapshot.executionProfile.adaptationMatrix
        return RuntimeContext(
            generatedAt: export.generatedAt,
            activeProvider: summary.activeProvider.title,
            fallbackProvider: summary.fallbackProvider?.title,
            runtimeGear: adaptationMatrix.runtimeGear.rawValue,
            environmentClass: adaptationMatrix.environmentClass.rawValue,
            deviceClass: adaptationMatrix.deviceClass.rawValue,
            languageMode: adaptationMatrix.languageMode.rawValue,
            totalRequests: summary.totalRequests,
            totalProviderAttempts: summary.totalProviderAttempts,
            isPureLocalClosedLoop: export.flightDeck.isPureLocalClosedLoop
        )
    }

    static func brainSnapshot(
        from currentBrainState: CurrentBrainState?
    ) -> BrainSnapshot? {
        guard let currentBrainState else { return nil }

        return BrainSnapshot(
            generatedAt: currentBrainState.loadedAt,
            source: currentBrainState.source,
            sourceSurface: currentBrainState.sourceSurface,
            mode: currentBrainState.mode,
            riskLevel: currentBrainState.riskLevel,
            roleTitle: currentBrainState.identityProfile.role.title,
            postureTitle: currentBrainState.identityProfile.posture.rawValue,
            initiativeTitle: currentBrainState.identityProfile.initiative.rawValue,
            boundaryModeTitle: currentBrainState.boundaryPolicy.mode.rawValue,
            calibrationStatusTitle: currentBrainState.calibrationState.status.rawValue,
            evolutionCheckpointCount: currentBrainState.evolutionState.checkpointCount,
            dominantGoal: currentBrainState.dominantGoal,
            activeConstraints: currentBrainState.activeConstraints,
            activeTemplateIDs: currentBrainState.activeTemplateIDs,
            failureGuardIDs: currentBrainState.failureGuardIDs,
            fingerprint: currentBrainState.verificationSnapshot.fingerprint
        )
    }

    static func consoleSnapshot(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> ConsoleSnapshot {
        ConsoleSnapshot(
            generatedAt: export.generatedAt,
            runtimeContext: runtimeContext(from: export),
            flightDeck: export.flightDeck,
            brainSnapshot: brainSnapshot(from: currentBrainState)
        )
    }
}
