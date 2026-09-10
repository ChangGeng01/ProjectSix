import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASRequestOutcome: String, CaseIterable, Codable, Sendable {
    case templatePinned
    case cacheHit
    case providerSuccess
    case admissionSkipped
    case deterministicFallback
}

public struct BASRequestLifecycleMetrics: Codable, Sendable, Equatable {
    public var promptAssemblyMs: Double
    public var admissionEvaluationMs: Double
    public var providerSelectionMs: Double
    public var firstPresentableMs: Double
    public var executionMs: Double

    public init(
        promptAssemblyMs: Double,
        admissionEvaluationMs: Double,
        providerSelectionMs: Double,
        firstPresentableMs: Double,
        executionMs: Double
    ) {
        self.promptAssemblyMs = promptAssemblyMs
        self.admissionEvaluationMs = admissionEvaluationMs
        self.providerSelectionMs = providerSelectionMs
        self.firstPresentableMs = firstPresentableMs
        self.executionMs = executionMs
    }

    public var prefillEquivalentMs: Double {
        promptAssemblyMs + admissionEvaluationMs + providerSelectionMs
    }

    public var prefillEquivalentShare: Double {
        guard firstPresentableMs > 0 else { return 0 }
        return prefillEquivalentMs / firstPresentableMs
    }
}

public enum BASLifecycleMetricsCompiler {
    public static func compile(
        promptAssemblyMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerSelectionMs: Double? = nil,
        firstPresentableMs: Double
    ) -> BASRequestLifecycleMetrics {
        let promptBoundary = max(0, promptAssemblyMs)
        let admissionBoundary = max(promptBoundary, admissionEvaluatedMs ?? promptBoundary)
        let providerBoundary = max(admissionBoundary, providerSelectionMs ?? admissionBoundary)
        let presentationBoundary = max(providerBoundary, firstPresentableMs)

        return BASRequestLifecycleMetrics(
            promptAssemblyMs: promptBoundary,
            admissionEvaluationMs: max(0, admissionBoundary - promptBoundary),
            providerSelectionMs: max(0, providerBoundary - admissionBoundary),
            firstPresentableMs: presentationBoundary,
            executionMs: max(0, presentationBoundary - providerBoundary)
        )
    }
}

public struct BASTelemetrySummaryInput: Codable, Sendable, Equatable {
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
    public var selectionNeedCount: [String: Int]
    public var promptCharactersTotalByKind: [String: Int]
    public var prefixCharactersTotalByKind: [String: Int]
    public var immutablePrefixCharactersTotalByKind: [String: Int]
    public var adaptivePrefixCharactersTotalByKind: [String: Int]
    public var suffixCharactersTotalByKind: [String: Int]
    public var overTargetBudgetCountByKind: [String: Int]
    public var lowPressureModelCallCountByKind: [String: Int]
    public var selectionKindRawValue: String
    public var selectionKnowledgeNeedRawValue: String
    public var selectionControlNeedRawValue: String
    public var selectionRetrievalBypassReasonRawValues: [String]
    public var avoidableSkipReasonRawValues: [String]

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
        selectionNeedCount: [String: Int],
        promptCharactersTotalByKind: [String: Int],
        prefixCharactersTotalByKind: [String: Int],
        immutablePrefixCharactersTotalByKind: [String: Int],
        adaptivePrefixCharactersTotalByKind: [String: Int],
        suffixCharactersTotalByKind: [String: Int],
        overTargetBudgetCountByKind: [String: Int],
        lowPressureModelCallCountByKind: [String: Int],
        selectionKindRawValue: String,
        selectionKnowledgeNeedRawValue: String,
        selectionControlNeedRawValue: String,
        selectionRetrievalBypassReasonRawValues: [String],
        avoidableSkipReasonRawValues: [String]
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
        self.selectionNeedCount = selectionNeedCount
        self.promptCharactersTotalByKind = promptCharactersTotalByKind
        self.prefixCharactersTotalByKind = prefixCharactersTotalByKind
        self.immutablePrefixCharactersTotalByKind = immutablePrefixCharactersTotalByKind
        self.adaptivePrefixCharactersTotalByKind = adaptivePrefixCharactersTotalByKind
        self.suffixCharactersTotalByKind = suffixCharactersTotalByKind
        self.overTargetBudgetCountByKind = overTargetBudgetCountByKind
        self.lowPressureModelCallCountByKind = lowPressureModelCallCountByKind
        self.selectionKindRawValue = selectionKindRawValue
        self.selectionKnowledgeNeedRawValue = selectionKnowledgeNeedRawValue
        self.selectionControlNeedRawValue = selectionControlNeedRawValue
        self.selectionRetrievalBypassReasonRawValues = selectionRetrievalBypassReasonRawValues
        self.avoidableSkipReasonRawValues = avoidableSkipReasonRawValues
    }
}

public struct BASTelemetrySummary: Codable, Sendable, Equatable {
    public var input: BASTelemetrySummaryInput

    public init(input: BASTelemetrySummaryInput) {
        self.input = input
    }

    public var totalRequests: Int {
        input.requestCountByKind.values.reduce(0, +)
    }

    public var totalProviderAttempts: Int {
        input.attemptedProviderCount.values.reduce(0, +)
    }

    public var cacheHitRate: Double {
        rate(numerator: input.outcomeCount[.cacheHit] ?? 0, denominator: totalRequests)
    }

    public var admissionSkipRate: Double {
        rate(numerator: input.outcomeCount[.admissionSkipped] ?? 0, denominator: totalRequests)
    }

    public var providerBypassRate: Double {
        rate(numerator: providerBypassCount, denominator: totalRequests)
    }

    public var deterministicFallbackRate: Double {
        rate(numerator: input.outcomeCount[.deterministicFallback] ?? 0, denominator: totalRequests)
    }

    public var averageRequestDurationMs: Double {
        average(totals: input.requestDurationTotalMsByKind.values.reduce(0, +), count: totalRequests)
    }

    public var averageRequestDurationMsByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, average(totals: input.requestDurationTotalMsByKind[kind] ?? 0, count: count))
            }
        )
    }

    public var averageFirstPresentableMs: Double {
        average(totals: input.firstPresentableTotalMsByKind.values.reduce(0, +), count: totalRequests)
    }

    public var averageFirstPresentableMsByKind: [String: Double] {
        averageByKind(from: input.firstPresentableTotalMsByKind)
    }

    public var averagePromptAssemblyMsByKind: [String: Double] {
        averageByKind(from: input.promptAssemblyTotalMsByKind)
    }

    public var averageAdmissionEvaluationMsByKind: [String: Double] {
        averageByKind(from: input.admissionEvaluationTotalMsByKind)
    }

    public var averageProviderSelectionMsByKind: [String: Double] {
        averageByKind(from: input.providerSelectionTotalMsByKind)
    }

    public var averageExecutionMsByKind: [String: Double] {
        averageByKind(from: input.executionTotalMsByKind)
    }

    public var averagePrefillEquivalentShareByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                let firstPresentable = input.firstPresentableTotalMsByKind[kind] ?? 0
                let prefillEquivalent =
                    (input.promptAssemblyTotalMsByKind[kind] ?? 0) +
                    (input.admissionEvaluationTotalMsByKind[kind] ?? 0) +
                    (input.providerSelectionTotalMsByKind[kind] ?? 0)
                let ratio = firstPresentable > 0 ? prefillEquivalent / firstPresentable : 0
                return (kind, count > 0 ? ratio : 0)
            }
        )
    }

    public var averageRequestDurationMsByActiveProvider: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.activeProviderDurationTotalMs.map { provider, total in
                (provider, average(totals: total, count: input.activeProviderCount[provider] ?? 0))
            }
        )
    }

    public var averageRequestDurationMsByBackend: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.backendDurationTotalMs.map { backend, total in
                (backend, average(totals: total, count: input.backendCount[backend] ?? 0))
            }
        )
    }

    public var averagePromptCharactersByKind: [String: Double] {
        averageCharacterByKind(from: input.promptCharactersTotalByKind)
    }

    public var averagePrefixCharactersByKind: [String: Double] {
        averageCharacterByKind(from: input.prefixCharactersTotalByKind)
    }

    public var averageImmutablePrefixCharactersByKind: [String: Double] {
        averageCharacterByKind(from: input.immutablePrefixCharactersTotalByKind)
    }

    public var averageAdaptivePrefixCharactersByKind: [String: Double] {
        averageCharacterByKind(from: input.adaptivePrefixCharactersTotalByKind)
    }

    public var averageSuffixCharactersByKind: [String: Double] {
        averageCharacterByKind(from: input.suffixCharactersTotalByKind)
    }

    public var averageStablePrefixShareByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                let totalPrompt = input.promptCharactersTotalByKind[kind] ?? 0
                let totalPrefix = input.prefixCharactersTotalByKind[kind] ?? 0
                let ratio = totalPrompt > 0 ? Double(totalPrefix) / Double(totalPrompt) : 0
                return (kind, count > 0 ? ratio : 0)
            }
        )
    }

    public var providerBypassRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: providerBypassCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var lowPressureModelCallRate: Double {
        rate(numerator: input.lowPressureModelCallCountByKind.values.reduce(0, +), denominator: totalRequests)
    }

    public var lowPressureModelCallRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: input.lowPressureModelCallCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var avoidableModelCallRate: Double {
        rate(numerator: avoidableModelCallCount, denominator: totalRequests)
    }

    public var avoidableModelCallRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: avoidableModelCallCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var avoidableModelCallCount: Int {
        avoidableModelCallCountByKind.values.reduce(0, +)
    }

    public var providerBypassCount: Int {
        providerBypassCountByKind.values.reduce(0, +)
    }

    public var overTargetBudgetRate: Double {
        rate(numerator: input.overTargetBudgetCountByKind.values.reduce(0, +), denominator: totalRequests)
    }

    public var overTargetBudgetRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: input.overTargetBudgetCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var selectionKnowledgeNeedRate: Double {
        rate(
            numerator: input.selectionNeedCount[input.selectionKnowledgeNeedRawValue] ?? 0,
            denominator: selectionRequestCount
        )
    }

    public var selectionControlOnlyRate: Double {
        rate(
            numerator: input.selectionNeedCount[input.selectionControlNeedRawValue] ?? 0,
            denominator: selectionRequestCount
        )
    }

    public var selectionRetrievalBypassRate: Double {
        rate(numerator: selectionRetrievalBypassCount, denominator: selectionRequestCount)
    }

    public var selectionRequestCount: Int {
        input.requestCountByKind[input.selectionKindRawValue] ?? 0
    }

    public var selectionRetrievalBypassCount: Int {
        input.selectionRetrievalBypassReasonRawValues.reduce(0) { partialResult, reason in
            partialResult + (input.admissionSkipCountByReason[reason] ?? 0)
        }
    }

    public var slowRequestRate: Double {
        rate(numerator: input.slowRequestCountByKind.values.reduce(0, +), denominator: totalRequests)
    }

    public var slowRequestRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: input.slowRequestCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var overTimeBudgetRate: Double {
        rate(numerator: input.overTimeBudgetCountByKind.values.reduce(0, +), denominator: totalRequests)
    }

    public var overTimeBudgetRateByKind: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, rate(numerator: input.overTimeBudgetCountByKind[kind] ?? 0, denominator: count))
            }
        )
    }

    public var providerBypassCountByKind: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.keys.map { kind in
                let templatePinned = outcomeCountForKind(.templatePinned, kind: kind)
                let admissionSkipped = outcomeCountForKind(.admissionSkipped, kind: kind)
                let cacheHit = outcomeCountForKind(.cacheHit, kind: kind)
                return (kind, templatePinned + admissionSkipped + cacheHit)
            }
        )
    }

    public var avoidableModelCallCountByKind: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.keys.map { kind in
                let count = input.avoidableSkipReasonRawValues.reduce(0) { partialResult, reason in
                    partialResult + (input.admissionSkipCountByReasonAndKind[reason]?[kind] ?? 0)
                }
                return (kind, count)
            }
        )
    }

    private func averageByKind(from totalsByKind: [String: Double]) -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: input.requestCountByKind.map { kind, count in
                (kind, average(totals: totalsByKind[kind] ?? 0, count: count))
            }
        )
    }

    private func averageCharacterByKind(from totalsByKind: [String: Int]) -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: totalsByKind.map { kind, total in
                (kind, average(totals: Double(total), count: input.requestCountByKind[kind] ?? 0))
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

    private func outcomeCountForKind(_ outcome: BASRequestOutcome, kind: String) -> Int {
        input.outcomeCountByKind[outcome]?[kind] ?? 0
    }
}

