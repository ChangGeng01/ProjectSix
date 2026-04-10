import Foundation
import SwiftData
import BASAdmin
import BASAppleAdapters
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

enum BehavioralAISubstrateBridge {
    @discardableResult
    static func bootstrapCurrentBrainState(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        envelope: DecisionIntentEnvelope? = nil,
        taskGraph: DecisionTaskGraphSnapshot?,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        now: Date = .now
    ) -> CurrentBrainState {
        InterventionTemplateStore.ensureDefaults(in: context)
        FailurePatternStore.syncFromHistory(in: context)

        let committed: BASAppleCurrentBrainBootstrapCommitResult<
            BrainStateUpdate,
            DecisionEvolutionCheckpoint
        > = BASAppleCurrentBrainRuntimeCoordinator.bootstrapAndCommit(
            context: hostBootstrapBuildContext(
                mode: mode,
                prompt: prompt,
                source: source,
                sourceSurfaceOverride: envelope?.sourceSurface,
                riskLevelOverride: envelope?.riskLevel,
                projection: projection.baseProjection,
                taskGraph: taskGraph,
                retrievalMode: retrievalMode.rawValue,
                recommendedTemplateIDs: [],
                now: now
            ),
            in: context,
            createdAt: now,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
            recommendTemplateIDs: { preparation in
                DecisionReactionBanditStore.recommendedArmIDs(
                    mode: mode,
                    riskLevel: interventionRiskLevel(from: preparation.riskLevel),
                    languageMode: decisionLanguageMode(from: preparation.languageMode),
                    now: preparation.now
                )
            },
            selectTemplates: { preparation, recommendedTemplateIDs in
                InterventionTemplateStore.selectTemplates(
                    in: context,
                    mode: mode,
                    riskLevel: interventionRiskLevel(from: preparation.riskLevel),
                    recommendedArmIDs: recommendedTemplateIDs
                )
            },
            selectFailurePatterns: { _ in
                FailurePatternStore.selectedFailurePatterns(in: context, mode: mode)
            },
            mapTemplate: { template in
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: template.id,
                    modeID: template.mode.rawValue,
                    riskLevelID: template.riskLevel.rawValue,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            },
            mapFailurePattern: { pattern in
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: pattern.id,
                    modeID: pattern.mode.rawValue,
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            },
            onCheckpointSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "recording evolution checkpoints"
                )
            },
            onUpdateSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "persisting current brain updates"
                )
            }
        )

        return CurrentBrainState(
            source: source,
            sourceSurface: sourceSurface(from: committed.preparation.sourceSurface),
            mode: mode,
            riskLevel: interventionRiskLevel(from: committed.preparation.riskLevel),
            taskGraph: taskGraph,
            brainState: committed.brainState,
            dominantGoal: committed.dominantGoal,
            activeConstraints: committed.activeConstraints,
            activeTemplateIDs: committed.orderedTemplateIDs,
            failureGuardIDs: committed.orderedFailurePatternIDs,
            sourceIntentEnvelope: envelope,
            loadedAt: now
        )
    }

    static func runtimeContext(from export: DecisionTestingRuntimeExport) -> BASRuntimeContext {
        let adaptationMatrix = export.runtimeSnapshot.executionProfile.adaptationMatrix
        let primaryKind = export.recentTraces.first?.kind ?? .quick
        let strategy = adaptationMatrix.strategy(for: primaryKind)

        return BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRuntimeContextSourceInput(
                primaryTraceKind: export.recentTraces.first?.kind.rawValue,
                runtimeGear: runtimeGear(from: adaptationMatrix.runtimeGear),
                environmentClass: environmentClass(from: adaptationMatrix.environmentClass),
                deviceClass: devicePerformanceClass(from: adaptationMatrix.deviceClass),
                riskLevel: riskLevel(from: currentRiskBand(in: export)),
                budget: BASAdaptiveRuntimeBudget(
                    contextBudget: strategy.contextBudget,
                    outputCharacterBudget: strategy.outputCharacterBudget,
                    timeBudgetMs: strategy.timeBudgetMs,
                    toolCallBudget: strategy.toolCallBudget,
                    retrievalItemBudget: strategy.retrievalItemBudget
                )
            )
        )
    }

    static func roleProfile(from currentBrainState: CurrentBrainState?) -> BASRoleProfile? {
        BASAppleInspectionBridgeBuilder.roleProfile(
            from: currentBrainState.map { currentBrainState in
                BASAppleRoleProfileSourceInput(
                    name: currentBrainState.identityProfile.role.title,
                    postureID: currentBrainState.identityProfile.posture.rawValue,
                    initiativeID: currentBrainState.identityProfile.initiative.rawValue,
                    confidenceCeiling: currentBrainState.identityProfile.confidenceCeiling,
                    roleBoundaryPreset: currentBrainState.identityProfile.relationshipBoundary
                )
            }
        )
    }

    static func brainSnapshot(
        from currentBrainState: CurrentBrainState?
    ) -> BASCurrentBrainState? {
        BASAppleInspectionBridgeBuilder.brainSnapshot(
            from: currentBrainState.map { currentBrainState in
                BASAppleBrainSnapshotSourceInput(
                    mode: currentBrainState.mode.rawValue,
                    dominantGoals: currentBrainState.dominantGoal.map { [$0] } ?? [],
                    activeConstraints: currentBrainState.activeConstraints,
                    warmth: currentBrainState.brainState.reactionWeights.warmDirectTone,
                    directness: currentBrainState.brainState.reactionWeights.tradeoffClarityBias,
                    brevity: currentBrainState.brainState.reactionWeights.briefLanguage,
                    actionBias: currentBrainState.brainState.reactionWeights.interruptiveActionBias,
                    activeTemplateIDs: currentBrainState.activeTemplateIDs,
                    recentFailurePatternIDs: currentBrainState.failureGuardIDs,
                    retrievalTags: currentBrainState.brainState.retrievalTags,
                    verificationSnapshot: currentBrainState.verificationSnapshot.fingerprint
                )
            }
        )
    }

    static func consoleSnapshot(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> BASConsoleSnapshot {
        let flightDeckCompilation = export.basFlightDeckCompilation
        let runtimeContext = runtimeContext(from: export)
        let brainSnapshot = brainSnapshot(from: currentBrainState)
        let roleProfile = roleProfile(from: currentBrainState)

        return BASAppleInspectionBridgeBuilder.consoleSnapshot(
            from: BASAppleConsoleBridgeSourceInput(
                generatedAt: export.generatedAt,
                flightDeckCompilation: flightDeckCompilation,
                activeProviderTitle: export.runtimeSnapshot.runtimeStatus.active.title,
                totalRequests: export.basRuntimeInspectionSummary.totalRequests,
                totalProviderAttempts: export.basRuntimeInspectionSummary.totalProviderAttempts,
                runtimeContext: runtimeContext,
                roleProfile: roleProfile,
                boundaryModeID: currentBrainState?.boundaryPolicy.mode.rawValue,
                calibrationStatusID: currentBrainState?.calibrationState.status.rawValue,
                brainState: brainSnapshot,
                capabilityCoverage: DecisionCapabilityCoverageBuilder.build(
                    from: export,
                    currentBrainState: currentBrainState
                )
            )
        )
    }

    static func entryIntentEnvelope(from envelope: DecisionIntentEnvelope) -> BASEntryIntentEnvelope {
        BASEntryIntentEnvelope(
            kind: intentKind(from: envelope.kind),
            surface: intentSurface(from: envelope.sourceSurface),
            taskKind: taskKind(from: traceKind(for: envelope.preferredMode)),
            preferredWorkflowID: envelope.preferredMode?.rawValue,
            promptSeed: envelope.promptSeed,
            riskLevel: envelope.riskLevel.map(riskLevel(from:)),
            triggerReason: envelope.triggerReason,
            continuityToken: envelope.brainFingerprint,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt
        )
    }

    static func entryIntentSummary(from envelope: DecisionIntentEnvelope) -> BASEntryIntentSummary {
        BASEntryIntentSummarizer.summarize(entryIntentEnvelope(from: envelope))
    }

    static func handoffSummary(from envelope: DecisionIntentEnvelope) -> BASAppleHandoffSummary {
        BASDefaultAppleHandoffSummarizer().summarize(
            BASAppleHandoffEnvelope(
                id: envelope.id,
                surface: appleSurface(from: envelope.sourceSurface),
                taskKind: taskKind(from: traceKind(for: envelope.preferredMode)),
                riskLevel: envelope.riskLevel.map(riskLevel(from:)) ?? .low,
                payloadSummary: envelope.promptSeed ?? envelope.triggerReason ?? envelope.kind.rawValue,
                createdAt: envelope.requestedAt
            ),
            route: nil
        )
    }

    static func enrichBrainState(
        brainState: DecisionBrainState,
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel,
        taskGraph: DecisionTaskGraphSnapshot?,
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        now: Date
    ) -> BASBootstrappedBrainState {
        BASCognitionBootstrapper.enrich(
            brainState: brainState,
            mode: substrateMode(from: mode),
            sourceSurface: resolvedInteractionSurface(
                source: source,
                sourceSurface: sourceSurface
            ),
            riskLevel: substrateRiskLevel(from: riskLevel),
            taskGraphHint: taskGraph.map(taskGraphHint(from:)),
            dominantGoal: brainState.activeGoals.first,
            activeConstraints: Array(orderedUnique(brainState.sessionBiases).prefix(4)),
            activeTemplateIDs: activeTemplateIDs,
            failureGuardIDs: failureGuardIDs,
            now: now
        )
    }

    private static func hostBootstrapBuildContext(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        sourceSurfaceOverride: DecisionIntentSourceSurface?,
        riskLevelOverride: InterventionRiskLevel?,
        projection: BASBrainProjection,
        taskGraph: DecisionTaskGraphSnapshot?,
        retrievalMode: String,
        recommendedTemplateIDs: [String],
        now: Date
    ) -> BASAppleCurrentBrainBootstrapHostBuildContext {
        BASAppleCurrentBrainBootstrapHostBuildContext(
            modeID: mode.rawValue,
            prompt: prompt,
            triggerID: source.rawValue,
            sourceSurfaceOverrideID: sourceSurfaceOverride?.rawValue,
            riskLevelOverrideID: riskLevelOverride?.rawValue,
            preferredLanguages: Locale.preferredLanguages,
            now: now,
            projection: projection,
            embeddingScores: embeddingScores(for: prompt),
            taskGraphHint: taskGraph.map(hostTaskGraphInput(from:)),
            retrievalMode: retrievalMode,
            recommendedTemplateIDs: recommendedTemplateIDs
        )
    }

    private static func hostTaskGraphInput(
        from snapshot: DecisionTaskGraphSnapshot
    ) -> BASAppleCurrentBrainBootstrapHostTaskGraphInput {
        BASAppleCurrentBrainBootstrapHostInputBuilder.taskGraphInput(
            headline: snapshot.nextActionHint,
            activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
            hasResumeCandidate: !snapshot.tasks.isEmpty,
            resumeHint: snapshot.nextActionHint
        )
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

    private static func devicePerformanceClass(
        from deviceClass: DecisionDevicePerformanceClass
    ) -> BASDevicePerformanceClass {
        switch deviceClass {
        case .simulator:
            .simulator
        case .memoryConstrainedPhone:
            .memoryConstrainedPhone
        case .balancedPhone:
            .balancedPhone
        case .fullPhone:
            .fullPhone
        }
    }

    private static func environmentClass(
        from environmentClass: DecisionEnvironmentClass
    ) -> BASEnvironmentClass {
        switch environmentClass {
        case .simulator:
            .simulator
        case .lowPower:
            .lowPower
        case .memoryConstrained:
            .memoryConstrained
        case .normal:
            .normal
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

    private static func interventionRiskLevel(
        from riskLevel: BASRiskLevel
    ) -> InterventionRiskLevel {
        switch riskLevel {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }

    private static func sourceSurface(
        from sourceSurface: BASInteractionSurface
    ) -> DecisionIntentSourceSurface {
        switch sourceSurface {
        case .app, .system:
            .app
        case .watch:
            .watch
        case .widget:
            .widget
        case .shortcut:
            .shortcut
        case .siri:
            .siri
        case .notification:
            .notification
        }
    }

    private static func decisionLanguageMode(
        from languageMode: BASLanguageMode
    ) -> DecisionLanguageMode {
        switch languageMode {
        case .english:
            .english
        case .chinese:
            .chinese
        case .mixed:
            .mixed
        case .unknown:
            .unknown
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

    private static func intentKind(from kind: DecisionIntentKind) -> BASEntryIntentKind {
        switch kind {
        case .quickCapture:
            .quickCapture
        case .openMode:
            .openMode
        case .reopenTomorrowItem:
            .reopenTomorrowItem
        case .predictiveIntervention:
            .predictiveIntervention
        case .resumeCurrentDecision:
            .resumeCurrentDecision
        }
    }

    private static func intentSurface(from surface: DecisionIntentSourceSurface) -> BASEntryIntentSurface {
        switch surface {
        case .app:
            .app
        case .watch:
            .watch
        case .widget:
            .widget
        case .shortcut:
            .shortcut
        case .siri:
            .siri
        case .notification:
            .notification
        }
    }

    private static func appleSurface(from surface: DecisionIntentSourceSurface) -> BASAppleSurface {
        switch surface {
        case .app:
            .app
        case .watch:
            .watch
        case .widget:
            .widget
        case .shortcut, .siri:
            .shortcut
        case .notification:
            .notification
        }
    }

    private static func traceKind(for mode: DecisionMode?) -> DecisionIntelligenceTraceKind? {
        switch mode {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case nil:
            nil
        }
    }

    private static func taskGraphHint(from snapshot: DecisionTaskGraphSnapshot) -> BASTaskGraphHint {
        BASTaskGraphHint(
            headline: snapshot.nextActionHint,
            activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
            hasResumeCandidate: !snapshot.tasks.isEmpty,
            resumeHint: snapshot.nextActionHint
        )
    }

    private static func embeddingScores(for prompt: String) -> [BASAppleEmbeddingScoreInput] {
        EmbeddingMemoryStore.query(
            prompt,
            allowedTiers: [.hot, .warm],
            limit: 12
        ).map { BASAppleEmbeddingScoreInput(id: $0.id, score: $0.score) }
    }

    private static func interactionSurface(from sourceSurface: DecisionIntentSourceSurface) -> BASInteractionSurface {
        switch sourceSurface {
        case .app:
            .app
        case .watch:
            .watch
        case .widget:
            .widget
        case .shortcut:
            .shortcut
        case .siri:
            .siri
        case .notification:
            .notification
        }
    }

    private static func resolvedInteractionSurface(
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface
    ) -> BASInteractionSurface {
        if source == .notification {
            return .notification
        }
        return interactionSurface(from: sourceSurface)
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}
