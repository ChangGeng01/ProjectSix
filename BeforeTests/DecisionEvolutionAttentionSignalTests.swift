import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionAttentionSignalTests: XCTestCase {
    func testAttentionSignalPrioritizesActiveKillSwitchesFromWorkspaceFacts() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .automatic,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .blocked,
                headline: DecisionEvolutionReleasePathPresentationSupport.blockedActiveKillSwitchHeadline,
                reasons: [DecisionEvolutionReleasePathPresentationSupport.activeKillSwitchReason],
                activeKillSwitches: ["force_guard_mode"],
                recommendedKillSwitches: [],
                killSwitches: ["force_guard_mode"],
                pendingReviewCount: 0,
                rollbackReadyCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-1",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: nil
            )
        )

        let signal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        XCTAssertEqual(signal.severity, .blocked)
        XCTAssertEqual(signal.badgeValue, "!")
        XCTAssertEqual(
            signal.headline,
            DecisionEvolutionKillSwitchPresentationSupport.blockedReviewHeadline
        )
        XCTAssertEqual(signal.killSwitches, ["force_guard_mode"])
        XCTAssertTrue(signal.rollbackReady)
    }

    func testAttentionSignalPrioritizesQueueKillSwitches() {
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let signal = DecisionEvolutionAttentionSignal.build(
            workspace: .build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: nil,
                    reviewCheckpoint: review,
                    pendingReviewQueue: [review],
                    latestPersistedLineage: nil
                )
            )
        )

        XCTAssertEqual(signal.severity, .blocked)
        XCTAssertEqual(signal.badgeValue, "!")
        XCTAssertEqual(
            signal.headline,
            DecisionEvolutionKillSwitchPresentationSupport.blockedReviewHeadline
        )
        XCTAssertEqual(
            signal.detail,
            DecisionEvolutionKillSwitchPresentationSupport.blockedReviewDetail
        )
        XCTAssertEqual(signal.killSwitches, ["kill-review-1"])
        XCTAssertEqual(signal.pendingReviewCount, 1)
    }

    func testAttentionSignalUsesReviewCountWhenQueueNeedsReview() {
        let reviewA = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let reviewB = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 11),
            approvalState: .reviewSuggested,
            hasLineage: false
        )

        let signal = DecisionEvolutionAttentionSignal.build(
            workspace: .build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: nil,
                    reviewCheckpoint: reviewA,
                    pendingReviewQueue: [reviewA, reviewB],
                    latestPersistedLineage: nil
                )
            )
        )

        XCTAssertEqual(signal.severity, .review)
        XCTAssertEqual(signal.badgeValue, "2")
        XCTAssertEqual(signal.pendingReviewCount, 2)
        XCTAssertTrue(signal.killSwitches.isEmpty)
    }

    func testAttentionSignalFallsBackToRollbackWatchWhenQueueIsClear() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .automatic,
            hasLineage: true
        )

        let signal = DecisionEvolutionAttentionSignal.build(
            workspace: .build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: active,
                    reviewCheckpoint: nil,
                    pendingReviewQueue: [],
                    latestPersistedLineage: nil,
                    restorableCheckpointIDs: ["active-1", "previous-active-1"]
                )
            )
        )

        XCTAssertEqual(signal.severity, .rollbackWatch)
        XCTAssertEqual(signal.badgeValue, "↺")
        XCTAssertEqual(
            signal.headline,
            DecisionEvolutionAttentionPresentationSupport.rollbackReadyHeadline
        )
        XCTAssertEqual(
            signal.detail,
            DecisionEvolutionAttentionPresentationSupport.rollbackReadyDetail
        )
        XCTAssertTrue(signal.rollbackReady)
    }

    func testAttentionSignalSurfacesRuntimeGuardrailsFromReleaseSummary() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .automatic,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .blocked,
                headline: DecisionEvolutionReleasePathPresentationSupport.blockedRuntimeGuardrailsHeadline,
                reasons: ["Thermal guardrail requires cooldown before wider rollout."],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 0,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: "active-1",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: nil
            )
        )

        let signal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        XCTAssertEqual(signal.severity, .blocked)
        XCTAssertEqual(signal.badgeValue, "!")
        XCTAssertEqual(
            signal.headline,
            DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline
        )
        XCTAssertEqual(
            signal.detail,
            "Thermal guardrail requires cooldown before wider rollout."
        )
        XCTAssertFalse(signal.rollbackReady)
    }

    func testAttentionSignalPrefersReleaseSummaryFactsOverRawControlSurface() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 21),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .ready,
                headline: "Ready",
                reasons: [],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 0,
                rollbackReadyCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-1",
                activeCheckpointSource: .automaticFallback,
                reviewCheckpointID: "review-1"
            )
        )

        let signal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        XCTAssertEqual(signal.severity, .rollbackWatch)
        XCTAssertEqual(signal.pendingReviewCount, 0)
        XCTAssertTrue(signal.rollbackReady)
    }

    func testAttentionPresentationSupportExposesRollbackAndQuietCopy() {
        XCTAssertEqual(
            DecisionEvolutionAttentionPresentationSupport.rollbackReadyHeadline,
            "Rollback-ready active checkpoint is available"
        )
        XCTAssertEqual(
            DecisionEvolutionAttentionPresentationSupport.rollbackReadyDetail,
            "Evolution Control can restore the previous checkpoint without rebuilding the full lineage path."
        )
        XCTAssertEqual(
            DecisionEvolutionAttentionPresentationSupport.quietHeadline,
            "Evolution is quiet"
        )
        XCTAssertEqual(
            DecisionEvolutionAttentionPresentationSupport.reviewBadgeValue(
                pendingReviewCount: 12
            ),
            "9+"
        )
    }

    func testAttentionPresentationBuildUsesSharedPrimaryBlockerFallbacks() {
        let reviewA = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let reviewB = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 11),
            approvalState: .reviewSuggested,
            hasLineage: false
        )

        let reviewPresentation = DecisionEvolutionAttentionPresentation.build(
            workspace: .build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: nil,
                    reviewCheckpoint: reviewA,
                    pendingReviewQueue: [reviewA, reviewB],
                    latestPersistedLineage: nil
                )
            )
        )

        XCTAssertEqual(reviewPresentation.severity, .review)
        XCTAssertEqual(reviewPresentation.badgeValue, "2")
        XCTAssertEqual(
            reviewPresentation.headline,
            DecisionEvolutionReviewPathPresentationSupport.reviewWaitingHeadline
        )

        let quietPresentation = DecisionEvolutionAttentionPresentation.build(
            workspace: .build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: nil,
                    reviewCheckpoint: nil,
                    pendingReviewQueue: [],
                    latestPersistedLineage: nil
                )
            )
        )

        XCTAssertEqual(quietPresentation.severity, .none)
        XCTAssertEqual(
            quietPresentation.headline,
            DecisionEvolutionAttentionPresentationSupport.quietHeadline
        )
    }

    private func makeSnapshot(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool
    ) -> DecisionReviewCheckpointSnapshot {
        let summary = hasLineage ? makeLineageSummary(checkpointID: checkpointID, recordedAt: createdAt) : nil
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
        recordedAt: Date
    ) -> BASEvolutionLineageSummary {
        BASEvolutionLineageSummary(
            recordedAt: recordedAt,
            sessionID: "session-\(checkpointID)",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 77,
            thoughtFoldChecksum: "fold-\(checkpointID)",
            updateTicketSummaries: ["ticket-\(checkpointID)"],
            guardrailFindings: ["audit-\(checkpointID)"],
            recommendedKillSwitches: ["kill-\(checkpointID)"]
        )
    }
}
