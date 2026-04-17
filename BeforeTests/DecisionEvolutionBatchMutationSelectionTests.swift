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

    func testSelectionPresentationBuildsSharedSummaryAndTargetsLines() {
        let now = Date(timeIntervalSince1970: 100)
        let active = makePresentation(
            checkpointID: "checkpoint-active",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: false,
            applyReady: true
        )
        let review = makePresentation(
            checkpointID: "checkpoint-review",
            createdAt: now.addingTimeInterval(20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            applyReady: false
        )
        let selection = DecisionEvolutionBatchMutationSelection(
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            selectablePresentations: [active, review],
            selectedCheckpointIDs: ["checkpoint-active", "checkpoint-review"]
        )

        let presentation = DecisionEvolutionBatchMutationSelectionPresentationSupport.build(
            selection: selection,
            targetsPrefix: "Targets"
        )

        XCTAssertEqual(
            presentation.summaryLine,
            "2 selected • 1 review • 1 automatic • 1 lineage-backed"
        )
        XCTAssertEqual(
            presentation.summaryLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "2 selected",
                "1 review",
                "1 automatic",
                "1 lineage-backed"
            ])
        )
        XCTAssertTrue(presentation.usesAccentTone)
        XCTAssertEqual(
            presentation.targetsLine,
            "Targets: checkpoint-active • checkpoint-review"
        )
        XCTAssertEqual(
            presentation.targetsLine,
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Targets",
                values: ["checkpoint-active", "checkpoint-review"]
            )
        )

        let emptyPresentation = DecisionEvolutionBatchMutationSelectionPresentationSupport.build(
            selection: DecisionEvolutionBatchMutationSelection(
                controlSurface: selection.controlSurface,
                selectablePresentations: [active, review],
                selectedCheckpointIDs: []
            ),
            targetsPrefix: "Targets"
        )
        XCTAssertEqual(
            emptyPresentation.summaryLine,
            "No checkpoints are selected yet. Pick a slice of the control surface, then run guarded batch mutations from here."
        )
        XCTAssertFalse(emptyPresentation.usesAccentTone)
        XCTAssertNil(emptyPresentation.targetsLine)
    }

    func testOrderedSelectablePresentationsKeepSurfacePriorityAndDeduplicate() {
        let now = Date(timeIntervalSince1970: 100)
        let active = makePresentation(
            checkpointID: "checkpoint-active",
            createdAt: now,
            approvalState: .automatic,
            hasLineage: false,
            applyReady: true
        )
        let review = makePresentation(
            checkpointID: "checkpoint-review",
            createdAt: now.addingTimeInterval(20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            applyReady: false
        )
        let queueTail = makePresentation(
            checkpointID: "checkpoint-queue-tail",
            createdAt: now.addingTimeInterval(40),
            approvalState: .reviewSuggested,
            hasLineage: false,
            applyReady: false
        )
        let history = makePresentation(
            checkpointID: "checkpoint-history",
            createdAt: now.addingTimeInterval(60),
            approvalState: .automatic,
            hasLineage: true,
            applyReady: false
        )

        let ordered = DecisionEvolutionBatchMutationSelection.orderedSelectablePresentations(
            activePresentation: active,
            reviewPresentation: review,
            remainingReviewQueue: [review, queueTail],
            historyPresentations: [history, active]
        )

        XCTAssertEqual(
            ordered.map(\.checkpointID),
            ["checkpoint-active", "checkpoint-review", "checkpoint-queue-tail", "checkpoint-history"]
        )
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
