import Foundation
import BASObservability

public struct BASAppleTelemetryAccumulatorConfig: Codable, Sendable, Equatable {
    public var reminderKindRawValue: String
    public var reminderKnowledgeNeedRawValue: String
    public var reminderControlNeedRawValue: String
    public var reminderRetrievalBypassReasonRawValues: [String]
    public var avoidableSkipReasonRawValues: [String]

    public init(
        reminderKindRawValue: String,
        reminderKnowledgeNeedRawValue: String,
        reminderControlNeedRawValue: String,
        reminderRetrievalBypassReasonRawValues: [String],
        avoidableSkipReasonRawValues: [String]
    ) {
        self.reminderKindRawValue = reminderKindRawValue
        self.reminderKnowledgeNeedRawValue = reminderKnowledgeNeedRawValue
        self.reminderControlNeedRawValue = reminderControlNeedRawValue
        self.reminderRetrievalBypassReasonRawValues = reminderRetrievalBypassReasonRawValues
        self.avoidableSkipReasonRawValues = avoidableSkipReasonRawValues
    }
}

public struct BASAppleTelemetryAccumulatorSnapshot: Codable, Sendable, Equatable {
    public var requestCountByKind: [String: Int]
    public var outcomeCount: [BASRequestOutcome: Int]
    public var outcomeCountByKind: [BASRequestOutcome: [String: Int]]
    public var activeProviderCount: [String: Int]
    public var attemptedProviderCount: [String: Int]
    public var fallbackActivations: Int
    public var backendCount: [String: Int]
    public var slowRequestCountByKind: [String: Int]
    public var overTimeBudgetCountByKind: [String: Int]
    public var requestDurationTotalMsByKind: [String: Double]
    public var firstPresentableTotalMsByKind: [String: Double]
    public var promptAssemblyTotalMsByKind: [String: Double]
    public var admissionEvaluationTotalMsByKind: [String: Double]
    public var providerSelectionTotalMsByKind: [String: Double]
    public var executionTotalMsByKind: [String: Double]
    public var activeProviderDurationTotalMs: [String: Double]
    public var backendDurationTotalMs: [String: Double]
    public var admissionSkipCountByReason: [String: Int]
    public var admissionSkipCountByReasonAndKind: [String: [String: Int]]
    public var reminderSelectionNeedCount: [String: Int]
    public var reminderSelectionNeedCountByKind: [String: [String: Int]]
    public var promptPressureCount: [String: Int]
    public var promptCharactersTotalByKind: [String: Int]
    public var prefixCharactersTotalByKind: [String: Int]
    public var immutablePrefixCharactersTotalByKind: [String: Int]
    public var adaptivePrefixCharactersTotalByKind: [String: Int]
    public var suffixCharactersTotalByKind: [String: Int]
    public var overTargetBudgetCountByKind: [String: Int]
    public var lowPressureModelCallCountByKind: [String: Int]
    public var config: BASAppleTelemetryAccumulatorConfig

