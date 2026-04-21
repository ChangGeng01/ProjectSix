import Foundation
import Testing
import BASHostKit
@testable import Before

struct DecisionEvolutionPilotControlSnapshotTests {
    @Test
    func guidedActionMatchesSharedSurfaceActionPlanContract() throws {
        let controlSurface = makeControlSurface(
            active: makeCheckpoint(
                checkpointID: "active-action-plan",
                createdAt: Date(timeIntervalSince1970: 10),
                approvalState: .automatic,
                hasLineage: true
            ),
            pendingReview: [
                makeCheckpoint(
                    checkpointID: "review-action-plan",
                    createdAt: Date(timeIntervalSince1970: 20),
                    approvalState: .reviewSuggested,
                    hasLineage: true
                )
            ],
            restorableCheckpointIDs: ["active-action-plan-prior"]
        )
        let releaseSummary = makeReleaseSummary(
            headline: "Pending review is blocking release.",
            reasons: ["Review queue must be cleared first."],
            pendingReviewCount: 1,
            activeKillSwitches: [],
            recommendedKillSwitches: ["external-tools"],
            killSwitches: ["external-tools"],
            canRestoreActiveCheckpoint: true,
            activeCheckpointID: "active-action-plan",
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: "review-action-plan"
        )
        let surfaceContract = DecisionEvolutionSurfaceContract.controlCenter
        let navigationOptions = surfaceContract.navigationSurfaceOptions()

        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions
        )
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: releaseSummary,
                activeKillSwitches: releaseSummary.activeKillSwitches,
                recommendedKillSwitches: releaseSummary.recommendedKillSwitches,
                canRestoreActiveCheckpoint: releaseSummary.canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: releaseSummary.canRollbackActiveCheckpoint,
                allowsLocalMutationActions: surfaceContract.allowsMutations
            )
        )
        let actionPlan = policy.surfaceActionPlan(
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter
        )

        let guidedAction = try #require(snapshot.guidedAction)
        let expectedGuidedAction = try #require(actionPlan.guidedAction)

        #expect(snapshot.allowsLocalMutationActions == actionPlan.allowsLocalMutationActions)
        #expect(guidedAction.title == expectedGuidedAction.title)
        #expect(guidedAction.detail == expectedGuidedAction.detail)
        #expect(guidedAction.actionTitle == expectedGuidedAction.actionTitle)

        if case let .mutation(intent) = guidedAction.route {
            #expect(expectedGuidedAction.route == .approvePendingQueue)
            #expect(intent.kind == .approvePendingCheckpoints)
        } else {
            Issue.record("Expected pilot guided action to stay aligned with the shared approve-pending route.")
        }
    }

    @Test
    func guidedActionNavigationMatrixMatchesSurfaceModeAndPreferredDestination() {
        let localMutationSnapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-control",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                ),
                pendingReview: [
                    makeCheckpoint(
                        checkpointID: "review-queue",
                        createdAt: Date(timeIntervalSince1970: 20),
                        approvalState: .reviewSuggested,
                        hasLineage: true
                    )
                ],
                restorableCheckpointIDs: ["active-control-prior"]
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Pending review is blocking release.",
                reasons: ["Review queue must be cleared first."],
                pendingReviewCount: 1,
                activeKillSwitches: [],
                recommendedKillSwitches: ["external-tools"],
                killSwitches: ["external-tools"],
                canRestoreActiveCheckpoint: true,
                activeCheckpointID: "active-control",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-queue"
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(localMutationSnapshot.interactionMode == .mutationHub)
        #expect(localMutationSnapshot.allowsLocalMutationActions)
        #expect(
            localMutationSnapshot.summaryBadgePresentations
                == [
                    DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange),
                    DecisionEvolutionSummaryBadgePresentation(title: "0 ROLLBACK READY", tone: .secondary),
                    DecisionEvolutionSummaryBadgePresentation(title: "1 LINEAGE-BACKED", tone: .ember)
                ]
        )
        #expect(localMutationSnapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewHeadline)
        #expect(
            localMutationSnapshot.guidedAction?.detail
                == DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewDetail(allowsMutations: true)
        )
        #expect(
            DecisionEvolutionPendingReviewPresentationSupport.pilotHeadline
                == DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewHeadline
        )
        #expect(
            localMutationSnapshot.guidedAction?.actionTitle
                == DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle
        )

        if case let .mutation(intent)? = localMutationSnapshot.guidedAction?.route {
            #expect(intent.kind == .approvePendingCheckpoints)
        } else {
            Issue.record("Expected local mutation guidance to stay on the approve queue mutation route.")
        }

        let controlCenterReadFirstSnapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                pendingReview: [
                    makeCheckpoint(
                        checkpointID: "review-read-first",
                        createdAt: Date(timeIntervalSince1970: 30),
                        approvalState: .reviewSuggested,
                        hasLineage: true
                    )
                ]
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Read-first surface should route control.",
                reasons: ["Pending review remains."],
                pendingReviewCount: 1,
                canRestoreActiveCheckpoint: false,
                reviewCheckpointID: "review-read-first"
            ),
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.checkpointNavigationOptions
        )

        #expect(controlCenterReadFirstSnapshot.interactionMode == .observeAndRoute)
        #expect(controlCenterReadFirstSnapshot.allowsLocalMutationActions == false)
        #expect(
            controlCenterReadFirstSnapshot.summaryBadgePresentations
                == [
                    DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange),
                    DecisionEvolutionSummaryBadgePresentation(title: "0 ROLLBACK READY", tone: .secondary),
                    DecisionEvolutionSummaryBadgePresentation(title: "1 LINEAGE-BACKED", tone: .ember)
                ]
        )
        #expect(
            controlCenterReadFirstSnapshot.guidedAction?.title
                == DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline
        )
        #expect(
            controlCenterReadFirstSnapshot.guidedAction?.detail
                == DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason
        )
        #expect(controlCenterReadFirstSnapshot.guidedAction?.actionTitle == "Open control center")

        if case let .navigation(destination)? = controlCenterReadFirstSnapshot.guidedAction?.route {
            #expect(destination == .controlCenter)
        } else {
            Issue.record("Expected read-first pending-review guidance to route to control center.")
        }

        let historySnapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                pendingReview: []
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Kill switches should route to history.",
                reasons: ["Inspect the active checkpoint and its guardrails before widening rollout."],
                pendingReviewCount: 0,
                activeKillSwitches: ["external-tools"],
                recommendedKillSwitches: ["external-tools"],
                killSwitches: ["external-tools"],
                canRestoreActiveCheckpoint: true
            ),
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionNavigationSurfaceOptions(
                showControlCenterShortcut: false,
                showHistoryShortcut: true,
                showPortraitShortcut: false
            )
        )

        #expect(historySnapshot.guidedAction?.actionTitle == "Open History")
        #expect(historySnapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchHeadline)
        #expect(historySnapshot.guidedAction?.detail == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchDetail)
        if case let .navigation(destination)? = historySnapshot.guidedAction?.route {
            #expect(destination == .history)
        } else {
            Issue.record("Expected kill-switch guidance to honor the history destination.")
        }

        let portraitSnapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                pendingReview: []
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Kill switches should route to portrait.",
                reasons: ["Inspect the active checkpoint and its guardrails before widening rollout."],
                pendingReviewCount: 0,
                activeKillSwitches: ["host-write"],
                recommendedKillSwitches: ["host-write"],
                killSwitches: ["host-write"],
                canRestoreActiveCheckpoint: true
            ),
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionNavigationSurfaceOptions(
                showControlCenterShortcut: false,
                showHistoryShortcut: false,
                showPortraitShortcut: true
            )
        )

        #expect(portraitSnapshot.guidedAction?.actionTitle == "Open Portrait")
        #expect(portraitSnapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchHeadline)
        #expect(portraitSnapshot.guidedAction?.detail == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchDetail)
        if case let .navigation(destination)? = portraitSnapshot.guidedAction?.route {
            #expect(destination == .portrait)
        } else {
            Issue.record("Expected kill-switch guidance to honor the portrait destination.")
        }
    }

    @Test
    func localMutationSurfacePrefersApproveQueueGuidanceWhenReviewIsPending() {
        let controlSurface = makeControlSurface(
            active: makeCheckpoint(
                checkpointID: "active-control",
                createdAt: Date(timeIntervalSince1970: 10),
                approvalState: .automatic,
                hasLineage: true
            ),
            pendingReview: [
                makeCheckpoint(
                    checkpointID: "review-queue",
                    createdAt: Date(timeIntervalSince1970: 20),
                    approvalState: .reviewSuggested,
                    hasLineage: true
                )
            ],
            restorableCheckpointIDs: ["active-control-prior"]
        )
        let releaseSummary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Pending review is blocking release.",
            reasons: ["Review queue must be cleared first."],
            activeKillSwitches: [],
            recommendedKillSwitches: ["external-tools"],
            killSwitches: ["external-tools"],
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: "active-control",
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: "review-queue"
        )

        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(snapshot.allowsLocalMutationActions)
        #expect(snapshot.pendingReviewCount == 1)
        #expect(snapshot.rollbackReadyCount == 0)
        #expect(snapshot.headerTitle == "Evolution pilot controls")
        #expect(
            snapshot.headerDetail
                == DecisionEvolutionMutationRoutingPresentationSupport.mutationHubPilotDetail
        )
        #expect(snapshot.guidedActionSectionTitle == "Recommended next step")
        #expect(snapshot.restoreActiveTitle == "Restore active path")
        #expect(snapshot.rollbackActiveTitle == "Rollback active path")
        #expect(
            snapshot.approveQueueTitle
                == DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle
        )
        #expect(snapshot.clearQueueLineageTitle == "Clear queue lineage")
        #expect(
            snapshot.summaryBadgePresentations
                == [
                    DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange),
                    DecisionEvolutionSummaryBadgePresentation(title: "0 ROLLBACK READY", tone: .secondary),
                    DecisionEvolutionSummaryBadgePresentation(title: "1 LINEAGE-BACKED", tone: .ember)
                ]
        )
        #expect(snapshot.embeddedReleaseSummaryMode == .mutationHub)
        #expect(snapshot.approveQueueIntent?.kind == .approvePendingCheckpoints)
        #expect(snapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewHeadline)
        #expect(
            snapshot.guidedAction?.detail
                == DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewDetail(allowsMutations: true)
        )
        #expect(
            snapshot.guidedAction?.actionTitle
                == DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle
        )
        #expect(
            snapshot.pendingReviewLineageNotice
                == DecisionEvolutionLineagePresentationSupport.pendingReviewLineageNotice(
                    pendingReviewLineageCount: 1,
                    hasReleaseSummary: true
                )
        )
        #expect(snapshot.reviewAuditLine == "Review audit: guardrail-review-queue")
        #expect(snapshot.recommendedKillSwitchesLine == "Suggested kill switches: external-tools")

        if case let .mutation(intent)? = snapshot.guidedAction?.route {
            #expect(intent.kind == .approvePendingCheckpoints)
        } else {
            Issue.record("Expected mutation-guided action for local mutation surface.")
        }

        #expect(snapshot.recommendedKillSwitches == ["external-tools"])
        #expect(snapshot.foldedLungTitle == nil)
        #expect(snapshot.foldedLungLines.isEmpty)
    }

    @Test
    func pilotSnapshotSurfacesFoldedLungLinesFromReleaseReasons() {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-folded-lung",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                )
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Folded lung should remain visible in pilot controls.",
                reasons: [
                    "L3 compression runtime • resumed checkpoint lineage",
                    "Breath guard/exchange • thermal 0.42 • restore ready",
                    "Morph graph guard.runtime • organs riskPermit,stubCore",
                    "Hot pack hot stubCore,riskPermit • warm sentinel • cold projectionRing",
                    "Precision profile riskPermit fp16 • stubCore fp16",
                    "Thermal exchanger predictive_guard • reroute stubCore->ane",
                    "Integrity weave verified guard.fold"
                ],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: true,
                activeCheckpointID: "active-folded-lung",
                activeCheckpointSource: .pinnedHint
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(snapshot.foldedLungTitle == "Folded lung")
        #expect(
            snapshot.foldedLungLines
                == [
                    "L3 compression runtime • resumed checkpoint lineage",
                    "Breath guard/exchange • thermal 0.42 • restore ready",
                    "Morph graph guard.runtime • organs riskPermit,stubCore",
                    "Hot pack hot stubCore,riskPermit • warm sentinel • cold projectionRing",
                    "Precision profile riskPermit fp16 • stubCore fp16",
                    "Thermal exchanger predictive_guard • reroute stubCore->ane",
                    "Integrity weave verified guard.fold"
                ]
        )
    }

    @Test
    func pilotSnapshotOmitsFoldedLungLinesWithoutReleaseSummary() {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-no-folded-lung",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                )
            ),
            releaseSummary: nil,
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(snapshot.foldedLungTitle == nil)
        #expect(snapshot.foldedLungLines.isEmpty)
    }

    @Test
    func localMutationSurfaceBuildsFurnaceWorkbenchGuidanceForQuickActions() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-furnace-quick",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                )
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace quick actions should hold the next step.",
                reasons: [
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 ready/1 • version 0 • retract 0 ready/0 • gate hold"
                ],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: true,
                activeCheckpointID: "active-furnace-quick",
                activeCheckpointSource: .pinnedHint
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(snapshot.furnaceWorkbenchSectionTitle == "Furnace workbench")
        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.title == "Quick actions are holding the next furnace review step")
        #expect(guidance.detail == "Review the pending shadow trial before promotion or approval.")
        #expect(guidance.runNowActionTitle == DecisionEvolutionPilotControlPresentationSupport.restoreActiveTitle)
        #expect(guidance.runNowIntent?.kind == .restoreActiveCheckpoint)
        #expect(guidance.actionTitle == "Inspect quick actions")
        #expect(guidance.focusTarget == .quickActions)
    }

    @Test
    func localMutationSurfaceBuildsFurnaceWorkbenchGuidanceForQueueLineage() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-furnace-lineage",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                ),
                pendingReview: [
                    makeCheckpoint(
                        checkpointID: "review-furnace-lineage",
                        createdAt: Date(timeIntervalSince1970: 20),
                        approvalState: .reviewSuggested,
                        hasLineage: true
                    )
                ]
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace lineage cleanup should hold the next step.",
                reasons: [
                    "L13 retraction • pending rule.pending • reason evolution.shadow_trial_pending"
                ],
                pendingReviewCount: 1,
                canRestoreActiveCheckpoint: true,
                activeCheckpointID: "active-furnace-lineage",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-furnace-lineage"
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        #expect(snapshot.furnaceWorkbenchSectionTitle == "Furnace workbench")
        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.title == "Queue lineage is holding the next furnace review step")
        #expect(guidance.detail == "Clear the pending retraction order before wider rollout.")
        #expect(guidance.runNowActionTitle == DecisionEvolutionPilotControlPresentationSupport.clearQueueLineageTitle)
        #expect(guidance.runNowIntent?.kind == .clearPendingReviewLineage)
        #expect(guidance.actionTitle == "Inspect queue lineage")
        #expect(guidance.focusTarget == .queueLineage)
    }

    @Test
    func localMutationSurfaceBuildsReadyFurnaceWorkbenchAvailabilityForQuickActions() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-furnace-ready",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                ),
                pendingReview: [
                    makeCheckpoint(
                        checkpointID: "review-furnace-ready",
                        createdAt: Date(timeIntervalSince1970: 20),
                        approvalState: .reviewSuggested,
                        hasLineage: true
                    )
                ],
                restorableCheckpointIDs: ["active-furnace-ready-prior"]
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace quick actions should show what can run now.",
                reasons: [
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 0 ready/0 • version 0 • retract 0 ready/0 • gate hold"
                ],
                pendingReviewCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-furnace-ready",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-furnace-ready"
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.focusTarget == .quickActions)
        #expect(guidance.runNowActionTitle == DecisionEvolutionPilotControlPresentationSupport.approveQueueTitle)
        #expect(guidance.runNowIntent?.kind == .approvePendingCheckpoints)
        #expect(guidance.availabilityTitle == "Ready now")
        #expect(
            guidance.availabilityLines
                == [
                    "Restore active path is available.",
                    "Rollback active path is available.",
                    "Approve review queue is available."
                ]
        )
    }

    @Test
    func localMutationSurfaceBuildsMixedFurnaceWorkbenchAvailabilityForQuickActions() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-furnace-mixed",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                )
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace quick actions should explain mixed readiness.",
                reasons: [
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 0 ready/0 • version 0 • retract 0 ready/0 • gate hold"
                ],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: "active-furnace-mixed",
                activeCheckpointSource: .pinnedHint
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.focusTarget == .quickActions)
        #expect(guidance.runNowActionTitle == DecisionEvolutionPilotControlPresentationSupport.restoreActiveTitle)
        #expect(guidance.runNowIntent?.kind == .restoreActiveCheckpoint)
        #expect(guidance.availabilityTitle == "Ready now")
        #expect(
            guidance.availabilityLines
                == [
                    "Restore active path is available.",
                    "Rollback active path is waiting for a restorable previous checkpoint.",
                    "Approve review queue is waiting for pending review checkpoints."
                ]
        )
    }

    @Test
    func localMutationSurfaceBuildsBlockedFurnaceWorkbenchAvailabilityForQuickActions() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace quick actions are fully blocked.",
                reasons: [
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 0 ready/0 • version 0 • retract 0 ready/0 • gate hold"
                ],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: false
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.focusTarget == .quickActions)
        #expect(guidance.runNowActionTitle == nil)
        #expect(guidance.runNowIntent == nil)
        #expect(guidance.availabilityTitle == "Blocked")
        #expect(
            guidance.availabilityLines
                == [
                    "Restore active path is waiting for an active checkpoint.",
                    "Rollback active path is waiting for an active checkpoint.",
                    "Approve review queue is waiting for pending review checkpoints."
                ]
        )
    }

    @Test
    func localMutationSurfaceBuildsBlockedFurnaceWorkbenchAvailabilityForQueueLineage() throws {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-furnace-lineage-blocked",
                    createdAt: Date(timeIntervalSince1970: 10),
                    approvalState: .automatic,
                    hasLineage: true
                )
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Furnace lineage cleanup is blocked.",
                reasons: [
                    "L13 retraction • pending rule.pending • reason evolution.shadow_trial_pending"
                ],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: true,
                activeCheckpointID: "active-furnace-lineage-blocked",
                activeCheckpointSource: .pinnedHint
            ),
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        let guidance = try #require(snapshot.furnaceWorkbenchGuidance)
        #expect(guidance.focusTarget == .queueLineage)
        #expect(guidance.runNowActionTitle == nil)
        #expect(guidance.runNowIntent == nil)
        #expect(guidance.availabilityTitle == "Blocked")
        #expect(
            guidance.availabilityLines
                == [
                    "Clear queue lineage is waiting for lineage-backed review checkpoints."
                ]
        )
    }

    @Test
    func readFirstSurfaceRoutesPendingReviewGuidanceToPreferredDestination() {
        let controlSurface = makeControlSurface(
            pendingReview: [
                makeCheckpoint(
                    checkpointID: "review-read-first",
                    createdAt: Date(timeIntervalSince1970: 30),
                    approvalState: .reviewSuggested,
                    hasLineage: true
                )
            ]
        )
        let releaseSummary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Read-first surface should route control.",
            reasons: ["Pending review remains."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: false,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: nil,
            activeCheckpointSource: .none,
            reviewCheckpointID: "review-read-first"
        )
        let navigationOptions = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: true,
            showHistoryShortcut: true,
            showPortraitShortcut: true
        )

        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            surfaceContract: .settings,
            navigationOptions: navigationOptions
        )

        #expect(snapshot.allowsLocalMutationActions == false)
        #expect(snapshot.pendingReviewCount == 1)
        #expect(snapshot.rollbackReadyCount == 0)
        #expect(snapshot.headerTitle == "Evolution pilot controls")
        #expect(
            snapshot.headerDetail
                == DecisionEvolutionMutationRoutingPresentationSupport.routedPilotDetail()
        )
        #expect(snapshot.embeddedReleaseSummaryMode == .surface)
        #expect(
            snapshot.guidedAction?.title
                == DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline
        )
        #expect(
            snapshot.guidedAction?.detail
                == DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason
        )
        #expect(snapshot.guidedAction?.actionTitle == "Open control center")
        #expect(
            snapshot.pendingReviewLineageNotice
                == DecisionEvolutionLineagePresentationSupport.pendingReviewLineageNotice(
                    pendingReviewLineageCount: 1,
                    hasReleaseSummary: true
                )
        )
        #expect(snapshot.reviewAuditLine == "Review audit: guardrail-review-read-first")
        #expect(snapshot.recommendedKillSwitchesLine == nil)

        if case let .navigation(destination)? = snapshot.guidedAction?.route {
            #expect(destination == .controlCenter)
        } else {
            Issue.record("Expected navigation-guided action for read-first surface.")
        }
    }

    @Test
    func recommendedKillSwitchesFallBackToReviewCheckpointWhenReleaseSummaryIsMissing() {
        let controlSurface = makeControlSurface(
            pendingReview: [
                makeCheckpoint(
                    checkpointID: "review-fallback",
                    createdAt: Date(timeIntervalSince1970: 40),
                    approvalState: .reviewSuggested,
                    hasLineage: true,
                    killSwitches: ["external-tools", "host-write"]
                ),
                makeCheckpoint(
                    checkpointID: "review-legacy",
                    createdAt: Date(timeIntervalSince1970: 35),
                    approvalState: .reviewSuggested,
                    hasLineage: false
                )
            ]
        )

        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: nil,
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.checkpointNavigationOptions
        )

        #expect(snapshot.pendingReviewCount == 2)
        #expect(snapshot.rollbackReadyCount == 0)
        #expect(snapshot.recommendedKillSwitches == ["external-tools", "host-write"])
        #expect(snapshot.pendingReviewLineageCount == 1)
        #expect(snapshot.embeddedReleaseSummaryMode == nil)
        #expect(snapshot.pendingReviewLineageNotice == nil)
        #expect(snapshot.reviewAuditLine == "Review audit: guardrail-review-fallback")
        #expect(snapshot.recommendedKillSwitchesLine == "Suggested kill switches: external-tools • host-write")
        #expect(snapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchHeadline)
        #expect(snapshot.guidedAction?.detail == DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchDetail)
        #expect(snapshot.guidedAction?.actionTitle == "Open control center")

        if case let .navigation(destination)? = snapshot.guidedAction?.route {
            #expect(destination == .controlCenter)
        } else {
            Issue.record("Expected read-first fallback guidance to route pending review through control center.")
        }
    }

    @Test
    func notRestorableGuidanceUsesSharedRecoveryCopy() {
        let snapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: makeControlSurface(
                active: makeCheckpoint(
                    checkpointID: "active-not-restorable",
                    createdAt: Date(timeIntervalSince1970: 60),
                    approvalState: .automatic,
                    hasLineage: true
                ),
                pendingReview: []
            ),
            releaseSummary: makeReleaseSummary(
                headline: "Active path is not restorable.",
                reasons: ["Recovery is required first."],
                pendingReviewCount: 0,
                canRestoreActiveCheckpoint: false,
                activeCheckpointID: "active-not-restorable"
            ),
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.checkpointNavigationOptions
        )

        #expect(snapshot.guidedAction?.title == DecisionEvolutionReviewPathPresentationSupport.pilotNotRestorableHeadline)
        #expect(snapshot.guidedAction?.detail == DecisionEvolutionReviewPathPresentationSupport.pilotNotRestorableDetail)
        #expect(snapshot.guidedAction?.actionTitle == "Open control center")
    }

    @Test
    func primaryBlockerPresentationSupportBuildsSharedPilotGuidance() {
        #expect(
            DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
                blocker: .runtimeGuardrails,
                primaryReason: nil,
                allowsLocalMutationActions: false
            )
                == DecisionEvolutionPrimaryBlockerGuidancePresentation(
                    headline: DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
                    detail: DecisionEvolutionReleaseStagePresentationSupport.pilotRuntimeGuardrailsDetail
                )
        )
        #expect(
            DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
                blocker: .pendingReview,
                primaryReason: nil,
                allowsLocalMutationActions: true
            )
                == DecisionEvolutionPrimaryBlockerGuidancePresentation(
                    headline: DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewHeadline,
                    detail: DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewDetail(
                        allowsMutations: true
                    )
                )
        )
        #expect(
            DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
                blocker: .ready,
                primaryReason: nil,
                allowsLocalMutationActions: false
            ) == nil
        )
    }

    private func makeControlSurface(
        active: DecisionReviewCheckpointSnapshot? = nil,
        pendingReview: [DecisionReviewCheckpointSnapshot] = [],
        restorableCheckpointIDs: Set<String> = []
    ) -> DecisionEvolutionControlSurface {
        DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            reviewCheckpoint: nil,
            pendingReviewQueue: pendingReview,
            latestPersistedLineage: nil,
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }

    private func makeCheckpoint(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool,
        killSwitches: [String] = []
    ) -> DecisionReviewCheckpointSnapshot {
        DecisionReviewCheckpointSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: checkpointID + "-prior",
            createdAt: createdAt,
            mode: .mirror,
            approvalState: approvalState,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["\(checkpointID) summary"],
            eBrain: hasLineage ? makeReplaySummary(
                checkpointID: checkpointID,
                recordedAt: createdAt,
                killSwitches: killSwitches
            ) : nil,
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
    }

    private func makeReleaseSummary(
        headline: String,
        reasons: [String],
        pendingReviewCount: Int,
        activeKillSwitches: [String] = [],
        recommendedKillSwitches: [String] = [],
        killSwitches: [String] = [],
        canRestoreActiveCheckpoint: Bool,
        canRollbackActiveCheckpoint: Bool = false,
        activeCheckpointID: String? = nil,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource = .none,
        reviewCheckpointID: String? = nil
    ) -> DecisionSystemReleaseControlSummary {
        DecisionSystemReleaseControlSummary(
            state: pendingReviewCount > 0 ? .watch : (activeKillSwitches.isEmpty ? .ready : .blocked),
            headline: headline,
            reasons: reasons,
            activeKillSwitches: activeKillSwitches,
            recommendedKillSwitches: recommendedKillSwitches,
            killSwitches: killSwitches,
            pendingReviewCount: pendingReviewCount,
            rollbackReadyCount: canRollbackActiveCheckpoint ? 1 : 0,
            canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: canRollbackActiveCheckpoint,
            activeCheckpointID: activeCheckpointID,
            activeCheckpointSource: activeCheckpointSource,
            reviewCheckpointID: reviewCheckpointID
        )
    }

    private func makeReplaySummary(
        checkpointID: String,
        recordedAt: Date,
        killSwitches: [String]
    ) -> DeveloperDecisionReplayEBrainSummary {
        DeveloperDecisionReplayEBrainSummary(
            lineageSummary: BASEvolutionLineageSummary(
                recordedAt: recordedAt,
                sessionID: "session-\(checkpointID)",
                taskType: "decision",
                riskLevel: "high",
                permitMode: "delay",
                hostGatePercent: 82,
                thoughtFoldChecksum: "fold-\(checkpointID)",
                updateTicketSummaries: ["ticket-\(checkpointID)"],
                activeKillSwitches: killSwitches,
                guardrailFindings: ["guardrail-\(checkpointID)"],
                recommendedKillSwitches: killSwitches
            )
        )
    }
}
