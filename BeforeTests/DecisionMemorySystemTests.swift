import XCTest
import SwiftData
import BASAppleAdapters
import BASMemory
import BASRuntimeCore
@testable import Before

final class DecisionMemorySystemTests: XCTestCase {
    @MainActor
    func testRefreshStoredMemoriesDerivesStructuredRecordsFromHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        let memories = DecisionMemorySystem.refreshStoredMemories(in: context)

        XCTAssertTrue(memories.contains(where: { $0.id == "preference.communication.concise" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "semantic.scenario.buy" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertTrue(memories.contains(where: { $0.type == .goal }))
    }

    @MainActor
    func testRefreshStoredMemoriesStagesSituationalCandidatesWithoutPromotingThem() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)
        let candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let quickCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "situational.quick.latest" }))
        XCTAssertEqual(quickCandidate.status, .pending)
        XCTAssertEqual(quickCandidate.lastWriteOperation, .noop)
        XCTAssertFalse(
            DecisionMemorySystem.fetchMemoryRecords(in: context)
                .contains(where: { $0.id == "situational.quick.latest" })
        )
    }

    @MainActor
    func testRefreshStoredMemoriesUsesExplicitMemoryWriteOperations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context, now: stableNow)
        var candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let supportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(supportCandidate.status, .promoted)
        XCTAssertEqual(supportCandidate.lastWriteOperation, .add)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context, now: stableNow)
        candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let unchangedSupportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(unchangedSupportCandidate.lastWriteOperation, .noop)
        XCTAssertEqual(unchangedSupportCandidate.confirmationCount, 1)
    }

    @MainActor
    func testRefreshStoredMemoriesStagesStableNonGoalDraftsWhenExecutionFrameRequiresExternalRefresh() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        let volatileFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelHeuristic,
            reasonCodes: []
        )

        let memories = DecisionMemorySystem.refreshStoredMemories(
            in: context,
            executionCapabilityFrame: volatileFrame,
            now: date("2026-04-09T23:10:00Z")
        )
        let candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        XCTAssertTrue(memories.contains(where: { $0.type == .goal }))
        XCTAssertFalse(memories.contains(where: { $0.id == "semantic.scenario.buy" }))

        let semanticCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "semantic.scenario.buy" }))
        XCTAssertEqual(semanticCandidate.status, .pending)
        XCTAssertEqual(semanticCandidate.lastGovernanceDecision, .deferred)
        XCTAssertEqual(semanticCandidate.decayPolicy, .fast)
        XCTAssertEqual(semanticCandidate.tierRaw, "volatile")
        XCTAssertTrue(semanticCandidate.retrievalTags.contains("external_refresh"))
        XCTAssertTrue(semanticCandidate.retrievalTags.contains("volatile"))
    }

    func testHorizonAwareMemoryPersistencePolicyRequiresCorroborationWhenExecutionFrameRequiresCaveat() {
        let supportedFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelDedicated,
            reasonCodes: []
        )

        let policy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: supportedFrame
        )

        XCTAssertEqual(policy.minimumDurableEvidenceCount, 2)
        XCTAssertTrue(policy.evidencePendingRetrievalTags.contains("evidence_caveat"))
        XCTAssertEqual(policy.volatileClaimWriteMode, .admitDirectly)
    }

    @MainActor
    func testLoadBrainStateReconstructsProfileGoalsAndRelevantMemories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.profileCore.contains("Short, direct language lands better."))
        XCTAssertTrue(
            brainState.activeGoals.contains(where: { $0.contains("Sleep before midnight") }),
            "Expected sleep goal in \(brainState.activeGoals)"
        )
        XCTAssertTrue(
            brainState.relevantMemories.contains(where: { $0.contains("Buy pressure keeps recurring.") }),
            "Expected repeated buy pattern in \(brainState.relevantMemories)"
        )
        XCTAssertTrue(brainState.relevantMemories.contains(where: {
            $0.contains("Holding the decision") ||
                $0.contains("lighter, shorter guidance") ||
                $0.contains("Recently carrying") ||
                $0.contains("Recently weighing")
        }), "Expected stabilizing or context-carrying memory in \(brainState.relevantMemories)")
        XCTAssertTrue(brainState.sessionBiases.contains("Keep the language short and concrete."))
        XCTAssertTrue(brainState.sessionBiases.contains(where: { $0.localizedCaseInsensitiveContains("late at night") }))
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.briefLanguage, 0.9)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.8)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.7)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.totalRecordCount, 4)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.pendingCandidateCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.loadedPromotedMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.deferredCandidateCount, 1)
        XCTAssertTrue(brainState.retrievalTags.contains("quick"))
        XCTAssertTrue(brainState.retrievalTags.contains("buy"))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .profile &&
                $0.governanceStatus == .admitted &&
                $0.eligibility == .allowed(.defaultAllowed)
        }))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .goal &&
                $0.eligibility == .allowed(.goalOverride)
        }))
    }

    @MainActor
    func testLoadBrainStateRaisesInterruptiveBiasWhenReflectionsRewardPausePaths() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T08:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I almost bought it again after a stressful morning.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "Tomorrow usually feels quieter.",
                verdict: .pause,
                finalAction: .wait90s,
                reflectionOutcome: .notNeeded,
                entrySource: .app
            )
        )
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T09:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I pushed through anyway and felt worse.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "It usually feels noisy tomorrow.",
                verdict: .pause,
                finalAction: .goAheadAnyway,
                reflectionOutcome: .feltEmptier,
                entrySource: .app
            )
        )

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this again late at night.",
            context: context,
            now: date("2026-04-09T23:20:00Z")
        )

        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.85)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.85)
    }

    @MainActor
    func testLoadBrainStateScreensOutStalePendingMemoriesWhenTheyAreNotRelevant() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Help me think about whether I should cook at home tonight.",
            context: context,
            now: date("2026-04-10T18:00:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutPendingMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.confidenceNoOverlap] ?? 0,
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: \.isPending))
    }

    @MainActor
    func testLoadBrainStateScreensOutPendingCandidatesWithoutOverlapAfterGraceWindow() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "situational.market.latest",
                type: .situational,
                topic: "market_latest",
                headline: "Tonight's market move",
                value: "volatile market signal",
                confidence: 0.79,
                priority: 0.76,
                source: .reflection,
                firstObservedAt: date("2026-04-08T00:00:00Z"),
                lastObservedAt: date("2026-04-08T00:00:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["latest", "market", "night"],
                evidenceCount: 2,
                confirmationCount: 1,
                lastObservationFingerprint: "market-fp",
                status: .pending,
                provenanceSummary: "Fresh reflection from tonight.",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Awaiting confirmation."
            )
        )
        try context.save()

        let volatileBrainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Help me decide whether to cook at home tonight.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(volatileBrainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertEqual(
            volatileBrainState.memoryGovernance.screenedOutReasonCounts[.confidenceNoOverlap],
            1
        )
        XCTAssertFalse(
            volatileBrainState.memorySlices.contains(where: { $0.id == "situational.market.latest" })
        )
    }

    @MainActor
    func testLoadBrainStateMakesRetrievalModeExecutable() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let filtered = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z")
        )

        let off = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .off,
            now: date("2026-04-09T23:10:00Z")
        )

        let adaptive = DecisionMemorySystem.loadBrainState(
            mode: .mirror,
            prompt: "Should I stay in this relationship?",
            context: context,
            retrievalMode: .adaptive,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertGreaterThan(filtered.memorySlices.count, off.memorySlices.count)
        XCTAssertGreaterThan(filtered.memoryGovernance.loadedPendingMemoryCount, off.memoryGovernance.loadedPendingMemoryCount)
        XCTAssertEqual(off.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertLessThanOrEqual(off.relevantMemories.count, 1)
        XCTAssertGreaterThanOrEqual(adaptive.relevantMemories.count, 2)
    }

    @MainActor
    func testLoadBrainStateScreensOutContaminatedCandidateBeforeFrontstageLoad() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "semantic.injected.buy",
                type: .semantic,
                topic: "buy",
                headline: "Buy pressure keeps recurring.",
                value: "buy",
                confidence: 0.88,
                priority: 0.84,
                source: .pattern,
                firstObservedAt: date("2026-04-09T20:00:00Z"),
                lastObservedAt: date("2026-04-09T20:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["buy", "night", "pattern"],
                evidenceCount: 3,
                confirmationCount: 2,
                lastObservationFingerprint: "fp",
                status: .pending,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Pending verification."
            )
        )
        try context.save()

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this late at night again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.provenanceContamination],
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: { $0.id == "semantic.injected.buy" }))
        XCTAssertTrue(brainState.verificationSnapshot.riskFlags.contains(.contaminationGuardTriggered))
    }

    @MainActor
    func testLoadBrainStateAnnotatesHorizonRefreshAndQuarantineSignals() {
        let compiledState = DecisionBrainState(
            profileCore: [],
            activeGoals: ["Ship the fix safely."],
            relevantMemories: [],
            sessionBiases: ["baseline"],
            retrievalTags: ["baseline"],
            reactionWeights: .defaults(for: "quick"),
            identityProfile: .default(modeName: "quick"),
            boundaryPolicy: .default(riskLevel: BASRiskLevel.low),
            memoryGovernance: BASMemoryGovernanceState(
                totalRecordCount: 0,
                totalCandidateCount: 2,
                pendingCandidateCount: 2,
                promotedCandidateCount: 0,
                loadedPromotedMemoryCount: 0,
                loadedPendingMemoryCount: 0,
                screenedOutReasonCounts: [.externalRefreshNoOverlap: 1]
            ),
            loadedAt: date("2026-04-09T23:10:00Z")
        )

        let projection = BASAppleMemoryProjectionRefreshResult(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [
                    BASMemoryEligibilityCandidate(
                        id: "candidate.external-refresh",
                        role: .relevant,
                        kind: .semantic,
                        headline: "Latest policy note is still volatile.",
                        source: .pattern,
                        scope: .task,
                        sensitivity: .medium,
                        confidence: 0.66,
                        priority: 0.71,
                        retrievalTags: ["external_refresh", "volatile"],
                        lastConfirmedAt: date("2026-04-09T23:10:00Z"),
                        decayPolicy: .fast,
                        lifecycleState: "warming",
                        governanceStatus: .deferred,
                        isPending: true,
                        provenanceSummary: "Needs refreshed evidence.",
                        sourceTrustScore: 0.58,
                        sourceTrustTier: .medium,
                        effectiveConfidence: 0.61,
                        provenanceRisk: false
                    ),
                    BASMemoryEligibilityCandidate(
                        id: "candidate.tool-quarantine",
                        role: .relevant,
                        kind: .situational,
                        headline: "Tool observation has not been corroborated yet.",
                        source: .pattern,
                        scope: .task,
                        sensitivity: .medium,
                        confidence: 0.61,
                        priority: 0.64,
                        retrievalTags: ["quarantined", "tool_observation"],
                        lastConfirmedAt: date("2026-04-09T23:10:00Z"),
                        decayPolicy: .fast,
                        lifecycleState: "warming",
                        governanceStatus: .deferred,
                        isPending: true,
                        provenanceSummary: "Observation-only candidate.",
                        sourceTrustScore: 0.56,
                        sourceTrustTier: .medium,
                        effectiveConfidence: 0.58,
                        provenanceRisk: false
                    )
                ],
                recentEvents: [],
                governanceSnapshot: BASMemoryGovernanceState(
                    totalRecordCount: 0,
                    totalCandidateCount: 2,
                    pendingCandidateCount: 2,
                    promotedCandidateCount: 0,
                    loadedPromotedMemoryCount: 0,
                    loadedPendingMemoryCount: 0
                )
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 0,
                totalCandidateCount: 2,
                pendingCandidateCount: 2,
                promotedCandidateCount: 0,
                deferredCandidateCount: 2,
                admittedCandidateCount: 0
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 0,
                candidateCount: 2,
                allCandidatesPending: true
            ),
            refreshedAt: date("2026-04-09T23:10:00Z")
        )

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Should I trust the newest tool note?",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                compiledState
            }
        )

        XCTAssertTrue(brainState.sessionBiases.contains("horizon-external-refresh"))
        XCTAssertTrue(brainState.sessionBiases.contains("horizon-tool-quarantine"))
        XCTAssertTrue(
            brainState.sessionBiases.contains("Keep uncertainty visible until fresh evidence arrives.")
        )
        XCTAssertTrue(
            brainState.sessionBiases.contains("Treat tool observations as provisional until corroborated.")
        )
        XCTAssertTrue(brainState.retrievalTags.contains("external_refresh"))
        XCTAssertTrue(brainState.retrievalTags.contains("volatile"))
        XCTAssertTrue(brainState.retrievalTags.contains("quarantine"))
        XCTAssertTrue(brainState.retrievalTags.contains("tool_observation"))
    }

    @MainActor
    func testBrainStateVerificationSnapshotIsStableForSameInputs() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let first = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let second = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(first.verificationSnapshot.fingerprint, second.verificationSnapshot.fingerprint)
        XCTAssertEqual(
            first.verificationSnapshot.dominantReactionWeight,
            second.verificationSnapshot.dominantReactionWeight
        )
        XCTAssertGreaterThan(first.verificationSnapshot.loadedMemoryCount, 0)
    }

    @MainActor
    func testLoadBrainStateAddsLanguageAndScriptTagsForChinesePrompt() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "我今晚又想买这个。",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.retrievalTags.contains("lang:chinese"))
        XCTAssertTrue(brainState.retrievalTags.contains("script:han"))
        XCTAssertTrue(brainState.retrievalTags.contains(where: { $0.contains("今晚") || $0.contains("想买") }))
    }

    @MainActor
    func testLoadBrainStateFallbackRecordsAuditableNoticeAndDegradedBias() {
        enum SyntheticFailure: Error {
            case compilerRejected
        }

        PersistenceIssueRecorder.clear()
        defer { PersistenceIssueRecorder.clear() }
        let projection = DecisionMemorySystem.BrainStateProjection(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                activeTemplateIDs: ["projection.template/bootstrap-rebuild"],
                failureGuardIDs: ["projection.guard/compiler-drift"]
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 7,
                totalCandidateCount: 4,
                pendingCandidateCount: 2,
                promotedCandidateCount: 2,
                deferredCandidateCount: 1,
                admittedCandidateCount: 1
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 3,
                candidateCount: 2,
                allCandidatesPending: false
            ),
            refreshedAt: date("2026-04-09T23:09:30Z")
        )

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I need a fallback path.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        XCTAssertTrue(brainState.sessionBiases.contains("brain-bootstrap-recovery"))
        XCTAssertTrue(brainState.sessionBiases.contains("brain-bootstrap-remediation-required"))
        XCTAssertTrue(brainState.retrievalTags.contains("recovery"))
        XCTAssertTrue(brainState.retrievalTags.contains("restricted"))
        XCTAssertTrue(brainState.retrievalTags.contains("restricted-lease"))
        XCTAssertTrue(brainState.retrievalTags.contains("tool-write-blocked"))
        XCTAssertTrue(brainState.retrievalTags.contains("memory-write-blocked"))
        XCTAssertTrue(brainState.retrievalTags.contains("deep-loop-blocked"))
        XCTAssertEqual(brainState.boundaryPolicy.mode, .localOnlyProtective)
        XCTAssertEqual(
            brainState.boundaryPolicy.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryAllowedActionClasses
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBlockedActionClasses
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryRequiredConfirmations
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.activeConstraints,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBoundaryConstraints
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.auditHeadline,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBoundaryAuditHeadline
        )
        XCTAssertEqual(brainState.calibrationState.status, .drifting)
        XCTAssertTrue(brainState.calibrationState.alerts.contains(.templateCoverageGap))
        XCTAssertEqual(
            brainState.activeInterventionTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/recovery-remediation",
                "projection.template/bootstrap-rebuild"
            ]
        )
        XCTAssertEqual(
            brainState.failureGuardIDs,
            [
                "before.guard/bootstrap-recovery",
                "before.guard/restricted-writes",
                "projection.guard/compiler-drift"
            ]
        )
        XCTAssertEqual(
            brainState.reactionWeights,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .recoveryReactionWeightsByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(
            brainState.identityProfile,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .recoveryIdentityProfilesByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(brainState.memoryGovernance.totalRecordCount, 7)
        XCTAssertEqual(brainState.memoryGovernance.totalCandidateCount, 4)
        XCTAssertEqual(brainState.memoryGovernance.pendingCandidateCount, 2)
        XCTAssertEqual(brainState.memoryGovernance.promotedCandidateCount, 2)
        XCTAssertEqual(brainState.memoryGovernance.deferredCandidateCount, 1)
        XCTAssertEqual(brainState.memoryGovernance.admittedCandidateCount, 1)
        XCTAssertEqual(brainState.evolutionState.pendingReviewCount, 2)
        XCTAssertTrue(
            brainState.evolutionState.recentDiffSummary.contains(where: {
                $0.localizedCaseInsensitiveContains("recovery")
            })
        )
        XCTAssertNotNil(PersistenceIssueRecorder.latestNotice())
        XCTAssertTrue(
            PersistenceIssueRecorder.latestNotice()?.contains("bootstrapping current brain state from projection") == true
        )
        let issue = PersistenceIssueRecorder.latestIssue()
        XCTAssertEqual(issue?.category, .brainBootstrapFallback)
        XCTAssertEqual(issue?.severity, .warning)
        XCTAssertEqual(issue?.operation, "bootstrapping current brain state from projection")
        XCTAssertTrue(issue?.remediation?.localizedCaseInsensitiveContains("restricted recovery") == true)
    }

    @MainActor
    func testRepeatedBrainBootstrapFallbackEscalatesToQuarantineContract() {
        enum SyntheticFailure: Error {
            case compilerRejected
        }

        PersistenceIssueRecorder.clear()
        defer { PersistenceIssueRecorder.clear() }
        let projection = DecisionMemorySystem.BrainStateProjection(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                activeTemplateIDs: ["projection.template/bootstrap-rebuild"],
                failureGuardIDs: ["projection.guard/compiler-drift"]
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 9,
                totalCandidateCount: 5,
                pendingCandidateCount: 3,
                promotedCandidateCount: 2,
                deferredCandidateCount: 2,
                admittedCandidateCount: 1
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 4,
                candidateCount: 3,
                allCandidatesPending: false
            ),
            refreshedAt: date("2026-04-09T23:09:30Z")
        )

        _ = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "First recovery attempt.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        let quarantinedBrainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Second recovery attempt.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:11:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("brain-bootstrap-quarantine"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("quarantine"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("restricted-lease"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("tool-write-blocked"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("memory-write-blocked"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("deep-loop-blocked"))
        XCTAssertEqual(quarantinedBrainState.boundaryPolicy.mode, .localOnlyProtective)
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineAllowedActionClasses
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBlockedActionClasses
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineRequiredConfirmations
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.activeConstraints,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBoundaryConstraints
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.auditHeadline,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBoundaryAuditHeadline
        )
        XCTAssertEqual(
            quarantinedBrainState.activeInterventionTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/quarantine-lane",
                "before.template/recovery-remediation",
                "projection.template/bootstrap-rebuild"
            ]
        )
        XCTAssertEqual(
            quarantinedBrainState.failureGuardIDs,
            [
                "before.guard/bootstrap-recovery",
                "before.guard/bootstrap-quarantine",
                "before.guard/restricted-writes",
                "projection.guard/compiler-drift"
            ]
        )
        XCTAssertEqual(
            quarantinedBrainState.reactionWeights,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .quarantineReactionWeightsByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(
            quarantinedBrainState.identityProfile,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .quarantineIdentityProfilesByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.totalRecordCount, 9)
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.pendingCandidateCount, 3)
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.deferredCandidateCount, 2)
        XCTAssertEqual(quarantinedBrainState.evolutionState.pendingReviewCount, 3)
        XCTAssertEqual(PersistenceIssueRecorder.latestIssue()?.severity, .critical)
    }

    @MainActor
    func testRefreshProjectionUsesBoundedWorkingSetAndPreservesGovernanceCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0..<110 {
            context.insert(
                DecisionMemoryRecord(
                    id: "record-\(index)",
                    type: .semantic,
                    topic: "topic-\(index)",
                    headline: "Headline \(index)",
                    value: "Value \(index)",
                    confidence: 0.8,
                    priority: Double(200 - index),
                    source: .pattern,
                    lastConfirmedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 60),
                    decayPolicy: .slow,
                    retrievalTags: ["tag-\(index)"],
                    evidenceCount: 2,
                    observationCount: 2,
                    provenanceSummary: "Synthetic record \(index)"
                )
            )
        }

        for index in 0..<44 {
            context.insert(
                DecisionMemoryCandidateRecord(
                    id: "candidate-\(index)",
                    type: .situational,
                    topic: "candidate-topic-\(index)",
                    headline: "Candidate \(index)",
                    value: "Candidate value \(index)",
                    confidence: 0.7,
                    priority: Double(100 - index),
                    source: .history,
                    firstObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    lastObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    decayPolicy: .fast,
                    retrievalTags: ["candidate-\(index)"],
                    evidenceCount: 1,
                    confirmationCount: 1,
                    lastObservationFingerprint: "fingerprint-\(index)",
                    status: index < 26 ? .pending : .promoted,
                    provenanceSummary: "Synthetic candidate \(index)",
                    lastWriteOperation: .add,
                    lastGovernanceDecision: index.isMultiple(of: 2) ? .admit : .deferred,
                    governanceReason: "synthetic"
                )
            )
        }
        try context.save()

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(projection.governanceSnapshot.totalRecordCount, 110)
        XCTAssertEqual(projection.governanceSnapshot.totalCandidateCount, 44)
        XCTAssertEqual(projection.governanceSnapshot.pendingCandidateCount, 26)
        XCTAssertEqual(projection.governanceSnapshot.promotedCandidateCount, 18)
        XCTAssertEqual(projection.governanceSnapshot.admittedCandidateCount, 22)
        XCTAssertEqual(projection.governanceSnapshot.deferredCandidateCount, 22)
        XCTAssertLessThanOrEqual(projection.diagnostics.recordCount, DecisionMemorySystem.projectionRecordLimit)
        XCTAssertLessThanOrEqual(projection.diagnostics.candidateCount, DecisionMemorySystem.projectionCandidateLimit)
        XCTAssertTrue(projection.diagnostics.allCandidatesPending)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: CheckEvent.self,
            SelfReminder.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
    }

    @MainActor
    private func seedHistory(into context: ModelContext) {
        let checkDates = [
            date("2026-04-08T22:10:00Z"),
            date("2026-04-07T22:45:00Z"),
            date("2026-04-06T23:05:00Z")
        ]

        checkDates.forEach { createdAt in
            context.insert(
                CheckEvent(
                    createdAt: createdAt,
                    scenario: .buy,
                    motivation: .reward,
                    expectedOutcome: .temporaryRelief,
                    controlLevel: .maybe,
                    note: "I want these shoes after a rough day.",
                    currentPerspective: "You want a quick hit of relief.",
                    afterPerspective: "It usually feels noisy tomorrow.",
                    verdict: .pause,
                    finalAction: .decideTomorrow,
                    entrySource: .app
                )
            )
        }

        context.insert(
            BalanceDecisionRecord(
                createdAt: date("2026-04-08T09:00:00Z"),
                updatedAt: date("2026-04-08T09:05:00Z"),
                prompt: "Should I keep taking late freelance work?",
                desire: "Extra income",
                concern: "It wrecks sleep",
                constraint: "Bills are real",
                longTerm: "Sleep before midnight",
                focusTitle: "Protect sleep",
                focusSummary: "The real trade-off is cash versus recovery.",
                nextAction: "Cap late work to two nights.",
                entrySource: .app
            )
        )

        context.insert(
            MirrorDecisionRecord(
                createdAt: date("2026-04-08T12:00:00Z"),
                updatedAt: date("2026-04-08T12:10:00Z"),
                prompt: "Should I stay in this relationship?",
                emotion: "Drained",
                relationship: "I keep shrinking around them.",
                reality: "Nothing changes after the apology.",
                longTerm: "Stop shrinking myself in love",
                selfLens: "I stay because ending it feels empty.",
                coreTension: "Comfort keeps beating truth.",
                nextActionTitle: "Name the real cost",
                nextAction: "Write what staying is costing your life.",
                entrySource: .app
            )
        )

        [
            "Keep it short. I do not need a speech.",
            "This is stress shopping again.",
            "Tomorrow is still an option."
        ].forEach { content in
            context.insert(
                SelfReminder(
                    content: content,
                    scenario: .buy,
                    source: .userWritten,
                    createdAt: date("2026-04-08T08:00:00Z"),
                    lastUsedAt: date("2026-04-08T21:55:00Z"),
                    useCount: 1
                )
            )
        }

        try? context.save()
    }

    private func date(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601) ?? .now
    }
}
