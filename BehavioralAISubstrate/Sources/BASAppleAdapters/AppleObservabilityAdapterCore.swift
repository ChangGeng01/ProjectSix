import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASAppleProviderTraceInput: Codable, Sendable, Equatable {
    public var environment: [String: String]
    public var considerRuntimeTestingContext: Bool
    public var runtimeTestingContextDetected: Bool
    public var testingOverridePresent: Bool
    public var kind: String
    public var preferredProviderID: String
    public var activeProviderID: String?
    public var attemptedProviderIDs: [String]
    public var allowFallbacks: Bool
    public var prompt: String
    public var outputPreview: String
    public var detail: String
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var promptBudget: BASPromptBudget?
    public var lifecycleMetrics: BASRequestLifecycleMetrics?
    public var brainState: BASDecisionBrainState?
    public var consistencyRejected: Bool
    public var consistencyViolationKinds: [String]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        considerRuntimeTestingContext: Bool = true,
        runtimeTestingContextDetected: Bool = NSClassFromString("XCTestCase") != nil,
        testingOverridePresent: Bool = false,
        kind: String,
        preferredProviderID: String,
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        allowFallbacks: Bool,
        prompt: String,
        outputPreview: String,
        detail: String,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        promptBudget: BASPromptBudget? = nil,
        lifecycleMetrics: BASRequestLifecycleMetrics? = nil,
        brainState: BASDecisionBrainState? = nil,
        consistencyRejected: Bool = false,
        consistencyViolationKinds: [String] = []
    ) {
        self.environment = environment
        self.considerRuntimeTestingContext = considerRuntimeTestingContext
        self.runtimeTestingContextDetected = runtimeTestingContextDetected
        self.testingOverridePresent = testingOverridePresent
        self.kind = kind
        self.preferredProviderID = preferredProviderID
        self.activeProviderID = activeProviderID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.allowFallbacks = allowFallbacks
        self.prompt = prompt
        self.outputPreview = outputPreview
        self.detail = detail
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.promptBudget = promptBudget
        self.lifecycleMetrics = lifecycleMetrics
        self.brainState = brainState
        self.consistencyRejected = consistencyRejected
        self.consistencyViolationKinds = consistencyViolationKinds
    }
}

public struct BASAppleProviderTraceCompilation: Codable, Sendable, Equatable {
    public var allowsSensitivePayload: Bool
    public var storedPrompt: String
    public var storedOutputPreview: String
    public var executionTrace: BASExecutionTrace

    public init(
        allowsSensitivePayload: Bool,
        storedPrompt: String,
        storedOutputPreview: String,
        executionTrace: BASExecutionTrace
    ) {
        self.allowsSensitivePayload = allowsSensitivePayload
        self.storedPrompt = storedPrompt
        self.storedOutputPreview = storedOutputPreview
        self.executionTrace = executionTrace
    }
}

public struct BASAppleTelemetryRecordInput: Codable, Sendable, Equatable {
    public var kind: String
    public var outcome: BASRequestOutcome
    public var activeProviderID: String?
    public var attemptedProviderIDs: [String]
    public var usedFallback: Bool
    public var durationMs: Double
    public var lifecycleMetrics: BASRequestLifecycleMetrics?
    public var promptBudget: BASPromptBudget?
    public var runtimeTimeBudgetMs: Int?
    public var admissionPressureID: String?
    public var admissionSkipReasonID: String?
    public var reminderSelectionNeedID: String?
    public var activeBackendID: String?

