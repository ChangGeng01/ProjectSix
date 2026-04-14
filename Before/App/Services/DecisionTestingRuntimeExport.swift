import Foundation
import BASHostKit

enum DecisionTestingEBrainSource: String, Equatable, Sendable {
    case liveRuntime = "live_runtime"
    case persistedCheckpoint = "persisted_checkpoint"

    var sourceDescriptor: DecisionEvolutionSourceDescriptor {
        switch self {
        case .liveRuntime:
            .liveRuntimeDefault
        case .persistedCheckpoint:
            .checkpointRecoveryDefault
        }
    }

    var title: String {
        sourceDescriptor.title
    }
}

struct DecisionEvolutionLineageSnapshot: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let previousCheckpointID: String?
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: DecisionEvolutionApprovalState
    let rollbackReady: Bool
    let hasBrainStateSnapshot: Bool
    let diffSummary: [String]
    let eBrain: DeveloperDecisionReplayEBrainSummary

    var id: String { checkpointID }

    init(
        checkpointID: String,
        previousCheckpointID: String? = nil,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        rollbackReady: Bool,
        hasBrainStateSnapshot: Bool = false,
        diffSummary: [String],
        eBrain: DeveloperDecisionReplayEBrainSummary
    ) {
        self.checkpointID = checkpointID
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.mode = mode
        self.approvalState = approvalState
        self.rollbackReady = rollbackReady
        self.hasBrainStateSnapshot = hasBrainStateSnapshot
        self.diffSummary = diffSummary
        self.eBrain = eBrain
    }
}

struct DecisionReviewCheckpointSnapshot: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let previousCheckpointID: String?
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: DecisionEvolutionApprovalState
    let rollbackReady: Bool
    let hasBrainStateSnapshot: Bool
    let diffSummary: [String]
    let eBrain: DeveloperDecisionReplayEBrainSummary?
    let fallbackRiskLevel: String?
    let fallbackPermitMode: String?

    var id: String { checkpointID }

    var applyReady: Bool {
        hasBrainStateSnapshot
    }

    var primarySummary: String {
        diffSummary.first
            ?? eBrain?.updateTicketSummaries.first
            ?? (eBrain == nil
                ? "This checkpoint predates persisted lineage data but still needs review."
                : "This checkpoint is ready for review.")
    }

    init(
        checkpointID: String,
        previousCheckpointID: String? = nil,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        rollbackReady: Bool,
        hasBrainStateSnapshot: Bool,
        diffSummary: [String],
        eBrain: DeveloperDecisionReplayEBrainSummary?,
        fallbackRiskLevel: String? = nil,
        fallbackPermitMode: String? = nil
    ) {
        self.checkpointID = checkpointID
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.mode = mode
        self.approvalState = approvalState
        self.rollbackReady = rollbackReady
        self.hasBrainStateSnapshot = hasBrainStateSnapshot
        self.diffSummary = diffSummary
        self.eBrain = eBrain
        self.fallbackRiskLevel = fallbackRiskLevel
        self.fallbackPermitMode = fallbackPermitMode
    }
}

