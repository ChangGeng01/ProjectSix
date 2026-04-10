import Foundation
import BASAppleAdapters
import BASObservability

typealias DecisionIntelligenceRequestOutcome = BASRequestOutcome
typealias DecisionRequestLifecycleMetrics = BASRequestLifecycleMetrics

struct DecisionIntelligenceTelemetrySnapshot: Equatable, Sendable {
    private let substrateSnapshot: BASAppleTelemetryAccumulatorSnapshot

    init(substrateSnapshot: BASAppleTelemetryAccumulatorSnapshot) {
        self.substrateSnapshot = substrateSnapshot
    }

    var requestCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.requestCountByKind)
    }

    var outcomeCount: [DecisionIntelligenceRequestOutcome: Int] {
        substrateSnapshot.outcomeCount
    }

    var outcomeCountByKind: [DecisionIntelligenceRequestOutcome: [DecisionIntelligenceTraceKind: Int]] {
        substrateSnapshot.outcomeCountByKind.mapValues(mapKindDictionary)
    }

    var activeProviderCount: [DecisionModelProviderKind: Int] {
        mapProviderDictionary(substrateSnapshot.activeProviderCount)
    }

    var attemptedProviderCount: [DecisionModelProviderKind: Int] {
        mapProviderDictionary(substrateSnapshot.attemptedProviderCount)
    }

    var fallbackActivations: Int {
        substrateSnapshot.fallbackActivations
    }

    var gemmaBackendCount: [InferenceBackendKind: Int] {
        mapBackendDictionary(substrateSnapshot.backendCount)
    }

    var slowRequestCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.slowRequestCountByKind)
    }

    var overTimeBudgetCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.overTimeBudgetCountByKind)
    }

    var requestDurationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.requestDurationTotalMsByKind)
    }

    var firstPresentableTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.firstPresentableTotalMsByKind)
    }

    var promptAssemblyTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.promptAssemblyTotalMsByKind)
    }

    var admissionEvaluationTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.admissionEvaluationTotalMsByKind)
    }

    var providerSelectionTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.providerSelectionTotalMsByKind)
    }

    var executionTotalMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSnapshot.executionTotalMsByKind)
    }

    var activeProviderDurationTotalMs: [DecisionModelProviderKind: Double] {
        mapProviderDictionary(substrateSnapshot.activeProviderDurationTotalMs)
    }

    var gemmaBackendDurationTotalMs: [InferenceBackendKind: Double] {
        mapBackendDictionary(substrateSnapshot.backendDurationTotalMs)
    }

    var admissionSkipCountByReason: [DecisionIntelligenceAdmissionSkipReason: Int] {
        mapSkipReasonDictionary(substrateSnapshot.admissionSkipCountByReason)
    }

    var admissionSkipCountByReasonAndKind: [DecisionIntelligenceAdmissionSkipReason: [DecisionIntelligenceTraceKind: Int]] {
        substrateSnapshot.admissionSkipCountByReasonAndKind.reduce(into: [:]) { partialResult, item in
            guard let reason = DecisionIntelligenceAdmissionSkipReason(rawValue: item.key) else { return }
            partialResult[reason] = mapKindDictionary(item.value)
        }
    }

    var reminderSelectionNeedCount: [ReminderSelectionNeed: Int] {
        mapReminderNeedDictionary(substrateSnapshot.reminderSelectionNeedCount)
    }

    var reminderSelectionNeedCountByKind: [ReminderSelectionNeed: [DecisionIntelligenceTraceKind: Int]] {
        substrateSnapshot.reminderSelectionNeedCountByKind.reduce(into: [:]) { partialResult, item in
            guard let need = ReminderSelectionNeed(rawValue: item.key) else { return }
            partialResult[need] = mapKindDictionary(item.value)
        }
    }

    var promptPressureCount: [DecisionIntelligencePromptPressure: Int] {
        mapPromptPressureDictionary(substrateSnapshot.promptPressureCount)
    }

    var promptCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.promptCharactersTotalByKind)
    }

    var prefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.prefixCharactersTotalByKind)
    }

    var immutablePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.immutablePrefixCharactersTotalByKind)
    }

    var adaptivePrefixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.adaptivePrefixCharactersTotalByKind)
    }

    var suffixCharactersTotalByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.suffixCharactersTotalByKind)
    }

    var overTargetBudgetCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.overTargetBudgetCountByKind)
    }

    var lowPressureModelCallCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSnapshot.lowPressureModelCallCountByKind)
    }

    var totalRequests: Int {
        substrateSummary.totalRequests
    }

    var totalProviderAttempts: Int {
        substrateSummary.totalProviderAttempts
    }

    var cacheHitRate: Double {
        substrateSummary.cacheHitRate
    }

    var admissionSkipRate: Double {
        substrateSummary.admissionSkipRate
    }

    var providerBypassRate: Double {
        substrateSummary.providerBypassRate
    }

    var deterministicFallbackRate: Double {
        substrateSummary.deterministicFallbackRate
    }

    var averageRequestDurationMs: Double {
        substrateSummary.averageRequestDurationMs
    }

    var averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageRequestDurationMsByKind)
    }

    var averageFirstPresentableMs: Double {
        substrateSummary.averageFirstPresentableMs
    }

    var averageFirstPresentableMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageFirstPresentableMsByKind)
    }

    var averagePromptAssemblyMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averagePromptAssemblyMsByKind)
    }

    var averageAdmissionEvaluationMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageAdmissionEvaluationMsByKind)
    }

    var averageProviderSelectionMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageProviderSelectionMsByKind)
    }

    var averageExecutionMsByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageExecutionMsByKind)
    }

    var averagePrefillEquivalentShareByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averagePrefillEquivalentShareByKind)
    }

    var averageRequestDurationMsByActiveProvider: [DecisionModelProviderKind: Double] {
        mapProviderDictionary(substrateSummary.averageRequestDurationMsByActiveProvider)
    }

    var averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double] {
        mapBackendDictionary(substrateSummary.averageRequestDurationMsByBackend)
    }

    var averagePromptCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averagePromptCharactersByKind)
    }

    var averagePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averagePrefixCharactersByKind)
    }

    var averageImmutablePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageImmutablePrefixCharactersByKind)
    }

    var averageAdaptivePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageAdaptivePrefixCharactersByKind)
    }

    var averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageSuffixCharactersByKind)
    }

    var averageStablePrefixShareByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.averageStablePrefixShareByKind)
    }

    var providerBypassRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.providerBypassRateByKind)
    }

    var lowPressureModelCallRate: Double {
        substrateSummary.lowPressureModelCallRate
    }

    var lowPressureModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.lowPressureModelCallRateByKind)
    }

    var avoidableModelCallRate: Double {
        substrateSummary.avoidableModelCallRate
    }

    var avoidableModelCallRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.avoidableModelCallRateByKind)
    }

    var avoidableModelCallCount: Int {
        substrateSummary.avoidableModelCallCount
    }

    var providerBypassCount: Int {
        substrateSummary.providerBypassCount
    }

    private var providerBypassCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSummary.providerBypassCountByKind)
    }

    private var avoidableModelCallCountByKind: [DecisionIntelligenceTraceKind: Int] {
        mapKindDictionary(substrateSummary.avoidableModelCallCountByKind)
    }

    var overTargetBudgetRate: Double {
        substrateSummary.overTargetBudgetRate
    }

    var overTargetBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.overTargetBudgetRateByKind)
    }

    var reminderKnowledgeNeedRate: Double {
        substrateSummary.reminderKnowledgeNeedRate
    }

    var reminderControlOnlyRate: Double {
        substrateSummary.reminderControlOnlyRate
    }

    var reminderRetrievalBypassRate: Double {
        substrateSummary.reminderRetrievalBypassRate
    }

    var reminderRetrievalBypassCount: Int {
        substrateSummary.reminderRetrievalBypassCount
    }

    var slowRequestRate: Double {
        substrateSummary.slowRequestRate
    }

    var slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.slowRequestRateByKind)
    }

    var overTimeBudgetRate: Double {
        substrateSummary.overTimeBudgetRate
    }

    var overTimeBudgetRateByKind: [DecisionIntelligenceTraceKind: Double] {
        mapKindDictionary(substrateSummary.overTimeBudgetRateByKind)
    }

    var substrateSummary: BASTelemetrySummary {
        substrateSnapshot.summary
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

    private func mapSkipReasonDictionary<Value>(
        _ values: [String: Value]
    ) -> [DecisionIntelligenceAdmissionSkipReason: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let reason = DecisionIntelligenceAdmissionSkipReason(rawValue: item.key) else { return }
            partialResult[reason] = item.value
        }
    }

    private func mapReminderNeedDictionary<Value>(
        _ values: [String: Value]
    ) -> [ReminderSelectionNeed: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let need = ReminderSelectionNeed(rawValue: item.key) else { return }
            partialResult[need] = item.value
        }
    }

    private func mapPromptPressureDictionary<Value>(
        _ values: [String: Value]
    ) -> [DecisionIntelligencePromptPressure: Value] {
        values.reduce(into: [:]) { partialResult, item in
            guard let pressure = DecisionIntelligencePromptPressure(rawValue: item.key) else { return }
            partialResult[pressure] = item.value
        }
    }
}

