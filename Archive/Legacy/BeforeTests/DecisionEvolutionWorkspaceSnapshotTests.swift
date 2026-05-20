import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionWorkspaceSnapshotTests: XCTestCase {
    func testWorkspaceSnapshotCarriesReleaseSummaryAndPartitionsHistory() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let reviewHead = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let reviewTail = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let history = makeSnapshot(
            checkpointID: "history-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )

        let surface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead, reviewTail],
            latestPersistedLineage: nil
        )
        let releaseSummary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Watching the pending review queue",
            reasons: ["1 checkpoint still requires review."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 2,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: true,
            activeCheckpointID: active.checkpointID,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpointID: reviewHead.checkpointID
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: surface,
            releaseSummary: releaseSummary,
            historyPresentations: [active.presentation, reviewHead.presentation, reviewTail.presentation, history.presentation]
        )

        XCTAssertEqual(workspace.releaseSummary?.headline, releaseSummary.headline)
        XCTAssertEqual(workspace.activePresentation?.checkpointID, "active-1")
        XCTAssertEqual(workspace.reviewPresentation?.checkpointID, "review-2")
        XCTAssertEqual(workspace.remainingReviewQueue.map(\.checkpointID), ["review-1"])
        XCTAssertEqual(workspace.historyPresentations.map(\.checkpointID), ["history-1"])
    }

    func testWorkspaceSnapshotSupportsNilReleaseSummary() {
        let reviewHead = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let reviewTail = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: false
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: reviewHead,
                pendingReviewQueue: [reviewHead, reviewTail],
                latestPersistedLineage: nil
            ),
            historyPresentations: [reviewHead.presentation, reviewTail.presentation]
        )

        XCTAssertNil(workspace.releaseSummary)
        XCTAssertNil(workspace.activePresentation)
        XCTAssertEqual(workspace.reviewPresentation?.checkpointID, "review-2")
        XCTAssertEqual(workspace.remainingReviewQueue.map(\.checkpointID), ["review-1"])
    }

    func testWorkspaceSnapshotPrefersReleaseSummaryForEffectiveFacts() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching the pending review queue",
                reasons: ["Queue review remains pending."],
                activeKillSwitches: ["force_guard_mode"],
                recommendedKillSwitches: ["external-tools"],
                killSwitches: ["force_guard_mode", "external-tools"],
                pendingReviewCount: 3,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: active.checkpointID,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: review.checkpointID
            )
        )

        XCTAssertEqual(workspace.facts.pendingReviewCount, 3)
        XCTAssertEqual(workspace.facts.rollbackReadyCount, 2)
        XCTAssertEqual(workspace.facts.activeKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(workspace.facts.recommendedKillSwitches, ["external-tools"])
        XCTAssertEqual(workspace.facts.killSwitches, ["force_guard_mode", "external-tools"])
        XCTAssertTrue(workspace.facts.canRestoreActiveCheckpoint)
        XCTAssertTrue(workspace.facts.canRollbackActiveCheckpoint)
        XCTAssertEqual(workspace.effectivePendingReviewCount, 3)
        XCTAssertEqual(workspace.effectiveRollbackReadyCount, 2)
        XCTAssertEqual(workspace.effectiveActiveKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(workspace.effectiveRecommendedKillSwitches, ["external-tools"])
        XCTAssertEqual(workspace.effectiveKillSwitches, ["force_guard_mode", "external-tools"])
        XCTAssertTrue(workspace.effectiveCanRestoreActiveCheckpoint)
        XCTAssertTrue(workspace.effectiveCanRollbackActiveCheckpoint)
    }

    func testWorkspacePolicyUsesSurfaceContractMutationModeForSharedConsumers() {
        let active = makeSnapshot(
            checkpointID: "active-policy-surface",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-policy-surface",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .automaticFallback,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil,
                restorableCheckpointIDs: ["previous-active-policy-surface", "previous-review-policy-surface"]
            )
        )

        let homePolicy = workspace.policy(for: .home)
        let controlPolicy = workspace.policy(for: .controlCenter)

        XCTAssertFalse(homePolicy.input.allowsLocalMutationActions)
        XCTAssertTrue(controlPolicy.input.allowsLocalMutationActions)
        XCTAssertEqual(homePolicy.primaryBlocker, controlPolicy.primaryBlocker)
        XCTAssertEqual(homePolicy.input.pendingReviewCount, 1)
        XCTAssertEqual(controlPolicy.input.pendingReviewCount, 1)
        XCTAssertNil(homePolicy.recommendedPilotStep(canNavigate: false))
        XCTAssertEqual(
            controlPolicy.recommendedPilotStep(canNavigate: false)?.action,
            .approvePendingQueue
        )
    }

    func testWorkspaceSnapshotSeparatesSpotlightReviewFromQueueTailCounts() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let reviewHead = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let reviewTailA = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let reviewTailB = makeSnapshot(
            checkpointID: "review-0",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: false
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                reviewCheckpoint: reviewHead,
                pendingReviewQueue: [reviewHead, reviewTailA, reviewTailB],
                latestPersistedLineage: nil
            )
        )

        XCTAssertEqual(workspace.spotlightedPendingReviewCount, 1)
        XCTAssertEqual(workspace.queuedPendingReviewCount, 2)
        XCTAssertEqual(workspace.totalPendingReviewCount, 3)
    }

    func testWorkspaceSnapshotFiltersQueueAndHistoryWithSharedEvolutionFilterContract() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 50),
            approvalState: .automatic,
            hasLineage: true
        )
        let reviewHead = makeSnapshot(
            checkpointID: "review-2",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let reviewTail = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: false
        )
        let blockedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "history-blocked",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .mirror,
            approvalState: .automatic,
            rollbackReady: false,
            hasBrainStateSnapshot: true,
            diffSummary: ["history-blocked"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: Date(timeIntervalSince1970: 20),
                    sessionID: "session-history-blocked",
                    taskType: "decision",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 77,
                    thoughtFoldChecksum: "fold-history-blocked",
                    updateTicketSummaries: ["ticket-history-blocked"],
                    guardrailFindings: ["audit-history-blocked"],
                    recommendedKillSwitches: ["kill-history-blocked"]
                )
            )
        )
        let lineageOnly = DecisionEvolutionLineageSnapshot(
            checkpointID: "history-lineage",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .mirror,
            approvalState: .automatic,
            rollbackReady: false,
            hasBrainStateSnapshot: true,
            diffSummary: ["history-lineage"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: Date(timeIntervalSince1970: 10),
                    sessionID: "session-history-lineage",
                    taskType: "decision",
                    riskLevel: "stable",
                    permitMode: "delay",
                    hostGatePercent: 55,
                    thoughtFoldChecksum: "fold-history-lineage",
                    updateTicketSummaries: ["ticket-history-lineage"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        XCTAssertEqual(
            [
                DecisionEvolutionHistoryFilterPresentationSupport.allTitle,
                DecisionEvolutionHistoryFilterPresentationSupport.reviewTitle,
                DecisionEvolutionHistoryFilterPresentationSupport.rollbackReadyTitle,
                DecisionEvolutionHistoryFilterPresentationSupport.blockedTitle,
                DecisionEvolutionHistoryFilterPresentationSupport.lineageBackedTitle,
            ],
            ["All", "Review", "Rollback", "Blocked", "Lineage"]
        )

        XCTAssertEqual(
            DecisionEvolutionHistoryFilter.allCases.map(\.title),
            ["All", "Review", "Rollback", "Blocked", "Lineage"]
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpoint: reviewHead,
                pendingReviewQueue: [reviewHead, reviewTail],
                latestPersistedLineage: nil
            ),
            historyPresentations: [
                active.presentation,
                reviewHead.presentation,
                reviewTail.presentation,
                DecisionReviewCheckpointSnapshot(lineage: blockedLineage).presentation,
                DecisionReviewCheckpointSnapshot(lineage: lineageOnly).presentation
            ]
        )

        XCTAssertEqual(
            workspace.filteredEvolutionQueue(using: .all).map(\.checkpointID),
            ["review-1"]
        )
        XCTAssertEqual(
            workspace.filteredEvolutionQueue(using: .review).map(\.checkpointID),
            ["review-1"]
        )
        XCTAssertEqual(
            workspace.filteredEvolutionQueue(using: .rollbackReady).map(\.checkpointID),
            []
        )
        XCTAssertEqual(
            workspace.filteredEvolutionQueue(using: .blocked).map(\.checkpointID),
            []
        )
        XCTAssertEqual(
            workspace.filteredEvolutionQueue(using: .lineageBacked).map(\.checkpointID),
            []
        )

        XCTAssertEqual(
            workspace.filteredEvolutionHistory(using: .all).map(\.checkpointID),
            ["history-blocked", "history-lineage"]
        )
        XCTAssertEqual(
            workspace.filteredEvolutionHistory(using: .review).map(\.checkpointID),
            []
        )
        XCTAssertEqual(
            workspace.filteredEvolutionHistory(using: .rollbackReady).map(\.checkpointID),
            []
        )
        XCTAssertEqual(
            workspace.filteredEvolutionHistory(using: .blocked).map(\.checkpointID),
            ["history-blocked"]
        )
        XCTAssertEqual(
            workspace.filteredEvolutionHistory(using: .lineageBacked).map(\.checkpointID),
            ["history-blocked", "history-lineage"]
        )
    }

    func testRuntimeSpotlightPrefersActiveCheckpointAndCarriesSourceDetails() throws {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching the pending review queue",
                reasons: ["Queue review remains pending."],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 1,
                rollbackReadyCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: active.checkpointID,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: review.checkpointID
            )
        )

        let spotlight = workspace.runtimeSpotlight(
            releaseSummary: try XCTUnwrap(workspace.releaseSummary)
        )

        XCTAssertEqual(spotlight?.roleTitle, "Active")
        XCTAssertEqual(
            spotlight?.detailText,
            "Active active-1 • Pinned active • Automatic • Apply ready"
        )
    }

    func testRuntimeStatusPresentationPrefersSpotlightOverAttention() throws {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching the pending review queue",
                reasons: ["Queue review remains pending."],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 1,
                rollbackReadyCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: active.checkpointID,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: review.checkpointID
            )
        )
        let attentionSignal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        let presentation = workspace.runtimeStatusPresentation(attentionSignal: attentionSignal)

        XCTAssertEqual(
            presentation,
            DecisionEvolutionRuntimeStatusPresentation(
                headline: nil,
                detail: "Active active-1 • Pinned active • Automatic • Apply ready",
                usesAttentionAccent: false
            )
        )
    }

    func testRuntimeStatusPresentationFallsBackToAttentionWhenNoSpotlightIsAvailable() {
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )
        let attentionSignal = DecisionEvolutionAttentionSignal.build(workspace: workspace)

        let presentation = workspace.runtimeStatusPresentation(attentionSignal: attentionSignal)

        XCTAssertEqual(
            presentation,
            DecisionEvolutionRuntimeStatusPresentation(
                headline: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchDetail,
                usesAttentionAccent: true
            )
        )
    }

    func testReviewHeadWithoutActiveCheckpointLineUsesSharedReviewHeadCopy() {
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )

        XCTAssertEqual(
            workspace.reviewHeadWithoutActiveCheckpointLine,
            "Review head review-1 is visible in the shared control surface, but no active checkpoint is attached to the main release path yet."
        )
    }

    func testRuntimePresentationSupportFormatsSharedSpotlightAndReviewHeadCopy() {
        XCTAssertEqual(
            DecisionEvolutionRuntimePresentationSupport.roleTitle(isActive: true),
            "Active"
        )
        XCTAssertEqual(
            DecisionEvolutionRuntimePresentationSupport.roleTitle(isActive: false),
            "Review head"
        )
        XCTAssertEqual(
            DecisionEvolutionRuntimePresentationSupport.applyTitle(applyReady: true),
            "Apply ready"
        )
        XCTAssertEqual(
            DecisionEvolutionRuntimePresentationSupport.spotlightDetail(
                checkpointID: "active-1",
                isActive: true,
                approvalStateTitle: "Automatic",
                applyReady: true,
                activeCheckpointSource: .pinnedHint
            ),
            "Active active-1 • Pinned active • Automatic • Apply ready"
        )
        XCTAssertEqual(
            DecisionEvolutionRuntimePresentationSupport.reviewHeadWithoutActiveCheckpointLine(
                checkpointID: "review-1"
            ),
            "Review head review-1 is visible in the shared control surface, but no active checkpoint is attached to the main release path yet."
        )
    }

    func testRecoveryPresentationPrefersRecoveredDescriptorAndSharedEmptyMessages() {
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )

        let recoveredPresentation = workspace.recoveryPresentation(hasCurrentBrainState: false)
        XCTAssertEqual(recoveredPresentation.sourceDescriptor?.kind, .checkpointRecovery)
        XCTAssertEqual(
            recoveredPresentation.availabilityText,
            "Live brain state is unavailable right now, but persisted checkpoints remain reviewable and restorable from local lineage."
        )
        XCTAssertEqual(
            recoveredPresentation.emptyMessage,
            "Recovered checkpoints remain visible here even without a live current brain."
        )

        let livePresentation = workspace.recoveryPresentation(hasCurrentBrainState: true)
        XCTAssertEqual(livePresentation.sourceDescriptor?.kind, .checkpointRecovery)
        XCTAssertEqual(livePresentation.availabilityText, "Rollback ready")
        XCTAssertEqual(
            livePresentation.emptyMessage,
            "Evolution checkpoints appear after the current brain is loaded."
        )
    }

    func testRecoveryPresentationWithoutCheckpointsUsesPendingSharedCopy() {
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            )
        )

        let presentation = workspace.recoveryPresentation(hasCurrentBrainState: false)
        XCTAssertNil(presentation.sourceDescriptor)
        XCTAssertEqual(
            presentation.availabilityText,
            "Evolution checkpoints appear after the current brain is loaded."
        )
        XCTAssertEqual(
            presentation.emptyMessage,
            "Evolution checkpoints appear after the current brain is loaded."
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
            previousCheckpointID: nil,
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
