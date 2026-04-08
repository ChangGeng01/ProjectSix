import Foundation

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
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

        return DecisionTestingLifecycleSummary(
            contextAwareTraceCount: contextAwareTraces.count,
            rebuildCount: contextAwareTraces.filter(\.rebuiltSession).count,
            rebuildCountByKind: rebuildCountByKind,
            staleFieldDropCount: contextAwareTraces.reduce(0) { $0 + $1.staleFieldCount },
            staleFieldDropCountByKind: staleFieldCountByKind,
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
            slowRequestRate: intelligenceTelemetry.slowRequestRate,
            slowRequestRateByKind: intelligenceTelemetry.slowRequestRateByKind,
            overTargetBudgetRate: intelligenceTelemetry.overTargetBudgetRate,
            fallbackActivations: intelligenceTelemetry.fallbackActivations,
            admissionSkipCount: intelligenceTelemetry.outcomeCount[.admissionSkipped] ?? 0,
            contextAwareTraceCount: lifecycleSummary.contextAwareTraceCount,
            lifecycleRebuildCount: lifecycleSummary.rebuildCount,
            staleFieldDropCount: lifecycleSummary.staleFieldDropCount,
            neuralTraceCount: neuralSummary.neuralTraceCount,
            suppressedBehaviorCount: neuralSummary.suppressedBehaviorCount,
            traceCount: recentTraces.count,
            replayCount: recentReplay.count,
            totalCacheEntries: cacheTelemetry.entryCountByKind.values.reduce(0, +),
            dominantGemmaBackend: dominantGemmaBackend
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
}

struct DecisionTestingLifecycleSummary: Equatable, Sendable {
    let contextAwareTraceCount: Int
    let rebuildCount: Int
    let rebuildCountByKind: [DecisionIntelligenceTraceKind: Int]
    let staleFieldDropCount: Int
    let staleFieldDropCountByKind: [DecisionIntelligenceTraceKind: Int]
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
    let slowRequestRate: Double
    let slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double]
    let overTargetBudgetRate: Double
    let fallbackActivations: Int
    let admissionSkipCount: Int
    let contextAwareTraceCount: Int
    let lifecycleRebuildCount: Int
    let staleFieldDropCount: Int
    let neuralTraceCount: Int
    let suppressedBehaviorCount: Int
    let traceCount: Int
    let replayCount: Int
    let totalCacheEntries: Int
    let dominantGemmaBackend: InferenceBackendKind?
}
