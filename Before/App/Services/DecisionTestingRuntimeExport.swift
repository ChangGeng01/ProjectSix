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

    var lifecycleSummary: DecisionTestingLifecycleSummary {
        DecisionTestingLifecycleSummary(basSummary: basLifecycleSummary)
    }

    var neuralSummary: DecisionTestingNeuralSummary {
        DecisionTestingNeuralSummary(basSummary: basNeuralSummary)
    }

    var brainSummary: DecisionTestingBrainSummary {
        DecisionTestingBrainSummary(basSummary: basBrainSummary)
    }

    var summary: DecisionTestingRuntimeSummary {
        DecisionTestingRuntimeSummary(basSummary: basRuntimeInspectionSummary)
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
                activeProviderTitle: summary.activeProvider.title,
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
            BASAppleRuntimeInspectionTraceSourceInput(
                lifecycle: BASLifecycleTraceInput(
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
                    droppedBudgetEvidenceCount: trace.frontstageState?.droppedBudgetEvidenceCount ?? 0
                ),
                neural: trace.neuralState.map { neuralState in
                    BASNeuralTraceInput(
                        kind: trace.kind.rawValue,
                        suppressedBehaviorCount: neuralState.suppressedBehaviors.count,
                        dominantActionRawValue: neuralState.dominantAction?.rawValue,
                        strongestSignalRawValue: neuralState.dominantActivations.first?.signal.rawValue
                    )
                },
                brain: trace.brainState.map { brainState in
                    BASBrainTraceInput(
                        kind: trace.kind.rawValue,
                        dominantReactionWeight: brainState.reactionWeights.dominantKey,
                        profileCoreCount: brainState.profileCore.count,
                        activeGoalCount: brainState.activeGoals.count,
                        relevantMemoryCount: brainState.relevantMemories.count,
                        loadedPromotedMemoryCount: brainState.memoryGovernance.loadedPromotedMemoryCount,
                        loadedPendingMemoryCount: brainState.memoryGovernance.loadedPendingMemoryCount,
                        pendingCandidateCount: brainState.memoryGovernance.pendingCandidateCount,
                        promotedRecordCount: brainState.memoryGovernance.totalRecordCount,
                        screenedOutMemoryCount: brainState.memoryGovernance.screenedOutMemoryCount,
                        loadedEligibilityReasonCounts: brainState.memoryGovernance.loadedReasonCounts,
                        screenedOutEligibilityReasonCounts: brainState.memoryGovernance.screenedOutReasonCounts,
                        snapshotFingerprint: brainState.verificationSnapshot.fingerprint,
                        lowTrustMemoryLoadRate: brainState.verificationSnapshot.lowTrustMemoryLoadRate,
                        riskFlags: brainState.verificationSnapshot.riskFlags,
                        identityRole: brainState.identityProfile.role,
                        boundaryMode: brainState.boundaryPolicy.mode,
                        activeConstraints: brainState.boundaryPolicy.activeConstraints,
                        calibrationStatus: brainState.calibrationState.status,
                        calibrationAlerts: brainState.calibrationState.alerts,
                        evolutionCheckpointCount: brainState.evolutionState.checkpointCount,
                        evolutionPendingReviewCount: brainState.evolutionState.pendingReviewCount,
                        evolutionRollbackReady: brainState.evolutionState.rollbackReady
                    )
                },
                runtimeInspection: BASRuntimeInspectionTraceInput(
                    kind: trace.kind.rawValue,
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

    private func strategyMap<Value>(
        _ keyPath: KeyPath<DecisionAdaptiveTaskStrategy, Value>
    ) -> [DecisionIntelligenceTraceKind: Value] {
        runtimeSnapshot.executionProfile.adaptationMatrix.strategiesByKind.mapValues { strategy in
            strategy[keyPath: keyPath]
        }
    }

    private func effectiveStrategyMap<Value>(
        _ keyPath: KeyPath<DecisionAdaptiveTaskStrategy, Value>
    ) -> [DecisionIntelligenceTraceKind: Value] {
        Dictionary(grouping: recentTraces.compactMap { trace in
            trace.runtimeStrategy.map { (trace.kind, $0) }
        }, by: \.0)
        .compactMapValues { grouped in
            grouped.first?.1[keyPath: keyPath]
        }
    }

    private var firstAttemptedProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderKind] {
        Dictionary(grouping: recentTraces.filter { !$0.attemptedProviders.isEmpty }, by: \.kind)
            .compactMapValues { grouped in
                grouped.first?.attemptedProviders.first
            }
    }

    private var effectiveProviderOrderByKind: [DecisionIntelligenceTraceKind: [DecisionModelProviderKind]] {
        Dictionary(grouping: recentTraces.filter { !$0.attemptedProviders.isEmpty }, by: \.kind)
            .compactMapValues { grouped in
                grouped.first?.attemptedProviders
            }
    }

    private var latestGenerationByKind: [DecisionIntelligenceTraceKind: Int] {
        recentTraces.reduce(into: [:]) { partialResult, trace in
            guard let generation = trace.contextState?.generation else { return }
            partialResult[trace.kind] = max(partialResult[trace.kind] ?? generation, generation)
        }
    }

    private var averageAnchorFieldCountByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(grouping: recentTraces.filter { $0.contextState != nil }, by: \.kind)
            .compactMapValues { traces in
                guard !traces.isEmpty else { return nil }
                let total = traces.reduce(0) { partialResult, trace in
                    partialResult + (trace.contextState?.anchorFieldCount ?? 0)
                }
                return Double(total) / Double(traces.count)
            }
    }

    private var averageRetainedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(grouping: recentTraces.filter { $0.frontstageState != nil }, by: \.kind)
            .compactMapValues { traces in
                guard !traces.isEmpty else { return nil }
                let total = traces.reduce(0) { partialResult, trace in
                    partialResult + (trace.frontstageState?.retainedEvidenceCount ?? 0)
                }
                return Double(total) / Double(traces.count)
            }
    }

    private var evidenceRetentionRatio: Double {
        let retained = lifecycleSummary.retainedEvidenceCount
        let total = retained + lifecycleSummary.droppedEvidenceCount
        guard total > 0 else { return 0 }
        return Double(retained) / Double(total)
    }

    private var semanticPromptVariantCountByKind: [DecisionIntelligenceTraceKind: Int] {
        variantCountByKind(for: \.semanticPromptFingerprint)
    }

    private var semanticPromptReuseRateByKind: [DecisionIntelligenceTraceKind: Double] {
        reuseRateByKind(from: semanticPromptVariantCountByKind)
    }

    private var stablePrefixVariantCountByKind: [DecisionIntelligenceTraceKind: Int] {
        variantCountByKind(for: \.stablePrefixFingerprint)
    }

    private var stablePrefixReuseRateByKind: [DecisionIntelligenceTraceKind: Double] {
        reuseRateByKind(from: stablePrefixVariantCountByKind)
    }

    private var stablePrefixPollutionRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: intelligenceTelemetry.requestCountByKind.map { kind, requestCount in
                let variants = stablePrefixVariantCountByKind[kind] ?? 0
                let pollutionEvents = max(0, variants - 1)
                return (kind, rate(numerator: pollutionEvents, denominator: requestCount))
            }
        )
    }

    private func variantCountByKind(
        for keyPath: KeyPath<DecisionIntelligenceTrace, String?>
    ) -> [DecisionIntelligenceTraceKind: Int] {
        Dictionary(grouping: recentTraces, by: \.kind)
            .compactMapValues { traces in
                let variants = Set(traces.compactMap { $0[keyPath: keyPath] })
                guard !variants.isEmpty else { return nil }
                return variants.count
            }
    }

    private func reuseRateByKind(
        from variantCountByKind: [DecisionIntelligenceTraceKind: Int]
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: intelligenceTelemetry.requestCountByKind.map { kind, requestCount in
                let variants = min(variantCountByKind[kind] ?? requestCount, requestCount)
                let reused = max(0, requestCount - variants)
                return (kind, rate(numerator: reused, denominator: requestCount))
            }
        )
    }

    private var evidencePollutionRate: Double {
        rate(
            numerator: lifecycleSummary.droppedInjectedEvidenceCount,
            denominator: lifecycleSummary.retainedEvidenceCount + lifecycleSummary.droppedEvidenceCount
        )
    }

    private var evidencePollutionRateByKind: [DecisionIntelligenceTraceKind: Double] {
        evidenceRateByKind(
            numeratorByKind: lifecycleSummary.droppedInjectedEvidenceCountByKind
        )
    }

    private var duplicateEvidenceDropRate: Double {
        rate(
            numerator: lifecycleSummary.droppedDuplicateEvidenceCount,
            denominator: lifecycleSummary.retainedEvidenceCount + lifecycleSummary.droppedEvidenceCount
        )
    }

    private var duplicateEvidenceDropRateByKind: [DecisionIntelligenceTraceKind: Double] {
        evidenceRateByKind(
            numeratorByKind: lifecycleSummary.droppedDuplicateEvidenceCountByKind
        )
    }

    private var budgetTrimRate: Double {
        rate(
            numerator: lifecycleSummary.droppedBudgetEvidenceCount,
            denominator: lifecycleSummary.retainedEvidenceCount + lifecycleSummary.droppedEvidenceCount
        )
    }

    private var budgetTrimRateByKind: [DecisionIntelligenceTraceKind: Double] {
        evidenceRateByKind(
            numeratorByKind: lifecycleSummary.droppedBudgetEvidenceCountByKind
        )
    }

    private func memoryLoadRateByKind(
        promotedByKind: [DecisionIntelligenceTraceKind: Double],
        pendingByKind: [DecisionIntelligenceTraceKind: Double]
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: intelligenceTelemetry.requestCountByKind.keys.map { kind in
                let promoted = promotedByKind[kind] ?? 0
                let pending = pendingByKind[kind] ?? 0
                let total = promoted + pending
                return (kind, total > 0 ? pending / total : 0)
            }
        )
    }

    private func averageBrainMetricByKind(
        _ projection: (DecisionBrainState) -> Int
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0) { partialResult, item in
                partialResult + projection(item.1)
            }
            return Double(total) / Double(grouped.count)
        }
    }

    private func averageBrainMetricByKind(
        _ projection: (DecisionBrainState) -> Double
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0.0) { partialResult, item in
                partialResult + projection(item.1)
            }
            return total / Double(grouped.count)
        }
    }

    private func aggregatedBrainReasonCountsByKind(
        _ keyPath: KeyPath<DecisionMemoryGovernanceState, [DecisionMemoryEligibilityReason: Int]>
    ) -> [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .mapValues { grouped in
            grouped.reduce(into: [:]) { partialResult, item in
                for (reason, count) in item.1.memoryGovernance[keyPath: keyPath] {
                    partialResult[reason, default: 0] += count
                }
            }
        }
    }

    private func aggregatedBrainRiskFlagCountsByKind(
    ) -> [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .mapValues { grouped in
            grouped.reduce(into: [:]) { partialResult, item in
                for flag in item.1.verificationSnapshot.riskFlags {
                    partialResult[flag, default: 0] += 1
                }
            }
        }
    }

    private func aggregatedBrainBoundaryConstraintCountsByKind(
    ) -> [DecisionIntelligenceTraceKind: [DecisionBoundaryConstraint: Int]] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .mapValues { grouped in
            grouped.reduce(into: [:]) { partialResult, item in
                for constraint in item.1.boundaryPolicy.activeConstraints {
                    partialResult[constraint, default: 0] += 1
                }
            }
        }
    }

    private func aggregatedBrainCalibrationAlertCountsByKind(
    ) -> [DecisionIntelligenceTraceKind: [DecisionCalibrationAlert: Int]] {
        Dictionary(
            grouping: recentTraces.compactMap { trace in
                trace.brainState.map { (trace.kind, $0) }
            },
            by: \.0
        )
        .mapValues { grouped in
            grouped.reduce(into: [:]) { partialResult, item in
                for alert in item.1.calibrationState.alerts {
                    partialResult[alert, default: 0] += 1
                }
            }
        }
    }

    private func evidenceRateByKind(
        numeratorByKind: [DecisionIntelligenceTraceKind: Int]
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: intelligenceTelemetry.requestCountByKind.keys.map { kind in
                let retained = retainedEvidenceCountByKind[kind] ?? 0
                let dropped = lifecycleSummary.droppedEvidenceCountByKind[kind] ?? 0
                return (
                    kind,
                    rate(
                        numerator: numeratorByKind[kind] ?? 0,
                        denominator: retained + dropped
                    )
                )
            }
        )
    }

    private var retainedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int] {
        Dictionary(
            grouping: recentTraces.filter { $0.frontstageState != nil },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.frontstageState?.retainedEvidenceCount ?? 0)
            }
        }
    }

    private func rate(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private func mapKindDictionary<Value>(
        _ values: [String: Value]
    ) -> [DecisionIntelligenceTraceKind: Value] {
        mapKindDictionary(values) { $0 }
    }

    private func mapKindDictionary<Input, Output>(
        _ values: [String: Input],
        transform: (Input) -> Output?
    ) -> [DecisionIntelligenceTraceKind: Output] {
        values.reduce(into: [:]) { partialResult, item in
            guard
                let kind = DecisionIntelligenceTraceKind(rawValue: item.key),
                let mappedValue = transform(item.value)
            else {
                return
            }
            partialResult[kind] = mappedValue
        }
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

struct DecisionTestingLifecycleSummary: Equatable, Sendable {
    let contextAwareTraceCount: Int
    let rebuildCount: Int
    let rebuildCountByKind: [DecisionIntelligenceTraceKind: Int]
    let staleFieldDropCount: Int
    let staleFieldDropCountByKind: [DecisionIntelligenceTraceKind: Int]
    let retainedEvidenceCount: Int
    let droppedEvidenceCount: Int
    let droppedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedInjectedEvidenceCount: Int
    let droppedInjectedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedDuplicateEvidenceCount: Int
    let droppedDuplicateEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedBudgetEvidenceCount: Int
    let droppedBudgetEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let averageRetainedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAnchorFieldCountByKind: [DecisionIntelligenceTraceKind: Double]
    let latestGenerationByKind: [DecisionIntelligenceTraceKind: Int]
}

struct DecisionTestingNeuralSummary: Equatable, Sendable {
    let neuralTraceCount: Int
    let suppressedBehaviorCount: Int
    let dominantActionByKind: [DecisionIntelligenceTraceKind: DecisionActionRoute]
    let strongestSignalByKind: [DecisionIntelligenceTraceKind: DecisionNeuralSignal]
}

struct DecisionTestingBrainSummary: Equatable, Sendable {
    let brainTraceCount: Int
    let dominantReactionWeightByKind: [DecisionIntelligenceTraceKind: DecisionReactionWeightKey]
    let averageProfileCoreCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageActiveGoalCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageRelevantMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageLoadedPromotedMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageLoadedPendingMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePendingCandidateCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePromotedRecordCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageScreenedOutMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let loadedEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let screenedOutEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let pendingMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let retrievalRejectionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let latestSnapshotFingerprintByKind: [DecisionIntelligenceTraceKind: String]
    let snapshotVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowTrustMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let riskFlagCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]]
    let identityRoleByKind: [DecisionIntelligenceTraceKind: DecisionIdentityRole]
    let boundaryModeByKind: [DecisionIntelligenceTraceKind: DecisionBoundaryPolicyMode]
    let boundaryConstraintCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBoundaryConstraint: Int]]
    let calibrationStatusByKind: [DecisionIntelligenceTraceKind: DecisionCalibrationStatus]
    let calibrationAlertCountsByKind: [DecisionIntelligenceTraceKind: [DecisionCalibrationAlert: Int]]
    let evolutionCheckpointCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionPendingReviewCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionRollbackReadyByKind: [DecisionIntelligenceTraceKind: Bool]
}

