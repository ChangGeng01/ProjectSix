import Foundation
import SwiftData
import BASAdmin
import BASAppleAdapters
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

struct CurrentBrainBootstrapPreparation: Equatable, Sendable {
    let sourceSurface: DecisionIntentSourceSurface
    let riskLevel: InterventionRiskLevel
    let languageMode: DecisionLanguageMode
    fileprivate let substratePreparation: BASCurrentBrainBootstrapPreparation
}

struct CurrentBrainBootstrapExecution: Equatable, Sendable {
    let preparation: CurrentBrainBootstrapPreparation
    let bootstrapped: BASBootstrappedBrainState
    let activeTemplateIDs: [String]
    let failureGuardIDs: [String]
}

struct CurrentBrainBootstrapArtifact: Equatable, Sendable {
    let sourceSurface: DecisionIntentSourceSurface
    let riskLevel: InterventionRiskLevel
    let languageMode: DecisionLanguageMode
    let bootstrapped: BASBootstrappedBrainState
    let activeTemplateIDs: [String]
    let failureGuardIDs: [String]
    let persistenceInput: BASCurrentBrainUpdatePersistenceInput
}

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

        let artifact = bootstrapCurrentBrainStateArtifact(
            mode: mode,
            prompt: prompt,
            source: source,
            envelope: envelope,
            taskGraph: taskGraph,
            context: context,
            projection: projection,
            retrievalMode: retrievalMode,
            now: now
        )
        let commit: BASAppleCurrentBrainCommitWriteResult<
            BrainStateUpdate,
            DecisionEvolutionCheckpoint
        > = BASAppleCurrentBrainCommitter.commit(
            modeName: mode.rawValue,
            sourceID: source.rawValue,
            brainState: artifact.bootstrapped.brainState,
            persistenceInput: artifact.persistenceInput,
            in: context,
            createdAt: now,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
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
            sourceSurface: artifact.sourceSurface,
            mode: mode,
            riskLevel: artifact.riskLevel,
            taskGraph: taskGraph,
            brainState: commit.brainState,
            dominantGoal: artifact.bootstrapped.dominantGoal,
            activeConstraints: artifact.bootstrapped.activeConstraints,
            activeTemplateIDs: artifact.activeTemplateIDs,
            failureGuardIDs: artifact.failureGuardIDs,
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

    static func bootstrapCurrentBrainStateArtifact(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        envelope: DecisionIntentEnvelope?,
        taskGraph: DecisionTaskGraphSnapshot?,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        now: Date
    ) -> CurrentBrainBootstrapArtifact {
        let preparation = prepareCurrentBrainBootstrap(
            mode: mode,
            prompt: prompt,
            source: source,
            envelope: envelope,
            now: now
        )
        let languageMode = preparation.languageMode
        let riskLevel = preparation.riskLevel
        let recommendedArmIDs = DecisionReactionBanditStore.recommendedArmIDs(
            mode: mode,
            riskLevel: riskLevel,
            languageMode: languageMode,
            now: now
        )
        let templates = InterventionTemplateStore.selectTemplates(
            in: context,
            mode: mode,
            riskLevel: riskLevel,
            recommendedArmIDs: recommendedArmIDs
        )
        let failurePatterns = FailurePatternStore.selectedFailurePatterns(in: context, mode: mode)
        let artifact = BASAppleCurrentBrainBootstrapPlanner.artifact(
            source: BASAppleCurrentBrainBootstrapPlanningPreparedInput(
                preparation: preparation.substratePreparation,
                projection: projection.baseProjection,
                embeddingScores: embeddingScores(for: prompt),
                taskGraphHint: taskGraph.map(appleTaskGraphHint(from:)),
                retrievalMode: retrievalMode.rawValue,
                recommendedTemplateIDs: recommendedArmIDs,
                templates: appleTemplateInputs(from: templates),
                failurePatterns: appleFailurePatternInputs(from: failurePatterns)
            )
        )
        let artifactPreparation = artifact.execution.preparation

        return CurrentBrainBootstrapArtifact(
            sourceSurface: sourceSurface(from: artifactPreparation.sourceSurface),
            riskLevel: interventionRiskLevel(from: artifactPreparation.riskLevel),
            languageMode: decisionLanguageMode(from: artifactPreparation.languageMode),
            bootstrapped: artifact.execution.bootstrapped,
            activeTemplateIDs: artifact.execution.orderedTemplateIDs,
            failureGuardIDs: artifact.execution.orderedFailurePatternIDs,
            persistenceInput: artifact.persistenceInput
        )
    }

    static func prepareCurrentBrainBootstrap(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        envelope: DecisionIntentEnvelope?,
        now: Date
    ) -> CurrentBrainBootstrapPreparation {
        let preparation = BASAppleCurrentBrainBootstrapAdapter.prepare(
            source: BASAppleCurrentBrainBootstrapSourceInput(
                preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                    mode: substrateMode(from: mode),
                    prompt: prompt,
                    trigger: currentBrainBootstrapTrigger(from: source),
                    sourceSurfaceOverride: envelope.map { interactionSurface(from: $0.sourceSurface) },
                    riskLevelOverride: envelope?.riskLevel.map(riskLevel(from:)),
                    preferredLanguages: Locale.preferredLanguages,
                    now: now
                ),
                projection: .init(records: [], candidates: [], recentEvents: []),
                retrievalMode: "prepare",
                templates: [],
                failurePatterns: []
            )
        )

        return CurrentBrainBootstrapPreparation(
            sourceSurface: sourceSurface(from: preparation.sourceSurface),
            riskLevel: interventionRiskLevel(from: preparation.riskLevel),
            languageMode: decisionLanguageMode(from: preparation.languageMode),
            substratePreparation: preparation
        )
    }

    static func executeCurrentBrainBootstrap(
        preparation: CurrentBrainBootstrapPreparation,
        taskGraph: DecisionTaskGraphSnapshot?,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        recommendedTemplateIDs: [String],
        templates: [InterventionTemplateRecord],
        failurePatterns: [FailurePatternRecord]
    ) -> CurrentBrainBootstrapExecution {
        let execution = BASAppleCurrentBrainBootstrapPlanner.execute(
            source: BASAppleCurrentBrainBootstrapPlanningPreparedInput(
                preparation: preparation.substratePreparation,
                projection: projection.baseProjection,
                embeddingScores: embeddingScores(for: preparation.substratePreparation.prompt),
                taskGraphHint: taskGraph.map(appleTaskGraphHint(from:)),
                retrievalMode: retrievalMode.rawValue,
                recommendedTemplateIDs: recommendedTemplateIDs,
                templates: appleTemplateInputs(from: templates),
                failurePatterns: appleFailurePatternInputs(from: failurePatterns)
            )
        )

        return CurrentBrainBootstrapExecution(
            preparation: preparation,
            bootstrapped: execution.bootstrapped,
            activeTemplateIDs: execution.orderedTemplateIDs,
            failureGuardIDs: execution.orderedFailurePatternIDs
        )
    }

    static func bootstrapBrainState(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel,
        taskGraph: DecisionTaskGraphSnapshot?,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        now: Date
    ) -> BASBootstrappedBrainState {
        let execution = BASAppleCurrentBrainBootstrapPlanner.artifact(
            source: BASAppleCurrentBrainBootstrapPlanningSourceInput(
                preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                    mode: substrateMode(from: mode),
                    prompt: prompt,
                    trigger: currentBrainBootstrapTrigger(from: source),
                    sourceSurfaceOverride: interactionSurface(from: sourceSurface),
                    riskLevelOverride: self.riskLevel(from: riskLevel),
                    preferredLanguages: Locale.preferredLanguages,
                    now: now
                ),
                projection: projection.baseProjection,
                embeddingScores: embeddingScores(for: prompt),
                taskGraphHint: taskGraph.map(appleTaskGraphHint(from:)),
                retrievalMode: retrievalMode.rawValue,
                recommendedTemplateIDs: activeTemplateIDs,
                templates: activeTemplateIDs.map {
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: $0,
                        mode: substrateMode(from: mode),
                        riskLevel: self.riskLevel(from: riskLevel),
                        isPinned: false,
                        successCount: 0,
                        updatedAt: now
                    )
                },
                failurePatterns: failureGuardIDs.map {
                    BASAppleCurrentBrainBootstrapFailurePatternInput(
                        id: $0,
                        mode: substrateMode(from: mode),
                        suppressionWeight: 1,
                        evidenceCount: 1,
                        updatedAt: now
                    )
                }
            )
        )
        return execution.execution.bootstrapped
    }

    static func inferredRiskLevel(
        mode: DecisionMode,
        prompt: String,
        now: Date
    ) -> InterventionRiskLevel {
        interventionRiskLevel(
            from: BASBrainBootstrapAdvisor.inferRiskLevel(
                mode: substrateMode(from: mode),
                prompt: prompt,
                now: now
            )
        )
    }

    static func orderedTemplateIDs(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        recommendedTemplateIDs: [String],
        templates: [InterventionTemplateRecord]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: substrateMode(from: mode),
            riskLevel: self.riskLevel(from: riskLevel),
            recommendedTemplateIDs: recommendedTemplateIDs,
            templates: templates.map { template in
                BASInterventionTemplateDescriptor(
                    id: template.id,
                    mode: substrateMode(from: template.mode),
                    riskLevel: self.riskLevel(from: template.riskLevel),
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            }
        )
    }

    static func orderedFailurePatternIDs(
        mode: DecisionMode,
        failurePatterns: [FailurePatternRecord]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: substrateMode(from: mode),
            failurePatterns: failurePatterns.map { pattern in
                BASFailurePatternDescriptor(
                    id: pattern.id,
                    mode: substrateMode(from: pattern.mode),
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            }
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

    static func brainBootstrapRequest(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel,
        retrievalMode: DecisionRetrievalMode,
        now: Date
    ) -> BASBrainBootstrapRequest {
        BASBrainBootstrapRequest(
            mode: substrateMode(from: mode),
            prompt: prompt,
            source: memorySource(for: source, mode: mode),
            sourceSurface: interactionSurface(from: sourceSurface),
            riskLevel: substrateRiskLevel(from: riskLevel),
            retrievalMode: retrievalMode.rawValue,
            now: now
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

    private static func appleTaskGraphHint(
        from snapshot: DecisionTaskGraphSnapshot
    ) -> BASAppleTaskGraphHintInput {
        BASAppleTaskGraphHintInput(
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

    private static func appleTemplateInputs(
        from templates: [InterventionTemplateRecord]
    ) -> [BASAppleCurrentBrainBootstrapTemplateInput] {
        templates.map { template in
            BASAppleCurrentBrainBootstrapTemplateInput(
                id: template.id,
                mode: substrateMode(from: template.mode),
                riskLevel: riskLevel(from: template.riskLevel),
                isPinned: template.isPinned,
                successCount: template.successCount,
                updatedAt: template.updatedAt
            )
        }
    }

    private static func appleFailurePatternInputs(
        from patterns: [FailurePatternRecord]
    ) -> [BASAppleCurrentBrainBootstrapFailurePatternInput] {
        patterns.map { pattern in
            BASAppleCurrentBrainBootstrapFailurePatternInput(
                id: pattern.id,
                mode: substrateMode(from: pattern.mode),
                suppressionWeight: pattern.suppressionWeight,
                evidenceCount: pattern.evidenceCount,
                updatedAt: pattern.updatedAt
            )
        }
    }

    private static func memorySource(
        for source: BrainStateUpdateSource,
        mode: DecisionMode
    ) -> BASMemorySource {
        if mode == .mirror {
            return .reflection
        }
        switch source {
        case .watchHandoff, .notification, .widget:
            return .reminder
        case .sessionPrime, .explicitRefresh:
            return .pattern
        case .launch, .sceneActive:
            return .history
        }
    }

    private static func currentBrainBootstrapTrigger(
        from source: BrainStateUpdateSource
    ) -> BASCurrentBrainBootstrapTrigger {
        switch source {
        case .launch:
            .launch
        case .sceneActive:
            .sceneActive
        case .watchHandoff:
            .watchHandoff
        case .notification:
            .notification
        case .widget:
            .widget
        case .explicitRefresh:
            .explicitRefresh
        case .sessionPrime:
            .sessionPrime
        }
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
