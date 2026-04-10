import Foundation

public struct BASReferenceRuntimeLayerInput: Codable, Sendable, Equatable {
    public var activeProviderTitle: String
    public var runtimeGear: String
    public var averageRequestDurationMs: Double
    public var averageFirstPresentableMs: Double
    public var frontLoadShare: Double
    public var backendTitle: String
    public var activeRuntimeUsingDeterministicFallback: Bool
    public var overTimeBudgetRate: Double
    public var slowRequestRate: Double
    public var kindsOverFirstPresentableBudget: [String]
    public var hardwareAccelerationActive: Bool

    public init(
        activeProviderTitle: String,
        runtimeGear: String,
        averageRequestDurationMs: Double,
        averageFirstPresentableMs: Double,
        frontLoadShare: Double,
        backendTitle: String,
        activeRuntimeUsingDeterministicFallback: Bool,
        overTimeBudgetRate: Double,
        slowRequestRate: Double,
        kindsOverFirstPresentableBudget: [String],
        hardwareAccelerationActive: Bool
    ) {
        self.activeProviderTitle = activeProviderTitle
        self.runtimeGear = runtimeGear
        self.averageRequestDurationMs = averageRequestDurationMs
        self.averageFirstPresentableMs = averageFirstPresentableMs
        self.frontLoadShare = frontLoadShare
        self.backendTitle = backendTitle
        self.activeRuntimeUsingDeterministicFallback = activeRuntimeUsingDeterministicFallback
        self.overTimeBudgetRate = overTimeBudgetRate
        self.slowRequestRate = slowRequestRate
        self.kindsOverFirstPresentableBudget = kindsOverFirstPresentableBudget
        self.hardwareAccelerationActive = hardwareAccelerationActive
    }
}

public struct BASReferenceDataLayerInput: Codable, Sendable, Equatable {
    public var traceCount: Int
    public var replayCount: Int
    public var contextAwareTraceCount: Int
    public var activeTaskGraphTaskCount: Int

    public init(
        traceCount: Int,
        replayCount: Int,
        contextAwareTraceCount: Int,
        activeTaskGraphTaskCount: Int
    ) {
        self.traceCount = traceCount
        self.replayCount = replayCount
        self.contextAwareTraceCount = contextAwareTraceCount
        self.activeTaskGraphTaskCount = activeTaskGraphTaskCount
    }
}

public struct BASReferenceMemoryLayerInput: Codable, Sendable, Equatable {
    public var brainTraceCount: Int
    public var averagePromotedRecordCount: Double
    public var averagePendingCandidateCount: Double
    public var lowTrustMemoryLoadRate: Double
    public var pendingMemoryLoadRate: Double
    public var snapshotVariantCount: Int

    public init(
        brainTraceCount: Int,
        averagePromotedRecordCount: Double,
        averagePendingCandidateCount: Double,
        lowTrustMemoryLoadRate: Double,
        pendingMemoryLoadRate: Double,
        snapshotVariantCount: Int
    ) {
        self.brainTraceCount = brainTraceCount
        self.averagePromotedRecordCount = averagePromotedRecordCount
        self.averagePendingCandidateCount = averagePendingCandidateCount
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.pendingMemoryLoadRate = pendingMemoryLoadRate
        self.snapshotVariantCount = snapshotVariantCount
    }
}

public struct BASReferenceSafetyLayerInput: Codable, Sendable, Equatable {
    public var traceCount: Int
    public var evidencePollutionRate: Double
    public var lowTrustMemoryLoadRate: Double
    public var cacheQuarantineRate: Double
    public var circuitTripCount: Int
    public var circuitOpenProviderCount: Int
    public var boundaryModeCount: Int
    public var lockedSensitiveCoverage: Int
    public var consistencyCheckedTraceCount: Int
    public var consistencyRejectRate: Double
    public var forbiddenActionViolations: Int

