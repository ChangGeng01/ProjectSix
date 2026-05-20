import Foundation

enum DecisionEvolutionControlSurfaceFactory {
    static func build(
        activeCheckpointHint: DecisionReviewCheckpointSnapshot?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource? = nil,
        latestAutomaticLineage: DecisionEvolutionLineageSnapshot? = nil,
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot],
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?,
        restorableCheckpointIDs: Set<String> = []
    ) -> DecisionEvolutionControlSurface {
        let slots = DecisionEvolutionControlSurface.resolveCheckpointSlots(
            activeCheckpointHint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            latestAutomaticLineage: latestAutomaticLineage,
            pendingReviewCheckpoints: pendingReviewCheckpoints
        )

        return DecisionEvolutionControlSurface(
            activeCheckpoint: slots.activeCheckpoint,
            activeCheckpointSource: slots.activeCheckpointSource,
            reviewCheckpoint: slots.reviewCheckpoint,
            pendingReviewQueue: slots.pendingReviewQueue,
            latestPersistedLineage: latestPersistedLineage,
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }
}