struct DecisionTestingRuntimeSummary: Equatable, Sendable {
    let activeProvider: DecisionModelProviderKind
    let fallbackProvider: DecisionModelProviderKind?
    let runtimeGear: DecisionRuntimeGear
    let environmentClass: DecisionEnvironmentClass
    let deviceClass: DecisionDevicePerformanceClass
    let languageMode: DecisionLanguageMode
    let taskEntropyByKind: [DecisionIntelligenceTraceKind: DecisionTaskEntropyClass]
    let runtimeGearByKind: [DecisionIntelligenceTraceKind: DecisionRuntimeGear]
    let preferredProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderPreference]
    let allowsModelInvocationByKind: [DecisionIntelligenceTraceKind: Bool]
    let contextBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let outputCharacterBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let timeBudgetMsByKind: [DecisionIntelligenceTraceKind: Int]
    let toolCallBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let retrievalItemBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let retrievalModeByKind: [DecisionIntelligenceTraceKind: DecisionRetrievalMode]
    let thinkingModeByKind: [DecisionIntelligenceTraceKind: DecisionThinkingMode]
    let outputModeByKind: [DecisionIntelligenceTraceKind: DecisionOutputMode]
    let toneByKind: [DecisionIntelligenceTraceKind: DecisionToneProfile]
    let actionSpaceByKind: [DecisionIntelligenceTraceKind: [String]]
    let responseLanguageByKind: [DecisionIntelligenceTraceKind: DecisionAdaptiveResponseLanguage]
    let effectiveRuntimeGearByKind: [DecisionIntelligenceTraceKind: DecisionRuntimeGear]
    let effectivePreferredProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderPreference]
    let effectiveContextBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveOutputCharacterBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveTimeBudgetMsByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveToolCallBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveRetrievalItemBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveRetrievalModeByKind: [DecisionIntelligenceTraceKind: DecisionRetrievalMode]
    let effectiveThinkingModeByKind: [DecisionIntelligenceTraceKind: DecisionThinkingMode]
    let effectiveOutputModeByKind: [DecisionIntelligenceTraceKind: DecisionOutputMode]
    let effectiveToneByKind: [DecisionIntelligenceTraceKind: DecisionToneProfile]
    let effectiveActionSpaceByKind: [DecisionIntelligenceTraceKind: [String]]
    let effectiveResponseLanguageByKind: [DecisionIntelligenceTraceKind: DecisionAdaptiveResponseLanguage]
    let firstAttemptedProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderKind]
    let effectiveProviderOrderByKind: [DecisionIntelligenceTraceKind: [DecisionModelProviderKind]]
    let totalRequests: Int
    let totalProviderAttempts: Int
    let cacheHitRate: Double
    let admissionSkipRate: Double
    let providerBypassRate: Double
    let providerBypassRateByKind: [DecisionIntelligenceTraceKind: Double]
    let lowPressureModelCallRate: Double
    let lowPressureModelCallRateByKind: [DecisionIntelligenceTraceKind: Double]
    let avoidableModelCallRate: Double
    let avoidableModelCallRateByKind: [DecisionIntelligenceTraceKind: Double]
    let reminderRequestCount: Int
    let reminderKnowledgeNeedRate: Double
    let reminderControlOnlyRate: Double
    let reminderRetrievalBypassRate: Double
    let deterministicFallbackRate: Double
    let averageRequestDurationMs: Double
    let averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageFirstPresentableMs: Double
    let averageFirstPresentableMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePromptAssemblyMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAdmissionEvaluationMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageProviderSelectionMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageExecutionMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePrefillEquivalentShareByKind: [DecisionIntelligenceTraceKind: Double]
    let averageRequestDurationMsByProvider: [DecisionModelProviderKind: Double]
    let averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double]
    let averagePromptCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageImmutablePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAdaptivePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageStablePrefixShareByKind: [DecisionIntelligenceTraceKind: Double]
    let semanticPromptVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let semanticPromptReuseRateByKind: [DecisionIntelligenceTraceKind: Double]
    let stablePrefixVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let stablePrefixReuseRateByKind: [DecisionIntelligenceTraceKind: Double]
    let stablePrefixPollutionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let slowRequestRate: Double
    let slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double]
    let overTimeBudgetRate: Double
    let overTimeBudgetRateByKind: [DecisionIntelligenceTraceKind: Double]
    let overTargetBudgetRate: Double
    let fallbackActivations: Int
    let admissionSkipCount: Int
    let contextAwareTraceCount: Int
    let lifecycleRebuildCount: Int
    let staleFieldDropCount: Int
    let retainedEvidenceCount: Int
    let evidenceRetentionRatio: Double
    let droppedEvidenceCount: Int
    let droppedInjectedEvidenceCount: Int
    let droppedDuplicateEvidenceCount: Int
    let droppedBudgetEvidenceCount: Int
    let evidencePollutionRate: Double
    let evidencePollutionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let duplicateEvidenceDropRate: Double
    let duplicateEvidenceDropRateByKind: [DecisionIntelligenceTraceKind: Double]
    let budgetTrimRate: Double
    let budgetTrimRateByKind: [DecisionIntelligenceTraceKind: Double]
    let neuralTraceCount: Int
    let suppressedBehaviorCount: Int
    let brainTraceCount: Int
    let dominantReactionWeightByKind: [DecisionIntelligenceTraceKind: DecisionReactionWeightKey]
    let loadedEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let screenedOutEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let pendingMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let retrievalRejectionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let brainSnapshotFingerprintByKind: [DecisionIntelligenceTraceKind: String]
    let brainSnapshotVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowTrustMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let brainRiskFlagCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]]
    let identityRoleByKind: [DecisionIntelligenceTraceKind: DecisionIdentityRole]
    let boundaryModeByKind: [DecisionIntelligenceTraceKind: DecisionBoundaryPolicyMode]
    let boundaryConstraintCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBoundaryConstraint: Int]]
    let calibrationStatusByKind: [DecisionIntelligenceTraceKind: DecisionCalibrationStatus]
    let calibrationAlertCountsByKind: [DecisionIntelligenceTraceKind: [DecisionCalibrationAlert: Int]]
    let evolutionCheckpointCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionPendingReviewCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionRollbackReadyByKind: [DecisionIntelligenceTraceKind: Bool]
    let traceCount: Int
    let replayCount: Int
    let totalCacheEntries: Int
    let totalCacheRejectedStores: Int
    let totalCacheQuarantinedHits: Int
    let cacheQuarantineRate: Double
    let dominantGemmaBackend: InferenceBackendKind?
    let registeredProviderCount: Int
    let registeredOpenModelProviderCount: Int
    let circuitOpenProviderCount: Int
    let activeCircuitProviders: [DecisionModelProviderKind]
    let circuitTripCount: Int
    let circuitTripCountByProvider: [DecisionModelProviderKind: Int]
    let circuitTripCountByReason: [DecisionIntelligenceCircuitTripReason: Int]
    let consistencyCheckedTraceCount: Int
    let consistencyRejectedTraceCount: Int
    let consistencyCheckCoverageRate: Double
    let consistencyRejectRate: Double
    let consistencyRejectedCountByKind: [DecisionIntelligenceTraceKind: Int]
    let consistencyViolationCounts: [BASConsistencyViolationKind: Int]
}