public enum BASTelemetrySummaryBuilder {
    public static func build(from input: BASTelemetrySummaryInput) -> BASTelemetrySummary {
        BASTelemetrySummary(input: input)
    }
}

public struct BASTraceLatencyBreakdown: Codable, Sendable, Equatable {
    public var routeSelectionMs: Int
    public var retrievalMs: Int
    public var generationMs: Int
    public var toolMs: Int

    public init(routeSelectionMs: Int, retrievalMs: Int, generationMs: Int, toolMs: Int) {
        self.routeSelectionMs = routeSelectionMs
        self.retrievalMs = retrievalMs
        self.generationMs = generationMs
        self.toolMs = toolMs
    }

    public var totalMs: Int { routeSelectionMs + retrievalMs + generationMs + toolMs }
}

public struct BASAuditEvent: Codable, Sendable, Equatable {
    public var id: UUID
    public var category: String
    public var message: String
    public var timestamp: Date
    public var metadata: [String: String]

    public init(id: UUID = UUID(), category: String, message: String, timestamp: Date = .now, metadata: [String: String] = [:]) {
        self.id = id
        self.category = category
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public struct BASExecutionTrace: Codable, Sendable, Equatable {
    public var inputSummary: String
    public var selectedRoute: BASModelRoute
    public var memoriesRecalled: [String]
    public var toolsCalled: [String]
    public var latency: BASTraceLatencyBreakdown
    public var auditEvents: [BASAuditEvent]
    public var outputSummary: String

    public init(
        inputSummary: String,
        selectedRoute: BASModelRoute,
        memoriesRecalled: [String],
        toolsCalled: [String],
        latency: BASTraceLatencyBreakdown,
        auditEvents: [BASAuditEvent] = [],
        outputSummary: String
    ) {
        self.inputSummary = inputSummary
        self.selectedRoute = selectedRoute
        self.memoriesRecalled = memoriesRecalled
        self.toolsCalled = toolsCalled
        self.latency = latency
        self.auditEvents = auditEvents
        self.outputSummary = outputSummary
    }
}

public struct BASReplayBundle: Codable, Sendable, Equatable {
    public var trace: BASExecutionTrace
    public var brainState: BASCurrentBrainState
    public var runtimeContext: BASRuntimeContext
    public var policyDecision: BASPolicyDecisionRecord
    public var replayDisposition: BASReplayDisposition

    public init(
        trace: BASExecutionTrace,
        brainState: BASCurrentBrainState,
        runtimeContext: BASRuntimeContext,
        policyDecision: BASPolicyDecisionRecord,
        replayDisposition: BASReplayDisposition = BASReplayDisposition()
    ) {
        self.trace = trace
        self.brainState = brainState
        self.runtimeContext = runtimeContext
        self.policyDecision = policyDecision
        self.replayDisposition = replayDisposition
    }
}

public enum BASReleaseDecisionKind: String, Codable, Sendable {
    case allow
    case requireConfirmation
    case deny
}

public struct BASReleaseDecision: Codable, Sendable, Equatable {
    public var kind: BASReleaseDecisionKind
    public var reason: String

    public init(kind: BASReleaseDecisionKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

public struct BASReplayFingerprint: Codable, Sendable, Equatable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct BASReplayDisposition: Codable, Sendable, Equatable {
    public var isAvailable: Bool
    public var reason: String?
    public var forgetRequestID: String?
    public var checkpointsRevoked: Bool
    public var syncExportsRevoked: Bool
    public var vaultConsistencyState: String?
    public var vaultDeletionManifestID: String?
    public var vaultSyncRevocationCount: Int
    public var vaultRequiresApproval: Bool
    public var vaultOutOfSyncDeviceIDs: [String]
    public var vaultMigrationTargetDeviceID: String?

    public init(
        isAvailable: Bool = true,
        reason: String? = nil,
        forgetRequestID: String? = nil,
        checkpointsRevoked: Bool = false,
        syncExportsRevoked: Bool = false,
        vaultConsistencyState: String? = nil,
        vaultDeletionManifestID: String? = nil,
        vaultSyncRevocationCount: Int = 0,
        vaultRequiresApproval: Bool = false,
        vaultOutOfSyncDeviceIDs: [String] = [],
        vaultMigrationTargetDeviceID: String? = nil
    ) {
        self.isAvailable = isAvailable
        self.reason = reason
        self.forgetRequestID = forgetRequestID
        self.checkpointsRevoked = checkpointsRevoked
        self.syncExportsRevoked = syncExportsRevoked
        self.vaultConsistencyState = vaultConsistencyState
        self.vaultDeletionManifestID = vaultDeletionManifestID
        self.vaultSyncRevocationCount = vaultSyncRevocationCount
        self.vaultRequiresApproval = vaultRequiresApproval
        self.vaultOutOfSyncDeviceIDs = vaultOutOfSyncDeviceIDs
        self.vaultMigrationTargetDeviceID = vaultMigrationTargetDeviceID
    }
}

public struct BASAnomalySignal: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: String
    public var severity: String
    public var message: String
    public var timestamp: Date

    public init(id: UUID = UUID(), kind: String, severity: String, message: String, timestamp: Date = .now) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
    }
}

public struct BASInspectionCalibrationSummary: Codable, Sendable, Equatable {
    public var score: Double
    public var status: String
    public var summary: String
    public var alertCount: Int
    public var alertReasons: [String]

    public init(
        score: Double,
        status: String,
        summary: String,
        alertCount: Int,
        alertReasons: [String] = []
    ) {
        self.score = score
        self.status = status
        self.summary = summary
        self.alertCount = alertCount
        self.alertReasons = alertReasons
    }
}

public struct BASInspectionBundle: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var trace: BASExecutionTrace
    public var replayFingerprint: BASReplayFingerprint
    public var replayDisposition: BASReplayDisposition
    public var releaseDecision: BASReleaseDecision
    public var anomalySignals: [BASAnomalySignal]
    public var calibration: BASInspectionCalibrationSummary?

    public init(
        generatedAt: Date = .now,
        trace: BASExecutionTrace,
        replayFingerprint: BASReplayFingerprint,
        replayDisposition: BASReplayDisposition = BASReplayDisposition(),
        releaseDecision: BASReleaseDecision,
        anomalySignals: [BASAnomalySignal],
        calibration: BASInspectionCalibrationSummary? = nil
    ) {
        self.generatedAt = generatedAt
        self.trace = trace
        self.replayFingerprint = replayFingerprint
        self.replayDisposition = replayDisposition
        self.releaseDecision = releaseDecision
        self.anomalySignals = anomalySignals
        self.calibration = calibration
    }

    public var summary: String {
        let anomalySummary = anomalySignals.isEmpty
            ? "no active anomalies"
            : "\(anomalySignals.count) anomaly signal\(anomalySignals.count == 1 ? "" : "s")"
        let calibrationSummary = calibration.map { "calibration \($0.status.lowercased())" } ?? "calibration unavailable"
        let replaySummary = replayDisposition.isAvailable ? "replay available" : "replay blocked"
        let rawVaultSummary = replayDisposition.isAvailable
            ? nil
            : [
                replayDisposition.vaultOutOfSyncDeviceIDs.isEmpty
                    ? nil
                    : "devices \(replayDisposition.vaultOutOfSyncDeviceIDs.joined(separator: ", "))",
                replayDisposition.vaultMigrationTargetDeviceID.map { "migration target \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        let vaultSummary: String? = {
            guard let rawVaultSummary, !rawVaultSummary.isEmpty else {
                return nil
            }
            return rawVaultSummary
        }()
        return [
            "Release \(releaseDecision.kind.rawValue)",
            "route \(trace.selectedRoute.preferredModelID)",
            anomalySummary,
            replaySummary,
            vaultSummary,
            calibrationSummary
        ]
        .compactMap { $0 }
        .joined(separator: "; ") + "."
    }

    public var blockerSummary: [String] {
        var blockers: [String] = []
        if releaseDecision.kind == .deny {
            blockers.append(releaseDecision.reason)
        }
        blockers.append(
            contentsOf: anomalySignals
                .filter { $0.severity == "high" }
                .map(\.message)
        )
        if let calibration, calibration.status.caseInsensitiveCompare("fail") == .orderedSame {
            blockers.append(calibration.summary)
        }
        if let replayReason = replayDisposition.reason, replayDisposition.isAvailable == false {
            blockers.append(replayReason)
        }
        return blockers
    }
}

public enum BASObservabilityInspector {
    public static func releaseDecision(
        for trace: BASExecutionTrace,
        policyDecision: BASPolicyDecisionRecord
    ) -> BASReleaseDecision {
        switch policyDecision.decision {
        case .allow:
            return BASReleaseDecision(
                kind: .allow,
                reason: "Output released via \(trace.selectedRoute.preferredModelID)."
            )
        case .requireConfirmation:
            return BASReleaseDecision(
                kind: .requireConfirmation,
                reason: policyDecision.reason
            )
        case .deny:
            return BASReleaseDecision(
                kind: .deny,
                reason: policyDecision.reason
            )
        }
    }

    public static func replayFingerprint(for bundle: BASReplayBundle) -> BASReplayFingerprint {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // audit policy-obs-misc LOW-3: a non-finite Double (NaN/±inf) anywhere in the bundle used to
        // make encode() THROW → the `?? Data()` fallback hashed EMPTY → every non-finite bundle
        // collided to SHA256(""). Encode them to distinct sentinel strings so the fallback is
        // unreachable for that trigger and such bundles keep distinct fingerprints. All-finite
        // bundles encode byte-identically (the strategy only affects non-conforming floats).
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "nan")
        let data = (try? encoder.encode(bundle)) ?? Data()
        let digest = SHA256.hash(data: data)
        // LEGACY (chapter 七百十九 第三刀 / M2268):
        //     return BASReplayFingerprint(value: digest.map {
        //         String(format: "%02x", $0) }.joined())
        return BASReplayFingerprint(
            value: BASAutoRouteRanker.bytesToHexLower(
                Array(digest)))
    }

    public static func anomalySignals(
        for trace: BASExecutionTrace,
        policyDecision: BASPolicyDecisionRecord,
        replayDisposition: BASReplayDisposition = BASReplayDisposition()
    ) -> [BASAnomalySignal] {
        var signals: [BASAnomalySignal] = []

        if trace.latency.totalMs >= 5_000 {
            signals.append(
                BASAnomalySignal(
                    kind: "latency_spike",
                    severity: "high",
                    message: "Execution latency crossed 5000ms."
                )
            )
        }

        if !trace.toolsCalled.isEmpty && trace.latency.toolMs == 0 {
            signals.append(
                BASAnomalySignal(
                    kind: "tool_timing_gap",
                    severity: "medium",
                    message: "Tools were called without recorded tool latency."
                )
            )
        }

        if policyDecision.decision == .deny && !trace.outputSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            signals.append(
                BASAnomalySignal(
                    kind: "release_mismatch",
                    severity: "high",
                    message: "Policy denied release but output summary is still present."
                )
            )
        }

        if Set(trace.memoriesRecalled).count != trace.memoriesRecalled.count {
            signals.append(
                BASAnomalySignal(
                    kind: "duplicate_memory_recall",
                    severity: "medium",
                    message: "The same memory summary was recalled multiple times."
                )
            )
        }

        if replayDisposition.isAvailable == false, let reason = replayDisposition.reason {
            signals.append(
                BASAnomalySignal(
                    kind: "replay_revoked",
                    severity: "high",
                    message: reason
                )
            )
        }

        if let vaultConsistencyState = replayDisposition.vaultConsistencyState,
           replayDisposition.isAvailable == false,
           ["revocation_pending", "out_of_sync", "migration_pending"].contains(vaultConsistencyState) {
            signals.append(
                BASAnomalySignal(
                    kind: "vault_consistency_risk",
                    severity: "high",
                    message: replayDisposition.reason
                        ?? "Host constitution vault consistency is \(vaultConsistencyState)."
                )
            )
        }

        return signals
    }

