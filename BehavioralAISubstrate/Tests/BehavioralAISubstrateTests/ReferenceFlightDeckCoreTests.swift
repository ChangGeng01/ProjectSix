import Foundation
import Testing
@testable import BASAdmin

@Suite("BASReferenceFlightDeck")
struct ReferenceFlightDeckCoreTests {
    @Test("reference flight deck scores runtime and observability blockers")
    func scoresRuntimeAndObservabilityRisks() throws {
        let output = BASReferenceFlightDeckBuilder.build(
            from: BASReferenceFlightDeckInput(
                generatedAt: Date(timeIntervalSince1970: 1_710_000_000),
                isPureLocalClosedLoop: true,
                runtime: BASReferenceRuntimeLayerInput(
                    activeProviderTitle: "Template",
                    runtimeGear: "low",
                    averageRequestDurationMs: 1800,
                    averageFirstPresentableMs: 1400,
                    frontLoadShare: 0.82,
                    backendTitle: "CPU",
                    activeRuntimeUsingDeterministicFallback: true,
                    overTimeBudgetRate: 0.22,
                    slowRequestRate: 0.31,
                    kindsOverFirstPresentableBudget: ["Quick", "Mirror"],
                    hardwareAccelerationActive: false
                ),
                data: BASReferenceDataLayerInput(
                    traceCount: 2,
                    replayCount: 2,
                    contextAwareTraceCount: 1,
                    activeTaskGraphTaskCount: 3
                ),
                memory: BASReferenceMemoryLayerInput(
                    brainTraceCount: 1,
                    averagePromotedRecordCount: 3,
                    averagePendingCandidateCount: 2,
                    lowTrustMemoryLoadRate: 0.05,
                    pendingMemoryLoadRate: 0.2,
                    snapshotVariantCount: 1
                ),
                safety: BASReferenceSafetyLayerInput(
                    traceCount: 2,
                    evidencePollutionRate: 0.05,
                    lowTrustMemoryLoadRate: 0.05,
                    cacheQuarantineRate: 0.03,
                    circuitTripCount: 0,
                    circuitOpenProviderCount: 0,
                    boundaryModeCount: 1,
                    lockedSensitiveCoverage: 2,
                    consistencyCheckedTraceCount: 2,
                    consistencyRejectRate: 0.0,
                    forbiddenActionViolations: 0
                ),
                orchestration: BASReferenceOrchestrationLayerInput(
                    traceCount: 2,
                    lifecycleRebuildCount: 1,
                    exercisedKindCount: 4,
                    fallbackActivations: 1,
                    totalRequests: 4,
                    actionSurfaceCount: 8
                ),
                observability: BASReferenceObservabilityLayerInput(
                    traceCount: 2,
                    replayCount: 0,
                    totalRequests: 4,
                    promptMetricsPresent: false,
                    firstPresentableTracked: true,
                    consistencyCheckedTraceCount: 1,
                    consistencyCheckCoverageRate: 0.25,
                    totalCacheEntries: 6,
                    averageFirstPresentableMs: 1400
                ),
                evaluation: BASReferenceEvaluationLayerInput(
                    totalRequests: 4,
                    traceCount: 2,
                    brainTraceCount: 1,
                    promptVariantCount: 2,
                    calibrationKindCount: 1,
                    driftingKinds: [],
                    pendingReviewAverage: 0,
                    overTargetBudgetRate: 0.12
                ),
                delivery: BASReferenceDeliveryLayerInput(
                    registeredProviderCount: 3,
                    registeredOpenModelProviderCount: 1,
                    activeProviderIsTestingStub: false,
                    hasFallbackProvider: true,
                    fallbackTitle: "Gemma",
                    averageCheckpointCount: 1,
                    rollbackReadyCount: 1
                )
            )
        )

        let runtime = try #require(output.assessments.first(where: { $0.kind == .runtime }))
        let observability = try #require(output.assessments.first(where: { $0.kind == .observability }))

        #expect(runtime.score == 5)
        #expect(runtime.blockers.contains("Active runtime is leaning on deterministic fallback."))
        #expect(runtime.blockers.contains(where: { $0.contains("Quick, Mirror") }))
        #expect(observability.score == 60)
        #expect(observability.blockers.contains("Replay coverage is zero."))
        #expect(observability.blockers.contains("Prompt-shape metrics are missing."))
        #expect(observability.blockers.contains("Consistency-harness coverage is too shallow across sampled traces."))
    }

