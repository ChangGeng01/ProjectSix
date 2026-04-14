import Foundation

struct DecisionEvolutionWorkspaceFacts: Equatable, Sendable {
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let canRestoreActiveCheckpoint: Bool
    let canRollbackActiveCheckpoint: Bool
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let killSwitches: [String]

    var hasPendingReview: Bool {
        pendingReviewCount > 0
    }

    var hasRecommendedKillSwitches: Bool {
        !recommendedKillSwitches.isEmpty
    }

    var hasActiveKillSwitches: Bool {
        !activeKillSwitches.isEmpty
    }
}

struct DecisionEvolutionRuntimeSpotlight: Equatable, Sendable {
    let roleTitle: String
    let detailText: String
}

struct DecisionEvolutionRecoveryPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor?
    let availabilityText: String
    let emptyMessage: String
}

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

    var facts: DecisionEvolutionWorkspaceFacts {
        DecisionEvolutionWorkspaceFacts(
            pendingReviewCount: releaseSummary?.pendingReviewCount ?? controlSurface.pendingReviewCount,
            rollbackReadyCount: releaseSummary?.rollbackReadyCount ?? controlSurface.rollbackReadyCount,
            canRestoreActiveCheckpoint: releaseSummary?.canRestoreActiveCheckpoint ?? (controlSurface.activePresentation?.applyReady == true),
            canRollbackActiveCheckpoint: releaseSummary?.canRollbackActiveCheckpoint ?? controlSurface.canRollbackActiveCheckpoint,
            activeKillSwitches: releaseSummary?.activeKillSwitches ?? controlSurface.activeCheckpoint?.activeKillSwitches ?? [],
            recommendedKillSwitches: releaseSummary?.recommendedKillSwitches ?? controlSurface.queueKillSwitches,
            killSwitches: releaseSummary?.killSwitches ?? Self.orderedUnique(
                (releaseSummary?.activeKillSwitches ?? controlSurface.activeCheckpoint?.activeKillSwitches ?? [])
                + (releaseSummary?.recommendedKillSwitches ?? controlSurface.queueKillSwitches)
            )
        )
    }

    var effectivePendingReviewCount: Int {
        facts.pendingReviewCount
    }

    var effectiveRollbackReadyCount: Int {
        facts.rollbackReadyCount
    }

    var effectiveCanRestoreActiveCheckpoint: Bool {
        facts.canRestoreActiveCheckpoint
    }

    var effectiveCanRollbackActiveCheckpoint: Bool {
        facts.canRollbackActiveCheckpoint
    }

    var effectiveActiveKillSwitches: [String] {
        facts.activeKillSwitches
    }

    var effectiveRecommendedKillSwitches: [String] {
        facts.recommendedKillSwitches
    }

    var effectiveKillSwitches: [String] {
        facts.killSwitches
    }

    func recoveryPresentation(hasCurrentBrainState: Bool) -> DecisionEvolutionRecoveryPresentation {
        let hasRecoveredLineage = activePresentation?.hasLineage == true
            || reviewPresentation?.hasLineage == true
        let availabilityText: String
        if hasCurrentBrainState {
            availabilityText = "Rollback ready"
        } else if controlSurface.hasAnyCheckpoint {
            availabilityText = "Live brain state is unavailable right now, but persisted checkpoints remain reviewable and restorable from local lineage."
        } else {
            availabilityText = "Evolution checkpoints appear after the current brain is loaded."
        }

        let emptyMessage: String
        if hasCurrentBrainState {
            emptyMessage = "Evolution checkpoints will surface here after the current brain is loaded."
        } else if controlSurface.hasAnyCheckpoint {
            emptyMessage = "Recovered checkpoints remain visible here even without a live current brain."
        } else {
            emptyMessage = "Evolution checkpoints appear after the current brain is loaded."
        }

        return DecisionEvolutionRecoveryPresentation(
            sourceDescriptor: hasRecoveredLineage ? .checkpointRecoveryWorkspace : nil,
            availabilityText: availabilityText,
            emptyMessage: emptyMessage
        )
    }

    func runtimeSpotlight(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> DecisionEvolutionRuntimeSpotlight? {
        let spotlightPresentation = activePresentation ?? reviewPresentation
        guard let spotlightPresentation else { return nil }

        let roleTitle = activePresentation?.checkpointID == spotlightPresentation.checkpointID
            ? "Active"
            : "Review head"
        let applyTitle = spotlightPresentation.applyReady
            ? "Apply ready"
            : "Apply unavailable"
        let activeSourceDetail = if roleTitle == "Active",
                                    releaseSummary.activeCheckpointSource != .none {
            " • \(releaseSummary.activeCheckpointSource.title)"
        } else {
            ""
        }

        return DecisionEvolutionRuntimeSpotlight(
            roleTitle: roleTitle,
            detailText: "\(roleTitle) \(spotlightPresentation.checkpointID)\(activeSourceDetail) • \(spotlightPresentation.approvalStateTitle) • \(applyTitle)"
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}