    public init(
        kind: String,
        outcome: BASRequestOutcome,
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        usedFallback: Bool,
        durationMs: Double,
        lifecycleMetrics: BASRequestLifecycleMetrics? = nil,
        promptBudget: BASPromptBudget? = nil,
        runtimeTimeBudgetMs: Int? = nil,
        admissionPressureID: String? = nil,
        admissionSkipReasonID: String? = nil,
        reminderSelectionNeedID: String? = nil,
        activeBackendID: String? = nil
    ) {
        self.kind = kind
        self.outcome = outcome
        self.activeProviderID = activeProviderID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.usedFallback = usedFallback
        self.durationMs = durationMs
        self.lifecycleMetrics = lifecycleMetrics
        self.promptBudget = promptBudget
        self.runtimeTimeBudgetMs = runtimeTimeBudgetMs
        self.admissionPressureID = admissionPressureID
        self.admissionSkipReasonID = admissionSkipReasonID
        self.reminderSelectionNeedID = reminderSelectionNeedID
        self.activeBackendID = activeBackendID
    }
}

public struct BASAppleTelemetryRecordCompilation: Codable, Sendable, Equatable {
    public var kind: String
    public var outcome: BASRequestOutcome
    public var activeProviderID: String?
    public var attemptedProviderIDs: [String]
    public var usedFallback: Bool
    public var durationMs: Double
    public var lifecycleMetrics: BASRequestLifecycleMetrics?
    public var promptBudget: BASPromptBudget?
    public var admissionPressureID: String?
    public var admissionSkipReasonID: String?
    public var reminderSelectionNeedID: String?
    public var activeBackendID: String?
    public var slowRequestThresholdMs: Double
    public var isSlowRequest: Bool
    public var exceedsTimeBudget: Bool
    public var lowPressureModelCall: Bool
    public var overTargetPromptBudget: Bool

    public init(
        kind: String,
        outcome: BASRequestOutcome,
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        usedFallback: Bool,
        durationMs: Double,
        lifecycleMetrics: BASRequestLifecycleMetrics?,
        promptBudget: BASPromptBudget?,
        admissionPressureID: String?,
        admissionSkipReasonID: String?,
        reminderSelectionNeedID: String?,
        activeBackendID: String?,
        slowRequestThresholdMs: Double,
        isSlowRequest: Bool,
        exceedsTimeBudget: Bool,
        lowPressureModelCall: Bool,
        overTargetPromptBudget: Bool
    ) {
        self.kind = kind
        self.outcome = outcome
        self.activeProviderID = activeProviderID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.usedFallback = usedFallback
        self.durationMs = durationMs
        self.lifecycleMetrics = lifecycleMetrics
        self.promptBudget = promptBudget
        self.admissionPressureID = admissionPressureID
        self.admissionSkipReasonID = admissionSkipReasonID
        self.reminderSelectionNeedID = reminderSelectionNeedID
        self.activeBackendID = activeBackendID
        self.slowRequestThresholdMs = slowRequestThresholdMs
        self.isSlowRequest = isSlowRequest
        self.exceedsTimeBudget = exceedsTimeBudget
        self.lowPressureModelCall = lowPressureModelCall
        self.overTargetPromptBudget = overTargetPromptBudget
    }
}

public enum BASAppleObservabilityAdapter {
    public static func compileLifecycleMetrics(
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerSelectionMs: Double? = nil,
        firstPresentableMs: Double
    ) -> BASRequestLifecycleMetrics {
        BASLifecycleMetricsCompiler.compile(
            promptAssemblyMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerSelectionMs: providerSelectionMs,
            firstPresentableMs: firstPresentableMs
        )
    }

