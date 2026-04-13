import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionMutationIntentTests: XCTestCase {
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
