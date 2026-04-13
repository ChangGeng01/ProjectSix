import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionBatchMutationSelectionTests: XCTestCase {
    func testSelectionBuildFiltersInvalidIDsAndExposesAvailableMutations() {
        let now = Date(timeIntervalSince1970: 100)
        let active = makePresentation(
            checkpointID: "checkpoint-active",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: true,
            applyReady: true
        )
        let review = makePresentation(
            checkpointID: "checkpoint-review",
            createdAt: now.addingTimeInterval(20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            applyReady: false
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: nil,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil
        )

        let selection = DecisionEvolutionBatchMutationSelection(
            controlSurface: controlSurface,
            selectablePresentations: [active, review],
            selectedCheckpointIDs: ["checkpoint-active", "checkpoint-review", "missing"]
        )

        XCTAssertEqual(selection.selectedCount, 2)
        XCTAssertTrue(selection.contains("checkpoint-active"))
        XCTAssertTrue(selection.contains("checkpoint-review"))
        XCTAssertFalse(selection.contains("missing"))
        XCTAssertNotNil(selection.markSelectedForReviewIntent)
        XCTAssertNotNil(selection.approveSelectedIntent)
        XCTAssertNotNil(selection.clearSelectedLineageIntent)
        XCTAssertNil(selection.selectedRestorablePresentation)
    }

    private func makePresentation(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool,
        applyReady: Bool
    ) -> DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(
            snapshot: DecisionReviewCheckpointSnapshot(
                checkpointID: checkpointID,
                previousCheckpointID: nil,
                createdAt: createdAt,
                mode: .quick,
                approvalState: approvalState,
                rollbackReady: false,
                hasBrainStateSnapshot: applyReady,
                diffSummary: ["\(checkpointID) diff"],
                eBrain: hasLineage
                    ? DeveloperDecisionReplayEBrainSummary(
                        lineageSummary: BASEvolutionLineageSummary(
                            recordedAt: createdAt,
                            sessionID: "session-\(checkpointID)",
                            taskType: "decision",
                            riskLevel: "medium",
                            permitMode: "compare",
                            hostGatePercent: 50,
                            thoughtFoldChecksum: "fold-\(checkpointID)",
                            updateTicketSummaries: ["ticket-\(checkpointID)"],
                            guardrailFindings: [],
                            recommendedKillSwitches: []
                        )
                    )
                    : nil
            )
        )
    }
}
