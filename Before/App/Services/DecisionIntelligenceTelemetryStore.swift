import Foundation

enum DecisionIntelligenceRequestOutcome: String, CaseIterable, Sendable {
    case templatePinned
    case cacheHit
    case providerSuccess
    case deterministicFallback
}

struct DecisionIntelligenceTelemetrySnapshot: Equatable, Sendable {
    let requestCountByKind: [DecisionIntelligenceTraceKind: Int]
    let outcomeCount: [DecisionIntelligenceRequestOutcome: Int]
    let activeProviderCount: [DecisionModelProviderKind: Int]
    let attemptedProviderCount: [DecisionModelProviderKind: Int]
    let fallbackActivations: Int
    let gemmaBackendCount: [InferenceBackendKind: Int]
    let requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let activeProviderDurationTotalMs: [DecisionModelProviderKind: Double]
    let gemmaBackendDurationTotalMs: [InferenceBackendKind: Double]

    var totalRequests: Int {
        requestCountByKind.values.reduce(0, +)
    }

    var totalProviderAttempts: Int {
        attemptedProviderCount.values.reduce(0, +)
    }

    var cacheHitRate: Double {
        rate(
            numerator: outcomeCount[.cacheHit] ?? 0,
            denominator: totalRequests
        )
    }

    var deterministicFallbackRate: Double {
        rate(
            numerator: outcomeCount[.deterministicFallback] ?? 0,
            denominator: totalRequests
        )
    }

    var averageRequestDurationMs: Double {
        average(
            totals: requestDurationTotalMsByKind.values.reduce(0, +),
            count: totalRequests
        )
    }

    var averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestDurationTotalMsByKind.map { kind, total in
                (kind, average(totals: total, count: requestCountByKind[kind] ?? 0))
            }
        )
    }

    var averageRequestDurationMsByActiveProvider: [DecisionModelProviderKind: Double] {
        Dictionary(
            uniqueKeysWithValues: activeProviderDurationTotalMs.map { provider, total in
                (provider, average(totals: total, count: activeProviderCount[provider] ?? 0))
            }
        )
    }

    var averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double] {
        Dictionary(
            uniqueKeysWithValues: gemmaBackendDurationTotalMs.map { backend, total in
                (backend, average(totals: total, count: gemmaBackendCount[backend] ?? 0))
            }
        )
    }

    private func rate(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private func average(totals: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return totals / Double(count)
    }
}

actor DecisionIntelligenceTelemetryStore {
    static let shared = DecisionIntelligenceTelemetryStore()

    private var requestCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var outcomeCount: [DecisionIntelligenceRequestOutcome: Int] = [:]
    private var activeProviderCount: [DecisionModelProviderKind: Int] = [:]
    private var attemptedProviderCount: [DecisionModelProviderKind: Int] = [:]
    private var fallbackActivations = 0
    private var gemmaBackendCount: [InferenceBackendKind: Int] = [:]
    private var requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var activeProviderDurationTotalMs: [DecisionModelProviderKind: Double] = [:]
    private var gemmaBackendDurationTotalMs: [InferenceBackendKind: Double] = [:]

    func record(
        kind: DecisionIntelligenceTraceKind,
        outcome: DecisionIntelligenceRequestOutcome,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        usedFallback: Bool,
        durationMs: Double,
        gemmaBackendResolution: InferenceBackendResolution? = nil
    ) {
        requestCountByKind[kind, default: 0] += 1
        outcomeCount[outcome, default: 0] += 1
        requestDurationTotalMsByKind[kind, default: 0] += durationMs

        for provider in attemptedProviders {
            attemptedProviderCount[provider, default: 0] += 1
        }

        if let activeProvider {
            activeProviderCount[activeProvider, default: 0] += 1
            activeProviderDurationTotalMs[activeProvider, default: 0] += durationMs
        }

        if usedFallback {
            fallbackActivations += 1
        }

        if let gemmaBackendResolution {
            gemmaBackendCount[gemmaBackendResolution.effectiveBackend, default: 0] += 1
            gemmaBackendDurationTotalMs[gemmaBackendResolution.effectiveBackend, default: 0] += durationMs
        }
    }

    func snapshot() -> DecisionIntelligenceTelemetrySnapshot {
        DecisionIntelligenceTelemetrySnapshot(
            requestCountByKind: requestCountByKind,
            outcomeCount: outcomeCount,
            activeProviderCount: activeProviderCount,
            attemptedProviderCount: attemptedProviderCount,
            fallbackActivations: fallbackActivations,
            gemmaBackendCount: gemmaBackendCount,
            requestDurationTotalMsByKind: requestDurationTotalMsByKind,
            activeProviderDurationTotalMs: activeProviderDurationTotalMs,
            gemmaBackendDurationTotalMs: gemmaBackendDurationTotalMs
        )
    }

    func clear() {
        requestCountByKind.removeAll()
        outcomeCount.removeAll()
        activeProviderCount.removeAll()
        attemptedProviderCount.removeAll()
        fallbackActivations = 0
        gemmaBackendCount.removeAll()
        requestDurationTotalMsByKind.removeAll()
        activeProviderDurationTotalMs.removeAll()
        gemmaBackendDurationTotalMs.removeAll()
    }
}
