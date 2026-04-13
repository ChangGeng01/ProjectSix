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
        let activePresentation = controlSurface.activePresentation
        let reviewPresentation = controlSurface.spotlightReviewPresentation
        let spotlightIDs = Set(
            [activePresentation?.checkpointID, reviewPresentation?.checkpointID]
                .compactMap { $0 }
        )

        let remainingReviewQueue = controlSurface.pendingReviewQueue
            .map(\.presentation)
            .filter { checkpoint in
                guard let reviewPresentation else { return true }
                return checkpoint.checkpointID != reviewPresentation.checkpointID
            }

        let queueIDs = Set(remainingReviewQueue.map(\.checkpointID))
        let excludedIDs = spotlightIDs.union(queueIDs)
        let remainingHistory = historyPresentations.filter { !excludedIDs.contains($0.checkpointID) }

        return DecisionEvolutionSpotlightSet(
            activePresentation: activePresentation,
            reviewPresentation: reviewPresentation,
            remainingReviewQueue: remainingReviewQueue,
            historyPresentations: remainingHistory
        )
    }
}

extension DecisionEvolutionControlSurface {
    var spotlightReviewPresentation: DecisionEvolutionCheckpointPresentation? {
        distinctReviewPresentation
            ?? (activePresentation == nil ? reviewPresentation : nil)
    }

    var spotlightSet: DecisionEvolutionSpotlightSet {
        DecisionEvolutionSpotlightSet.build(controlSurface: self)
    }
}
