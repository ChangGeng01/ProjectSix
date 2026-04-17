import Foundation

enum DecisionEvolutionPilotControlPresentationSupport {
    static let headerTitle = "Evolution pilot controls"
    static let guidedActionSectionTitle = "Recommended next step"
    static let restoreActiveTitle = DecisionEvolutionMutationHubPresentationSupport.restoreActivePathTitle
    static let rollbackActiveTitle = DecisionEvolutionMutationHubPresentationSupport.rollbackActivePathTitle
    static let approveQueueTitle = DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle
    static let clearQueueLineageTitle = DecisionEvolutionMutationHubPresentationSupport.clearQueueLineageTitle

    static func headerDetail(
        allowsLocalMutationActions: Bool
    ) -> String {
        allowsLocalMutationActions
            ? DecisionEvolutionMutationRoutingPresentationSupport.mutationHubPilotDetail
            : DecisionEvolutionMutationRoutingPresentationSupport.routedPilotDetail()
    }

    static func embeddedReleaseSummaryMode(
        allowsLocalMutationActions: Bool
    ) -> DecisionEvolutionReleaseSummaryPresentationMode {
        allowsLocalMutationActions ? .mutationHub : .surface
    }

    static func pendingReviewLineageNotice(
        pendingReviewLineageCount: Int,
        hasReleaseSummary: Bool
    ) -> String? {
        DecisionEvolutionLineagePresentationSupport.pendingReviewLineageNotice(
            pendingReviewLineageCount: pendingReviewLineageCount,
            hasReleaseSummary: hasReleaseSummary
        )
    }

    static func reviewAuditLine(
        auditFindings: [String]
    ) -> String? {
        DecisionEvolutionPendingReviewPresentationSupport.auditLine(
            auditFindings: auditFindings
        )
    }

    static func recommendedKillSwitchesLine(
        killSwitches: [String]
    ) -> String? {
        DecisionEvolutionKillSwitchPresentationSupport.suggestedLine(
            killSwitches: killSwitches
        )
    }

