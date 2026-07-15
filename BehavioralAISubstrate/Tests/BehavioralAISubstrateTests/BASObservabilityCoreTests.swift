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
                requestCountByKind: ["primary": 2, "reflective": 1],
                outcomeCount: [.providerSuccess: 1, .cacheHit: 1, .admissionSkipped: 1],
                outcomeCountByKind: [
                    .providerSuccess: ["primary": 1],
                    .cacheHit: ["primary": 1],
                    .admissionSkipped: ["reflective": 1]
                ],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1, "foundationModels": 1],
                fallbackActivations: 0,
                backendCount: ["coreML": 1],
                slowRequestCountByKind: ["reflective": 1],
                overTimeBudgetCountByKind: ["reflective": 1],
                requestDurationTotalMsByKind: ["primary": 510, "reflective": 2_400],
                firstPresentableTotalMsByKind: ["primary": 216],
                promptAssemblyTotalMsByKind: ["primary": 58],
                admissionEvaluationTotalMsByKind: ["primary": 26],
                providerSelectionTotalMsByKind: ["primary": 14],
                executionTotalMsByKind: ["primary": 118],
                activeProviderDurationTotalMs: ["gemmaE4B": 120],
                backendDurationTotalMs: ["coreML": 120],
                admissionSkipCountByReason: ["templateAlreadySufficient": 1],
                admissionSkipCountByReasonAndKind: ["templateAlreadySufficient": ["reflective": 1]],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 200],
                prefixCharactersTotalByKind: ["primary": 80],
                immutablePrefixCharactersTotalByKind: ["primary": 48],
                adaptivePrefixCharactersTotalByKind: ["primary": 32],
                suffixCharactersTotalByKind: ["primary": 120],
                overTargetBudgetCountByKind: ["reflective": 1],
                lowPressureModelCallCountByKind: ["primary": 1],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: ["retrievalNotNeeded", "insufficientChoiceSpread"],
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
        #expect(summary.slowRequestRateByKind["reflective"] == 1)
        #expect(summary.overTimeBudgetRateByKind["reflective"] == 1)
        #expect(summary.averageRequestDurationMsByActiveProvider["gemmaE4B"] == 120)
        #expect(summary.averageRequestDurationMsByBackend["coreML"] == 120)
        #expect(summary.averagePrefillEquivalentShareByKind["primary"] == 98.0 / 216.0)
    }

    @Test("telemetry summary builder tracks selection retrieval bypass")
    func telemetrySummaryBuilderTracksReminderBypass() {
        let summary = BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: ["selection": 2],
                outcomeCount: [.admissionSkipped: 1, .providerSuccess: 1],
                outcomeCountByKind: [
                    .admissionSkipped: ["selection": 1],
                    .providerSuccess: ["selection": 1]
                ],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: [:],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["selection": 148],
                firstPresentableTotalMsByKind: [:],
                promptAssemblyTotalMsByKind: [:],
                admissionEvaluationTotalMsByKind: [:],
                providerSelectionTotalMsByKind: [:],
                executionTotalMsByKind: [:],
                activeProviderDurationTotalMs: [:],
                backendDurationTotalMs: [:],
                admissionSkipCountByReason: ["retrievalNotNeeded": 1],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: ["knowledge": 1, "control": 1],
                promptCharactersTotalByKind: [:],
                prefixCharactersTotalByKind: [:],
                immutablePrefixCharactersTotalByKind: [:],
                adaptivePrefixCharactersTotalByKind: [:],
                suffixCharactersTotalByKind: [:],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: ["retrievalNotNeeded", "insufficientChoiceSpread"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )

        #expect(summary.selectionRequestCount == 2)
        #expect(summary.selectionKnowledgeNeedRate == 0.5)
        #expect(summary.selectionControlOnlyRate == 0.5)
        #expect(summary.selectionRetrievalBypassCount == 1)
        #expect(summary.selectionRetrievalBypassRate == 0.5)
    }

    @Test("replay fingerprint is stable for identical bundles")
    func replayFingerprintIsStable() {
        let bundle = makeReplayBundle()

        let first = BASObservabilityInspector.replayFingerprint(for: bundle)
        let second = BASObservabilityInspector.replayFingerprint(for: bundle)

        #expect(first == second)
        #expect(first.value.count == 64)
    }

    @Test("audit policy-obs-misc LOW-3: distinct non-finite bundles get distinct fingerprints")
    func replayFingerprintDistinguishesNonFiniteBundles() {
        // Two DIFFERENT bundles, each with a non-finite reaction weight. The old code made encode()
        // THROW on non-finite floats → both fell back to SHA256(empty) → they COLLIDED. The encoder's
        // non-conforming-float strategy now serialises them distinctly.
        var a = makeReplayBundle()
        a.brainState.reactionWeights = BASReactionWeights(warmth: .nan, directness: 0.5, brevity: 0.8, actionBias: 0.6)
        var b = makeReplayBundle()
        b.brainState.reactionWeights = BASReactionWeights(warmth: .infinity, directness: 0.5, brevity: 0.8, actionBias: 0.6)
        let fpA = BASObservabilityInspector.replayFingerprint(for: a)
        let fpB = BASObservabilityInspector.replayFingerprint(for: b)
        #expect(fpA.value != fpB.value)
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
            inputSummary: "primary",
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

    @Test("inspection bundle blocks replay when a verified forget gate revokes replay artifacts")
    func inspectionBundleBlocksReplayWhenForgetGateRevokesReplayArtifacts() {
        let replayBundle = makeReplayBundle()
        let blockedBrainState = BASCurrentBrainState(
            mode: replayBundle.brainState.mode,
            dominantGoals: replayBundle.brainState.dominantGoals,
            activeConstraints: replayBundle.brainState.activeConstraints,
            reactionWeights: replayBundle.brainState.reactionWeights,
            activeTemplateIDs: replayBundle.brainState.activeTemplateIDs,
            recentFailurePatternIDs: replayBundle.brainState.recentFailurePatternIDs,
            retrievalTags: replayBundle.brainState.retrievalTags + [
                "forget_request:forget.guard.anchor",
                "forget_verified:true",
                "forget_checkpoints_revoked:true",
                "forget_sync_exports_revoked:true"
            ],
            verificationSnapshot: [
                replayBundle.brainState.verificationSnapshot,
                "forget:forget.guard.anchor",
                "forget_verified:true",
                "forget_checkpoints_revoked:true",
                "forget_sync_exports_revoked:true"
            ].joined(separator: "|")
        )

        let bundle = BASObservabilityInspector.inspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_456),
            trace: replayBundle.trace,
            brainState: blockedBrainState,
            runtimeContext: replayBundle.runtimeContext,
            policyDecision: replayBundle.policyDecision
        )

        #expect(bundle.replayDisposition.isAvailable == false)
        #expect(bundle.replayDisposition.forgetRequestID == "forget.guard.anchor")
        #expect(bundle.replayDisposition.checkpointsRevoked == true)
        #expect(bundle.replayDisposition.syncExportsRevoked == true)
        #expect(bundle.blockerSummary.contains(where: { $0.contains("forget.guard.anchor") }))
        #expect(bundle.summary.contains("replay blocked"))
        #expect(bundle.anomalySignals.contains(where: { $0.kind == "replay_revoked" }))
    }

    @Test("inspection bundle blocks replay when vault consistency is pending revocation propagation")
    func inspectionBundleBlocksReplayWhenVaultConsistencyIsPending() {
        let replayBundle = makeReplayBundle()
        let blockedBrainState = BASCurrentBrainState(
            mode: replayBundle.brainState.mode,
            dominantGoals: replayBundle.brainState.dominantGoals,
            activeConstraints: replayBundle.brainState.activeConstraints,
            reactionWeights: replayBundle.brainState.reactionWeights,
            activeTemplateIDs: replayBundle.brainState.activeTemplateIDs,
            recentFailurePatternIDs: replayBundle.brainState.recentFailurePatternIDs,
            retrievalTags: replayBundle.brainState.retrievalTags + [
                "vault_signature:abcd1234efgh5678",
                "vault_consistency:revocation_pending",
                "vault_sync_revocations:2",
                "vault_deletion_manifest:forget.private_notes",
                "vault_requires_approval:true"
            ],
            verificationSnapshot: [
                replayBundle.brainState.verificationSnapshot,
                "vault_signature:abcd1234efgh5678",
                "vault_consistency:revocation_pending",
                "vault_sync_revocations:2",
                "vault_deletion_manifest:forget.private_notes",
                "vault_requires_approval:true"
            ].joined(separator: "|")
        )

        let bundle = BASObservabilityInspector.inspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_789),
            trace: replayBundle.trace,
            brainState: blockedBrainState,
            runtimeContext: replayBundle.runtimeContext,
            policyDecision: replayBundle.policyDecision
        )

        #expect(bundle.replayDisposition.isAvailable == false)
        #expect(bundle.replayDisposition.vaultConsistencyState == "revocation_pending")
        #expect(bundle.replayDisposition.vaultDeletionManifestID == "forget.private_notes")
        #expect(bundle.replayDisposition.vaultSyncRevocationCount == 2)
        #expect(bundle.replayDisposition.vaultRequiresApproval == true)
        #expect(bundle.blockerSummary.contains(where: { $0.contains("forget.private_notes") }))
        #expect(bundle.summary.contains("replay blocked"))
        #expect(bundle.anomalySignals.contains(where: { $0.kind == "vault_consistency_risk" }))
    }

    @Test("inspection bundle surfaces device-level vault migration blockers")
    func inspectionBundleSurfacesDeviceLevelVaultMigrationBlockers() {
        let replayBundle = makeReplayBundle()
        let blockedBrainState = BASCurrentBrainState(
            mode: replayBundle.brainState.mode,
            dominantGoals: replayBundle.brainState.dominantGoals,
            activeConstraints: replayBundle.brainState.activeConstraints,
            reactionWeights: replayBundle.brainState.reactionWeights,
            activeTemplateIDs: replayBundle.brainState.activeTemplateIDs,
            recentFailurePatternIDs: replayBundle.brainState.recentFailurePatternIDs,
            retrievalTags: replayBundle.brainState.retrievalTags + [
                "vault_consistency:out_of_sync",
                "vault_out_of_sync_devices:2",
                "vault_out_of_sync_list:device.secondary,device.tablet",
                "vault_migration_target:device.secondary"
            ],
            verificationSnapshot: [
                replayBundle.brainState.verificationSnapshot,
                "vault_consistency:out_of_sync",
                "vault_out_of_sync_devices:2",
                "vault_out_of_sync_list:device.secondary,device.tablet",
                "vault_migration_target:device.secondary"
            ].joined(separator: "|")
        )

        let bundle = BASObservabilityInspector.inspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_790),
            trace: replayBundle.trace,
            brainState: blockedBrainState,
            runtimeContext: replayBundle.runtimeContext,
            policyDecision: replayBundle.policyDecision
        )

        #expect(bundle.replayDisposition.isAvailable == false)
        #expect(bundle.replayDisposition.vaultConsistencyState == "out_of_sync")
        #expect(bundle.replayDisposition.vaultOutOfSyncDeviceIDs == ["device.secondary", "device.tablet"])
        #expect(bundle.replayDisposition.vaultMigrationTargetDeviceID == "device.secondary")
        #expect(bundle.replayDisposition.reason?.contains("device.secondary") == true)
        #expect(bundle.replayDisposition.reason?.contains("device.tablet") == true)
        #expect(bundle.summary.contains("device.secondary"))
        #expect(bundle.summary.contains("device.tablet"))
        #expect(bundle.summary.contains("migration target"))
    }

    @Test("lifecycle summary compiler tracks rebuilds and evidence compaction")
    func lifecycleSummaryCompilerTracksRebuildsAndCompaction() {
        let summary = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "primary",
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
                    kind: "primary",
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
                    kind: "reflective",
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
        #expect(summary.rebuildCountByKind["primary"] == 1)
        #expect(summary.staleFieldDropCount == 3)
        #expect(summary.retainedEvidenceCount == 6)
        #expect(summary.retainedEvidenceCountByKind["primary"] == 3)
        #expect(summary.droppedEvidenceCount == 3)
        #expect(summary.droppedInjectedEvidenceCountByKind["primary"] == 1)
        #expect(summary.droppedDuplicateEvidenceCountByKind["primary"] == 1)
        #expect(summary.droppedBudgetEvidenceCountByKind["primary"] == 1)
        #expect(summary.averageAnchorFieldCountByKind["primary"] == 2)
        #expect(summary.averageRetainedEvidenceCountByKind["primary"] == 1.5)
        #expect(summary.latestGenerationByKind["primary"] == 3)
    }

    @Test("neural summary compiler keeps dominant route and strongest signal by kind")
    func neuralSummaryCompilerTracksDominantSignals() {
        let summary = BASNeuralSummaryBuilder.build(
            from: [
                BASNeuralTraceInput(
                    kind: "primary",
                    suppressedBehaviorCount: 2,
                    dominantActionRawValue: "waitBuffer",
                    strongestSignalRawValue: "urgency"
                ),
                BASNeuralTraceInput(
                    kind: "primary",
                    suppressedBehaviorCount: 1,
                    dominantActionRawValue: "stepAway",
                    strongestSignalRawValue: "fatigue"
                ),
                BASNeuralTraceInput(
                    kind: "reflective",
                    suppressedBehaviorCount: 3,
                    dominantActionRawValue: "protectSelf",
                    strongestSignalRawValue: "identityDrift"
                )
            ]
        )

        #expect(summary.neuralTraceCount == 3)
        #expect(summary.suppressedBehaviorCount == 6)
        #expect(summary.dominantActionByKind["primary"] == "waitBuffer")
        #expect(summary.strongestSignalByKind["reflective"] == "identityDrift")
    }

    @Test("brain summary compiler aggregates governance calibration and evolution")
    func brainSummaryCompilerAggregatesGovernanceCalibrationAndEvolution() {
        let summary = BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "primary",
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
                    kind: "primary",
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
                    kind: "reflective",
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
                    identityRole: .reflectiveWitness,
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
        #expect(summary.dominantReactionWeightByKind["primary"] == .briefLanguage)
        #expect(summary.averageProfileCoreCountByKind["primary"] == 3)
        #expect(summary.averageLoadedPendingMemoryCountByKind["primary"] == 1)
        #expect(summary.pendingMemoryLoadRateByKind["primary"] == 1.0 / 3.0)
        #expect(summary.retrievalRejectionRateByKind["primary"] == 0.25)
        // audit policy-obs-misc LOW-4: "latest" must be the NEWEST (last) of the oldest-first traces,
        // fp-q-2 — not fp-q-1 (the OLDEST) the field returned when it used firstValueByKind.
        #expect(summary.latestSnapshotFingerprintByKind["primary"] == "fp-q-2")
        #expect(summary.snapshotVariantCountByKind["primary"] == 2)
        #expect(summary.lowTrustMemoryLoadRateByKind["primary"] == 0.375)
        #expect(summary.riskFlagCountsByKind["primary"]?[.lowTrustLoad] == 2)
        #expect(summary.boundaryConstraintCountsByKind["primary"]?[.lockSensitiveMemory] == 2)
        #expect(summary.calibrationStatusByKind["primary"] == .watch)
        #expect(summary.calibrationAlertCountsByKind["primary"]?[.templateCoverageGap] == 1)
        #expect(summary.evolutionCheckpointCountByKind["primary"] == 3)
        #expect(summary.evolutionPendingReviewCountByKind["primary"] == 2)
        #expect(summary.evolutionRollbackReadyByKind["primary"] == true)
    }

    @Test("runtime inspection builder compiles cross-domain summary from substrate inputs")
    func runtimeInspectionBuilderCompilesCrossDomainSummary() {
        let telemetry = BASTelemetrySummaryBuilder.build(
            from: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 2],
                outcomeCount: [.providerSuccess: 1, .cacheHit: 1],
                outcomeCountByKind: [
                    .providerSuccess: ["primary": 1],
                    .cacheHit: ["primary": 1]
                ],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: ["cpu": 1],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 220],
                firstPresentableTotalMsByKind: ["primary": 140],
                promptAssemblyTotalMsByKind: ["primary": 40],
                admissionEvaluationTotalMsByKind: ["primary": 20],
                providerSelectionTotalMsByKind: ["primary": 10],
                executionTotalMsByKind: ["primary": 70],
                activeProviderDurationTotalMs: ["gemmaE4B": 220],
                backendDurationTotalMs: ["cpu": 220],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 480],
                prefixCharactersTotalByKind: ["primary": 180],
                immutablePrefixCharactersTotalByKind: ["primary": 120],
                adaptivePrefixCharactersTotalByKind: ["primary": 60],
                suffixCharactersTotalByKind: ["primary": 300],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: ["primary": 1],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: ["retrievalNotNeeded", "insufficientChoiceSpread"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )
        let lifecycle = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "primary",
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
                    kind: "primary",
                    suppressedBehaviorCount: 1,
                    dominantActionRawValue: "waitBuffer",
                    strongestSignalRawValue: "urgency"
                )
            ]
        )
        let brain = BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "primary",
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

        let summary = BASRuntimeInspectionBuilder.build(
            from: BASRuntimeInspectionInput(
                activeProviderID: "gemmaE4B",
                fallbackProviderID: nil,
                runtimeGear: .low,
                environmentClass: .normal,
                deviceClass: .balancedPhone,
                languageMode: .english,
                taskEntropyByKind: ["primary": .low],
                preferredProviderRawValueByKind: ["primary": "gemmaE4B"],
                strategyByKind: [
                    "primary": BASAdaptiveTaskStrategy(
                        kind: .primary,
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
                effectivePreferredProviderRawValueByKind: ["primary": "gemmaE4B"],
                traceInputs: [
                    BASRuntimeInspectionTraceInput(
                        kind: "primary",
                        attemptedProviderIDs: ["gemmaE4B"],
                        runtimeStrategy: BASAdaptiveTaskStrategy(
                            kind: .primary,
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

        #expect(summary.activeProviderID == "gemmaE4B")
        #expect(summary.runtimeGearByKind["primary"] == .low)
        #expect(summary.effectiveRuntimeGearByKind["primary"] == .low)
        #expect(summary.firstAttemptedProviderByKind["primary"] == "gemmaE4B")
        #expect(summary.effectiveProviderOrderByKind["primary"] == ["gemmaE4B"])
        #expect(summary.semanticPromptVariantCountByKind["primary"] == 1)
        #expect(summary.stablePrefixVariantCountByKind["primary"] == 1)
        #expect(summary.consistencyCheckedTraceCount == 1)
        #expect(summary.consistencyRejectedTraceCount == 0)
        #expect(summary.evidenceRetentionRatio == 2.0 / 3.0)
        #expect(summary.evidencePollutionRateByKind["primary"] == 1.0 / 3.0)
        #expect(summary.averageRequestDurationMsByBackend["cpu"] == 220)
        #expect(summary.boundaryModeByKind["primary"] == .localOnlyAdvisory)
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
                mode: "primary",
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