    public static func replayDisposition(
        for brainState: BASCurrentBrainState
    ) -> BASReplayDisposition {
        let markers = Set(
            brainState.retrievalTags
            + brainState.verificationSnapshot
                .split(separator: "|")
                .map(String.init)
        )
        let forgetRequestID = markers
            .first(where: { $0.hasPrefix("forget_request:") })
            .map { String($0.dropFirst("forget_request:".count)) }
            ?? markers
                .first(where: { $0.hasPrefix("forget:") })
                .map { String($0.dropFirst("forget:".count)) }
        let forgetVerified = markers.contains("forget_verified:true")
        let checkpointsRevoked = markers.contains("forget_checkpoints_revoked:true")
            || markers.contains("forget_checkpoint_exports_revoked:true")
        let syncExportsRevoked = markers.contains("forget_sync_exports_revoked:true")
        let vaultConsistencyState = markers
            .first(where: { $0.hasPrefix("vault_consistency:") })
            .map { String($0.dropFirst("vault_consistency:".count)) }
        let vaultDeletionManifestID = markers
            .first(where: { $0.hasPrefix("vault_deletion_manifest:") })
            .map { String($0.dropFirst("vault_deletion_manifest:".count)) }
        let vaultSyncRevocationCount = markers
            .first(where: { $0.hasPrefix("vault_sync_revocations:") })
            .flatMap { Int($0.dropFirst("vault_sync_revocations:".count)) }
            ?? 0
        let vaultRequiresApproval = markers.contains("vault_requires_approval:true")
        let vaultOutOfSyncDeviceIDs = markers
            .first(where: { $0.hasPrefix("vault_out_of_sync_list:") })
            .map { String($0.dropFirst("vault_out_of_sync_list:".count)) }
            .map { value in
                value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            ?? []
        let vaultMigrationTargetDeviceID = markers
            .first(where: { $0.hasPrefix("vault_migration_target:") })
            .map { String($0.dropFirst("vault_migration_target:".count)) }

        let vaultConsistencyBlocksReplay =
            vaultConsistencyState == "revocation_pending" ||
            vaultConsistencyState == "out_of_sync" ||
            vaultConsistencyState == "migration_pending"

        guard (forgetVerified && (checkpointsRevoked || syncExportsRevoked)) || vaultConsistencyBlocksReplay else {
            return BASReplayDisposition(
                isAvailable: true,
                forgetRequestID: forgetRequestID,
                checkpointsRevoked: checkpointsRevoked,
                syncExportsRevoked: syncExportsRevoked,
                vaultConsistencyState: vaultConsistencyState,
                vaultDeletionManifestID: vaultDeletionManifestID,
                vaultSyncRevocationCount: vaultSyncRevocationCount,
                vaultRequiresApproval: vaultRequiresApproval,
                vaultOutOfSyncDeviceIDs: vaultOutOfSyncDeviceIDs,
                vaultMigrationTargetDeviceID: vaultMigrationTargetDeviceID
            )
        }

        let vaultReason: String?
        if vaultConsistencyBlocksReplay {
            let manifestSummary = vaultDeletionManifestID.map { " for deletion manifest \($0)" } ?? ""
            let approvalSummary = vaultRequiresApproval ? " Explicit approval is still required." : ""
            let outOfSyncSummary = vaultOutOfSyncDeviceIDs.isEmpty
                ? ""
                : " Out-of-sync devices: \(vaultOutOfSyncDeviceIDs.joined(separator: ", "))."
            let migrationSummary = vaultMigrationTargetDeviceID.map { " Migration target: \($0)." } ?? ""
            vaultReason = "Replay blocked while host constitution vault consistency is \(vaultConsistencyState ?? "unavailable")\(manifestSummary).\((vaultSyncRevocationCount > 0) ? " Sync revocations pending: \(vaultSyncRevocationCount)." : "")\(outOfSyncSummary)\(migrationSummary)\(approvalSummary)"
        } else {
            vaultReason = nil
        }

        let revokedScopes = [
            checkpointsRevoked ? "checkpoint exports" : nil,
            syncExportsRevoked ? "sync exports" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " and ")
        let requestID = forgetRequestID ?? "unknown"
        return BASReplayDisposition(
            isAvailable: false,
            reason: vaultReason ?? "Replay revoked by forget gate \(requestID) after \(revokedScopes).",
            forgetRequestID: forgetRequestID,
            checkpointsRevoked: checkpointsRevoked,
            syncExportsRevoked: syncExportsRevoked,
            vaultConsistencyState: vaultConsistencyState,
            vaultDeletionManifestID: vaultDeletionManifestID,
            vaultSyncRevocationCount: vaultSyncRevocationCount,
            vaultRequiresApproval: vaultRequiresApproval,
            vaultOutOfSyncDeviceIDs: vaultOutOfSyncDeviceIDs,
            vaultMigrationTargetDeviceID: vaultMigrationTargetDeviceID
        )
    }

    public static func inspectionBundle(
        generatedAt: Date = .now,
        trace: BASExecutionTrace,
        brainState: BASCurrentBrainState,
        runtimeContext: BASRuntimeContext,
        policyDecision: BASPolicyDecisionRecord,
        calibration: BASInspectionCalibrationSummary? = nil
    ) -> BASInspectionBundle {
        let replayDisposition = replayDisposition(for: brainState)
        let replayBundle = BASReplayBundle(
            trace: trace,
            brainState: brainState,
            runtimeContext: runtimeContext,
            policyDecision: policyDecision,
            replayDisposition: replayDisposition
        )
        return BASInspectionBundle(
            generatedAt: generatedAt,
            trace: trace,
            replayFingerprint: replayFingerprint(for: replayBundle),
            replayDisposition: replayDisposition,
            releaseDecision: releaseDecision(for: trace, policyDecision: policyDecision),
            anomalySignals: anomalySignals(
                for: trace,
                policyDecision: policyDecision,
                replayDisposition: replayDisposition
            ),
            calibration: calibration
        )
    }
}

public struct BASLifecycleTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var hasContextState: Bool
    public var generation: Int?
    public var rebuiltSession: Bool
    public var staleFieldCount: Int
    public var anchorFieldCount: Int
    public var hasFrontstageState: Bool
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int

    public init(
        kind: String,
        hasContextState: Bool,
        generation: Int?,
        rebuiltSession: Bool,
        staleFieldCount: Int,
        anchorFieldCount: Int,
        hasFrontstageState: Bool,
        retainedEvidenceCount: Int,
        droppedEvidenceCount: Int,
        droppedInjectedEvidenceCount: Int,
        droppedDuplicateEvidenceCount: Int,
        droppedBudgetEvidenceCount: Int
    ) {
        self.kind = kind
        self.hasContextState = hasContextState
        self.generation = generation
        self.rebuiltSession = rebuiltSession
        self.staleFieldCount = staleFieldCount
        self.anchorFieldCount = anchorFieldCount
        self.hasFrontstageState = hasFrontstageState
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
    }
}

