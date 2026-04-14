import Foundation
import Testing
import BASHostKit
@testable import Before

struct DecisionEvolutionPilotControlSnapshotTests {
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
        #expect(localMutationSnapshot.guidedAction?.actionTitle == "Approve review queue")

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
        #expect(snapshot.approveQueueIntent?.kind == .approvePendingCheckpoints)
        #expect(snapshot.guidedAction?.actionTitle == "Approve review queue")

        if case let .mutation(intent)? = snapshot.guidedAction?.route {
            #expect(intent.kind == .approvePendingCheckpoints)
        } else {
            Issue.record("Expected mutation-guided action for local mutation surface.")
        }

        #expect(snapshot.recommendedKillSwitches == ["external-tools"])
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
        #expect(snapshot.guidedAction?.actionTitle == "Open control center")

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
        #expect(snapshot.guidedAction?.actionTitle == "Open control center")

        if case let .navigation(destination)? = snapshot.guidedAction?.route {
            #expect(destination == .controlCenter)
        } else {
            Issue.record("Expected read-first fallback guidance to route pending review through control center.")
        }
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
