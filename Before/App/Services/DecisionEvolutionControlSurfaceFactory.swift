import Foundation

enum DecisionEvolutionControlSurfaceFactory {
    static func build(
        activeCheckpointHint: DecisionReviewCheckpointSnapshot?,
        latestAutomaticLineage: DecisionEvolutionLineageSnapshot? = nil,
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot],
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    ) -> DecisionEvolutionControlSurface {
        let pendingReviewQueue = pendingReviewCheckpoints.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.checkpointID > rhs.checkpointID
        }

        let resolvedActiveCheckpoint = activeCheckpointHint
            ?? latestAutomaticLineage.map(DecisionReviewCheckpointSnapshot.init(lineage:))

        return DecisionEvolutionControlSurface(
            activeCheckpoint: resolvedActiveCheckpoint,
            reviewCheckpoint: pendingReviewQueue.first,
            pendingReviewQueue: pendingReviewQueue,
            latestPersistedLineage: latestPersistedLineage
        )
    }
}