    public init(
        traceCount: Int,
        evidencePollutionRate: Double,
        lowTrustMemoryLoadRate: Double,
        cacheQuarantineRate: Double,
        circuitTripCount: Int,
        circuitOpenProviderCount: Int,
        boundaryModeCount: Int,
        lockedSensitiveCoverage: Int,
        consistencyCheckedTraceCount: Int,
        consistencyRejectRate: Double,
        forbiddenActionViolations: Int
    ) {
        self.traceCount = traceCount
        self.evidencePollutionRate = evidencePollutionRate
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.cacheQuarantineRate = cacheQuarantineRate
        self.circuitTripCount = circuitTripCount
        self.circuitOpenProviderCount = circuitOpenProviderCount
        self.boundaryModeCount = boundaryModeCount
        self.lockedSensitiveCoverage = lockedSensitiveCoverage
        self.consistencyCheckedTraceCount = consistencyCheckedTraceCount
        self.consistencyRejectRate = consistencyRejectRate
        self.forbiddenActionViolations = forbiddenActionViolations
    }
}

public struct BASReferenceOrchestrationLayerInput: Codable, Sendable, Equatable {
    public var traceCount: Int
    public var lifecycleRebuildCount: Int
    public var exercisedKindCount: Int
    public var fallbackActivations: Int
    public var totalRequests: Int
    public var actionSurfaceCount: Int

    public init(
        traceCount: Int,
        lifecycleRebuildCount: Int,
        exercisedKindCount: Int,
        fallbackActivations: Int,
        totalRequests: Int,
        actionSurfaceCount: Int
    ) {
        self.traceCount = traceCount
        self.lifecycleRebuildCount = lifecycleRebuildCount
        self.exercisedKindCount = exercisedKindCount
        self.fallbackActivations = fallbackActivations
        self.totalRequests = totalRequests
        self.actionSurfaceCount = actionSurfaceCount
    }
}

public struct BASReferenceObservabilityLayerInput: Codable, Sendable, Equatable {
    public var traceCount: Int
    public var replayCount: Int
    public var totalRequests: Int
    public var promptMetricsPresent: Bool
    public var firstPresentableTracked: Bool
    public var consistencyCheckedTraceCount: Int
    public var consistencyCheckCoverageRate: Double
    public var totalCacheEntries: Int
    public var averageFirstPresentableMs: Double

    public init(
        traceCount: Int,
        replayCount: Int,
        totalRequests: Int,
        promptMetricsPresent: Bool,
        firstPresentableTracked: Bool,
        consistencyCheckedTraceCount: Int,
        consistencyCheckCoverageRate: Double,
        totalCacheEntries: Int,
        averageFirstPresentableMs: Double
    ) {
        self.traceCount = traceCount
        self.replayCount = replayCount
        self.totalRequests = totalRequests
        self.promptMetricsPresent = promptMetricsPresent
        self.firstPresentableTracked = firstPresentableTracked
        self.consistencyCheckedTraceCount = consistencyCheckedTraceCount
        self.consistencyCheckCoverageRate = consistencyCheckCoverageRate
        self.totalCacheEntries = totalCacheEntries
        self.averageFirstPresentableMs = averageFirstPresentableMs
    }
}

public struct BASReferenceEvaluationLayerInput: Codable, Sendable, Equatable {
    public var totalRequests: Int
    public var traceCount: Int
    public var brainTraceCount: Int
    public var promptVariantCount: Int
    public var calibrationKindCount: Int
    public var driftingKinds: [String]
    public var pendingReviewAverage: Double
    public var overTargetBudgetRate: Double

    public init(
        totalRequests: Int,
        traceCount: Int,
        brainTraceCount: Int,
        promptVariantCount: Int,
        calibrationKindCount: Int,
        driftingKinds: [String],
        pendingReviewAverage: Double,
        overTargetBudgetRate: Double
    ) {
        self.totalRequests = totalRequests
        self.traceCount = traceCount
        self.brainTraceCount = brainTraceCount
        self.promptVariantCount = promptVariantCount
        self.calibrationKindCount = calibrationKindCount
        self.driftingKinds = driftingKinds
        self.pendingReviewAverage = pendingReviewAverage
        self.overTargetBudgetRate = overTargetBudgetRate
    }
}

