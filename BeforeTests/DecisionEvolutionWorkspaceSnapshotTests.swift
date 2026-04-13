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
            reviewCheckpoint: reviewHead,
            pendingReviewQueue: [reviewHead, reviewTail],
            latestPersistedLineage: nil
        )
        let releaseSummary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Watching the pending review queue",
            reasons: ["1 checkpoint still requires review."],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 2,
            canRestoreActiveCheckpoint: true,
            canRollbackActiveCheckpoint: true,
            activeCheckpointID: active.checkpointID,
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