    public static func providerDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASProviderTraceNarrator.detail(
            preferredTitle: preferredTitle,
            activeTitle: activeTitle,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: activeResolutionDetail
        )
    }

    public static func cachedProviderDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASProviderTraceNarrator.cachedDetail(
            base: providerDetail(
                preferredTitle: preferredTitle,
                activeTitle: activeTitle,
                allowFallbacks: allowFallbacks,
                activeResolutionDetail: activeResolutionDetail
            )
        )
    }

    public static func deterministicFallbackDetail(
        base: String,
        suspendedProviderTitles: [String]
    ) -> String {
        BASProviderTraceNarrator.deterministicFallbackDetail(
            base: base,
            suspendedProviderTitles: suspendedProviderTitles
        )
    }

    public static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        BASProviderReleaseGate.rejectedConsistencyDetail(
            base: base,
            result: result,
            source: source
        )
    }

    public static func allowsSensitivePayload(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        considerRuntimeTestingContext: Bool = true,
        runtimeTestingContextDetected: Bool = NSClassFromString("XCTestCase") != nil,
        testingOverridePresent: Bool = false
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil ||
            testingOverridePresent ||
            (considerRuntimeTestingContext && runtimeTestingContextDetected)
    }

    public static func sanitizedPrompt(
        detail: String,
        semanticPromptFingerprint: String?,
        stablePrefixFingerprint: String?,
        promptBudget: BASPromptBudget?
    ) -> String {
        let budgetSummary = promptBudget.map {
            "target=\($0.targetCharacters), actual=\($0.totalCharacters), within=\($0.isWithinTarget)"
        } ?? "unavailable"

        return [
            "[REDACTED LIVE PROMPT]",
            normalizedText(detail),
            semanticPromptFingerprint.map { "semantic_fingerprint=\($0)" },
            stablePrefixFingerprint.map { "stable_prefix=\($0)" },
            "budget=\(budgetSummary)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    public static func sanitizedOutputPreview(
        outputPreview: String
    ) -> String {
        "[REDACTED LIVE OUTPUT PREVIEW] length=\(outputPreview.count)"
    }

    public static func compileProviderTrace(
        from input: BASAppleProviderTraceInput
    ) -> BASAppleProviderTraceCompilation {
        let allowsSensitivePayload = allowsSensitivePayload(
            environment: input.environment,
            considerRuntimeTestingContext: input.considerRuntimeTestingContext,
            runtimeTestingContextDetected: input.runtimeTestingContextDetected,
            testingOverridePresent: input.testingOverridePresent
        )
        let storedPrompt = allowsSensitivePayload
            ? input.prompt
            : sanitizedPrompt(
                detail: input.detail,
                semanticPromptFingerprint: input.semanticPromptFingerprint,
                stablePrefixFingerprint: input.stablePrefixFingerprint,
                promptBudget: input.promptBudget
            )
        let storedOutputPreview = allowsSensitivePayload
            ? input.outputPreview
            : sanitizedOutputPreview(outputPreview: input.outputPreview)

        return BASAppleProviderTraceCompilation(
            allowsSensitivePayload: allowsSensitivePayload,
            storedPrompt: storedPrompt,
            storedOutputPreview: storedOutputPreview,
            executionTrace: BASExecutionTrace(
                inputSummary: normalizedText(input.detail),
                selectedRoute: selectedRoute(from: input),
                memoriesRecalled: recalledMemoryHeadlines(from: input.brainState),
                toolsCalled: [],
                latency: latencyBreakdown(from: input.lifecycleMetrics),
                auditEvents: auditEvents(
                    from: input,
                    allowsSensitivePayload: allowsSensitivePayload
                ),
                outputSummary: storedOutputPreview
            )
        )
    }

    public static func slowRequestThresholdMs(
        for kind: String
    ) -> Double {
        switch kind {
        case "quick":
            800
        case "balance", "mirror":
            1_500
        case "reminder":
            450
        default:
            1_000
        }
    }

    public static func compileTelemetryRecord(
        from input: BASAppleTelemetryRecordInput
    ) -> BASAppleTelemetryRecordCompilation {
        let threshold = slowRequestThresholdMs(for: input.kind)
        let exceedsTimeBudget = input.runtimeTimeBudgetMs.map { input.durationMs > Double($0) } ?? false
        let lowPressureModelCall = input.outcome == .providerSuccess && input.admissionPressureID == "low"

        return BASAppleTelemetryRecordCompilation(
            kind: input.kind,
            outcome: input.outcome,
            activeProviderID: input.activeProviderID,
            attemptedProviderIDs: input.attemptedProviderIDs,
            usedFallback: input.usedFallback,
            durationMs: input.durationMs,
            lifecycleMetrics: input.lifecycleMetrics,
            promptBudget: input.promptBudget,
            admissionPressureID: input.admissionPressureID,
            admissionSkipReasonID: input.admissionSkipReasonID,
            reminderSelectionNeedID: input.reminderSelectionNeedID,
            activeBackendID: input.activeBackendID,
            slowRequestThresholdMs: threshold,
            isSlowRequest: input.durationMs >= threshold,
            exceedsTimeBudget: exceedsTimeBudget,
            lowPressureModelCall: lowPressureModelCall,
            overTargetPromptBudget: input.promptBudget.map { !$0.isWithinTarget } ?? false
        )
    }

    private static func selectedRoute(
        from input: BASAppleProviderTraceInput
    ) -> BASModelRoute {
        BASModelRoute.local(
            input.activeProviderID ?? input.preferredProviderID,
            fallbackModelIDs: Array(input.attemptedProviderIDs.dropFirst())
        )
    }

    private static func recalledMemoryHeadlines(
        from brainState: BASDecisionBrainState?
    ) -> [String] {
        guard let brainState else { return [] }

        var headlines: [String] = []
        for headline in brainState.activeGoals.prefix(2) + brainState.relevantMemories.prefix(3) {
            let normalized = normalizedText(headline)
            guard normalized.isEmpty == false else { continue }
            guard headlines.contains(normalized) == false else { continue }
            headlines.append(normalized)
        }
        return headlines
    }

    private static func latencyBreakdown(
        from lifecycleMetrics: BASRequestLifecycleMetrics?
    ) -> BASTraceLatencyBreakdown {
        guard let lifecycleMetrics else {
            return BASTraceLatencyBreakdown(
                routeSelectionMs: 0,
                retrievalMs: 0,
                generationMs: 0,
                toolMs: 0
            )
        }

        return BASTraceLatencyBreakdown(
            routeSelectionMs: roundedMilliseconds(lifecycleMetrics.providerSelectionMs),
            retrievalMs: roundedMilliseconds(
                lifecycleMetrics.promptAssemblyMs + lifecycleMetrics.admissionEvaluationMs
            ),
            generationMs: roundedMilliseconds(lifecycleMetrics.executionMs),
            toolMs: 0
        )
    }

    private static func auditEvents(
        from input: BASAppleProviderTraceInput,
        allowsSensitivePayload: Bool
    ) -> [BASAuditEvent] {
        var events: [BASAuditEvent] = [
            BASAuditEvent(
                category: "provider.preference",
                message: "Preferred provider \(input.preferredProviderID) handled a \(input.kind) trace.",
                metadata: [
                    "allow_fallbacks": input.allowFallbacks.description,
                    "sensitive_payload": allowsSensitivePayload.description
                ]
            )
        ]

        if let activeProviderID = input.activeProviderID {
            events.append(
                BASAuditEvent(
                    category: "provider.execution",
                    message: "Active provider resolved to \(activeProviderID).",
                    metadata: [
                        "used_fallback": (activeProviderID != input.preferredProviderID).description,
                        "attempted_provider_count": String(input.attemptedProviderIDs.count)
                    ]
                )
            )
        }

        if let promptBudget = input.promptBudget {
            events.append(
                BASAuditEvent(
                    category: "prompt.budget",
                    message: "Prompt budget settled at \(promptBudget.totalCharacters)/\(promptBudget.targetCharacters) characters.",
                    metadata: [
                        "stable_prefix_share": String(format: "%.3f", promptBudget.stablePrefixShare),
                        "within_target": promptBudget.isWithinTarget.description
                    ]
                )
            )
        }

        if input.consistencyRejected {
            events.append(
                BASAuditEvent(
                    category: "consistency.rejected",
                    message: "Consistency harness rejected the release candidate.",
                    metadata: [
                        "violation_kinds": input.consistencyViolationKinds.joined(separator: ",")
                    ]
                )
            )
        }

        return events
    }

    private static func roundedMilliseconds(
        _ value: Double
    ) -> Int {
        max(0, Int(value.rounded()))
    }

    private static func normalizedText(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
