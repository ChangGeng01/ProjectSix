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

    static func reviewCourtLine(
        courtLine: String?,
        queueCourtLines: [String]
    ) -> String? {
        if let courtLine {
            return courtLine
        }

        return queueCourtLines.first
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

    static func preferredQuickActionExecutionBlockerLine(
        controlSurface: DecisionEvolutionControlSurface,
        actionBundle: DecisionEvolutionWorkspaceMutationActionBundle
    ) -> String {
        if actionBundle.approveQueueIntent == nil {
            return approveQueueAvailabilityLine(
                controlSurface: controlSurface,
                isAvailable: false
            )
        }

        if actionBundle.rollbackActiveIntent == nil {
            return rollbackActionAvailabilityLine(
                controlSurface: controlSurface,
                isAvailable: false
            )
        }

        return restoreActionAvailabilityLine(
            controlSurface: controlSurface,
            isAvailable: false
        )
    }

    static func queueLineageExecutionBlockerLine(
        controlSurface: DecisionEvolutionControlSurface,
        clearLineageAvailable: Bool
    ) -> String {
        queueLineageAvailabilityLines(
            controlSurface: controlSurface,
            clearLineageAvailable: clearLineageAvailable
        ).first ?? "\(clearQueueLineageTitle) is not currently available."
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
    let executionState: DecisionEvolutionFurnaceExecutionStatePresentation
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
    let presenceTitle: String?
    let presenceLines: [String]
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let restoreActiveTitle: String
    let rollbackActiveTitle: String
    let approveQueueTitle: String
    let clearQueueLineageTitle: String
    let embeddedReleaseSummaryMode: DecisionEvolutionReleaseSummaryPresentationMode?
    let pendingReviewLineageNotice: String?
    let reviewAuditLine: String?
    let reviewCourtLine: String?
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
            surfaceContract: surfaceContract
        )
        let presenceLines = releaseSummary.map {
            DecisionEvolutionPresencePresentationSupport.lines(
                presenceLine: $0.presenceLine,
                reasons: $0.reasons
            )
        } ?? []
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
            presenceTitle: presenceLines.isEmpty
                ? nil
                : DecisionEvolutionPresencePresentationSupport.title,
            presenceLines: presenceLines,
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
            reviewCourtLine: DecisionEvolutionPilotControlPresentationSupport.reviewCourtLine(
                courtLine: controlSurface.reviewCourtLine,
                queueCourtLines: controlSurface.queueCourtLines
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
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionPilotFurnaceWorkbenchGuidance? {
        guard surfaceContract.allowsMutations,
              let releaseSummary else { return nil }

        guard let workbenchPresentation = DecisionEvolutionFurnaceReviewPresentationSupport.build(
            releaseSummary: releaseSummary,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        ).workbenchPresentation,
           let action = workbenchPresentation.nextStepAction,
           case .focusMutationHub = action.kind else {
            return nil
        }

        return DecisionEvolutionPilotFurnaceWorkbenchGuidance(
            title: workbenchPresentation.headline,
            detail: workbenchPresentation.detail,
            availabilityTitle: workbenchPresentation.availabilityTitle,
            availabilityLines: workbenchPresentation.availabilityLines,
            executionState: workbenchPresentation.executionState,
            runNowActionTitle: workbenchPresentation.runNowAction?.actionTitle,
            runNowIntent: workbenchPresentation.runNowAction?.intent,
            actionTitle: action.actionTitle,
            focusTarget: workbenchPresentation.focusTarget
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
