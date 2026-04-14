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
            let contextPreferred = lineages.dropFirst().reduce(lineages[0]) { best, candidate in
                if isPreferredCheckpointLineage(
                    candidate,
                    over: best,
                    matching: resolvedContext
                ) {
                    return candidate
                }

                if isPreferredCheckpointLineage(
                    best,
                    over: candidate,
                    matching: resolvedContext
                ) {
                    return best
                }

                return candidate.checkpointID > best.checkpointID ? candidate : best
            }

            return contextPreferred
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

    private func isPreferredCheckpointLineage(
        _ lhs: DecisionEvolutionLineageSnapshot,
        over rhs: DecisionEvolutionLineageSnapshot,
        matching context: DecisionTestingCheckpointSelectionContext
    ) -> Bool {
        let lhsModeScore = lhs.mode == context.mode ? 1 : 0
        let rhsModeScore = rhs.mode == context.mode ? 1 : 0
        if lhsModeScore != rhsModeScore {
            return lhsModeScore > rhsModeScore
        }

        if let contextSource = context.source {
            let lhsSourceScore = lhs.eBrain.source == contextSource ? 1 : 0
            let rhsSourceScore = rhs.eBrain.source == contextSource ? 1 : 0
            if lhsSourceScore != rhsSourceScore {
                return lhsSourceScore > rhsSourceScore
            }
        }

        let lhsDistance = abs(lhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        let rhsDistance = abs(rhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        if lhs.eBrain.recordedAt != rhs.eBrain.recordedAt {
            return lhs.eBrain.recordedAt > rhs.eBrain.recordedAt
        }

        return lhs.checkpointID > rhs.checkpointID
    }
}
