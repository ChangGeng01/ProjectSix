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
        let taskGraphInput = taskGraphInput(from: taskGraph)
        return bootstrapCurrentBrainState(
            input: BASAppleCurrentBrainBootstrapBridgeInput(
                modeID: mode.rawValue,
                prompt: prompt,
                triggerID: source.rawValue,
                sourceSurfaceOverrideID: envelope?.sourceSurface.rawValue,
                riskLevelOverrideID: envelope?.riskLevel?.rawValue,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                embeddingScores: embeddingScores(for: prompt),
                taskGraphHeadline: taskGraphInput?.headline,
                taskGraphActiveNodeCount: taskGraphInput?.activeNodeCount,
                taskGraphHasResumeCandidate: taskGraphInput?.hasResumeCandidate,
                taskGraphResumeHint: taskGraphInput?.resumeHint,
                retrievalMode: retrievalMode.rawValue
            ),
            envelope: envelope,
            taskGraph: taskGraph,
            context: context
        )
    }

    @discardableResult
    static func primeCurrentBrainState(
        mode: DecisionMode,
        promptFragments: [String],
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        now: Date = .now
    ) -> CurrentBrainState {
        BASAppleCurrentBrainRuntimeBridgeExecutor.primeSession(
            input: BASAppleCurrentBrainSessionBridgeInput(
                modeID: mode.rawValue,
                promptFragments: promptFragments,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                retrievalMode: retrievalMode.rawValue
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                return bootstrapCurrentBrainState(
                    input: bootstrapInput,
                    context: context
                )
            },
            afterBootstrap: { _ in }
        )
    }

    @discardableResult
    static func refreshCurrentBrainState(
        quickPromptFragments: [String]?,
        balancePromptFragments: [String]?,
        mirrorPromptFragments: [String]?,
        taskGraph: DecisionTaskGraphSnapshot?,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalModesByModeID: [String: String],
        source: BrainStateUpdateSource,
        now: Date = .now
    ) -> CurrentBrainState {
        BASAppleCurrentBrainRuntimeBridgeExecutor.refreshActiveBrain(
            input: BASAppleCurrentBrainActiveRefreshBridgeInput(
                quickPromptFragments: quickPromptFragments,
                balancePromptFragments: balancePromptFragments,
                mirrorPromptFragments: mirrorPromptFragments,
                taskGraphModeID: taskGraph?.mode?.rawValue,
                taskGraphPromptSeed: taskGraph?.promptSeed,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                taskGraphHint: taskGraphInput(from: taskGraph),
                retrievalModesByModeID: retrievalModesByModeID,
                triggerID: source.rawValue
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                return bootstrapCurrentBrainState(
                    input: bootstrapInput,
                    taskGraph: taskGraph,
                    context: context
                )
            }
        )
    }

    @discardableResult
    private static func bootstrapCurrentBrainState(
        input: BASAppleCurrentBrainBootstrapBridgeInput,
        envelope: DecisionIntentEnvelope? = nil,
        taskGraph: DecisionTaskGraphSnapshot? = nil,
        context: ModelContext
    ) -> CurrentBrainState {
        InterventionTemplateStore.ensureDefaults(in: context)
        FailurePatternStore.syncFromHistory(in: context)
        let mode = DecisionMode(rawValue: input.modeID) ?? .quick
        let source = BrainStateUpdateSource(rawValue: input.triggerID) ?? .explicitRefresh

        let committed: BASAppleCurrentBrainBootstrapBridgeResult<
            BrainStateUpdate,
            DecisionEvolutionCheckpoint
        > = BASAppleCurrentBrainBootstrapBridgeBuilder.bootstrapAndCommit(
            input: input,
            in: context,
            createdAt: input.now,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
            recommendTemplateIDs: { preparation in
                DecisionReactionBanditStore.recommendedArmIDs(
                    mode: mode,
                    riskLevel: InterventionRiskLevel(rawValue: preparation.riskLevel.rawValue) ?? .low,
                    languageMode: DecisionLanguageMode(rawValue: preparation.languageMode.rawValue) ?? .unknown,
                    now: preparation.now
                )
            },
            selectTemplates: { preparation, recommendedTemplateIDs in
                InterventionTemplateStore.selectTemplates(
                    in: context,
                    mode: mode,
                    riskLevel: InterventionRiskLevel(rawValue: preparation.riskLevel.rawValue) ?? .low,
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
            sourceSurface: DecisionIntentSourceSurface(rawValue: committed.sourceSurfaceID) ?? .app,
            mode: mode,
            riskLevel: InterventionRiskLevel(rawValue: committed.riskLevelID) ?? .low,
            taskGraph: taskGraph,
            brainState: committed.brainState,
            dominantGoal: committed.dominantGoal,
            activeConstraints: committed.activeConstraints,
            activeTemplateIDs: committed.activeTemplateIDs,
            failureGuardIDs: committed.failureGuardIDs,
            sourceIntentEnvelope: envelope,
            loadedAt: input.now
        )
    }

    static func runtimeContext(from export: DecisionTestingRuntimeExport) -> BASRuntimeContext {
        let adaptationMatrix = export.runtimeSnapshot.executionProfile.adaptationMatrix
        let primaryKind = export.recentTraces.first?.kind ?? .quick
        let strategy = adaptationMatrix.strategy(for: primaryKind)

        return BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRawRuntimeContextSourceInput(
                primaryTraceKindID: export.recentTraces.first?.kind.rawValue,
                runtimeGearID: adaptationMatrix.runtimeGear.rawValue,
                environmentClassID: adaptationMatrix.environmentClass.rawValue,
                deviceClassID: adaptationMatrix.deviceClass.rawValue,
                riskLevelID: currentRiskBand(in: export).rawValue,
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
        currentBrainState.flatMap { currentBrainState in
            BASAppleInspectionBridgeBuilder.roleProfile(
                name: currentBrainState.identityProfile.role.title,
                postureID: currentBrainState.identityProfile.posture.rawValue,
                initiativeID: currentBrainState.identityProfile.initiative.rawValue,
                confidenceCeiling: currentBrainState.identityProfile.confidenceCeiling,
                roleBoundaryPreset: currentBrainState.identityProfile.relationshipBoundary
            )
        }
    }

    static func brainSnapshot(
        from currentBrainState: CurrentBrainState?
    ) -> BASCurrentBrainState? {
        currentBrainState.flatMap { currentBrainState in
            BASAppleInspectionBridgeBuilder.brainSnapshot(
                modeID: currentBrainState.mode.rawValue,
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
        BASEntryIntentBridgeBuilder.envelope(
            kindID: envelope.kind.rawValue,
            surfaceID: envelope.sourceSurface.rawValue,
            preferredWorkflowID: envelope.preferredMode?.rawValue,
            promptSeed: envelope.promptSeed,
            riskLevelID: envelope.riskLevel?.rawValue,
            triggerReason: envelope.triggerReason,
            continuityToken: envelope.brainFingerprint,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt
        )
    }

    static func entryIntentSummary(from envelope: DecisionIntentEnvelope) -> BASEntryIntentSummary {
        BASEntryIntentBridgeBuilder.summary(
            kindID: envelope.kind.rawValue,
            surfaceID: envelope.sourceSurface.rawValue,
            preferredWorkflowID: envelope.preferredMode?.rawValue,
            promptSeed: envelope.promptSeed,
            riskLevelID: envelope.riskLevel?.rawValue,
            triggerReason: envelope.triggerReason,
            continuityToken: envelope.brainFingerprint,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt
        )
    }

    static func handoffSummary(from envelope: DecisionIntentEnvelope) -> BASAppleHandoffSummary {
        BASAppleHandoffBridgeBuilder.summary(
            id: envelope.id,
            surfaceID: envelope.sourceSurface.rawValue,
            preferredWorkflowID: envelope.preferredMode?.rawValue,
            riskLevelID: envelope.riskLevel?.rawValue,
            payloadSummary: envelope.promptSeed ?? envelope.triggerReason ?? envelope.kind.rawValue,
            createdAt: envelope.requestedAt,
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

    private static func taskGraphHint(from snapshot: DecisionTaskGraphSnapshot) -> BASTaskGraphHint {
        BASTaskGraphHint(
            headline: snapshot.nextActionHint,
            activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
            hasResumeCandidate: !snapshot.tasks.isEmpty,
            resumeHint: snapshot.nextActionHint
        )
    }

    private static func taskGraphInput(
        from snapshot: DecisionTaskGraphSnapshot?
    ) -> BASAppleCurrentBrainBootstrapHostTaskGraphInput? {
        snapshot.map { snapshot in
            BASAppleCurrentBrainBootstrapHostTaskGraphInput(
                headline: snapshot.nextActionHint,
                activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
                hasResumeCandidate: !snapshot.tasks.isEmpty,
                resumeHint: snapshot.nextActionHint
            )
        }
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
