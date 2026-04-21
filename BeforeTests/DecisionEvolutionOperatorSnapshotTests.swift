import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionOperatorSnapshotTests: XCTestCase {
    func testOperatorSnapshotUsesReleaseSummaryWhenAvailable() {
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
                reasons: ["1 checkpoint still requires review."],
                activeKillSwitches: [],
                recommendedKillSwitches: ["host-write"],
                killSwitches: ["host-write"],
                pendingReviewCount: 1,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-1",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-1"
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.releaseState, .watch)
        XCTAssertEqual(snapshot.headline, "Watching the pending review queue")
        XCTAssertEqual(snapshot.primaryReason, "1 checkpoint still requires review.")
        XCTAssertEqual(snapshot.pendingReviewCount, 1)
        XCTAssertEqual(snapshot.rollbackReadyCount, 2)
        XCTAssertEqual(snapshot.activeCheckpointID, "active-1")
        XCTAssertEqual(snapshot.activeCheckpointSource, .pinnedHint)
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(snapshot.killSwitches, ["host-write"])
        XCTAssertEqual(snapshot.surfaceTitle, "Evolution Control")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.mutationHub.operatorHeadline)
    }

    func testOperatorSummaryPresentationSurfacesFoldedLungLinesFromReleaseReasons() {
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching audit findings before wider rollout",
                reasons: [
                    "Factors: evidence_caveat_load",
                    "L3 compression runtime • breath guard • phase resume • anchor anchor-release",
                    "Breath guard • Phase resume • Restore 87%",
                    "Morph graph morph.release • organs riskSpine, permitKnot, stubCore • route checkpoint • thermal checkpoint-recovery",
                    "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 173ms • maintenance 0ms • resume rollback_hot",
                    "Integrity weave recovered • checks 3/3 • contamination 2 • hash hash-release",
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 pending/1 • version 1 • retract 1 pending/1 • gate hold"
                ],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 0,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.summaryPresentation.foldedLungTitle, "Folded lung")
        XCTAssertEqual(
            snapshot.summaryPresentation.foldedLungLines,
            [
                "L3 compression runtime • breath guard • phase resume • anchor anchor-release",
                "Breath guard • Phase resume • Restore 87%",
                "Morph graph morph.release • organs riskSpine, permitKnot, stubCore • route checkpoint • thermal checkpoint-recovery",
                "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 173ms • maintenance 0ms • resume rollback_hot",
                "Integrity weave recovered • checks 3/3 • contamination 2 • hash hash-release"
            ]
        )
    }

    func testOperatorSnapshotFallsBackToControlSurfaceSignalsWithoutReleaseSummary() {
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

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .history,
            workspace: workspace,
            contract: .history
        )

        XCTAssertNil(snapshot.releaseState)
        XCTAssertEqual(snapshot.headline, "Watching queue kill switches")
        XCTAssertEqual(snapshot.primaryReason, "Queue kill switches remain active until the review path is cleared.")
        XCTAssertEqual(snapshot.pendingReviewCount, 1)
        XCTAssertEqual(snapshot.rollbackReadyCount, 0)
        XCTAssertNil(snapshot.activeCheckpointID)
        XCTAssertEqual(snapshot.activeCheckpointSource, .none)
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(snapshot.killSwitches, ["kill-review-1"])
        XCTAssertEqual(snapshot.surfaceTitle, "History workbench")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.observeAndRoute.operatorHeadline)
    }

    func testOperatorSnapshotPrioritizesFirstActiveCheckpointBeforeReadOnlyPendingReviewWhenQueueIsClean() {
        let review = makeSnapshot(
            checkpointID: "review-clean",
            createdAt: Date(timeIntervalSince1970: 35),
            approvalState: .reviewSuggested,
            hasLineage: true,
            recommendedKillSwitches: []
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .history,
            workspace: workspace,
            contract: .history
        )

        XCTAssertEqual(snapshot.headline, "Watching for the first active checkpoint")
        XCTAssertEqual(snapshot.primaryReason, "No active checkpoint is attached to the current release path yet.")
        XCTAssertNil(snapshot.activeCheckpointID)
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-clean")
        XCTAssertEqual(snapshot.killSwitches, [])
    }

    func testOperatorSnapshotPrioritizesQueueKillSwitchesInsideMutationHub() {
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

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertNil(snapshot.releaseState)
        XCTAssertEqual(snapshot.headline, "Watching queue kill switches")
        XCTAssertEqual(snapshot.primaryReason, "Queue kill switches remain active until the review path is cleared.")
        XCTAssertEqual(snapshot.pendingReviewCount, 1)
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(snapshot.activeCheckpointSource, .none)
        XCTAssertEqual(snapshot.killSwitches, ["kill-review-1"])
        XCTAssertEqual(snapshot.surfaceTitle, "Evolution Control")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.mutationHub.operatorHeadline)
    }

    func testOperatorSnapshotUsesRecoveredActiveCheckpointCopyWhenFallbackIsVisible() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .automaticFallback,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .home,
            workspace: workspace,
            contract: .home
        )

        XCTAssertNil(snapshot.releaseState)
        XCTAssertEqual(snapshot.headline, "Recovered active checkpoint is visible")
        XCTAssertEqual(
            snapshot.primaryReason,
            "The recovered automatic checkpoint can be inspected without leaving this surface."
        )
        XCTAssertEqual(snapshot.activeCheckpointID, "active-1")
        XCTAssertEqual(snapshot.activeCheckpointSource, .automaticFallback)
    }

    func testPrimaryBlockerPresentationSupportBuildsSharedOperatorGuidance() {
        let review = makeSnapshot(
            checkpointID: "review-guidance",
            createdAt: Date(timeIntervalSince1970: 30),
            approvalState: .reviewSuggested,
            hasLineage: true,
            recommendedKillSwitches: []
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )

        let mutationGuidance = DecisionEvolutionPrimaryBlockerPresentationSupport.operatorGuidance(
            blocker: .pendingReview,
            workspace: workspace,
            contract: .controlCenter
        )
        let readOnlyGuidance = DecisionEvolutionPrimaryBlockerPresentationSupport.operatorGuidance(
            blocker: .pendingReview,
            workspace: workspace,
            contract: .history
        )
        let emptyGuidance = DecisionEvolutionPrimaryBlockerPresentationSupport.operatorGuidance(
            blocker: .missingActiveCheckpoint,
            workspace: DecisionEvolutionWorkspaceSnapshot.build(
                controlSurface: DecisionEvolutionControlSurface(
                    activeCheckpoint: nil,
                    reviewCheckpoint: nil,
                    pendingReviewQueue: [],
                    latestPersistedLineage: nil
                )
            ),
            contract: .history
        )

        XCTAssertEqual(
            mutationGuidance,
            DecisionEvolutionReviewPathPresentationSupport.operatorPendingReviewGuidance(
                pendingReviewCount: 1,
                allowsMutations: true
            )
        )
        XCTAssertEqual(
            readOnlyGuidance,
            DecisionEvolutionReviewPathPresentationSupport.operatorPendingReviewGuidance(
                pendingReviewCount: 1,
                allowsMutations: false
            )
        )
        XCTAssertEqual(
            emptyGuidance,
            DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionCheckpointRecoverySupport.noPersistedLineageHeadline,
                detail: nil
            )
        )
    }

    func testReviewPathPresentationSupportExposesSharedGuidanceBuilders() {
        XCTAssertEqual(
            DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchGuidance,
            DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchReason
            )
        )
        XCTAssertEqual(
            DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewGuidance(
                allowsMutations: false
            ),
            DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewDetail(
                    allowsMutations: false
                )
            )
        )
    }

    func testActiveCheckpointSourceExposesSharedVisibleLexicon() {
        XCTAssertEqual(
            DecisionEvolutionActiveCheckpointSource.pinnedHint.visibleTitle,
            "Pinned active"
        )
        XCTAssertEqual(
            DecisionEvolutionActiveCheckpointSource.pinnedHint.visibleCheckpointHeadline,
            "Pinned active checkpoint is visible"
        )
        XCTAssertEqual(
            DecisionEvolutionActiveCheckpointSource.pinnedHint.visibleCheckpointReason,
            "The host-pinned active checkpoint can be inspected without leaving this surface."
        )
        XCTAssertNil(DecisionEvolutionActiveCheckpointSource.none.visibleTitle)
        XCTAssertEqual(
            DecisionEvolutionActiveCheckpointSource.none.visibleCheckpointHeadline,
            "Active checkpoint is visible"
        )
    }

    func testOperatorSummaryPresentationFormatsModeCountsAndKillSwitches() {
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
                reasons: ["1 checkpoint still requires review."],
                activeKillSwitches: [],
                recommendedKillSwitches: ["host-write"],
                killSwitches: ["host-write"],
                pendingReviewCount: 1,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-1",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-1"
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.summaryPresentation.headline, "Watching the pending review queue")
        XCTAssertEqual(snapshot.summaryPresentation.primaryReason, "1 checkpoint still requires review.")
        XCTAssertEqual(snapshot.summaryPresentation.modeLine, "Evolution Control • Mutation hub")
        XCTAssertEqual(
            snapshot.summaryPresentation.countsLine,
            "Active active-1 • Review review-1 • Pending 1 • Rollback-ready 2"
        )
        XCTAssertEqual(snapshot.summaryPresentation.killSwitchesLine, "Kill switches: host-write")
    }

    func testOperatorSnapshotElevatesSovereignPostureLinesOutOfPrimaryReason() {
        let active = makeSnapshot(
            checkpointID: "active-sovereign",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-sovereign",
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
                reasons: [
                    "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
                    "Factors: evidence_caveat_load",
                    "Sovereign authority • tokens memoryWrite • warrants memoryWrite • lock session • quarantine session",
                    "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
                ],
                activeKillSwitches: [],
                recommendedKillSwitches: ["host-write"],
                killSwitches: ["host-write"],
                pendingReviewCount: 1,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-sovereign",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: "review-sovereign"
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.primaryReason, "Factors: evidence_caveat_load")
        XCTAssertEqual(
            snapshot.summaryPresentation.primaryReason,
            "Factors: evidence_caveat_load"
        )
        XCTAssertEqual(
            snapshot.summaryPresentation.headline,
            "Watching the pending review queue"
        )
    }

    func testOperatorSnapshotSummaryPresentationSurfacesHorizonDiagnosticsLines() {
        let executionCapabilityFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .foundationModels,
            preferredProvider: .foundationModels,
            fallbackProvider: .gemmaE4B,
            providerTrack: .builtInSystem,
            executionTier: .systemManaged,
            foundationTier: .systemManaged,
            reasonCodes: ["tier:systemManaged", "active:foundationModels"]
        )
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching audit findings before wider rollout",
                reasons: [
                    executionCapabilityFrame.detailLine,
                    executionCapabilityFrame.horizonLine,
                    executionCapabilityFrame.temporalLine,
                    executionCapabilityFrame.evidenceLine,
                    executionCapabilityFrame.persistenceLine,
                    "Factors: evidence_caveat_load"
                ],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 0,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.primaryReason, "Factors: evidence_caveat_load")
        XCTAssertEqual(
            snapshot.summaryPresentation.primaryReason,
            "Factors: evidence_caveat_load"
        )
        XCTAssertEqual(snapshot.summaryPresentation.horizonDiagnosticsTitle, "Horizon diagnostics")
        XCTAssertEqual(
            snapshot.summaryPresentation.horizonDiagnosticsLines,
            [
                executionCapabilityFrame.detailLine,
                executionCapabilityFrame.horizonLine,
                executionCapabilityFrame.temporalLine,
                executionCapabilityFrame.evidenceLine,
                executionCapabilityFrame.persistenceLine
            ]
        )
    }

    func testOperatorSnapshotSummaryPresentationSurfacesFurnaceFabricLines() {
        let active = makeSnapshot(
            checkpointID: "active-fabric",
            createdAt: Date(timeIntervalSince1970: 40),
            approvalState: .automatic,
            hasLineage: true
        )

        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                activeCheckpointSource: .pinnedHint,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching audit findings before wider rollout",
                reasons: [
                    "Factors: evidence_caveat_load",
                    "L8 temporal field • records 1 • arcs 1 • conflicts 1",
                    "L10-L12 adjudication • tri 1 scored/0 veto • HIGH → DELAY • GSI 68% • alternatives 1",
                    "L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 pending/1 • version 1 • retract 1 pending/1 • gate hold",
                    "L13 version tree • rule rule.ready • rollback rollback.rule.ready",
                    "L13 retraction • pending rule.pending • reason evolution.shadow_trial_pending",
                    "L14 sovereign • constraints tool_cut • verdict quarantine"
                ],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 0,
                rollbackReadyCount: 1,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-fabric",
                activeCheckpointSource: .pinnedHint,
                reviewCheckpointID: nil
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.primaryReason, "Factors: evidence_caveat_load")
        XCTAssertEqual(snapshot.summaryPresentation.furnaceContributionTitle, "Furnace fabric")
        XCTAssertEqual(
            snapshot.summaryPresentation.furnaceContributionLines,
            [
                "L8 temporal field • records 1 • arcs 1 • conflicts 1",
                "L10-L12 adjudication • tri 1 scored/0 veto • HIGH → DELAY • GSI 68% • alternatives 1",
                "L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 pending/1 • version 1 • retract 1 pending/1 • gate hold",
                "L13 version tree • rule rule.ready • rollback rollback.rule.ready",
                "L13 retraction • pending rule.pending • reason evolution.shadow_trial_pending"
            ]
        )
        XCTAssertEqual(snapshot.summaryPresentation.furnaceChecklistTitle, "Furnace review checklist")
        XCTAssertEqual(
            snapshot.summaryPresentation.furnaceChecklistLines,
            [
                "Review the pending shadow trial before promotion or approval.",
                "Review the pending evolution seal before promotion or approval.",
                "Inspect the version tree delta and rollback pointer before wider rollout.",
                "Clear the pending retraction order before wider rollout."
            ]
        )
        XCTAssertEqual(snapshot.summaryPresentation.furnaceNextStepTitle, "Recommended next step")
        XCTAssertEqual(
            snapshot.summaryPresentation.furnaceNextStepDetail,
            "Review the pending shadow trial before promotion or approval."
        )
    }

    func testOperatorSnapshotSummaryPresentationSurfacesQueueLineageWorkbenchPreview() {
        let review = makeSnapshot(
            checkpointID: "review-retraction",
            createdAt: Date(timeIntervalSince1970: 30),
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
                headline: "Watching audit findings before wider rollout",
                reasons: [
                    "Factors: evidence_caveat_load",
                    "L13 retraction • pending rule.pending • reason evolution.shadow_trial_pending"
                ],
                activeKillSwitches: [],
                recommendedKillSwitches: [],
                killSwitches: [],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: "review-retraction"
            )
        )

        let snapshot = DecisionEvolutionOperatorSnapshot.build(
            surfaceKind: .controlCenter,
            workspace: workspace,
            contract: .controlCenter
        )

        XCTAssertEqual(snapshot.furnaceWorkbenchPresentation?.title, "Furnace workbench")
        XCTAssertEqual(
            snapshot.furnaceWorkbenchPresentation?.headline,
            "Queue lineage is holding the next furnace review step"
        )
        XCTAssertEqual(
            snapshot.furnaceWorkbenchPresentation?.detail,
            "Clear the pending retraction order before wider rollout."
        )
        XCTAssertEqual(
            snapshot.furnaceWorkbenchPresentation?.availabilityTitle,
            "Blocked"
        )
        XCTAssertEqual(
            snapshot.furnaceWorkbenchPresentation?.availabilityLines,
            [
                "Clear queue lineage is waiting for lineage-backed review checkpoints."
            ]
        )
    }

    func testOperatorSummaryPresentationSupportFormatsSharedSurfaceAndCountCopy() {
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.surfaceTitle(for: .history),
            DecisionEvolutionSurfaceTitleLexiconSupport.historyTitle
        )
        XCTAssertEqual(DecisionEvolutionOperatorSummaryPresentationSupport.activePrefix, "Active")
        XCTAssertEqual(DecisionEvolutionOperatorSummaryPresentationSupport.reviewPrefix, "Review")
        XCTAssertEqual(DecisionEvolutionOperatorSummaryPresentationSupport.pendingPrefix, "Pending")
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.rollbackReadyPrefix,
            "Rollback-ready"
        )
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.killSwitchesPrefix,
            "Kill switches"
        )
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.modeLine(
                surfaceKind: .controlCenter,
                interactionMode: .mutationHub
            ),
            "Evolution Control • Mutation hub"
        )
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.countsLine(
                activeCheckpointID: nil,
                reviewCheckpointID: "review-1",
                pendingReviewCount: 2,
                rollbackReadyCount: 1
            ),
            "Active none • Review review-1 • Pending 2 • Rollback-ready 1"
        )
        XCTAssertEqual(
            DecisionEvolutionOperatorSummaryPresentationSupport.killSwitchesLine(["host-write"]),
            "Kill switches: host-write"
        )
        XCTAssertNil(DecisionEvolutionOperatorSummaryPresentationSupport.killSwitchesLine([]))
    }

    private func makeSnapshot(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool,
        recommendedKillSwitches: [String]? = nil
    ) -> DecisionReviewCheckpointSnapshot {
        let summary = hasLineage
            ? makeLineageSummary(
                checkpointID: checkpointID,
                recordedAt: createdAt,
                recommendedKillSwitches: recommendedKillSwitches ?? ["kill-\(checkpointID)"]
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
        recommendedKillSwitches: [String]
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
            recommendedKillSwitches: recommendedKillSwitches
        )
    }
}