public struct BASLifecycleSummary: Codable, Sendable, Equatable {
    public var contextAwareTraceCount: Int
    public var rebuildCount: Int
    public var rebuildCountByKind: [String: Int]
    public var staleFieldDropCount: Int
    public var staleFieldDropCountByKind: [String: Int]
    public var retainedEvidenceCount: Int
    public var retainedEvidenceCountByKind: [String: Int]
    public var droppedEvidenceCount: Int
    public var droppedEvidenceCountByKind: [String: Int]
    public var droppedInjectedEvidenceCount: Int
    public var droppedInjectedEvidenceCountByKind: [String: Int]
    public var droppedDuplicateEvidenceCount: Int
    public var droppedDuplicateEvidenceCountByKind: [String: Int]
    public var droppedBudgetEvidenceCount: Int
    public var droppedBudgetEvidenceCountByKind: [String: Int]
    public var averageRetainedEvidenceCountByKind: [String: Double]
    public var averageAnchorFieldCountByKind: [String: Double]
    public var latestGenerationByKind: [String: Int]

    public init(
        contextAwareTraceCount: Int,
        rebuildCount: Int,
        rebuildCountByKind: [String: Int],
        staleFieldDropCount: Int,
        staleFieldDropCountByKind: [String: Int],
        retainedEvidenceCount: Int,
        retainedEvidenceCountByKind: [String: Int],
        droppedEvidenceCount: Int,
        droppedEvidenceCountByKind: [String: Int],
        droppedInjectedEvidenceCount: Int,
        droppedInjectedEvidenceCountByKind: [String: Int],
        droppedDuplicateEvidenceCount: Int,
        droppedDuplicateEvidenceCountByKind: [String: Int],
        droppedBudgetEvidenceCount: Int,
        droppedBudgetEvidenceCountByKind: [String: Int],
        averageRetainedEvidenceCountByKind: [String: Double],
        averageAnchorFieldCountByKind: [String: Double],
        latestGenerationByKind: [String: Int]
    ) {
        self.contextAwareTraceCount = contextAwareTraceCount
        self.rebuildCount = rebuildCount
        self.rebuildCountByKind = rebuildCountByKind
        self.staleFieldDropCount = staleFieldDropCount
        self.staleFieldDropCountByKind = staleFieldDropCountByKind
        self.retainedEvidenceCount = retainedEvidenceCount
        self.retainedEvidenceCountByKind = retainedEvidenceCountByKind
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedEvidenceCountByKind = droppedEvidenceCountByKind
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedInjectedEvidenceCountByKind = droppedInjectedEvidenceCountByKind
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedDuplicateEvidenceCountByKind = droppedDuplicateEvidenceCountByKind
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
        self.droppedBudgetEvidenceCountByKind = droppedBudgetEvidenceCountByKind
        self.averageRetainedEvidenceCountByKind = averageRetainedEvidenceCountByKind
        self.averageAnchorFieldCountByKind = averageAnchorFieldCountByKind
        self.latestGenerationByKind = latestGenerationByKind
    }
}

public enum BASLifecycleSummaryBuilder {
    public static func build(from traces: [BASLifecycleTraceInput]) -> BASLifecycleSummary {
        let contextAwareTraces = traces.filter(\.hasContextState)
        let frontstageTraces = traces.filter(\.hasFrontstageState)

        return BASLifecycleSummary(
            contextAwareTraceCount: contextAwareTraces.count,
            rebuildCount: contextAwareTraces.filter(\.rebuiltSession).count,
            rebuildCountByKind: countByKind(
                from: traces.filter { $0.rebuiltSession }
            ),
            staleFieldDropCount: contextAwareTraces.reduce(0) { $0 + $1.staleFieldCount },
            staleFieldDropCountByKind: sumByKind(from: traces, value: \.staleFieldCount),
            retainedEvidenceCount: traces.reduce(0) { $0 + $1.retainedEvidenceCount },
            retainedEvidenceCountByKind: sumByKind(from: traces, value: \.retainedEvidenceCount),
            droppedEvidenceCount: traces.reduce(0) { $0 + $1.droppedEvidenceCount },
            droppedEvidenceCountByKind: sumByKind(from: traces, value: \.droppedEvidenceCount),
            droppedInjectedEvidenceCount: traces.reduce(0) { $0 + $1.droppedInjectedEvidenceCount },
            droppedInjectedEvidenceCountByKind: sumByKind(from: traces, value: \.droppedInjectedEvidenceCount),
            droppedDuplicateEvidenceCount: traces.reduce(0) { $0 + $1.droppedDuplicateEvidenceCount },
            droppedDuplicateEvidenceCountByKind: sumByKind(from: traces, value: \.droppedDuplicateEvidenceCount),
            droppedBudgetEvidenceCount: traces.reduce(0) { $0 + $1.droppedBudgetEvidenceCount },
            droppedBudgetEvidenceCountByKind: sumByKind(from: traces, value: \.droppedBudgetEvidenceCount),
            averageRetainedEvidenceCountByKind: averageLifecycleByKind(from: frontstageTraces, value: { Double($0.retainedEvidenceCount) }),
            averageAnchorFieldCountByKind: averageLifecycleByKind(from: contextAwareTraces, value: { Double($0.anchorFieldCount) }),
            latestGenerationByKind: latestGenerationByKind(from: traces)
        )
    }
}

public struct BASNeuralTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var suppressedBehaviorCount: Int
    public var dominantActionRawValue: String?
    public var strongestSignalRawValue: String?

    public init(
        kind: String,
        suppressedBehaviorCount: Int,
        dominantActionRawValue: String?,
        strongestSignalRawValue: String?
    ) {
        self.kind = kind
        self.suppressedBehaviorCount = suppressedBehaviorCount
        self.dominantActionRawValue = dominantActionRawValue
        self.strongestSignalRawValue = strongestSignalRawValue
    }
}

public struct BASNeuralSummary: Codable, Sendable, Equatable {
    public var neuralTraceCount: Int
    public var suppressedBehaviorCount: Int
    public var dominantActionByKind: [String: String]
    public var strongestSignalByKind: [String: String]

    public init(
        neuralTraceCount: Int,
        suppressedBehaviorCount: Int,
        dominantActionByKind: [String: String],
        strongestSignalByKind: [String: String]
    ) {
        self.neuralTraceCount = neuralTraceCount
        self.suppressedBehaviorCount = suppressedBehaviorCount
        self.dominantActionByKind = dominantActionByKind
        self.strongestSignalByKind = strongestSignalByKind
    }
}

public enum BASNeuralSummaryBuilder {
    public static func build(from traces: [BASNeuralTraceInput]) -> BASNeuralSummary {
        BASNeuralSummary(
            neuralTraceCount: traces.count,
            suppressedBehaviorCount: traces.reduce(0) { $0 + $1.suppressedBehaviorCount },
            dominantActionByKind: firstValueByKind(from: traces.compactMap {
                guard let dominantActionRawValue = $0.dominantActionRawValue else { return nil }
                return ($0.kind, dominantActionRawValue)
            }),
            strongestSignalByKind: firstValueByKind(from: traces.compactMap {
                guard let strongestSignalRawValue = $0.strongestSignalRawValue else { return nil }
                return ($0.kind, strongestSignalRawValue)
            })
        )
    }
}

public struct BASBrainTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var dominantReactionWeight: BASReactionWeightKey
    public var profileCoreCount: Int
    public var activeGoalCount: Int
    public var relevantMemoryCount: Int
    public var loadedPromotedMemoryCount: Int
    public var loadedPendingMemoryCount: Int
    public var pendingCandidateCount: Int
    public var promotedRecordCount: Int
    public var screenedOutMemoryCount: Int
    public var loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var snapshotFingerprint: String
    public var lowTrustMemoryLoadRate: Double
    public var riskFlags: [BASBrainStateRiskFlag]
    public var identityRole: BASIdentityRole
    public var boundaryMode: BASBoundaryPolicyMode
    public var activeConstraints: [BASBoundaryConstraint]
    public var calibrationStatus: BASCalibrationStatus
    public var calibrationAlerts: [BASCalibrationAlert]
    public var evolutionCheckpointCount: Int
    public var evolutionPendingReviewCount: Int
    public var evolutionRollbackReady: Bool

    public init(
        kind: String,
        dominantReactionWeight: BASReactionWeightKey,
        profileCoreCount: Int,
        activeGoalCount: Int,
        relevantMemoryCount: Int,
        loadedPromotedMemoryCount: Int,
        loadedPendingMemoryCount: Int,
        pendingCandidateCount: Int,
        promotedRecordCount: Int,
        screenedOutMemoryCount: Int,
        loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int],
        screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int],
        snapshotFingerprint: String,
        lowTrustMemoryLoadRate: Double,
        riskFlags: [BASBrainStateRiskFlag],
        identityRole: BASIdentityRole,
        boundaryMode: BASBoundaryPolicyMode,
        activeConstraints: [BASBoundaryConstraint],
        calibrationStatus: BASCalibrationStatus,
        calibrationAlerts: [BASCalibrationAlert],
        evolutionCheckpointCount: Int,
        evolutionPendingReviewCount: Int,
        evolutionRollbackReady: Bool
    ) {
        self.kind = kind
        self.dominantReactionWeight = dominantReactionWeight
        self.profileCoreCount = profileCoreCount
        self.activeGoalCount = activeGoalCount
        self.relevantMemoryCount = relevantMemoryCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedRecordCount = promotedRecordCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.loadedEligibilityReasonCounts = loadedEligibilityReasonCounts
        self.screenedOutEligibilityReasonCounts = screenedOutEligibilityReasonCounts
        self.snapshotFingerprint = snapshotFingerprint
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.riskFlags = riskFlags
        self.identityRole = identityRole
        self.boundaryMode = boundaryMode
        self.activeConstraints = activeConstraints
        self.calibrationStatus = calibrationStatus
        self.calibrationAlerts = calibrationAlerts
        self.evolutionCheckpointCount = evolutionCheckpointCount
        self.evolutionPendingReviewCount = evolutionPendingReviewCount
        self.evolutionRollbackReady = evolutionRollbackReady
    }
}

