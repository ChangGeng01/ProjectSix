import Foundation
import Testing
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASObservability")
struct BASObservabilityCoreTests {
    @Test("lifecycle metrics compiler turns stage boundaries into stable timings")
    func lifecycleMetricsCompilerBuildsStageDurations() {
        let metrics = BASLifecycleMetricsCompiler.compile(
            promptAssemblyMs: 40,
            admissionEvaluatedMs: 60,
            providerSelectionMs: 70,
            firstPresentableMs: 180
        )

        #expect(metrics.promptAssemblyMs == 40)
        #expect(metrics.admissionEvaluationMs == 20)
        #expect(metrics.providerSelectionMs == 10)
        #expect(metrics.firstPresentableMs == 180)
        #expect(metrics.executionMs == 110)
        #expect(metrics.prefillEquivalentMs == 70)
        #expect(metrics.prefillEquivalentShare == 70.0 / 180.0)
    }

    @Test("lifecycle metrics compiler clamps missing stages without going negative")
    func lifecycleMetricsCompilerClampsMissingStages() {
        let metrics = BASLifecycleMetricsCompiler.compile(
            promptAssemblyMs: 24,
            admissionEvaluatedMs: nil,
            providerSelectionMs: 18,
            firstPresentableMs: 12
        )

        #expect(metrics.promptAssemblyMs == 24)
        #expect(metrics.admissionEvaluationMs == 0)
        #expect(metrics.providerSelectionMs == 0)
        #expect(metrics.firstPresentableMs == 24)
        #expect(metrics.executionMs == 0)
    }

    @Test("telemetry summary builder tracks latency skip and bypass semantics")
    func telemetrySummaryBuilderTracksRates() {
        let summary = BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: ["quick": 2, "mirror": 1],
                outcomeCount: [.providerSuccess: 1, .cacheHit: 1, .admissionSkipped: 1],
                outcomeCountByKind: [
                    .providerSuccess: ["quick": 1],
                    .cacheHit: ["quick": 1],
                    .admissionSkipped: ["mirror": 1]
                ],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1, "foundationModels": 1],
                fallbackActivations: 0,
                backendCount: ["coreML": 1],
                slowRequestCountByKind: ["mirror": 1],
                overTimeBudgetCountByKind: ["mirror": 1],
                requestDurationTotalMsByKind: ["quick": 510, "mirror": 2_400],
                firstPresentableTotalMsByKind: ["quick": 216],
                promptAssemblyTotalMsByKind: ["quick": 58],
                admissionEvaluationTotalMsByKind: ["quick": 26],
                providerSelectionTotalMsByKind: ["quick": 14],
                executionTotalMsByKind: ["quick": 118],
                activeProviderDurationTotalMs: ["gemmaE4B": 120],
                backendDurationTotalMs: ["coreML": 120],
                admissionSkipCountByReason: ["templateAlreadySufficient": 1],
                admissionSkipCountByReasonAndKind: ["templateAlreadySufficient": ["mirror": 1]],
                reminderSelectionNeedCount: [:],
                promptCharactersTotalByKind: ["quick": 200],
                prefixCharactersTotalByKind: ["quick": 80],
                immutablePrefixCharactersTotalByKind: ["quick": 48],
                adaptivePrefixCharactersTotalByKind: ["quick": 32],
                suffixCharactersTotalByKind: ["quick": 120],
                overTargetBudgetCountByKind: ["mirror": 1],
                lowPressureModelCallCountByKind: ["quick": 1],
                reminderKindRawValue: "reminder",
                reminderKnowledgeNeedRawValue: "knowledge",
                reminderControlNeedRawValue: "control",
                reminderRetrievalBypassReasonRawValues: ["retrievalNotNeeded", "insufficientReminderChoice"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )

