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
        now: Date = .now,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil
    ) -> CurrentBrainState {
        let taskGraphInput = taskGraphInput(from: taskGraph)
        let cognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: executionCapabilityFrame
        )
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
                bootstrapBehavior: BeforeProductCompatibility.currentBrainBootstrapBehavior,
                reactionWeightSeed: BeforeProductCompatibility.reactionWeights(for: mode),
                identityProfileOverride: BeforeProductCompatibility.identityProfile(for: mode),
                cognitionBehavior: cognitionBehavior
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
        now: Date = .now,
        cognitionBehavior: BASCognitionBehavior = BeforeProductCompatibility.substrateCognitionBehavior
    ) -> CurrentBrainState {
        return BASAppleCurrentBrainRuntimeBridgeExecutor.primeSession(
            input: BASAppleCurrentBrainSessionBridgeInput(
                modeID: mode.substrateModeID,
                promptFragments: promptFragments,
                preferredLanguages: Locale.preferredLanguages,
                now: now,
                projection: projection.baseProjection,
                retrievalMode: retrievalMode.rawValue,
                bootstrapBehavior: BeforeProductCompatibility.currentBrainBootstrapBehavior,
                cognitionBehavior: cognitionBehavior
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                bootstrapInput.reactionWeightSeed = BeforeProductCompatibility.reactionWeights(for: mode)
                bootstrapInput.identityProfileOverride = BeforeProductCompatibility.identityProfile(for: mode)
                bootstrapInput.cognitionBehavior = cognitionBehavior
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
        let cognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: preferences
        )
        return primeCurrentBrainState(
            mode: .quick,
            promptFragments: quickPromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .quick,
                preferences: preferences
            ),
            now: now,
            cognitionBehavior: cognitionBehavior
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
        let executionCapabilityFrame = BeforeProductCompatibility.resolvedExecutionCapabilityFrame(
            for: preferences
        )
        return executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            executionCapabilityFrame: executionCapabilityFrame,
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
        let cognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: preferences
        )
        return primeCurrentBrainState(
            mode: .balance,
            promptFragments: balancePromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .balance,
                preferences: preferences
            ),
            now: now,
            cognitionBehavior: cognitionBehavior
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
        let executionCapabilityFrame = BeforeProductCompatibility.resolvedExecutionCapabilityFrame(
            for: preferences
        )
        return executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            executionCapabilityFrame: executionCapabilityFrame,
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
        let cognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: preferences
        )
        return primeCurrentBrainState(
            mode: .mirror,
            promptFragments: mirrorPromptFragments(for: session),
            context: context,
            projection: projection,
            retrievalMode: currentBrainRuntimeRetrievalMode(
                for: .mirror,
                preferences: preferences
            ),
            now: now,
            cognitionBehavior: cognitionBehavior
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
        let executionCapabilityFrame = BeforeProductCompatibility.resolvedExecutionCapabilityFrame(
            for: preferences
        )
        return executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            executionCapabilityFrame: executionCapabilityFrame,
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
        now: Date = .now,
        cognitionBehavior: BASCognitionBehavior = BeforeProductCompatibility.substrateCognitionBehavior
    ) -> CurrentBrainState {
        return BASAppleCurrentBrainRuntimeBridgeExecutor.refreshActiveBrain(
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
                lifecycleBehavior: BeforeProductCompatibility.lifecycleBootstrapBehavior,
                bootstrapBehavior: BeforeProductCompatibility.currentBrainBootstrapBehavior,
                cognitionBehavior: cognitionBehavior
            ),
            bootstrapCurrentBrain: { bootstrapInput in
                var bootstrapInput = bootstrapInput
                bootstrapInput.embeddingScores = embeddingScores(for: bootstrapInput.prompt)
                if let mode = DecisionMode.fromSubstrateModeID(bootstrapInput.modeID) {
                    bootstrapInput.reactionWeightSeed = BeforeProductCompatibility.reactionWeights(for: mode)
                    bootstrapInput.identityProfileOverride = BeforeProductCompatibility.identityProfile(for: mode)
                }
                bootstrapInput.cognitionBehavior = cognitionBehavior
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
        let cognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: preferences
        )
        return refreshCurrentBrainState(
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
            now: now,
            cognitionBehavior: cognitionBehavior
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
        let executionCapabilityFrame = BeforeProductCompatibility.resolvedExecutionCapabilityFrame(
            for: preferences
        )
        return executeCurrentBrainProjection(
            cachedProjection: cachedProjection,
            isProjectionDirty: isProjectionDirty,
            context: context,
            executionCapabilityFrame: executionCapabilityFrame,
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
        let normalizedInput = BASAppleCurrentBrainBootstrapBridgeInput(
            modeID: BeforeProductCompatibility.substrateModeID(rawValue: input.modeID),
            prompt: input.prompt,
            triggerID: BeforeLegacyMigration.normalizedBrainStateUpdateSourceIdentifier(input.triggerID),
            sourceSurfaceOverrideID: input.sourceSurfaceOverrideID,
            riskLevelOverrideID: input.riskLevelOverrideID,
            preferredLanguages: input.preferredLanguages,
            now: input.now,
            projection: input.projection,
            embeddingScores: input.embeddingScores,
            taskGraphHeadline: input.taskGraphHeadline,
            taskGraphActiveNodeCount: input.taskGraphActiveNodeCount,
            taskGraphHasResumeCandidate: input.taskGraphHasResumeCandidate,
            taskGraphResumeHint: input.taskGraphResumeHint,
            retrievalMode: input.retrievalMode,
            bootstrapBehavior: input.bootstrapBehavior,
            reactionWeightSeed: input.reactionWeightSeed,
            identityProfileOverride: input.identityProfileOverride,
            cognitionBehavior: input.cognitionBehavior
        )
        let mode = DecisionMode.fromSubstrateModeID(normalizedInput.modeID) ?? .quick
        let runtimeInput = BASAppleCurrentBrainHostLifecycleRuntimeInput(
            bootstrapInput: normalizedInput,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval
        )
        let support: BASAppleCurrentBrainHostSupportDescriptor<
            InterventionTemplateRecord,
            FailurePatternRecord
        > = currentBrainHostSupport(mode: mode, context: context)

        do {
            return try BASAppleCurrentBrainHostSupportRuntimeExecutor.bootstrapAndBuildCurrentBrain(
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
                        source: BrainStateUpdateSource(identifier: committed.triggerID) ?? .explicitRefresh,
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
        } catch {
            PersistenceIssueRecorder.record(
                error: error,
                operation: "bootstrapping current brain state"
            )
            let trimmedPrompt = normalizedInput.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackBrainState = DecisionBrainState(
                profileCore: [],
                activeGoals: trimmedPrompt.isEmpty ? [] : [trimmedPrompt],
                relevantMemories: normalizedInput.projection.records.prefix(3).map(\.content),
                sessionBiases: ["host-bootstrap-fallback", "retrieval:\(normalizedInput.retrievalMode)"],
                retrievalTags: ["fallback", "retrieval:\(normalizedInput.retrievalMode)"],
                reactionWeights: BeforeProductCompatibility.reactionWeights(for: mode),
                identityProfile: BeforeProductCompatibility.identityProfile(for: mode),
                boundaryPolicy: .default(
                    riskLevel: InterventionRiskLevel(rawValue: normalizedInput.riskLevelOverrideID ?? "") ?? .low
                ),
                loadedAt: normalizedInput.now
            )
            return CurrentBrainState(
                source: BrainStateUpdateSource(identifier: normalizedInput.triggerID) ?? .explicitRefresh,
                sourceSurface: DecisionIntentSourceSurface(rawValue: normalizedInput.sourceSurfaceOverrideID ?? "") ?? .app,
                mode: mode,
                riskLevel: InterventionRiskLevel(rawValue: normalizedInput.riskLevelOverrideID ?? "") ?? .low,
                taskGraph: taskGraph,
                brainState: fallbackBrainState,
                dominantGoal: fallbackBrainState.activeGoals.first,
                activeConstraints: Array(orderedUnique(fallbackBrainState.sessionBiases).prefix(4)),
                activeTemplateIDs: [],
                failureGuardIDs: [],
                sourceIntentEnvelope: envelope,
                loadedAt: normalizedInput.now
            )
        }
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
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
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
            routingPolicy: BeforeProductCompatibility.requireProviderRoutingPolicy(from: runtimePolicyResolution),
            routingRegistryVersion: runtimePolicyResolution.lineage.providerRoutingRegistryVersion,
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
        currentBrainState: CurrentBrainState?,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> BASConsoleSnapshot {
        let resolvedTurn = eBrainTurn ?? export.eBrainTurn
        let synchronizedExport = export.attaching(eBrainTurn: resolvedTurn)
        let checkpointLineage = resolvedTurn == nil
            ? export.selectedCheckpointLineage(matching: export.preferredCheckpointSelectionContext)
            : nil
        let flightDeckCompilation = synchronizedExport.basFlightDeckCompilation
        let runtimeContext = runtimeContext(from: export)
        let brainSnapshot = brainSnapshot(from: currentBrainState)
        let roleProfile = roleProfile(from: currentBrainState)
        let recoveredInspection = checkpointLineage.map {
            checkpointInspectionBundle(from: $0, generatedAt: export.generatedAt)
        }
        let evolutionRuntimeFacts = export.evolutionRuntimeFacts(
            currentBrainState: currentBrainState
        )

        let baseSnapshot = BASAppleInspectionBridgeBuilder.consoleSnapshot(
            from: BASAppleConsoleBridgeSourceInput(
                generatedAt: export.generatedAt,
                flightDeckCompilation: flightDeckCompilation,
                activeProviderTitle: export.runtimeSnapshot.runtimeStatus.active.title,
                totalRequests: export.basRuntimeInspectionSummary.totalRequests,
                totalProviderAttempts: export.basRuntimeInspectionSummary.totalProviderAttempts,
                layerStackLines: synchronizedExport.effectiveLayerStackLines,
                runtimeContext: runtimeContext,
                roleProfile: roleProfile,
                boundaryModeID: currentBrainState?.boundaryPolicy.mode.rawValue,
                calibrationStatusID: currentBrainState?.calibrationState.status.rawValue,
                brainState: brainSnapshot,
                capabilityCoverage: DecisionCapabilityCoverageBuilder.build(
                    from: synchronizedExport,
                    currentBrainState: currentBrainState,
                    evolutionFacts: evolutionRuntimeFacts.coverageFacts
                ),
                inspectionBundle: resolvedTurn.map {
                    BASEBrainConsoleSupport.inspectionBundle(for: $0, generatedAt: export.generatedAt)
                } ?? recoveredInspection
            )
        )

        if let resolvedTurn {
            var mergedSnapshot = BASEBrainConsoleSupport.mergedSnapshot(baseSnapshot, with: resolvedTurn)
            let runtimeAdditions =
                synchronizedExport.effectiveEBrainFactsBundle?.consoleRuntimeSummaryAdditions
                ?? DeveloperDecisionReplayEBrainSummary(turn: resolvedTurn).factsBundle().consoleRuntimeSummaryAdditions
            if !runtimeAdditions.isEmpty {
                mergedSnapshot.runtimeSummary = appendConsoleSummary(
                    base: mergedSnapshot.runtimeSummary,
                    additions: runtimeAdditions
                )
            }
            if !synchronizedExport.effectiveLayerStackLines.isEmpty {
                mergedSnapshot.layerStackLines = synchronizedExport.effectiveLayerStackLines
            }
            return mergedSnapshot
        }

        guard let checkpointLineage, let recoveredInspection else {
            return baseSnapshot
        }

        let checkpointFacts = checkpointLineage.factsBundle
        var recoveredSnapshot = baseSnapshot
        if !checkpointFacts.layerStackLines.isEmpty {
            recoveredSnapshot.layerStackLines = checkpointFacts.layerStackLines
        }
        recoveredSnapshot.runtimeSummary = appendConsoleSummary(
            base: baseSnapshot.runtimeSummary,
            additions: checkpointFacts.consoleRuntimeSummaryAdditions
        )
        recoveredSnapshot.brainSummary = appendConsoleSummary(
            base: baseSnapshot.brainSummary,
            addition: checkpointFacts.consoleBrainSummaryAddition
        )
        recoveredSnapshot.blockerSummary = orderedUnique(
            recoveredSnapshot.blockerSummary
                + checkpointLineage.diffSummary
                + recoveredInspection.blockerSummary
        )
        recoveredSnapshot.inspectionBundle = recoveredInspection
        return recoveredSnapshot
    }

    @MainActor
    static func eBrainTurn(
        hostRuntime: BASHostRuntime,
        activeQuickSession: QuickCheckSession?,
        activeBalanceSession: BalanceBoardSession?,
        activeMirrorSession: MirrorWorkspaceSession?,
        currentBrainState: CurrentBrainState?,
        projection: DecisionMemorySystem.BrainStateProjection?,
        activeKillSwitches: [BASKillSwitchID] = [],
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        now: Date = .now
    ) -> BASEBrainTurnResult? {
        guard let currentBrainState, let projection else {
            return nil
        }

        let fragmentsByModeID = promptFragmentsByModeID(
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession
        )
        let workflowProfile = hostWorkflowProfile(for: currentBrainState.mode)
        let modeID = currentBrainState.mode.substrateModeID
        let fragments = (fragmentsByModeID[modeID] ?? [])
            .map(trimmed)
            .filter { !$0.isEmpty }
        let prompt = fragments.first ?? currentBrainState.dominantGoal ?? currentBrainState.mode.title
        let detailFragments = Array(fragments.dropFirst())
            .filter { !$0.isEmpty }
        let detail = DecisionEvolutionNarrativeFormattingSupport.joined(detailFragments)
            .nilIfEmpty

        let request = BASHostSessionRequest(
            kind: hostSessionKind(
                source: currentBrainState.source,
                sourceSurface: currentBrainState.sourceSurface
            ),
            workflowProfile: workflowProfile,
            surface: hostSurface(from: currentBrainState.sourceSurface),
            prompt: prompt,
            title: currentBrainState.mode.title,
            detail: detail,
            riskLevel: hostRiskLevel(from: currentBrainState.riskLevel),
            triggerReason: currentBrainState.source.rawValue,
            activeKillSwitches: activeKillSwitches
        )

        let hostCurrentBrain = BASHostCurrentBrain(
            workflowProfile: workflowProfile,
            workflowTitle: currentBrainState.mode.title,
            roleID: currentBrainState.identityProfile.role.identifier,
            identityPosture: currentBrainState.identityProfile.posture,
            identityInitiative: currentBrainState.identityProfile.initiative,
            confidenceCeiling: currentBrainState.identityProfile.confidenceCeiling,
            relationshipBoundary: currentBrainState.identityProfile.relationshipBoundary,
            boundaryHeadline: currentBrainState.boundaryPolicy.auditHeadline,
            boundaryMode: currentBrainState.boundaryPolicy.mode,
            boundaryConstraints: currentBrainState.boundaryPolicy.activeConstraints,
            calibrationStatus: currentBrainState.calibrationState.status,
            calibrationAlerts: currentBrainState.calibrationState.alerts,
            riskFlags: currentBrainState.verificationSnapshot.riskFlags,
            dominantGoals: orderedUnique(
                [currentBrainState.dominantGoal].compactMap { $0 } +
                currentBrainState.brainState.activeGoals
            ),
            activeConstraints: orderedUnique(
                currentBrainState.activeConstraints +
                currentBrainState.brainState.sessionBiases
            ),
            retrievalTags: orderedUnique(currentBrainState.brainState.retrievalTags),
            verificationSummary: currentBrainState.verificationSnapshot.fingerprint,
            activeTemplateCount: currentBrainState.activeTemplateIDs.count,
            failureGuardCount: currentBrainState.failureGuardIDs.count,
            evolutionPendingReviewCount: currentBrainState.evolutionState.pendingReviewCount,
            evolutionRollbackReady: currentBrainState.evolutionState.rollbackReady
        )

        return hostRuntime.buildEBrainTurn(
            request: request,
            currentBrain: hostCurrentBrain,
            projection: projection.baseProjection,
            deviceStateOverride: eBrainDeviceState(
                from: currentBrainState,
                runtimeSnapshot: runtimeSnapshot
            ),
            now: now
        )
    }

    @MainActor
    @discardableResult
    static func persistEBrainLineage(
        _ turn: BASEBrainTurnResult,
        targeting checkpointID: String? = nil,
        in context: ModelContext
    ) -> DecisionEvolutionState? {
        let result: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            if let checkpointID {
                BASAppleEvolutionCheckpointWriter.attachLineageSummary(
                    turn.evolutionLineageSummary,
                    for: checkpointID,
                    in: context,
                    onSaveError: { error in
                        PersistenceIssueRecorder.record(
                            error: error,
                            operation: "attaching eBrain lineage to explicit evolution checkpoint"
                        )
                    }
                )
            } else {
                BASAppleEvolutionCheckpointWriter.attachLineageSummary(
                    turn.evolutionLineageSummary,
                    in: context,
                    onSaveError: { error in
                        PersistenceIssueRecorder.record(
                            error: error,
                            operation: "attaching eBrain lineage to evolution checkpoint"
                        )
                    }
                )
            }

        guard !result.orderedCheckpoints.isEmpty else {
            return nil
        }

        return reconciledEvolutionState(
            result.currentState,
            preservingLoadedCheckpointID: checkpointID,
            in: context
        )
    }

    @MainActor
    @discardableResult
    static func setEvolutionCheckpointApproval(
        _ checkpointID: String,
        to approvalState: DecisionEvolutionApprovalState,
        in context: ModelContext
    ) -> DecisionEvolutionState? {
        let gateVerdict = evolutionCheckpointApprovalGateVerdict(
            checkpointID,
            to: approvalState,
            in: context
        )
        guard gateVerdict?.allowsPromotion != false else {
            return nil
        }

        let result: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.setApprovalState(
                approvalState,
                for: checkpointID,
                in: context,
                onSaveError: { error in
                    PersistenceIssueRecorder.record(
                        error: error,
                        operation: "updating evolution checkpoint approval state"
                    )
                }
            )

        guard !result.orderedCheckpoints.isEmpty else {
            return nil
        }

        return result.currentState
    }

    @MainActor
    static func evolutionCheckpointApprovalBlockReason(
        _ checkpointID: String,
        to approvalState: DecisionEvolutionApprovalState,
        in context: ModelContext
    ) -> String? {
        guard let verdict = evolutionCheckpointApprovalGateVerdict(
            checkpointID,
            to: approvalState,
            in: context
        ), !verdict.allowsPromotion else {
            return nil
        }

        let labels = BASEvolutionPromotionGate.operatorFacingRequirementLabels(
            for: verdict.reasonCodes
        )
        guard labels.isEmpty == false else {
            return "Checkpoint \(checkpointID) could not be approved for automatic evolution."
        }

        let requirementSummary: String
        if labels.count == 1 {
            requirementSummary = labels[0]
        } else if labels.count == 2 {
            requirementSummary = "\(labels[0]) and \(labels[1])"
        } else {
            requirementSummary = labels.dropLast().joined(separator: ", ")
                + ", and "
                + (labels.last ?? "")
        }

        let baseReason = "Checkpoint \(checkpointID) is still waiting on \(requirementSummary)."
        guard let checkpoint = fetchEvolutionCheckpoint(checkpointID, in: context) else {
            return baseReason
        }

        let detailSentences = governanceApprovalDetailSentences(
            for: checkpoint.lineageSummary?.governanceSummary
        )
        guard detailSentences.isEmpty == false else {
            return baseReason
        }

        return ([baseReason] + detailSentences).joined(separator: " ")
    }

    @MainActor
    @discardableResult
    static func clearEvolutionCheckpointLineage(
        _ checkpointID: String,
        in context: ModelContext
    ) -> DecisionEvolutionState? {
        let result: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.setLineageSummary(
                nil,
                for: checkpointID,
                in: context,
                onSaveError: { error in
                    PersistenceIssueRecorder.record(
                        error: error,
                        operation: "clearing evolution checkpoint lineage"
                    )
                }
            )

        guard !result.orderedCheckpoints.isEmpty else {
            return nil
        }

        return result.currentState
    }

    @MainActor
    static func restoreEvolutionCheckpoint(
        _ checkpointID: String,
        currentBrainState: CurrentBrainState?,
        taskGraph: DecisionTaskGraphSnapshot?,
        in context: ModelContext,
        now: Date = .now
    ) -> CurrentBrainState? {
        guard let checkpoint = fetchEvolutionCheckpoint(checkpointID, in: context),
              let snapshot = checkpoint.brainStateSnapshot else {
            return nil
        }

        let checkpoints = (try? context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())) ?? []
        let restoredEvolutionState = restoredEvolutionState(
            selecting: checkpoint,
            across: checkpoints
        )

        var restoredBrainState = snapshot
        restoredBrainState.evolutionState = restoredEvolutionState

        let source = BrainStateUpdateSource(rawValue: checkpoint.sourceRaw) ?? .explicitRefresh
        let riskLevel = interventionRiskLevel(
            from: checkpoint.lineageSummary?.riskLevel,
            fallback: restoredBrainState.boundaryPolicy.riskLevel
        )

        return CurrentBrainState(
            source: source,
            sourceSurface: currentBrainState?.sourceSurface ?? .app,
            mode: checkpoint.mode,
            riskLevel: riskLevel,
            taskGraph: taskGraph ?? currentBrainState?.taskGraph,
            brainState: restoredBrainState,
            dominantGoal: restoredBrainState.activeGoals.first ?? currentBrainState?.dominantGoal,
            activeConstraints: restoredBrainState.boundaryPolicy.activeConstraints.map(\.title),
            activeTemplateIDs: restoredBrainState.activeInterventionTemplateIDs,
            failureGuardIDs: restoredBrainState.failureGuardIDs,
            sourceIntentEnvelope: currentBrainState?.sourceIntentEnvelope,
            loadedAt: now
        )
    }

    private static func governanceApprovalDetailSentences(
        for governanceSummary: BASEvolutionLineageSummary.GovernanceSummary?
    ) -> [String] {
        guard let governanceSummary else {
            return []
        }

        return [
            approvalDetailSentence(
                prefix: "Version tree",
                highlights: governanceSummary.versionDeltaHighlights
            ),
            approvalDetailSentence(
                prefix: "Retraction",
                highlights: governanceSummary.retractionOrderHighlights
            )
        ].compactMap { $0 }
    }

    private static func approvalDetailSentence(
        prefix: String,
        highlights: [String]
    ) -> String? {
        guard let detail = highlights.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !detail.isEmpty else {
            return nil
        }

        return "\(prefix): \(detail)."
    }

    static func entryIntentEnvelope(from envelope: DecisionIntentEnvelope) -> BASEntryIntentEnvelope {
        let kindID = BeforeProductCompatibility.substrateEntryIntentKindID(envelope.kind)
        return BASEntryIntentBridgeBuilder.envelope(
            kindID: kindID,
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
        let kindID = BeforeProductCompatibility.substrateEntryIntentKindID(envelope.kind)
        return BASEntryIntentBridgeBuilder.summary(
            kindID: kindID,
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
        let kindID = BeforeProductCompatibility.substrateEntryIntentKindID(envelope.kind)
        return BASAppleHandoffBridgeBuilder.summary(
            id: envelope.id,
            surfaceID: envelope.sourceSurface.rawValue,
            preferredWorkflowID: envelope.preferredMode?.substrateModeID,
            riskLevelID: envelope.riskLevel?.rawValue,
            payloadSummary: envelope.promptSeed ?? envelope.triggerReason ?? kindID,
            createdAt: envelope.requestedAt,
            route: nil
        )
    }

    @MainActor
    static func consumeLifecycleEntrySourcesIfNeeded(
        consumeHandoff: () -> DecisionIntentEnvelope?,
        consumeDeferredEnvelope: () -> DecisionIntentEnvelope?,
        performCapture: (EntrySource, ScenarioType?, String) -> Void,
        performPresent: (DecisionMode, EntrySource, String) -> Void,
        performRoutedInput: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        performOpenEvolutionControl: (DecisionIntentEnvelope) -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        let handleDeferredEnvelope: (DecisionIntentEnvelope) -> Void = { envelope in
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
                performRoutedInput: { envelope, prompt in
                    performRoutedInput(prompt, envelope.entrySource)
                },
                performPredictiveIntervention: performPredictiveIntervention,
                performRestore: performRestore,
                performOpenEvolutionControl: performOpenEvolutionControl,
                refreshCurrentBrain: refreshCurrentBrain
            )
        }

        BASAppleAppLifecycleOrchestrationExecutor.consumeEntriesIfNeeded(
            consumeHandoff: consumeHandoff,
            handleHandoff: handleDeferredEnvelope,
            consumePendingRequest: consumeDeferredEnvelope,
            handlePendingRequest: handleDeferredEnvelope
        )
    }

    @MainActor
    static func executeAppLifecyclePhase(
        _ phase: BASAppleLifecycleBootstrapPhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void,
        presentPendingReflection: () -> Void,
        consumeHandoff: () -> DecisionIntentEnvelope?,
        consumeDeferredEnvelope: () -> DecisionIntentEnvelope?,
        performCapture: (EntrySource, ScenarioType?, String) -> Void,
        performPresent: (DecisionMode, EntrySource, String) -> Void,
        performRoutedInput: (String, EntrySource) -> Void,
        selectBoxTab: () -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        performOpenEvolutionControl: (DecisionIntentEnvelope) -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        let handleDeferredEnvelope: (DecisionIntentEnvelope) -> Void = { envelope in
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
                performRoutedInput: { envelope, prompt in
                    performRoutedInput(prompt, envelope.entrySource)
                },
                performPredictiveIntervention: performPredictiveIntervention,
                performRestore: performRestore,
                performOpenEvolutionControl: performOpenEvolutionControl,
                refreshCurrentBrain: refreshCurrentBrain
            )
        }

        BASAppleAppLifecycleOrchestrationExecutor.execute(
            phase: phase,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: { source in
                refreshCurrentBrain(
                    BrainStateUpdateSource(identifier: source) ?? .explicitRefresh
                )
            },
            presentPendingReflection: presentPendingReflection,
            consumeHandoff: consumeHandoff,
            handleHandoff: handleDeferredEnvelope,
            consumePendingRequest: consumeDeferredEnvelope,
            handlePendingRequest: handleDeferredEnvelope,
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
        performRoutedInput: (DecisionIntentEnvelope, String) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        performOpenEvolutionControl: (DecisionIntentEnvelope) -> Void,
        refreshCurrentBrain: (BrainStateUpdateSource) -> Void
    ) {
        if envelope.kind == .openEvolutionControl {
            performOpenEvolutionControl(envelope)
            refreshCurrentBrain(.watchHandoff)
            return
        }

        let kindID = BeforeProductCompatibility.substrateEntryIntentKindID(envelope.kind)
        BASAppleEntryIntentRuntimeExecutor.execute(
            input: BASAppleEntryIntentRuntimeInput(
                kindID: kindID,
                surfaceID: envelope.sourceSurface.rawValue,
                preferredModeID: envelope.preferredMode?.substrateModeID,
                scenarioID: envelope.scenario?.rawValue,
                promptSeed: envelope.promptSeed,
                riskLevelID: envelope.riskLevel?.rawValue,
                triggerReason: envelope.triggerReason,
                predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation(
                    fallbackTitle: BeforeProductCompatibility.predictiveInterventionPresentation.mediumRiskTitle,
                    fallbackDetail: BeforeProductCompatibility.predictiveInterventionPresentation.mediumRiskDetail,
                    fallbackReason: BeforeProductCompatibility.predictiveInterventionPresentation.defaultReason
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
            performRoutedInput: { actionPlan in
                performRoutedInput(envelope, actionPlan.promptSeed)
            },
            performPredictiveIntervention: performPredictiveIntervention,
            performRestore: performRestore,
            refreshCurrentBrain: { triggerID in
                refreshCurrentBrain(
                    BrainStateUpdateSource(identifier: triggerID) ?? .explicitRefresh
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
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
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
                let projection = DecisionMemorySystem.refreshProjection(
                    in: context,
                    executionCapabilityFrame: executionCapabilityFrame,
                    now: now
                )
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
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now
    ) {
        BASAppleCurrentBrainHostStateExecutor.commitProjectionRefresh(
            outcome: resolveMemoryProjection(
                force: force,
                cachedProjection: cachedProjection,
                isDirty: isProjectionDirty,
                context: context,
                executionCapabilityFrame: executionCapabilityFrame,
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
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
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
                    executionCapabilityFrame: executionCapabilityFrame,
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
        if let recoveredRiskLevel = export.selectedCheckpointLineage(
            matching: export.preferredCheckpointSelectionContext
        )?.eBrain.riskLevel {
            switch recoveredRiskLevel {
            case "extreme", "high":
                return .high
            case "medium":
                return .medium
            default:
                break
            }
        }
        if export.recentTraces.contains(where: { $0.kind == .mirror }) {
            return .medium
        }
        return .low
    }

    private static func checkpointInspectionBundle(
        from lineage: DecisionEvolutionLineageSnapshot,
        generatedAt: Date
    ) -> BASInspectionBundle {
        let auditEvents = lineage.eBrain.guardrailFindings.map {
            BASAuditEvent(
                category: "checkpoint_guardrail",
                message: $0,
                timestamp: lineage.createdAt
            )
        }
        let anomalySignals = checkpointAnomalySignals(from: lineage)
        let releaseKind: BASReleaseDecisionKind

        switch lineage.eBrain.permitMode {
        case "block":
            releaseKind = .deny
        case "delay":
            releaseKind = .requireConfirmation
        default:
            releaseKind = .allow
        }

        return BASInspectionBundle(
            generatedAt: generatedAt,
            trace: BASExecutionTrace(
                inputSummary: DecisionEvolutionEBrainPresentationSupport.recoveredCheckpointInputSummary(
                    modeTitle: lineage.mode.shortTitle,
                    checkpointID: lineage.checkpointID
                ),
                selectedRoute: BASModelRoute.local("persisted.checkpoint.\(lineage.mode.rawValue)"),
                memoriesRecalled: Array(lineage.diffSummary.prefix(3)),
                toolsCalled: [],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 0,
                    retrievalMs: 0,
                    generationMs: 0,
                    toolMs: 0
                ),
                auditEvents: auditEvents,
                outputSummary: DecisionEvolutionEBrainPresentationSupport.riskPermitHostLine(
                    riskLevel: lineage.eBrain.riskLevel,
                    permitMode: lineage.eBrain.permitMode,
                    hostGatePercent: lineage.eBrain.hostGatePercent
                )
            ),
            replayFingerprint: BASReplayFingerprint(
                value: "\(lineage.checkpointID):\(lineage.eBrain.thoughtFoldChecksum)"
            ),
            releaseDecision: BASReleaseDecision(
                kind: releaseKind,
                reason: DecisionEvolutionEBrainPresentationSupport.recoveredCheckpointReason(
                    modeTitle: lineage.mode.shortTitle,
                    approvalStateRawValue: lineage.approvalState.rawValue
                )
            ),
            anomalySignals: anomalySignals,
            calibration: BASInspectionCalibrationSummary(
                score: checkpointCalibrationScore(for: lineage),
                status: lineage.rollbackReady ? "recovered" : "watch",
                summary: DecisionEvolutionEBrainPresentationSupport.checkpointCalibrationSummary(
                    riskLevel: lineage.eBrain.riskLevel,
                    permitMode: lineage.eBrain.permitMode
                ),
                alertCount: anomalySignals.count,
                alertReasons: orderedUnique(lineage.diffSummary + lineage.eBrain.killSwitches)
            )
        )
    }

    private static func checkpointAnomalySignals(
        from lineage: DecisionEvolutionLineageSnapshot
    ) -> [BASAnomalySignal] {
        let guardrailSignals = lineage.eBrain.guardrailFindings.map {
            BASAnomalySignal(
                kind: "checkpoint_guardrail",
                severity: checkpointSeverity(for: lineage.eBrain.riskLevel),
                message: $0,
                timestamp: lineage.createdAt
            )
        }
        let diffSignals = lineage.diffSummary.map {
            BASAnomalySignal(
                kind: "checkpoint_diff",
                severity: "high",
                message: $0,
                timestamp: lineage.createdAt
            )
        }
        let killSwitchSignals = lineage.eBrain.killSwitches.map {
            BASAnomalySignal(
                kind: "checkpoint_kill_switch",
                severity: "high",
                message: "Recommended kill switch: \($0)",
                timestamp: lineage.createdAt
            )
        }
        return guardrailSignals + diffSignals + killSwitchSignals
    }

    private static func checkpointCalibrationScore(
        for lineage: DecisionEvolutionLineageSnapshot
    ) -> Double {
        switch lineage.eBrain.riskLevel {
        case "extreme":
            0.45
        case "high":
            0.58
        case "medium":
            0.74
        default:
            0.88
        }
    }

    private static func checkpointSeverity(for riskLevel: String) -> String {
        switch riskLevel {
        case "extreme", "high":
            "high"
        case "medium":
            "medium"
        default:
            "warning"
        }
    }

    private static func appendConsoleSummary(
        base: String?,
        addition: String
    ) -> String {
        guard let base, !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return addition
        }
        return "\(base) • \(addition)"
    }

    private static func appendConsoleSummary(
        base: String?,
        additions: [String]
    ) -> String? {
        additions.reduce(base) { partial, addition in
            appendConsoleSummary(base: partial, addition: addition)
        }
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

    private static func hostSurface(from sourceSurface: DecisionIntentSourceSurface) -> BASHostSurface {
        switch sourceSurface {
        case .app:
            .application
        case .watch:
            .wearable
        case .widget:
            .widget
        case .shortcut:
            .shortcut
        case .siri:
            .voiceAssistant
        case .notification:
            .notification
        }
    }

    private static func hostWorkflowProfile(for mode: DecisionMode) -> BASHostWorkflowProfile {
        switch mode {
        case .quick:
            .primary
        case .balance:
            .comparative
        case .mirror:
            .reflective
        }
    }

    private static func hostRiskLevel(from riskLevel: InterventionRiskLevel) -> BASHostRiskLevel {
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
        from storedRiskLevel: String?,
        fallback substrateRiskLevel: BASRiskLevel
    ) -> InterventionRiskLevel {
        if let storedRiskLevel,
           let resolved = InterventionRiskLevel(rawValue: storedRiskLevel) {
            return resolved
        }

        switch substrateRiskLevel {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        }
    }

    @MainActor
    private static func fetchEvolutionCheckpoint(
        _ checkpointID: String,
        in context: ModelContext
    ) -> DecisionEvolutionCheckpoint? {
        ((try? context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())) ?? [])
            .first(where: { $0.id == checkpointID })
    }

    @MainActor
    private static func evolutionCheckpointApprovalGateVerdict(
        _ checkpointID: String,
        to approvalState: DecisionEvolutionApprovalState,
        in context: ModelContext
    ) -> BASEvolutionPromotionGateVerdict? {
        guard approvalState == .automatic,
              let checkpoint = fetchEvolutionCheckpoint(checkpointID, in: context) else {
            return nil
        }

        let checkpointSummary = BASEvolutionCheckpointSummary(
            id: checkpoint.id,
            previousCheckpointID: checkpoint.previousCheckpointID,
            createdAt: checkpoint.createdAt,
            diffSummary: checkpoint.diffSummary,
            rollbackReady: checkpoint.rollbackReady,
            approvalState: checkpoint.approvalState,
            lineageSummary: checkpoint.lineageSummary
        )
        return BASEvolutionPromotionGate.evaluate(
            checkpoint: checkpointSummary,
            targetApprovalState: approvalState
        )
    }

    private static func restoredEvolutionState(
        selecting checkpoint: DecisionEvolutionCheckpoint,
        across checkpoints: [DecisionEvolutionCheckpoint]
    ) -> DecisionEvolutionState {
        let pendingReviewCount = checkpoints.filter { $0.approvalState == .reviewSuggested }.count
        let summary = DecisionEvolutionCheckpointSummary(
            id: checkpoint.id,
            previousCheckpointID: checkpoint.previousCheckpointID,
            createdAt: checkpoint.createdAt,
            diffSummary: checkpoint.diffSummary,
            rollbackReady: checkpoint.rollbackReady,
            approvalState: checkpoint.approvalState,
            lineageSummary: checkpoint.lineageSummary
        )

        return DecisionEvolutionState(
            latestCheckpoint: summary,
            checkpointCount: checkpoints.count,
            rollbackReady: checkpoint.rollbackReady,
            pendingReviewCount: pendingReviewCount,
            recentDiffSummary: checkpoint.diffSummary
        )
    }

    @MainActor
    static func reconciledEvolutionState(
        _ evolutionState: DecisionEvolutionState,
        preservingLoadedCheckpointID loadedCheckpointID: String?,
        in context: ModelContext
    ) -> DecisionEvolutionState {
        guard let loadedCheckpointID,
              let checkpoint = fetchEvolutionCheckpoint(loadedCheckpointID, in: context) else {
            return evolutionState
        }

        let checkpoints = (try? context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())) ?? []
        return restoredEvolutionState(selecting: checkpoint, across: checkpoints)
    }

    private static func hostSessionKind(
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface
    ) -> BASHostSessionKind {
        if sourceSurface == .notification || source == .notification {
            return .notification
        }
        if sourceSurface == .widget || source == .widget {
            return .widget
        }
        if sourceSurface == .watch || source == .watchHandoff {
            return .handoff
        }
        return source == .sceneActive ? .ambient : .interactive
    }

    private static func currentBrainRuntimeRetrievalMode(
        for mode: DecisionMode,
        preferences: BeforePreferences
    ) -> DecisionRetrievalMode {
        return DecisionIntelligenceCoordinator
            .runtimeCoordination(preferences: preferences)
            .retrievalMode(for: mode)
    }

    private static func currentBrainRuntimeRetrievalModesByModeID(
        preferences: BeforePreferences
    ) -> [String: String] {
        DecisionIntelligenceCoordinator
            .runtimeCoordination(preferences: preferences)
            .retrievalModesByModeID
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

    private static func eBrainDeviceState(
        from currentBrainState: CurrentBrainState,
        runtimeSnapshot: DecisionTestingRuntimeSnapshot?
    ) -> BASDeviceState {
        guard let runtimeSnapshot else {
            return BASDeviceState(
                batteryLevel: 0.64,
                thermalLevel: currentBrainState.riskLevel == .high ? .warm : .nominal,
                memoryFreeMB: 2_048,
                networkState: .constrained,
                foregroundState: foregroundState(for: currentBrainState.sourceSurface),
                cpuLoad: currentBrainState.riskLevel == .high ? 0.28 : 0.16,
                gpuLoad: currentBrainState.mode == .balance ? 0.22 : 0.10,
                npuAvailable: true,
                latencyBudgetMs: currentBrainState.riskLevel == .high ? 1_800 : 1_200
            )
        }

        let capabilities = runtimeSnapshot.deviceCapabilities
        let memoryFreeMB = max(1_024, capabilities.physicalMemoryGB * 768)
        let batteryLevel = capabilities.isLowPowerModeEnabled ? 0.24 : 0.76
        let thermalLevel: BASThermalLevel
        if capabilities.isLowPowerModeEnabled && currentBrainState.riskLevel == .high {
            thermalLevel = .warm
        } else if capabilities.isSimulator && currentBrainState.mode == .mirror {
            thermalLevel = .warm
        } else {
            thermalLevel = .nominal
        }

        let networkState: BASNetworkState =
            runtimeSnapshot.preferences.onDeviceIntelligenceMode.isEnabled ? .constrained : .online

        let gpuLoad: Double
        switch runtimeSnapshot.gemmaBackendResolution.effectiveBackend {
        case .metal:
            gpuLoad = 0.34
        case .coreML, .systemManaged:
            gpuLoad = 0.14
        case .cpu:
            gpuLoad = 0.06
        }

        let cpuLoad: Double
        switch runtimeSnapshot.executionProfile.tier {
        case .off, .simulator, .conservativeDeterministic:
            cpuLoad = currentBrainState.riskLevel == .high ? 0.24 : 0.12
        case .balancedGemma, .fullGemma, .systemManaged, .testingOverride:
            cpuLoad = currentBrainState.riskLevel == .high ? 0.36 : 0.20
        }

        let latencyBudgetMs: Int
        switch currentBrainState.riskLevel {
        case .low:
            latencyBudgetMs = currentBrainState.mode == .quick ? 900 : 1_200
        case .medium:
            latencyBudgetMs = 1_400
        case .high:
            latencyBudgetMs = 1_800
        }

        return BASDeviceState(
            batteryLevel: batteryLevel,
            thermalLevel: thermalLevel,
            memoryFreeMB: memoryFreeMB,
            networkState: networkState,
            foregroundState: foregroundState(for: currentBrainState.sourceSurface),
            cpuLoad: cpuLoad,
            gpuLoad: gpuLoad,
            npuAvailable: capabilities.supportsCoreMLAcceleration,
            latencyBudgetMs: latencyBudgetMs
        )
    }

    private static func foregroundState(
        for sourceSurface: DecisionIntentSourceSurface
    ) -> BASForegroundState {
        switch sourceSurface {
        case .widget, .notification:
            .background
        case .watch:
            .suspended
        case .app, .shortcut, .siri:
            .foreground
        }
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