    static func summaryBadgePresentations(
        pendingReviewCount: Int,
        rollbackReadyCount: Int,
        pendingReviewLineageCount: Int
    ) -> [DecisionEvolutionSummaryBadgePresentation] {
        var badges: [DecisionEvolutionSummaryBadgePresentation] = [
            DecisionEvolutionSurfaceBadgePresentationSupport.pendingReviewBadge(
                count: pendingReviewCount
            ),
            DecisionEvolutionSurfaceBadgePresentationSupport.rollbackReadyBadge(
                count: rollbackReadyCount
            )
        ]

        if let lineageBadge = DecisionEvolutionSurfaceBadgePresentationSupport.lineageBackedBadge(
            count: pendingReviewLineageCount
        ) {
            badges.append(
                lineageBadge
            )
        }

        return badges
    }
}

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
    let summaryBadgePresentations: [DecisionEvolutionSummaryBadgePresentation]
    let headerTitle: String
    let headerDetail: String
    let guidedActionSectionTitle: String
    let restoreActiveTitle: String
    let rollbackActiveTitle: String
    let approveQueueTitle: String
    let clearQueueLineageTitle: String
    let embeddedReleaseSummaryMode: DecisionEvolutionReleaseSummaryPresentationMode?
    let pendingReviewLineageNotice: String?
    let reviewAuditLine: String?
    let recommendedKillSwitchesLine: String?
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
        let resolvedCanRollbackActiveCheckpoint = releaseSummary?.canRollbackActiveCheckpoint
            ?? controlSurface.canRollbackActiveCheckpoint
        let pendingReviewLineageCount = controlSurface.pendingReviewLineagePresentations.count

        return DecisionEvolutionPilotControlSnapshot(
            interactionMode: surfaceContract.interactionMode,
            allowsLocalMutationActions: allowsLocalMutationActions,
            pendingReviewCount: resolvedPendingReviewCount,
            rollbackReadyCount: resolvedRollbackReadyCount,
            pendingReviewLineageCount: pendingReviewLineageCount,
            summaryBadgePresentations: DecisionEvolutionPilotControlPresentationSupport.summaryBadgePresentations(
                pendingReviewCount: resolvedPendingReviewCount,
                rollbackReadyCount: resolvedRollbackReadyCount,
                pendingReviewLineageCount: pendingReviewLineageCount
            ),
            headerTitle: DecisionEvolutionPilotControlPresentationSupport.headerTitle,
            headerDetail: DecisionEvolutionPilotControlPresentationSupport.headerDetail(
                allowsLocalMutationActions: allowsLocalMutationActions
            ),
            guidedActionSectionTitle: DecisionEvolutionPilotControlPresentationSupport.guidedActionSectionTitle,
            restoreActiveTitle: DecisionEvolutionPilotControlPresentationSupport.restoreActiveTitle,
            rollbackActiveTitle: DecisionEvolutionPilotControlPresentationSupport.rollbackActiveTitle,
            approveQueueTitle: DecisionEvolutionPilotControlPresentationSupport.approveQueueTitle,
            clearQueueLineageTitle: DecisionEvolutionPilotControlPresentationSupport.clearQueueLineageTitle,
            embeddedReleaseSummaryMode: releaseSummary.map { _ in
                DecisionEvolutionPilotControlPresentationSupport.embeddedReleaseSummaryMode(
                    allowsLocalMutationActions: allowsLocalMutationActions
                )
            },
            pendingReviewLineageNotice: DecisionEvolutionPilotControlPresentationSupport.pendingReviewLineageNotice(
                pendingReviewLineageCount: pendingReviewLineageCount,
                hasReleaseSummary: releaseSummary != nil
            ),
            reviewAuditLine: DecisionEvolutionPilotControlPresentationSupport.reviewAuditLine(
                auditFindings: controlSurface.reviewAuditFindings
            ),
            recommendedKillSwitchesLine: DecisionEvolutionPilotControlPresentationSupport.recommendedKillSwitchesLine(
                killSwitches: resolvedRecommendedKillSwitches
            ),
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
                priorities: DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                    controlSurface: controlSurface,
                    releaseSummary: releaseSummary,
                    activeKillSwitches: resolvedActiveKillSwitches,
                    recommendedKillSwitches: resolvedRecommendedKillSwitches,
                    canRestoreActiveCheckpoint: resolvedCanRestoreActiveCheckpoint,
                    canRollbackActiveCheckpoint: resolvedCanRollbackActiveCheckpoint
                ),
                primaryReason: releaseSummary?.reasons.first,
                navigationOptions: navigationOptions,
                allowsLocalMutationActions: allowsLocalMutationActions,
                routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                approveQueueIntent: approveQueueIntent
            )
        )
    }

    private static func guidedAction(
        priorities: [DecisionEvolutionPrimaryBlocker],
        primaryReason: String?,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        allowsLocalMutationActions: Bool,
        routesMutationsToControlCenter: Bool,
        approveQueueIntent: DecisionEvolutionMutationIntent?
    ) -> DecisionEvolutionPilotGuidedAction? {
        for priority in priorities {
            if let action = guidedAction(
                for: priority,
                primaryReason: primaryReason,
                navigationOptions: navigationOptions,
                allowsLocalMutationActions: allowsLocalMutationActions,
                routesMutationsToControlCenter: routesMutationsToControlCenter,
                approveQueueIntent: approveQueueIntent
            ) {
                return action
            }
        }

        return nil
    }

    private static func guidedAction(
        for priority: DecisionEvolutionPrimaryBlocker,
        primaryReason: String?,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        allowsLocalMutationActions: Bool,
        routesMutationsToControlCenter: Bool,
        approveQueueIntent: DecisionEvolutionMutationIntent?
    ) -> DecisionEvolutionPilotGuidedAction? {
        let guidance = DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
            blocker: priority,
            primaryReason: primaryReason,
            allowsLocalMutationActions: allowsLocalMutationActions
        )

        if priority == .pendingReview,
           allowsLocalMutationActions,
           let approveQueueIntent,
           let guidance,
           let detail = guidance.detail {
            return DecisionEvolutionPilotGuidedAction(
                title: guidance.headline,
                detail: detail,
                actionTitle: DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle,
                route: .mutation(approveQueueIntent)
            )
        }

        guard let guidance,
              let detail = guidance.detail else { return nil }

        return navigationGuidedAction(
            title: guidance.headline,
            detail: detail,
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: routesMutationsToControlCenter
        )
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