        #expect(summary.totalRequests == 3)
        #expect(summary.totalProviderAttempts == 2)
        #expect(summary.cacheHitRate == 1.0 / 3.0)
        #expect(summary.admissionSkipRate == 1.0 / 3.0)
        #expect(summary.providerBypassRate == 2.0 / 3.0)
        #expect(summary.lowPressureModelCallRate == 1.0 / 3.0)
        #expect(summary.avoidableModelCallRate == 1.0 / 3.0)
        #expect(summary.slowRequestRateByKind["mirror"] == 1)
        #expect(summary.overTimeBudgetRateByKind["mirror"] == 1)
        #expect(summary.averageRequestDurationMsByActiveProvider["gemmaE4B"] == 120)
        #expect(summary.averageRequestDurationMsByBackend["coreML"] == 120)
        #expect(summary.averagePrefillEquivalentShareByKind["quick"] == 98.0 / 216.0)
    }

    @Test("telemetry summary builder tracks reminder retrieval bypass")
    func telemetrySummaryBuilderTracksReminderBypass() {
        let summary = BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: ["reminder": 2],
                outcomeCount: [.admissionSkipped: 1, .providerSuccess: 1],
                outcomeCountByKind: [
                    .admissionSkipped: ["reminder": 1],
                    .providerSuccess: ["reminder": 1]
                ],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: [:],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["reminder": 148],
                firstPresentableTotalMsByKind: [:],
                promptAssemblyTotalMsByKind: [:],
                admissionEvaluationTotalMsByKind: [:],
                providerSelectionTotalMsByKind: [:],
                executionTotalMsByKind: [:],
                activeProviderDurationTotalMs: [:],
                backendDurationTotalMs: [:],
                admissionSkipCountByReason: ["retrievalNotNeeded": 1],
                admissionSkipCountByReasonAndKind: [:],
                reminderSelectionNeedCount: ["knowledge": 1, "control": 1],
                promptCharactersTotalByKind: [:],
                prefixCharactersTotalByKind: [:],
                immutablePrefixCharactersTotalByKind: [:],
                adaptivePrefixCharactersTotalByKind: [:],
                suffixCharactersTotalByKind: [:],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                reminderKindRawValue: "reminder",
                reminderKnowledgeNeedRawValue: "knowledge",
                reminderControlNeedRawValue: "control",
                reminderRetrievalBypassReasonRawValues: ["retrievalNotNeeded", "insufficientReminderChoice"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )

        #expect(summary.reminderRequestCount == 2)
        #expect(summary.reminderKnowledgeNeedRate == 0.5)
        #expect(summary.reminderControlOnlyRate == 0.5)
        #expect(summary.reminderRetrievalBypassCount == 1)
        #expect(summary.reminderRetrievalBypassRate == 0.5)
    }

    @Test("replay fingerprint is stable for identical bundles")
    func replayFingerprintIsStable() {
        let bundle = makeReplayBundle()

        let first = BASObservabilityInspector.replayFingerprint(for: bundle)
        let second = BASObservabilityInspector.replayFingerprint(for: bundle)

        #expect(first == second)
        #expect(first.value.count == 64)
    }

    @Test("anomaly inspector catches release mismatches and latency spikes")
    func anomalyInspectorCatchesReleaseMismatchesAndLatencySpikes() {
        let trace = BASExecutionTrace(
            inputSummary: "Should I send this?",
            selectedRoute: .cloud("cloud-large"),
            memoriesRecalled: ["same memory", "same memory"],
            toolsCalled: ["send_message"],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 200,
                retrievalMs: 400,
                generationMs: 4700,
                toolMs: 0
            ),
            outputSummary: "Drafted a reply."
        )

        let signals = BASObservabilityInspector.anomalySignals(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
        )

        #expect(signals.contains(where: { $0.kind == "latency_spike" }))
        #expect(signals.contains(where: { $0.kind == "tool_timing_gap" }))
        #expect(signals.contains(where: { $0.kind == "release_mismatch" }))
        #expect(signals.contains(where: { $0.kind == "duplicate_memory_recall" }))
    }

    @Test("release decision mirrors policy outcome")
    func releaseDecisionMirrorsPolicyOutcome() {
        let trace = BASExecutionTrace(
            inputSummary: "quick",
            selectedRoute: .local("local-fast"),
            memoriesRecalled: [],
            toolsCalled: [],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 20,
                retrievalMs: 0,
                generationMs: 100,
                toolMs: 0
            ),
            outputSummary: "ok"
        )

        let allow = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed")
        )
        let confirm = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .requireConfirmation, reason: "need confirm")
        )
        let deny = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
        )

        #expect(allow.kind == .allow)
        #expect(confirm.kind == .requireConfirmation)
        #expect(deny.kind == .deny)
    }

    @Test("inspection bundle packages replay release anomalies and calibration")
    func inspectionBundlePackagesUnifiedInspectionState() {
        let bundle = BASObservabilityInspector.inspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_123),
            trace: BASExecutionTrace(
                inputSummary: "Should I send this?",
                selectedRoute: .cloud("cloud-large"),
                memoriesRecalled: ["same memory", "same memory"],
                toolsCalled: ["send_message"],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 100,
                    retrievalMs: 200,
                    generationMs: 4_800,
                    toolMs: 0
                ),
                outputSummary: "Drafted a reply."
            ),
            brainState: makeReplayBundle().brainState,
            runtimeContext: makeReplayBundle().runtimeContext,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked by boundary"),
            calibration: BASInspectionCalibrationSummary(
                score: 0.62,
                status: "warn",
                summary: "Retrieval drift rising.",
                alertCount: 2,
                alertReasons: ["retrieval drift", "route instability"]
            )
        )

        #expect(bundle.generatedAt == Date(timeIntervalSince1970: 1_700_000_123))
        #expect(bundle.releaseDecision.kind == .deny)
        #expect(bundle.replayFingerprint.value.count == 64)
        #expect(bundle.anomalySignals.contains(where: { $0.kind == "latency_spike" }))
        #expect(bundle.calibration?.status == "warn")
        #expect(bundle.summary.contains("Release deny"))
        #expect(bundle.blockerSummary.contains("blocked by boundary"))
    }

    @Test("lifecycle summary compiler tracks rebuilds and evidence compaction")
    func lifecycleSummaryCompilerTracksRebuildsAndCompaction() {
        let summary = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "quick",
                    hasContextState: true,
                    generation: 2,
                    rebuiltSession: true,
                    staleFieldCount: 2,
                    anchorFieldCount: 3,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 2,
                    droppedEvidenceCount: 1,
                    droppedInjectedEvidenceCount: 1,
                    droppedDuplicateEvidenceCount: 0,
                    droppedBudgetEvidenceCount: 1
                ),
                BASLifecycleTraceInput(
                    kind: "quick",
                    hasContextState: true,
                    generation: 3,
                    rebuiltSession: false,
                    staleFieldCount: 1,
                    anchorFieldCount: 1,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 1,
                    droppedEvidenceCount: 2,
                    droppedInjectedEvidenceCount: 0,
                    droppedDuplicateEvidenceCount: 1,
                    droppedBudgetEvidenceCount: 0
                ),
                BASLifecycleTraceInput(
                    kind: "mirror",
                    hasContextState: false,
                    generation: nil,
                    rebuiltSession: false,
                    staleFieldCount: 0,
                    anchorFieldCount: 0,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 3,
                    droppedEvidenceCount: 0,
                    droppedInjectedEvidenceCount: 0,
                    droppedDuplicateEvidenceCount: 0,
                    droppedBudgetEvidenceCount: 0
                )
            ]
        )

        #expect(summary.contextAwareTraceCount == 2)
        #expect(summary.rebuildCount == 1)
        #expect(summary.rebuildCountByKind["quick"] == 1)
        #expect(summary.staleFieldDropCount == 3)
        #expect(summary.retainedEvidenceCount == 6)
        #expect(summary.droppedEvidenceCount == 3)
        #expect(summary.droppedInjectedEvidenceCountByKind["quick"] == 1)
        #expect(summary.droppedDuplicateEvidenceCountByKind["quick"] == 1)
        #expect(summary.droppedBudgetEvidenceCountByKind["quick"] == 1)
        #expect(summary.averageAnchorFieldCountByKind["quick"] == 2)
        #expect(summary.averageRetainedEvidenceCountByKind["quick"] == 1.5)
        #expect(summary.latestGenerationByKind["quick"] == 3)
    }

    @Test("neural summary compiler keeps dominant route and strongest signal by kind")
    func neuralSummaryCompilerTracksDominantSignals() {
        let summary = BASNeuralSummaryBuilder.build(
            from: [
                BASNeuralTraceInput(
                    kind: "quick",
                    suppressedBehaviorCount: 2,
                    dominantActionRawValue: "waitBuffer",
                    strongestSignalRawValue: "urgency"
                ),
                BASNeuralTraceInput(
                    kind: "quick",
                    suppressedBehaviorCount: 1,
                    dominantActionRawValue: "stepAway",
                    strongestSignalRawValue: "fatigue"
                ),
                BASNeuralTraceInput(
                    kind: "mirror",
                    suppressedBehaviorCount: 3,
                    dominantActionRawValue: "protectSelf",
                    strongestSignalRawValue: "identityDrift"
                )
            ]
        )

        #expect(summary.neuralTraceCount == 3)
        #expect(summary.suppressedBehaviorCount == 6)
        #expect(summary.dominantActionByKind["quick"] == "waitBuffer")
        #expect(summary.strongestSignalByKind["mirror"] == "identityDrift")
    }

    @Test("brain summary compiler aggregates governance calibration and evolution")
    func brainSummaryCompilerAggregatesGovernanceCalibrationAndEvolution() {
        let summary = BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "quick",
                    dominantReactionWeight: .briefLanguage,
                    profileCoreCount: 2,
                    activeGoalCount: 1,
                    relevantMemoryCount: 4,
                    loadedPromotedMemoryCount: 3,
                    loadedPendingMemoryCount: 1,
                    pendingCandidateCount: 2,
                    promotedRecordCount: 5,
                    screenedOutMemoryCount: 2,
                    loadedEligibilityReasonCounts: [.defaultAllowed: 2],
                    screenedOutEligibilityReasonCounts: [.lowTrustPending: 1],
                    snapshotFingerprint: "fp-q-1",
                    lowTrustMemoryLoadRate: 0.25,
                    riskFlags: [.lowTrustLoad],
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    activeConstraints: [.lockSensitiveMemory, .noCloudEscalation],
                    calibrationStatus: .watch,
                    calibrationAlerts: [.highPendingInfluence],
                    evolutionCheckpointCount: 2,
                    evolutionPendingReviewCount: 1,
                    evolutionRollbackReady: false
                ),
                BASBrainTraceInput(
                    kind: "quick",
                    dominantReactionWeight: .briefLanguage,
                    profileCoreCount: 4,
                    activeGoalCount: 3,
                    relevantMemoryCount: 2,
                    loadedPromotedMemoryCount: 1,
                    loadedPendingMemoryCount: 1,
                    pendingCandidateCount: 4,
                    promotedRecordCount: 7,
                    screenedOutMemoryCount: 0,
                    loadedEligibilityReasonCounts: [.defaultAllowed: 1],
                    screenedOutEligibilityReasonCounts: [.provenanceContamination: 1],
                    snapshotFingerprint: "fp-q-2",
                    lowTrustMemoryLoadRate: 0.5,
                    riskFlags: [.lowTrustLoad, .retrievalInstability],
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    activeConstraints: [.lockSensitiveMemory],
                    calibrationStatus: .drifting,
                    calibrationAlerts: [.templateCoverageGap],
                    evolutionCheckpointCount: 4,
                    evolutionPendingReviewCount: 3,
                    evolutionRollbackReady: true
                ),
                BASBrainTraceInput(
                    kind: "mirror",
                    dominantReactionWeight: .boundaryNamingBias,
                    profileCoreCount: 1,
                    activeGoalCount: 2,
                    relevantMemoryCount: 3,
                    loadedPromotedMemoryCount: 2,
                    loadedPendingMemoryCount: 0,
                    pendingCandidateCount: 1,
                    promotedRecordCount: 3,
                    screenedOutMemoryCount: 1,
                    loadedEligibilityReasonCounts: [.defaultAllowed: 1],
                    screenedOutEligibilityReasonCounts: [:],
                    snapshotFingerprint: "fp-m-1",
                    lowTrustMemoryLoadRate: 0.1,
                    riskFlags: [],
                    identityRole: .mirrorWitness,
                    boundaryMode: .localOnlyReflective,
                    activeConstraints: [.roleLimitedAdvice],
                    calibrationStatus: .stable,
                    calibrationAlerts: [],
                    evolutionCheckpointCount: 1,
                    evolutionPendingReviewCount: 0,
                    evolutionRollbackReady: true
                )
            ]
        )

        #expect(summary.brainTraceCount == 3)
        #expect(summary.dominantReactionWeightByKind["quick"] == .briefLanguage)
        #expect(summary.averageProfileCoreCountByKind["quick"] == 3)
        #expect(summary.averageLoadedPendingMemoryCountByKind["quick"] == 1)
        #expect(summary.pendingMemoryLoadRateByKind["quick"] == 1.0 / 3.0)
        #expect(summary.retrievalRejectionRateByKind["quick"] == 0.25)
        #expect(summary.latestSnapshotFingerprintByKind["quick"] == "fp-q-1")
        #expect(summary.snapshotVariantCountByKind["quick"] == 2)
        #expect(summary.lowTrustMemoryLoadRateByKind["quick"] == 0.375)
        #expect(summary.riskFlagCountsByKind["quick"]?[.lowTrustLoad] == 2)
        #expect(summary.boundaryConstraintCountsByKind["quick"]?[.lockSensitiveMemory] == 2)
        #expect(summary.calibrationStatusByKind["quick"] == .watch)
        #expect(summary.calibrationAlertCountsByKind["quick"]?[.templateCoverageGap] == 1)
        #expect(summary.evolutionCheckpointCountByKind["quick"] == 3)
        #expect(summary.evolutionPendingReviewCountByKind["quick"] == 2)
        #expect(summary.evolutionRollbackReadyByKind["quick"] == true)
    }

    private func makeReplayBundle() -> BASReplayBundle {
        BASReplayBundle(
            trace: BASExecutionTrace(
                inputSummary: "replay this",
                selectedRoute: .local("local-fast"),
                memoriesRecalled: ["Memory A"],
                toolsCalled: ["toolA"],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 12,
                    retrievalMs: 35,
                    generationMs: 180,
                    toolMs: 45
                ),
                outputSummary: "Released"
            ),
            brainState: BASCurrentBrainState(
                mode: "quick",
                dominantGoals: ["stay calm"],
                activeConstraints: ["sleep first"],
                reactionWeights: BASReactionWeights(warmth: 0.7, directness: 0.5, brevity: 0.8, actionBias: 0.6),
                activeTemplateIDs: [],
                recentFailurePatternIDs: [],
                retrievalTags: ["night"],
                verificationSnapshot: "fp_1"
            ),
            runtimeContext: BASRuntimeContext(
                taskKind: .chat,
                gear: .balanced,
                deviceProfile: BASDeviceProfile(
                    modelName: "iPhone",
                    memoryMB: 6144,
                    batteryLevel: 0.8,
                    lowPowerMode: false,
                    thermalState: "nominal"
                ),
                privacyMode: .localOnly,
                riskLevel: .medium,
                networkAvailable: false,
                budget: BASExecutionBudget(
                    contextTokens: 1200,
                    outputTokens: 300,
                    retrievalItems: 3,
                    toolCalls: 1,
                    timeBudgetMs: 1500
                )
            ),
            policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed")
        )
    }
}