public struct BASBrainSummary: Codable, Sendable, Equatable {
    public var brainTraceCount: Int
    public var dominantReactionWeightByKind: [String: BASReactionWeightKey]
    public var averageProfileCoreCountByKind: [String: Double]
    public var averageActiveGoalCountByKind: [String: Double]
    public var averageRelevantMemoryCountByKind: [String: Double]
    public var averageLoadedPromotedMemoryCountByKind: [String: Double]
    public var averageLoadedPendingMemoryCountByKind: [String: Double]
    public var averagePendingCandidateCountByKind: [String: Double]
    public var averagePromotedRecordCountByKind: [String: Double]
    public var averageScreenedOutMemoryCountByKind: [String: Double]
    public var loadedEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var screenedOutEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var pendingMemoryLoadRateByKind: [String: Double]
    public var retrievalRejectionRateByKind: [String: Double]
    public var latestSnapshotFingerprintByKind: [String: String]
    public var snapshotVariantCountByKind: [String: Int]
    public var lowTrustMemoryLoadRateByKind: [String: Double]
    public var riskFlagCountsByKind: [String: [BASBrainStateRiskFlag: Int]]
    public var identityRoleByKind: [String: BASIdentityRole]
    public var boundaryModeByKind: [String: BASBoundaryPolicyMode]
    public var boundaryConstraintCountsByKind: [String: [BASBoundaryConstraint: Int]]
    public var calibrationStatusByKind: [String: BASCalibrationStatus]
    public var calibrationAlertCountsByKind: [String: [BASCalibrationAlert: Int]]
    public var evolutionCheckpointCountByKind: [String: Double]
    public var evolutionPendingReviewCountByKind: [String: Double]
    public var evolutionRollbackReadyByKind: [String: Bool]

    public init(
        brainTraceCount: Int,
        dominantReactionWeightByKind: [String: BASReactionWeightKey],
        averageProfileCoreCountByKind: [String: Double],
        averageActiveGoalCountByKind: [String: Double],
        averageRelevantMemoryCountByKind: [String: Double],
        averageLoadedPromotedMemoryCountByKind: [String: Double],
        averageLoadedPendingMemoryCountByKind: [String: Double],
        averagePendingCandidateCountByKind: [String: Double],
        averagePromotedRecordCountByKind: [String: Double],
        averageScreenedOutMemoryCountByKind: [String: Double],
        loadedEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]],
        screenedOutEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]],
        pendingMemoryLoadRateByKind: [String: Double],
        retrievalRejectionRateByKind: [String: Double],
        latestSnapshotFingerprintByKind: [String: String],
        snapshotVariantCountByKind: [String: Int],
        lowTrustMemoryLoadRateByKind: [String: Double],
        riskFlagCountsByKind: [String: [BASBrainStateRiskFlag: Int]],
        identityRoleByKind: [String: BASIdentityRole],
        boundaryModeByKind: [String: BASBoundaryPolicyMode],
        boundaryConstraintCountsByKind: [String: [BASBoundaryConstraint: Int]],
        calibrationStatusByKind: [String: BASCalibrationStatus],
        calibrationAlertCountsByKind: [String: [BASCalibrationAlert: Int]],
        evolutionCheckpointCountByKind: [String: Double],
        evolutionPendingReviewCountByKind: [String: Double],
        evolutionRollbackReadyByKind: [String: Bool]
    ) {
        self.brainTraceCount = brainTraceCount
        self.dominantReactionWeightByKind = dominantReactionWeightByKind
        self.averageProfileCoreCountByKind = averageProfileCoreCountByKind
        self.averageActiveGoalCountByKind = averageActiveGoalCountByKind
        self.averageRelevantMemoryCountByKind = averageRelevantMemoryCountByKind
        self.averageLoadedPromotedMemoryCountByKind = averageLoadedPromotedMemoryCountByKind
        self.averageLoadedPendingMemoryCountByKind = averageLoadedPendingMemoryCountByKind
        self.averagePendingCandidateCountByKind = averagePendingCandidateCountByKind
        self.averagePromotedRecordCountByKind = averagePromotedRecordCountByKind
        self.averageScreenedOutMemoryCountByKind = averageScreenedOutMemoryCountByKind
        self.loadedEligibilityReasonCountsByKind = loadedEligibilityReasonCountsByKind
        self.screenedOutEligibilityReasonCountsByKind = screenedOutEligibilityReasonCountsByKind
        self.pendingMemoryLoadRateByKind = pendingMemoryLoadRateByKind
        self.retrievalRejectionRateByKind = retrievalRejectionRateByKind
        self.latestSnapshotFingerprintByKind = latestSnapshotFingerprintByKind
        self.snapshotVariantCountByKind = snapshotVariantCountByKind
        self.lowTrustMemoryLoadRateByKind = lowTrustMemoryLoadRateByKind
        self.riskFlagCountsByKind = riskFlagCountsByKind
        self.identityRoleByKind = identityRoleByKind
        self.boundaryModeByKind = boundaryModeByKind
        self.boundaryConstraintCountsByKind = boundaryConstraintCountsByKind
        self.calibrationStatusByKind = calibrationStatusByKind
        self.calibrationAlertCountsByKind = calibrationAlertCountsByKind
        self.evolutionCheckpointCountByKind = evolutionCheckpointCountByKind
        self.evolutionPendingReviewCountByKind = evolutionPendingReviewCountByKind
        self.evolutionRollbackReadyByKind = evolutionRollbackReadyByKind
    }
}

public enum BASBrainSummaryBuilder {
    public static func build(from traces: [BASBrainTraceInput]) -> BASBrainSummary {
        BASBrainSummary(
            brainTraceCount: traces.count,
            dominantReactionWeightByKind: firstValueByKind(from: traces.map { ($0.kind, $0.dominantReactionWeight) }),
            averageProfileCoreCountByKind: averageBrainByKind(from: traces, value: { Double($0.profileCoreCount) }),
            averageActiveGoalCountByKind: averageBrainByKind(from: traces, value: { Double($0.activeGoalCount) }),
            averageRelevantMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.relevantMemoryCount) }),
            averageLoadedPromotedMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.loadedPromotedMemoryCount) }),
            averageLoadedPendingMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.loadedPendingMemoryCount) }),
            averagePendingCandidateCountByKind: averageBrainByKind(from: traces, value: { Double($0.pendingCandidateCount) }),
            averagePromotedRecordCountByKind: averageBrainByKind(from: traces, value: { Double($0.promotedRecordCount) }),
            averageScreenedOutMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.screenedOutMemoryCount) }),
            loadedEligibilityReasonCountsByKind: aggregatedCountMapByKind(from: traces, value: \.loadedEligibilityReasonCounts),
            screenedOutEligibilityReasonCountsByKind: aggregatedCountMapByKind(from: traces, value: \.screenedOutEligibilityReasonCounts),
            pendingMemoryLoadRateByKind: ratioByKind(
                numerator: averageBrainByKind(from: traces, value: { Double($0.loadedPendingMemoryCount) }),
                denominatorAugend: averageBrainByKind(from: traces, value: { Double($0.loadedPromotedMemoryCount) })
            ),
            retrievalRejectionRateByKind: ratioByKind(
                numerator: averageBrainByKind(from: traces, value: { Double($0.screenedOutMemoryCount) }),
                denominatorAugend: averageBrainByKind(from: traces, value: { Double($0.relevantMemoryCount) })
            ),
            // audit policy-obs-misc LOW-4: the field is the LATEST snapshot per kind, so take the LAST
            // (newest) of the oldest-first trace array — firstValueByKind returned the OLDEST.
            latestSnapshotFingerprintByKind: lastValueByKind(from: traces.map { ($0.kind, $0.snapshotFingerprint) }),
            snapshotVariantCountByKind: variantCountByKind(from: traces.map { ($0.kind, $0.snapshotFingerprint) }),
            lowTrustMemoryLoadRateByKind: averageBrainByKind(from: traces, value: \.lowTrustMemoryLoadRate),
            riskFlagCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.riskFlags),
            identityRoleByKind: firstValueByKind(from: traces.map { ($0.kind, $0.identityRole) }),
            boundaryModeByKind: firstValueByKind(from: traces.map { ($0.kind, $0.boundaryMode) }),
            boundaryConstraintCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.activeConstraints),
            calibrationStatusByKind: firstValueByKind(from: traces.map { ($0.kind, $0.calibrationStatus) }),
            calibrationAlertCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.calibrationAlerts),
            evolutionCheckpointCountByKind: averageBrainByKind(from: traces, value: { Double($0.evolutionCheckpointCount) }),
            evolutionPendingReviewCountByKind: averageBrainByKind(from: traces, value: { Double($0.evolutionPendingReviewCount) }),
            evolutionRollbackReadyByKind: containsTrueByKind(from: traces, value: \.evolutionRollbackReady)
        )
    }
}

public struct BASRuntimeInspectionTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var attemptedProviderIDs: [String]
    public var runtimeStrategy: BASAdaptiveTaskStrategy?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var consistencyChecked: Bool
    public var consistencyRejected: Bool
    public var consistencyViolationKinds: [BASConsistencyViolationKind]

    public init(
        kind: String,
        attemptedProviderIDs: [String],
        runtimeStrategy: BASAdaptiveTaskStrategy? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        consistencyChecked: Bool = false,
        consistencyRejected: Bool = false,
        consistencyViolationKinds: [BASConsistencyViolationKind] = []
    ) {
        self.kind = kind
        self.attemptedProviderIDs = attemptedProviderIDs
        self.runtimeStrategy = runtimeStrategy
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.consistencyChecked = consistencyChecked
        self.consistencyRejected = consistencyRejected
        self.consistencyViolationKinds = consistencyViolationKinds
    }
}