public struct BASReferenceDeliveryLayerInput: Codable, Sendable, Equatable {
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeProviderIsTestingStub: Bool
    public var hasFallbackProvider: Bool
    public var fallbackTitle: String?
    public var averageCheckpointCount: Double
    public var rollbackReadyCount: Int

    public init(
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeProviderIsTestingStub: Bool,
        hasFallbackProvider: Bool,
        fallbackTitle: String?,
        averageCheckpointCount: Double,
        rollbackReadyCount: Int
    ) {
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeProviderIsTestingStub = activeProviderIsTestingStub
        self.hasFallbackProvider = hasFallbackProvider
        self.fallbackTitle = fallbackTitle
        self.averageCheckpointCount = averageCheckpointCount
        self.rollbackReadyCount = rollbackReadyCount
    }
}

public struct BASReferenceFlightDeckInput: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var isPureLocalClosedLoop: Bool
    public var runtime: BASReferenceRuntimeLayerInput
    public var data: BASReferenceDataLayerInput
    public var memory: BASReferenceMemoryLayerInput
    public var safety: BASReferenceSafetyLayerInput
    public var orchestration: BASReferenceOrchestrationLayerInput
    public var observability: BASReferenceObservabilityLayerInput
    public var evaluation: BASReferenceEvaluationLayerInput
    public var delivery: BASReferenceDeliveryLayerInput

    public init(
        generatedAt: Date = .now,
        isPureLocalClosedLoop: Bool,
        runtime: BASReferenceRuntimeLayerInput,
        data: BASReferenceDataLayerInput,
        memory: BASReferenceMemoryLayerInput,
        safety: BASReferenceSafetyLayerInput,
        orchestration: BASReferenceOrchestrationLayerInput,
        observability: BASReferenceObservabilityLayerInput,
        evaluation: BASReferenceEvaluationLayerInput,
        delivery: BASReferenceDeliveryLayerInput
    ) {
        self.generatedAt = generatedAt
        self.isPureLocalClosedLoop = isPureLocalClosedLoop
        self.runtime = runtime
        self.data = data
        self.memory = memory
        self.safety = safety
        self.orchestration = orchestration
        self.observability = observability
        self.evaluation = evaluation
        self.delivery = delivery
    }
}

public struct BASReferenceLayerAssessment: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASLayerKind
    public var score: Int
    public var headline: String
    public var signals: [String]
    public var blockers: [String]

    public var id: BASLayerKind { kind }

    public init(
        kind: BASLayerKind,
        score: Int,
        headline: String,
        signals: [String],
        blockers: [String]
    ) {
        self.kind = kind
        self.score = score
        self.headline = headline
        self.signals = signals
        self.blockers = blockers
    }
}

public struct BASReferenceFlightDeckOutput: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var overallScore: Int
    public var assessments: [BASReferenceLayerAssessment]
    public var isPureLocalClosedLoop: Bool
    public var dominantBlockers: [String]

    public init(
        generatedAt: Date,
        overallScore: Int,
        assessments: [BASReferenceLayerAssessment],
        isPureLocalClosedLoop: Bool,
        dominantBlockers: [String]
    ) {
        self.generatedAt = generatedAt
        self.overallScore = overallScore
        self.assessments = assessments
        self.isPureLocalClosedLoop = isPureLocalClosedLoop
        self.dominantBlockers = dominantBlockers
    }
}

public enum BASReferenceFlightDeckBuilder {
    public static func build(
        from input: BASReferenceFlightDeckInput
    ) -> BASReferenceFlightDeckOutput {
        let assessments = [
            runtimeAssessment(input.runtime),
            dataAssessment(input.data),
            memoryAssessment(input.memory),
            safetyAssessment(input.safety),
            orchestrationAssessment(input.orchestration),
            observabilityAssessment(input.observability),
            evaluationAssessment(input.evaluation),
            deliveryAssessment(input.delivery)
        ]

        let overallScore = Int(
            (
                Double(assessments.map(\.score).reduce(0, +)) /
                Double(max(1, assessments.count))
            ).rounded()
        )
        let dominantBlockers = assessments
            .flatMap { assessment in
                assessment.blockers.map { "\(assessment.kind.title): \($0)" }
            }
            .prefix(4)

        return BASReferenceFlightDeckOutput(
            generatedAt: input.generatedAt,
            overallScore: overallScore,
            assessments: assessments,
            isPureLocalClosedLoop: input.isPureLocalClosedLoop,
            dominantBlockers: Array(dominantBlockers)
        )
    }

