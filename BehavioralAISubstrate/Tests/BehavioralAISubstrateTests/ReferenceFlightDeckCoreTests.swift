import Foundation
import Testing
import BASObservability
import BASPolicy
import BASRuntimeCore
@testable import BASAdmin

@Suite("BASReferenceFlightDeck")
struct ReferenceFlightDeckCoreTests {
    @Test("reference flight deck input builder compiles package inspection summary into deck inputs")
    func referenceFlightDeckInputBuilderCompilesInspectionSummary() {
        let input = BASReferenceFlightDeckInputBuilder.build(
            from: BASReferenceFlightDeckAssemblyInput(
                generatedAt: Date(timeIntervalSince1970: 1_710_000_000),
                isPureLocalClosedLoop: true,
                activeProviderTitle: "Testing Stub",
                backendTitle: "CPU",
                activeTaskGraphTaskCount: 3,
                hardwareAccelerationActive: false,
                activeRuntimeUsingDeterministicFallback: true,
                fallbackTitle: "Gemma",
                inspectionSummary: makeInspectionSummary(activeProviderID: BASReferenceProviderRuntime.testingStubProviderID),
                brainSummary: makeBrainSummary()
            )
        )

        #expect(input.runtime.activeProviderTitle == "Testing Stub")
        #expect(input.runtime.frontLoadShare == 0.5)
        #expect(input.runtime.activeRuntimeUsingDeterministicFallback)
        #expect(input.data.activeTaskGraphTaskCount == 3)
        #expect(input.memory.averagePromotedRecordCount == 6)
        #expect(input.memory.snapshotVariantCount == 1)
        #expect(input.safety.lockedSensitiveCoverage == 1)
        #expect(input.orchestration.exercisedKindCount == 1)
        #expect(input.observability.promptMetricsPresent == true)
        #expect(input.evaluation.calibrationKindCount == 1)
        #expect(input.delivery.activeProviderIsTestingStub == true)
        #expect(input.delivery.hasFallbackProvider == true)
        #expect(input.delivery.fallbackTitle == "Gemma")
    }

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