    public init(
        requestCountByKind: [String: Int],
        outcomeCount: [BASRequestOutcome: Int],
        outcomeCountByKind: [BASRequestOutcome: [String: Int]],
        activeProviderCount: [String: Int],
        attemptedProviderCount: [String: Int],
        fallbackActivations: Int,
        backendCount: [String: Int],
        slowRequestCountByKind: [String: Int],
        overTimeBudgetCountByKind: [String: Int],
        requestDurationTotalMsByKind: [String: Double],
        firstPresentableTotalMsByKind: [String: Double],
        promptAssemblyTotalMsByKind: [String: Double],
        admissionEvaluationTotalMsByKind: [String: Double],
        providerSelectionTotalMsByKind: [String: Double],
        executionTotalMsByKind: [String: Double],
        activeProviderDurationTotalMs: [String: Double],
        backendDurationTotalMs: [String: Double],
        admissionSkipCountByReason: [String: Int],
        admissionSkipCountByReasonAndKind: [String: [String: Int]],
        reminderSelectionNeedCount: [String: Int],
        reminderSelectionNeedCountByKind: [String: [String: Int]],
        promptPressureCount: [String: Int],
        promptCharactersTotalByKind: [String: Int],
        prefixCharactersTotalByKind: [String: Int],
        immutablePrefixCharactersTotalByKind: [String: Int],
        adaptivePrefixCharactersTotalByKind: [String: Int],
        suffixCharactersTotalByKind: [String: Int],
        overTargetBudgetCountByKind: [String: Int],
        lowPressureModelCallCountByKind: [String: Int],
        config: BASAppleTelemetryAccumulatorConfig
    ) {
        self.requestCountByKind = requestCountByKind
        self.outcomeCount = outcomeCount
        self.outcomeCountByKind = outcomeCountByKind
        self.activeProviderCount = activeProviderCount
        self.attemptedProviderCount = attemptedProviderCount
        self.fallbackActivations = fallbackActivations
        self.backendCount = backendCount
        self.slowRequestCountByKind = slowRequestCountByKind
        self.overTimeBudgetCountByKind = overTimeBudgetCountByKind
        self.requestDurationTotalMsByKind = requestDurationTotalMsByKind
        self.firstPresentableTotalMsByKind = firstPresentableTotalMsByKind
        self.promptAssemblyTotalMsByKind = promptAssemblyTotalMsByKind
        self.admissionEvaluationTotalMsByKind = admissionEvaluationTotalMsByKind
        self.providerSelectionTotalMsByKind = providerSelectionTotalMsByKind
        self.executionTotalMsByKind = executionTotalMsByKind
        self.activeProviderDurationTotalMs = activeProviderDurationTotalMs
        self.backendDurationTotalMs = backendDurationTotalMs
        self.admissionSkipCountByReason = admissionSkipCountByReason
        self.admissionSkipCountByReasonAndKind = admissionSkipCountByReasonAndKind
        self.reminderSelectionNeedCount = reminderSelectionNeedCount
        self.reminderSelectionNeedCountByKind = reminderSelectionNeedCountByKind
        self.promptPressureCount = promptPressureCount
        self.promptCharactersTotalByKind = promptCharactersTotalByKind
        self.prefixCharactersTotalByKind = prefixCharactersTotalByKind
        self.immutablePrefixCharactersTotalByKind = immutablePrefixCharactersTotalByKind
        self.adaptivePrefixCharactersTotalByKind = adaptivePrefixCharactersTotalByKind
        self.suffixCharactersTotalByKind = suffixCharactersTotalByKind
        self.overTargetBudgetCountByKind = overTargetBudgetCountByKind
        self.lowPressureModelCallCountByKind = lowPressureModelCallCountByKind
        self.config = config
    }

    public var summaryInput: BASTelemetrySummaryInput {
        BASTelemetrySummaryInput(
            requestCountByKind: requestCountByKind,
            outcomeCount: outcomeCount,
            outcomeCountByKind: outcomeCountByKind,
            activeProviderCount: activeProviderCount,
            attemptedProviderCount: attemptedProviderCount,
            fallbackActivations: fallbackActivations,
            backendCount: backendCount,
            slowRequestCountByKind: slowRequestCountByKind,
            overTimeBudgetCountByKind: overTimeBudgetCountByKind,
            requestDurationTotalMsByKind: requestDurationTotalMsByKind,
            firstPresentableTotalMsByKind: firstPresentableTotalMsByKind,
            promptAssemblyTotalMsByKind: promptAssemblyTotalMsByKind,
            admissionEvaluationTotalMsByKind: admissionEvaluationTotalMsByKind,
            providerSelectionTotalMsByKind: providerSelectionTotalMsByKind,
            executionTotalMsByKind: executionTotalMsByKind,
            activeProviderDurationTotalMs: activeProviderDurationTotalMs,
            backendDurationTotalMs: backendDurationTotalMs,
            admissionSkipCountByReason: admissionSkipCountByReason,
            admissionSkipCountByReasonAndKind: admissionSkipCountByReasonAndKind,
            reminderSelectionNeedCount: reminderSelectionNeedCount,
            promptCharactersTotalByKind: promptCharactersTotalByKind,
            prefixCharactersTotalByKind: prefixCharactersTotalByKind,
            immutablePrefixCharactersTotalByKind: immutablePrefixCharactersTotalByKind,
            adaptivePrefixCharactersTotalByKind: adaptivePrefixCharactersTotalByKind,
            suffixCharactersTotalByKind: suffixCharactersTotalByKind,
            overTargetBudgetCountByKind: overTargetBudgetCountByKind,
            lowPressureModelCallCountByKind: lowPressureModelCallCountByKind,
            reminderKindRawValue: config.reminderKindRawValue,
            reminderKnowledgeNeedRawValue: config.reminderKnowledgeNeedRawValue,
            reminderControlNeedRawValue: config.reminderControlNeedRawValue,
            reminderRetrievalBypassReasonRawValues: config.reminderRetrievalBypassReasonRawValues,
            avoidableSkipReasonRawValues: config.avoidableSkipReasonRawValues
        )
    }

