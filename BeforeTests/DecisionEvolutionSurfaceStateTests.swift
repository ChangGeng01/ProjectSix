import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionSurfaceStateTests: XCTestCase {
    func testCheckpointApplyReadyOnlyRequiresRestorableSnapshot() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "apply-only",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: false,
            hasBrainStateSnapshot: true,
            diffSummary: ["restorable snapshot"],
            eBrain: nil,
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "answer"
        )

        XCTAssertTrue(snapshot.applyReady)
    }

    func testSurfaceStateBuildSharesWorkspaceOperatorAndAttentionFacts() {
        let now = Date(timeIntervalSince1970: 100)
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: now.addingTimeInterval(30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil
        )

        let state = DecisionEvolutionSurfaceState.build(
            contract: .history,
            controlSurface: controlSurface,
            historyPresentations: [active.presentation, review.presentation]
        )

        XCTAssertEqual(state.contract.kind, .history)
        XCTAssertEqual(state.workspace.controlSurface, controlSurface)
        XCTAssertEqual(state.workspace.activePresentation?.checkpointID, "active-1")
        XCTAssertEqual(state.workspace.reviewPresentation?.checkpointID, "review-1")
        XCTAssertEqual(state.operatorSnapshot.pendingReviewCount, 1)
        XCTAssertEqual(state.operatorSnapshot.reviewCheckpointID, "review-1")
        XCTAssertEqual(state.attentionSignal.severity, .blocked)
        XCTAssertEqual(state.attentionSignal.killSwitches, ["kill-review-1"])
    }

    func testSurfaceStateResolvesRollbackReadinessFromRestorablePreviousCheckpoint() {
        let now = Date(timeIntervalSince1970: 100)
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: now.addingTimeInterval(30),
            approvalState: .reviewSuggested,
            hasLineage: true
        )

        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["active-1", "previous-active-1"]
        )

        XCTAssertTrue(controlSurface.activePresentation?.rollbackReady == true)
        XCTAssertFalse(controlSurface.reviewPresentation?.rollbackReady == true)
        XCTAssertEqual(controlSurface.rollbackReadyCount, 0)
        XCTAssertFalse(controlSurface.pendingReviewPresentations.first?.rollbackReady == true)
    }

    func testControlSurfaceResolvesHistoryCheckpointRollbackReadiness() {
        let historyCheckpoint = DecisionEvolutionCheckpoint(
            id: "history-1",
            createdAt: Date(timeIntervalSince1970: 200),
            fingerprint: "history-1",
            previousCheckpointID: "previous-history-1",
            mode: .mirror,
            source: .explicitRefresh,
            identityRole: .reflectiveWitness,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .watch,
            diffSummary: ["history checkpoint"],
            approvalState: .automatic,
            rollbackReady: true,
            brainStateSnapshot: nil,
            lineageSummary: nil
        )

        let unresolvedSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: []
        )
        let resolvedSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-history-1"]
        )

        XCTAssertFalse(
            unresolvedSurface.resolvedPresentation(for: historyCheckpoint).rollbackReady
        )
        XCTAssertTrue(
            resolvedSurface.resolvedPresentation(for: historyCheckpoint).rollbackReady
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
            hostGatePercent: 72,
            thoughtFoldChecksum: "fold-\(checkpointID)",
            updateTicketSummaries: ["ticket-\(checkpointID)"],
            guardrailFindings: ["audit-\(checkpointID)"],
            recommendedKillSwitches: ["kill-\(checkpointID)"]
        )
    }
}