    private func makeInspectionSummary(activeProviderID: String) -> BASRuntimeInspectionSummary {
        let telemetry = BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: ["quick": 2],
                outcomeCount: [.providerSuccess: 1, .cacheHit: 1],
                outcomeCountByKind: [
                    .providerSuccess: ["quick": 1],
                    .cacheHit: ["quick": 1]
                ],
                activeProviderCount: [activeProviderID: 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 1,
                backendCount: ["cpu": 1],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["quick": 220],
                firstPresentableTotalMsByKind: ["quick": 140],
                promptAssemblyTotalMsByKind: ["quick": 40],
                admissionEvaluationTotalMsByKind: ["quick": 20],
                providerSelectionTotalMsByKind: ["quick": 10],
                executionTotalMsByKind: ["quick": 70],
                activeProviderDurationTotalMs: [activeProviderID: 220],
                backendDurationTotalMs: ["cpu": 220],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                reminderSelectionNeedCount: [:],
                promptCharactersTotalByKind: ["quick": 480],
                prefixCharactersTotalByKind: ["quick": 180],
                immutablePrefixCharactersTotalByKind: ["quick": 120],
                adaptivePrefixCharactersTotalByKind: ["quick": 60],
                suffixCharactersTotalByKind: ["quick": 300],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: ["quick": 1],
                reminderKindRawValue: "reminder",
                reminderKnowledgeNeedRawValue: "knowledge",
                reminderControlNeedRawValue: "control",
                reminderRetrievalBypassReasonRawValues: ["retrievalNotNeeded"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient"]
            )
        )
        let lifecycle = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "quick",
                    hasContextState: true,
                    generation: 4,
                    rebuiltSession: true,
                    staleFieldCount: 0,
                    anchorFieldCount: 1,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 2,
                    droppedEvidenceCount: 1,
                    droppedInjectedEvidenceCount: 1,
                    droppedDuplicateEvidenceCount: 0,
                    droppedBudgetEvidenceCount: 0
                )
            ]
        )
        let neural = BASNeuralSummaryBuilder.build(
            from: [
                BASNeuralTraceInput(
                    kind: "quick",
                    suppressedBehaviorCount: 1,
                    dominantActionRawValue: "waitBuffer",
                    strongestSignalRawValue: "urgency"
                )
            ]
        )
        let brain = makeBrainSummary()

        return BASRuntimeInspectionBuilder.build(
            from: BASRuntimeInspectionInput(
                activeProviderID: activeProviderID,
                fallbackProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                runtimeGear: .low,
                environmentClass: .normal,
                deviceClass: .balancedPhone,
                languageMode: .english,
                taskEntropyByKind: ["quick": .low],
                preferredProviderRawValueByKind: ["quick": "gemmaE4B"],
                strategyByKind: [
                    "quick": BASAdaptiveTaskStrategy(
                        kind: .quick,
                        entropy: .low,
                        runtimeGear: .low,
                        contextBudget: 220,
                        outputCharacterBudget: 180,
                        timeBudgetMs: 500,
                        toolCallBudget: 1,
                        retrievalItemBudget: 0,
                        retrievalMode: .off,
                        thinkingMode: .off,
                        outputMode: .guidedShort,
                        tone: .briefWarm,
                        actionSpace: ["encourage", "next_step", "fallback_to_template"],
                        responseLanguage: .english,
                        allowsModelInvocation: true
                    )
                ],
                effectivePreferredProviderRawValueByKind: ["quick": "gemmaE4B"],
                traceInputs: [
                    BASRuntimeInspectionTraceInput(
                        kind: "quick",
                        attemptedProviderIDs: ["gemmaE4B"],
                        runtimeStrategy: BASAdaptiveTaskStrategy(
                            kind: .quick,
                            entropy: .low,
                            runtimeGear: .low,
                            contextBudget: 220,
                            outputCharacterBudget: 180,
                            timeBudgetMs: 500,
                            toolCallBudget: 1,
                            retrievalItemBudget: 0,
                            retrievalMode: .off,
                            thinkingMode: .off,
                            outputMode: .guidedShort,
                            tone: .briefWarm,
                            actionSpace: ["encourage", "next_step", "fallback_to_template"],
                            responseLanguage: .english,
                            allowsModelInvocation: true
                        ),
                        semanticPromptFingerprint: "semantic-q-1",
                        stablePrefixFingerprint: "stable-q-1",
                        consistencyChecked: true
                    )
                ],
                telemetrySummary: telemetry,
                lifecycleSummary: lifecycle,
                neuralSummary: neural,
                brainSummary: brain,
                totalCacheEntries: 1,
                totalCacheLookupCount: 1,
                totalCacheRejectedStores: 0,
                totalCacheQuarantinedHits: 0,
                dominantBackendID: "cpu",
                registeredProviderCount: 4,
                registeredOpenModelProviderCount: 2,
                activeCircuitProviderIDs: ["gemmaE4B"],
                circuitTripCount: 1,
                circuitTripCountByProvider: ["gemmaE4B": 1],
                circuitTripCountByReason: ["repeatedProviderFailure": 1],
                traceCount: 1,
                replayCount: 1
            )
        )
    }

    private func makeBrainSummary() -> BASBrainSummary {
        BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "quick",
                    dominantReactionWeight: .interruptiveActionBias,
                    profileCoreCount: 1,
                    activeGoalCount: 1,
                    relevantMemoryCount: 1,
                    loadedPromotedMemoryCount: 3,
                    loadedPendingMemoryCount: 1,
                    pendingCandidateCount: 1,
                    promotedRecordCount: 6,
                    screenedOutMemoryCount: 1,
                    loadedEligibilityReasonCounts: [.goalOverride: 1],
                    screenedOutEligibilityReasonCounts: [.confidenceNoOverlap: 1],
                    snapshotFingerprint: "fp-q",
                    lowTrustMemoryLoadRate: 0,
                    riskFlags: [],
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    activeConstraints: [.lockSensitiveMemory],
                    calibrationStatus: .stable,
                    calibrationAlerts: [],
                    evolutionCheckpointCount: 0,
                    evolutionPendingReviewCount: 0,
                    evolutionRollbackReady: false
                )
            ]
        )
    }
}
