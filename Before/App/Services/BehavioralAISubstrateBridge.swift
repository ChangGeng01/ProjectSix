import Foundation
import BASAdmin
import BASAppleAdapters
import BASMemory
import BASOrchestration
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

        return BASConsoleSnapshotBuilder.build(
            from: BASFlightDeckMetrics(
                generatedAt: export.generatedAt,
                layerInputs: flightDeck.layerReports.map { report in
                    BASLayerAssessmentInput(
                        layer: map(report.layer),
                        score: Double(report.score),
                        summary: report.headline,
                        blockers: report.blockers
                    )
                },
                runtimeSummary: "Route \(export.summary.activeProvider.title) • gear \(runtimeContext.gear.rawValue) • requests \(export.summary.totalRequests) • attempts \(export.summary.totalProviderAttempts)",
                brainSummary: brainSummary(
                    currentBrainState: currentBrainState,
                    roleProfile: roleProfile(from: currentBrainState),
                    brainSnapshot: brainSnapshot
                ),
                isPureLocal: flightDeck.isPureLocalClosedLoop,
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
        BASCognitionBootstrapper.bootstrap(
            request: brainBootstrapRequest(
                mode: mode,
                prompt: prompt,
                source: source,
                sourceSurface: sourceSurface,
                riskLevel: riskLevel,
                retrievalMode: retrievalMode,
                now: now
            ),
            projection: brainProjection(
                from: projection,
                prompt: prompt,
                taskGraph: taskGraph,
                activeTemplateIDs: activeTemplateIDs,
                failureGuardIDs: failureGuardIDs
            )
        )
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

    static func brainProjection(
        from projection: DecisionMemorySystem.BrainStateProjection,
        prompt: String,
        taskGraph: DecisionTaskGraphSnapshot?,
        activeTemplateIDs: [String],
        failureGuardIDs: [String]
    ) -> BASBrainProjection {
        let embeddingScores = Dictionary(
            uniqueKeysWithValues: EmbeddingMemoryStore.query(
                prompt,
                allowedTiers: [.hot, .warm],
                limit: 12
            ).map { ($0.id, $0.score) }
        )
        var compiled = projection.baseProjection
        compiled.embeddingScoresByID = embeddingScores
        compiled.taskGraphHint = taskGraph.map(taskGraphHint(from:))
        compiled.activeTemplateIDs = activeTemplateIDs
        compiled.failureGuardIDs = failureGuardIDs
        return compiled
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

    private static func brainSummary(
        currentBrainState: CurrentBrainState?,
        roleProfile: BASRoleProfile?,
        brainSnapshot: BASCurrentBrainState?
    ) -> String? {
        guard let currentBrainState, let roleProfile, let brainSnapshot else { return nil }
        return "\(roleProfile.name) • \(currentBrainState.boundaryPolicy.mode.rawValue) • \(currentBrainState.calibrationState.status.rawValue) • fingerprint \(brainSnapshot.verificationSnapshot)"
    }

    private static func taskGraphHint(from snapshot: DecisionTaskGraphSnapshot) -> BASTaskGraphHint {
        BASTaskGraphHint(
            headline: snapshot.nextActionHint,
            activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
            hasResumeCandidate: !snapshot.tasks.isEmpty,
            resumeHint: snapshot.nextActionHint
        )
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