private extension DecisionTestingLifecycleSummary {
    init(basSummary: BASLifecycleSummary) {
        self.init(
            contextAwareTraceCount: basSummary.contextAwareTraceCount,
            rebuildCount: basSummary.rebuildCount,
            rebuildCountByKind: mapTraceKindDictionary(basSummary.rebuildCountByKind),
            staleFieldDropCount: basSummary.staleFieldDropCount,
            staleFieldDropCountByKind: mapTraceKindDictionary(basSummary.staleFieldDropCountByKind),
            retainedEvidenceCount: basSummary.retainedEvidenceCount,
            droppedEvidenceCount: basSummary.droppedEvidenceCount,
            droppedEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedEvidenceCountByKind),
            droppedInjectedEvidenceCount: basSummary.droppedInjectedEvidenceCount,
            droppedInjectedEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedInjectedEvidenceCountByKind),
            droppedDuplicateEvidenceCount: basSummary.droppedDuplicateEvidenceCount,
            droppedDuplicateEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedDuplicateEvidenceCountByKind),
            droppedBudgetEvidenceCount: basSummary.droppedBudgetEvidenceCount,
            droppedBudgetEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedBudgetEvidenceCountByKind),
            averageRetainedEvidenceCountByKind: mapTraceKindDictionary(basSummary.averageRetainedEvidenceCountByKind),
            averageAnchorFieldCountByKind: mapTraceKindDictionary(basSummary.averageAnchorFieldCountByKind),
            latestGenerationByKind: mapTraceKindDictionary(basSummary.latestGenerationByKind)
        )
    }
}

