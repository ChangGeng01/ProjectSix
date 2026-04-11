import Foundation
import SwiftData
import BASAdmin
import BASAppleAdapters
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

enum BehavioralAISubstrateBridge {
    typealias ProviderObservationContext = BASAppleHostProviderObservationContext<
        DecisionIntelligenceTraceKind,
        DecisionFrontstageState,
        DecisionContextPreparedState,
        DecisionNeuralState,
        DecisionBrainState,
        DecisionAdaptiveTaskStrategy,
        DecisionIntelligencePromptContract.ContextBudget,
        DecisionIntelligenceAdmissionDecision
    >

    struct MemoryProjectionRefreshOutcome {
        let projection: DecisionMemorySystem.BrainStateProjection
        let refreshed: Bool
        let notice: String?
    }

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

    @MainActor
    @discardableResult
    static func primeQuickSession(
        _ session: QuickCheckSession,
        preferences: BeforePreferences,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        now: Date = .now
    ) -> CurrentBrainState {
        primeCurrentBrainState(
            mode: .quick,
            promptFragments: quickPromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .quick,
                preferences: preferences
            ),
            now: now
        )
    }

    @MainActor
    @discardableResult
    static func primeBalanceSession(
        _ session: BalanceBoardSession,
        preferences: BeforePreferences,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        now: Date = .now
    ) -> CurrentBrainState {
        primeCurrentBrainState(
            mode: .balance,
            promptFragments: balancePromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .balance,
                preferences: preferences
            ),
            now: now
        )
    }

    @MainActor
    @discardableResult
    static func primeMirrorSession(
        _ session: MirrorWorkspaceSession,
        preferences: BeforePreferences,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        now: Date = .now
    ) -> CurrentBrainState {
        primeCurrentBrainState(
            mode: .mirror,
            promptFragments: mirrorPromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .mirror,
                preferences: preferences
            ),
            now: now
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

    @MainActor
    @discardableResult
    static func refreshCurrentBrainState(
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?,
        taskGraph: DecisionTaskGraphSnapshot?,
        preferences: BeforePreferences,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        source: BrainStateUpdateSource,
        now: Date = .now
    ) -> CurrentBrainState {
        refreshCurrentBrainState(
            quickPromptFragments: activeQuickSession.map(quickPromptFragments(for:)),
            balancePromptFragments: activeBalanceSession.map(balancePromptFragments(for:)),
            mirrorPromptFragments: activeMirrorSession.map(mirrorPromptFragments(for:)),
            taskGraph: taskGraph,
            context: context,
            projection: projection,
            retrievalModesByModeID: currentBrainRuntimeRetrievalModesByModeID(
                preferences: preferences
            ),
            source: source,
            now: now
        )
    }

    @discardableResult
    private static func bootstrapCurrentBrainState(
        input: BASAppleCurrentBrainBootstrapBridgeInput,
        envelope: DecisionIntentEnvelope? = nil,
        taskGraph: DecisionTaskGraphSnapshot? = nil,
        context: ModelContext
    ) -> CurrentBrainState {
        let mode = DecisionMode(rawValue: input.modeID) ?? .quick
        let committed: BASAppleCurrentBrainLifecycleResult<
            BrainStateUpdate,
            DecisionEvolutionCheckpoint
        > = BASAppleCurrentBrainLifecycleExecutor.bootstrapAndCommit(
            input: input,
            in: context,
            createdAt: input.now,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
            prepareLifecycleState: {
                InterventionTemplateStore.ensureDefaults(in: context)
                FailurePatternStore.syncFromHistory(in: context)
            },
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
            source: BrainStateUpdateSource(rawValue: committed.triggerID) ?? .explicitRefresh,
            sourceSurface: DecisionIntentSourceSurface(rawValue: committed.sourceSurfaceID) ?? .app,
            mode: DecisionMode(rawValue: committed.modeID) ?? .quick,
            riskLevel: InterventionRiskLevel(rawValue: committed.riskLevelID) ?? .low,
            taskGraph: taskGraph,
            brainState: committed.brainState,
            dominantGoal: committed.dominantGoal,
            activeConstraints: committed.activeConstraints,
            activeTemplateIDs: committed.activeTemplateIDs,
            failureGuardIDs: committed.failureGuardIDs,
            sourceIntentEnvelope: envelope,
            loadedAt: committed.loadedAt
        )
    }

    static func providerProfiles() -> [String: BASAppleProviderProfile] {
        BASAppleHostProviderObservationBridge.providerProfiles(
            descriptors: DecisionIntelligenceProviderRegistry.shared.descriptors(),
            providerID: { $0.kind.rawValue },
            title: { $0.kind.title },
            activeResolutionDetail: { descriptor in
                guard descriptor.kind == .gemmaE4B else { return nil }
                let resolution = GemmaE4BIntelligenceService.backendResolution(
                    policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                )
                return "\(resolution.title): \(resolution.detail)"
            },
            activeBackendID: { descriptor in
                guard descriptor.kind == .gemmaE4B else { return nil }
                return GemmaE4BIntelligenceService.backendResolution(
                    policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                ).effectiveBackend.rawValue
            }
        )
    }

    static func observeProviderRequestEvent<Result: Sendable>(
        _ event: BASProviderRequestEvent<any DecisionIntelligenceProviding, Result, BASProviderReleaseAssessment>,
        context: ProviderObservationContext,
        durationMs: Double,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        storeResolvedResult: (((any DecisionIntelligenceProviding), Result) async -> Void)? = nil
    ) async {
        await BASAppleHostProviderObservationExecutor.handleEvent(
            event,
            context: context,
            durationMs: durationMs,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerID: { $0.kind.rawValue },
            storeResolvedResult: storeResolvedResult,
            applyCircuitEvent: { event in
                await BASAppleHostProviderObservationBridge.applyCircuitEvent(
                    event,
                    providerForID: DecisionModelProviderKind.init(rawValue:),
                    kindForID: DecisionIntelligenceTraceKind.init(rawValue:),
                    onCacheHit: { provider in
                        await DecisionIntelligenceCircuitBreaker.shared.record(
                            provider: provider,
                            event: .cacheHit
                        )
                    },
                    onProviderFailure: { provider in
                        await DecisionIntelligenceCircuitBreaker.shared.record(
                            provider: provider,
                            event: .providerFailure
                        )
                    },
                    onProviderSuccess: { provider, kind, durationMs in
                        await DecisionIntelligenceCircuitBreaker.shared.record(
                            provider: provider,
                            event: .providerSuccess(
                                kind: kind,
                                durationMs: durationMs
                            )
                        )
                    }
                )
            },
            recordTelemetry: { observation in
                await DecisionIntelligenceTelemetryStore.shared.record(
                    observation: observation
                )
            },
            recordTrace: { traceRecord in
                let preferredProvider = DecisionModelProviderKind(
                    rawValue: traceRecord.preferredProviderID
                ) ?? .template
                let activeProvider = traceRecord.activeProviderID.flatMap(DecisionModelProviderKind.init(rawValue:))
                let attemptedProviders = traceRecord.attemptedProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:))

                let trace = DecisionIntelligenceTrace(
                    kind: traceRecord.kind,
                    preferredProvider: preferredProvider,
                    activeProvider: activeProvider,
                    attemptedProviders: attemptedProviders,
                    allowFallbacks: traceRecord.allowFallbacks,
                    usedFallback: traceRecord.usedFallback,
                    frontstageState: traceRecord.frontstageState,
                    contextState: traceRecord.contextState,
                    neuralState: traceRecord.neuralState,
                    brainState: traceRecord.brainState,
                    runtimeStrategy: traceRecord.runtimeStrategy,
                    promptBudget: traceRecord.promptBudget,
                    admissionDecision: traceRecord.admissionDecision,
                    semanticPromptFingerprint: traceRecord.semanticPromptFingerprint,
                    stablePrefixFingerprint: traceRecord.stablePrefixFingerprint,
                    consistencyCheck: traceRecord.consistencyCheck,
                    consistencyRejected: traceRecord.consistencyRejected,
                    substrateTrace: traceRecord.substrateTrace,
                    prompt: traceRecord.prompt,
                    outputPreview: traceRecord.outputPreview,
                    detail: traceRecord.detail
                )

                DecisionIntelligenceDebugStore.shared.record(trace)
            }
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

    @MainActor
    static func consumePendingLaunchRequest(
        consumeHandoff: () -> DecisionIntentEnvelope?,
        handleHandoff: (DecisionIntentEnvelope) -> Void,
        consumePendingRequest: () -> PendingLaunchRequest?,
        performQuickCapture: (EntrySource, ScenarioType?, String) -> Void,
        performOpenMode: (DecisionMode, EntrySource, String) -> Void,
        performRoutedPrompt: (String, EntrySource) -> Void
    ) {
        if let envelope = consumeHandoff() {
            handleHandoff(envelope)
            return
        }

        guard let request = consumePendingRequest() else { return }
        let plan = BASApplePendingLaunchOutcomeBuilder.resolve(
            preferredModeID: request.preferredModeRaw,
            scenarioID: request.scenarioRaw,
            promptSeed: request.prompt
        )

        BASApplePendingLaunchOutcomeExecutor.execute(
            plan: plan,
            performQuickCapture: { plan in
                performQuickCapture(
                    request.entrySource,
                    plan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                    plan.promptSeed
                )
            },
            performOpenMode: { plan in
                performOpenMode(
                    plan.preferredModeID.flatMap(DecisionMode.init(rawValue:)) ?? .quick,
                    request.entrySource,
                    plan.promptSeed
                )
            },
            performRoutedPrompt: { plan in
                performRoutedPrompt(plan.promptSeed, request.entrySource)
            }
        )
    }

    @MainActor
    static func consumeLifecycleEntrySourcesIfNeeded(
        consumeHandoff: () -> DecisionIntentEnvelope?,
        consumePendingRequest: () -> PendingLaunchRequest?,
        performQuickCapture: (EntrySource, ScenarioType?, String) -> Void,
        performOpenMode: (DecisionMode, EntrySource, String) -> Void,
        performRoutedPrompt: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestoreWorkspace: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        consumePendingLaunchRequest(
            consumeHandoff: consumeHandoff,
            handleHandoff: { envelope in
                consumeDecisionIntentEnvelope(
                    envelope,
                    performQuickCapture: { envelope, scenario, prompt in
                        performQuickCapture(envelope.entrySource, scenario, prompt)
                    },
                    performOpenMode: { envelope, mode, shouldSelectBoxTab, prompt in
                        if shouldSelectBoxTab {
                            selectBoxTab()
                        }
                        performOpenMode(mode, envelope.entrySource, prompt)
                    },
                    performPredictiveIntervention: performPredictiveIntervention,
                    performRestoreWorkspace: performRestoreWorkspace,
                    refreshCurrentBrain: refreshCurrentBrain
                )
            },
            consumePendingRequest: consumePendingRequest,
            performQuickCapture: performQuickCapture,
            performOpenMode: performOpenMode,
            performRoutedPrompt: performRoutedPrompt
        )
    }

    @MainActor
    static func executeAppLifecyclePhase(
        _ phase: BASAppleLifecycleBootstrapPhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void,
        presentPendingReflection: () -> Void,
        consumeHandoff: () -> DecisionIntentEnvelope?,
        consumePendingRequest: () -> PendingLaunchRequest?,
        performQuickCapture: (EntrySource, ScenarioType?, String) -> Void,
        performOpenMode: (DecisionMode, EntrySource, String) -> Void,
        performRoutedPrompt: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestoreWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        executeLifecycleBootstrapPhase(
            phase,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: refreshCurrentBrain,
            presentPendingReflection: presentPendingReflection,
            consumeLifecycleEntries: {
                consumeLifecycleEntrySourcesIfNeeded(
                    consumeHandoff: consumeHandoff,
                    consumePendingRequest: consumePendingRequest,
                    performQuickCapture: performQuickCapture,
                    performOpenMode: performOpenMode,
                    performRoutedPrompt: performRoutedPrompt,
                    selectBoxTab: selectBoxTab,
                    performPredictiveIntervention: performPredictiveIntervention,
                    performRestoreWorkspace: performRestoreWorkspace,
                    refreshCurrentBrain: refreshCurrentBrain
                )
            },
            restoreActiveWorkspace: performRestoreWorkspace,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }

    @MainActor
    static func consumeDecisionIntentEnvelope(
        _ envelope: DecisionIntentEnvelope,
        performQuickCapture: (DecisionIntentEnvelope, ScenarioType?, String) -> Void,
        performOpenMode: (DecisionIntentEnvelope, DecisionMode, Bool, String) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestoreWorkspace: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: envelope.kind.rawValue,
            surfaceID: envelope.sourceSurface.rawValue,
            preferredModeID: envelope.preferredMode?.rawValue,
            scenarioID: envelope.scenario?.rawValue,
            promptSeed: envelope.promptSeed,
            riskLevelID: envelope.riskLevel?.rawValue,
            triggerReason: envelope.triggerReason,
            expiresAt: envelope.expiresAt
        )

        BASAppleEntryIntentOutcomeExecutor.execute(
            resolution: resolution,
            performQuickCapture: { actionPlan in
                performQuickCapture(
                    envelope,
                    actionPlan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                    actionPlan.promptSeed
                )
            },
            performOpenMode: { actionPlan in
                performOpenMode(
                    envelope,
                    actionPlan.preferredModeID.flatMap(DecisionMode.init(rawValue:)) ?? .quick,
                    actionPlan.shouldSelectBoxTab,
                    actionPlan.promptSeed
                )
            },
            performPredictiveIntervention: performPredictiveIntervention,
            performRestoreWorkspace: performRestoreWorkspace,
            refreshCurrentBrain: { triggerID in
                refreshCurrentBrain(
                    BrainStateUpdateSource(rawValue: triggerID) ?? .explicitRefresh
                )
            }
        )
    }

    @MainActor
    static func executeLifecycleBootstrapPhase(
        _ phase: BASAppleLifecycleBootstrapPhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void,
        presentPendingReflection: () -> Void,
        consumeLifecycleEntries: () -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        BASAppleLifecycleBootstrapExecutor.execute(
            phase: phase,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: { triggerID in
                refreshCurrentBrain(
                    BrainStateUpdateSource(rawValue: triggerID) ?? .explicitRefresh
                )
            },
            presentPendingReflection: presentPendingReflection,
            consumePendingLaunchRequest: consumeLifecycleEntries,
            restoreActiveWorkspace: restoreActiveWorkspace,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }

    @MainActor
    static func restoreActiveWorkspaceIfNeeded(
        preferences: BeforePreferences,
        hasActiveQuickSession: Bool,
        hasActiveBalanceSession: Bool,
        hasActiveMirrorSession: Bool,
        hasReflectionContext: Bool,
        loadState: () -> ActiveDecisionWorkspaceState?,
        restoreQuick: (ActiveDecisionWorkspaceState) -> Void,
        restoreBalance: (ActiveDecisionWorkspaceState) -> Void,
        restoreMirror: (ActiveDecisionWorkspaceState) -> Void,
        selectHomeTab: () -> Void,
        afterRestore: () -> Void
    ) {
        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: preferences.restoreInProgressWorkspaces,
                hasActiveQuickSession: hasActiveQuickSession,
                hasActiveBalanceSession: hasActiveBalanceSession,
                hasActiveMirrorSession: hasActiveMirrorSession,
                hasReflectionContext: hasReflectionContext
            ),
            loadState: loadState,
            modeID: { $0.modeRaw },
            restoreQuick: restoreQuick,
            restoreBalance: restoreBalance,
            restoreMirror: restoreMirror,
            selectHomeTab: selectHomeTab,
            afterRestore: afterRestore
        )
    }

    static func resolveMemoryProjection(
        force: Bool,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isDirty: Bool,
        context: ModelContext,
        now: Date = .now
    ) -> MemoryProjectionRefreshOutcome {
        BASAppleMemoryProjectionRefreshExecutor.resolve(
            force: force,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: cachedProjection != nil,
                isDirty: isDirty
            ),
            cached: {
                cachedProjection.map {
                    MemoryProjectionRefreshOutcome(
                        projection: $0,
                        refreshed: false,
                        notice: nil
                    )
                }
            },
            refresh: {
                InterventionTemplateStore.ensureDefaults(in: context)
                FailurePatternStore.syncFromHistory(in: context)
                let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
                return MemoryProjectionRefreshOutcome(
                    projection: projection,
                    refreshed: true,
                    notice: PersistenceIssueRecorder.latestNotice() ?? StateStorageIssueRecorder.latestNotice()
                )
            }
        )
    }

    static func refreshPredictedIntervention(
        existing: InterventionPredictionCandidate?,
        currentBrainState: CurrentBrainState?,
        context: ModelContext,
        preferences: BeforePreferences,
        now: Date = .now
    ) -> InterventionPredictionCandidate? {
        let next = InterventionPredictionEngine.predictCandidate(
            currentBrainState: currentBrainState,
            context: context,
            preferences: preferences,
            now: now
        )

        return BASApplePredictiveInterventionReconciler.reconcile(
            existing: existing.map(predictiveInterventionSummary(from:)),
            next: next.map(predictiveInterventionSummary(from:))
        )
        .map(interventionCandidate(from:))
    }

    @MainActor
    static func schedulePredictiveInterventionIfNeeded(
        candidate: InterventionPredictionCandidate?,
        preferences: BeforePreferences,
        currentBrainState: CurrentBrainState?,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        upsertTrigger: (InterventionPredictionCandidate, Bool) -> Void,
        cancelNotification: (UUID) -> Void,
        scheduleNotification: (InterventionPredictionCandidate) -> Void
    ) {
        let summary = candidate.map(predictiveInterventionSummary(from:))
        guard BASApplePredictiveInterventionDeliveryPlanner.shouldEvaluatePolicy(
            candidate: summary,
            predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled
        ), let candidate else {
            return
        }

        let policyDecision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: preferences,
            currentBrainState: currentBrainState,
            context: context,
            now: now,
            calendar: calendar
        )

        let plan = BASApplePredictiveInterventionDeliveryPlanner.plan(
            candidate: summary,
            predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled,
            policyAllowed: policyDecision.isAllowed
        )

        BASApplePredictiveInterventionDeliveryExecutor.execute(
            plan: plan,
            upsertTrigger: { summary, wasDelivered in
                upsertTrigger(
                    interventionCandidate(from: summary),
                    wasDelivered
                )
            },
            cancelNotification: cancelNotification,
            scheduleNotification: { summary in
                scheduleNotification(
                    interventionCandidate(from: summary)
                )
            }
        )
    }

    @MainActor
    static func refreshActiveTaskGraphSnapshot(
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?,
        saveSnapshot: (DecisionTaskGraphSnapshot) -> Void,
        clearSnapshot: () -> Void
    ) -> DecisionTaskGraphSnapshot? {
        BASAppleTaskGraphLifecycleExecutor.refresh(
            quickSnapshot: { activeQuickSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
            balanceSnapshot: { activeBalanceSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
            mirrorSnapshot: { activeMirrorSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
            saveSnapshot: saveSnapshot,
            clearSnapshot: clearSnapshot
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

    private static func predictiveInterventionSummary(
        from candidate: InterventionPredictionCandidate
    ) -> BASApplePredictiveInterventionCandidateSummary {
        BASApplePredictiveInterventionCandidateSummary(
            id: candidate.id,
            riskLevelID: candidate.riskLevel.rawValue,
            title: candidate.title,
            detail: candidate.detail,
            evidenceSignalCount: candidate.evidenceSignalCount,
            preferredModeID: candidate.suggestedModeRaw,
            reason: candidate.reason,
            createdAt: candidate.createdAt,
            expiresAt: candidate.expiresAt
        )
    }

    private static func interventionCandidate(
        from summary: BASApplePredictiveInterventionCandidateSummary
    ) -> InterventionPredictionCandidate {
        InterventionPredictionCandidate(
            id: summary.id,
            riskLevel: InterventionRiskLevel(rawValue: summary.riskLevelID) ?? .medium,
            title: summary.title,
            detail: summary.detail,
            evidenceSignalCount: summary.evidenceSignalCount,
            suggestedMode: summary.preferredModeID.flatMap(DecisionMode.init(rawValue:)),
            reason: summary.reason,
            createdAt: summary.createdAt,
            expiresAt: summary.expiresAt
        )
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

    private static func currentBrainRuntimeRetrievalMode(
        for mode: DecisionMode,
        preferences: BeforePreferences
    ) -> DecisionRetrievalMode {
        let traceKind = DecisionIntelligenceTraceKind(rawValue: mode.rawValue) ?? .quick
        return DecisionIntelligenceCoordinator
            .executionProfile(preferences: preferences)
            .strategy(for: traceKind)
            .retrievalMode
    }

    private static func currentBrainRuntimeRetrievalModesByModeID(
        preferences: BeforePreferences
    ) -> [String: String] {
        [
            DecisionMode.quick.rawValue: currentBrainRuntimeRetrievalMode(
                for: .quick,
                preferences: preferences
            ).rawValue,
            DecisionMode.balance.rawValue: currentBrainRuntimeRetrievalMode(
                for: .balance,
                preferences: preferences
            ).rawValue,
            DecisionMode.mirror.rawValue: currentBrainRuntimeRetrievalMode(
                for: .mirror,
                preferences: preferences
            ).rawValue
        ]
    }

    @MainActor
    private static func quickPromptFragments(for session: QuickCheckSession) -> [String] {
        [
            session.scenario.title,
            session.note,
            session.motivation?.title ?? "",
            session.expectedOutcome?.title ?? "",
            session.controlLevel?.title ?? ""
        ]
        .map(trimmed)
    }

    @MainActor
    private static func balancePromptFragments(for session: BalanceBoardSession) -> [String] {
        [
            session.prompt,
            session.desire,
            session.concern,
            session.constraint,
            session.longTerm
        ]
        .map(trimmed)
    }

    @MainActor
    private static func mirrorPromptFragments(for session: MirrorWorkspaceSession) -> [String] {
        [
            session.prompt,
            session.emotion,
            session.relationship,
            session.reality,
            session.longTerm,
            session.selfLens
        ]
        .map(trimmed)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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