public struct BASRuntimeInspectionInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var strategyByKind: [String: BASAdaptiveTaskStrategy]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var traceInputs: [BASRuntimeInspectionTraceInput]
    public var telemetrySummary: BASTelemetrySummary
    public var lifecycleSummary: BASLifecycleSummary
    public var neuralSummary: BASNeuralSummary
    public var brainSummary: BASBrainSummary
    public var totalCacheEntries: Int
    public var totalCacheLookupCount: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var traceCount: Int
    public var replayCount: Int

    public init(
        activeProviderID: String,
        fallbackProviderID: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        taskEntropyByKind: [String: BASTaskEntropyClass],
        preferredProviderRawValueByKind: [String: String],
        strategyByKind: [String: BASAdaptiveTaskStrategy],
        effectivePreferredProviderRawValueByKind: [String: String],
        traceInputs: [BASRuntimeInspectionTraceInput],
        telemetrySummary: BASTelemetrySummary,
        lifecycleSummary: BASLifecycleSummary,
        neuralSummary: BASNeuralSummary,
        brainSummary: BASBrainSummary,
        totalCacheEntries: Int,
        totalCacheLookupCount: Int,
        totalCacheRejectedStores: Int,
        totalCacheQuarantinedHits: Int,
        dominantBackendID: String?,
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeCircuitProviderIDs: [String],
        circuitTripCount: Int,
        circuitTripCountByProvider: [String: Int],
        circuitTripCountByReason: [String: Int],
        traceCount: Int,
        replayCount: Int
    ) {
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.taskEntropyByKind = taskEntropyByKind
        self.preferredProviderRawValueByKind = preferredProviderRawValueByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderRawValueByKind = effectivePreferredProviderRawValueByKind
        self.traceInputs = traceInputs
        self.telemetrySummary = telemetrySummary
        self.lifecycleSummary = lifecycleSummary
        self.neuralSummary = neuralSummary
        self.brainSummary = brainSummary
        self.totalCacheEntries = totalCacheEntries
        self.totalCacheLookupCount = totalCacheLookupCount
        self.totalCacheRejectedStores = totalCacheRejectedStores
        self.totalCacheQuarantinedHits = totalCacheQuarantinedHits
        self.dominantBackendID = dominantBackendID
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeCircuitProviderIDs = activeCircuitProviderIDs
        self.circuitTripCount = circuitTripCount
        self.circuitTripCountByProvider = circuitTripCountByProvider
        self.circuitTripCountByReason = circuitTripCountByReason
        self.traceCount = traceCount
        self.replayCount = replayCount
    }
}

public struct BASRuntimeInspectionSummary: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var runtimeGearByKind: [String: BASRuntimeGear]
    public var allowsModelInvocationByKind: [String: Bool]
    public var contextBudgetByKind: [String: Int]
    public var outputCharacterBudgetByKind: [String: Int]
    public var timeBudgetMsByKind: [String: Int]
    public var toolCallBudgetByKind: [String: Int]
    public var retrievalItemBudgetByKind: [String: Int]
    public var retrievalModeByKind: [String: BASRetrievalMode]
    public var thinkingModeByKind: [String: BASThinkingMode]
    public var outputModeByKind: [String: BASOutputMode]
    public var toneByKind: [String: BASToneProfile]
    public var actionSpaceByKind: [String: [String]]
    public var responseLanguageByKind: [String: BASAdaptiveResponseLanguage]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var effectiveRuntimeGearByKind: [String: BASRuntimeGear]
    public var effectiveContextBudgetByKind: [String: Int]
    public var effectiveOutputCharacterBudgetByKind: [String: Int]
    public var effectiveTimeBudgetMsByKind: [String: Int]
    public var effectiveToolCallBudgetByKind: [String: Int]
    public var effectiveRetrievalItemBudgetByKind: [String: Int]
    public var effectiveRetrievalModeByKind: [String: BASRetrievalMode]
    public var effectiveThinkingModeByKind: [String: BASThinkingMode]
    public var effectiveOutputModeByKind: [String: BASOutputMode]
    public var effectiveToneByKind: [String: BASToneProfile]
    public var effectiveActionSpaceByKind: [String: [String]]
    public var effectiveResponseLanguageByKind: [String: BASAdaptiveResponseLanguage]
    public var firstAttemptedProviderByKind: [String: String]
    public var effectiveProviderOrderByKind: [String: [String]]
    public var totalRequests: Int
    public var totalProviderAttempts: Int
    public var cacheHitRate: Double
    public var admissionSkipRate: Double
    public var providerBypassRate: Double
    public var providerBypassRateByKind: [String: Double]
    public var lowPressureModelCallRate: Double
    public var lowPressureModelCallRateByKind: [String: Double]
    public var avoidableModelCallRate: Double
    public var avoidableModelCallRateByKind: [String: Double]
    public var selectionRequestCount: Int
    public var selectionKnowledgeNeedRate: Double
    public var selectionControlOnlyRate: Double
    public var selectionRetrievalBypassRate: Double
    public var deterministicFallbackRate: Double
    public var averageRequestDurationMs: Double
    public var averageRequestDurationMsByKind: [String: Double]
    public var averageFirstPresentableMs: Double
    public var averageFirstPresentableMsByKind: [String: Double]
    public var averagePromptAssemblyMsByKind: [String: Double]
    public var averageAdmissionEvaluationMsByKind: [String: Double]
    public var averageProviderSelectionMsByKind: [String: Double]
    public var averageExecutionMsByKind: [String: Double]
    public var averagePrefillEquivalentShareByKind: [String: Double]
    public var averageRequestDurationMsByActiveProvider: [String: Double]
    public var averageRequestDurationMsByBackend: [String: Double]
    public var averagePromptCharactersByKind: [String: Double]
    public var averagePrefixCharactersByKind: [String: Double]
    public var averageImmutablePrefixCharactersByKind: [String: Double]
    public var averageAdaptivePrefixCharactersByKind: [String: Double]
    public var averageSuffixCharactersByKind: [String: Double]
    public var averageStablePrefixShareByKind: [String: Double]
    public var semanticPromptVariantCountByKind: [String: Int]
    public var semanticPromptReuseRateByKind: [String: Double]
    public var stablePrefixVariantCountByKind: [String: Int]
    public var stablePrefixReuseRateByKind: [String: Double]
    public var stablePrefixPollutionRateByKind: [String: Double]
    public var slowRequestRate: Double
    public var slowRequestRateByKind: [String: Double]
    public var overTimeBudgetRate: Double
    public var overTimeBudgetRateByKind: [String: Double]
    public var overTargetBudgetRate: Double
    public var fallbackActivations: Int
    public var admissionSkipCount: Int
    public var contextAwareTraceCount: Int
    public var lifecycleRebuildCount: Int
    public var staleFieldDropCount: Int
    public var retainedEvidenceCount: Int
    public var evidenceRetentionRatio: Double
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int
    public var evidencePollutionRate: Double
    public var evidencePollutionRateByKind: [String: Double]
    public var duplicateEvidenceDropRate: Double
    public var duplicateEvidenceDropRateByKind: [String: Double]
    public var budgetTrimRate: Double
    public var budgetTrimRateByKind: [String: Double]
    public var neuralTraceCount: Int
    public var suppressedBehaviorCount: Int
    public var brainTraceCount: Int
    public var dominantReactionWeightByKind: [String: BASReactionWeightKey]
    public var loadedEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var screenedOutEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var pendingMemoryLoadRateByKind: [String: Double]
    public var retrievalRejectionRateByKind: [String: Double]
    public var brainSnapshotFingerprintByKind: [String: String]
    public var brainSnapshotVariantCountByKind: [String: Int]
    public var lowTrustMemoryLoadRateByKind: [String: Double]
    public var brainRiskFlagCountsByKind: [String: [BASBrainStateRiskFlag: Int]]
    public var identityRoleByKind: [String: BASIdentityRole]
    public var boundaryModeByKind: [String: BASBoundaryPolicyMode]
    public var boundaryConstraintCountsByKind: [String: [BASBoundaryConstraint: Int]]
    public var calibrationStatusByKind: [String: BASCalibrationStatus]
    public var calibrationAlertCountsByKind: [String: [BASCalibrationAlert: Int]]
    public var evolutionCheckpointCountByKind: [String: Double]
    public var evolutionPendingReviewCountByKind: [String: Double]
    public var evolutionRollbackReadyByKind: [String: Bool]
    public var traceCount: Int
    public var replayCount: Int
    public var totalCacheEntries: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var cacheQuarantineRate: Double
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var circuitOpenProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var consistencyCheckedTraceCount: Int
    public var consistencyRejectedTraceCount: Int
    public var consistencyCheckCoverageRate: Double
    public var consistencyRejectRate: Double
    public var consistencyRejectedCountByKind: [String: Int]
    public var consistencyViolationCounts: [BASConsistencyViolationKind: Int]
}