private extension DecisionTestingNeuralSummary {
    init(basSummary: BASNeuralSummary) {
        self.init(
            neuralTraceCount: basSummary.neuralTraceCount,
            suppressedBehaviorCount: basSummary.suppressedBehaviorCount,
            dominantActionByKind: mapTraceKindDictionary(basSummary.dominantActionByKind) {
                DecisionActionRoute(rawValue: $0)
            },
            strongestSignalByKind: mapTraceKindDictionary(basSummary.strongestSignalByKind) {
                DecisionNeuralSignal(rawValue: $0)
            }
        )
    }
}

private extension DecisionTestingBrainSummary {
    init(basSummary: BASBrainSummary) {
        self.init(
            brainTraceCount: basSummary.brainTraceCount,
            dominantReactionWeightByKind: mapTraceKindDictionary(basSummary.dominantReactionWeightByKind) {
                DecisionReactionWeightKey(rawValue: $0.rawValue)
            },
            averageProfileCoreCountByKind: mapTraceKindDictionary(basSummary.averageProfileCoreCountByKind),
            averageActiveGoalCountByKind: mapTraceKindDictionary(basSummary.averageActiveGoalCountByKind),
            averageRelevantMemoryCountByKind: mapTraceKindDictionary(basSummary.averageRelevantMemoryCountByKind),
            averageLoadedPromotedMemoryCountByKind: mapTraceKindDictionary(basSummary.averageLoadedPromotedMemoryCountByKind),
            averageLoadedPendingMemoryCountByKind: mapTraceKindDictionary(basSummary.averageLoadedPendingMemoryCountByKind),
            averagePendingCandidateCountByKind: mapTraceKindDictionary(basSummary.averagePendingCandidateCountByKind),
            averagePromotedRecordCountByKind: mapTraceKindDictionary(basSummary.averagePromotedRecordCountByKind),
            averageScreenedOutMemoryCountByKind: mapTraceKindDictionary(basSummary.averageScreenedOutMemoryCountByKind),
            loadedEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.loadedEligibilityReasonCountsByKind),
            screenedOutEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.screenedOutEligibilityReasonCountsByKind),
            pendingMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.pendingMemoryLoadRateByKind),
            retrievalRejectionRateByKind: mapTraceKindDictionary(basSummary.retrievalRejectionRateByKind),
            latestSnapshotFingerprintByKind: mapTraceKindDictionary(basSummary.latestSnapshotFingerprintByKind),
            snapshotVariantCountByKind: mapTraceKindDictionary(basSummary.snapshotVariantCountByKind),
            lowTrustMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.lowTrustMemoryLoadRateByKind),
            riskFlagCountsByKind: mapTraceKindDictionary(basSummary.riskFlagCountsByKind),
            identityRoleByKind: mapTraceKindDictionary(basSummary.identityRoleByKind) {
                DecisionIdentityRole(rawValue: $0.rawValue)
            },
            boundaryModeByKind: mapTraceKindDictionary(basSummary.boundaryModeByKind) {
                DecisionBoundaryPolicyMode(rawValue: $0.rawValue)
            },
            boundaryConstraintCountsByKind: mapTraceKindDictionary(basSummary.boundaryConstraintCountsByKind),
            calibrationStatusByKind: mapTraceKindDictionary(basSummary.calibrationStatusByKind) {
                DecisionCalibrationStatus(rawValue: $0.rawValue)
            },
            calibrationAlertCountsByKind: mapTraceKindDictionary(basSummary.calibrationAlertCountsByKind),
            evolutionCheckpointCountByKind: mapTraceKindDictionary(basSummary.evolutionCheckpointCountByKind),
            evolutionPendingReviewCountByKind: mapTraceKindDictionary(basSummary.evolutionPendingReviewCountByKind),
            evolutionRollbackReadyByKind: mapTraceKindDictionary(basSummary.evolutionRollbackReadyByKind)
        )
    }
}

