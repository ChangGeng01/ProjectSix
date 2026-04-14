import Foundation

struct DecisionEvolutionSpotlightSet: Equatable, Sendable {
    let activePresentation: DecisionEvolutionCheckpointPresentation?
    let reviewPresentation: DecisionEvolutionCheckpointPresentation?
    let remainingReviewQueue: [DecisionEvolutionCheckpointPresentation]
    let historyPresentations: [DecisionEvolutionCheckpointPresentation]

    static func build(
        controlSurface: DecisionEvolutionControlSurface,
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionSpotlightSet {
        controlSurface.spotlightSet(historyPresentations: historyPresentations)
    }
}

extension DecisionEvolutionControlSurface {
    var spotlightCheckpointIDs: Set<String> {
        Set(
            [activePresentation?.checkpointID, spotlightReviewPresentation?.checkpointID]
                .compactMap { $0 }
        )
    }

    var spotlightReviewPresentation: DecisionEvolutionCheckpointPresentation? {
        distinctReviewPresentation
            ?? (activePresentation == nil ? reviewPresentation : nil)
    }

    var remainingReviewQueuePresentations: [DecisionEvolutionCheckpointPresentation] {
        let spotlightReviewCheckpointID = spotlightReviewPresentation?.checkpointID
        return pendingReviewPresentations.filter { checkpoint in
            checkpoint.checkpointID != spotlightReviewCheckpointID
        }
    }

    func spotlightSet(
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionSpotlightSet {
        let excludedIDs = spotlightCheckpointIDs.union(
            remainingReviewQueuePresentations.map(\.checkpointID)
        )
        let remainingHistory = historyPresentations.filter { !excludedIDs.contains($0.checkpointID) }

        return DecisionEvolutionSpotlightSet(
            activePresentation: activePresentation,
            reviewPresentation: spotlightReviewPresentation,
            remainingReviewQueue: remainingReviewQueuePresentations,
            historyPresentations: remainingHistory
        )
    }

    var spotlightSet: DecisionEvolutionSpotlightSet {
        spotlightSet()
    }
}