    @Test("reference flight deck tracks evaluation drift and delivery debt")
    func scoresEvaluationAndDeliveryDebt() throws {
        let output = BASReferenceFlightDeckBuilder.build(
            from: BASReferenceFlightDeckInput(
                isPureLocalClosedLoop: false,
                runtime: BASReferenceRuntimeLayerInput(
                    activeProviderTitle: "Gemma",
                    runtimeGear: "balanced",
                    averageRequestDurationMs: 620,
                    averageFirstPresentableMs: 420,
                    frontLoadShare: 0.42,
                    backendTitle: "Metal",
                    activeRuntimeUsingDeterministicFallback: false,
                    overTimeBudgetRate: 0.02,
                    slowRequestRate: 0.04,
                    kindsOverFirstPresentableBudget: [],
                    hardwareAccelerationActive: true
                ),
                data: BASReferenceDataLayerInput(
                    traceCount: 8,
                    replayCount: 5,
                    contextAwareTraceCount: 8,
                    activeTaskGraphTaskCount: 2
                ),
                memory: BASReferenceMemoryLayerInput(
                    brainTraceCount: 6,
                    averagePromotedRecordCount: 5,
                    averagePendingCandidateCount: 1,
                    lowTrustMemoryLoadRate: 0.04,
                    pendingMemoryLoadRate: 0.12,
                    snapshotVariantCount: 3
                ),
                safety: BASReferenceSafetyLayerInput(
                    traceCount: 8,
                    evidencePollutionRate: 0.04,
                    lowTrustMemoryLoadRate: 0.04,
                    cacheQuarantineRate: 0.02,
                    circuitTripCount: 0,
                    circuitOpenProviderCount: 0,
                    boundaryModeCount: 2,
                    lockedSensitiveCoverage: 3,
                    consistencyCheckedTraceCount: 8,
                    consistencyRejectRate: 0.05,
                    forbiddenActionViolations: 0
                ),
                orchestration: BASReferenceOrchestrationLayerInput(
                    traceCount: 8,
                    lifecycleRebuildCount: 3,
                    exercisedKindCount: 4,
                    fallbackActivations: 2,
                    totalRequests: 8,
                    actionSurfaceCount: 12
                ),
                observability: BASReferenceObservabilityLayerInput(
                    traceCount: 8,
                    replayCount: 5,
                    totalRequests: 8,
                    promptMetricsPresent: true,
                    firstPresentableTracked: true,
                    consistencyCheckedTraceCount: 8,
                    consistencyCheckCoverageRate: 1.0,
                    totalCacheEntries: 9,
                    averageFirstPresentableMs: 420
                ),
                evaluation: BASReferenceEvaluationLayerInput(
                    totalRequests: 8,
                    traceCount: 8,
                    brainTraceCount: 6,
                    promptVariantCount: 4,
                    calibrationKindCount: 2,
                    driftingKinds: ["Mirror"],
                    pendingReviewAverage: 2,
                    overTargetBudgetRate: 0.28
                ),
                delivery: BASReferenceDeliveryLayerInput(
                    registeredProviderCount: 2,
                    registeredOpenModelProviderCount: 0,
                    activeProviderIsTestingStub: true,
                    hasFallbackProvider: false,
                    fallbackTitle: nil,
                    averageCheckpointCount: 2,
                    rollbackReadyCount: 0
                )
            )
        )

        let evaluation = try #require(output.assessments.first(where: { $0.kind == .evaluation }))
        let delivery = try #require(output.assessments.first(where: { $0.kind == .delivery }))

        #expect(evaluation.score == 70)
        #expect(evaluation.blockers.contains("Calibration is drifting for Mirror."))
        #expect(evaluation.blockers.contains("Safe-evolution review debt is accumulating."))
        #expect(delivery.score == 5)
        #expect(delivery.blockers.contains("Provider catalog is too narrow for long-term runtime portability."))
        #expect(delivery.blockers.contains("No open-model adapter path is registered."))
        #expect(delivery.blockers.contains("Active runtime is still pinned to a testing stub."))
        #expect(delivery.blockers.contains("No fallback provider is configured."))
        #expect(delivery.blockers.contains("Evolution checkpoints are not marked rollback-ready."))
    }
}
