import Foundation
import BASHostKit

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
