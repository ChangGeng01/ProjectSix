import Foundation

enum DecisionEvolutionPilotGuidedActionRoute: Equatable, Sendable {
    case mutation(DecisionEvolutionMutationIntent)
    case navigation(DecisionEvolutionNavigationDestination)
}

struct DecisionEvolutionPilotGuidedAction: Equatable, Sendable {
    let title: String
    let detail: String
    let actionTitle: String
    let route: DecisionEvolutionPilotGuidedActionRoute
}

struct DecisionEvolutionPilotControlSnapshot: Equatable, Sendable {
    let interactionMode: DecisionEvolutionControlInteractionMode
    let allowsLocalMutationActions: Bool
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let pendingReviewLineageCount: Int
    let mutationIntents: [DecisionEvolutionMutationIntent]
    let restoreActiveIntent: DecisionEvolutionMutationIntent?
    let rollbackActiveIntent: DecisionEvolutionMutationIntent?
    let approveQueueIntent: DecisionEvolutionMutationIntent?
    let clearReviewLineageIntent: DecisionEvolutionMutationIntent?
    let reviewAuditFindings: [String]
    let recommendedKillSwitches: [String]
    let guidedAction: DecisionEvolutionPilotGuidedAction?

    static func build(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionPilotControlSnapshot {
        let restoreActiveIntent = DecisionEvolutionMutationIntentFactory.restoreActiveCheckpoint(
            controlSurface: controlSurface
        )
        let rollbackActiveIntent = DecisionEvolutionMutationIntentFactory.rollbackActiveCheckpoint(
            controlSurface: controlSurface
        )
        let approveQueueIntent = DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
            controlSurface: controlSurface
        )
        let clearReviewLineageIntent = DecisionEvolutionMutationIntentFactory.clearPendingReviewLineage(
            controlSurface: controlSurface
        )
        let allowsLocalMutationActions = surfaceContract.allowsMutations
        let resolvedPendingReviewCount = releaseSummary?.pendingReviewCount ?? controlSurface.pendingReviewCount
        let resolvedRollbackReadyCount = releaseSummary?.rollbackReadyCount ?? controlSurface.rollbackReadyCount
        let resolvedRecommendedKillSwitches = releaseSummary?.recommendedKillSwitches
            ?? controlSurface.reviewKillSwitches
        let resolvedActiveKillSwitches = releaseSummary?.activeKillSwitches
            ?? controlSurface.activeKillSwitches
        let resolvedCanRestoreActiveCheckpoint = releaseSummary?.canRestoreActiveCheckpoint
            ?? (controlSurface.activePresentation?.applyReady == true)

        return DecisionEvolutionPilotControlSnapshot(
            interactionMode: surfaceContract.interactionMode,
            allowsLocalMutationActions: allowsLocalMutationActions,
            pendingReviewCount: resolvedPendingReviewCount,
            rollbackReadyCount: resolvedRollbackReadyCount,
            pendingReviewLineageCount: controlSurface.pendingReviewLineagePresentations.count,
            mutationIntents: [
                restoreActiveIntent,
                rollbackActiveIntent,
                approveQueueIntent,
                clearReviewLineageIntent
            ].compactMap { $0 },
            restoreActiveIntent: restoreActiveIntent,
            rollbackActiveIntent: rollbackActiveIntent,
            approveQueueIntent: approveQueueIntent,
            clearReviewLineageIntent: clearReviewLineageIntent,
            reviewAuditFindings: controlSurface.reviewAuditFindings,
            recommendedKillSwitches: resolvedRecommendedKillSwitches,
            guidedAction: guidedAction(
                pendingReviewCount: resolvedPendingReviewCount,
                activeKillSwitches: resolvedActiveKillSwitches,
                canRestoreActiveCheckpoint: resolvedCanRestoreActiveCheckpoint,
                navigationOptions: navigationOptions,
                allowsLocalMutationActions: allowsLocalMutationActions,
                routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                approveQueueIntent: approveQueueIntent
            )
        )
    }

    private static func guidedAction(
        pendingReviewCount: Int,
        activeKillSwitches: [String],
        canRestoreActiveCheckpoint: Bool,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        allowsLocalMutationActions: Bool,
        routesMutationsToControlCenter: Bool,
        approveQueueIntent: DecisionEvolutionMutationIntent?
    ) -> DecisionEvolutionPilotGuidedAction? {
        if pendingReviewCount > 0 {
            if allowsLocalMutationActions, let approveQueueIntent {
                return DecisionEvolutionPilotGuidedAction(
                    title: "Pending review is the next blocker",
                    detail: "Clear or approve the review queue before treating this release path as ready.",
                    actionTitle: "Approve review queue",
                    route: .mutation(approveQueueIntent)
                )
            }

            return navigationGuidedAction(
                title: "Pending review is the next blocker",
                detail: allowsLocalMutationActions
                    ? "Open the checkpoint workspace and work the queue before widening rollout."
                    : "This surface stays read-first. Open Evolution Control and work the queue there before widening rollout.",
                navigationOptions: navigationOptions,
                routesMutationsToControlCenter: routesMutationsToControlCenter
            )
        }

        if !activeKillSwitches.isEmpty {
            return navigationGuidedAction(
                title: "Kill switches are holding the release path",
                detail: "Inspect the active checkpoint and its guardrails before trying to widen rollout.",
                navigationOptions: navigationOptions,
                routesMutationsToControlCenter: routesMutationsToControlCenter
            )
        }

        if !canRestoreActiveCheckpoint {
            return navigationGuidedAction(
                title: "The active path is not restorable yet",
                detail: "Open the control surface and recover a checkpoint with a valid brain-state snapshot.",
                navigationOptions: navigationOptions,
                routesMutationsToControlCenter: routesMutationsToControlCenter
            )
        }

        return nil
    }

    private static func navigationGuidedAction(
        title: String,
        detail: String,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool
    ) -> DecisionEvolutionPilotGuidedAction? {
        guard let destination = navigationOptions.preferredDestination else { return nil }

        return DecisionEvolutionPilotGuidedAction(
            title: title,
            detail: detail,
            actionTitle: destination.actionTitle(
                routesMutationsToControlCenter: routesMutationsToControlCenter
            ),
            route: .navigation(destination)
        )
    }
}