private extension DecisionTestingRuntimeSummary {
    init(basSummary: BASRuntimeInspectionSummary) {
        self.init(
            activeProvider: DecisionModelProviderKind(rawValue: basSummary.activeProviderID) ?? .template,
            fallbackProvider: basSummary.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:)),
            runtimeGear: DecisionRuntimeGear(rawValue: basSummary.runtimeGear.rawValue) ?? .balanced,
            environmentClass: DecisionEnvironmentClass(rawValue: basSummary.environmentClass.rawValue) ?? .normal,
            deviceClass: DecisionDevicePerformanceClass(rawValue: basSummary.deviceClass.rawValue) ?? .balancedPhone,
            languageMode: DecisionLanguageMode(rawValue: basSummary.languageMode.rawValue) ?? .unknown,
            taskEntropyByKind: mapTraceKindDictionary(basSummary.taskEntropyByKind) {
                DecisionTaskEntropyClass(rawValue: $0.rawValue)
            },
            runtimeGearByKind: mapTraceKindDictionary(basSummary.runtimeGearByKind) {
                DecisionRuntimeGear(rawValue: $0.rawValue)
            },
            preferredProviderByKind: mapTraceKindDictionary(basSummary.preferredProviderRawValueByKind) {
                DecisionModelProviderPreference(rawValue: $0)
            },
            allowsModelInvocationByKind: mapTraceKindDictionary(basSummary.allowsModelInvocationByKind),
            contextBudgetByKind: mapTraceKindDictionary(basSummary.contextBudgetByKind),
            outputCharacterBudgetByKind: mapTraceKindDictionary(basSummary.outputCharacterBudgetByKind),
            timeBudgetMsByKind: mapTraceKindDictionary(basSummary.timeBudgetMsByKind),
            toolCallBudgetByKind: mapTraceKindDictionary(basSummary.toolCallBudgetByKind),
            retrievalItemBudgetByKind: mapTraceKindDictionary(basSummary.retrievalItemBudgetByKind),
            retrievalModeByKind: mapTraceKindDictionary(basSummary.retrievalModeByKind) {
                DecisionRetrievalMode(rawValue: $0.rawValue)
            },
            thinkingModeByKind: mapTraceKindDictionary(basSummary.thinkingModeByKind) {
                DecisionThinkingMode(rawValue: $0.rawValue)
            },
            outputModeByKind: mapTraceKindDictionary(basSummary.outputModeByKind) {
                DecisionOutputMode(rawValue: $0.rawValue)
            },
            toneByKind: mapTraceKindDictionary(basSummary.toneByKind) {
                DecisionToneProfile(rawValue: $0.rawValue)
            },
            actionSpaceByKind: mapTraceKindDictionary(basSummary.actionSpaceByKind),
            responseLanguageByKind: mapTraceKindDictionary(basSummary.responseLanguageByKind) {
                DecisionAdaptiveResponseLanguage(rawValue: $0.rawValue)
            },
            effectiveRuntimeGearByKind: mapTraceKindDictionary(basSummary.effectiveRuntimeGearByKind) {
                DecisionRuntimeGear(rawValue: $0.rawValue)
            },
            effectivePreferredProviderByKind: mapTraceKindDictionary(basSummary.effectivePreferredProviderRawValueByKind) {
                DecisionModelProviderPreference(rawValue: $0)
            },
            effectiveContextBudgetByKind: mapTraceKindDictionary(basSummary.effectiveContextBudgetByKind),
            effectiveOutputCharacterBudgetByKind: mapTraceKindDictionary(basSummary.effectiveOutputCharacterBudgetByKind),
            effectiveTimeBudgetMsByKind: mapTraceKindDictionary(basSummary.effectiveTimeBudgetMsByKind),
            effectiveToolCallBudgetByKind: mapTraceKindDictionary(basSummary.effectiveToolCallBudgetByKind),
            effectiveRetrievalItemBudgetByKind: mapTraceKindDictionary(basSummary.effectiveRetrievalItemBudgetByKind),
            effectiveRetrievalModeByKind: mapTraceKindDictionary(basSummary.effectiveRetrievalModeByKind) {
                DecisionRetrievalMode(rawValue: $0.rawValue)
            },
            effectiveThinkingModeByKind: mapTraceKindDictionary(basSummary.effectiveThinkingModeByKind) {
                DecisionThinkingMode(rawValue: $0.rawValue)
            },
            effectiveOutputModeByKind: mapTraceKindDictionary(basSummary.effectiveOutputModeByKind) {
                DecisionOutputMode(rawValue: $0.rawValue)
            },
            effectiveToneByKind: mapTraceKindDictionary(basSummary.effectiveToneByKind) {
                DecisionToneProfile(rawValue: $0.rawValue)
            },
            effectiveActionSpaceByKind: mapTraceKindDictionary(basSummary.effectiveActionSpaceByKind),
            effectiveResponseLanguageByKind: mapTraceKindDictionary(basSummary.effectiveResponseLanguageByKind) {
                DecisionAdaptiveResponseLanguage(rawValue: $0.rawValue)
            },
            firstAttemptedProviderByKind: mapTraceKindDictionary(basSummary.firstAttemptedProviderByKind) {
                DecisionModelProviderKind(rawValue: $0)
            },
            effectiveProviderOrderByKind: mapTraceKindDictionary(basSummary.effectiveProviderOrderByKind) { values in
                values.compactMap(DecisionModelProviderKind.init(rawValue:))
            },
            totalRequests: basSummary.totalRequests,
            totalProviderAttempts: basSummary.totalProviderAttempts,
            cacheHitRate: basSummary.cacheHitRate,
            admissionSkipRate: basSummary.admissionSkipRate,
            providerBypassRate: basSummary.providerBypassRate,
            providerBypassRateByKind: mapTraceKindDictionary(basSummary.providerBypassRateByKind),
            lowPressureModelCallRate: basSummary.lowPressureModelCallRate,
            lowPressureModelCallRateByKind: mapTraceKindDictionary(basSummary.lowPressureModelCallRateByKind),
            avoidableModelCallRate: basSummary.avoidableModelCallRate,
            avoidableModelCallRateByKind: mapTraceKindDictionary(basSummary.avoidableModelCallRateByKind),
            reminderRequestCount: basSummary.reminderRequestCount,
            reminderKnowledgeNeedRate: basSummary.reminderKnowledgeNeedRate,
            reminderControlOnlyRate: basSummary.reminderControlOnlyRate,
            reminderRetrievalBypassRate: basSummary.reminderRetrievalBypassRate,
            deterministicFallbackRate: basSummary.deterministicFallbackRate,
            averageRequestDurationMs: basSummary.averageRequestDurationMs,
            averageRequestDurationMsByKind: mapTraceKindDictionary(basSummary.averageRequestDurationMsByKind),
            averageFirstPresentableMs: basSummary.averageFirstPresentableMs,
            averageFirstPresentableMsByKind: mapTraceKindDictionary(basSummary.averageFirstPresentableMsByKind),
            averagePromptAssemblyMsByKind: mapTraceKindDictionary(basSummary.averagePromptAssemblyMsByKind),
            averageAdmissionEvaluationMsByKind: mapTraceKindDictionary(basSummary.averageAdmissionEvaluationMsByKind),
            averageProviderSelectionMsByKind: mapTraceKindDictionary(basSummary.averageProviderSelectionMsByKind),
            averageExecutionMsByKind: mapTraceKindDictionary(basSummary.averageExecutionMsByKind),
            averagePrefillEquivalentShareByKind: mapTraceKindDictionary(basSummary.averagePrefillEquivalentShareByKind),
            averageRequestDurationMsByProvider: mapProviderKindDictionary(basSummary.averageRequestDurationMsByActiveProvider),
            averageRequestDurationMsByGemmaBackend: mapBackendKindDictionary(basSummary.averageRequestDurationMsByBackend),
            averagePromptCharactersByKind: mapTraceKindDictionary(basSummary.averagePromptCharactersByKind),
            averagePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averagePrefixCharactersByKind),
            averageImmutablePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averageImmutablePrefixCharactersByKind),
            averageAdaptivePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averageAdaptivePrefixCharactersByKind),
            averageSuffixCharactersByKind: mapTraceKindDictionary(basSummary.averageSuffixCharactersByKind),
            averageStablePrefixShareByKind: mapTraceKindDictionary(basSummary.averageStablePrefixShareByKind),
            semanticPromptVariantCountByKind: mapTraceKindDictionary(basSummary.semanticPromptVariantCountByKind),
            semanticPromptReuseRateByKind: mapTraceKindDictionary(basSummary.semanticPromptReuseRateByKind),
            stablePrefixVariantCountByKind: mapTraceKindDictionary(basSummary.stablePrefixVariantCountByKind),
            stablePrefixReuseRateByKind: mapTraceKindDictionary(basSummary.stablePrefixReuseRateByKind),
            stablePrefixPollutionRateByKind: mapTraceKindDictionary(basSummary.stablePrefixPollutionRateByKind),
            slowRequestRate: basSummary.slowRequestRate,
            slowRequestRateByKind: mapTraceKindDictionary(basSummary.slowRequestRateByKind),
            overTimeBudgetRate: basSummary.overTimeBudgetRate,
            overTimeBudgetRateByKind: mapTraceKindDictionary(basSummary.overTimeBudgetRateByKind),
            overTargetBudgetRate: basSummary.overTargetBudgetRate,
            fallbackActivations: basSummary.fallbackActivations,
            admissionSkipCount: basSummary.admissionSkipCount,
            contextAwareTraceCount: basSummary.contextAwareTraceCount,
            lifecycleRebuildCount: basSummary.lifecycleRebuildCount,
            staleFieldDropCount: basSummary.staleFieldDropCount,
            retainedEvidenceCount: basSummary.retainedEvidenceCount,
            evidenceRetentionRatio: basSummary.evidenceRetentionRatio,
            droppedEvidenceCount: basSummary.droppedEvidenceCount,
            droppedInjectedEvidenceCount: basSummary.droppedInjectedEvidenceCount,
            droppedDuplicateEvidenceCount: basSummary.droppedDuplicateEvidenceCount,
            droppedBudgetEvidenceCount: basSummary.droppedBudgetEvidenceCount,
            evidencePollutionRate: basSummary.evidencePollutionRate,
            evidencePollutionRateByKind: mapTraceKindDictionary(basSummary.evidencePollutionRateByKind),
            duplicateEvidenceDropRate: basSummary.duplicateEvidenceDropRate,
            duplicateEvidenceDropRateByKind: mapTraceKindDictionary(basSummary.duplicateEvidenceDropRateByKind),
            budgetTrimRate: basSummary.budgetTrimRate,
            budgetTrimRateByKind: mapTraceKindDictionary(basSummary.budgetTrimRateByKind),
            neuralTraceCount: basSummary.neuralTraceCount,
            suppressedBehaviorCount: basSummary.suppressedBehaviorCount,
            brainTraceCount: basSummary.brainTraceCount,
            dominantReactionWeightByKind: mapTraceKindDictionary(basSummary.dominantReactionWeightByKind) {
                DecisionReactionWeightKey(rawValue: $0.rawValue)
            },
            loadedEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.loadedEligibilityReasonCountsByKind),
            screenedOutEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.screenedOutEligibilityReasonCountsByKind),
            pendingMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.pendingMemoryLoadRateByKind),
            retrievalRejectionRateByKind: mapTraceKindDictionary(basSummary.retrievalRejectionRateByKind),
            brainSnapshotFingerprintByKind: mapTraceKindDictionary(basSummary.brainSnapshotFingerprintByKind),
            brainSnapshotVariantCountByKind: mapTraceKindDictionary(basSummary.brainSnapshotVariantCountByKind),
            lowTrustMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.lowTrustMemoryLoadRateByKind),
            brainRiskFlagCountsByKind: mapTraceKindDictionary(basSummary.brainRiskFlagCountsByKind),
            identityRoleByKind: mapTraceKindDictionary(basSummary.identityRoleByKind) {
                DecisionIdentityRole(rawValue: $0.rawValue)
            },
            boundaryModeByKind: mapTraceKindDictionary(basSummary.boundaryModeByKind) {
                DecisionBoundaryPolicyMode(rawValue: $0.rawValue)
            },
            boundaryConstraintCountsByKind: mapTraceKindDictionary(basSummary.boundaryConstraintCountsByKind),
            calibrationStatusByKind: mapTraceKindDictionary(basSummary.calibrationStatusByKind) {
                DecisionCalibrationStatus(rawValue: $0.rawValue)
            },
            calibrationAlertCountsByKind: mapTraceKindDictionary(basSummary.calibrationAlertCountsByKind),
            evolutionCheckpointCountByKind: mapTraceKindDictionary(basSummary.evolutionCheckpointCountByKind),
            evolutionPendingReviewCountByKind: mapTraceKindDictionary(basSummary.evolutionPendingReviewCountByKind),
            evolutionRollbackReadyByKind: mapTraceKindDictionary(basSummary.evolutionRollbackReadyByKind),
            traceCount: basSummary.traceCount,
            replayCount: basSummary.replayCount,
            totalCacheEntries: basSummary.totalCacheEntries,
            totalCacheRejectedStores: basSummary.totalCacheRejectedStores,
            totalCacheQuarantinedHits: basSummary.totalCacheQuarantinedHits,
            cacheQuarantineRate: basSummary.cacheQuarantineRate,
            dominantGemmaBackend: basSummary.dominantBackendID.flatMap(InferenceBackendKind.init(rawValue:)),
            registeredProviderCount: basSummary.registeredProviderCount,
            registeredOpenModelProviderCount: basSummary.registeredOpenModelProviderCount,
            circuitOpenProviderCount: basSummary.circuitOpenProviderCount,
            activeCircuitProviders: basSummary.activeCircuitProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:)),
            circuitTripCount: basSummary.circuitTripCount,
            circuitTripCountByProvider: mapProviderKindDictionary(basSummary.circuitTripCountByProvider),
            circuitTripCountByReason: mapCircuitReasonDictionary(basSummary.circuitTripCountByReason),
            consistencyCheckedTraceCount: basSummary.consistencyCheckedTraceCount,
            consistencyRejectedTraceCount: basSummary.consistencyRejectedTraceCount,
            consistencyCheckCoverageRate: basSummary.consistencyCheckCoverageRate,
            consistencyRejectRate: basSummary.consistencyRejectRate,
            consistencyRejectedCountByKind: mapTraceKindDictionary(basSummary.consistencyRejectedCountByKind),
            consistencyViolationCounts: basSummary.consistencyViolationCounts
        )
    }
}

private func mapTraceKindDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionIntelligenceTraceKind: Value] {
    mapTraceKindDictionary(values) { $0 }
}

private func mapTraceKindDictionary<Input, Output>(
    _ values: [String: Input],
    transform: (Input) -> Output?
) -> [DecisionIntelligenceTraceKind: Output] {
    values.reduce(into: [:]) { partialResult, item in
        guard
            let kind = DecisionIntelligenceTraceKind(rawValue: item.key),
            let mappedValue = transform(item.value)
        else {
            return
        }
        partialResult[kind] = mappedValue
    }
}

private func mapProviderKindDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionModelProviderKind: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let provider = DecisionModelProviderKind(rawValue: item.key) else { return }
        partialResult[provider] = item.value
    }
}

private func mapBackendKindDictionary<Value>(
    _ values: [String: Value]
) -> [InferenceBackendKind: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let backend = InferenceBackendKind(rawValue: item.key) else { return }
        partialResult[backend] = item.value
    }
}

private func mapCircuitReasonDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionIntelligenceCircuitTripReason: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let reason = DecisionIntelligenceCircuitTripReason(rawValue: item.key) else { return }
        partialResult[reason] = item.value
    }
}
