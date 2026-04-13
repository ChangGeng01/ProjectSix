import Foundation

struct DecisionEvolutionWorkspaceSnapshot: Equatable, Sendable {
    let controlSurface: DecisionEvolutionControlSurface
    let releaseSummary: DecisionSystemReleaseControlSummary?
    let spotlightSet: DecisionEvolutionSpotlightSet

    static func build(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionWorkspaceSnapshot {
        DecisionEvolutionWorkspaceSnapshot(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            spotlightSet: DecisionEvolutionSpotlightSet.build(
                controlSurface: controlSurface,
                historyPresentations: historyPresentations
            )
        )
    }

    var activePresentation: DecisionEvolutionCheckpointPresentation? {
        spotlightSet.activePresentation
    }

    var reviewPresentation: DecisionEvolutionCheckpointPresentation? {
        spotlightSet.reviewPresentation
    }

    var remainingReviewQueue: [DecisionEvolutionCheckpointPresentation] {
        spotlightSet.remainingReviewQueue
    }

    var historyPresentations: [DecisionEvolutionCheckpointPresentation] {
        spotlightSet.historyPresentations
    }

    var spotlightedPendingReviewCount: Int {
        reviewPresentation == nil ? 0 : 1
    }

    var queuedPendingReviewCount: Int {
        remainingReviewQueue.count
    }

    var totalPendingReviewCount: Int {
        controlSurface.pendingReviewCount
    }
}
