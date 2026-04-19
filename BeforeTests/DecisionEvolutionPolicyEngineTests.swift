import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionPolicyEngineTests: XCTestCase {
    func testReleaseSummaryBuilderStoresPrimaryBlockerForSharedPolicyConsumers() {
        let review = makeSnapshot(
            checkpointID: "review-policy",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["queue-kill"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: []
        )

        XCTAssertEqual(summary.primaryBlocker, .recommendedKillSwitches)
    }

    func testPolicyEngineHonorsStoredReleasePrimaryBlockerAheadOfFallbackOrdering() {
        let releaseSummary = DecisionSystemReleaseControlSummary(
            state: .blocked,
            headline: "Custom runtime guardrail state",
            reasons: ["Thermal guardrail requires cooldown before wider rollout."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: "active-1",
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: "review-1",
            primaryBlocker: .runtimeGuardrails
        )

        let priorities = DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
            releaseSummary: releaseSummary,
            reviewAuditFindings: ["audit-1"]
        )

        XCTAssertEqual(priorities.first, .runtimeGuardrails)
        XCTAssertTrue(priorities.contains(.pendingReview))
        XCTAssertTrue(priorities.contains(.auditFindings))
    }

    func testAttentionPolicyKeepsPendingReviewVisibleWhenReleaseSummaryWatchesForActiveCheckpoint() {
        let review = makeSnapshot(
            checkpointID: "review-waiting",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline,
                reasons: [DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: "review-waiting",
                primaryBlocker: .missingActiveCheckpoint
            )
        )

        let signal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        XCTAssertEqual(signal.severity, .review)
        XCTAssertEqual(signal.badgeValue, "1")
        XCTAssertEqual(
            signal.headline,
            DecisionEvolutionReviewPathPresentationSupport.reviewWaitingHeadline
        )
    }

    func testOperatorGuidanceUsesTypedPolicyForReadyRecoveryWithoutReleaseSummary() {
        let active = makeSnapshot(
            checkpointID: "active-ready",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .automaticFallback,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil,
                restorableCheckpointIDs: ["previous-active-ready"]
            )
        )

        let guidance = workspace.operatorGuidance(for: .home)

        XCTAssertEqual(
            guidance.headline,
            DecisionEvolutionCheckpointRecoverySupport.activeCheckpointHeadline(
                source: .automaticFallback
            )
        )
        XCTAssertEqual(
            guidance.primaryReason,
            DecisionEvolutionCheckpointRecoverySupport.activeCheckpointReason(
                source: .automaticFallback
            )
        )
    }

    func testInputWorkspaceUsesReleaseSummaryFactsButRetainsControlSurfaceQueueSignals() {
        let active = makeSnapshot(
            checkpointID: "active-workspace",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-workspace",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["queue-kill"]
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .automaticFallback,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil,
                restorableCheckpointIDs: ["previous-active-workspace", "previous-review-workspace"]
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .blocked,
                headline: DecisionEvolutionReleasePathPresentationSupport.blockedActiveKillSwitchHeadline,
                reasons: ["Runtime host writes are paused."],
                activeKillSwitches: ["host-write"],
                recommendedKillSwitches: ["external-tools"],
                killSwitches: ["host-write", "external-tools"],
                pendingReviewCount: 3,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: "summary-active",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "summary-review",
                primaryBlocker: .activeKillSwitches
            )
        )

        let input = DecisionEvolutionPolicyEngine.input(workspace: workspace)

        XCTAssertEqual(input.pendingReviewCount, 3)
        XCTAssertEqual(input.activeCheckpointSource, .pinnedHint)
        XCTAssertEqual(input.activeCheckpointID, "summary-active")
        XCTAssertEqual(input.activeKillSwitches, ["host-write"])
        XCTAssertEqual(input.recommendedKillSwitches, ["external-tools"])
        XCTAssertFalse(input.canRestoreActiveCheckpoint)
        XCTAssertFalse(input.canRollbackActiveCheckpoint)
        XCTAssertEqual(input.reviewAuditFindings, ["audit-review-workspace"])
        XCTAssertEqual(input.queueAuditFindings, ["audit-review-workspace"])
        XCTAssertEqual(input.queueKillSwitches, ["queue-kill"])
    }

    func testOrderedPrioritiesFallsBackFromLegacyReleaseHeadlineWhenPrimaryBlockerIsMissing() {
        let runtimeSummary = DecisionSystemReleaseControlSummary(
            state: .blocked,
            headline: DecisionEvolutionReleasePathPresentationSupport.blockedRuntimeGuardrailsHeadline,
            reasons: ["Thermal guardrail requires cooldown."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: "runtime-1",
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: nil,
            primaryBlocker: nil
        )
        let pendingSummary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: DecisionEvolutionReleasePathPresentationSupport.watchingPendingReviewHeadline,
            reasons: ["Review queue remains."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 2,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: "pending-1",
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: "review-1",
            primaryBlocker: nil
        )

        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                releaseSummary: runtimeSummary,
                reviewAuditFindings: []
            ).first,
            .runtimeGuardrails
        )
        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                releaseSummary: pendingSummary,
                reviewAuditFindings: []
            ).first,
            .pendingReview
        )
    }

    func testActionAvailabilitySeparatesRestoreOnlyPilotActionsFromMutationWorkspaceQuickActions() {
        let active = makeSnapshot(
            checkpointID: "active-restore-only",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: []
        )

        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: nil,
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: false,
                allowsLocalMutationActions: true
            )
        )

        XCTAssertTrue(policy.actionAvailability.canRestoreActivePath)
        XCTAssertFalse(policy.actionAvailability.canRollbackActivePath)
        XCTAssertFalse(policy.actionAvailability.canApprovePendingQueue)
        XCTAssertFalse(policy.actionAvailability.canClearPendingReviewLineage)
        XCTAssertTrue(policy.actionAvailability.hasAnyLocalAction)
        XCTAssertFalse(policy.actionAvailability.hasAnyMutationWorkspaceAction)
        XCTAssertNil(policy.recommendedPilotStep(canNavigate: false))
    }

    func testRecommendedPilotActionPrefersApprovePendingQueueOnMutationSurface() {
        let active = makeSnapshot(
            checkpointID: "active-policy",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-policy",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-policy", "previous-review-policy"]
        )

        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: nil,
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                allowsLocalMutationActions: true
            )
        )

        XCTAssertEqual(policy.primaryBlocker, .pendingReview)
        XCTAssertTrue(policy.actionAvailability.canApprovePendingQueue)
        XCTAssertTrue(policy.actionAvailability.canClearPendingReviewLineage)
        XCTAssertEqual(
            policy.recommendedPilotStep(canNavigate: false)?.action,
            .approvePendingQueue
        )
    }

    func testWidgetControlEntryKindTracksSharedAttentionSeverity() {
        let reviewPolicy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: [],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 2,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: false
                )
            )
        )
        let blockedPolicy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: ["host-write"],
                    recommendedKillSwitches: [],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 0,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: false
                )
            )
        )
        let rollbackPolicy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: [],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 0,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: true
                )
            )
        )
        let quietPolicy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: [],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 0,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: false
                )
            )
        )

        XCTAssertEqual(reviewPolicy.widgetControlEntryKind, .review)
        XCTAssertEqual(blockedPolicy.widgetControlEntryKind, .control)
        XCTAssertEqual(rollbackPolicy.widgetControlEntryKind, .rollback)
        XCTAssertNil(quietPolicy.widgetControlEntryKind)
    }

    func testWidgetControlEntryUsesAuditKindForAuditFindingAttention() {
        let auditPolicy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: [],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 0,
                    reviewAuditFindings: ["Factors: evidence_caveat_load"],
                    canRollbackActiveCheckpoint: false
                )
            )
        )

        XCTAssertEqual(auditPolicy.widgetControlEntryKind, .audit)
        XCTAssertEqual(
            auditPolicy.widgetControlEntryPresentation(
                prompt: "Watching audit findings before wider rollout",
                triggerReason: "Factors: evidence_caveat_load"
            ),
            DecisionEvolutionWidgetControlEntryPresentation(
                title: "Audit on iPhone",
                systemImage: "exclamationmark.circle",
                prompt: "Watching audit findings before wider rollout",
                instruction: "Continue on iPhone to inspect audit findings before widening rollout.",
                triggerReason: "Factors: evidence_caveat_load"
            )
        )
    }

    func testSurfaceActionPlanPrefersApproveQueueForLocalMutationSurfaces() {
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: ["external-tools"],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: true,
                    canRestoreActiveCheckpoint: true,
                    pendingReviewCount: 1,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: false
                ),
                activeCheckpointID: "active-1",
                activeCheckpointSource: .pinnedHint,
                pendingReviewLineageCount: 1,
                hasRollbackTarget: false,
                allowsLocalMutationActions: true
            )
        )

        let actionPlan = policy.surfaceActionPlan(
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(),
            routesMutationsToControlCenter: false
        )

        XCTAssertTrue(actionPlan.allowsLocalMutationActions)
        XCTAssertTrue(actionPlan.showsAnyActionRow)
        XCTAssertEqual(actionPlan.quickActionsTitle, "Quick actions")
        XCTAssertEqual(
            actionPlan.guidedAction?.route,
            .approvePendingQueue
        )
        XCTAssertEqual(
            actionPlan.guidedAction?.actionTitle,
            DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle
        )
    }

    func testSurfaceActionPlanRoutesReadFirstSurfacesToPreferredDestination() {
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: ["host-write"],
                    recommendedKillSwitches: ["host-write"],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: false,
                    canRestoreActiveCheckpoint: false,
                    pendingReviewCount: 0,
                    reviewAuditFindings: [],
                    canRollbackActiveCheckpoint: false
                ),
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                pendingReviewLineageCount: 0,
                hasRollbackTarget: false,
                allowsLocalMutationActions: false
            )
        )

        let actionPlan = policy.surfaceActionPlan(
            navigationOptions: DecisionEvolutionNavigationSurfaceOptions(
                showControlCenterShortcut: false,
                showHistoryShortcut: true,
                showPortraitShortcut: false
            ),
            routesMutationsToControlCenter: true
        )

        XCTAssertFalse(actionPlan.allowsLocalMutationActions)
        XCTAssertTrue(actionPlan.showsAnyActionRow)
        XCTAssertNil(actionPlan.quickActionsTitle)
        XCTAssertEqual(
            actionPlan.guidedAction?.route,
            .navigate(.history)
        )
        XCTAssertEqual(
            actionPlan.guidedAction?.actionTitle,
            "Open History"
        )
    }

    func testCheckpointActionAvailabilityExposesTypedMutationEligibility() {
        let mutationHubAvailability = DecisionEvolutionPolicyEngine.checkpointActionAvailability(
            allowsLocalMutationActions: true,
            applyReady: true,
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        XCTAssertTrue(mutationHubAvailability.showsMutationActions)
        XCTAssertTrue(mutationHubAvailability.canApply)
        XCTAssertEqual(mutationHubAvailability.secondaryActionKind, .approve)
        XCTAssertTrue(mutationHubAvailability.canClearLineage)

        let readFirstAvailability = DecisionEvolutionPolicyEngine.checkpointActionAvailability(
            allowsLocalMutationActions: false,
            applyReady: true,
            approvalState: .automatic,
            hasLineage: true
        )

        XCTAssertFalse(readFirstAvailability.showsMutationActions)
        XCTAssertFalse(readFirstAvailability.canApply)
        XCTAssertNil(readFirstAvailability.secondaryActionKind)
        XCTAssertFalse(readFirstAvailability.canClearLineage)
    }

    func testCheckpointSetEligibilityKeepsOrderedSelectionBucketsAndRestorableTarget() {
        let now = Date(timeIntervalSince1970: 100)
        let review = makeSnapshot(
            checkpointID: "checkpoint-review",
            createdAt: now.addingTimeInterval(20),
            approvalState: .reviewSuggested,
            hasLineage: true
        ).presentation
        let automatic = makeSnapshot(
            checkpointID: "checkpoint-automatic",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: false
        ).presentation

        let eligibility = DecisionEvolutionPolicyEngine.checkpointSetEligibility(
            allowsLocalMutationActions: true,
            presentations: [review, automatic, review]
        )

        XCTAssertEqual(
            eligibility.checkpointIDs,
            ["checkpoint-review", "checkpoint-automatic"]
        )
        XCTAssertEqual(eligibility.reviewCheckpointIDs, ["checkpoint-review"])
        XCTAssertEqual(eligibility.automaticCheckpointIDs, ["checkpoint-automatic"])
        XCTAssertEqual(eligibility.lineageCheckpointIDs, ["checkpoint-review"])
        XCTAssertNil(eligibility.restorableCheckpointID)
        XCTAssertTrue(eligibility.canApproveCheckpoints)
        XCTAssertTrue(eligibility.canMarkCheckpointsForReview)
        XCTAssertTrue(eligibility.canClearCheckpointLineage)

        let singleEligibility = DecisionEvolutionPolicyEngine.checkpointSetEligibility(
            allowsLocalMutationActions: false,
            presentations: [automatic]
        )

        XCTAssertEqual(singleEligibility.restorableCheckpointID, "checkpoint-automatic")
        XCTAssertFalse(singleEligibility.canApproveCheckpoints)
        XCTAssertFalse(singleEligibility.canMarkCheckpointsForReview)
        XCTAssertFalse(singleEligibility.canClearCheckpointLineage)
    }

    func testApplyCheckpointPreviewStateKeepsReviewSuggestedTargetOffAutomaticPath() {
        let now = Date(timeIntervalSince1970: 200)
        let target = makeSnapshot(
            checkpointID: "checkpoint-review",
            createdAt: now,
            approvalState: .reviewSuggested,
            hasLineage: true
        ).presentation

        let previewState = DecisionEvolutionPolicyEngine.applyCheckpointPreviewState(
            targetCheckpointID: target.checkpointID,
            targetPresentation: target,
            currentActiveCheckpointID: "checkpoint-active",
            currentReviewCheckpointID: "checkpoint-review"
        )

        XCTAssertEqual(
            previewState,
            DecisionEvolutionPolicyPreviewState(
                currentActiveCheckpointID: "checkpoint-active",
                projectedActiveCheckpointID: "checkpoint-active",
                currentReviewCheckpointID: "checkpoint-review",
                projectedReviewCheckpointID: "checkpoint-review"
            )
        )
    }

    func testApprovePendingQueuePreviewStateUsesActiveSourceToProjectAutomaticPromotion() {
        let pinnedPreviewState = DecisionEvolutionPolicyEngine.approvePendingQueuePreviewState(
            activeCheckpointSource: .pinnedHint,
            currentActiveCheckpointID: "checkpoint-active",
            currentReviewCheckpointID: "checkpoint-review",
            projectedAutomaticCheckpointID: "checkpoint-review-newest"
        )
        let automaticPreviewState = DecisionEvolutionPolicyEngine.approvePendingQueuePreviewState(
            activeCheckpointSource: .automaticFallback,
            currentActiveCheckpointID: "checkpoint-active",
            currentReviewCheckpointID: "checkpoint-review",
            projectedAutomaticCheckpointID: "checkpoint-review-newest"
        )

        XCTAssertEqual(
            pinnedPreviewState,
            DecisionEvolutionPolicyPreviewState(
                currentActiveCheckpointID: "checkpoint-active",
                projectedActiveCheckpointID: "checkpoint-active",
                currentReviewCheckpointID: "checkpoint-review",
                projectedReviewCheckpointID: nil
            )
        )
        XCTAssertEqual(
            automaticPreviewState,
            DecisionEvolutionPolicyPreviewState(
                currentActiveCheckpointID: "checkpoint-active",
                projectedActiveCheckpointID: "checkpoint-review-newest",
                currentReviewCheckpointID: "checkpoint-review",
                projectedReviewCheckpointID: nil
            )
        )
    }

    func testApproveCheckpointPreviewStateBreaksTimestampTiesUsingCheckpointIDOrdering() {
        let now = Date(timeIntervalSince1970: 300)
        let currentActive = makeSnapshot(
            checkpointID: "checkpoint-a",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: true
        ).presentation
        let target = makeSnapshot(
            checkpointID: "checkpoint-z",
            createdAt: now,
            approvalState: .reviewSuggested,
            hasLineage: true
        ).presentation

        let previewState = DecisionEvolutionPolicyEngine.approveCheckpointPreviewState(
            targetPresentation: target,
            currentActivePresentation: currentActive,
            currentReviewCheckpointID: "checkpoint-z",
            remainingReviewQueue: []
        )

        XCTAssertEqual(
            previewState,
            DecisionEvolutionPolicyPreviewState(
                currentActiveCheckpointID: "checkpoint-a",
                projectedActiveCheckpointID: "checkpoint-z",
                currentReviewCheckpointID: "checkpoint-z",
                projectedReviewCheckpointID: nil
            )
        )
    }

    func testMarkSelectedCheckpointsForReviewPreviewStateDropsSelectedActiveAndPrefersNewestReviewHead() {
        let now = Date(timeIntervalSince1970: 400)
        let currentReview = makeSnapshot(
            checkpointID: "checkpoint-review-a",
            createdAt: now,
            approvalState: .reviewSuggested,
            hasLineage: true
        ).presentation
        let selectedActive = makeSnapshot(
            checkpointID: "checkpoint-review-z",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: true
        ).presentation

        let previewState = DecisionEvolutionPolicyEngine.markSelectedCheckpointsForReviewPreviewState(
            targetPresentations: [selectedActive],
            currentActiveCheckpointID: "checkpoint-review-z",
            currentReviewPresentation: currentReview
        )

        XCTAssertEqual(
            previewState,
            DecisionEvolutionPolicyPreviewState(
                currentActiveCheckpointID: "checkpoint-review-z",
                projectedActiveCheckpointID: nil,
                currentReviewCheckpointID: "checkpoint-review-a",
                projectedReviewCheckpointID: "checkpoint-review-z"
            )
        )
    }

    private func makeSnapshot(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool,
        killSwitches: [String] = []
    ) -> DecisionReviewCheckpointSnapshot {
        let summary = hasLineage
            ? makeLineageSummary(
                checkpointID: checkpointID,
                recordedAt: createdAt,
                killSwitches: killSwitches.isEmpty ? ["kill-\(checkpointID)"] : killSwitches
            )
            : nil
        return DecisionReviewCheckpointSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: "previous-\(checkpointID)",
            createdAt: createdAt,
            mode: .mirror,
            approvalState: approvalState,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["checkpoint \(checkpointID)"],
            eBrain: summary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:)),
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "delay"
        )
    }

    private func makeLineageSummary(
        checkpointID: String,
        recordedAt: Date,
        killSwitches: [String]
    ) -> BASEvolutionLineageSummary {
        BASEvolutionLineageSummary(
            recordedAt: recordedAt,
            sessionID: "session-\(checkpointID)",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 72,
            thoughtFoldChecksum: "fold-\(checkpointID)",
            updateTicketSummaries: ["ticket-\(checkpointID)"],
            guardrailFindings: ["audit-\(checkpointID)"],
            recommendedKillSwitches: killSwitches
        )
    }
}
