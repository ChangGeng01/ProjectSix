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
                reviewCheckpoint: review,
                pendingReviewQueue: [review],
                latestPersistedLineage: nil
            ),
            releaseSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Watching the pending review queue",
                reasons: ["1 checkpoint still requires review."],
                killSwitches: ["host-write"],
                pendingReviewCount: 1,
                rollbackReadyCount: 2,
                canRestoreActiveCheckpoint: true,
                canRollbackActiveCheckpoint: true,
                activeCheckpointID: "active-1",
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
        XCTAssertEqual(snapshot.rollbackReadyCount, 0)
        XCTAssertEqual(snapshot.activeCheckpointID, "active-1")
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(snapshot.killSwitches, ["host-write"])
        XCTAssertEqual(snapshot.surfaceTitle, "Evolution Control")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.mutationHub.operatorHeadline)
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
        XCTAssertEqual(snapshot.headline, "Pending review remains visible from this read-first surface")
        XCTAssertEqual(snapshot.primaryReason, "1 checkpoint(s) still require review before the release path is clean.")
        XCTAssertEqual(snapshot.pendingReviewCount, 1)
        XCTAssertEqual(snapshot.rollbackReadyCount, 0)
        XCTAssertNil(snapshot.activeCheckpointID)
        XCTAssertEqual(snapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(snapshot.killSwitches, ["kill-review-1"])
        XCTAssertEqual(snapshot.surfaceTitle, "History workbench")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.observeAndRoute.operatorHeadline)
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
        XCTAssertEqual(snapshot.killSwitches, ["kill-review-1"])
        XCTAssertEqual(snapshot.surfaceTitle, "Evolution Control")
        XCTAssertEqual(snapshot.operatorHeadline, DecisionEvolutionControlInteractionMode.mutationHub.operatorHeadline)
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