public enum BASRuntimeInspectionBuilder {
    public static func build(from input: BASRuntimeInspectionInput) -> BASRuntimeInspectionSummary {
        let effectiveStrategiesByKind = firstStrategyByKind(from: input.traceInputs)
        let semanticPromptVariantCountByKind = variantCountByKind(
            from: input.traceInputs.compactMap { trace in
                trace.semanticPromptFingerprint.map { (trace.kind, $0) }
            }
        )
        let stablePrefixVariantCountByKind = variantCountByKind(
            from: input.traceInputs.compactMap { trace in
                trace.stablePrefixFingerprint.map { (trace.kind, $0) }
            }
        )
        let firstAttemptedProviderByKind = firstAttemptedProviderByKind(from: input.traceInputs)
        let effectiveProviderOrderByKind = effectiveProviderOrderByKind(from: input.traceInputs)
        let consistencyCheckedTraceCount = input.traceInputs.filter(\.consistencyChecked).count
        let consistencyRejectedTraceCount = input.traceInputs.filter(\.consistencyRejected).count
        let consistencyRejectedCountByKind = Dictionary(
            grouping: input.traceInputs.filter(\.consistencyRejected),
            by: \.kind
        )
        .mapValues(\.count)
        let consistencyViolationCounts = input.traceInputs
            .flatMap(\.consistencyViolationKinds)
            .reduce(into: [BASConsistencyViolationKind: Int]()) { partialResult, kind in
                partialResult[kind, default: 0] += 1
            }

        return BASRuntimeInspectionSummary(
            activeProviderID: input.activeProviderID,
            fallbackProviderID: input.fallbackProviderID,
            runtimeGear: input.runtimeGear,
            environmentClass: input.environmentClass,
            deviceClass: input.deviceClass,
            languageMode: input.languageMode,
            taskEntropyByKind: input.taskEntropyByKind,
            preferredProviderRawValueByKind: input.preferredProviderRawValueByKind,
            runtimeGearByKind: strategyMap(input.strategyByKind, value: \.runtimeGear),
            allowsModelInvocationByKind: strategyMap(input.strategyByKind, value: \.allowsModelInvocation),
            contextBudgetByKind: strategyMap(input.strategyByKind, value: \.contextBudget),
            outputCharacterBudgetByKind: strategyMap(input.strategyByKind, value: \.outputCharacterBudget),
            timeBudgetMsByKind: strategyMap(input.strategyByKind, value: \.timeBudgetMs),
            toolCallBudgetByKind: strategyMap(input.strategyByKind, value: \.toolCallBudget),
            retrievalItemBudgetByKind: strategyMap(input.strategyByKind, value: \.retrievalItemBudget),
            retrievalModeByKind: strategyMap(input.strategyByKind, value: \.retrievalMode),
            thinkingModeByKind: strategyMap(input.strategyByKind, value: \.thinkingMode),
            outputModeByKind: strategyMap(input.strategyByKind, value: \.outputMode),
            toneByKind: strategyMap(input.strategyByKind, value: \.tone),
            actionSpaceByKind: strategyMap(input.strategyByKind, value: \.actionSpace),
            responseLanguageByKind: strategyMap(input.strategyByKind, value: \.responseLanguage),
            effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderRawValueByKind,
            effectiveRuntimeGearByKind: strategyMap(effectiveStrategiesByKind, value: \.runtimeGear),
            effectiveContextBudgetByKind: strategyMap(effectiveStrategiesByKind, value: \.contextBudget),
            effectiveOutputCharacterBudgetByKind: strategyMap(effectiveStrategiesByKind, value: \.outputCharacterBudget),
            effectiveTimeBudgetMsByKind: strategyMap(effectiveStrategiesByKind, value: \.timeBudgetMs),
            effectiveToolCallBudgetByKind: strategyMap(effectiveStrategiesByKind, value: \.toolCallBudget),
            effectiveRetrievalItemBudgetByKind: strategyMap(effectiveStrategiesByKind, value: \.retrievalItemBudget),
            effectiveRetrievalModeByKind: strategyMap(effectiveStrategiesByKind, value: \.retrievalMode),
            effectiveThinkingModeByKind: strategyMap(effectiveStrategiesByKind, value: \.thinkingMode),
            effectiveOutputModeByKind: strategyMap(effectiveStrategiesByKind, value: \.outputMode),
            effectiveToneByKind: strategyMap(effectiveStrategiesByKind, value: \.tone),
            effectiveActionSpaceByKind: strategyMap(effectiveStrategiesByKind, value: \.actionSpace),
            effectiveResponseLanguageByKind: strategyMap(effectiveStrategiesByKind, value: \.responseLanguage),
            firstAttemptedProviderByKind: firstAttemptedProviderByKind,
            effectiveProviderOrderByKind: effectiveProviderOrderByKind,
            totalRequests: input.telemetrySummary.totalRequests,
            totalProviderAttempts: input.telemetrySummary.totalProviderAttempts,
            cacheHitRate: input.telemetrySummary.cacheHitRate,
            admissionSkipRate: input.telemetrySummary.admissionSkipRate,
            providerBypassRate: input.telemetrySummary.providerBypassRate,
            providerBypassRateByKind: input.telemetrySummary.providerBypassRateByKind,
            lowPressureModelCallRate: input.telemetrySummary.lowPressureModelCallRate,
            lowPressureModelCallRateByKind: input.telemetrySummary.lowPressureModelCallRateByKind,
            avoidableModelCallRate: input.telemetrySummary.avoidableModelCallRate,
            avoidableModelCallRateByKind: input.telemetrySummary.avoidableModelCallRateByKind,
            selectionRequestCount: input.telemetrySummary.selectionRequestCount,
            selectionKnowledgeNeedRate: input.telemetrySummary.selectionKnowledgeNeedRate,
            selectionControlOnlyRate: input.telemetrySummary.selectionControlOnlyRate,
            selectionRetrievalBypassRate: input.telemetrySummary.selectionRetrievalBypassRate,
            deterministicFallbackRate: input.telemetrySummary.deterministicFallbackRate,
            averageRequestDurationMs: input.telemetrySummary.averageRequestDurationMs,
            averageRequestDurationMsByKind: input.telemetrySummary.averageRequestDurationMsByKind,
            averageFirstPresentableMs: input.telemetrySummary.averageFirstPresentableMs,
            averageFirstPresentableMsByKind: input.telemetrySummary.averageFirstPresentableMsByKind,
            averagePromptAssemblyMsByKind: input.telemetrySummary.averagePromptAssemblyMsByKind,
            averageAdmissionEvaluationMsByKind: input.telemetrySummary.averageAdmissionEvaluationMsByKind,
            averageProviderSelectionMsByKind: input.telemetrySummary.averageProviderSelectionMsByKind,
            averageExecutionMsByKind: input.telemetrySummary.averageExecutionMsByKind,
            averagePrefillEquivalentShareByKind: input.telemetrySummary.averagePrefillEquivalentShareByKind,
            averageRequestDurationMsByActiveProvider: input.telemetrySummary.averageRequestDurationMsByActiveProvider,
            averageRequestDurationMsByBackend: input.telemetrySummary.averageRequestDurationMsByBackend,
            averagePromptCharactersByKind: input.telemetrySummary.averagePromptCharactersByKind,
            averagePrefixCharactersByKind: input.telemetrySummary.averagePrefixCharactersByKind,
            averageImmutablePrefixCharactersByKind: input.telemetrySummary.averageImmutablePrefixCharactersByKind,
            averageAdaptivePrefixCharactersByKind: input.telemetrySummary.averageAdaptivePrefixCharactersByKind,
            averageSuffixCharactersByKind: input.telemetrySummary.averageSuffixCharactersByKind,
            averageStablePrefixShareByKind: input.telemetrySummary.averageStablePrefixShareByKind,
            semanticPromptVariantCountByKind: semanticPromptVariantCountByKind,
            semanticPromptReuseRateByKind: reuseRateByKind(
                requestCountByKind: input.telemetrySummary.input.requestCountByKind,
                variantCountByKind: semanticPromptVariantCountByKind
            ),
            stablePrefixVariantCountByKind: stablePrefixVariantCountByKind,
            stablePrefixReuseRateByKind: reuseRateByKind(
                requestCountByKind: input.telemetrySummary.input.requestCountByKind,
                variantCountByKind: stablePrefixVariantCountByKind
            ),
            stablePrefixPollutionRateByKind: stablePrefixPollutionRateByKind(
                requestCountByKind: input.telemetrySummary.input.requestCountByKind,
                stablePrefixVariantCountByKind: stablePrefixVariantCountByKind
            ),
            slowRequestRate: input.telemetrySummary.slowRequestRate,
            slowRequestRateByKind: input.telemetrySummary.slowRequestRateByKind,
            overTimeBudgetRate: input.telemetrySummary.overTimeBudgetRate,
            overTimeBudgetRateByKind: input.telemetrySummary.overTimeBudgetRateByKind,
            overTargetBudgetRate: input.telemetrySummary.overTargetBudgetRate,
            fallbackActivations: input.telemetrySummary.input.fallbackActivations,
            admissionSkipCount: input.telemetrySummary.input.outcomeCount[.admissionSkipped] ?? 0,
            contextAwareTraceCount: input.lifecycleSummary.contextAwareTraceCount,
            lifecycleRebuildCount: input.lifecycleSummary.rebuildCount,
            staleFieldDropCount: input.lifecycleSummary.staleFieldDropCount,
            retainedEvidenceCount: input.lifecycleSummary.retainedEvidenceCount,
            evidenceRetentionRatio: evidenceRetentionRatio(lifecycleSummary: input.lifecycleSummary),
            droppedEvidenceCount: input.lifecycleSummary.droppedEvidenceCount,
            droppedInjectedEvidenceCount: input.lifecycleSummary.droppedInjectedEvidenceCount,
            droppedDuplicateEvidenceCount: input.lifecycleSummary.droppedDuplicateEvidenceCount,
            droppedBudgetEvidenceCount: input.lifecycleSummary.droppedBudgetEvidenceCount,
            evidencePollutionRate: evidenceRate(
                numerator: input.lifecycleSummary.droppedInjectedEvidenceCount,
                retained: input.lifecycleSummary.retainedEvidenceCount,
                dropped: input.lifecycleSummary.droppedEvidenceCount
            ),
            evidencePollutionRateByKind: evidenceRateByKind(
                numeratorByKind: input.lifecycleSummary.droppedInjectedEvidenceCountByKind,
                retainedEvidenceCountByKind: input.lifecycleSummary.retainedEvidenceCountByKind,
                droppedEvidenceCountByKind: input.lifecycleSummary.droppedEvidenceCountByKind
            ),
            duplicateEvidenceDropRate: evidenceRate(
                numerator: input.lifecycleSummary.droppedDuplicateEvidenceCount,
                retained: input.lifecycleSummary.retainedEvidenceCount,
                dropped: input.lifecycleSummary.droppedEvidenceCount
            ),
            duplicateEvidenceDropRateByKind: evidenceRateByKind(
                numeratorByKind: input.lifecycleSummary.droppedDuplicateEvidenceCountByKind,
                retainedEvidenceCountByKind: input.lifecycleSummary.retainedEvidenceCountByKind,
                droppedEvidenceCountByKind: input.lifecycleSummary.droppedEvidenceCountByKind
            ),
            budgetTrimRate: evidenceRate(
                numerator: input.lifecycleSummary.droppedBudgetEvidenceCount,
                retained: input.lifecycleSummary.retainedEvidenceCount,
                dropped: input.lifecycleSummary.droppedEvidenceCount
            ),
            budgetTrimRateByKind: evidenceRateByKind(
                numeratorByKind: input.lifecycleSummary.droppedBudgetEvidenceCountByKind,
                retainedEvidenceCountByKind: input.lifecycleSummary.retainedEvidenceCountByKind,
                droppedEvidenceCountByKind: input.lifecycleSummary.droppedEvidenceCountByKind
            ),
            neuralTraceCount: input.neuralSummary.neuralTraceCount,
            suppressedBehaviorCount: input.neuralSummary.suppressedBehaviorCount,
            brainTraceCount: input.brainSummary.brainTraceCount,
            dominantReactionWeightByKind: input.brainSummary.dominantReactionWeightByKind,
            loadedEligibilityReasonCountsByKind: input.brainSummary.loadedEligibilityReasonCountsByKind,
            screenedOutEligibilityReasonCountsByKind: input.brainSummary.screenedOutEligibilityReasonCountsByKind,
            pendingMemoryLoadRateByKind: input.brainSummary.pendingMemoryLoadRateByKind,
            retrievalRejectionRateByKind: input.brainSummary.retrievalRejectionRateByKind,
            brainSnapshotFingerprintByKind: input.brainSummary.latestSnapshotFingerprintByKind,
            brainSnapshotVariantCountByKind: input.brainSummary.snapshotVariantCountByKind,
            lowTrustMemoryLoadRateByKind: input.brainSummary.lowTrustMemoryLoadRateByKind,
            brainRiskFlagCountsByKind: input.brainSummary.riskFlagCountsByKind,
            identityRoleByKind: input.brainSummary.identityRoleByKind,
            boundaryModeByKind: input.brainSummary.boundaryModeByKind,
            boundaryConstraintCountsByKind: input.brainSummary.boundaryConstraintCountsByKind,
            calibrationStatusByKind: input.brainSummary.calibrationStatusByKind,
            calibrationAlertCountsByKind: input.brainSummary.calibrationAlertCountsByKind,
            evolutionCheckpointCountByKind: input.brainSummary.evolutionCheckpointCountByKind,
            evolutionPendingReviewCountByKind: input.brainSummary.evolutionPendingReviewCountByKind,
            evolutionRollbackReadyByKind: input.brainSummary.evolutionRollbackReadyByKind,
            traceCount: input.traceCount,
            replayCount: input.replayCount,
            totalCacheEntries: input.totalCacheEntries,
            totalCacheRejectedStores: input.totalCacheRejectedStores,
            totalCacheQuarantinedHits: input.totalCacheQuarantinedHits,
            cacheQuarantineRate: inspectionRate(
                numerator: input.totalCacheQuarantinedHits,
                denominator: input.totalCacheLookupCount
            ),
            dominantBackendID: input.dominantBackendID,
            registeredProviderCount: input.registeredProviderCount,
            registeredOpenModelProviderCount: input.registeredOpenModelProviderCount,
            circuitOpenProviderCount: input.activeCircuitProviderIDs.count,
            activeCircuitProviderIDs: input.activeCircuitProviderIDs,
            circuitTripCount: input.circuitTripCount,
            circuitTripCountByProvider: input.circuitTripCountByProvider,
            circuitTripCountByReason: input.circuitTripCountByReason,
            consistencyCheckedTraceCount: consistencyCheckedTraceCount,
            consistencyRejectedTraceCount: consistencyRejectedTraceCount,
            consistencyCheckCoverageRate: inspectionRate(
                numerator: consistencyCheckedTraceCount,
                denominator: input.traceCount
            ),
            consistencyRejectRate: inspectionRate(
                numerator: consistencyRejectedTraceCount,
                denominator: consistencyCheckedTraceCount
            ),
            consistencyRejectedCountByKind: consistencyRejectedCountByKind,
            consistencyViolationCounts: consistencyViolationCounts
        )
    }
}

