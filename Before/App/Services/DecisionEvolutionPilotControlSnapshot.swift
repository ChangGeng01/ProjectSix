import Foundation

enum DecisionEvolutionPilotControlPresentationSupport {
    static let headerTitle = "Evolution pilot controls"
    static let guidedActionSectionTitle = "Recommended next step"
    static let furnaceWorkbenchSectionTitle = "Furnace workbench"
    static let foldedLungSectionTitle = DecisionEvolutionFoldedLungPresentationSupport.title
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

    static func furnaceWorkbenchHeadline(
        for focusTarget: DecisionEvolutionMutationHubFocusTarget
    ) -> String {
        switch focusTarget {
        case .quickActions:
            "Quick actions are holding the next furnace review step"
        case .queueLineage:
            "Queue lineage is holding the next furnace review step"
        }
    }

    static func furnaceWorkbenchAvailabilityTitle(
        isBlocked: Bool
    ) -> String {
        isBlocked ? "Blocked" : "Ready now"
    }

    static func quickActionAvailabilityLines(
        controlSurface: DecisionEvolutionControlSurface,
        actionBundle: DecisionEvolutionWorkspaceMutationActionBundle
    ) -> [String] {
        [
            restoreActionAvailabilityLine(
                controlSurface: controlSurface,
                isAvailable: actionBundle.restoreActiveIntent != nil
            ),
            rollbackActionAvailabilityLine(
                controlSurface: controlSurface,
                isAvailable: actionBundle.rollbackActiveIntent != nil
            ),
            approveQueueAvailabilityLine(
                controlSurface: controlSurface,
                isAvailable: actionBundle.approveQueueIntent != nil
            )
        ]
    }

    static func queueLineageAvailabilityLines(
        controlSurface: DecisionEvolutionControlSurface,
        clearLineageAvailable: Bool
    ) -> [String] {
        [
            clearLineageAvailable
                ? "\(clearQueueLineageTitle) is available."
                : controlSurface.pendingReviewLineagePresentations.isEmpty
                    ? "\(clearQueueLineageTitle) is waiting for lineage-backed review checkpoints."
                    : "\(clearQueueLineageTitle) is not currently available."
        ]
    }

    private static func restoreActionAvailabilityLine(
        controlSurface: DecisionEvolutionControlSurface,
        isAvailable: Bool
    ) -> String {
        if isAvailable {
            return "\(restoreActiveTitle) is available."
        }

        guard let activePresentation = controlSurface.activePresentation else {
            return "\(restoreActiveTitle) is waiting for an active checkpoint."
        }

        return activePresentation.applyReady
            ? "\(restoreActiveTitle) is not currently available."
            : "\(restoreActiveTitle) is waiting for a restorable active checkpoint."
    }

    private static func rollbackActionAvailabilityLine(
        controlSurface: DecisionEvolutionControlSurface,
        isAvailable: Bool
    ) -> String {
        if isAvailable {
            return "\(rollbackActiveTitle) is available."
        }

        guard controlSurface.activePresentation != nil else {
            return "\(rollbackActiveTitle) is waiting for an active checkpoint."
        }

        return controlSurface.activeRollbackCheckpointID == nil
            ? "\(rollbackActiveTitle) is waiting for a restorable previous checkpoint."
            : "\(rollbackActiveTitle) is not currently available."
    }

