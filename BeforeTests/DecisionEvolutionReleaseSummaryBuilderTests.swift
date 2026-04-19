import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionReleaseSummaryBuilderTests: XCTestCase {
    func testReleasePathPresentationSupportExposesSharedHeadlineAndReasonContract() {
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.blockedReleaseHeadline,
            "Blocked by active kill switches"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.blockedReleaseReason,
            "Kill switches are active on the current release path."
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.recommendedReleaseHeadline,
            "Watching recommended kill switches"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.blockedReviewHeadline,
            "Evolution is blocked by active kill switches"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.blockedReviewDetail,
            "Open Evolution Control to clear the blocked review path before release work continues."
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.releaseHeadline,
            "Watching the pending review queue"
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.attentionDetail(
                pendingReviewCount: 2
            ),
            "2 checkpoint(s) still need review before the queue is clear."
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.operatorReason(
                pendingReviewCount: 2,
                allowsMutations: true
            ),
            "2 checkpoint(s) are ready for direct queue work here."
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.releaseReason(
                pendingReviewCount: 2,
                beforePromotion: true
            ),
            "2 checkpoint(s) still require review before promotion."
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.pilotDetail(
                allowsMutations: false
            ),
            "This surface stays read-first. Open Evolution Control and work the queue there before widening rollout."
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
            "Blocked by runtime guardrails"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseStagePresentationSupport.watchingAuditFindingsHeadline,
            "Watching audit findings before wider rollout"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseStagePresentationSupport.readyForGuardedPilotHeadline,
            "Ready for guarded pilot rollout"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseStagePresentationSupport.rollbackNotReadyReason,
            "The active checkpoint does not currently expose a previous checkpoint for rollback."
        )
        XCTAssertEqual(
            DecisionEvolutionRestorabilityPresentationSupport.blockedUntilRestorableHeadline,
            "Blocked until the active checkpoint is restorable"
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.blockedActiveKillSwitchHeadline,
            "Blocked by active kill switches"
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.watchingPendingReviewHeadline,
            "Watching the pending review queue"
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.readyForGuardedPilotHeadline,
            "Ready for guarded pilot rollout"
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason,
            "The active checkpoint does not currently expose a previous checkpoint for rollback."
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason,
            "No active checkpoint is attached to the current release path yet."
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.activeCheckpointRestorableReason(
                checkpointID: "active-1"
            ),
            "Active checkpoint active-1 is restorable."
        )
        XCTAssertEqual(
            DecisionEvolutionReleasePathPresentationSupport.activeCheckpointRestorableReason(
                checkpointID: nil
            ),
            "The active checkpoint is restorable."
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.auditLine(
                auditFindings: ["guardrail-a", "guardrail-b"]
            ),
            "Review audit: guardrail-a • guardrail-b"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.suggestedLine(
                killSwitches: ["external-tools", "host-write"]
            ),
            "Suggested kill switches: external-tools • host-write"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.queueReasonLine(
                killSwitches: ["queue-a", "queue-b"]
            ),
            "Pending review kill switches: queue-a • queue-b"
        )
    }

    func testPrimaryBlockerEvaluatorUsesSharedPriorityOrder() {
        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                for: DecisionEvolutionPrimaryBlockerContext(
                    activeKillSwitches: [],
                    recommendedKillSwitches: ["external-tools"],
                    runtimeBlockers: [],
                    hasActiveCheckpoint: false,
                    canRestoreActiveCheckpoint: false,
                    pendingReviewCount: 2,
                    reviewAuditFindings: ["audit-a"],
                    canRollbackActiveCheckpoint: false
                )
            ),
            [
                .recommendedKillSwitches,
                .missingActiveCheckpoint,
                .pendingReview,
                .auditFindings
            ]
        )
    }

    func testPrimaryBlockerEvaluatorUsesSharedWorkspaceFactsFallback() {
        let review = makeSnapshot(
            checkpointID: "review-workspace",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["queue-kill"]
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
            DecisionEvolutionPrimaryBlockerEvaluator.evaluate(workspace: workspace),
            .recommendedKillSwitches
        )
    }

    func testPrimaryBlockerPresentationSupportBuildsSharedReleaseGuidance() {
        let review = makeSnapshot(
            checkpointID: "review-guidance",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["queue-kill"]
        )
        let pendingReviewSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil
        )

        let pendingReviewGuidance = DecisionEvolutionPrimaryBlockerPresentationSupport.releaseGuidance(
            blocker: .missingActiveCheckpoint,
            blockerSignals: [],
            controlSurface: pendingReviewSurface,
            queueAuditFindings: pendingReviewSurface.queueAuditFindings,
            queueKillSwitches: pendingReviewSurface.queueKillSwitches
        )

        XCTAssertEqual(pendingReviewGuidance.state, .watch)
        XCTAssertEqual(
            pendingReviewGuidance.headline,
            DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline
        )
        XCTAssertEqual(
            pendingReviewGuidance.reasons.first,
            DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason
        )
        XCTAssertTrue(
            pendingReviewGuidance.reasons.contains(
                DecisionEvolutionReviewPathPresentationSupport.releasePendingReviewReason(
                    pendingReviewCount: 1,
                    beforePromotion: true
                )
            )
        )
        XCTAssertTrue(
            pendingReviewGuidance.reasons.contains(
                DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchReasonLine(
                    killSwitches: ["queue-kill"]
                )
            )
        )
        XCTAssertEqual(
            pendingReviewGuidance.state,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseState(
                for: .missingActiveCheckpoint
            )
        )
        XCTAssertEqual(
            pendingReviewGuidance.headline,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseHeadline(
                for: .missingActiveCheckpoint
            )
        )
        XCTAssertEqual(
            pendingReviewGuidance.reasons,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseReasons(
                for: .missingActiveCheckpoint,
                blockerSignals: [],
                controlSurface: pendingReviewSurface,
                queueAuditFindings: pendingReviewSurface.queueAuditFindings,
                queueKillSwitches: pendingReviewSurface.queueKillSwitches
            )
        )

        let active = makeSnapshot(
            checkpointID: "active-guidance",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let readySurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-guidance"]
        )

        let readyGuidance = DecisionEvolutionPrimaryBlockerPresentationSupport.releaseGuidance(
            blocker: .ready,
            blockerSignals: [],
            controlSurface: readySurface,
            queueAuditFindings: [],
            queueKillSwitches: []
        )

        XCTAssertEqual(readyGuidance.state, .ready)
        XCTAssertEqual(
            readyGuidance.headline,
            DecisionEvolutionReleasePathPresentationSupport.readyForGuardedPilotHeadline
        )
        XCTAssertEqual(
            readyGuidance.reasons,
            [
                DecisionEvolutionReleasePathPresentationSupport.activeCheckpointRestorableReason(
                    checkpointID: "active-guidance"
                )
            ]
        )
        XCTAssertEqual(
            readyGuidance.state,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseState(for: .ready)
        )
        XCTAssertEqual(
            readyGuidance.headline,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseHeadline(for: .ready)
        )
        XCTAssertEqual(
            readyGuidance.reasons,
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseReasons(
                for: .ready,
                blockerSignals: [],
                controlSurface: readySurface,
                queueAuditFindings: [],
                queueKillSwitches: []
            )
        )
        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseState(for: .runtimeGuardrails),
            .blocked
        )
        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseHeadline(for: .pendingReview),
            DecisionEvolutionReleasePathPresentationSupport.watchingPendingReviewHeadline
        )
        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerPresentationSupport.releaseReasons(
                for: .activeKillSwitches,
                blockerSignals: [],
                controlSurface: readySurface,
                queueAuditFindings: [],
                queueKillSwitches: []
            ),
            [DecisionEvolutionReleasePathPresentationSupport.activeKillSwitchReason]
        )
    }

    func testPrimaryBlockerEvaluatorUsesSharedControlSurfaceFallbackOrdering() {
        let review = makeSnapshot(
            checkpointID: "review-fallback",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil
        )

        XCTAssertEqual(
            DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                controlSurface: controlSurface,
                releaseSummary: nil,
                activeKillSwitches: [],
                recommendedKillSwitches: controlSurface.queueKillSwitches,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false
            ),
            [
                .missingActiveCheckpoint,
                .pendingReview,
                .auditFindings
            ]
        )
    }

    func testBuilderBlocksWhenActiveKillSwitchesArePresent() {
        let active = makeSnapshot(
            checkpointID: "active-1",
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
            restorableCheckpointIDs: ["previous-active-1"]
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitchesHint: ["external-tools"]
        )

        XCTAssertEqual(summary.state, .blocked)
        XCTAssertEqual(summary.headline, "Blocked by active kill switches")
        XCTAssertEqual(summary.activeKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(summary.recommendedKillSwitches, ["external-tools"])
        XCTAssertEqual(summary.killSwitches, ["force_guard_mode", "external-tools"])
    }

    func testBuilderSurfacesQueueRecommendationsWhenReviewRemains() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: []
        )

        XCTAssertEqual(summary.state, .watch)
        XCTAssertEqual(summary.headline, "Watching recommended kill switches")
        XCTAssertEqual(summary.pendingReviewCount, 1)
        XCTAssertEqual(summary.recommendedKillSwitches, ["external-tools"])
        XCTAssertTrue(summary.reasons.contains("Recommended kill switches are waiting for operator review before wider rollout."))
    }

    func testBuilderUsesSharedQueueSignalCopy() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools", "host-write"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: ["external-tools", "host-write"]
        )

        XCTAssertTrue(
            summary.reasons.contains(
                DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchReasonLine(
                    killSwitches: ["external-tools", "host-write"]
                )
            )
        )
        XCTAssertTrue(
            summary.reasons.contains(
                DecisionEvolutionReviewPathPresentationSupport.queueAuditFindingsReasonLine(
                    auditFindings: ["guardrail-review-1"]
                )
            )
        )
        XCTAssertEqual(
            DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                auditFindings: ["guardrail-review-1"],
                killSwitches: ["external-tools", "host-write"]
            ),
            [
                DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchReasonLine(
                    killSwitches: ["external-tools", "host-write"]
                ),
                DecisionEvolutionReviewPathPresentationSupport.queueAuditFindingsReasonLine(
                    auditFindings: ["guardrail-review-1"]
                )
            ]
        )
    }

    func testReleaseStagePresentationSupportReturnsSharedAuditReasonLines() {
        XCTAssertEqual(
            DecisionEvolutionReleaseStagePresentationSupport.auditReasonLines(
                auditFindings: ["audit-a", "audit-b"]
            ),
            ["audit-a", "audit-b"]
        )
    }

    func testBuilderPromotesLiveHorizonDiagnosticsToWatchingAuditFindings() {
        let active = makeSnapshot(
            checkpointID: "active-horizon",
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
            restorableCheckpointIDs: ["previous-active-horizon"]
        )
        let eBrainSummary = DecisionSystemEBrainSummary(
            source: .liveRuntime,
            runMode: "guarded",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            deviceRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            hostGatePercent: 37,
            pressureLine: nil,
            riskFactorsLine: "Factors: evidence_caveat_load",
            reasonCodesLine: "Reason codes: evidence.caveat",
            foldChecksum: "checksum-horizon",
            updateTicketCount: 1,
            auditFindingCount: 1,
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            sovereignVerdictLine: nil,
            sovereignAuthorityLine: nil,
            sovereignAuditLine: nil,
            inspectionHeadline: "Horizon diagnostics active.",
            blockers: [],
            layerStackLines: [],
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: eBrainSummary,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: []
        )

        XCTAssertEqual(summary.state, .watch)
        XCTAssertEqual(
            summary.headline,
            DecisionEvolutionReleaseStagePresentationSupport.watchingAuditFindingsHeadline
        )
        XCTAssertEqual(summary.primaryBlocker, .auditFindings)
        XCTAssertTrue(summary.reasons.contains("Factors: evidence_caveat_load"))
        XCTAssertTrue(summary.reasons.contains("Reason codes: evidence.caveat"))
    }

    func testBuilderPromotesLiveSovereignSignalsToWatchingAuditFindings() {
        let active = makeSnapshot(
            checkpointID: "active-sovereign",
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
            restorableCheckpointIDs: ["previous-active-sovereign"]
        )
        let eBrainSummary = DecisionSystemEBrainSummary(
            source: .liveRuntime,
            runMode: "guarded",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            deviceRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            hostGatePercent: 37,
            pressureLine: nil,
            riskFactorsLine: nil,
            reasonCodesLine: nil,
            foldChecksum: "checksum-sovereign",
            updateTicketCount: 1,
            auditFindingCount: 1,
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            sovereignVerdictLine: "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
            sovereignAuthorityLine: "Sovereign authority • tokens memoryWrite • lock session • quarantine session",
            sovereignAuditLine: "Sovereign audit • BR-SOV-004 • ref audit.session-l14",
            inspectionHeadline: "Sovereign posture active.",
            blockers: [],
            layerStackLines: [],
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: eBrainSummary,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: []
        )

        XCTAssertEqual(summary.state, .watch)
        XCTAssertEqual(
            summary.headline,
            DecisionEvolutionReleaseStagePresentationSupport.watchingAuditFindingsHeadline
        )
        XCTAssertEqual(summary.primaryBlocker, .auditFindings)
        XCTAssertTrue(summary.reasons.contains("Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine"))
        XCTAssertTrue(summary.reasons.contains("Sovereign authority • tokens memoryWrite • lock session • quarantine session"))
        XCTAssertTrue(summary.reasons.contains("Sovereign audit • BR-SOV-004 • ref audit.session-l14"))
    }

    func testPresentationBuildCarriesCheckpointAndKillSwitchCopy() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )
        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitchesHint: ["external-tools"]
        )

        let presentation = DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: summary,
            controlSurface: controlSurface,
            presentationMode: .surface
        )

        XCTAssertEqual(presentation.stateTone, .red)
        XCTAssertEqual(
            presentation.badgePresentations,
            [
                DecisionEvolutionSummaryBadgePresentation(title: "BLOCKED", tone: .red),
                DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange),
                DecisionEvolutionSummaryBadgePresentation(title: "1 ROLLBACK READY", tone: .moss)
            ]
        )
        XCTAssertEqual(
            presentation.activeSourceText,
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: DecisionEvolutionReleaseSummaryPresentationSupport.activeSourcePrefix,
                values: ["Pinned active"]
            )
        )
        XCTAssertEqual(presentation.activeKillSwitchesText, "Active kill switches: force_guard_mode")
        XCTAssertEqual(presentation.recommendedKillSwitchesText, "Recommended kill switches: external-tools")
        XCTAssertEqual(presentation.activeCheckpointHeadline, "Active: active-1 • Automatic • HIGH → DELAY")
        XCTAssertEqual(presentation.reviewCheckpointHeadline, "Review head: review-1 • Review suggested • HIGH → DELAY")
    }

    func testPresentationSupportBuildCarriesCheckpointAndKillSwitchCopy() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )
        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitchesHint: ["external-tools"]
        )

        let presentation = DecisionEvolutionReleaseSummaryPresentationSupport.build(
            releaseSummary: summary,
            controlSurface: controlSurface,
            presentationMode: .surface
        )

        XCTAssertEqual(presentation.stateTone, .red)
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.activeSourcePrefix,
            "Active source"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.checkpointHeadline(
                roleTitle: DecisionEvolutionRuntimePresentationSupport.activeRoleTitle,
                presentation: controlSurface.activePresentation!
            ),
            "Active: active-1 • Automatic • HIGH → DELAY"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.checkpointHeadline(
                roleTitle: DecisionEvolutionRuntimePresentationSupport.reviewHeadRoleTitle,
                presentation: controlSurface.spotlightReviewPresentation!
            ),
            "Review head: review-1 • Review suggested • HIGH → DELAY"
        )
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.activeSourceText(
                releaseSummary: summary
            ),
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: DecisionEvolutionReleaseSummaryPresentationSupport.activeSourcePrefix,
                values: ["Pinned active"]
            )
        )
        XCTAssertEqual(
            presentation.badgePresentations,
            [
                DecisionEvolutionSummaryBadgePresentation(title: "BLOCKED", tone: .red),
                DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange),
                DecisionEvolutionSummaryBadgePresentation(title: "1 ROLLBACK READY", tone: .moss)
            ]
        )
        XCTAssertEqual(
            presentation.activeSourceText,
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: DecisionEvolutionReleaseSummaryPresentationSupport.activeSourcePrefix,
                values: ["Pinned active"]
            )
        )
        XCTAssertEqual(presentation.activeKillSwitchesText, "Active kill switches: force_guard_mode")
        XCTAssertEqual(presentation.recommendedKillSwitchesText, "Recommended kill switches: external-tools")
        XCTAssertEqual(presentation.activeCheckpointHeadline, "Active: active-1 • Automatic • HIGH → DELAY")
        XCTAssertEqual(presentation.reviewCheckpointHeadline, "Review head: review-1 • Review suggested • HIGH → DELAY")
    }

    func testPresentationBuildCarriesMutationHubOperatorCopy() {
        let summary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Watching the pending review queue",
            reasons: ["Queue review remains pending."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: false,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: nil,
            activeCheckpointSource: .none,
            reviewCheckpointID: nil
        )

        let presentation = DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: summary,
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            presentationMode: .mutationHub
        )

        XCTAssertEqual(presentation.operatorHeadline, "Mutation hub")
        XCTAssertTrue(presentation.operatorDetail?.contains("Apply, approve, rollback") == true)
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.operatorHeadline(for: .mutationHub),
            "Mutation hub"
        )
        XCTAssertTrue(
            DecisionEvolutionReleaseSummaryPresentationSupport.operatorDetail(for: .mutationHub)?
                .contains("Apply, approve, rollback") == true
        )
    }

    func testActionSupportUsesMutationHubQuickActionsWhenLocalMutationsAreAllowed() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )

        let actionPresentation = DecisionEvolutionReleaseSummaryActionSupport.build(
            controlSurface: controlSurface,
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        XCTAssertTrue(actionPresentation.allowsLocalMutationActions)
        XCTAssertTrue(actionPresentation.showsAnyActionRow)
        XCTAssertEqual(actionPresentation.quickActionsTitle, "Quick actions")
        XCTAssertEqual(actionPresentation.rollbackTitle, "Rollback active")
        XCTAssertEqual(actionPresentation.approveQueueTitle, "Approve queue")
        XCTAssertEqual(actionPresentation.clearReviewLineageTitle, "Clear review lineage")
        XCTAssertEqual(actionPresentation.rollbackIntent?.kind, .rollbackActiveCheckpoint)
        XCTAssertEqual(actionPresentation.approveQueueIntent?.kind, .approvePendingCheckpoints)
        XCTAssertEqual(actionPresentation.clearReviewLineageIntent?.kind, .clearPendingReviewLineage)
    }

    func testActionSupportKeepsObserveFooterWhenSurfaceRoutesMutationsAway() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )

        let actionPresentation = DecisionEvolutionReleaseSummaryActionSupport.build(
            controlSurface: controlSurface,
            surfaceContract: .home,
            navigationOptions: DecisionEvolutionSurfaceContract.home.navigationSurfaceOptions()
        )

        XCTAssertFalse(actionPresentation.allowsLocalMutationActions)
        XCTAssertTrue(actionPresentation.showsAnyActionRow)
        XCTAssertNil(actionPresentation.quickActionsTitle)
        XCTAssertEqual(actionPresentation.rollbackTitle, "Rollback active")
        XCTAssertEqual(actionPresentation.approveQueueTitle, "Approve queue")
        XCTAssertEqual(actionPresentation.clearReviewLineageTitle, "Clear review lineage")
        XCTAssertEqual(actionPresentation.rollbackIntent?.kind, .rollbackActiveCheckpoint)
        XCTAssertEqual(actionPresentation.approveQueueIntent?.kind, .approvePendingCheckpoints)
        XCTAssertEqual(actionPresentation.clearReviewLineageIntent?.kind, .clearPendingReviewLineage)
    }

    func testActionSupportDoesNotOpenQuickActionsForRestoreOnlyMutationSurface() {
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

        let actionPresentation = DecisionEvolutionReleaseSummaryActionSupport.build(
            controlSurface: controlSurface,
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        )

        XCTAssertTrue(actionPresentation.allowsLocalMutationActions)
        XCTAssertFalse(actionPresentation.showsAnyActionRow)
        XCTAssertNil(actionPresentation.quickActionsTitle)
        XCTAssertNil(actionPresentation.rollbackIntent)
        XCTAssertNil(actionPresentation.approveQueueIntent)
        XCTAssertNil(actionPresentation.clearReviewLineageIntent)
    }

    func testActionSupportMatchesSharedSurfaceActionPlanContractAcrossSurfaceModes() {
        let active = makeSnapshot(
            checkpointID: "active-policy-contract",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-policy-contract",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-policy-contract"]
        )

        for surfaceContract in [DecisionEvolutionSurfaceContract.controlCenter, .home] {
            let navigationOptions = surfaceContract.navigationSurfaceOptions()
            let actionPresentation = DecisionEvolutionReleaseSummaryActionSupport.build(
                controlSurface: controlSurface,
                surfaceContract: surfaceContract,
                navigationOptions: navigationOptions
            )
            let policy = DecisionEvolutionPolicyEngine.evaluate(
                DecisionEvolutionPolicyEngine.input(
                    controlSurface: controlSurface,
                    releaseSummary: nil,
                    activeKillSwitches: controlSurface.activeKillSwitches,
                    recommendedKillSwitches: controlSurface.queueKillSwitches,
                    canRestoreActiveCheckpoint: controlSurface.activePresentation?.applyReady == true,
                    canRollbackActiveCheckpoint: controlSurface.canRollbackActiveCheckpoint,
                    allowsLocalMutationActions: surfaceContract.allowsMutations
                )
            )
            let actionPlan = policy.surfaceActionPlan(
                navigationOptions: navigationOptions,
                routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter
            )

            XCTAssertEqual(
                actionPresentation.allowsLocalMutationActions,
                actionPlan.allowsLocalMutationActions,
                "Release-summary action availability drifted for \(surfaceContract.kind)."
            )
            XCTAssertEqual(
                actionPresentation.showsAnyActionRow,
                actionPlan.showsAnyActionRow,
                "Release-summary action-row visibility drifted for \(surfaceContract.kind)."
            )
            XCTAssertEqual(
                actionPresentation.quickActionsTitle,
                actionPlan.quickActionsTitle,
                "Release-summary quick-actions title drifted for \(surfaceContract.kind)."
            )
        }
    }

    func testKillSwitchPresentationSupportFormatsSharedActiveAndRecommendedLines() {
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: ["force_guard_mode", "require_reviewed_writes"]
            ),
            "Active kill switches: force_guard_mode • require_reviewed_writes"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchPresentationSupport.recommendedLine(
                killSwitches: ["external-tools"]
            ),
            "Recommended kill switches: external-tools"
        )
        XCTAssertNil(
            DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: []
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
        DecisionReviewCheckpointSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: "previous-\(checkpointID)",
            createdAt: createdAt,
            mode: .mirror,
            approvalState: approvalState,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["checkpoint \(checkpointID)"],
            eBrain: hasLineage ? DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: createdAt,
                    sessionID: "session-\(checkpointID)",
                    taskType: "decision",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 73,
                    thoughtFoldChecksum: "fold-\(checkpointID)",
                    updateTicketSummaries: ["ticket-\(checkpointID)"],
                    activeKillSwitches: [],
                    guardrailFindings: ["guardrail-\(checkpointID)"],
                    recommendedKillSwitches: killSwitches
                )
            ) : nil,
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
    }
}
