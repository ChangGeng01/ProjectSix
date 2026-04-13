import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionSpotlightSetTests: XCTestCase {
    func testSpotlightSetSeparatesActiveReviewQueueAndHistory() {
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
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead, reviewTail],
            latestPersistedLineage: nil
        )

        let spotlightSet = DecisionEvolutionSpotlightSet.build(
            controlSurface: surface,
            historyPresentations: [active.presentation, reviewHead.presentation, reviewTail.presentation, history.presentation]
        )

        XCTAssertEqual(spotlightSet.activePresentation?.checkpointID, "active-1")
        XCTAssertEqual(spotlightSet.reviewPresentation?.checkpointID, "review-2")
        XCTAssertEqual(spotlightSet.remainingReviewQueue.map(\.checkpointID), ["review-1"])
        XCTAssertEqual(spotlightSet.historyPresentations.map(\.checkpointID), ["history-1"])
    }

    func testSpotlightSetUsesReviewHeadWhenNoActiveCheckpointExists() {
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

        let surface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead, reviewTail],
            latestPersistedLineage: nil
        )

        let spotlightSet = DecisionEvolutionSpotlightSet.build(
            controlSurface: surface,
            historyPresentations: [reviewHead.presentation, reviewTail.presentation]
        )

        XCTAssertNil(spotlightSet.activePresentation)
        XCTAssertEqual(spotlightSet.reviewPresentation?.checkpointID, "review-2")
        XCTAssertEqual(spotlightSet.remainingReviewQueue.map(\.checkpointID), ["review-1"])
        XCTAssertTrue(spotlightSet.historyPresentations.isEmpty)
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
