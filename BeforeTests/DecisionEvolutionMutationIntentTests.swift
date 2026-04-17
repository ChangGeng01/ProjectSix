import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionMutationIntentTests: XCTestCase {
    func testMutationPreviewPresentationExposesSharedViewCopyContract() {
        let intent = DecisionEvolutionMutationIntent(
            kind: .clearCheckpointLineage,
            title: "Clear lineage",
            message: "Preview lineage removal.",
            confirmTitle: "Clear lineage",
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearCheckpointLineage,
                scope: .checkpoint,
                headline: "Clear checkpoint-review lineage",
                summary: "Remove lineage facts without changing approval.",
                targetCheckpointIDs: ["checkpoint-review"],
                currentActiveCheckpointID: "checkpoint-active",
                projectedActiveCheckpointID: "checkpoint-active",
                currentReviewCheckpointID: "checkpoint-review",
                projectedReviewCheckpointID: "checkpoint-review",
                changeHighlights: ["Lineage will be removed."],
                retainedHighlights: ["Approval remains review-suggested."],
                warningHighlights: ["This cannot be undone."]
            )
        )

        let presentation = intent.previewPresentation
        XCTAssertEqual(presentation.toneBadgeTitle, "DESTRUCTIVE")
        XCTAssertEqual(presentation.impactTitle, "Control-surface impact")
        XCTAssertEqual(
            presentation.impactDetail,
            "See the active/review shift before you open the guarded confirmation sheet."
        )
        XCTAssertEqual(
            presentation.impactTargetsPrefix,
            DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix
        )
        XCTAssertEqual(
            presentation.activeTransitionTitle,
            DecisionEvolutionMutationLabelPresentationSupport.activeTransitionTitle
        )
        XCTAssertEqual(presentation.reviewTransitionTitle, "Review")
        XCTAssertEqual(presentation.transitionArrow, "→")
        XCTAssertEqual(presentation.currentLineTitle, "Current")
        XCTAssertEqual(presentation.projectedLineTitle, "Projected")
        XCTAssertEqual(presentation.missingCheckpointToken, "none")
        XCTAssertEqual(presentation.checkpointToken(nil), "none")
        XCTAssertEqual(
            presentation.transitionLine(current: nil, projected: "checkpoint-review"),
            "none → checkpoint-review"
        )
        XCTAssertEqual(
            presentation.currentLine(nil),
            "Current: none"
        )
        XCTAssertEqual(
            presentation.projectedLine("checkpoint-review"),
            "Projected: checkpoint-review"
        )
        XCTAssertEqual(
            presentation.impactTargetsLine(["checkpoint-a", "checkpoint-b"]),
            "Targets: checkpoint-a • checkpoint-b"
        )
        XCTAssertEqual(
            presentation.impactTargetsLine(["checkpoint-a", "checkpoint-b"]),
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: presentation.impactTargetsPrefix,
                values: ["checkpoint-a", "checkpoint-b"]
            )
        )
        XCTAssertNil(presentation.impactTargetsLine([]))
        XCTAssertEqual(presentation.changeSectionTitle, "Will change")
        XCTAssertEqual(presentation.retainedSectionTitle, "Will remain")
        XCTAssertEqual(presentation.warningSectionTitle, "Watch")
        XCTAssertEqual(presentation.cancelTitle, "Cancel")
    }

    func testCheckpointLexiconSupportExposesSharedApprovalAndMissingTokenCopy() {
        XCTAssertEqual(DecisionEvolutionCheckpointLexiconSupport.missingCheckpointToken, "none")
        XCTAssertEqual(
            DecisionEvolutionCheckpointLexiconSupport.checkpointToken(nil),
            "none"
        )
        XCTAssertEqual(
            DecisionEvolutionCheckpointLexiconSupport.approvalStateTitle(.automatic),
            "Automatic"
        )
        XCTAssertEqual(
            DecisionEvolutionCheckpointLexiconSupport.approvalStateTitle(.reviewSuggested),
            "Review suggested"
        )
    }

    func testMutationActionLexiconSupportExposesSharedActionTitles() {
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.applyCheckpointTitle,
            "Apply checkpoint"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.approveCheckpointTitle,
            "Approve checkpoint"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.markReviewTitle,
            "Mark review"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.clearLineageTitle,
            "Clear lineage"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.restoreActiveTitle,
            "Restore active"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.rollbackActiveTitle,
            "Rollback active"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.approvePendingTitle,
            "Approve pending"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.clearReviewLineageTitle,
            "Clear review lineage"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.approveSelectedTitle,
            "Approve selected"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.markSelectedTitle,
            "Mark selected"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationActionLexiconSupport.clearSelectedLineageTitle,
            "Clear selected lineage"
        )
    }

    func testMutationIntentCopySupportExposesSharedHeadlineAndSummaryContract() {
        XCTAssertEqual(
            DecisionEvolutionMutationIntentCopySupport.applyCheckpoint(
                checkpointID: "checkpoint-a"
            ),
            DecisionEvolutionMutationIntentCopy(
                message: "Restore checkpoint checkpoint-a as the active brain state. This changes the live host state, but it does not auto-approve review status or clear lineage.",
                headline: "Apply checkpoint-a",
                summary: "Restore this checkpoint as the active brain state while keeping review/audit facts visible."
            )
        )
        XCTAssertEqual(
            DecisionEvolutionMutationIntentCopySupport.approvePendingCheckpoints(
                count: 2,
                keepsActiveBrainStateStable: false
            ).summary,
            "Empty the review queue and let the automatic active slot advance to the most recent approved checkpoint."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationIntentCopySupport.clearSelectedCheckpointLineages(
                count: 3
            ).headline,
            "Clear lineage on 3 selected checkpoints"
        )
    }

    func testMutationPhraseSupportExposesSharedQueueTransitionCopy() {
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.approvalMovesToAutomaticLine,
            "Approval state will move from review-suggested to automatic."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.checkpointWillEnterReviewQueueLine(
                checkpointID: "checkpoint-a"
            ),
            "Checkpoint checkpoint-a will enter the review queue."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.pendingCheckpointsMoveToAutomaticLine(
                count: 2
            ),
            "2 checkpoint(s) will move from review-suggested to automatic."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.selectedCheckpointsMoveToAutomaticLine(
                count: 3
            ),
            "3 selected checkpoint(s) will move from review-suggested to automatic."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.selectedCheckpointsEnterReviewQueueLine(
                count: 1
            ),
            "1 selected checkpoint(s) will enter the review queue."
        )
    }

    func testMutationLabelPresentationSupportExposesSharedTargetsAndActiveCopy() {
        XCTAssertEqual(
            DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix,
            "Targets"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationLabelPresentationSupport.activeTransitionTitle,
            DecisionEvolutionCheckpointLexiconSupport.activeRuntimeRoleTitle
        )
    }

    func testMutationPhraseSupportExposesSharedDynamicCopy() {
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.reviewQueueWillBeEmptiedLine,
            "Review queue will be emptied."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.automaticActiveSlotMovesToLine(
                projectedActiveID: "checkpoint-a"
            ),
            "Automatic active slot will move to checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.automaticActiveSlotTransitionLine(
                currentCheckpointID: "checkpoint-a",
                projectedCheckpointID: "checkpoint-b"
            ),
            "Active automatic slot will move from checkpoint-a to checkpoint-b."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.automaticActiveSlotRemainsLine(
                projectedActiveID: "checkpoint-a"
            ),
            "Automatic active slot remains checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                checkpointID: "checkpoint-a"
            ),
            "Active checkpoint remains checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.activeCheckpointTransitionLine(
                currentCheckpointID: "checkpoint-a",
                projectedCheckpointID: "checkpoint-b"
            ),
            "Active checkpoint will move from checkpoint-a to checkpoint-b."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                checkpointID: nil
            ),
            "Active checkpoint remains none."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.restoredBrainStateLine(
                checkpointID: "checkpoint-b",
                projectedActiveID: "checkpoint-a"
            ),
            "Live brain state will restore from checkpoint-b, but the automatic active slot remains checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.reviewHeadAlignedLine(
                checkpointID: "checkpoint-a"
            ),
            "Review head stays aligned on checkpoint-a until its approval state changes."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.reviewHeadRemainsLine(
                checkpointID: "checkpoint-a"
            ),
            "Review head remains checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.currentReviewHeadRemainsLine(
                checkpointID: "checkpoint-a"
            ),
            "Current review head remains checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.reviewHeadShiftLine(
                checkpointID: "checkpoint-a"
            ),
            "Review head will shift to checkpoint-a."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.reviewQueueRetainedAfterApprovalLine(
                count: 2
            ),
            "Review queue will keep 2 checkpoint(s) after approval."
        )
        XCTAssertEqual(
            DecisionEvolutionMutationPhraseSupport.suggestedKillSwitchRemovalWarning(
                count: 2
            ),
            "2 suggested kill-switch recommendation(s) will be removed with the lineage payload."
        )
    }

    func testMutationOutcomePresentationExposesSharedOutcomeContract() {
        let success = DecisionEvolutionMutationOutcome(
            kind: .approveCheckpoint,
            title: "Approved checkpoint",
            message: "Checkpoint moved back onto the automatic path.",
            isSuccess: true,
            isDestructive: false,
            affectedCheckpointIDs: ["checkpoint-a"],
            recordedAt: .distantPast
        )
        XCTAssertEqual(success.presentation.statusTitle, "Completed")
        XCTAssertEqual(success.presentation.iconName, "checkmark.seal.fill")
        XCTAssertEqual(success.presentation.dismissTitle, "Dismiss")
        XCTAssertEqual(success.presentation.targetsPrefix, "Targets")
        XCTAssertEqual(
            success.presentation.targetsLine(success.affectedCheckpointIDs),
            "Targets: checkpoint-a"
        )
        XCTAssertEqual(success.presentation.tone, .success)

        let destructive = DecisionEvolutionMutationOutcome(
            kind: .clearCheckpointLineage,
            title: "Cleared lineage",
            message: "Removed stored lineage facts.",
            isSuccess: true,
            isDestructive: true,
            affectedCheckpointIDs: ["checkpoint-b"],
            recordedAt: .distantFuture
        )
        XCTAssertEqual(destructive.presentation.statusTitle, "Completed with lineage changes")
        XCTAssertEqual(destructive.presentation.iconName, "exclamationmark.shield.fill")
        XCTAssertEqual(destructive.presentation.tone, .caution)
        XCTAssertEqual(
            destructive.presentation.targetsLine(destructive.affectedCheckpointIDs),
            "Targets: checkpoint-b"
        )

        let failure = DecisionEvolutionMutationOutcome(
            kind: .rollbackActiveCheckpoint,
            title: "Rollback needs attention",
            message: "Rollback could not complete.",
            isSuccess: false,
            isDestructive: false,
            affectedCheckpointIDs: [],
            recordedAt: .now
        )
        XCTAssertEqual(failure.presentation.statusTitle, "Action needs attention")
        XCTAssertEqual(failure.presentation.iconName, "xmark.octagon.fill")
        XCTAssertEqual(failure.presentation.tone, .failure)
        XCTAssertNil(failure.presentation.targetsLine(failure.affectedCheckpointIDs))
        XCTAssertEqual(
            DecisionEvolutionMutationOutcomePresentationSupport.targetsLine(
                checkpointIDs: ["checkpoint-a", "checkpoint-b"]
            ),
            "Targets: checkpoint-a • checkpoint-b"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationOutcomePresentationSupport.targetsLine(
                checkpointIDs: ["checkpoint-a", "checkpoint-b"]
            ),
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: DecisionEvolutionMutationOutcomePresentationSupport.targetsPrefix,
                values: ["checkpoint-a", "checkpoint-b"]
            )
        )
    }

    func testPilotMutationIntentsExposePreflightActionsInStableOrder() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: "checkpoint-previous",
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Active checkpoint"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            reviewCheckpoint: nil,
            pendingReviewQueue: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review",
                    previousCheckpointID: nil,
                    createdAt: now.addingTimeInterval(-60),
                    mode: .mirror,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: true,
                    diffSummary: ["Pending review checkpoint"],
                    eBrain: replaySummary(
                        sessionID: "review",
                        riskLevel: "high",
                        permitMode: "delay",
                        updateTicketSummaries: ["Hold the response"],
                        guardrailFindings: ["Review guardrail"],
                        killSwitches: ["disableHighRiskAutoAction"]
                    )
                )
            ],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["checkpoint-active", "checkpoint-previous"]
        )

        let intents = DecisionEvolutionMutationIntentFactory.pilotMutationIntents(
            controlSurface: controlSurface
        )

        XCTAssertEqual(intents.map(\.kind), [
            .restoreActiveCheckpoint,
            .rollbackActiveCheckpoint,
            .approvePendingCheckpoints,
            .clearPendingReviewLineage
        ])
        XCTAssertEqual(intents.map(\.preview.scope), [
            .activePath,
            .activePath,
            .reviewQueue,
            .reviewQueue
        ])
    }

    func testPilotMutationIntentsCollapseWhenNoActionIsAvailable() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: false,
                hasBrainStateSnapshot: false,
                diffSummary: ["Active checkpoint"],
                eBrain: nil
            ),
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil
        )

        let intents = DecisionEvolutionMutationIntentFactory.pilotMutationIntents(
            controlSurface: controlSurface
        )

        XCTAssertTrue(intents.isEmpty)
    }

    func testRollbackIntentStaysHiddenWhenPreviousCheckpointIsNotRestorable() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: "checkpoint-previous",
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Active checkpoint"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["checkpoint-active"]
        )

        XCTAssertFalse(controlSurface.canRollbackActiveCheckpoint)
        XCTAssertNil(controlSurface.activeRollbackCheckpointID)
        XCTAssertNil(
            DecisionEvolutionMutationIntentFactory.rollbackActiveCheckpoint(
                controlSurface: controlSurface
            )
        )
    }

    func testApplyCheckpointPreviewKeepsAutomaticActiveSlotWhenTargetIsReviewSuggested() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Automatic active checkpoint"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            reviewCheckpoint: nil,
            pendingReviewQueue: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review",
                    previousCheckpointID: nil,
                    createdAt: now.addingTimeInterval(-60),
                    mode: .mirror,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: true,
                    diffSummary: ["Review checkpoint"],
                    eBrain: replaySummary(
                        sessionID: "review",
                        riskLevel: "high",
                        permitMode: "delay"
                    )
                )
            ],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.applyCheckpoint(
            checkpointID: "checkpoint-review",
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.preview.scope, .checkpoint)
        XCTAssertEqual(intent?.preview.currentActiveCheckpointID, "checkpoint-active")
        XCTAssertEqual(intent?.preview.projectedActiveCheckpointID, "checkpoint-active")
        XCTAssertEqual(intent?.preview.currentReviewCheckpointID, "checkpoint-review")
        XCTAssertEqual(intent?.preview.projectedReviewCheckpointID, "checkpoint-review")
    }

    func testApprovePendingPreviewPromotesMostRecentCheckpointWhenActiveSlotIsAutomaticFallback() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: false,
                diffSummary: ["Fallback active checkpoint"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            activeCheckpointSource: .automaticFallback,
            reviewCheckpoint: nil,
            pendingReviewQueue: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review-b",
                    previousCheckpointID: nil,
                    createdAt: now.addingTimeInterval(60),
                    mode: .mirror,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: false,
                    diffSummary: ["Newest review checkpoint"],
                    eBrain: nil
                )
            ],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.preview.currentActiveCheckpointID, "checkpoint-active")
        XCTAssertEqual(intent?.preview.projectedActiveCheckpointID, "checkpoint-review-b")
        XCTAssertEqual(
            intent?.preview.summary,
            "Empty the review queue and let the automatic active slot advance to the most recent approved checkpoint."
        )
    }

    func testApprovePendingPreviewKeepsPinnedActiveCheckpointStable() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Pinned active checkpoint"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: nil,
            pendingReviewQueue: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review-b",
                    previousCheckpointID: nil,
                    createdAt: now.addingTimeInterval(60),
                    mode: .mirror,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: false,
                    diffSummary: ["Newest review checkpoint"],
                    eBrain: replaySummary(
                        sessionID: "review-b",
                        riskLevel: "high",
                        permitMode: "delay"
                    )
                )
            ],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.preview.currentActiveCheckpointID, "checkpoint-active")
        XCTAssertEqual(intent?.preview.projectedActiveCheckpointID, "checkpoint-active")
        XCTAssertEqual(
            intent?.preview.summary,
            "Empty the review queue without restoring or rewriting the active brain state."
        )
        XCTAssertTrue(
            intent?.preview.retainedHighlights.contains(
                DecisionEvolutionLineagePresentationSupport.retainedPendingReviewFactsLine(
                    lineageBackedCount: 1
                )!
            ) == true
        )
    }

    func testMarkReviewPreviewBreaksTimestampTiesUsingCheckpointIDOrdering() {
        let now = Date()
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-review-z",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Automatic checkpoint that will enter review."],
                eBrain: replaySummary(
                    sessionID: "active-z",
                    riskLevel: "medium",
                    permitMode: "compare"
                )
            ),
            reviewCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-review-a",
                previousCheckpointID: nil,
                createdAt: now,
                mode: .mirror,
                approvalState: .reviewSuggested,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Existing review head."],
                eBrain: replaySummary(
                    sessionID: "review-a",
                    riskLevel: "high",
                    permitMode: "delay"
                )
            ),
            pendingReviewQueue: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review-a",
                    previousCheckpointID: nil,
                    createdAt: now,
                    mode: .mirror,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: true,
                    diffSummary: ["Existing review head."],
                    eBrain: replaySummary(
                        sessionID: "review-a",
                        riskLevel: "high",
                        permitMode: "delay"
                    )
                )
            ],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.markCheckpointForReview(
            checkpointID: "checkpoint-review-z",
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.preview.scope, .checkpoint)
        XCTAssertEqual(intent?.preview.currentActiveCheckpointID, "checkpoint-review-z")
        XCTAssertEqual(intent?.preview.currentReviewCheckpointID, "checkpoint-review-a")
        XCTAssertEqual(intent?.preview.projectedReviewCheckpointID, "checkpoint-review-z")
    }

    func testApproveSelectedCheckpointsKeepsUntouchedReviewHead() {
        let now = Date()
        let reviewHead = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-review-head",
            previousCheckpointID: nil,
            createdAt: now,
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review head"],
            eBrain: replaySummary(
                sessionID: "review-head",
                riskLevel: "high",
                permitMode: "delay"
            )
        )
        let reviewTail = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-review-tail",
            previousCheckpointID: nil,
            createdAt: now.addingTimeInterval(-30),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review tail"],
            eBrain: replaySummary(
                sessionID: "review-tail",
                riskLevel: "medium",
                permitMode: "compare"
            )
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: DecisionReviewCheckpointSnapshot(
                checkpointID: "checkpoint-active",
                previousCheckpointID: nil,
                createdAt: now.addingTimeInterval(-60),
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                hasBrainStateSnapshot: true,
                diffSummary: ["Active"],
                eBrain: replaySummary(
                    sessionID: "active",
                    riskLevel: "low",
                    permitMode: "answer"
                )
            ),
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead, reviewTail],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.approveSelectedCheckpoints(
            presentations: [reviewTail.presentation],
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.kind, .approveSelectedCheckpoints)
        XCTAssertEqual(intent?.preview.scope, .selection)
        XCTAssertEqual(intent?.preview.targetCheckpointIDs, ["checkpoint-review-tail"])
        XCTAssertEqual(intent?.preview.currentReviewCheckpointID, "checkpoint-review-head")
        XCTAssertEqual(intent?.preview.projectedReviewCheckpointID, "checkpoint-review-head")
        XCTAssertTrue(
            intent?.preview.retainedHighlights.contains(
                DecisionEvolutionLineagePresentationSupport.retainedSelectedFactsAfterApprovalLine(
                    lineageBackedCount: 1
                )!
            ) == true
        )
    }

    func testMarkSelectedCheckpointsForReviewDropsAutomaticActiveWhenSelected() {
        let now = Date()
        let active = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-active",
            previousCheckpointID: nil,
            createdAt: now,
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Automatic active"],
            eBrain: replaySummary(
                sessionID: "active",
                riskLevel: "medium",
                permitMode: "compare"
            )
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.markSelectedCheckpointsForReview(
            presentations: [active.presentation],
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.kind, .markSelectedCheckpointsForReview)
        XCTAssertEqual(intent?.preview.scope, .selection)
        XCTAssertEqual(intent?.preview.targetCheckpointIDs, ["checkpoint-active"])
        XCTAssertEqual(intent?.preview.currentActiveCheckpointID, "checkpoint-active")
        XCTAssertNil(intent?.preview.projectedActiveCheckpointID)
        XCTAssertEqual(intent?.preview.projectedReviewCheckpointID, "checkpoint-active")
    }

    func testApproveSelectedCheckpointsCountsOnlyTargetedLineageBackedSelections() {
        let now = Date()
        let reviewHead = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-review-head",
            previousCheckpointID: nil,
            createdAt: now.addingTimeInterval(-20),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review head"],
            eBrain: replaySummary(
                sessionID: "review-head",
                riskLevel: "medium",
                permitMode: "delay"
            )
        )
        let automaticLineage = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-automatic-lineage",
            previousCheckpointID: nil,
            createdAt: now.addingTimeInterval(-60),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Automatic lineage"],
            eBrain: replaySummary(
                sessionID: "automatic-lineage",
                riskLevel: "low",
                permitMode: "answer"
            )
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: automaticLineage,
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.approveSelectedCheckpoints(
            presentations: [reviewHead.presentation, automaticLineage.presentation],
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.preview.targetCheckpointIDs, ["checkpoint-review-head"])
        XCTAssertTrue(
            intent?.preview.retainedHighlights.contains(
                DecisionEvolutionLineagePresentationSupport.retainedSelectedFactsAfterApprovalLine(
                    lineageBackedCount: 1
                )!
            ) == true
        )
        XCTAssertFalse(
            intent?.preview.retainedHighlights.contains(
                DecisionEvolutionLineagePresentationSupport.retainedSelectedFactsAfterApprovalLine(
                    lineageBackedCount: 2
                )!
            ) == true
        )
    }

    func testClearSelectedCheckpointLineagesSkipsLineageLessSelections() {
        let now = Date()
        let lineageBacked = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-lineage",
            previousCheckpointID: nil,
            createdAt: now,
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Lineage"],
            eBrain: replaySummary(
                sessionID: "lineage",
                riskLevel: "high",
                permitMode: "delay",
                updateTicketSummaries: ["ticket"]
            )
        )
        let lineageLess = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-no-lineage",
            previousCheckpointID: nil,
            createdAt: now.addingTimeInterval(-30),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["No lineage"],
            eBrain: nil
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: lineageLess,
            reviewCheckpoint: nil,
            pendingReviewQueue: [lineageBacked],
            latestPersistedLineage: nil
        )

        let intent = DecisionEvolutionMutationIntentFactory.clearSelectedCheckpointLineages(
            presentations: [lineageBacked.presentation, lineageLess.presentation],
            controlSurface: controlSurface
        )

        XCTAssertEqual(intent?.kind, .clearSelectedCheckpointLineages)
        XCTAssertEqual(intent?.preview.targetCheckpointIDs, ["checkpoint-lineage"])
    }

    private func replaySummary(
        sessionID: String,
        riskLevel: String,
        permitMode: String,
        updateTicketSummaries: [String] = [],
        guardrailFindings: [String] = [],
        killSwitches: [String] = []
    ) -> DeveloperDecisionReplayEBrainSummary {
        DeveloperDecisionReplayEBrainSummary(
            lineageSummary: BASEvolutionLineageSummary(
                recordedAt: Date(),
                sessionID: sessionID,
                taskType: "decision",
                riskLevel: riskLevel,
                permitMode: permitMode,
                hostGatePercent: 55,
                thoughtFoldChecksum: "fold-\(sessionID)",
                updateTicketSummaries: updateTicketSummaries,
                guardrailFindings: guardrailFindings,
                recommendedKillSwitches: killSwitches
            )
        )
    }
}