extension DecisionReviewCheckpointSnapshot {
    init(checkpoint: DecisionEvolutionCheckpoint) {
        self.init(
            checkpointID: checkpoint.id,
            previousCheckpointID: checkpoint.previousCheckpointID,
            createdAt: checkpoint.createdAt,
            mode: checkpoint.mode,
            approvalState: checkpoint.approvalState,
            rollbackReady: checkpoint.rollbackReady,
            hasBrainStateSnapshot: checkpoint.brainStateSnapshot != nil,
            diffSummary: checkpoint.diffSummary,
            eBrain: checkpoint.lineageSummary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:)),
            fallbackRiskLevel: checkpoint.calibrationStatus.rawValue,
            fallbackPermitMode: checkpoint.boundaryMode.rawValue
        )
    }

    init(summary: DecisionEvolutionCheckpointSummary, mode: DecisionMode) {
        self.init(
            checkpointID: summary.id,
            previousCheckpointID: summary.previousCheckpointID,
            createdAt: summary.createdAt,
            mode: mode,
            approvalState: summary.approvalState,
            rollbackReady: summary.rollbackReady,
            hasBrainStateSnapshot: false,
            diffSummary: summary.diffSummary,
            eBrain: summary.lineageSummary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:))
        )
    }

    init(lineage: DecisionEvolutionLineageSnapshot) {
        self.init(
            checkpointID: lineage.checkpointID,
            previousCheckpointID: lineage.previousCheckpointID,
            createdAt: lineage.createdAt,
            mode: lineage.mode,
            approvalState: lineage.approvalState,
            rollbackReady: lineage.rollbackReady,
            hasBrainStateSnapshot: lineage.hasBrainStateSnapshot,
            diffSummary: lineage.diffSummary,
            eBrain: lineage.eBrain
        )
    }
}

