import Foundation
import SwiftData
import BASHostKit

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

    typealias MemoryProjectionRefreshOutcome =
        BASAppleProjectionRefreshResult<DecisionMemorySystem.BrainStateProjection>
    typealias CurrentBrainProjectionOutcome =
        BASAppleCurrentBrainProjectionRuntimeResult<
            CurrentBrainState,
            DecisionMemorySystem.BrainStateProjection
        >

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
            input: BASAppleCurrentBrainBootstrapBridgeInputBuilder.build(
                modeID: mode.substrateModeID,
                prompt: prompt,
                triggerID: source.rawValue,
                sourceSurfaceOverrideID: envelope?.sourceSurface.rawValue,
                riskLevelOverrideID: envelope?.riskLevel?.rawValue,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                embeddingScores: embeddingScores(for: prompt),
                taskGraphHint: taskGraphInput,
                retrievalMode: retrievalMode.rawValue,
                bootstrapBehavior: BeforeProductLanguage.hostLifecycleBehavior.currentBrainBootstrapBehavior,
                reactionWeightSeed: BeforeProductLanguage.reactionWeights(for: mode),
                identityProfileOverride: BeforeProductLanguage.identityProfile(for: mode),
                cognitionBehavior: BeforeProductLanguage.hostCognition.substrateBehavior
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
                modeID: mode.substrateModeID,
                promptFragments: promptFragments,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                retrievalMode: retrievalMode.rawValue,
                bootstrapBehavior: BeforeProductLanguage.hostLifecycleBehavior.currentBrainBootstrapBehavior,
                cognitionBehavior: BeforeProductLanguage.hostCognition.substrateBehavior
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                bootstrapInput.reactionWeightSeed = BeforeProductLanguage.reactionWeights(for: mode)
                bootstrapInput.identityProfileOverride = BeforeProductLanguage.identityProfile(for: mode)
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
    static func activateQuickSession(
        _ session: QuickCheckSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        now: Date = .now
    ) -> CurrentBrainProjectionOutcome {
        executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            now: now
        ) { projection in
            primeQuickSession(
                session,
                preferences: preferences,
                context: context,
                projection: projection,
                now: now
            )
        }
    }

    @MainActor
    static func activateQuickSessionHost(
        _ session: QuickCheckSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        loadBrainState: (QuickCheckSession, CurrentBrainState) -> Void,
        commitProjection: (DecisionMemorySystem.BrainStateProjection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrainState) -> Void,
        commitSession: (QuickCheckSession) -> Void,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.activateSession(
            session: session,
            outcome: activateQuickSession(
                session,
                preferences: preferences,
                context: context,
                cachedProjection: cachedProjection,
                isProjectionDirty: isProjectionDirty,
                now: now
            ),
            loadBrainState: loadBrainState,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain,
            commitSession: commitSession
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
    static func activateBalanceSession(
        _ session: BalanceBoardSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        now: Date = .now
    ) -> CurrentBrainProjectionOutcome {
        executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            now: now
        ) { projection in
            primeBalanceSession(
                session,
                preferences: preferences,
                context: context,
                projection: projection,
                now: now
            )
        }
    }

    @MainActor
    static func activateBalanceSessionHost(
        _ session: BalanceBoardSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        loadBrainState: (BalanceBoardSession, CurrentBrainState) -> Void,
        commitProjection: (DecisionMemorySystem.BrainStateProjection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrainState) -> Void,
        commitSession: (BalanceBoardSession) -> Void,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.activateSession(
            session: session,
            outcome: activateBalanceSession(
                session,
                preferences: preferences,
                context: context,
                cachedProjection: cachedProjection,
                isProjectionDirty: isProjectionDirty,
                now: now
            ),
            loadBrainState: loadBrainState,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain,
            commitSession: commitSession
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

    @MainActor
    static func activateMirrorSession(
        _ session: MirrorWorkspaceSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        now: Date = .now
    ) -> CurrentBrainProjectionOutcome {
        executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            now: now
        ) { projection in
            primeMirrorSession(
                session,
                preferences: preferences,
                context: context,
                projection: projection,
                now: now
            )
        }
    }

    @MainActor
    static func activateMirrorSessionHost(
        _ session: MirrorWorkspaceSession,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        loadBrainState: (MirrorWorkspaceSession, CurrentBrainState) -> Void,
        commitProjection: (DecisionMemorySystem.BrainStateProjection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrainState) -> Void,
        commitSession: (MirrorWorkspaceSession) -> Void,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.activateSession(
            session: session,
            outcome: activateMirrorSession(
                session,
                preferences: preferences,
                context: context,
                cachedProjection: cachedProjection,
                isProjectionDirty: isProjectionDirty,
                now: now
            ),
            loadBrainState: loadBrainState,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain,
            commitSession: commitSession
        )
    }

    @discardableResult
    static func refreshCurrentBrainState(
        promptFragmentsByModeID: [String: [String]],
        modePriority: [String],
        taskGraph: DecisionTaskGraphSnapshot?,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalModesByModeID: [String: String],
        source: BrainStateUpdateSource,
        now: Date = .now
    ) -> CurrentBrainState {
        BASAppleCurrentBrainRuntimeBridgeExecutor.refreshActiveBrain(
            input: BASAppleCurrentBrainActiveRefreshBridgeInput(
                promptFragmentsByModeID: promptFragmentsByModeID,
                modePriority: modePriority,
                taskGraphModeID: taskGraph?.mode?.substrateModeID,
                taskGraphPromptSeed: taskGraph?.promptSeed,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                taskGraphHint: taskGraphInput(from: taskGraph),
                retrievalModesByModeID: retrievalModesByModeID,
                triggerID: source.rawValue,
                lifecycleBehavior: BeforeProductLanguage.hostLifecycleBehavior.bootstrapBehavior,
                bootstrapBehavior: BeforeProductLanguage.hostLifecycleBehavior.currentBrainBootstrapBehavior,
                cognitionBehavior: BeforeProductLanguage.hostCognition.substrateBehavior
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                if let mode = DecisionMode.fromSubstrateModeID(bootstrapInput.modeID) {
                    bootstrapInput.reactionWeightSeed = BeforeProductLanguage.reactionWeights(for: mode)
                    bootstrapInput.identityProfileOverride = BeforeProductLanguage.identityProfile(for: mode)
                }
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
            promptFragmentsByModeID: promptFragmentsByModeID(
                activeQuickSession: activeQuickSession,
                activeBalanceSession: activeBalanceSession,
                activeMirrorSession: activeMirrorSession
            ),
            modePriority: activeModePriority,
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

    @MainActor
    static func refreshCurrentBrainState(
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?,
        taskGraph: DecisionTaskGraphSnapshot?,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        source: BrainStateUpdateSource,
        now: Date = .now
    ) -> CurrentBrainProjectionOutcome {
        executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            now: now
        ) { projection in
            refreshCurrentBrainState(
                activeQuickSession: activeQuickSession,
                activeBalanceSession: activeBalanceSession,
                activeMirrorSession: activeMirrorSession,
                taskGraph: taskGraph,
                preferences: preferences,
                context: context,
                projection: projection,
                source: source,
                now: now
            )
        }
    }

    @MainActor
    static func refreshCurrentBrainHostState(
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?,
        taskGraph: DecisionTaskGraphSnapshot?,
        preferences: BeforePreferences,
        context: ModelContext,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        source: BrainStateUpdateSource,
        commitProjection: (DecisionMemorySystem.BrainStateProjection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrainState) -> Void,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.commitCurrentBrainProjection(
            outcome: refreshCurrentBrainState(
                activeQuickSession: activeQuickSession,
                activeBalanceSession: activeBalanceSession,
                activeMirrorSession: activeMirrorSession,
                taskGraph: taskGraph,
                preferences: preferences,
                context: context,
                cachedProjection: cachedProjection,
                isProjectionDirty: isProjectionDirty,
                source: source,
                now: now
            ),
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain
        )
    }

    @discardableResult
    private static func bootstrapCurrentBrainState(
        input: BASAppleCurrentBrainBootstrapBridgeInput,
        envelope: DecisionIntentEnvelope? = nil,
        taskGraph: DecisionTaskGraphSnapshot? = nil,
        context: ModelContext
    ) -> CurrentBrainState {
        let mode = DecisionMode.fromSubstrateModeID(input.modeID) ?? .quick
        let runtimeInput = BASAppleCurrentBrainHostLifecycleRuntimeInput(
            bootstrapInput: input,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval
        )
        let support: BASAppleCurrentBrainHostSupportDescriptor<
            InterventionTemplateRecord,
            FailurePatternRecord
        > = currentBrainHostSupport(mode: mode, context: context)

        return BASAppleCurrentBrainHostSupportRuntimeExecutor.bootstrapAndBuildCurrentBrain(
            input: runtimeInput,
            in: context,
            support: support,
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
            },
            buildCurrentBrain: { (committed: BASAppleCurrentBrainLifecycleResult<
                BrainStateUpdate,
                DecisionEvolutionCheckpoint
            >) in
                CurrentBrainState(
                    source: BrainStateUpdateSource(rawValue: committed.triggerID) ?? .explicitRefresh,
                    sourceSurface: DecisionIntentSourceSurface(rawValue: committed.sourceSurfaceID) ?? .app,
                    mode: DecisionMode.fromSubstrateModeID(committed.modeID) ?? .quick,
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
        )
    }

    private static func currentBrainHostSupport(
        mode: DecisionMode,
        context: ModelContext
    ) -> BASAppleCurrentBrainHostSupportDescriptor<
        InterventionTemplateRecord,
        FailurePatternRecord
    > {
        BASAppleCurrentBrainHostSupportDescriptor(
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
            templateMapper: BASAppleCurrentBrainHostTemplateMapper(
                id: \.id,
                modeID: { $0.mode.substrateModeID },
                riskLevelID: { $0.riskLevel.rawValue },
                isPinned: \.isPinned,
                successCount: \.successCount,
                updatedAt: \.updatedAt
            ),
            failurePatternMapper: BASAppleCurrentBrainHostFailurePatternMapper(
                id: \.id,
                modeID: { $0.mode.substrateModeID },
                suppressionWeight: \.suppressionWeight,
                evidenceCount: \.evidenceCount,
                updatedAt: \.updatedAt
            )
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

    static func executeObservedProviderRequest<Result: Sendable>(
        task: DecisionIntelligenceTraceKind,
        strategy: DecisionAdaptiveTaskStrategy?,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile?,
        admissionAllowed: Bool,
        observationContext: ProviderObservationContext,
        requestStart: ContinuousClock.Instant,
        clock: ContinuousClock,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        loadCachedResult: @escaping ((any DecisionIntelligenceProviding)) async -> Result?,
        assessCachedResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
        quarantineCachedResult: @escaping ((any DecisionIntelligenceProviding)) async -> Void,
        invokeProvider: @escaping ((any DecisionIntelligenceProviding)) async -> Result?,
        assessProviderResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
        storeResolvedResult: (((any DecisionIntelligenceProviding), Result) async -> Void)? = nil
    ) async -> BASProviderRequestOutcome<Result, BASProviderReleaseAssessment> {
        let registry = DecisionIntelligenceProviderRegistry.shared
        let runtimeInput: BASAppleProviderRequestRuntimeInput<any DecisionIntelligenceProviding> = BASAppleProviderRequestRuntimeInput(
            task: DecisionIntelligenceTaskRouter.substrateTraceKind(task),
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            suspendedProviderIDs: Set(
                await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders.map(\.rawValue)
            ),
            strategy: strategy.map(DecisionIntelligenceTaskRouter.substrateAdaptiveStrategy),
            descriptors: registry.descriptors().map(DecisionIntelligenceTaskRouter.substrateProviderDescriptor),
            testingOverrideProvider: testingStubProfile.flatMap { profile in
                guard preference != .template else { return nil }
                return TestingDecisionIntelligenceProvider(profile: profile) as (any DecisionIntelligenceProviding)
            },
            admissionAllowed: admissionAllowed
        )

        return await BASAppleObservedProviderRequestExecutor.execute(
            runtimeInput: runtimeInput,
            observationContext: observationContext,
            requestStart: requestStart,
            clock: clock,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerID: { $0.kind.rawValue },
            providerForID: { providerID in
                DecisionModelProviderKind(rawValue: providerID).flatMap(registry.provider(for:))
            },
            isAvailable: { $0.availabilityStatus.isAvailable },
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
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
                modeID: currentBrainState.mode.substrateModeID,
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
            preferredWorkflowID: envelope.preferredMode?.substrateModeID,
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
            preferredWorkflowID: envelope.preferredMode?.substrateModeID,
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
            preferredWorkflowID: envelope.preferredMode?.substrateModeID,
            riskLevelID: envelope.riskLevel?.rawValue,
            payloadSummary: envelope.promptSeed ?? envelope.triggerReason ?? envelope.kind.rawValue,
            createdAt: envelope.requestedAt,
            route: nil
        )
    }

    @MainActor
    static func consumeLifecycleEntrySourcesIfNeeded(
        consumeHandoff: () -> DecisionIntentEnvelope?,
        consumePendingRequest: () -> PendingLaunchRequest?,
        performCapture: (EntrySource, ScenarioType?, String) -> Void,
        performPresent: (DecisionMode, EntrySource, String) -> Void,
        performRoutedInput: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.consumeEntriesIfNeeded(
            consumeHandoff: consumeHandoff,
            handleHandoff: { envelope in
                consumeDecisionIntentEnvelope(
                    envelope,
                    performCapture: { envelope, scenario, prompt in
                        performCapture(envelope.entrySource, scenario, prompt)
                    },
                    performPresent: { envelope, mode, shouldSelectBoxTab, prompt in
                        if shouldSelectBoxTab {
                            selectBoxTab()
                        }
                        performPresent(mode, envelope.entrySource, prompt)
                    },
                    performPredictiveIntervention: performPredictiveIntervention,
                    performRestore: performRestore,
                    refreshCurrentBrain: refreshCurrentBrain
                )
            },
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: { request in
                BASApplePendingLaunchRuntimeExecutor.execute(
                    input: BASApplePendingLaunchRuntimeInput(
                        preferredModeID: DecisionMode.fromSubstrateModeID(request.preferredModeRaw)?.substrateModeID ?? request.preferredModeRaw,
                        scenarioID: request.scenarioRaw,
                        promptSeed: request.prompt
                    ),
                    performCapture: { plan in
                        performCapture(
                            request.entrySource,
                            plan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                            plan.promptSeed
                        )
                    },
                    performPresent: { plan in
                        performPresent(
                            DecisionMode.fromSubstrateModeID(plan.preferredModeID) ?? .quick,
                            request.entrySource,
                            plan.promptSeed
                        )
                    },
                    performRoutedInput: { plan in
                        performRoutedInput(plan.promptSeed, request.entrySource)
                    }
                )
            }
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
        performCapture: (EntrySource, ScenarioType?, String) -> Void,
        performPresent: (DecisionMode, EntrySource, String) -> Void,
        performRoutedInput: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.execute(
            phase: phase,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: { source in
                refreshCurrentBrain(
                    BrainStateUpdateSource(rawValue: source) ?? .explicitRefresh
                )
            },
            presentPendingReflection: presentPendingReflection,
            consumeHandoff: consumeHandoff,
            handleHandoff: { envelope in
                consumeDecisionIntentEnvelope(
                    envelope,
                    performCapture: { envelope, scenario, prompt in
                        performCapture(envelope.entrySource, scenario, prompt)
                    },
                    performPresent: { envelope, mode, shouldSelectBoxTab, prompt in
                        if shouldSelectBoxTab {
                            selectBoxTab()
                        }
                        performPresent(mode, envelope.entrySource, prompt)
                    },
                    performPredictiveIntervention: performPredictiveIntervention,
                    performRestore: performRestore,
                    refreshCurrentBrain: refreshCurrentBrain
                )
            },
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: { request in
                BASApplePendingLaunchRuntimeExecutor.execute(
                    input: BASApplePendingLaunchRuntimeInput(
                        preferredModeID: DecisionMode.fromSubstrateModeID(request.preferredModeRaw)?.substrateModeID ?? request.preferredModeRaw,
                        scenarioID: request.scenarioRaw,
                        promptSeed: request.prompt
                    ),
                    performCapture: { plan in
                        performCapture(
                            request.entrySource,
                            plan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                            plan.promptSeed
                        )
                    },
                    performPresent: { plan in
                        performPresent(
                            DecisionMode.fromSubstrateModeID(plan.preferredModeID) ?? .quick,
                            request.entrySource,
                            plan.promptSeed
                        )
                    },
                    performRoutedInput: { plan in
                        performRoutedInput(plan.promptSeed, request.entrySource)
                    }
                )
            },
            restoreActiveWorkspace: performRestore,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }

    @MainActor
    static func consumeDecisionIntentEnvelope(
        _ envelope: DecisionIntentEnvelope,
        performCapture: (DecisionIntentEnvelope, ScenarioType?, String) -> Void,
        performPresent: (DecisionIntentEnvelope, DecisionMode, Bool, String) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        BASAppleEntryIntentRuntimeExecutor.execute(
            input: BASAppleEntryIntentRuntimeInput(
                kindID: envelope.kind.rawValue,
                surfaceID: envelope.sourceSurface.rawValue,
                preferredModeID: envelope.preferredMode?.substrateModeID,
                scenarioID: envelope.scenario?.rawValue,
                promptSeed: envelope.promptSeed,
                riskLevelID: envelope.riskLevel?.rawValue,
                triggerReason: envelope.triggerReason,
                predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation(
                    fallbackTitle: BeforeProductLanguage.hostPresentation.predictiveIntervention.mediumRiskTitle,
                    fallbackDetail: BeforeProductLanguage.hostPresentation.predictiveIntervention.mediumRiskDetail,
                    fallbackReason: BeforeProductLanguage.hostPresentation.predictiveIntervention.defaultReason
                ),
                expiresAt: envelope.expiresAt
            ),
            performCapture: { actionPlan in
                performCapture(
                    envelope,
                    actionPlan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                    actionPlan.promptSeed
                )
            },
            performPresent: { actionPlan in
                performPresent(
                    envelope,
                    DecisionMode.fromSubstrateModeID(actionPlan.preferredModeID) ?? .quick,
                    actionPlan.shouldSelectBoxTab,
                    actionPlan.promptSeed
                )
            },
            performPredictiveIntervention: performPredictiveIntervention,
            performRestore: performRestore,
            refreshCurrentBrain: { triggerID in
                refreshCurrentBrain(
                    BrainStateUpdateSource(rawValue: triggerID) ?? .explicitRefresh
                )
            }
        )
    }

    @MainActor
    static func reopenTomorrowBoxItem(
        _ item: TomorrowBoxItem,
        clearActiveDecisionFlows: () -> Void,
        activateQuick: (QuickCheckSession) -> Void,
        activateBalance: (BalanceBoardSession) -> Void,
        activateMirror: (MirrorWorkspaceSession) -> Void,
        startQuick: (String) -> Void,
        startBalance: (String) -> Void,
        startMirror: (String) -> Void,
        removeTomorrowBoxItem: () -> Void,
        setInterventionCandidate: (InterventionPredictionCandidate?) -> Void,
        refreshPredictedIntervention: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        let draft = item.draft
        let followUp = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: item.riskLevel?.rawValue,
            title: item.title,
            detail: item.detail,
            modeID: item.mode.substrateModeID,
            reopenHint: item.reopenHint,
            templateHint: item.templateHint,
            interventionHistorySummary: item.interventionHistorySummary
        )

        BASAppleDeferredReopenExecutor.execute(
            modeID: item.mode.substrateModeID,
            promptSeed: item.prompt,
            hasDraft: draft != nil,
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            activatePrimaryFromDraft: {
                guard let draft else { return }
                activateQuick(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparativeFromDraft: {
                guard let draft else { return }
                activateBalance(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflectiveFromDraft: {
                guard let draft else { return }
                activateMirror(draft.restoreMirrorSession(entrySource: .app))
            },
            startPrimary: startQuick,
            startComparative: startBalance,
            startReflective: startMirror,
            removeDeferredItem: removeTomorrowBoxItem,
            followUp: followUp,
            setInterventionSuggestion: { suggestion in
                setInterventionCandidate(suggestion.flatMap(interventionCandidate(from:)))
            },
            refreshPredictedIntervention: refreshPredictedIntervention,
            selectHomeTab: selectHomeTab,
            persistActiveWorkspaceState: persistActiveWorkspaceState
        )
    }

    @MainActor
    static func reopenCheckEvent(
        _ event: CheckEvent,
        clearActiveDecisionFlows: () -> Void,
        activateQuick: (QuickCheckSession) -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        BASAppleSimpleReopenExecutor.execute(
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            reopen: { activateQuick(event.restoredSession()) },
            afterSuccessfulReopen: {
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        )
    }

    @MainActor
    static func reopenBalanceRecord(
        _ record: BalanceDecisionRecord,
        clearActiveDecisionFlows: () -> Void,
        activateBalance: (BalanceBoardSession) -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        BASAppleSimpleReopenExecutor.execute(
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            reopen: { activateBalance(record.restoredSession()) },
            afterSuccessfulReopen: {
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        )
    }

    @MainActor
    static func reopenMirrorRecord(
        _ record: MirrorDecisionRecord,
        clearActiveDecisionFlows: () -> Void,
        activateMirror: (MirrorWorkspaceSession) -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        BASAppleSimpleReopenExecutor.execute(
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            reopen: { activateMirror(record.restoredSession()) },
            afterSuccessfulReopen: {
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        )
    }

    @MainActor
    static func reopenSupportRequest(
        _ request: SupportRequest,
        clearActiveDecisionFlows: () -> Void,
        activateQuick: (QuickCheckSession) -> Void,
        activateBalance: (BalanceBoardSession) -> Void,
        activateMirror: (MirrorWorkspaceSession) -> Void,
        markHeard: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        guard let mode = request.mode, let draft = request.draft else { return }

        guard BASAppleDraftedWorkflowReopenExecutor.execute(
            modeID: mode.substrateModeID,
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            activatePrimary: {
                activateQuick(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparative: {
                activateBalance(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflective: {
                activateMirror(draft.restoreMirrorSession(entrySource: .app))
            },
            afterSuccessfulReopen: {
                markHeard()
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        ) else {
            return
        }
    }

    @MainActor
    static func reopenSharedLifeItem(
        _ item: SharedLifeBoxItem,
        clearActiveDecisionFlows: () -> Void,
        activateQuick: (QuickCheckSession) -> Void,
        activateBalance: (BalanceBoardSession) -> Void,
        activateMirror: (MirrorWorkspaceSession) -> Void,
        markReviewing: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        guard let mode = item.mode, let draft = item.draft else { return }

        guard BASAppleDraftedWorkflowReopenExecutor.execute(
            modeID: mode.substrateModeID,
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            activatePrimary: {
                activateQuick(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparative: {
                activateBalance(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflective: {
                activateMirror(draft.restoreMirrorSession(entrySource: .app))
            },
            afterSuccessfulReopen: {
                markReviewing()
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        ) else {
            return
        }
    }

    @MainActor
    static func restoreActiveWorkspaceIfNeeded(
        preferences: BeforePreferences,
        hasActivePrimaryWorkflow: Bool,
        hasActiveComparativeWorkflow: Bool,
        hasActiveReflectiveWorkflow: Bool,
        hasReflectionContext: Bool,
        loadState: () -> ActiveDecisionWorkspaceState?,
        restorePrimary: (ActiveDecisionWorkspaceState) -> Void,
        restoreComparative: (ActiveDecisionWorkspaceState) -> Void,
        restoreReflective: (ActiveDecisionWorkspaceState) -> Void,
        selectHomeTab: () -> Void,
        afterRestore: () -> Void
    ) {
        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: preferences.restoreInProgressWorkspaces,
                hasActivePrimaryWorkflow: hasActivePrimaryWorkflow,
                hasActiveComparativeWorkflow: hasActiveComparativeWorkflow,
                hasActiveReflectiveWorkflow: hasActiveReflectiveWorkflow,
                hasReflectionContext: hasReflectionContext
            ),
            loadState: loadState,
            modeID: { $0.modeRaw },
            restorePrimary: restorePrimary,
            restoreComparative: restoreComparative,
            restoreReflective: restoreReflective,
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
        BASAppleCurrentBrainProjectionRuntimeExecutor.resolveProjection(
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

    static func refreshMemoryProjectionHostState(
        force: Bool,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        context: ModelContext,
        commitProjection: (DecisionMemorySystem.BrainStateProjection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.commitProjectionRefresh(
            outcome: resolveMemoryProjection(
                force: force,
                cachedProjection: cachedProjection,
                isDirty: isProjectionDirty,
                context: context,
                now: now
            ),
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice
        )
    }

    private static func executeCurrentBrainProjection(
        forceProjectionRefresh: Bool = false,
        cachedProjection: DecisionMemorySystem.BrainStateProjection?,
        isProjectionDirty: Bool,
        context: ModelContext,
        now: Date,
        execute: (DecisionMemorySystem.BrainStateProjection) -> CurrentBrainState
    ) -> CurrentBrainProjectionOutcome {
        BASAppleCurrentBrainProjectionRuntimeExecutor.execute(
            forceProjectionRefresh: forceProjectionRefresh,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: cachedProjection != nil,
                isDirty: isProjectionDirty
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
                resolveMemoryProjection(
                    force: true,
                    cachedProjection: cachedProjection,
                    isDirty: isProjectionDirty,
                    context: context,
                    now: now
                )
            },
            execute: execute
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
            snapshotsInPriorityOrder: [
                { activeQuickSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
                { activeBalanceSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
                { activeMirrorSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) }
            ],
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
            preferredModeID: candidate.suggestedMode?.substrateModeID,
            reason: candidate.reason,
            createdAt: candidate.createdAt,
            expiresAt: candidate.expiresAt
        )
    }

    private static func interventionCandidate(
        from suggestion: BASAppleReopenInterventionSuggestion
    ) -> InterventionPredictionCandidate {
        InterventionPredictionCandidate(
            riskLevel: InterventionRiskLevel(rawValue: suggestion.riskLevelID) ?? .medium,
            title: suggestion.title,
            detail: suggestion.detail ?? "",
            evidenceSignalCount: suggestion.evidenceSignalCount,
            suggestedMode: DecisionMode.fromSubstrateModeID(suggestion.suggestedModeID),
            reason: suggestion.reason,
            expiresAt: suggestion.expiresAt
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
            suggestedMode: DecisionMode.fromSubstrateModeID(summary.preferredModeID),
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
            DecisionMode.quick.substrateModeID: currentBrainRuntimeRetrievalMode(
                for: .quick,
                preferences: preferences
            ).rawValue,
            DecisionMode.balance.substrateModeID: currentBrainRuntimeRetrievalMode(
                for: .balance,
                preferences: preferences
            ).rawValue,
            DecisionMode.mirror.substrateModeID: currentBrainRuntimeRetrievalMode(
                for: .mirror,
                preferences: preferences
            ).rawValue
        ]
    }

    private static var activeModePriority: [String] {
        [
            DecisionMode.quick.substrateModeID,
            DecisionMode.balance.substrateModeID,
            DecisionMode.mirror.substrateModeID
        ]
    }

    @MainActor
    private static func promptFragmentsByModeID(
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?
    ) -> [String: [String]] {
        var fragmentsByModeID: [String: [String]] = [:]
        if let activeQuickSession {
            fragmentsByModeID[DecisionMode.quick.substrateModeID] = quickPromptFragments(for: activeQuickSession)
        }
        if let activeBalanceSession {
            fragmentsByModeID[DecisionMode.balance.substrateModeID] = balancePromptFragments(for: activeBalanceSession)
        }
        if let activeMirrorSession {
            fragmentsByModeID[DecisionMode.mirror.substrateModeID] = mirrorPromptFragments(for: activeMirrorSession)
        }
        return fragmentsByModeID
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