    private static func approveQueueAvailabilityLine(
        controlSurface: DecisionEvolutionControlSurface,
        isAvailable: Bool
    ) -> String {
        if isAvailable {
            return "\(approveQueueTitle) is available."
        }

        return controlSurface.pendingReviewCount == 0
            ? "\(approveQueueTitle) is waiting for pending review checkpoints."
            : "\(approveQueueTitle) is not currently available."
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

struct DecisionEvolutionPilotFurnaceWorkbenchGuidance: Equatable, Sendable {
    let title: String
    let detail: String
    let availabilityTitle: String
    let availabilityLines: [String]
    let runNowActionTitle: String?
    let runNowIntent: DecisionEvolutionMutationIntent?
    let actionTitle: String
    let focusTarget: DecisionEvolutionMutationHubFocusTarget
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
    let furnaceWorkbenchSectionTitle: String?
    let foldedLungTitle: String?
    let foldedLungLines: [String]
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
    let furnaceWorkbenchGuidance: DecisionEvolutionPilotFurnaceWorkbenchGuidance?

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
        let furnaceWorkbenchGuidance = furnaceWorkbenchGuidance(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            surfaceContract: surfaceContract,
            actionBundle: actionBundle
        )
        let foldedLungLines = releaseSummary.map {
            DecisionEvolutionFoldedLungPresentationSupport.lines(from: $0.reasons)
        } ?? []

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
            furnaceWorkbenchSectionTitle: furnaceWorkbenchGuidance == nil
                ? nil
                : DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchSectionTitle,
            foldedLungTitle: foldedLungLines.isEmpty
                ? nil
                : DecisionEvolutionPilotControlPresentationSupport.foldedLungSectionTitle,
            foldedLungLines: foldedLungLines,
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
            ),
            furnaceWorkbenchGuidance: furnaceWorkbenchGuidance
        )
    }

    private static func furnaceWorkbenchGuidance(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary?,
        surfaceContract: DecisionEvolutionSurfaceContract,
        actionBundle: DecisionEvolutionWorkspaceMutationActionBundle
    ) -> DecisionEvolutionPilotFurnaceWorkbenchGuidance? {
        guard surfaceContract.allowsMutations,
              let releaseSummary else { return nil }

        let checklistLines = DecisionEvolutionReleaseSummaryPresentationSupport.furnaceChecklistLines(
            releaseSummary: releaseSummary
        )
        guard let detail = DecisionEvolutionFurnaceNextStepPresentationSupport.detail(
            from: checklistLines
        ), let action = DecisionEvolutionFurnaceNextStepActionSupport.build(
            detail: detail,
            surfaceContract: surfaceContract
        ), case let .focusMutationHub(focusTarget) = action.kind else {
            return nil
        }

        let availabilityLines: [String]
        let isBlocked: Bool
        let runNowAction: DecisionEvolutionFurnaceRunNowActionPresentation?
        switch focusTarget {
        case .quickActions:
            let hasAvailableQuickAction = actionBundle.restoreActiveIntent != nil
                || actionBundle.rollbackActiveIntent != nil
                || actionBundle.approveQueueIntent != nil
            availabilityLines = DecisionEvolutionPilotControlPresentationSupport.quickActionAvailabilityLines(
                controlSurface: controlSurface,
                actionBundle: actionBundle
            )
            isBlocked = hasAvailableQuickAction == false
            runNowAction = DecisionEvolutionFurnaceRunNowActionSupport.preferredQuickAction(
                actionBundle: actionBundle
            )
        case .queueLineage:
            let canClearLineage = actionBundle.clearReviewLineageIntent != nil
            availabilityLines = DecisionEvolutionPilotControlPresentationSupport.queueLineageAvailabilityLines(
                controlSurface: controlSurface,
                clearLineageAvailable: canClearLineage
            )
            isBlocked = canClearLineage == false
            runNowAction = DecisionEvolutionFurnaceRunNowActionSupport.build(
                detail: detail,
                controlSurface: controlSurface,
                surfaceContract: surfaceContract
            )
        }

        return DecisionEvolutionPilotFurnaceWorkbenchGuidance(
            title: DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchHeadline(
                for: focusTarget
            ),
            detail: detail,
            availabilityTitle: DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchAvailabilityTitle(
                isBlocked: isBlocked
            ),
            availabilityLines: availabilityLines,
            runNowActionTitle: runNowAction?.actionTitle,
            runNowIntent: runNowAction?.intent,
            actionTitle: action.actionTitle,
            focusTarget: focusTarget
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
