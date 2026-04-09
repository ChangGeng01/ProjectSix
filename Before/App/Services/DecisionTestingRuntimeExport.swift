import Foundation

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let registeredProviders: [DecisionModelProviderDescriptor]
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
    let circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot
    let recentTraces: [DecisionIntelligenceTrace]
    let recentReplay: [DeveloperDecisionReplayEntry]

    var lifecycleSummary: DecisionTestingLifecycleSummary {
        let contextAwareTraces = recentTraces.compactMap(\.contextState)
        let rebuildCountByKind = Dictionary(
            grouping: recentTraces.filter { $0.contextState?.rebuiltSession == true },
            by: \.kind
        )
        .mapValues(\.count)

        let staleFieldCountByKind = Dictionary(
            grouping: recentTraces.filter { ($0.contextState?.staleFieldCount ?? 0) > 0 },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.contextState?.staleFieldCount ?? 0)
            }
        }

        let droppedEvidenceCountByKind = Dictionary(
            grouping: recentTraces.filter { ($0.frontstageState?.droppedEvidenceCount ?? 0) > 0 },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.frontstageState?.droppedEvidenceCount ?? 0)
            }
        }

        let droppedInjectedEvidenceCountByKind = Dictionary(
            grouping: recentTraces.filter { ($0.frontstageState?.droppedInjectedEvidenceCount ?? 0) > 0 },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.frontstageState?.droppedInjectedEvidenceCount ?? 0)
            }
        }

        let droppedDuplicateEvidenceCountByKind = Dictionary(
            grouping: recentTraces.filter { ($0.frontstageState?.droppedDuplicateEvidenceCount ?? 0) > 0 },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.frontstageState?.droppedDuplicateEvidenceCount ?? 0)
            }
        }

        let droppedBudgetEvidenceCountByKind = Dictionary(
            grouping: recentTraces.filter { ($0.frontstageState?.droppedBudgetEvidenceCount ?? 0) > 0 },
            by: \.kind
        )
        .mapValues { traces in
            traces.reduce(0) { partialResult, trace in
                partialResult + (trace.frontstageState?.droppedBudgetEvidenceCount ?? 0)
            }
        }

        return DecisionTestingLifecycleSummary(
            contextAwareTraceCount: contextAwareTraces.count,
            rebuildCount: contextAwareTraces.filter(\.rebuiltSession).count,
            rebuildCountByKind: rebuildCountByKind,
            staleFieldDropCount: contextAwareTraces.reduce(0) { $0 + $1.staleFieldCount },
            staleFieldDropCountByKind: staleFieldCountByKind,
            retainedEvidenceCount: recentTraces.reduce(0) { $0 + ($1.frontstageState?.retainedEvidenceCount ?? 0) },
            droppedEvidenceCount: recentTraces.reduce(0) { $0 + ($1.frontstageState?.droppedEvidenceCount ?? 0) },
            droppedEvidenceCountByKind: droppedEvidenceCountByKind,
            droppedInjectedEvidenceCount: recentTraces.reduce(0) { $0 + ($1.frontstageState?.droppedInjectedEvidenceCount ?? 0) },
            droppedInjectedEvidenceCountByKind: droppedInjectedEvidenceCountByKind,
            droppedDuplicateEvidenceCount: recentTraces.reduce(0) { $0 + ($1.frontstageState?.droppedDuplicateEvidenceCount ?? 0) },
            droppedDuplicateEvidenceCountByKind: droppedDuplicateEvidenceCountByKind,
            droppedBudgetEvidenceCount: recentTraces.reduce(0) { $0 + ($1.frontstageState?.droppedBudgetEvidenceCount ?? 0) },
            droppedBudgetEvidenceCountByKind: droppedBudgetEvidenceCountByKind,
            averageRetainedEvidenceCountByKind: averageRetainedEvidenceCountByKind,
            averageAnchorFieldCountByKind: averageAnchorFieldCountByKind,
            latestGenerationByKind: latestGenerationByKind
        )
    }

    var neuralSummary: DecisionTestingNeuralSummary {
        let neuralTraces = recentTraces.compactMap { trace in
            trace.neuralState.map { (trace.kind, $0) }
        }

        let dominantActionByKind = Dictionary(grouping: neuralTraces, by: \.0)
            .compactMapValues { grouped in
                grouped
                    .compactMap(\.1.dominantAction)
                    .first
            }

        let strongestSignalByKind = Dictionary(grouping: neuralTraces, by: \.0)
            .compactMapValues { grouped in
                grouped
                    .compactMap { $0.1.dominantActivations.first?.signal }
                    .first
            }

        return DecisionTestingNeuralSummary(
            neuralTraceCount: neuralTraces.count,
            suppressedBehaviorCount: neuralTraces.reduce(0) { $0 + $1.1.suppressedBehaviors.count },
            dominantActionByKind: dominantActionByKind,
            strongestSignalByKind: strongestSignalByKind
        )
    }

    var brainSummary: DecisionTestingBrainSummary {
        let brainTraces = recentTraces.compactMap { trace in
            trace.brainState.map { (trace.kind, $0) }
        }

        let dominantReactionWeightByKind = Dictionary(grouping: brainTraces, by: \.0)
            .compactMapValues { grouped in
                grouped.first?.1.reactionWeights.dominantKey
            }

        let averageProfileCoreCountByKind = averageBrainMetricByKind { $0.profileCore.count }
        let averageActiveGoalCountByKind = averageBrainMetricByKind { $0.activeGoals.count }
        let averageRelevantMemoryCountByKind = averageBrainMetricByKind { $0.relevantMemories.count }
        let averageLoadedPromotedMemoryCountByKind = averageBrainMetricByKind { $0.memoryGovernance.loadedPromotedMemoryCount }
        let averageLoadedPendingMemoryCountByKind = averageBrainMetricByKind { $0.memoryGovernance.loadedPendingMemoryCount }
        let averagePendingCandidateCountByKind = averageBrainMetricByKind { $0.memoryGovernance.pendingCandidateCount }
        let averagePromotedRecordCountByKind = averageBrainMetricByKind { $0.memoryGovernance.totalRecordCount }
        let averageScreenedOutMemoryCountByKind = averageBrainMetricByKind { $0.memoryGovernance.screenedOutMemoryCount }
        let loadedEligibilityReasonCountsByKind = aggregatedBrainReasonCountsByKind(\.loadedReasonCounts)
        let screenedOutEligibilityReasonCountsByKind = aggregatedBrainReasonCountsByKind(\.screenedOutReasonCounts)
        let pendingMemoryLoadRateByKind = memoryLoadRateByKind(
            promotedByKind: averageLoadedPromotedMemoryCountByKind,
            pendingByKind: averageLoadedPendingMemoryCountByKind
        )
        let retrievalRejectionRateByKind = memoryLoadRateByKind(
            promotedByKind: averageRelevantMemoryCountByKind,
            pendingByKind: averageScreenedOutMemoryCountByKind
        )
        let latestSnapshotByKind = Dictionary(grouping: brainTraces, by: \.0)
            .compactMapValues { grouped in
                grouped.first?.1.verificationSnapshot
            }
        let snapshotVariantCountByKind = Dictionary(grouping: brainTraces, by: \.0)
            .mapValues { grouped in
                Set(grouped.map { $0.1.verificationSnapshot.fingerprint }).count
            }
        let lowTrustMemoryLoadRateByKind = averageBrainMetricByKind {
            $0.verificationSnapshot.lowTrustMemoryLoadRate
        }
        let riskFlagCountsByKind = aggregatedBrainRiskFlagCountsByKind()

        return DecisionTestingBrainSummary(
            brainTraceCount: brainTraces.count,
            dominantReactionWeightByKind: dominantReactionWeightByKind,
            averageProfileCoreCountByKind: averageProfileCoreCountByKind,
            averageActiveGoalCountByKind: averageActiveGoalCountByKind,
            averageRelevantMemoryCountByKind: averageRelevantMemoryCountByKind,
            averageLoadedPromotedMemoryCountByKind: averageLoadedPromotedMemoryCountByKind,
            averageLoadedPendingMemoryCountByKind: averageLoadedPendingMemoryCountByKind,
            averagePendingCandidateCountByKind: averagePendingCandidateCountByKind,
            averagePromotedRecordCountByKind: averagePromotedRecordCountByKind,
            averageScreenedOutMemoryCountByKind: averageScreenedOutMemoryCountByKind,
            loadedEligibilityReasonCountsByKind: loadedEligibilityReasonCountsByKind,
            screenedOutEligibilityReasonCountsByKind: screenedOutEligibilityReasonCountsByKind,
            pendingMemoryLoadRateByKind: pendingMemoryLoadRateByKind,
            retrievalRejectionRateByKind: retrievalRejectionRateByKind,
            latestSnapshotByKind: latestSnapshotByKind,
            snapshotVariantCountByKind: snapshotVariantCountByKind,
            lowTrustMemoryLoadRateByKind: lowTrustMemoryLoadRateByKind,
            riskFlagCountsByKind: riskFlagCountsByKind
        )
    }

    var summary: DecisionTestingRuntimeSummary {
        let adaptationMatrix = runtimeSnapshot.executionProfile.adaptationMatrix
        return DecisionTestingRuntimeSummary(
            activeProvider: runtimeSnapshot.runtimeStatus.active,
            fallbackProvider: runtimeSnapshot.runtimeStatus.fallback,
            runtimeGear: adaptationMatrix.runtimeGear,
            environmentClass: adaptationMatrix.environmentClass,
            deviceClass: adaptationMatrix.deviceClass,
            languageMode: adaptationMatrix.languageMode,
            taskEntropyByKind: strategyMap(\.entropy),
            runtimeGearByKind: strategyMap(\.runtimeGear),
            preferredProviderByKind: strategyMap(\.preferredProvider),
            allowsModelInvocationByKind: strategyMap(\.allowsModelInvocation),
            contextBudgetByKind: strategyMap(\.contextBudget),
            outputCharacterBudgetByKind: strategyMap(\.outputCharacterBudget),
            timeBudgetMsByKind: strategyMap(\.timeBudgetMs),
            toolCallBudgetByKind: strategyMap(\.toolCallBudget),
            retrievalItemBudgetByKind: strategyMap(\.retrievalItemBudget),
            retrievalModeByKind: strategyMap(\.retrievalMode),
            thinkingModeByKind: strategyMap(\.thinkingMode),
            outputModeByKind: strategyMap(\.outputMode),
            toneByKind: strategyMap(\.tone),
            actionSpaceByKind: strategyMap(\.actionSpace),
            responseLanguageByKind: strategyMap(\.responseLanguage),
            effectiveRuntimeGearByKind: effectiveStrategyMap(\.runtimeGear),
            effectivePreferredProviderByKind: effectiveStrategyMap(\.preferredProvider),
            effectiveContextBudgetByKind: effectiveStrategyMap(\.contextBudget),
            effectiveOutputCharacterBudgetByKind: effectiveStrategyMap(\.outputCharacterBudget),
            effectiveTimeBudgetMsByKind: effectiveStrategyMap(\.timeBudgetMs),
            effectiveToolCallBudgetByKind: effectiveStrategyMap(\.toolCallBudget),
            effectiveRetrievalItemBudgetByKind: effectiveStrategyMap(\.retrievalItemBudget),
            effectiveRetrievalModeByKind: effectiveStrategyMap(\.retrievalMode),
            effectiveThinkingModeByKind: effectiveStrategyMap(\.thinkingMode),
            effectiveOutputModeByKind: effectiveStrategyMap(\.outputMode),
            effectiveToneByKind: effectiveStrategyMap(\.tone),
            effectiveActionSpaceByKind: effectiveStrategyMap(\.actionSpace),
            effectiveResponseLanguageByKind: effectiveStrategyMap(\.responseLanguage),
            firstAttemptedProviderByKind: firstAttemptedProviderByKind,
            effectiveProviderOrderByKind: effectiveProviderOrderByKind,
            totalRequests: intelligenceTelemetry.totalRequests,
            totalProviderAttempts: intelligenceTelemetry.totalProviderAttempts,
            cacheHitRate: intelligenceTelemetry.cacheHitRate,
            admissionSkipRate: intelligenceTelemetry.admissionSkipRate,
            providerBypassRate: intelligenceTelemetry.providerBypassRate,
            providerBypassRateByKind: intelligenceTelemetry.providerBypassRateByKind,
            lowPressureModelCallRate: intelligenceTelemetry.lowPressureModelCallRate,
            lowPressureModelCallRateByKind: intelligenceTelemetry.lowPressureModelCallRateByKind,
            avoidableModelCallRate: intelligenceTelemetry.avoidableModelCallRate,
            avoidableModelCallRateByKind: intelligenceTelemetry.avoidableModelCallRateByKind,
            reminderRequestCount: intelligenceTelemetry.requestCountByKind[.reminder] ?? 0,
            reminderKnowledgeNeedRate: intelligenceTelemetry.reminderKnowledgeNeedRate,
            reminderControlOnlyRate: intelligenceTelemetry.reminderControlOnlyRate,
            reminderRetrievalBypassRate: intelligenceTelemetry.reminderRetrievalBypassRate,
            deterministicFallbackRate: intelligenceTelemetry.deterministicFallbackRate,
            averageRequestDurationMs: intelligenceTelemetry.averageRequestDurationMs,
            averageRequestDurationMsByKind: intelligenceTelemetry.averageRequestDurationMsByKind,
            averageRequestDurationMsByProvider: intelligenceTelemetry.averageRequestDurationMsByActiveProvider,
            averageRequestDurationMsByGemmaBackend: intelligenceTelemetry.averageRequestDurationMsByGemmaBackend,
            averagePromptCharactersByKind: intelligenceTelemetry.averagePromptCharactersByKind,
            averagePrefixCharactersByKind: intelligenceTelemetry.averagePrefixCharactersByKind,
            averageImmutablePrefixCharactersByKind: intelligenceTelemetry.averageImmutablePrefixCharactersByKind,
            averageAdaptivePrefixCharactersByKind: intelligenceTelemetry.averageAdaptivePrefixCharactersByKind,
            averageSuffixCharactersByKind: intelligenceTelemetry.averageSuffixCharactersByKind,
            averageStablePrefixShareByKind: intelligenceTelemetry.averageStablePrefixShareByKind,
            semanticPromptVariantCountByKind: semanticPromptVariantCountByKind,
            semanticPromptReuseRateByKind: semanticPromptReuseRateByKind,
            stablePrefixVariantCountByKind: stablePrefixVariantCountByKind,
            stablePrefixReuseRateByKind: stablePrefixReuseRateByKind,
            stablePrefixPollutionRateByKind: stablePrefixPollutionRateByKind,
            slowRequestRate: intelligenceTelemetry.slowRequestRate,
            slowRequestRateByKind: intelligenceTelemetry.slowRequestRateByKind,
            overTimeBudgetRate: intelligenceTelemetry.overTimeBudgetRate,
            overTimeBudgetRateByKind: intelligenceTelemetry.overTimeBudgetRateByKind,
            overTargetBudgetRate: intelligenceTelemetry.overTargetBudgetRate,
            fallbackActivations: intelligenceTelemetry.fallbackActivations,
            admissionSkipCount: intelligenceTelemetry.outcomeCount[.admissionSkipped] ?? 0,
            contextAwareTraceCount: lifecycleSummary.contextAwareTraceCount,
            lifecycleRebuildCount: lifecycleSummary.rebuildCount,
            staleFieldDropCount: lifecycleSummary.staleFieldDropCount,
            retainedEvidenceCount: lifecycleSummary.retainedEvidenceCount,
            evidenceRetentionRatio: evidenceRetentionRatio,
            droppedEvidenceCount: lifecycleSummary.droppedEvidenceCount,
            droppedInjectedEvidenceCount: lifecycleSummary.droppedInjectedEvidenceCount,
            droppedDuplicateEvidenceCount: lifecycleSummary.droppedDuplicateEvidenceCount,
            droppedBudgetEvidenceCount: lifecycleSummary.droppedBudgetEvidenceCount,
            evidencePollutionRate: evidencePollutionRate,
            evidencePollutionRateByKind: evidencePollutionRateByKind,
            duplicateEvidenceDropRate: duplicateEvidenceDropRate,
            duplicateEvidenceDropRateByKind: duplicateEvidenceDropRateByKind,
            budgetTrimRate: budgetTrimRate,
            budgetTrimRateByKind: budgetTrimRateByKind,
            neuralTraceCount: neuralSummary.neuralTraceCount,
            suppressedBehaviorCount: neuralSummary.suppressedBehaviorCount,
            brainTraceCount: brainSummary.brainTraceCount,
            dominantReactionWeightByKind: brainSummary.dominantReactionWeightByKind,
            loadedEligibilityReasonCountsByKind: brainSummary.loadedEligibilityReasonCountsByKind,
            screenedOutEligibilityReasonCountsByKind: brainSummary.screenedOutEligibilityReasonCountsByKind,
            pendingMemoryLoadRateByKind: brainSummary.pendingMemoryLoadRateByKind,
            retrievalRejectionRateByKind: brainSummary.retrievalRejectionRateByKind,
            brainSnapshotFingerprintByKind: brainSummary.latestSnapshotByKind.mapValues(\.fingerprint),
            brainSnapshotVariantCountByKind: brainSummary.snapshotVariantCountByKind,
            lowTrustMemoryLoadRateByKind: brainSummary.lowTrustMemoryLoadRateByKind,
            brainRiskFlagCountsByKind: brainSummary.riskFlagCountsByKind,
            traceCount: recentTraces.count,
            replayCount: recentReplay.count,
            totalCacheEntries: cacheTelemetry.entryCountByKind.values.reduce(0, +),
            totalCacheRejectedStores: cacheTelemetry.totalRejectedStores,
            totalCacheQuarantinedHits: cacheTelemetry.totalQuarantinedHits,
            cacheQuarantineRate: rate(
                numerator: cacheTelemetry.totalQuarantinedHits,
                denominator: cacheTelemetry.totalHits + cacheTelemetry.totalMisses
            ),
            dominantGemmaBackend: dominantGemmaBackend,
            registeredProviderCount: registeredProviders.count,
            registeredOpenModelProviderCount: registeredProviders.filter { $0.track == .builtInOpenModel }.count,
            circuitOpenProviderCount: circuitBreakerSnapshot.activeProviders.count,
            activeCircuitProviders: circuitBreakerSnapshot.activeProviders,
            circuitTripCount: circuitBreakerSnapshot.totalTripCount,
            circuitTripCountByProvider: circuitBreakerSnapshot.totalTripCountByProvider,
            circuitTripCountByReason: circuitBreakerSnapshot.totalTripCountByReason
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
    let latestSnapshotByKind: [DecisionIntelligenceTraceKind: DecisionBrainStateSnapshot]
    let snapshotVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowTrustMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let riskFlagCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]]
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
}
