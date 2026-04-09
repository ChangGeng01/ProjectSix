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
    let outcomeCountByKind: [DecisionIntelligenceRequestOutcome: [DecisionIntelligenceTraceKind: Int]]
    let activeProviderCount: [DecisionModelProviderKind: Int]
    let attemptedProviderCount: [DecisionModelProviderKind: Int]
    let fallbackActivations: Int
    let gemmaBackendCount: [InferenceBackendKind: Int]
    let slowRequestCountByKind: [DecisionIntelligenceTraceKind: Int]
    let overTimeBudgetCountByKind: [DecisionIntelligenceTraceKind: Int]
    let requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let activeProviderDurationTotalMs: [DecisionModelProviderKind: Double]
    let gemmaBackendDurationTotalMs: [InferenceBackendKind: Double]
    let admissionSkipCountByReason: [DecisionIntelligenceAdmissionSkipReason: Int]
    let admissionSkipCountByReasonAndKind: [DecisionIntelligenceAdmissionSkipReason: [DecisionIntelligenceTraceKind: Int]]
    let reminderSelectionNeedCount: [ReminderSelectionNeed: Int]
    let reminderSelectionNeedCountByKind: [ReminderSelectionNeed: [DecisionIntelligenceTraceKind: Int]]
    let promptPressureCount: [DecisionIntelligencePromptPressure: Int]
    let promptCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let prefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let immutablePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let adaptivePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let suffixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int]
    let overTargetBudgetCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowPressureModelCallCountByKind: [DecisionIntelligenceTraceKind: Int]

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

    var providerBypassRate: Double {
        rate(
            numerator: providerBypassCount,
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

    var averageImmutablePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: immutablePrefixCharactersTotalByKind)
    }

    var averageAdaptivePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: adaptivePrefixCharactersTotalByKind)
    }

    var averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        averageCharactersByKind(from: suffixCharactersTotalByKind)
    }

    var averageStablePrefixShareByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                let totalPrompt = promptCharactersTotalByKind[kind] ?? 0
                let totalPrefix = prefixCharactersTotalByKind[kind] ?? 0
                let ratio = totalPrompt > 0 ? Double(totalPrefix) / Double(totalPrompt) : 0
                return (kind, count > 0 ? ratio : 0)
            }
        )
    }

    var providerBypassRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                let bypass = providerBypassCountByKind[kind] ?? 0
                return (kind, rate(numerator: bypass, denominator: count))
            }
        )
    }

    var lowPressureModelCallRate: Double {
        rate(
            numerator: lowPressureModelCallCountByKind.values.reduce(0, +),
            denominator: totalRequests
        )
    }

    var lowPressureModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                let lowPressureCalls = lowPressureModelCallCountByKind[kind] ?? 0
                return (kind, rate(numerator: lowPressureCalls, denominator: count))
            }
        )
    }

    var avoidableModelCallRate: Double {
        rate(
            numerator: avoidableModelCallCount,
            denominator: totalRequests
        )
    }

    var avoidableModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                let avoidableSkips = avoidableModelCallCountByKind[kind] ?? 0
                return (kind, rate(numerator: avoidableSkips, denominator: count))
            }
        )
    }

    var avoidableModelCallCount: Int {
        avoidableModelCallCountByKind.values.reduce(0, +)
    }

    var providerBypassCount: Int {
        providerBypassCountByKind.values.reduce(0, +)
    }

    private var providerBypassCountByKind: [DecisionIntelligenceTraceKind: Int] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.keys.map { kind in
                let templatePinned = outcomeCountForKind(.templatePinned, kind: kind)
                let admissionSkipped = outcomeCountForKind(.admissionSkipped, kind: kind)
                let cacheHit = outcomeCountForKind(.cacheHit, kind: kind)
                return (kind, templatePinned + admissionSkipped + cacheHit)
            }
        )
    }

    private var avoidableModelCallCountByKind: [DecisionIntelligenceTraceKind: Int] {
        let trackedReasons: [DecisionIntelligenceAdmissionSkipReason] = [
            .templateAlreadySufficient,
            .insufficientSourceMaterial
        ]

        return Dictionary(
            uniqueKeysWithValues: requestCountByKind.keys.map { kind in
                let count = trackedReasons.reduce(0) { partialResult, reason in
                    partialResult + (admissionSkipCountByReasonAndKind[reason]?[kind] ?? 0)
                }
                return (kind, count)
            }
        )
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

    var reminderKnowledgeNeedRate: Double {
        rate(
            numerator: reminderSelectionNeedCount[.knowledge] ?? 0,
            denominator: requestCountByKind[.reminder] ?? 0
        )
    }

    var reminderControlOnlyRate: Double {
        rate(
            numerator: reminderSelectionNeedCount[.control] ?? 0,
            denominator: requestCountByKind[.reminder] ?? 0
        )
    }

    var reminderRetrievalBypassRate: Double {
        rate(
            numerator: reminderRetrievalBypassCount,
            denominator: requestCountByKind[.reminder] ?? 0
        )
    }

    var reminderRetrievalBypassCount: Int {
        (admissionSkipCountByReason[.insufficientReminderChoice] ?? 0)
            + (admissionSkipCountByReason[.retrievalNotNeeded] ?? 0)
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

    var overTimeBudgetRate: Double {
        rate(
            numerator: overTimeBudgetCountByKind.values.reduce(0, +),
            denominator: totalRequests
        )
    }

    var overTimeBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        Dictionary(
            uniqueKeysWithValues: requestCountByKind.map { kind, count in
                (kind, rate(numerator: overTimeBudgetCountByKind[kind] ?? 0, denominator: count))
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

    private func outcomeCountForKind(
        _ outcome: DecisionIntelligenceRequestOutcome,
        kind: DecisionIntelligenceTraceKind
    ) -> Int {
        outcomeCountByKind[outcome]?[kind] ?? 0
    }
}

actor DecisionIntelligenceTelemetryStore {
    static let shared = DecisionIntelligenceTelemetryStore()

    private var requestCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var outcomeCount: [DecisionIntelligenceRequestOutcome: Int] = [:]
    private var outcomeCountByKind: [DecisionIntelligenceRequestOutcome: [DecisionIntelligenceTraceKind: Int]] = [:]
    private var activeProviderCount: [DecisionModelProviderKind: Int] = [:]
    private var attemptedProviderCount: [DecisionModelProviderKind: Int] = [:]
    private var fallbackActivations = 0
    private var gemmaBackendCount: [InferenceBackendKind: Int] = [:]
    private var slowRequestCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var overTimeBudgetCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var activeProviderDurationTotalMs: [DecisionModelProviderKind: Double] = [:]
    private var gemmaBackendDurationTotalMs: [InferenceBackendKind: Double] = [:]
    private var admissionSkipCountByReason: [DecisionIntelligenceAdmissionSkipReason: Int] = [:]
    private var admissionSkipCountByReasonAndKind: [DecisionIntelligenceAdmissionSkipReason: [DecisionIntelligenceTraceKind: Int]] = [:]
    private var reminderSelectionNeedCount: [ReminderSelectionNeed: Int] = [:]
    private var reminderSelectionNeedCountByKind: [ReminderSelectionNeed: [DecisionIntelligenceTraceKind: Int]] = [:]
    private var promptPressureCount: [DecisionIntelligencePromptPressure: Int] = [:]
    private var promptCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var prefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var immutablePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var adaptivePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var suffixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var overTargetBudgetCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var lowPressureModelCallCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]

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
        runtimeStrategy: DecisionAdaptiveTaskStrategy? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil,
        gemmaBackendResolution: InferenceBackendResolution? = nil
    ) {
        requestCountByKind[kind, default: 0] += 1
        outcomeCount[outcome, default: 0] += 1
        var countsForOutcome = outcomeCountByKind[outcome, default: [:]]
        countsForOutcome[kind, default: 0] += 1
        outcomeCountByKind[outcome] = countsForOutcome
        requestDurationTotalMsByKind[kind, default: 0] += durationMs
        if durationMs >= Self.slowRequestThresholdMs(for: kind) {
            slowRequestCountByKind[kind, default: 0] += 1
        }
        if let runtimeStrategy, durationMs > Double(runtimeStrategy.timeBudgetMs) {
            overTimeBudgetCountByKind[kind, default: 0] += 1
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
            immutablePrefixCharactersTotalByKind[kind, default: 0] += promptBudget.immutablePrefixCharacters
            adaptivePrefixCharactersTotalByKind[kind, default: 0] += promptBudget.adaptivePrefixCharacters
            suffixCharactersTotalByKind[kind, default: 0] += promptBudget.suffixCharacters
            if !promptBudget.isWithinTarget {
                overTargetBudgetCountByKind[kind, default: 0] += 1
            }
        }

        if let admissionDecision {
            promptPressureCount[admissionDecision.pressure, default: 0] += 1
            if outcome == .providerSuccess, admissionDecision.pressure == .low {
                lowPressureModelCallCountByKind[kind, default: 0] += 1
            }
            if let reminderSelectionNeed = admissionDecision.reminderSelectionNeed {
                reminderSelectionNeedCount[reminderSelectionNeed, default: 0] += 1
                var countsForNeed = reminderSelectionNeedCountByKind[reminderSelectionNeed, default: [:]]
                countsForNeed[kind, default: 0] += 1
                reminderSelectionNeedCountByKind[reminderSelectionNeed] = countsForNeed
            }
            if let skipReason = admissionDecision.skipReason {
                admissionSkipCountByReason[skipReason, default: 0] += 1
                var countsForReason = admissionSkipCountByReasonAndKind[skipReason, default: [:]]
                countsForReason[kind, default: 0] += 1
                admissionSkipCountByReasonAndKind[skipReason] = countsForReason
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
            outcomeCountByKind: outcomeCountByKind,
            activeProviderCount: activeProviderCount,
            attemptedProviderCount: attemptedProviderCount,
            fallbackActivations: fallbackActivations,
            gemmaBackendCount: gemmaBackendCount,
            slowRequestCountByKind: slowRequestCountByKind,
            overTimeBudgetCountByKind: overTimeBudgetCountByKind,
            requestDurationTotalMsByKind: requestDurationTotalMsByKind,
            activeProviderDurationTotalMs: activeProviderDurationTotalMs,
            gemmaBackendDurationTotalMs: gemmaBackendDurationTotalMs,
            admissionSkipCountByReason: admissionSkipCountByReason,
            admissionSkipCountByReasonAndKind: admissionSkipCountByReasonAndKind,
            reminderSelectionNeedCount: reminderSelectionNeedCount,
            reminderSelectionNeedCountByKind: reminderSelectionNeedCountByKind,
            promptPressureCount: promptPressureCount,
            promptCharactersTotalByKind: promptCharactersTotalByKind,
            prefixCharactersTotalByKind: prefixCharactersTotalByKind,
            immutablePrefixCharactersTotalByKind: immutablePrefixCharactersTotalByKind,
            adaptivePrefixCharactersTotalByKind: adaptivePrefixCharactersTotalByKind,
            suffixCharactersTotalByKind: suffixCharactersTotalByKind,
            overTargetBudgetCountByKind: overTargetBudgetCountByKind,
            lowPressureModelCallCountByKind: lowPressureModelCallCountByKind
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
        overTimeBudgetCountByKind.removeAll()
        requestDurationTotalMsByKind.removeAll()
        activeProviderDurationTotalMs.removeAll()
        gemmaBackendDurationTotalMs.removeAll()
        admissionSkipCountByReason.removeAll()
        admissionSkipCountByReasonAndKind.removeAll()
        reminderSelectionNeedCount.removeAll()
        reminderSelectionNeedCountByKind.removeAll()
        promptPressureCount.removeAll()
        promptCharactersTotalByKind.removeAll()
        prefixCharactersTotalByKind.removeAll()
        immutablePrefixCharactersTotalByKind.removeAll()
        adaptivePrefixCharactersTotalByKind.removeAll()
        suffixCharactersTotalByKind.removeAll()
        overTargetBudgetCountByKind.removeAll()
        lowPressureModelCallCountByKind.removeAll()
        outcomeCountByKind.removeAll()
    }
}
