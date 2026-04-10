import Foundation
import BASAppleAdapters
import BASObservability
import BASPolicy
import BASRuntimeCore

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let registeredProviders: [DecisionModelProviderDescriptor]
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
    let circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot
    let recentTraces: [DecisionIntelligenceTrace]
    let recentReplay: [DeveloperDecisionReplayEntry]

    var flightDeck: DecisionSystemFlightDeck {
        DecisionSystemFlightDeckBuilder.build(from: self)
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

    private var traceSources: [BASAppleRuntimeInspectionTraceSourceInput] {
        recentTraces.map { trace in
            BASAppleRuntimeInspectionBuilder.traceSource(
                from: BASAppleRuntimeInspectionTraceRecordInput(
                    kind: trace.kind.rawValue,
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
                    dominantActionRawValue: trace.neuralState?.dominantAction?.rawValue,
                    strongestSignalRawValue: trace.neuralState?.dominantActivations.first?.signal.rawValue,
                    dominantReactionWeight: trace.brainState?.reactionWeights.dominantKey,
                    profileCoreCount: trace.brainState?.profileCore.count,
                    activeGoalCount: trace.brainState?.activeGoals.count,
                    relevantMemoryCount: trace.brainState?.relevantMemories.count,
                    loadedPromotedMemoryCount: trace.brainState?.memoryGovernance.loadedPromotedMemoryCount,
                    loadedPendingMemoryCount: trace.brainState?.memoryGovernance.loadedPendingMemoryCount,
                    pendingCandidateCount: trace.brainState?.memoryGovernance.pendingCandidateCount,
                    promotedRecordCount: trace.brainState?.memoryGovernance.totalRecordCount,
                    screenedOutMemoryCount: trace.brainState?.memoryGovernance.screenedOutMemoryCount,
                    loadedEligibilityReasonCounts: trace.brainState?.memoryGovernance.loadedReasonCounts ?? [:],
                    screenedOutEligibilityReasonCounts: trace.brainState?.memoryGovernance.screenedOutReasonCounts ?? [:],
                    snapshotFingerprint: trace.brainState?.verificationSnapshot.fingerprint,
                    lowTrustMemoryLoadRate: trace.brainState?.verificationSnapshot.lowTrustMemoryLoadRate,
                    riskFlags: trace.brainState?.verificationSnapshot.riskFlags ?? [],
                    identityRole: trace.brainState?.identityProfile.role,
                    boundaryMode: trace.brainState?.boundaryPolicy.mode,
                    activeConstraints: trace.brainState?.boundaryPolicy.activeConstraints ?? [],
                    calibrationStatus: trace.brainState?.calibrationState.status,
                    calibrationAlerts: trace.brainState?.calibrationState.alerts ?? [],
                    evolutionCheckpointCount: trace.brainState?.evolutionState.checkpointCount,
                    evolutionPendingReviewCount: trace.brainState?.evolutionState.pendingReviewCount,
                    evolutionRollbackReady: trace.brainState?.evolutionState.rollbackReady,
                    attemptedProviderIDs: trace.attemptedProviders.map(\.rawValue),
                    runtimeStrategy: trace.runtimeStrategy.map(substrateAdaptiveStrategy),
                    semanticPromptFingerprint: trace.semanticPromptFingerprint,
                    stablePrefixFingerprint: trace.stablePrefixFingerprint,
                    consistencyChecked: trace.consistencyCheck != nil,
                    consistencyRejected: trace.consistencyRejected,
                    consistencyViolationKinds: trace.consistencyCheck?.violations.map(\.kind) ?? []
                )
            )
        }
    }

    private var basRuntimeInspectionCompilation: BASAppleRuntimeInspectionCompilation {
        let adaptationMatrix = runtimeSnapshot.executionProfile.adaptationMatrix

        return BASAppleRuntimeInspectionBuilder.build(
            from: BASAppleRuntimeInspectionSourceInput(
                activeProviderID: runtimeSnapshot.runtimeStatus.active.rawValue,
                fallbackProviderID: runtimeSnapshot.runtimeStatus.fallback?.rawValue,
                runtimeGear: BASRuntimeGear(rawValue: adaptationMatrix.runtimeGear.rawValue) ?? .balanced,
                environmentClass: BASEnvironmentClass(rawValue: adaptationMatrix.environmentClass.rawValue) ?? .normal,
                deviceClass: BASDevicePerformanceClass(rawValue: adaptationMatrix.deviceClass.rawValue) ?? .balancedPhone,
                languageMode: BASLanguageMode(rawValue: adaptationMatrix.languageMode.rawValue) ?? .unknown,
                taskEntropyByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = BASTaskEntropyClass(rawValue: item.value.entropy.rawValue) ?? .medium
                },
                preferredProviderRawValueByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value.preferredProvider.rawValue
                },
                strategyByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = substrateAdaptiveStrategy(item.value)
                },
                effectivePreferredProviderRawValueByKind: Dictionary(
                    grouping: recentTraces.compactMap { trace in
                        trace.runtimeStrategy.map { (trace.kind.rawValue, $0.preferredProvider.rawValue) }
                    },
                    by: \.0
                )
                .compactMapValues { grouped in
                    grouped.first?.1
                },
                traceSources: traceSources,
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

    private func substrateAdaptiveStrategy(
        _ strategy: DecisionAdaptiveTaskStrategy
    ) -> BASAdaptiveTaskStrategy {
        BASAdaptiveTaskStrategy(
            kind: substrateTraceKind(strategy.kind),
            entropy: substrateTaskEntropy(strategy.entropy),
            runtimeGear: substrateRuntimeGear(strategy.runtimeGear),
            contextBudget: strategy.contextBudget,
            outputCharacterBudget: strategy.outputCharacterBudget,
            timeBudgetMs: strategy.timeBudgetMs,
            toolCallBudget: strategy.toolCallBudget,
            retrievalItemBudget: strategy.retrievalItemBudget,
            retrievalMode: substrateRetrievalMode(strategy.retrievalMode),
            thinkingMode: substrateThinkingMode(strategy.thinkingMode),
            outputMode: substrateOutputMode(strategy.outputMode),
            tone: substrateTone(strategy.tone),
            actionSpace: strategy.actionSpace,
            responseLanguage: substrateResponseLanguage(strategy.responseLanguage),
            allowsModelInvocation: strategy.allowsModelInvocation
        )
    }

    private func substrateTraceKind(
        _ kind: DecisionIntelligenceTraceKind
    ) -> BASAdaptiveTraceKind {
        switch kind {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }

    private func substrateTaskEntropy(
        _ entropy: DecisionTaskEntropyClass
    ) -> BASTaskEntropyClass {
        switch entropy {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }

    private func substrateRuntimeGear(
        _ gear: DecisionRuntimeGear
    ) -> BASRuntimeGear {
        switch gear {
        case .low:
            .low
        case .balanced:
            .balanced
        case .high:
            .high
        }
    }

    private func substrateRetrievalMode(
        _ mode: DecisionRetrievalMode
    ) -> BASRetrievalMode {
        switch mode {
        case .off:
            .off
        case .filtered:
            .filtered
        case .adaptive:
            .adaptive
        }
    }

    private func substrateThinkingMode(
        _ mode: DecisionThinkingMode
    ) -> BASThinkingMode {
        switch mode {
        case .off:
            .off
        case .gated:
            .gated
        }
    }

    private func substrateOutputMode(
        _ mode: DecisionOutputMode
    ) -> BASOutputMode {
        switch mode {
        case .deterministicTemplate:
            .deterministicTemplate
        case .guidedShort:
            .guidedShort
        case .structuredBoard:
            .structuredBoard
        case .reflectiveStructured:
            .reflectiveStructured
        case .jsonShort:
            .jsonShort
        }
    }

    private func substrateTone(
        _ tone: DecisionToneProfile
    ) -> BASToneProfile {
        switch tone {
        case .neutral:
            .neutral
        case .briefWarm:
            .briefWarm
        case .groundedDirect:
            .groundedDirect
        case .reflectiveClear:
            .reflectiveClear
        }
    }

    private func substrateResponseLanguage(
        _ responseLanguage: DecisionAdaptiveResponseLanguage
    ) -> BASAdaptiveResponseLanguage {
        switch responseLanguage {
        case .english:
            .english
        case .chinese:
            .chinese
        case .mixed:
            .mixed
        }
    }
}
