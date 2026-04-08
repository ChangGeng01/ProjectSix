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

    private func rate(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
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

    func record(
        kind: DecisionIntelligenceTraceKind,
        outcome: DecisionIntelligenceRequestOutcome,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        usedFallback: Bool,
        gemmaBackendResolution: InferenceBackendResolution? = nil
    ) {
        requestCountByKind[kind, default: 0] += 1
        outcomeCount[outcome, default: 0] += 1

        for provider in attemptedProviders {
            attemptedProviderCount[provider, default: 0] += 1
        }

        if let activeProvider {
            activeProviderCount[activeProvider, default: 0] += 1
        }

        if usedFallback {
            fallbackActivations += 1
        }

        if let gemmaBackendResolution {
            gemmaBackendCount[gemmaBackendResolution.effectiveBackend, default: 0] += 1
        }
    }

    func snapshot() -> DecisionIntelligenceTelemetrySnapshot {
        DecisionIntelligenceTelemetrySnapshot(
            requestCountByKind: requestCountByKind,
            outcomeCount: outcomeCount,
            activeProviderCount: activeProviderCount,
            attemptedProviderCount: attemptedProviderCount,
            fallbackActivations: fallbackActivations,
            gemmaBackendCount: gemmaBackendCount
        )
    }

    func clear() {
        requestCountByKind.removeAll()
        outcomeCount.removeAll()
        activeProviderCount.removeAll()
        attemptedProviderCount.removeAll()
        fallbackActivations = 0
        gemmaBackendCount.removeAll()
    }
}