    public var summary: BASTelemetrySummary {
        BASTelemetrySummaryBuilder.build(from: summaryInput)
    }
}

public actor BASAppleTelemetryAccumulator {
    private let config: BASAppleTelemetryAccumulatorConfig

    private var requestCountByKind: [String: Int] = [:]
    private var outcomeCount: [BASRequestOutcome: Int] = [:]
    private var outcomeCountByKind: [BASRequestOutcome: [String: Int]] = [:]
    private var activeProviderCount: [String: Int] = [:]
    private var attemptedProviderCount: [String: Int] = [:]
    private var fallbackActivations = 0
    private var backendCount: [String: Int] = [:]
    private var slowRequestCountByKind: [String: Int] = [:]
    private var overTimeBudgetCountByKind: [String: Int] = [:]
    private var requestDurationTotalMsByKind: [String: Double] = [:]
    private var firstPresentableTotalMsByKind: [String: Double] = [:]
    private var promptAssemblyTotalMsByKind: [String: Double] = [:]
    private var admissionEvaluationTotalMsByKind: [String: Double] = [:]
    private var providerSelectionTotalMsByKind: [String: Double] = [:]
    private var executionTotalMsByKind: [String: Double] = [:]
    private var activeProviderDurationTotalMs: [String: Double] = [:]
    private var backendDurationTotalMs: [String: Double] = [:]
    private var admissionSkipCountByReason: [String: Int] = [:]
    private var admissionSkipCountByReasonAndKind: [String: [String: Int]] = [:]
    private var reminderSelectionNeedCount: [String: Int] = [:]
    private var reminderSelectionNeedCountByKind: [String: [String: Int]] = [:]
    private var promptPressureCount: [String: Int] = [:]
    private var promptCharactersTotalByKind: [String: Int] = [:]
    private var prefixCharactersTotalByKind: [String: Int] = [:]
    private var immutablePrefixCharactersTotalByKind: [String: Int] = [:]
    private var adaptivePrefixCharactersTotalByKind: [String: Int] = [:]
    private var suffixCharactersTotalByKind: [String: Int] = [:]
    private var overTargetBudgetCountByKind: [String: Int] = [:]
    private var lowPressureModelCallCountByKind: [String: Int] = [:]

    public init(config: BASAppleTelemetryAccumulatorConfig) {
        self.config = config
    }

    public func record(from input: BASAppleTelemetryRecordInput) {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(from: input)

        requestCountByKind[compilation.kind, default: 0] += 1
        outcomeCount[compilation.outcome, default: 0] += 1
        var countsForOutcome = outcomeCountByKind[compilation.outcome, default: [:]]
        countsForOutcome[compilation.kind, default: 0] += 1
        outcomeCountByKind[compilation.outcome] = countsForOutcome
        requestDurationTotalMsByKind[compilation.kind, default: 0] += compilation.durationMs

        if let lifecycleMetrics = compilation.lifecycleMetrics {
            firstPresentableTotalMsByKind[compilation.kind, default: 0] += lifecycleMetrics.firstPresentableMs
            promptAssemblyTotalMsByKind[compilation.kind, default: 0] += lifecycleMetrics.promptAssemblyMs
            admissionEvaluationTotalMsByKind[compilation.kind, default: 0] += lifecycleMetrics.admissionEvaluationMs
            providerSelectionTotalMsByKind[compilation.kind, default: 0] += lifecycleMetrics.providerSelectionMs
            executionTotalMsByKind[compilation.kind, default: 0] += lifecycleMetrics.executionMs
        }

        if compilation.isSlowRequest {
            slowRequestCountByKind[compilation.kind, default: 0] += 1
        }
        if compilation.exceedsTimeBudget {
            overTimeBudgetCountByKind[compilation.kind, default: 0] += 1
        }

        for providerID in compilation.attemptedProviderIDs {
            attemptedProviderCount[providerID, default: 0] += 1
        }

        if let activeProviderID = compilation.activeProviderID {
            activeProviderCount[activeProviderID, default: 0] += 1
            activeProviderDurationTotalMs[activeProviderID, default: 0] += compilation.durationMs
        }

        if compilation.usedFallback {
            fallbackActivations += 1
        }

        if let promptBudget = compilation.promptBudget {
            promptCharactersTotalByKind[compilation.kind, default: 0] += promptBudget.totalCharacters
            prefixCharactersTotalByKind[compilation.kind, default: 0] += promptBudget.prefixCharacters
            immutablePrefixCharactersTotalByKind[compilation.kind, default: 0] += promptBudget.immutablePrefixCharacters
            adaptivePrefixCharactersTotalByKind[compilation.kind, default: 0] += promptBudget.adaptivePrefixCharacters
            suffixCharactersTotalByKind[compilation.kind, default: 0] += promptBudget.suffixCharacters
            if compilation.overTargetPromptBudget {
                overTargetBudgetCountByKind[compilation.kind, default: 0] += 1
            }
        }

        if let admissionPressureID = compilation.admissionPressureID {
            promptPressureCount[admissionPressureID, default: 0] += 1
            if compilation.lowPressureModelCall {
                lowPressureModelCallCountByKind[compilation.kind, default: 0] += 1
            }
        }

        if let reminderSelectionNeedID = compilation.reminderSelectionNeedID {
            reminderSelectionNeedCount[reminderSelectionNeedID, default: 0] += 1
            var countsForNeed = reminderSelectionNeedCountByKind[reminderSelectionNeedID, default: [:]]
            countsForNeed[compilation.kind, default: 0] += 1
            reminderSelectionNeedCountByKind[reminderSelectionNeedID] = countsForNeed
        }

        if let admissionSkipReasonID = compilation.admissionSkipReasonID {
            admissionSkipCountByReason[admissionSkipReasonID, default: 0] += 1
            var countsForReason = admissionSkipCountByReasonAndKind[admissionSkipReasonID, default: [:]]
            countsForReason[compilation.kind, default: 0] += 1
            admissionSkipCountByReasonAndKind[admissionSkipReasonID] = countsForReason
        }

        if let activeBackendID = compilation.activeBackendID {
            backendCount[activeBackendID, default: 0] += 1
            backendDurationTotalMs[activeBackendID, default: 0] += compilation.durationMs
        }
    }

    public func snapshot() -> BASAppleTelemetryAccumulatorSnapshot {
        BASAppleTelemetryAccumulatorSnapshot(
            requestCountByKind: requestCountByKind,
            outcomeCount: outcomeCount,
            outcomeCountByKind: outcomeCountByKind,
            activeProviderCount: activeProviderCount,
            attemptedProviderCount: attemptedProviderCount,
            fallbackActivations: fallbackActivations,
            backendCount: backendCount,
            slowRequestCountByKind: slowRequestCountByKind,
            overTimeBudgetCountByKind: overTimeBudgetCountByKind,
            requestDurationTotalMsByKind: requestDurationTotalMsByKind,
            firstPresentableTotalMsByKind: firstPresentableTotalMsByKind,
            promptAssemblyTotalMsByKind: promptAssemblyTotalMsByKind,
            admissionEvaluationTotalMsByKind: admissionEvaluationTotalMsByKind,
            providerSelectionTotalMsByKind: providerSelectionTotalMsByKind,
            executionTotalMsByKind: executionTotalMsByKind,
            activeProviderDurationTotalMs: activeProviderDurationTotalMs,
            backendDurationTotalMs: backendDurationTotalMs,
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
            lowPressureModelCallCountByKind: lowPressureModelCallCountByKind,
            config: config
        )
    }

    public func clear() {
        requestCountByKind.removeAll()
        outcomeCount.removeAll()
        outcomeCountByKind.removeAll()
        activeProviderCount.removeAll()
        attemptedProviderCount.removeAll()
        fallbackActivations = 0
        backendCount.removeAll()
        slowRequestCountByKind.removeAll()
        overTimeBudgetCountByKind.removeAll()
        requestDurationTotalMsByKind.removeAll()
        firstPresentableTotalMsByKind.removeAll()
        promptAssemblyTotalMsByKind.removeAll()
        admissionEvaluationTotalMsByKind.removeAll()
        providerSelectionTotalMsByKind.removeAll()
        executionTotalMsByKind.removeAll()
        activeProviderDurationTotalMs.removeAll()
        backendDurationTotalMs.removeAll()
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
    }
}
