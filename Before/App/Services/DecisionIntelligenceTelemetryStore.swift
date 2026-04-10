import Foundation
import BASObservability

typealias DecisionIntelligenceRequestOutcome = BASRequestOutcome
typealias DecisionRequestLifecycleMetrics = BASRequestLifecycleMetrics

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
    let firstPresentableTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let promptAssemblyTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let admissionEvaluationTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let providerSelectionTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
    let executionTotalMsByKind: [DecisionIntelligenceTraceKind: Double]
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
        basSummary.totalRequests
    }

    var totalProviderAttempts: Int {
        basSummary.totalProviderAttempts
    }

    var cacheHitRate: Double {
        basSummary.cacheHitRate
    }

    var admissionSkipRate: Double {
        basSummary.admissionSkipRate
    }

    var providerBypassRate: Double {
        basSummary.providerBypassRate
    }

    var deterministicFallbackRate: Double {
        basSummary.deterministicFallbackRate
    }

    var averageRequestDurationMs: Double {
        basSummary.averageRequestDurationMs
    }

    var averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageRequestDurationMsByKind)
    }

    var averageFirstPresentableMs: Double {
        basSummary.averageFirstPresentableMs
    }

    var averageFirstPresentableMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageFirstPresentableMsByKind)
    }

    var averagePromptAssemblyMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averagePromptAssemblyMsByKind)
    }

    var averageAdmissionEvaluationMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageAdmissionEvaluationMsByKind)
    }

    var averageProviderSelectionMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageProviderSelectionMsByKind)
    }

    var averageExecutionMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageExecutionMsByKind)
    }

    var averagePrefillEquivalentShareByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averagePrefillEquivalentShareByKind)
    }

    var averageRequestDurationMsByActiveProvider: [DecisionModelProviderKind: Double] {
        mapProviderDictionary(basSummary.averageRequestDurationMsByActiveProvider)
    }

    var averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double] {
        mapBackendDictionary(basSummary.averageRequestDurationMsByBackend)
    }

    var averagePromptCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averagePromptCharactersByKind)
    }

    var averagePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averagePrefixCharactersByKind)
    }

    var averageImmutablePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageImmutablePrefixCharactersByKind)
    }

    var averageAdaptivePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageAdaptivePrefixCharactersByKind)
    }

    var averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageSuffixCharactersByKind)
    }

    var averageStablePrefixShareByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.averageStablePrefixShareByKind)
    }

    var providerBypassRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.providerBypassRateByKind)
    }

    var lowPressureModelCallRate: Double {
        basSummary.lowPressureModelCallRate
    }

    var lowPressureModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.lowPressureModelCallRateByKind)
    }

    var avoidableModelCallRate: Double {
        basSummary.avoidableModelCallRate
    }

    var avoidableModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.avoidableModelCallRateByKind)
    }

    var avoidableModelCallCount: Int {
        basSummary.avoidableModelCallCount
    }

    var providerBypassCount: Int {
        basSummary.providerBypassCount
    }

    private var providerBypassCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(basSummary.providerBypassCountByKind)
    }

    private var avoidableModelCallCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(basSummary.avoidableModelCallCountByKind)
    }

    var overTargetBudgetRate: Double {
        basSummary.overTargetBudgetRate
    }

    var overTargetBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.overTargetBudgetRateByKind)
    }

    var reminderKnowledgeNeedRate: Double {
        basSummary.reminderKnowledgeNeedRate
    }

    var reminderControlOnlyRate: Double {
        basSummary.reminderControlOnlyRate
    }

    var reminderRetrievalBypassRate: Double {
        basSummary.reminderRetrievalBypassRate
    }

    var reminderRetrievalBypassCount: Int {
        basSummary.reminderRetrievalBypassCount
    }

    var slowRequestRate: Double {
        basSummary.slowRequestRate
    }

    var slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.slowRequestRateByKind)
    }

    var overTimeBudgetRate: Double {
        basSummary.overTimeBudgetRate
    }

    var overTimeBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(basSummary.overTimeBudgetRateByKind)
    }

    var substrateSummary: BASTelemetrySummary {
        basSummary
    }

    private var basSummary: BASTelemetrySummary {
        BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: rawKeyDictionary(requestCountByKind),
                outcomeCount: outcomeCount,
                outcomeCountByKind: outcomeCountByKind.mapValues { rawKeyDictionary($0) },
                activeProviderCount: rawKeyDictionary(activeProviderCount),
                attemptedProviderCount: rawKeyDictionary(attemptedProviderCount),
                fallbackActivations: fallbackActivations,
                backendCount: rawKeyDictionary(gemmaBackendCount),
                slowRequestCountByKind: rawKeyDictionary(slowRequestCountByKind),
                overTimeBudgetCountByKind: rawKeyDictionary(overTimeBudgetCountByKind),
                requestDurationTotalMsByKind: rawKeyDictionary(requestDurationTotalMsByKind),
                firstPresentableTotalMsByKind: rawKeyDictionary(firstPresentableTotalMsByKind),
                promptAssemblyTotalMsByKind: rawKeyDictionary(promptAssemblyTotalMsByKind),
                admissionEvaluationTotalMsByKind: rawKeyDictionary(admissionEvaluationTotalMsByKind),
                providerSelectionTotalMsByKind: rawKeyDictionary(providerSelectionTotalMsByKind),
                executionTotalMsByKind: rawKeyDictionary(executionTotalMsByKind),
                activeProviderDurationTotalMs: rawKeyDictionary(activeProviderDurationTotalMs),
                backendDurationTotalMs: rawKeyDictionary(gemmaBackendDurationTotalMs),
                admissionSkipCountByReason: rawKeyDictionary(admissionSkipCountByReason),
                admissionSkipCountByReasonAndKind: admissionSkipCountByReasonAndKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = rawKeyDictionary(item.value)
                },
                reminderSelectionNeedCount: rawKeyDictionary(reminderSelectionNeedCount),
                promptCharactersTotalByKind: rawKeyDictionary(promptCharactersTotalByKind),
                prefixCharactersTotalByKind: rawKeyDictionary(prefixCharactersTotalByKind),
                immutablePrefixCharactersTotalByKind: rawKeyDictionary(immutablePrefixCharactersTotalByKind),
                adaptivePrefixCharactersTotalByKind: rawKeyDictionary(adaptivePrefixCharactersTotalByKind),
                suffixCharactersTotalByKind: rawKeyDictionary(suffixCharactersTotalByKind),
                overTargetBudgetCountByKind: rawKeyDictionary(overTargetBudgetCountByKind),
                lowPressureModelCallCountByKind: rawKeyDictionary(lowPressureModelCallCountByKind),
                reminderKindRawValue: DecisionIntelligenceTraceKind.reminder.rawValue,
                reminderKnowledgeNeedRawValue: ReminderSelectionNeed.knowledge.rawValue,
                reminderControlNeedRawValue: ReminderSelectionNeed.control.rawValue,
                reminderRetrievalBypassReasonRawValues: [
                    DecisionIntelligenceAdmissionSkipReason.insufficientReminderChoice.rawValue,
                    DecisionIntelligenceAdmissionSkipReason.retrievalNotNeeded.rawValue
                ],
                avoidableSkipReasonRawValues: [
                    DecisionIntelligenceAdmissionSkipReason.templateAlreadySufficient.rawValue,
                    DecisionIntelligenceAdmissionSkipReason.insufficientSourceMaterial.rawValue
                ]
            )
        )
    }

    private func mapKindDictionary<Value>(
        _ values: [String: Value]
    ) -> [DecisionIntelligenceTraceKind: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let kind = DecisionIntelligenceTraceKind(rawValue: item.key) else { return }
            partialResult[kind] = item.value
        }
    }

    private func mapProviderDictionary<Value>(
        _ values: [String: Value]
    ) -> [DecisionModelProviderKind: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let provider = DecisionModelProviderKind(rawValue: item.key) else { return }
            partialResult[provider] = item.value
        }
    }

    private func mapBackendDictionary<Value>(
        _ values: [String: Value]
    ) -> [InferenceBackendKind: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let backend = InferenceBackendKind(rawValue: item.key) else { return }
            partialResult[backend] = item.value
        }
    }

    private func rawKeyDictionary<Key: RawRepresentable, Value>(
        _ values: [Key: Value]
    ) -> [String: Value] where Key.RawValue == String {
        values.reduce(into: [:]) { partialResult, item in
            partialResult[item.key.rawValue] = item.value
        }
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
    private var firstPresentableTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var promptAssemblyTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var admissionEvaluationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var providerSelectionTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
    private var executionTotalMsByKind: [DecisionIntelligenceTraceKind: Double] = [:]
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
        lifecycleMetrics: DecisionRequestLifecycleMetrics? = nil,
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
        if let lifecycleMetrics {
            firstPresentableTotalMsByKind[kind, default: 0] += lifecycleMetrics.firstPresentableMs
            promptAssemblyTotalMsByKind[kind, default: 0] += lifecycleMetrics.promptAssemblyMs
            admissionEvaluationTotalMsByKind[kind, default: 0] += lifecycleMetrics.admissionEvaluationMs
            providerSelectionTotalMsByKind[kind, default: 0] += lifecycleMetrics.providerSelectionMs
            executionTotalMsByKind[kind, default: 0] += lifecycleMetrics.executionMs
        }
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
            firstPresentableTotalMsByKind: firstPresentableTotalMsByKind,
            promptAssemblyTotalMsByKind: promptAssemblyTotalMsByKind,
            admissionEvaluationTotalMsByKind: admissionEvaluationTotalMsByKind,
            providerSelectionTotalMsByKind: providerSelectionTotalMsByKind,
            executionTotalMsByKind: executionTotalMsByKind,
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
        firstPresentableTotalMsByKind.removeAll()
        promptAssemblyTotalMsByKind.removeAll()
        admissionEvaluationTotalMsByKind.removeAll()
        providerSelectionTotalMsByKind.removeAll()
        executionTotalMsByKind.removeAll()
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