struct DecisionTestingCheckpointSelectionContext: Equatable, Sendable {
    let mode: DecisionMode?
    let source: DeveloperDecisionReplayEBrainSource?
    let referenceDate: Date
}

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let sessionEngineSnapshot: DecisionSessionRuntimeSnapshot?
    let pendingSessionEngineImportPreview: DecisionSessionEnginePendingImportPreview?
    let registeredProviders: [DecisionModelProviderDescriptor]
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
    let circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot
    let recentTraces: [DecisionIntelligenceTrace]
    let recentReplay: [DeveloperDecisionReplayEntry]
    let persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot]
    let pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot]
    let activeCheckpointHint: DecisionReviewCheckpointSnapshot?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let restorableCheckpointIDs: Set<String>
    let activeKillSwitches: [String]
    let eBrainTurn: BASEBrainTurnResult?

    init(
        generatedAt: Date,
        runtimeSnapshot: DecisionTestingRuntimeSnapshot,
        sessionEngineSnapshot: DecisionSessionRuntimeSnapshot? = nil,
        pendingSessionEngineImportPreview: DecisionSessionEnginePendingImportPreview? = nil,
        registeredProviders: [DecisionModelProviderDescriptor],
        intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot,
        cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot,
        circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot,
        recentTraces: [DecisionIntelligenceTrace],
        recentReplay: [DeveloperDecisionReplayEntry],
        persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot],
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot],
        activeCheckpointHint: DecisionReviewCheckpointSnapshot?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource = .none,
        restorableCheckpointIDs: Set<String> = [],
        activeKillSwitches: [String] = [],
        eBrainTurn: BASEBrainTurnResult?
    ) {
        self.generatedAt = generatedAt
        self.runtimeSnapshot = runtimeSnapshot
        self.sessionEngineSnapshot = sessionEngineSnapshot
        self.pendingSessionEngineImportPreview = pendingSessionEngineImportPreview
        self.registeredProviders = registeredProviders
        self.intelligenceTelemetry = intelligenceTelemetry
        self.cacheTelemetry = cacheTelemetry
        self.circuitBreakerSnapshot = circuitBreakerSnapshot
        self.recentTraces = recentTraces
        self.recentReplay = recentReplay
        self.persistedCheckpointLineages = persistedCheckpointLineages
        self.pendingReviewCheckpoints = pendingReviewCheckpoints
        self.activeCheckpointHint = activeCheckpointHint
        self.activeCheckpointSource = activeCheckpointSource
        self.restorableCheckpointIDs = restorableCheckpointIDs
        self.activeKillSwitches = activeKillSwitches
        self.eBrainTurn = eBrainTurn
    }

    var evolutionControlSurface: DecisionEvolutionControlSurface {
        evolutionControlSurfaceInventory.buildControlSurface(
            preferredCheckpointSelectionContext: preferredCheckpointSelectionContext
        )
    }

    var evolutionControlSurfaceInventory: DecisionEvolutionControlSurfaceInventory {
        DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: effectivePendingReviewCheckpoints,
            persistedLineages: persistedCheckpointLineages,
            activeCheckpoint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }

    var pendingReviewCheckpointLineages: [DecisionEvolutionLineageSnapshot] {
        persistedCheckpointLineages
            .filter { $0.approvalState == .reviewSuggested }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.checkpointID > rhs.checkpointID
            }
    }

    var pendingReviewCheckpointCount: Int {
        effectivePendingReviewCheckpoints.count
    }

    var effectivePendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot] {
        let checkpoints = if pendingReviewCheckpoints.isEmpty {
            pendingReviewCheckpointLineages.map(DecisionReviewCheckpointSnapshot.init(lineage:))
        } else {
            pendingReviewCheckpoints
        }

        return checkpoints.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.checkpointID > rhs.checkpointID
        }
    }

    var latestCheckpointLineage: DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.latestPersistedLineage(
            matching: preferredCheckpointSelectionContext
        )
    }

    var latestAutomaticCheckpointLineage: DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.latestAutomaticLineage(
            matching: preferredCheckpointSelectionContext
        )
    }

    var preferredCheckpointSelectionContext: DecisionTestingCheckpointSelectionContext? {
        if let preferredReplay = recentReplay.first(where: { !$0.isCheckpointOnlyRecovery }) {
            return DecisionTestingCheckpointSelectionContext(
                mode: preferredReplay.mode,
                source: preferredReplay.eBrain?.source,
                referenceDate: preferredReplay.timestamp
            )
        }

        return nil
    }

    func selectedCheckpointLineage(
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.selectedCheckpointLineage(
            matching: context
        )
    }

    private func selectedCheckpointLineage(
        in lineages: [DecisionEvolutionLineageSnapshot],
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.selectedCheckpointLineage(
            in: lineages,
            matching: context
        )
    }

    var effectiveEBrainSummary: DeveloperDecisionReplayEBrainSummary? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainSummary
    }

    var effectiveEBrainSource: DecisionTestingEBrainSource? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainSource
    }

    var effectiveEBrainFactsBundle: DecisionEvolutionEBrainFactsBundle? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainFactsBundle
    }

    var flightDeck: DecisionSystemFlightDeck {
        DecisionSystemFlightDeckBuilder.build(from: self, eBrainTurn: eBrainTurn)
    }

    func flightDeck(
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> DecisionSystemFlightDeck {
        DecisionSystemFlightDeckBuilder.build(
            from: self,
            eBrainTurn: eBrainTurn ?? self.eBrainTurn
        )
    }

    var thoughtFoldChecksum: String? {
        evolutionRuntimeFacts(currentBrainState: nil).thoughtFoldChecksum
    }

    var updateTicketSummaries: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).updateTicketSummaries
    }

    var runtimeAuditFindings: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).runtimeAuditFindings
    }

    var recommendedKillSwitches: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).recommendedKillSwitches
    }

    var effectiveActiveKillSwitches: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveActiveKillSwitches
    }

    func evolutionRuntimeFacts(
        currentBrainState: CurrentBrainState?
    ) -> DecisionEvolutionRuntimeFacts {
        let resolvedEffectiveEBrainSummary: DeveloperDecisionReplayEBrainSummary? = if let eBrainTurn {
            DeveloperDecisionReplayEBrainSummary(turn: eBrainTurn)
        } else {
            latestCheckpointLineage?.eBrain
        }
        let resolvedEffectiveEBrainSource = resolvedEffectiveEBrainSummary.map {
            $0.source == .liveRuntime
                ? DecisionTestingEBrainSource.liveRuntime
                : DecisionTestingEBrainSource.persistedCheckpoint
        }
        let resolvedEffectiveEBrainFactsBundle = resolvedEffectiveEBrainSummary.map {
            $0.factsBundle(modeTitle: preferredCheckpointSelectionContext?.mode?.shortTitle)
        }
        let resolvedThoughtFoldChecksum: String? = if let eBrainTurn {
            String(eBrainTurn.thoughtFold.checksum.prefix(12))
        } else {
            resolvedEffectiveEBrainSummary?.thoughtFoldChecksum
        }
        let resolvedUpdateTicketSummaries: [String] = if let eBrainTurn {
            eBrainTurn.updateTickets.map(\.summary)
        } else {
            resolvedEffectiveEBrainSummary?.updateTicketSummaries ?? []
        }
        let resolvedRuntimeAuditFindings: [String] = if let eBrainTurn {
            eBrainTurn.runtimeTrace.guardrailFindings.map(\.summary)
        } else {
            resolvedEffectiveEBrainSummary?.guardrailFindings ?? []
        }
        let resolvedEffectiveActiveKillSwitches: [String] = if let eBrainTurn {
            orderedUnique(
                activeKillSwitches + eBrainTurn.runtimeTrace.activeKillSwitches.map(\.rawValue)
            )
        } else {
            activeKillSwitches
        }
        let resolvedRecommendedKillSwitches: [String] = if let eBrainTurn {
            eBrainTurn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)
        } else if let resolvedEffectiveEBrainSummary {
            resolvedEffectiveEBrainSummary.killSwitches.filter {
                !resolvedEffectiveEBrainSummary.activeKillSwitches.contains($0)
            }
        } else {
            []
        }
        let currentBrainAutomaticCheckpoint = currentBrainState?.evolutionState.latestCheckpoint
            .flatMap { checkpoint -> DecisionReviewCheckpointSnapshot? in
                guard checkpoint.approvalState == .automatic else {
                    return nil
                }

                return DecisionReviewCheckpointSnapshot(
                    summary: checkpoint,
                    mode: currentBrainState?.mode ?? .quick
                )
            }
        let coverageFacts = evolutionControlSurface.coverageFacts(
            latestPersistedLineage: latestCheckpointLineage,
            recoveredCheckpointOverride: currentBrainAutomaticCheckpoint ?? evolutionControlSurface.activeCheckpoint
        )

        return DecisionEvolutionRuntimeFacts(
            effectiveEBrainSummary: resolvedEffectiveEBrainSummary,
            effectiveEBrainSource: resolvedEffectiveEBrainSource,
            effectiveEBrainFactsBundle: resolvedEffectiveEBrainFactsBundle,
            thoughtFoldChecksum: resolvedThoughtFoldChecksum,
            updateTicketSummaries: resolvedUpdateTicketSummaries,
            runtimeAuditFindings: resolvedRuntimeAuditFindings,
            effectiveActiveKillSwitches: resolvedEffectiveActiveKillSwitches,
            recommendedKillSwitches: resolvedRecommendedKillSwitches,
            coverageFacts: coverageFacts
        )
    }

    func evolutionCoverageFacts(
        currentBrainState: CurrentBrainState?
    ) -> DecisionEvolutionCoverageFacts {
        evolutionRuntimeFacts(currentBrainState: currentBrainState).coverageFacts
    }

    func attaching(
        eBrainTurn: BASEBrainTurnResult?
    ) -> DecisionTestingRuntimeExport {
        DecisionTestingRuntimeExport(
            generatedAt: generatedAt,
            runtimeSnapshot: runtimeSnapshot,
            sessionEngineSnapshot: sessionEngineSnapshot,
            pendingSessionEngineImportPreview: pendingSessionEngineImportPreview,
            registeredProviders: registeredProviders,
            intelligenceTelemetry: intelligenceTelemetry,
            cacheTelemetry: cacheTelemetry,
            circuitBreakerSnapshot: circuitBreakerSnapshot,
            recentTraces: recentTraces,
            recentReplay: recentReplay,
            persistedCheckpointLineages: persistedCheckpointLineages,
            pendingReviewCheckpoints: pendingReviewCheckpoints,
            activeCheckpointHint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            restorableCheckpointIDs: restorableCheckpointIDs,
            activeKillSwitches: activeKillSwitches,
            eBrainTurn: eBrainTurn
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    var basLifecycleSummary: BASLifecycleSummary {
        basRuntimeInspectionCompilation.lifecycleSummary
    }

    var basNeuralSummary: BASNeuralSummary {
        basRuntimeInspectionCompilation.neuralSummary
    }

    var basBrainSummary: BASBrainSummary {
        basRuntimeInspectionCompilation.brainSummary
    }

    var basRuntimeInspectionSummary: BASRuntimeInspectionSummary {
        basRuntimeInspectionCompilation.runtimeInspectionSummary
    }

    var basFlightDeckCompilation: BASAppleFlightDeckCompilation {
        BASAppleFlightDeckBuilder.build(
            from: BASAppleFlightDeckSourceInput(
                generatedAt: generatedAt,
                registeredProviderIDs: registeredProviders.map { $0.kind.rawValue },
                activeProviderID: runtimeSnapshot.runtimeStatus.active.rawValue,
                activeProviderTitle: runtimeSnapshot.runtimeStatus.active.title,
                backendTitle: runtimeSnapshot.gemmaBackendResolution.effectiveBackend.title,
                activeTaskGraphTaskCount: runtimeSnapshot.activeTaskGraph?.tasks.count ?? 0,
                hardwareAccelerationActive: runtimeSnapshot.gemmaBackendResolution.isHardwareAccelerated,
                runningOnSimulator: runtimeSnapshot.deviceCapabilities.isSimulator,
                onDeviceIntelligenceEnabled: runtimeSnapshot.preferences.onDeviceIntelligenceMode != .off,
                fallbackTitle: runtimeSnapshot.runtimeStatus.fallback?.title,
                inspectionSummary: basRuntimeInspectionSummary,
                brainSummary: basBrainSummary
            )
        )
    }

    private var basRuntimeInspectionCompilation: BASAppleRuntimeInspectionCompilation {
        let adaptationMatrix = runtimeSnapshot.executionProfile.adaptationMatrix

        return BASAppleRuntimeExportBuilder.compileRuntimeInspection(
            from: BASAppleRuntimeInspectionExportSourceInput(
                activeProviderID: runtimeSnapshot.runtimeStatus.active.rawValue,
                fallbackProviderID: runtimeSnapshot.runtimeStatus.fallback?.rawValue,
                runtimeGearID: adaptationMatrix.runtimeGear.rawValue,
                environmentClassID: adaptationMatrix.environmentClass.rawValue,
                deviceClassID: adaptationMatrix.deviceClass.rawValue,
                languageModeID: adaptationMatrix.languageMode.rawValue,
                taskEntropyIDByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value.entropy.rawValue
                },
                preferredProviderIDByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value.preferredProvider.rawValue
                },
                strategyByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                        kindID: item.value.kind.rawValue,
                        entropyID: item.value.entropy.rawValue,
                        runtimeGearID: item.value.runtimeGear.rawValue,
                        contextBudget: item.value.contextBudget,
                        outputCharacterBudget: item.value.outputCharacterBudget,
                        timeBudgetMs: item.value.timeBudgetMs,
                        toolCallBudget: item.value.toolCallBudget,
                        retrievalItemBudget: item.value.retrievalItemBudget,
                        retrievalModeID: item.value.retrievalMode.rawValue,
                        thinkingModeID: item.value.thinkingMode.rawValue,
                        outputModeID: item.value.outputMode.rawValue,
                        toneID: item.value.tone.rawValue,
                        actionSpace: item.value.actionSpace,
                        responseLanguageID: item.value.responseLanguage.rawValue,
                        allowsModelInvocation: item.value.allowsModelInvocation
                    )
                },
                effectivePreferredProviderIDByKind: Dictionary(
                    grouping: recentTraces.compactMap { trace in
                        trace.runtimeStrategy.map { (trace.kind.rawValue, $0.preferredProvider.rawValue) }
                    },
                    by: \.0
                )
                .compactMapValues { grouped in
                    grouped.first?.1
                },
                traceRecords: recentTraces.map { trace in
                    BASAppleRuntimeInspectionTraceSourceRecordInput(
                        kindID: trace.kind.rawValue,
                        hasContextState: trace.contextState != nil,
                        generation: trace.contextState?.generation,
                        rebuiltSession: trace.contextState?.rebuiltSession ?? false,
                        staleFieldCount: trace.contextState?.staleFieldCount ?? 0,
                        anchorFieldCount: trace.contextState?.anchorFieldCount ?? 0,
                        hasFrontstageState: trace.frontstageState != nil,
                        retainedEvidenceCount: trace.frontstageState?.retainedEvidenceCount ?? 0,
                        droppedEvidenceCount: trace.frontstageState?.droppedEvidenceCount ?? 0,
                        droppedInjectedEvidenceCount: trace.frontstageState?.droppedInjectedEvidenceCount ?? 0,
                        droppedDuplicateEvidenceCount: trace.frontstageState?.droppedDuplicateEvidenceCount ?? 0,
                        droppedBudgetEvidenceCount: trace.frontstageState?.droppedBudgetEvidenceCount ?? 0,
                        suppressedBehaviorCount: trace.neuralState?.suppressedBehaviors.count,
                        dominantActionID: trace.neuralState?.dominantAction?.rawValue,
                        strongestSignalID: trace.neuralState?.dominantActivations.first?.signal.rawValue,
                        dominantReactionWeightID: trace.brainState?.reactionWeights.dominantKey.rawValue,
                        profileCoreCount: trace.brainState?.profileCore.count,
                        activeGoalCount: trace.brainState?.activeGoals.count,
                        relevantMemoryCount: trace.brainState?.relevantMemories.count,
                        loadedPromotedMemoryCount: trace.brainState?.memoryGovernance.loadedPromotedMemoryCount,
                        loadedPendingMemoryCount: trace.brainState?.memoryGovernance.loadedPendingMemoryCount,
                        pendingCandidateCount: trace.brainState?.memoryGovernance.pendingCandidateCount,
                        promotedRecordCount: trace.brainState?.memoryGovernance.totalRecordCount,
                        screenedOutMemoryCount: trace.brainState?.memoryGovernance.screenedOutMemoryCount,
                        loadedEligibilityReasonCounts: trace.brainState?.memoryGovernance.loadedReasonCounts.reduce(into: [:]) { partialResult, item in
                            partialResult[item.key.rawValue] = item.value
                        } ?? [:],
                        screenedOutEligibilityReasonCounts: trace.brainState?.memoryGovernance.screenedOutReasonCounts.reduce(into: [:]) { partialResult, item in
                            partialResult[item.key.rawValue] = item.value
                        } ?? [:],
                        snapshotFingerprint: trace.brainState?.verificationSnapshot.fingerprint,
                        lowTrustMemoryLoadRate: trace.brainState?.verificationSnapshot.lowTrustMemoryLoadRate,
                        riskFlagIDs: trace.brainState?.verificationSnapshot.riskFlags.map(\.rawValue) ?? [],
                        identityRoleID: trace.brainState?.identityProfile.role.rawValue,
                        boundaryModeID: trace.brainState?.boundaryPolicy.mode.rawValue,
                        activeConstraintIDs: trace.brainState?.boundaryPolicy.activeConstraints.map(\.rawValue) ?? [],
                        calibrationStatusID: trace.brainState?.calibrationState.status.rawValue,
                        calibrationAlertIDs: trace.brainState?.calibrationState.alerts.map(\.rawValue) ?? [],
                        evolutionCheckpointCount: trace.brainState?.evolutionState.checkpointCount,
                        evolutionPendingReviewCount: trace.brainState?.evolutionState.pendingReviewCount,
                        evolutionRollbackReady: trace.brainState?.evolutionState.rollbackReady,
                        attemptedProviderIDs: trace.attemptedProviders.map(\.rawValue),
                        runtimeStrategy: trace.runtimeStrategy.map { strategy in
                            BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                                kindID: strategy.kind.rawValue,
                                entropyID: strategy.entropy.rawValue,
                                runtimeGearID: strategy.runtimeGear.rawValue,
                                contextBudget: strategy.contextBudget,
                                outputCharacterBudget: strategy.outputCharacterBudget,
                                timeBudgetMs: strategy.timeBudgetMs,
                                toolCallBudget: strategy.toolCallBudget,
                                retrievalItemBudget: strategy.retrievalItemBudget,
                                retrievalModeID: strategy.retrievalMode.rawValue,
                                thinkingModeID: strategy.thinkingMode.rawValue,
                                outputModeID: strategy.outputMode.rawValue,
                                toneID: strategy.tone.rawValue,
                                actionSpace: strategy.actionSpace,
                                responseLanguageID: strategy.responseLanguage.rawValue,
                                allowsModelInvocation: strategy.allowsModelInvocation
                            )
                        },
                        semanticPromptFingerprint: trace.semanticPromptFingerprint,
                        stablePrefixFingerprint: trace.stablePrefixFingerprint,
                        consistencyChecked: trace.consistencyCheck != nil,
                        consistencyRejected: trace.consistencyRejected,
                        consistencyViolationKindIDs: trace.consistencyCheck?.violations.map(\.kind.rawValue) ?? []
                    )
                },
                telemetrySummary: intelligenceTelemetry.substrateSummary,
                totalCacheEntries: cacheTelemetry.entryCountByKind.values.reduce(0, +),
                totalCacheLookupCount: cacheTelemetry.totalHits + cacheTelemetry.totalMisses,
                totalCacheRejectedStores: cacheTelemetry.totalRejectedStores,
                totalCacheQuarantinedHits: cacheTelemetry.totalQuarantinedHits,
                dominantBackendID: dominantGemmaBackend?.rawValue,
                registeredProviderCount: registeredProviders.count,
                registeredOpenModelProviderCount: registeredProviders.filter { $0.track == .builtInOpenModel }.count,
                activeCircuitProviderIDs: circuitBreakerSnapshot.activeProviders.map(\.rawValue),
                circuitTripCount: circuitBreakerSnapshot.totalTripCount,
                circuitTripCountByProvider: circuitBreakerSnapshot.totalTripCountByProvider.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value
                },
                circuitTripCountByReason: circuitBreakerSnapshot.totalTripCountByReason.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value
                },
                traceCount: recentTraces.count,
                replayCount: recentReplay.count
            )
        )
    }

    private var dominantGemmaBackend: InferenceBackendKind? {
        intelligenceTelemetry.gemmaBackendCount
            .max { lhs, rhs in lhs.value < rhs.value }?
            .key
    }

}

struct DecisionTestingSubstrateInspectionSnapshot {
    let export: DecisionTestingRuntimeExport
    let eBrainTurn: BASEBrainTurnResult?

    var synchronizedExport: DecisionTestingRuntimeExport {
        export.attaching(eBrainTurn: eBrainTurn)
    }

    var effectiveEBrainSource: DecisionTestingEBrainSource? {
        synchronizedExport.effectiveEBrainSource
    }

    var flightDeck: DecisionSystemFlightDeck {
        synchronizedExport.flightDeck
    }

    func consoleSnapshot(
        currentBrainState: CurrentBrainState?
    ) -> BASHostConsoleSnapshot {
        BehavioralAISubstrateBridge.consoleSnapshot(
            from: synchronizedExport,
            currentBrainState: currentBrainState,
            eBrainTurn: eBrainTurn
        )
    }
}

private extension DeveloperDecisionReplayEntry {
    var isCheckpointOnlyRecovery: Bool {
        if case .checkpoint = record {
            return true
        }
        return false
    }
}