actor DecisionIntelligenceTelemetryStore {
    static let shared = DecisionIntelligenceTelemetryStore()

    private let accumulator = BASAppleTelemetryAccumulator(
        config: BASAppleTelemetryAccumulatorConfig(
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
    ) async {
        await accumulator.record(
            from: BASAppleTelemetryRecordInput(
                kind: kind.rawValue,
                outcome: outcome,
                activeProviderID: activeProvider?.rawValue,
                attemptedProviderIDs: attemptedProviders.map(\.rawValue),
                usedFallback: usedFallback,
                durationMs: durationMs,
                lifecycleMetrics: lifecycleMetrics,
                promptBudget: promptBudget,
                runtimeTimeBudgetMs: runtimeStrategy?.timeBudgetMs,
                admissionPressureID: admissionDecision?.pressure.rawValue,
                admissionSkipReasonID: admissionDecision?.skipReason?.rawValue,
                reminderSelectionNeedID: admissionDecision?.reminderSelectionNeed?.rawValue,
                activeBackendID: gemmaBackendResolution?.effectiveBackend.rawValue
            )
        )
    }

    func record(
        observation: BASAppleProviderTelemetryObservation
    ) async {
        await accumulator.record(from: observation.input)
    }

    func snapshot() async -> DecisionIntelligenceTelemetrySnapshot {
        DecisionIntelligenceTelemetrySnapshot(substrateSnapshot: await accumulator.snapshot())
    }

    func clear() async {
        await accumulator.clear()
    }
}
