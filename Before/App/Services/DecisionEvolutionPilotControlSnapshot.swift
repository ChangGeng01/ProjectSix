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
        let actionBundle = DecisionEvolutionWorkspaceMutationActionBundle.build(
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
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: releaseSummary,
                activeKillSwitches: resolvedActiveKillSwitches,
                recommendedKillSwitches: resolvedRecommendedKillSwitches,
                canRestoreActiveCheckpoint: resolvedCanRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: resolvedCanRollbackActiveCheckpoint,
                allowsLocalMutationActions: allowsLocalMutationActions
            )
        )
        let actionPlan = policy.surfaceActionPlan(
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter
        )

        return DecisionEvolutionPilotControlSnapshot(
            interactionMode: surfaceContract.interactionMode,
            allowsLocalMutationActions: actionPlan.allowsLocalMutationActions,
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
                    allowsLocalMutationActions: actionPlan.allowsLocalMutationActions
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
            mutationIntents: actionBundle.mutationIntents,
            restoreActiveIntent: actionBundle.restoreActiveIntent,
            rollbackActiveIntent: actionBundle.rollbackActiveIntent,
            approveQueueIntent: actionBundle.approveQueueIntent,
            clearReviewLineageIntent: actionBundle.clearReviewLineageIntent,
            reviewAuditFindings: controlSurface.reviewAuditFindings,
            recommendedKillSwitches: resolvedRecommendedKillSwitches,
            guidedAction: guidedAction(
                actionPlan: actionPlan,
                actionBundle: actionBundle
            )
        )
    }

    private static func guidedAction(
        actionPlan: DecisionEvolutionPolicySurfaceActionPlan,
        actionBundle: DecisionEvolutionWorkspaceMutationActionBundle
    ) -> DecisionEvolutionPilotGuidedAction? {
        guard let guidedAction = actionPlan.guidedAction else { return nil }

        switch guidedAction.route {
        case .approvePendingQueue:
            guard let mutationIntent = actionBundle.mutationIntent(for: guidedAction.route) else { return nil }
            return DecisionEvolutionPilotGuidedAction(
                title: guidedAction.title,
                detail: guidedAction.detail,
                actionTitle: guidedAction.actionTitle,
                route: .mutation(mutationIntent)
            )
        case .navigate(let destination):
            return DecisionEvolutionPilotGuidedAction(
                title: guidedAction.title,
                detail: guidedAction.detail,
                actionTitle: guidedAction.actionTitle,
                route: .navigation(destination)
            )
        }
    }
}
