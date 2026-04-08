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

    var summary: DecisionTestingRuntimeSummary {
        DecisionTestingRuntimeSummary(
            activeProvider: runtimeSnapshot.runtimeStatus.active,
            fallbackProvider: runtimeSnapshot.runtimeStatus.fallback,
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
            traceCount: recentTraces.count,
            replayCount: recentReplay.count,
            totalCacheEntries: cacheTelemetry.entryCountByKind.values.reduce(0, +),
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

struct DecisionTestingRuntimeSummary: Equatable, Sendable {
    let activeProvider: DecisionModelProviderKind
    let fallbackProvider: DecisionModelProviderKind?
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
    let traceCount: Int
    let replayCount: Int
    let totalCacheEntries: Int
    let dominantGemmaBackend: InferenceBackendKind?
    let registeredProviderCount: Int
    let registeredOpenModelProviderCount: Int
    let circuitOpenProviderCount: Int
    let activeCircuitProviders: [DecisionModelProviderKind]
    let circuitTripCount: Int
    let circuitTripCountByProvider: [DecisionModelProviderKind: Int]
    let circuitTripCountByReason: [DecisionIntelligenceCircuitTripReason: Int]
}