    private static func runtimeAssessment(
        _ input: BASReferenceRuntimeLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.activeRuntimeUsingDeterministicFallback {
            score -= 25
            blockers.append("Active runtime is leaning on deterministic fallback.")
        }

        if input.overTimeBudgetRate > 0.1 {
            score -= 20
            blockers.append("Runtime is exceeding time budgets too often.")
        }

        if input.slowRequestRate > 0.15 {
            score -= 15
            blockers.append("Slow-request rate is elevated.")
        }

        if !input.kindsOverFirstPresentableBudget.isEmpty {
            score -= 15
            blockers.append(
                "First-presentable latency is outrunning budget for \(input.kindsOverFirstPresentableBudget.joined(separator: ", "))."
            )
        }

        if input.frontLoadShare > 0.7 {
            score -= 10
            blockers.append("Front-loaded prompt and routing work is consuming too much of the first-presentable path.")
        }

        if !input.hardwareAccelerationActive {
            score -= 10
            blockers.append("No hardware acceleration path is active on device.")
        }

        return BASReferenceLayerAssessment(
            kind: .runtime,
            score: normalizedScore(score),
            headline: "The inference loop is live, budgeted, and local.",
            signals: [
                "Provider: \(input.activeProviderTitle)",
                "Gear: \(input.runtimeGear)",
                "Avg request: \(Int(input.averageRequestDurationMs.rounded())) ms",
                "Avg first presentable: \(Int(input.averageFirstPresentableMs.rounded())) ms",
                "Front-load share: \(percent(input.frontLoadShare))",
                "Backend: \(input.backendTitle)"
            ],
            blockers: blockers
        )
    }

    private static func dataAssessment(
        _ input: BASReferenceDataLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.traceCount == 0 {
            score -= 30
            blockers.append("No decision traces were captured.")
        }

        if input.replayCount == 0 {
            score -= 25
            blockers.append("No replayable decision ledger is available.")
        }

        if input.contextAwareTraceCount == 0 {
            score -= 15
            blockers.append("Context-aware state was not attached to traces.")
        }

        return BASReferenceLayerAssessment(
            kind: .data,
            score: normalizedScore(score),
            headline: "Facts are being captured as state instead of getting lost in chat.",
            signals: [
                "Replay entries: \(input.replayCount)",
                "Traces: \(input.traceCount)",
                "Context-aware traces: \(input.contextAwareTraceCount)",
                "Active task graph tasks: \(input.activeTaskGraphTaskCount)"
            ],
            blockers: blockers
        )
    }

    private static func memoryAssessment(
        _ input: BASReferenceMemoryLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.brainTraceCount == 0 {
            score -= 35
            blockers.append("No current brain state was loaded in sampled traces.")
        }

        if input.averagePromotedRecordCount == 0 {
            score -= 25
            blockers.append("No governed long-term memory is being surfaced.")
        }

        if input.lowTrustMemoryLoadRate > 0.15 {
            score -= 20
            blockers.append("Low-trust memories are influencing the front stage too often.")
        }

        if input.pendingMemoryLoadRate > 0.4 {
            score -= 10
            blockers.append("Pending memory influence is too high relative to promoted memory.")
        }

        return BASReferenceLayerAssessment(
            kind: .memory,
            score: normalizedScore(score),
            headline: "The local brain is carrying forward governed state, not just one-shot replies.",
            signals: [
                "Brain traces: \(input.brainTraceCount)",
                "Avg promoted records: \(Int(input.averagePromotedRecordCount.rounded()))",
                "Avg pending candidates: \(Int(input.averagePendingCandidateCount.rounded()))",
                "Snapshot variants: \(input.snapshotVariantCount)"
            ],
            blockers: blockers
        )
    }

