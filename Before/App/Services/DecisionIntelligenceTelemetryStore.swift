import Foundation

enum DecisionIntelligenceRequestOutcome: String, CaseIterable, Sendable {
    case templatePinned
    case cacheHit
    case providerSuccess
    case admissionSkipped
    case deterministicFallback
}

struct DecisionIntelligenceTelemetrySnapshot: Equatable, Sendable {
    let requestCountByKind: [DecisionIntelligenceTraceKind: Int]
    let outcomeCount: [DecisionIntelligenceRequestOutcome: Int]
    let activeProviderCount: [DecisionModelProviderKind: Int]
    let attemptedProviderCount: [DecisionModelProviderKind: Int]
    let fallbackActivations: Int
    let gemmaBackendCount: [InferenceBackendKind: Int]
    let slowRequestCountByKind: [DecisionIntelligenceTraceKind: Int]
    let requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let activeProviderDurationTotalMs: [DecisionModelProviderKind: Double]
    let gemmaBackendDurationTotalMs: [InferenceBackendKind: Double]
    let admissionSkipCountByReason: [DecisionIntelligenceAdmissionSkipReason: Int]
    let promptPressureCount: [DecisionIntelligencePromptPressure: Int]
    let promptCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let prefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let suffixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let overTargetBudgetCountByKind: [DecisionIntelligenceTraceKind: Int]

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

    var admissionSkipRate: Double {
        rate(
            numerator: outcomeCount[.admissionSkipped] ?? 0,
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

    var averagePromptCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: promptCharactersTotalByKind)
    }

    var averagePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: prefixCharactersTotalByKind)
    }

    var averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: suffixCharactersTotalByKind)
    }

    var overTargetBudgetRate: Double {
        rate(
            numerator: overTargetBudgetCountByKind.values.reduce(0, +),
            denominator: totalRequests
        )
    }

    var overTargetBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                (kind, rate(numerator: overTargetBudgetCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    var slowRequestRate: Double {
        rate(
            numerator: slowRequestCountByKind.values.reduce(0, +),
            denominator: totalRequests
        )
    }

    var slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                (kind, rate(numerator: slowRequestCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    private func averageCharactersByKind(
        from totalsByKind: [DecisionIntelligenceTraceKind: Int]
    ) -> [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: totalsByKind.map { kind, total in
                (kind, average(totals: Double(total), count: requestCountByKind[kind] ?? 0))
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
    private var slowRequestCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var activeProviderDurationTotalMs: [DecisionModelProviderKind: Double] = [:]
    private var gemmaBackendDurationTotalMs: [InferenceBackendKind: Double] = [:]
    private var admissionSkipCountByReason: [DecisionIntelligenceAdmissionSkipReason: Int] = [:]
    private var promptPressureCount: [DecisionIntelligencePromptPressure: Int] = [:]
    private var promptCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var prefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var suffixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var overTargetBudgetCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]

    private static func slowRequestThresholdMs(
        for kind: DecisionIntelligenceTraceKind
    ) -> Double {
        switch kind {
        case .quick:
            return 800
        case .balance, .mirror:
            return 1_500
        case .reminder:
            return 450
        }
    }

    func record(
        kind: DecisionIntelligenceTraceKind,
        outcome: DecisionIntelligenceRequestOutcome,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        usedFallback: Bool,
        durationMs: Double,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil,
        gemmaBackendResolution: InferenceBackendResolution? = nil
    ) {
        requestCountByKind[kind, default: 0] += 1
        outcomeCount[outcome, default: 0] += 1
        requestDurationTotalMsByKind[kind, default: 0] += durationMs
        if durationMs >= Self.slowRequestThresholdMs(for: kind) {
            slowRequestCountByKind[kind, default: 0] += 1
        }

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

        if let promptBudget {
            promptCharactersTotalByKind[kind, default: 0] += promptBudget.totalCharacters
            prefixCharactersTotalByKind[kind, default: 0] += promptBudget.prefixCharacters
            suffixCharactersTotalByKind[kind, default: 0] += promptBudget.suffixCharacters
            if !promptBudget.isWithinTarget {
                overTargetBudgetCountByKind[kind, default: 0] += 1
            }
        }

        if let admissionDecision {
            promptPressureCount[admissionDecision.pressure, default: 0] += 1
            if let skipReason = admissionDecision.skipReason {
                admissionSkipCountByReason[skipReason, default: 0] += 1
            }
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
            slowRequestCountByKind: slowRequestCountByKind,
            requestDurationTotalMsByKind: requestDurationTotalMsByKind,
            activeProviderDurationTotalMs: activeProviderDurationTotalMs,
            gemmaBackendDurationTotalMs: gemmaBackendDurationTotalMs,
            admissionSkipCountByReason: admissionSkipCountByReason,
            promptPressureCount: promptPressureCount,
            promptCharactersTotalByKind: promptCharactersTotalByKind,
            prefixCharactersTotalByKind: prefixCharactersTotalByKind,
            suffixCharactersTotalByKind: suffixCharactersTotalByKind,
            overTargetBudgetCountByKind: overTargetBudgetCountByKind
        )
    }

    func clear() {
        requestCountByKind.removeAll()
        outcomeCount.removeAll()
        activeProviderCount.removeAll()
        attemptedProviderCount.removeAll()
        fallbackActivations = 0
        gemmaBackendCount.removeAll()
        slowRequestCountByKind.removeAll()
        requestDurationTotalMsByKind.removeAll()
        activeProviderDurationTotalMs.removeAll()
        gemmaBackendDurationTotalMs.removeAll()
        admissionSkipCountByReason.removeAll()
        promptPressureCount.removeAll()
        promptCharactersTotalByKind.removeAll()
        prefixCharactersTotalByKind.removeAll()
        suffixCharactersTotalByKind.removeAll()
        overTargetBudgetCountByKind.removeAll()
    }
}