private func countByKind(
    from values: [BASLifecycleTraceInput]
) -> [String: Int] {
    Dictionary(grouping: values, by: \.kind).mapValues(\.count)
}

private func sumByKind(
    from values: [BASLifecycleTraceInput],
    value: KeyPath<BASLifecycleTraceInput, Int>
) -> [String: Int] {
    Dictionary(grouping: values, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(0) { $0 + $1[keyPath: value] }
        }
}

private func averageLifecycleByKind(
    from values: [BASLifecycleTraceInput],
    value: (BASLifecycleTraceInput) -> Double
) -> [String: Double] {
    Dictionary(grouping: values, by: \.kind)
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0.0) { partial, item in
                partial + value(item)
            }
            return total / Double(grouped.count)
        }
}

private func latestGenerationByKind(
    from traces: [BASLifecycleTraceInput]
) -> [String: Int] {
    traces.reduce(into: [String: Int]()) { partialResult, trace in
        guard let generation = trace.generation else { return }
        partialResult[trace.kind] = max(partialResult[trace.kind] ?? generation, generation)
    }
}

private func firstValueByKind<Value>(
    from pairs: [(String, Value)]
) -> [String: Value] {
    Dictionary(grouping: pairs, by: \.0)
        .compactMapValues { grouped in
            grouped.first?.1
        }
}

/// audit policy-obs-misc LOW-4 — sibling of firstValueByKind for the "latest" fields: takes the LAST
/// (newest) value per kind from an oldest-first pair list. `Dictionary(grouping:)` preserves array
/// order, so `.last` is the most recent.
private func lastValueByKind<Value>(
    from pairs: [(String, Value)]
) -> [String: Value] {
    Dictionary(grouping: pairs, by: \.0)
        .compactMapValues { grouped in
            grouped.last?.1
        }
}

private func variantCountByKind<Value: Hashable>(
    from pairs: [(String, Value)]
) -> [String: Int] {
    Dictionary(grouping: pairs, by: \.0)
        .mapValues { grouped in
            Set(grouped.map(\.1)).count
        }
}

private func averageBrainByKind(
    from values: [BASBrainTraceInput],
    value: (BASBrainTraceInput) -> Double
) -> [String: Double] {
    Dictionary(grouping: values, by: \.kind)
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0.0) { partial, item in
                partial + value(item)
            }
            return total / Double(grouped.count)
        }
}

private func firstStrategyByKind(
    from traces: [BASRuntimeInspectionTraceInput]
) -> [String: BASAdaptiveTaskStrategy] {
    Dictionary(grouping: traces.compactMap { trace in
        trace.runtimeStrategy.map { (trace.kind, $0) }
    }, by: \.0)
    .compactMapValues { grouped in
        grouped.first?.1
    }
}

private func firstAttemptedProviderByKind(
    from traces: [BASRuntimeInspectionTraceInput]
) -> [String: String] {
    Dictionary(grouping: traces.filter { !$0.attemptedProviderIDs.isEmpty }, by: \.kind)
        .compactMapValues { grouped in
            grouped.first?.attemptedProviderIDs.first
        }
}

private func effectiveProviderOrderByKind(
    from traces: [BASRuntimeInspectionTraceInput]
) -> [String: [String]] {
    Dictionary(grouping: traces.filter { !$0.attemptedProviderIDs.isEmpty }, by: \.kind)
        .compactMapValues { grouped in
            grouped.first?.attemptedProviderIDs
        }
}

private func strategyMap<Value>(
    _ strategiesByKind: [String: BASAdaptiveTaskStrategy],
    value: KeyPath<BASAdaptiveTaskStrategy, Value>
) -> [String: Value] {
    strategiesByKind.mapValues { strategy in
        strategy[keyPath: value]
    }
}

private func reuseRateByKind(
    requestCountByKind: [String: Int],
    variantCountByKind: [String: Int]
) -> [String: Double] {
    Dictionary(
        uniqueKeysWithValues: requestCountByKind.map { kind, requestCount in
            let variants = min(variantCountByKind[kind] ?? requestCount, requestCount)
            let reused = max(0, requestCount - variants)
            return (kind, inspectionRate(numerator: reused, denominator: requestCount))
        }
    )
}

private func stablePrefixPollutionRateByKind(
    requestCountByKind: [String: Int],
    stablePrefixVariantCountByKind: [String: Int]
) -> [String: Double] {
    Dictionary(
        uniqueKeysWithValues: requestCountByKind.map { kind, requestCount in
            let variants = stablePrefixVariantCountByKind[kind] ?? 0
            let pollutionEvents = max(0, variants - 1)
            return (kind, inspectionRate(numerator: pollutionEvents, denominator: requestCount))
        }
    )
}

private func evidenceRetentionRatio(
    lifecycleSummary: BASLifecycleSummary
) -> Double {
    let total = lifecycleSummary.retainedEvidenceCount + lifecycleSummary.droppedEvidenceCount
    guard total > 0 else { return 0 }
    return Double(lifecycleSummary.retainedEvidenceCount) / Double(total)
}

private func evidenceRate(
    numerator: Int,
    retained: Int,
    dropped: Int
) -> Double {
    inspectionRate(numerator: numerator, denominator: retained + dropped)
}

private func evidenceRateByKind(
    numeratorByKind: [String: Int],
    retainedEvidenceCountByKind: [String: Int],
    droppedEvidenceCountByKind: [String: Int]
) -> [String: Double] {
    let kinds = Set(retainedEvidenceCountByKind.keys)
        .union(droppedEvidenceCountByKind.keys)
        .union(numeratorByKind.keys)

    return Dictionary(
        uniqueKeysWithValues: kinds.map { kind in
            let retained = retainedEvidenceCountByKind[kind] ?? 0
            let dropped = droppedEvidenceCountByKind[kind] ?? 0
            return (
                kind,
                inspectionRate(
                    numerator: numeratorByKind[kind] ?? 0,
                    denominator: retained + dropped
                )
            )
        }
    )
}

private func inspectionRate(
    numerator: Int,
    denominator: Int
) -> Double {
    guard denominator > 0 else { return 0 }
    return Double(numerator) / Double(denominator)
}

private func aggregatedCountMapByKind<Value: Hashable>(
    from traces: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, [Value: Int]>
) -> [String: [Value: Int]] {
    Dictionary(grouping: traces, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(into: [Value: Int]()) { partialResult, item in
                for (key, count) in item[keyPath: value] {
                    partialResult[key, default: 0] += count
                }
            }
        }
}

private func aggregatedArrayCountsByKind<Value: Hashable>(
    from traces: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, [Value]>
) -> [String: [Value: Int]] {
    Dictionary(grouping: traces, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(into: [Value: Int]()) { partialResult, item in
                for key in item[keyPath: value] {
                    partialResult[key, default: 0] += 1
                }
            }
        }
}

private func ratioByKind(
    numerator: [String: Double],
    denominatorAugend: [String: Double]
) -> [String: Double] {
    let kinds = Set(numerator.keys).union(denominatorAugend.keys)
    return Dictionary(uniqueKeysWithValues: kinds.map { kind in
        let numeratorValue = numerator[kind] ?? 0
        let denominatorValue = (denominatorAugend[kind] ?? 0) + numeratorValue
        return (kind, denominatorValue > 0 ? numeratorValue / denominatorValue : 0)
    })
}

private func containsTrueByKind(
    from values: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, Bool>
) -> [String: Bool] {
    Dictionary(grouping: values, by: \.kind)
        .mapValues { grouped in
            grouped.contains { $0[keyPath: value] }
        }
}