    private static func safetyAssessment(
        _ input: BASReferenceSafetyLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.evidencePollutionRate > 0.2 {
            score -= 25
            blockers.append("Evidence pollution rate is above the safe line.")
        }

        if input.lowTrustMemoryLoadRate > 0.15 {
            score -= 25
            blockers.append("Low-trust memory load rate is too high.")
        }

        if input.cacheQuarantineRate > 0.1 {
            score -= 10
            blockers.append("Cache quarantine activity is elevated.")
        }

        if input.circuitOpenProviderCount > 0 {
            score -= 10
            blockers.append("One or more providers are in circuit-open cooldown.")
        }

        if input.boundaryModeCount == 0 {
            score -= 20
            blockers.append("No dynamic boundary policy state is attached to sampled brain traces.")
        }

        if input.lockedSensitiveCoverage == 0 {
            score -= 15
            blockers.append("Sensitive-memory lock coverage is not visible in boundary policy traces.")
        }

        if input.consistencyCheckedTraceCount == 0 && input.traceCount > 0 {
            score -= 15
            blockers.append("Live consistency harness results are missing from sampled traces.")
        }

        if input.consistencyRejectRate > 0.15 {
            score -= 15
            blockers.append("Consistency harness is rejecting too many live outputs.")
        }

        if input.forbiddenActionViolations > 0 {
            score -= 10
            blockers.append("Consistency harness caught forbidden actions in sampled outputs.")
        }

        return BASReferenceLayerAssessment(
            kind: .security,
            score: normalizedScore(score),
            headline: "Privacy, memory trust, and cache defenses are holding the line.",
            signals: [
                "Evidence pollution: \(percent(input.evidencePollutionRate))",
                "Low-trust load: \(percent(input.lowTrustMemoryLoadRate))",
                "Cache quarantine: \(percent(input.cacheQuarantineRate))",
                "Circuit trips: \(input.circuitTripCount)",
                "Boundary modes: \(input.boundaryModeCount)",
                "Consistency rejected: \(Int((Double(input.consistencyCheckedTraceCount) * input.consistencyRejectRate).rounded()))"
            ],
            blockers: blockers
        )
    }

    private static func orchestrationAssessment(
        _ input: BASReferenceOrchestrationLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.traceCount == 0 {
            score -= 30
            blockers.append("No orchestrated runs were observed.")
        }

        if input.lifecycleRebuildCount == 0 {
            score -= 15
            blockers.append("No lifecycle rebuilds were observed.")
        }

        if input.exercisedKindCount < 3 {
            score -= 10
            blockers.append("Not all primary decision modes have been exercised.")
        }

        if input.fallbackActivations > max(1, input.totalRequests / 2) {
            score -= 15
            blockers.append("Fallback activation rate is too high.")
        }

        return BASReferenceLayerAssessment(
            kind: .orchestration,
            score: normalizedScore(score),
            headline: "Routing, task state, and fallback logic are composing end-to-end decisions.",
            signals: [
                "Kinds exercised: \(input.exercisedKindCount)",
                "Lifecycle rebuilds: \(input.lifecycleRebuildCount)",
                "Fallback activations: \(input.fallbackActivations)",
                "Action slots: \(input.actionSurfaceCount)"
            ],
            blockers: blockers
        )
    }

    private static func observabilityAssessment(
        _ input: BASReferenceObservabilityLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.traceCount == 0 {
            score -= 35
            blockers.append("Trace coverage is zero.")
        }

        if input.replayCount == 0 {
            score -= 20
            blockers.append("Replay coverage is zero.")
        }

        if input.totalRequests == 0 {
            score -= 20
            blockers.append("Telemetry has no requests to analyze.")
        }

        if !input.promptMetricsPresent {
            score -= 10
            blockers.append("Prompt-shape metrics are missing.")
        }

        if input.totalRequests > 0 && !input.firstPresentableTracked {
            score -= 10
            blockers.append("First-presentable latency is not being tracked.")
        }

        if input.traceCount > 0 && input.consistencyCheckedTraceCount == 0 {
            score -= 20
            blockers.append("Trace corpus has no consistency-harness audit state.")
        }

        if input.traceCount > 0 && input.consistencyCheckCoverageRate < 0.6 {
            score -= 10
            blockers.append("Consistency-harness coverage is too shallow across sampled traces.")
        }

        return BASReferenceLayerAssessment(
            kind: .observability,
            score: normalizedScore(score),
            headline: "The stack can explain what it did, why it slowed, and where it fell back.",
            signals: [
                "Requests: \(input.totalRequests)",
                "Traces: \(input.traceCount)",
                "Replay: \(input.replayCount)",
                "Cache entries: \(input.totalCacheEntries)",
                "Avg first presentable: \(Int(input.averageFirstPresentableMs.rounded())) ms",
                "Consistency checked: \(input.consistencyCheckedTraceCount)"
            ],
            blockers: blockers
        )
    }

