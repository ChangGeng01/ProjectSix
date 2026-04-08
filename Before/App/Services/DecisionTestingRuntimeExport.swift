import Foundation

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
    let recentTraces: [DecisionIntelligenceTrace]
    let recentReplay: [DeveloperDecisionReplayEntry]

    var summary: DecisionTestingRuntimeSummary {
        DecisionTestingRuntimeSummary(
            activeProvider: runtimeSnapshot.runtimeStatus.active,
            fallbackProvider: runtimeSnapshot.runtimeStatus.fallback,
            totalRequests: intelligenceTelemetry.totalRequests,
            totalProviderAttempts: intelligenceTelemetry.totalProviderAttempts,
            cacheHitRate: intelligenceTelemetry.cacheHitRate,
            deterministicFallbackRate: intelligenceTelemetry.deterministicFallbackRate,
            averageRequestDurationMs: intelligenceTelemetry.averageRequestDurationMs,
            averageRequestDurationMsByKind: intelligenceTelemetry.averageRequestDurationMsByKind,
            averageRequestDurationMsByProvider: intelligenceTelemetry.averageRequestDurationMsByActiveProvider,
            averageRequestDurationMsByGemmaBackend: intelligenceTelemetry.averageRequestDurationMsByGemmaBackend,
            slowRequestRate: intelligenceTelemetry.slowRequestRate,
            slowRequestRateByKind: intelligenceTelemetry.slowRequestRateByKind,
            fallbackActivations: intelligenceTelemetry.fallbackActivations,
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
}

struct DecisionTestingRuntimeSummary: Equatable, Sendable {
    let activeProvider: DecisionModelProviderKind
    let fallbackProvider: DecisionModelProviderKind?
    let totalRequests: Int
    let totalProviderAttempts: Int
    let cacheHitRate: Double
    let deterministicFallbackRate: Double
    let averageRequestDurationMs: Double
    let averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageRequestDurationMsByProvider: [DecisionModelProviderKind: Double]
    let averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double]
    let slowRequestRate: Double
    let slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double]
    let fallbackActivations: Int
    let traceCount: Int
    let replayCount: Int
    let totalCacheEntries: Int
    let dominantGemmaBackend: InferenceBackendKind?
}
