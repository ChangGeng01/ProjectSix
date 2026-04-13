import XCTest
import SwiftData
import BASHostKit
@testable import Before

final class DecisionEvolutionEngineTests: XCTestCase {
    @MainActor
    func testEvolutionEngineDeduplicatesEquivalentCheckpointState() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        let brainState = DecisionBrainState(
            profileCore: ["Keep it brief."],
            activeGoals: ["Protect sleep"],
            relevantMemories: ["Tomorrow Box helps at night."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "night"],
            reactionWeights: .defaults(for: .quick),
            loadedAt: now
        )

        let first: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.launch.rawValue,
                    brainState: brainState
                ),
                in: context,
                createdAt: now
            )
        let second: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.launch.rawValue,
                    brainState: brainState
                ),
                in: context,
                createdAt: now.addingTimeInterval(60)
            )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(first.currentState.checkpointCount, 1)
        XCTAssertEqual(second.currentState.checkpointCount, 1)
        XCTAssertTrue(second.currentState.rollbackReady)
    }

    @MainActor
    func testEvolutionEngineMarksReviewSuggestedWhenCalibrationIsDrifting() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let boundaryPolicy = DecisionBoundaryPolicyState(
            mode: .localOnlyProtective,
            riskLevel: .high,
            allowedActionClasses: ["render_local_guidance"],
            blockedActionClasses: ["cloud_escalation"],
            requiredConfirmations: ["irreversible_decision"],
            activeConstraints: [.noCloudEscalation, .lockSensitiveMemory],
            auditHeadline: "Stay local."
        )
        let calibrationState = DecisionCalibrationState(
            status: .drifting,
            alerts: [.highPendingInfluence, .lowTrustLoad],
            suggestedAdjustments: ["Tighten retrieval."],
            driftScore: 0.64,
            generatedAt: .now
        )
        let brainState = DecisionBrainState(
            memorySlices: [
                DecisionGovernedMemorySlice(
                    id: "drifted",
                    role: .relevant,
                    type: "semantic",
                    headline: "Weak pattern",
                    source: "reflection",
                    confidence: 0.4,
                    priority: 0.4,
                    lifecycleState: "pending",
                    governanceStatus: .deferred,
                    eligibility: .allowed(.pendingTagOverlap),
                    sourceTrustScore: 0.2,
                    sourceTrustTier: .low,
                    retrievalTags: ["mirror"],
                    isPending: true,
                    provenanceSummary: "Weak inferred evidence."
                )
            ],
            sessionBiases: [],
            retrievalTags: ["mirror"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: DecisionIdentityProfile.default(for: .mirror),
            boundaryPolicy: boundaryPolicy,
            calibrationState: calibrationState,
            loadedAt: .now
        )

        let result: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.mirror.rawValue,
                    sourceID: BrainStateUpdateSource.sceneActive.rawValue,
                    brainState: brainState
                ),
                in: context,
                createdAt: .now
            )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(checkpoints.first?.approvalState, .reviewSuggested)
        XCTAssertEqual(result.currentState.pendingReviewCount, 1)
        XCTAssertTrue(result.currentState.recentDiffSummary.contains(where: { $0.contains("first local cognition checkpoint") }))
    }

    @MainActor
    func testEvolutionEngineAttachesLineageSummaryToLatestCheckpointWithoutAddingNewCheckpoint() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        let brainState = DecisionBrainState(
            profileCore: ["Keep it brief."],
            activeGoals: ["Protect sleep"],
            relevantMemories: ["Tomorrow Box helps at night."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "night"],
            reactionWeights: .defaults(for: .quick),
            loadedAt: now
        )

        _ = BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.quick.rawValue,
                sourceID: BrainStateUpdateSource.launch.rawValue,
                brainState: brainState
            ),
            in: context,
            createdAt: now
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "session-attach",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-attach",
            updateTicketSummaries: ["delay the message"],
            guardrailFindings: ["high-risk direct answer downgraded"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        let attachment: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.attachLineageSummary(
                lineage,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(attachment.currentState.latestCheckpoint?.lineageSummary, lineage)
        XCTAssertEqual(checkpoints.first?.lineageSummary, lineage)
    }

    @MainActor
    func testBridgeCanApproveCheckpointReviewWithoutCreatingExtraCheckpoint() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let driftingBrainState = DecisionBrainState(
            memorySlices: [],
            sessionBiases: ["watch review"],
            retrievalTags: ["mirror"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: .default(for: .mirror),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: DecisionCalibrationState(
                status: .drifting,
                alerts: [.highPendingInfluence],
                suggestedAdjustments: ["Require review."],
                driftScore: 0.61,
                generatedAt: .now
            ),
            loadedAt: .now
        )

        _ = BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.mirror.rawValue,
                sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                brainState: driftingBrainState
            ),
            in: context,
            createdAt: .now
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let initial = try XCTUnwrap(context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first)
        XCTAssertEqual(initial.approvalState, .reviewSuggested)

        let evolved = BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
            initial.id,
            to: .automatic,
            in: context
        )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(checkpoints.first?.approvalState, .automatic)
        XCTAssertEqual(evolved?.pendingReviewCount, 0)
        XCTAssertEqual(evolved?.latestCheckpoint?.approvalState, .automatic)
    }

    @MainActor
    func testBridgeCanClearPersistedCheckpointLineage() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        let brainState = DecisionBrainState(
            profileCore: ["Keep it brief."],
            activeGoals: ["Protect sleep"],
            relevantMemories: ["Tomorrow Box helps at night."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "night"],
            reactionWeights: .defaults(for: .quick),
            loadedAt: now
        )

        _ = BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.quick.rawValue,
                sourceID: BrainStateUpdateSource.launch.rawValue,
                brainState: brainState
            ),
            in: context,
            createdAt: now
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "session-clear",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-clear",
            updateTicketSummaries: ["wait until tomorrow"],
            guardrailFindings: ["high-risk direct answer downgraded"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        _ = BASAppleEvolutionCheckpointWriter.attachLineageSummary(
            lineage,
            in: context
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let checkpoint = try XCTUnwrap(context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first)
        XCTAssertNotNil(checkpoint.lineageSummary)

        let evolved = BehavioralAISubstrateBridge.clearEvolutionCheckpointLineage(
            checkpoint.id,
            in: context
        )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertNil(checkpoints.first?.lineageSummary)
        XCTAssertNil(evolved?.latestCheckpoint?.lineageSummary)
    }

    @MainActor
    func testBridgeCanRestoreCurrentBrainFromCheckpointSnapshot() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()

        let snapshotBrainState = DecisionBrainState(
            profileCore: ["Protect sleep."],
            activeGoals: ["Delay the message."],
            relevantMemories: ["High-risk conflict needs pacing."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["mirror", "high-risk"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: .default(for: .mirror),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: .stable(at: now),
            loadedAt: now
        )

        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "session-restore",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 88,
            thoughtFoldChecksum: "fold-restore",
            updateTicketSummaries: ["wait until tomorrow"],
            guardrailFindings: ["high-risk direct answer downgraded"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        _ = BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.mirror.rawValue,
                sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                brainState: snapshotBrainState,
                lineageSummary: lineage
            ),
            in: context,
            createdAt: now
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let checkpoint = try XCTUnwrap(context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first)
        let currentBrain = CurrentBrainState(
            source: .sceneActive,
            sourceSurface: .app,
            mode: .quick,
            riskLevel: .low,
            taskGraph: nil,
            brainState: DecisionBrainState(
                profileCore: ["Keep it short."],
                activeGoals: ["Ship a fast answer."],
                relevantMemories: ["Quick checks prefer brevity."],
                sessionBiases: ["Be concise."],
                retrievalTags: ["quick"],
                reactionWeights: .defaults(for: .quick),
                loadedAt: now
            ),
            dominantGoal: "Ship a fast answer.",
            activeConstraints: ["Be concise."],
            activeTemplateIDs: [],
            failureGuardIDs: [],
            sourceIntentEnvelope: nil,
            loadedAt: now
        )

        let restored = try XCTUnwrap(
            BehavioralAISubstrateBridge.restoreEvolutionCheckpoint(
                checkpoint.id,
                currentBrainState: currentBrain,
                taskGraph: nil,
                in: context,
                now: now.addingTimeInterval(30)
            )
        )

        var expectedBrainState = snapshotBrainState
        expectedBrainState.evolutionState = DecisionEvolutionState(
            latestCheckpoint: DecisionEvolutionCheckpointSummary(
                id: checkpoint.id,
                previousCheckpointID: checkpoint.previousCheckpointID,
                createdAt: checkpoint.createdAt,
                diffSummary: checkpoint.diffSummary,
                rollbackReady: checkpoint.rollbackReady,
                approvalState: checkpoint.approvalState,
                lineageSummary: checkpoint.lineageSummary
            ),
            checkpointCount: 1,
            rollbackReady: true,
            pendingReviewCount: checkpoint.approvalState == .reviewSuggested ? 1 : 0,
            recentDiffSummary: checkpoint.diffSummary
        )

        XCTAssertEqual(restored.mode, .mirror)
        XCTAssertEqual(restored.riskLevel, .high)
        XCTAssertEqual(restored.brainState, expectedBrainState)
        XCTAssertEqual(restored.dominantGoal, "Delay the message.")
        XCTAssertEqual(restored.evolutionState.latestCheckpoint?.id, checkpoint.id)
    }

    @MainActor
    func testBeforeAppModelApplyEvolutionCheckpointRestoresCurrentBrainAndActiveQuickSession() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")

        let preApplyBrain = try XCTUnwrap(app.currentBrainState)
        let preApplySessionBrain = try XCTUnwrap(app.activeQuickSession?.brainState)
        XCTAssertEqual(preApplyBrain.brainState, preApplySessionBrain)

        let checkpointDate = preApplyBrain.loadedAt.addingTimeInterval(60)
        let snapshotBrainState = DecisionBrainState(
            profileCore: ["Protect sleep."],
            activeGoals: ["Delay the message."],
            relevantMemories: ["High-risk conflict needs pacing."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["mirror", "high-risk"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: .default(for: .mirror),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: .stable(at: checkpointDate),
            loadedAt: checkpointDate
        )
        let lineage = BASEvolutionLineageSummary(
            recordedAt: checkpointDate,
            sessionID: "session-apply",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 88,
            thoughtFoldChecksum: "fold-apply",
            updateTicketSummaries: ["wait until tomorrow"],
            guardrailFindings: ["high-risk direct answer downgraded"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        _ = BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.mirror.rawValue,
                sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                brainState: snapshotBrainState,
                lineageSummary: lineage
            ),
            in: context,
            createdAt: checkpointDate
        ) as BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint>

        let checkpoint = try XCTUnwrap(
            context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first(where: {
                $0.createdAt == checkpointDate && $0.lineageSummary?.sessionID == "session-apply"
            })
        )
        let expected = try XCTUnwrap(
            BehavioralAISubstrateBridge.restoreEvolutionCheckpoint(
                checkpoint.id,
                currentBrainState: preApplyBrain,
                taskGraph: app.activeTaskGraph,
                in: context,
                now: checkpointDate.addingTimeInterval(30)
            )
        )

        app.applyEvolutionCheckpoint(
            checkpointID: checkpoint.id,
            now: checkpointDate.addingTimeInterval(30)
        )

        XCTAssertEqual(app.currentBrainState, expected)
        XCTAssertEqual(app.activeQuickSession?.brainState, expected.brainState)
        XCTAssertEqual(app.activeQuickSession?.brainState, app.currentBrainState?.brainState)
        XCTAssertNotEqual(preApplyBrain.brainState, expected.brainState)
        XCTAssertTrue(app.startupNotice?.contains("Applied checkpoint \(checkpoint.id)") == true)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .applyCheckpoint)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.isSuccess, true)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.affectedCheckpointIDs, [checkpoint.id])
    }

    @MainActor
    func testBeforeAppModelRollbackActiveEvolutionCheckpointRestoresPreviousCheckpoint() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")
        let currentBrain = try XCTUnwrap(app.currentBrainState)

        // Keep handcrafted checkpoints newer than the bootstrap checkpoint so
        // the chain reflects the actual rollback path we expect to test.
        let firstDate = currentBrain.loadedAt.addingTimeInterval(60)
        let firstBrainState = DecisionBrainState(
            profileCore: ["Pause before conflict."],
            activeGoals: ["Sleep first."],
            relevantMemories: ["A first checkpoint."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "sleep"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: .default(for: .quick),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.medium),
            calibrationState: .stable(at: firstDate),
            loadedAt: firstDate
        )
        let secondDate = firstDate.addingTimeInterval(300)
        let secondBrainState = DecisionBrainState(
            profileCore: ["Pause before conflict."],
            activeGoals: ["Reply tomorrow morning."],
            relevantMemories: ["A second checkpoint."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "reply"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: .default(for: .quick),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: .stable(at: secondDate),
            loadedAt: secondDate
        )

        let firstWrite: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                    brainState: firstBrainState
                ),
                in: context,
                createdAt: firstDate
            )
        let secondWrite: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                    brainState: secondBrainState
                ),
                in: context,
                createdAt: secondDate
            )

        let firstCheckpointID = try XCTUnwrap(
            firstWrite.orderedCheckpoints.first(where: {
                $0.createdAt == firstDate &&
                $0.fingerprint == firstBrainState.verificationSnapshot.fingerprint
            })?.id
        )
        let secondCheckpointID = try XCTUnwrap(
            secondWrite.orderedCheckpoints.first(where: {
                $0.createdAt == secondDate &&
                $0.fingerprint == secondBrainState.verificationSnapshot.fingerprint
            })?.id
        )
        XCTAssertTrue(firstWrite.wroteCheckpoint)
        XCTAssertTrue(secondWrite.wroteCheckpoint)
        XCTAssertNotEqual(firstCheckpointID, secondCheckpointID)

        app.applyEvolutionCheckpoint(checkpointID: secondCheckpointID, now: secondDate.addingTimeInterval(30))
        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(app.currentBrainState?.evolutionState.latestCheckpoint?.id, secondCheckpointID)
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, secondCheckpointID)
        XCTAssertEqual(controlSurface.activeCheckpoint?.previousCheckpointID, firstCheckpointID)
        XCTAssertEqual(controlSurface.activeRollbackCheckpointID, firstCheckpointID)

        app.rollbackActiveEvolutionCheckpoint(now: secondDate.addingTimeInterval(60))

        XCTAssertEqual(app.currentBrainState?.evolutionState.latestCheckpoint?.id, firstCheckpointID)
        XCTAssertEqual(app.activeQuickSession?.brainState?.evolutionState.latestCheckpoint?.id, firstCheckpointID)
        XCTAssertTrue(app.startupNotice?.contains("Rolled back the active checkpoint to \(firstCheckpointID).") == true)
    }

    @MainActor
    func testBeforeAppModelCheckpointReviewMutationSynchronizesActiveQuickSession() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I reply right now?")
        let currentBrain = try XCTUnwrap(app.currentBrainState)

        let checkpointDate = currentBrain.loadedAt.addingTimeInterval(60)
        let writeResult: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
            input: BASEvolutionCheckpointPlanner.checkpointInput(
                modeName: DecisionMode.quick.rawValue,
                sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                brainState: currentBrain.brainState
            ),
            in: context,
            createdAt: checkpointDate
        )

        let checkpointID = try XCTUnwrap(writeResult.currentState.latestCheckpoint?.id)

        app.markEvolutionCheckpointForReview(checkpointID: checkpointID)

        XCTAssertEqual(app.currentBrainState?.evolutionState.latestCheckpoint?.approvalState, .reviewSuggested)
        XCTAssertEqual(app.activeQuickSession?.brainState?.evolutionState.latestCheckpoint?.approvalState, .reviewSuggested)
        XCTAssertTrue(app.startupNotice?.contains("marked for review") == true)
    }

    @MainActor
    func testBeforeAppModelSystemFlightDeckPreservesPendingReviewCheckpointsWithoutLineage() async throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        let checkpointDate = localDate(year: 2026, month: 4, day: 10, hour: 22, minute: 0)
        let snapshotBrainState = DecisionBrainState(
            profileCore: ["Keep the line steady."],
            activeGoals: ["Require review before drift sticks."],
            relevantMemories: ["This checkpoint predates lineage export."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "review"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: .default(for: .quick),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.medium),
            calibrationState: .stable(at: checkpointDate),
            loadedAt: checkpointDate
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-legacy-app-model",
                createdAt: checkpointDate,
                fingerprint: "fingerprint-review-legacy",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Legacy pending review should stay visible on Home."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: snapshotBrainState,
                lineageSummary: nil
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let deck = await app.systemFlightDeck()

        XCTAssertEqual(deck.pendingReviewCheckpointCount, 1)
        XCTAssertEqual(deck.pendingReviewQueue.first?.checkpointID, "checkpoint-review-legacy-app-model")
        XCTAssertEqual(deck.pendingReviewQueue.first?.primarySummary, "Legacy pending review should stay visible on Home.")
        XCTAssertEqual(deck.pendingReviewQueue.first?.applyReady, true)
        XCTAssertNil(deck.pendingReviewQueue.first?.riskLevel)
    }

    @MainActor
    func testBeforeAppModelEvolutionControlSurfaceKeepsReviewSuggestedCurrentCheckpointOutOfActiveSlot() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")
        let currentBrain = try XCTUnwrap(app.currentBrainState)

        let checkpointDate = currentBrain.loadedAt.addingTimeInterval(60)
        let lineage = BASEvolutionLineageSummary(
            recordedAt: checkpointDate,
            sessionID: "session-control-surface",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 73,
            thoughtFoldChecksum: "fold-control",
            updateTicketSummaries: ["wait before replying"],
            guardrailFindings: ["control surface audit"],
            recommendedKillSwitches: ["host-write"]
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-control-surface-current",
                createdAt: checkpointDate,
                fingerprint: "fingerprint-control-current",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Current checkpoint should be shared across portrait and history."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: currentBrain.brainState,
                lineageSummary: lineage
            )
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-control-surface-legacy",
                createdAt: checkpointDate.addingTimeInterval(-120),
                fingerprint: "fingerprint-control-legacy",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Legacy review checkpoint should remain visible."],
                approvalState: .reviewSuggested,
                rollbackReady: false,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        try context.save()

        app.markEvolutionCheckpointForReview(checkpointID: "checkpoint-control-surface-current")
        let controlSurface = app.makeEvolutionControlSurface()

        XCTAssertEqual(controlSurface.pendingReviewCount, 2)
        XCTAssertEqual(controlSurface.rollbackReadyCount, 1)
        XCTAssertNotNil(controlSurface.activeCheckpoint)
        XCTAssertEqual(controlSurface.activeCheckpoint?.approvalState, .automatic)
        XCTAssertNotEqual(controlSurface.activeCheckpoint?.checkpointID, "checkpoint-control-surface-current")
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, "checkpoint-control-surface-current")
        XCTAssertEqual(controlSurface.reviewCheckpoint?.riskLevel, "high")
        XCTAssertEqual(controlSurface.reviewCheckpoint?.permitMode, "delay")
        XCTAssertEqual(controlSurface.reviewAuditFindings, ["control surface audit"])
        XCTAssertEqual(controlSurface.reviewKillSwitches, ["host-write"])
        XCTAssertEqual(controlSurface.pendingReviewQueue.map(\.checkpointID), [
            "checkpoint-control-surface-current",
            "checkpoint-control-surface-legacy"
        ])
    }

    @MainActor
    func testBeforeAppModelEvolutionControlSurfacePrefersAutomaticActiveCheckpointOverReviewSuggestedCurrentCheckpoint() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        let automaticLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 30),
            sessionID: "session-automatic-active",
            taskType: "summary",
            riskLevel: "low",
            permitMode: "answer",
            hostGatePercent: 42,
            thoughtFoldChecksum: "fold-automatic-active",
            updateTicketSummaries: ["automatic active checkpoint"],
            guardrailFindings: ["automatic active guardrail"],
            recommendedKillSwitches: []
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-automatic-active",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 30),
                fingerprint: "fingerprint-automatic-active",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Automatic checkpoint should remain active."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: automaticLineage
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I reopen this thread?")
        let currentBrain = try XCTUnwrap(app.currentBrainState)

        let reviewCheckpointDate = currentBrain.loadedAt.addingTimeInterval(60)
        let reviewLineage = BASEvolutionLineageSummary(
            recordedAt: reviewCheckpointDate,
            sessionID: "session-current-review",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 76,
            thoughtFoldChecksum: "fold-current-review",
            updateTicketSummaries: ["review current checkpoint"],
            guardrailFindings: ["current review guardrail"],
            recommendedKillSwitches: ["host-write"]
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-current-review",
                createdAt: reviewCheckpointDate,
                fingerprint: "fingerprint-current-review",
                previousCheckpointID: "checkpoint-automatic-active",
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Current checkpoint moves into review without taking over the active slot."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: currentBrain.brainState,
                lineageSummary: reviewLineage
            )
        )
        try context.save()

        app.markEvolutionCheckpointForReview(checkpointID: "checkpoint-current-review")
        let controlSurface = app.makeEvolutionControlSurface()

        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, "checkpoint-automatic-active")
        XCTAssertEqual(controlSurface.activeCheckpoint?.riskLevel, "low")
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, "checkpoint-current-review")
        XCTAssertEqual(controlSurface.pendingReviewQueue.map(\.checkpointID), ["checkpoint-current-review"])
        XCTAssertFalse(controlSurface.canRollbackActiveCheckpoint)
    }

    @MainActor
    func testBeforeAppModelEvolutionControlSurfaceSeparatesActiveCheckpointFromPendingReviewHead() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        let reviewHeadLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
            sessionID: "session-review-head",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 78,
            thoughtFoldChecksum: "fold-review-head",
            updateTicketSummaries: ["hold the response"],
            guardrailFindings: ["review head guardrail"],
            recommendedKillSwitches: ["host-write"]
        )
        let activeLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 10, minute: 0),
            sessionID: "session-active-latest",
            taskType: "summary",
            riskLevel: "low",
            permitMode: "answer",
            hostGatePercent: 40,
            thoughtFoldChecksum: "fold-active-latest",
            updateTicketSummaries: ["latest active checkpoint"],
            guardrailFindings: ["active checkpoint guardrail"],
            recommendedKillSwitches: []
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-pending-review-head",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-head",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Pending review head should stay separate from latest active checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: reviewHeadLineage
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-active-latest",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 10, minute: 0),
                fingerprint: "fingerprint-active-latest",
                previousCheckpointID: "checkpoint-pending-review-head",
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Latest active checkpoint should not be conflated with the pending review head."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: activeLineage
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let controlSurface = app.makeEvolutionControlSurface()

        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, "checkpoint-active-latest")
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, "checkpoint-pending-review-head")
        XCTAssertEqual(controlSurface.reviewAuditFindings, ["review head guardrail"])
        XCTAssertEqual(controlSurface.reviewKillSwitches, ["host-write"])
        XCTAssertEqual(controlSurface.pendingReviewCount, 1)
        XCTAssertEqual(controlSurface.rollbackReadyCount, 1)
        XCTAssertEqual(controlSurface.latestPersistedLineage?.checkpointID, "checkpoint-active-latest")
    }

    @MainActor
    func testBeforeAppModelEvolutionControlSurfaceKeepsReviewOnlyCheckpointOutOfActiveSlot() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-only",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-only",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Review-only checkpoint should not become active."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                    sessionID: "session-review-only",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 78,
                    thoughtFoldChecksum: "fold-review-only",
                    updateTicketSummaries: ["review-only ticket"],
                    guardrailFindings: ["review-only guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let controlSurface = app.makeEvolutionControlSurface()

        XCTAssertNil(controlSurface.activeCheckpoint)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, "checkpoint-review-only")
        XCTAssertFalse(controlSurface.canRollbackActiveCheckpoint)
    }

    @MainActor
    func testBeforeAppModelApprovePendingEvolutionCheckpointsClearsReviewQueue() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-a",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-a",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["First pending review checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-b",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-b",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Second pending review checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: false,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        XCTAssertEqual(app.makeEvolutionControlSurface().pendingReviewCount, 2)

        app.approvePendingEvolutionCheckpoints()

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.filter { $0.approvalState == .reviewSuggested }.count, 0)
        XCTAssertEqual(checkpoints.filter { $0.approvalState == .automatic }.count, 2)
        XCTAssertEqual(app.makeEvolutionControlSurface().pendingReviewCount, 0)
        XCTAssertTrue(app.startupNotice?.contains("Approved 2 pending review checkpoints.") == true)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .approvePendingCheckpoints)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.isSuccess, true)
        XCTAssertEqual(Set(app.latestEvolutionMutationOutcome?.affectedCheckpointIDs ?? []), [
            "checkpoint-review-a",
            "checkpoint-review-b"
        ])
    }

    @MainActor
    func testBeforeAppModelApprovePendingEvolutionCheckpointsPublishesFailureOutcomeWhenQueueIsEmpty() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        XCTAssertEqual(app.makeEvolutionControlSurface().pendingReviewCount, 0)

        app.approvePendingEvolutionCheckpoints()

        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .approvePendingCheckpoints)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.isSuccess, false)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.affectedCheckpointIDs, [])
        XCTAssertTrue(app.latestEvolutionMutationOutcome?.message.contains("No pending review checkpoints") == true)
    }

    @MainActor
    func testBeforeAppModelApprovePendingEvolutionCheckpointsUsesExplicitTargetIDs() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-a-explicit",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-a-explicit",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Explicit review checkpoint A."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-b-explicit",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-b-explicit",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Explicit review checkpoint B."],
                approvalState: .reviewSuggested,
                rollbackReady: false,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)

        app.approvePendingEvolutionCheckpoints(checkpointIDs: ["checkpoint-review-a-explicit"])

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        let pendingIDs = checkpoints
            .filter { $0.approvalState == .reviewSuggested }
            .map(\.id)
        let automaticIDs = checkpoints
            .filter { $0.approvalState == .automatic }
            .map(\.id)

        XCTAssertEqual(pendingIDs, ["checkpoint-review-b-explicit"])
        XCTAssertTrue(automaticIDs.contains("checkpoint-review-a-explicit"))
        XCTAssertEqual(app.makeEvolutionControlSurface().pendingReviewQueue.map(\.checkpointID), ["checkpoint-review-b-explicit"])
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.affectedCheckpointIDs, ["checkpoint-review-a-explicit"])
    }

    @MainActor
    func testBeforeAppModelClearPendingEvolutionCheckpointLineagesLeavesAutomaticCheckpointUntouched() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        let pendingLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
            sessionID: "session-pending-lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 83,
            thoughtFoldChecksum: "fold-pending",
            updateTicketSummaries: ["review pending"],
            guardrailFindings: ["pending audit"],
            recommendedKillSwitches: ["host-write"]
        )
        let activeLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 10, minute: 0),
            sessionID: "session-active-lineage",
            taskType: "summary",
            riskLevel: "low",
            permitMode: "answer",
            hostGatePercent: 31,
            thoughtFoldChecksum: "fold-active",
            updateTicketSummaries: ["keep active"],
            guardrailFindings: ["active audit"],
            recommendedKillSwitches: []
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-pending-lineage",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-pending-lineage",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Pending lineage should be clearable in bulk."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: pendingLineage
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-active-lineage",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 10, minute: 0),
                fingerprint: "fingerprint-active-lineage",
                previousCheckpointID: "checkpoint-pending-lineage",
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Automatic checkpoint lineage should stay intact."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: activeLineage
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        XCTAssertEqual(app.makeEvolutionControlSurface().pendingReviewCount, 1)

        app.clearPendingEvolutionCheckpointLineages()

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        let pending = try XCTUnwrap(checkpoints.first(where: { $0.id == "checkpoint-pending-lineage" }))
        let active = try XCTUnwrap(checkpoints.first(where: { $0.id == "checkpoint-active-lineage" }))

        XCTAssertNil(pending.lineageSummary)
        XCTAssertEqual(active.lineageSummary, activeLineage)
        XCTAssertTrue(app.startupNotice?.contains("Cleared persisted lineage for 1 pending review checkpoint.") == true)
    }

    @MainActor
    func testBeforeAppModelClearPendingEvolutionCheckpointLineagesUsesExplicitTargetIDs() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        let lineageA = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
            sessionID: "session-explicit-clear-a",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-explicit-clear-a",
            updateTicketSummaries: ["clear A"],
            guardrailFindings: ["audit A"],
            recommendedKillSwitches: ["kill A"]
        )
        let lineageB = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
            sessionID: "session-explicit-clear-b",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 83,
            thoughtFoldChecksum: "fold-explicit-clear-b",
            updateTicketSummaries: ["clear B"],
            guardrailFindings: ["audit B"],
            recommendedKillSwitches: ["kill B"]
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-lineage-a",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-lineage-a",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Review lineage A."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: lineageA
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-lineage-b",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-lineage-b",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Review lineage B."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: lineageB
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)

        app.clearPendingEvolutionCheckpointLineages(checkpointIDs: ["checkpoint-review-lineage-a"])

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        let checkpointA = try XCTUnwrap(checkpoints.first(where: { $0.id == "checkpoint-review-lineage-a" }))
        let checkpointB = try XCTUnwrap(checkpoints.first(where: { $0.id == "checkpoint-review-lineage-b" }))

        XCTAssertNil(checkpointA.lineageSummary)
        XCTAssertNotNil(checkpointB.lineageSummary)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.affectedCheckpointIDs, ["checkpoint-review-lineage-a"])
    }

    @MainActor
    func testApplyCheckpointPreviewMatchesActualControlSurfaceForReviewSuggestedTarget() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-active-automatic-preview",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-active-automatic-preview",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Automatic checkpoint should stay on the active release path."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                    sessionID: "session-active-automatic-preview",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 44,
                    thoughtFoldChecksum: "fold-active-automatic-preview",
                    updateTicketSummaries: ["automatic active path"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        let reviewBrainState = DecisionBrainState(
            profileCore: ["Wait before escalating."],
            activeGoals: ["Restore the high-risk checkpoint for inspection."],
            relevantMemories: ["This review checkpoint has a real snapshot."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["mirror", "review"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: .default(for: .mirror),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: .stable(at: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0)),
            loadedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0)
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-preview",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-preview",
                previousCheckpointID: "checkpoint-active-automatic-preview",
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Review checkpoint restores live state without rejoining automatic release."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: reviewBrainState,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                    sessionID: "session-review-preview",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 81,
                    thoughtFoldChecksum: "fold-review-preview",
                    updateTicketSummaries: ["review queue head"],
                    guardrailFindings: ["review preview guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.applyCheckpoint(
                checkpointID: "checkpoint-review-preview",
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.applyEvolutionCheckpoint(
            checkpointID: "checkpoint-review-preview",
            now: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 30)
        )

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        XCTAssertEqual(app.currentBrainState?.evolutionState.latestCheckpoint?.id, "checkpoint-review-preview")
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .applyCheckpoint)
    }

    @MainActor
    func testApprovePendingPreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-active-approve-preview",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 7, minute: 0),
                fingerprint: "fingerprint-active-approve-preview",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Active checkpoint remains stable while review queue clears."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 7, minute: 0),
                    sessionID: "session-active-approve-preview",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 38,
                    thoughtFoldChecksum: "fold-active-approve-preview",
                    updateTicketSummaries: [],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-approve-a",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-approve-a",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Pending review A."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-approve-b",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-approve-b",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Pending review B."],
                approvalState: .reviewSuggested,
                rollbackReady: false,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.approvePendingEvolutionCheckpoints()

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        XCTAssertEqual(controlSurface.pendingReviewCount, 0)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .approvePendingCheckpoints)
    }

    @MainActor
    func testClearPendingReviewLineagePreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)

        let pendingLineage = BASEvolutionLineageSummary(
            recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
            sessionID: "session-clear-preview",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 77,
            thoughtFoldChecksum: "fold-clear-preview",
            updateTicketSummaries: ["clear preview"],
            guardrailFindings: ["pending preview audit"],
            recommendedKillSwitches: ["host-write"]
        )

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-clear-preview",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-clear-preview",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Lineage-backed review checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: pendingLineage
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.clearPendingReviewLineage(
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.clearPendingEvolutionCheckpointLineages()

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        let checkpoint = try XCTUnwrap(
            context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first(where: {
                $0.id == "checkpoint-review-clear-preview"
            })
        )
        XCTAssertNil(checkpoint.lineageSummary)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .clearPendingReviewLineage)
    }

    @MainActor
    func testApproveCheckpointPreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-active-approve-single",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 7, minute: 0),
                fingerprint: "fingerprint-active-approve-single",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Automatic active checkpoint."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 7, minute: 0),
                    sessionID: "session-active-approve-single",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 37,
                    thoughtFoldChecksum: "fold-active-approve-single",
                    updateTicketSummaries: [],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-older",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-review-older",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Older pending review checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: nil
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-head",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-head",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Newest pending review checkpoint."],
                approvalState: .reviewSuggested,
                rollbackReady: false,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                    sessionID: "session-review-head-approve",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 79,
                    thoughtFoldChecksum: "fold-review-head-approve",
                    updateTicketSummaries: ["review head"],
                    guardrailFindings: ["approve preview guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.approveCheckpoint(
                checkpointID: "checkpoint-review-head",
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.approveEvolutionCheckpoint(checkpointID: "checkpoint-review-head")

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        XCTAssertEqual(controlSurface.pendingReviewQueue.map(\.checkpointID), ["checkpoint-review-older"])
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .approveCheckpoint)
    }

    @MainActor
    func testRollbackPreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext
        seedCheckpointApplyHistory(into: context)
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")
        let currentBrain = try XCTUnwrap(app.currentBrainState)

        let firstDate = currentBrain.loadedAt.addingTimeInterval(60)
        let firstBrainState = DecisionBrainState(
            profileCore: ["Pause before conflict."],
            activeGoals: ["Sleep first."],
            relevantMemories: ["A first checkpoint."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "sleep"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: .default(for: .quick),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.medium),
            calibrationState: .stable(at: firstDate),
            loadedAt: firstDate
        )
        let secondDate = firstDate.addingTimeInterval(300)
        let secondBrainState = DecisionBrainState(
            profileCore: ["Pause before conflict."],
            activeGoals: ["Reply tomorrow morning."],
            relevantMemories: ["A second checkpoint."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "reply"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: .default(for: .quick),
            boundaryPolicy: .default(riskLevel: InterventionRiskLevel.high),
            calibrationState: .stable(at: secondDate),
            loadedAt: secondDate
        )

        let firstWrite: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                    brainState: firstBrainState
                ),
                in: context,
                createdAt: firstDate
            )
        let secondWrite: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: DecisionMode.quick.rawValue,
                    sourceID: BrainStateUpdateSource.explicitRefresh.rawValue,
                    brainState: secondBrainState
                ),
                in: context,
                createdAt: secondDate
            )

        let firstCheckpointID = try XCTUnwrap(
            firstWrite.orderedCheckpoints.first(where: {
                $0.createdAt == firstDate &&
                $0.fingerprint == firstBrainState.verificationSnapshot.fingerprint
            })?.id
        )
        let secondCheckpointID = try XCTUnwrap(
            secondWrite.orderedCheckpoints.first(where: {
                $0.createdAt == secondDate &&
                $0.fingerprint == secondBrainState.verificationSnapshot.fingerprint
            })?.id
        )

        app.applyEvolutionCheckpoint(checkpointID: secondCheckpointID, now: secondDate.addingTimeInterval(30))
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.rollbackActiveCheckpoint(
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.rollbackActiveEvolutionCheckpoint(now: secondDate.addingTimeInterval(60))

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, firstCheckpointID)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .rollbackActiveCheckpoint)
    }

    @MainActor
    func testMarkCheckpointForReviewPreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-z",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-z",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Automatic checkpoint entering review."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                    sessionID: "session-review-z",
                    taskType: "decision",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 54,
                    thoughtFoldChecksum: "fold-review-z",
                    updateTicketSummaries: ["mark for review preview"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-review-a",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                fingerprint: "fingerprint-review-a",
                previousCheckpointID: nil,
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .reflectiveWitness,
                boundaryMode: .localOnlyProtective,
                calibrationStatus: .stable,
                diffSummary: ["Existing review head."],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0),
                    sessionID: "session-review-a",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 80,
                    thoughtFoldChecksum: "fold-review-a",
                    updateTicketSummaries: ["existing review head"],
                    guardrailFindings: ["review guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.markCheckpointForReview(
                checkpointID: "checkpoint-review-z",
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.markEvolutionCheckpointForReview(checkpointID: "checkpoint-review-z")

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        XCTAssertEqual(controlSurface.pendingReviewQueue.map(\.checkpointID), ["checkpoint-review-z", "checkpoint-review-a"])
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .markCheckpointForReview)
    }

    @MainActor
    func testClearCheckpointLineagePreviewMatchesActualControlSurface() throws {
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingLaunchRequestStore.clear()
        PendingReflectionStore.clear()

        let container = try makeCheckpointApplyContainer()
        let context = container.mainContext

        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-lineage-clear-single",
                createdAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                fingerprint: "fingerprint-lineage-clear-single",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Single lineage-backed automatic checkpoint."],
                approvalState: .automatic,
                rollbackReady: true,
                brainStateSnapshot: nil,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: localDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0),
                    sessionID: "session-lineage-clear-single",
                    taskType: "decision",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 41,
                    thoughtFoldChecksum: "fold-lineage-clear-single",
                    updateTicketSummaries: ["clear single lineage"],
                    guardrailFindings: ["single lineage audit"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        try context.save()

        let app = BeforeAppModel(modelContainer: container, startupNotice: nil)
        let preview = try XCTUnwrap(
            DecisionEvolutionMutationIntentFactory.clearCheckpointLineage(
                checkpointID: "checkpoint-lineage-clear-single",
                controlSurface: app.makeEvolutionControlSurface()
            )?.preview
        )

        app.clearEvolutionCheckpointLineage(checkpointID: "checkpoint-lineage-clear-single")

        let controlSurface = app.makeEvolutionControlSurface()
        XCTAssertEqual(controlSurface.activeCheckpoint?.checkpointID, preview.projectedActiveCheckpointID)
        XCTAssertEqual(controlSurface.reviewCheckpoint?.checkpointID, preview.projectedReviewCheckpointID)
        let checkpoint = try XCTUnwrap(
            context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>()).first(where: {
                $0.id == "checkpoint-lineage-clear-single"
            })
        )
        XCTAssertNil(checkpoint.lineageSummary)
        XCTAssertEqual(app.latestEvolutionMutationOutcome?.kind, .clearCheckpointLineage)
    }

    private func makeCheckpointApplyContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            BrainStateUpdate.self,
            DecisionEvolutionCheckpoint.self,
            InterventionTemplateRecord.self,
            FailurePatternRecord.self,
            InterventionTrigger.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func seedCheckpointApplyHistory(into context: ModelContext) {
        context.insert(
            CheckEvent(
                createdAt: localDate(year: 2026, month: 4, day: 10, hour: 8, minute: 0),
                scenario: .other,
                motivation: .genuineNeed,
                expectedOutcome: .satisfied,
                controlLevel: .maybe,
                note: "I want to reply fast.",
                currentPerspective: "You want a fast relief hit.",
                afterPerspective: "Waiting tends to clean this up.",
                verdict: .pause,
                finalAction: .decideTomorrow,
                reflectionOutcome: .betterThanExpected,
                entrySource: .app
            )
        )
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