    private static func evaluationAssessment(
        _ input: BASReferenceEvaluationLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.totalRequests == 0 {
            score -= 30
            blockers.append("No sampled workload is available for evaluation.")
        }

        if input.traceCount == 0 {
            score -= 20
            blockers.append("No trace corpus exists to compare behavior over time.")
        }

        if input.brainTraceCount == 0 {
            score -= 15
            blockers.append("Brain-state behavior is not part of the evaluation set.")
        }

        if input.promptVariantCount == 0 {
            score -= 10
            blockers.append("Prompt-shape drift metrics are missing.")
        }

        if input.calibrationKindCount == 0 {
            score -= 20
            blockers.append("Calibration state is not attached to sampled brain traces.")
        }

        if !input.driftingKinds.isEmpty {
            score -= 20
            blockers.append("Calibration is drifting for \(input.driftingKinds.joined(separator: ", ")).")
        }

        if input.pendingReviewAverage > 0 {
            score -= 10
            blockers.append("Safe-evolution review debt is accumulating.")
        }

        return BASReferenceLayerAssessment(
            kind: .evaluation,
            score: normalizedScore(score),
            headline: "The local stack can tell whether behavior is getting better, not just greener.",
            signals: [
                "Total requests: \(input.totalRequests)",
                "Brain traces: \(input.brainTraceCount)",
                "Prompt variants tracked: \(input.promptVariantCount)",
                "Over-target budget: \(percent(input.overTargetBudgetRate))",
                "Calibration kinds: \(input.calibrationKindCount)"
            ],
            blockers: blockers
        )
    }

    private static func deliveryAssessment(
        _ input: BASReferenceDeliveryLayerInput
    ) -> BASReferenceLayerAssessment {
        var score = 100
        var blockers: [String] = []

        if input.registeredProviderCount < 3 {
            score -= 25
            blockers.append("Provider catalog is too narrow for long-term runtime portability.")
        }

        if input.registeredOpenModelProviderCount == 0 {
            score -= 20
            blockers.append("No open-model adapter path is registered.")
        }

        if input.activeProviderIsTestingStub {
            score -= 25
            blockers.append("Active runtime is still pinned to a testing stub.")
        }

        if !input.hasFallbackProvider {
            score -= 10
            blockers.append("No fallback provider is configured.")
        }

        if input.averageCheckpointCount == 0 {
            score -= 20
            blockers.append("No safe-evolution checkpoints are being recorded.")
        }

        if input.rollbackReadyCount == 0 && input.averageCheckpointCount > 0 {
            score -= 15
            blockers.append("Evolution checkpoints are not marked rollback-ready.")
        }

        return BASReferenceLayerAssessment(
            kind: .delivery,
            score: normalizedScore(score),
            headline: "The system is shaped to ship, integrate, and survive model/runtime churn.",
            signals: [
                "Providers: \(input.registeredProviderCount)",
                "Open adapters: \(input.registeredOpenModelProviderCount)",
                "Fallback: \(input.fallbackTitle ?? "none")",
                "Local closed loop: yes",
                "Checkpoints: \(Int(input.averageCheckpointCount.rounded()))"
            ],
            blockers: blockers
        )
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func normalizedScore(_ score: Int) -> Int {
        min(100, max(0, score))
    }
}
