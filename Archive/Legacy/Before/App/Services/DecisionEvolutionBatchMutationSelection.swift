import Foundation

struct DecisionEvolutionBatchMutationSelection: Equatable, Sendable {
    let controlSurface: DecisionEvolutionControlSurface
    let selectablePresentations: [DecisionEvolutionCheckpointPresentation]
    let selectedCheckpointIDs: Set<String>
    let allowsLocalMutationActions: Bool

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
        selectedCheckpointIDs: Set<String>,
        allowsLocalMutationActions: Bool = true
    ) {
        self.controlSurface = controlSurface
        self.selectablePresentations = Self.orderedUnique(selectablePresentations)
        let validCheckpointIDs = Set(self.selectablePresentations.map(\.checkpointID))
        self.selectedCheckpointIDs = selectedCheckpointIDs.intersection(validCheckpointIDs)
        self.allowsLocalMutationActions = allowsLocalMutationActions
    }

    var selectableCheckpointIDs: Set<String> {
        Set(selectablePresentations.map(\.checkpointID))
    }

    var selectedPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectablePresentations.filter { selectedCheckpointIDs.contains($0.checkpointID) }
    }

    var selectedReviewPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations(
            matching: selectionEligibility.reviewCheckpointIDs
        )
    }

    var selectedAutomaticPresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations(
            matching: selectionEligibility.automaticCheckpointIDs
        )
    }

    var selectedLineagePresentations: [DecisionEvolutionCheckpointPresentation] {
        selectedPresentations(
            matching: selectionEligibility.lineageCheckpointIDs
        )
    }

    var selectedRestorablePresentation: DecisionEvolutionCheckpointPresentation? {
        guard let checkpointID = selectionEligibility.restorableCheckpointID else {
            return nil
        }
        return selectedPresentations.first { $0.checkpointID == checkpointID }
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
        Set(selectableEligibility.automaticCheckpointIDs)
    }

    var lineageCheckpointIDs: Set<String> {
        Set(selectableEligibility.lineageCheckpointIDs)
    }

    var approveSelectedIntent: DecisionEvolutionMutationIntent? {
        guard selectionEligibility.canApproveCheckpoints else { return nil }
        return DecisionEvolutionMutationIntentFactory.approveSelectedCheckpoints(
            presentations: selectedReviewPresentations,
            controlSurface: controlSurface
        )
    }

    var markSelectedForReviewIntent: DecisionEvolutionMutationIntent? {
        guard selectionEligibility.canMarkCheckpointsForReview else { return nil }
        return DecisionEvolutionMutationIntentFactory.markSelectedCheckpointsForReview(
            presentations: selectedAutomaticPresentations,
            controlSurface: controlSurface
        )
    }

    var clearSelectedLineageIntent: DecisionEvolutionMutationIntent? {
        guard selectionEligibility.canClearCheckpointLineage else { return nil }
        return DecisionEvolutionMutationIntentFactory.clearSelectedCheckpointLineages(
            presentations: selectedLineagePresentations,
            controlSurface: controlSurface
        )
    }

    func contains(_ checkpointID: String) -> Bool {
        selectedCheckpointIDs.contains(checkpointID)
    }

    private var selectionEligibility: DecisionEvolutionPolicyCheckpointSetEligibility {
        DecisionEvolutionPolicyEngine.checkpointSetEligibility(
            allowsLocalMutationActions: allowsLocalMutationActions,
            presentations: selectedPresentations
        )
    }

    private var selectableEligibility: DecisionEvolutionPolicyCheckpointSetEligibility {
        DecisionEvolutionPolicyEngine.checkpointSetEligibility(
            allowsLocalMutationActions: allowsLocalMutationActions,
            presentations: selectablePresentations
        )
    }

    private func selectedPresentations(
        matching checkpointIDs: [String]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        guard !checkpointIDs.isEmpty else { return [] }
        let checkpointIDSet = Set(checkpointIDs)
        return selectedPresentations.filter { checkpointIDSet.contains($0.checkpointID) }
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
