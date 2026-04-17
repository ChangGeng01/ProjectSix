import Foundation

struct DecisionEvolutionBatchMutationSelection: Equatable, Sendable {
    let controlSurface: DecisionEvolutionControlSurface
    let selectablePresentations: [DecisionEvolutionCheckpointPresentation]
    let selectedCheckpointIDs: Set<String>

    static func orderedSelectablePresentations(
        activePresentation: DecisionEvolutionCheckpointPresentation?,
        reviewPresentation: DecisionEvolutionCheckpointPresentation?,
        remainingReviewQueue: [DecisionEvolutionCheckpointPresentation],
        historyPresentations: [DecisionEvolutionCheckpointPresentation]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        orderedUnique(
            [activePresentation, reviewPresentation].compactMap { $0 }
            + remainingReviewQueue
            + historyPresentations
        )
    }

    init(
        controlSurface: DecisionEvolutionControlSurface,
        selectablePresentations: [DecisionEvolutionCheckpointPresentation],
        selectedCheckpointIDs: Set<String>
    ) {
        self.controlSurface = controlSurface
        self.selectablePresentations = Self.orderedUnique(selectablePresentations)
        let validCheckpointIDs = Set(self.selectablePresentations.map(\.checkpointID))
        self.selectedCheckpointIDs = selectedCheckpointIDs.intersection(validCheckpointIDs)
    }

    var selectableCheckpointIDs: Set<String> {
        Set(selectablePresentations.map(\.checkpointID))
    }

    var selectedPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectablePresentations.filter { selectedCheckpointIDs.contains($0.checkpointID) }
    }

    var selectedReviewPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations.filter { $0.approvalState == .reviewSuggested }
    }

    var selectedAutomaticPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations.filter { $0.approvalState == .automatic }
    }

    var selectedLineagePresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations.filter(\.hasLineage)
    }

    var selectedRestorablePresentation: DecisionEvolutionCheckpointPresentation? {
        guard selectedPresentations.count == 1 else { return nil }
        guard let presentation = selectedPresentations.first, presentation.applyReady else {
            return nil
        }
        return presentation
    }

    var selectedCount: Int {
        selectedPresentations.count
    }

    var hasSelection: Bool {
        !selectedPresentations.isEmpty
    }

    var reviewQueueCheckpointIDs: Set<String> {
        Set(controlSurface.pendingReviewPresentations.map(\.checkpointID))
    }

    var automaticCheckpointIDs: Set<String> {
        Set(selectablePresentations.filter { $0.approvalState == .automatic }.map(\.checkpointID))
    }

    var lineageCheckpointIDs: Set<String> {
        Set(selectablePresentations.filter(\.hasLineage).map(\.checkpointID))
    }

    var approveSelectedIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.approveSelectedCheckpoints(
            presentations: selectedReviewPresentations,
            controlSurface: controlSurface
        )
    }

    var markSelectedForReviewIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.markSelectedCheckpointsForReview(
            presentations: selectedAutomaticPresentations,
            controlSurface: controlSurface
        )
    }

    var clearSelectedLineageIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.clearSelectedCheckpointLineages(
            presentations: selectedLineagePresentations,
            controlSurface: controlSurface
        )
    }

    func contains(_ checkpointID: String) -> Bool {
        selectedCheckpointIDs.contains(checkpointID)
    }

    private static func orderedUnique(
        _ presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        presentations.reduce(into: [DecisionEvolutionCheckpointPresentation]()) { ordered, presentation in
            guard !ordered.contains(where: { $0.checkpointID == presentation.checkpointID }) else {
                return
            }
            ordered.append(presentation)
        }
    }
}
