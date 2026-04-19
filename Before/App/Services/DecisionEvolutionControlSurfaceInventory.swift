import Foundation

struct DecisionEvolutionControlSurfaceInventory: Equatable, Sendable {
    let pendingReviewQueue: [DecisionReviewCheckpointSnapshot]
    let persistedLineages: [DecisionEvolutionLineageSnapshot]
    let activeCheckpoint: DecisionReviewCheckpointSnapshot?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let restorableCheckpointIDs: Set<String>

    init(
        pendingReviewQueue: [DecisionReviewCheckpointSnapshot],
        persistedLineages: [DecisionEvolutionLineageSnapshot],
        activeCheckpoint: DecisionReviewCheckpointSnapshot?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource? = nil,
        restorableCheckpointIDs: Set<String>
    ) {
        self.pendingReviewQueue = pendingReviewQueue
        self.persistedLineages = persistedLineages
        self.activeCheckpoint = activeCheckpoint
        self.activeCheckpointSource = activeCheckpointSource ?? {
            if activeCheckpoint != nil {
                return .pinnedHint
            }

            if persistedLineages.contains(where: { $0.approvalState == .automatic }) {
                return .automaticFallback
            }

            return .none
        }()
        self.restorableCheckpointIDs = restorableCheckpointIDs
    }

    func buildControlSurface(
        preferredCheckpointSelectionContext: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionControlSurface {
        DecisionEvolutionControlSurfaceFactory.build(
            activeCheckpointHint: activeCheckpoint,
            activeCheckpointSource: activeCheckpointSource,
            latestAutomaticLineage: latestAutomaticLineage(
                matching: preferredCheckpointSelectionContext
            ),
            pendingReviewCheckpoints: pendingReviewQueue,
            latestPersistedLineage: latestPersistedLineage(
                matching: preferredCheckpointSelectionContext
            ),
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }

    func latestPersistedLineage(
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        selectedCheckpointLineage(
            in: persistedLineages,
            matching: context
        )
    }

    func latestAutomaticLineage(
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        selectedCheckpointLineage(
            in: persistedLineages.filter { $0.approvalState == .automatic },
            matching: context
        )
    }

    func selectedCheckpointLineage(
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        selectedCheckpointLineage(
            in: persistedLineages,
            matching: context
        )
    }

    func selectedCheckpointLineage(
        in lineages: [DecisionEvolutionLineageSnapshot],
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        guard !lineages.isEmpty else {
            return nil
        }

        if let resolvedContext = context {
            return DecisionEvolutionRuntimeAnchorResolver.preferredLineage(
                in: lineages,
                matching: resolvedContext
            )
        }

        return lineages.reduce(lineages[0]) { best, candidate in
            if candidate.eBrain.recordedAt != best.eBrain.recordedAt {
                return candidate.eBrain.recordedAt > best.eBrain.recordedAt ? candidate : best
            }

            if candidate.createdAt != best.createdAt {
                return candidate.createdAt > best.createdAt ? candidate : best
            }

            return candidate.checkpointID > best.checkpointID ? candidate : best
        }
    }
}
