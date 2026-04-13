import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionAttentionSignalTests: XCTestCase {
    func testAttentionSignalPrioritizesQueueKillSwitches() {
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let signal = DecisionEvolutionAttentionSignal.build(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            )
        )

        XCTAssertEqual(signal.severity, .blocked)
        XCTAssertEqual(signal.badgeValue, "!")
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
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: reviewA,
                pendingReviewQueue: [reviewA, reviewB],
                latestPersistedLineage: nil
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
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: active,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil,
                restorableCheckpointIDs: ["active-1", "previous-active-1"]
            )
        )

        XCTAssertEqual(signal.severity, .rollbackWatch)
        XCTAssertEqual(signal.badgeValue, "↺")
        XCTAssertTrue(signal.rollbackReady)
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
