import Foundation

struct DecisionEvolutionPolicyInput: Equatable, Sendable {
    let activeCheckpointID: String?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let pendingReviewCount: Int
    let pendingReviewLineageCount: Int
    let canRestoreActiveCheckpoint: Bool
    let canRollbackActiveCheckpoint: Bool
    let hasRollbackTarget: Bool
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let reviewAuditFindings: [String]
    let queueAuditFindings: [String]
    let queueKillSwitches: [String]
    let runtimeBlockerSignals: [String]
    let allowsLocalMutationActions: Bool
    let preferredPrimaryBlocker: DecisionEvolutionPrimaryBlocker?

    var hasActiveCheckpoint: Bool {
        activeCheckpointID != nil
    }

    var blockerContext: DecisionEvolutionPrimaryBlockerContext {
        DecisionEvolutionPrimaryBlockerContext(
            activeKillSwitches: activeKillSwitches,
            recommendedKillSwitches: recommendedKillSwitches,
            runtimeBlockers: runtimeBlockerSignals,
            hasActiveCheckpoint: hasActiveCheckpoint,
            canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
            pendingReviewCount: pendingReviewCount,
            reviewAuditFindings: reviewAuditFindings,
            canRollbackActiveCheckpoint: canRollbackActiveCheckpoint
        )
    }
}

enum DecisionEvolutionPolicyPilotAction: Equatable, Sendable {
    case approvePendingQueue
    case navigate
}

enum DecisionEvolutionPolicySurfaceActionRoute: Equatable, Sendable {
    case approvePendingQueue
    case navigate(DecisionEvolutionNavigationDestination)
}

struct DecisionEvolutionPolicySurfaceGuidedAction: Equatable, Sendable {
    let title: String
    let detail: String
    let actionTitle: String
    let route: DecisionEvolutionPolicySurfaceActionRoute
}

struct DecisionEvolutionPolicySurfaceActionPlan: Equatable, Sendable {
    let allowsLocalMutationActions: Bool
    let showsAnyActionRow: Bool
    let quickActionsTitle: String?
    let guidedAction: DecisionEvolutionPolicySurfaceGuidedAction?
}

struct DecisionEvolutionPolicyActionAvailability: Equatable, Sendable {
    let allowsLocalMutationActions: Bool
    let canRestoreActivePath: Bool
    let canRollbackActivePath: Bool
    let canApprovePendingQueue: Bool
    let canClearPendingReviewLineage: Bool

    var hasAnyLocalAction: Bool {
        allowsLocalMutationActions
            && (
                canRestoreActivePath
                || canRollbackActivePath
                || canApprovePendingQueue
                || canClearPendingReviewLineage
            )
    }

    var hasAnyMutationWorkspaceAction: Bool {
        allowsLocalMutationActions
            && (
                canRollbackActivePath
                || canApprovePendingQueue
                || canClearPendingReviewLineage
            )
    }
}

struct DecisionEvolutionPolicyCheckpointActionAvailability: Equatable, Sendable {
    let showsMutationActions: Bool
    let canApply: Bool
    let secondaryActionKind: DecisionEvolutionCheckpointSecondaryActionKind?
    let canClearLineage: Bool
}

struct DecisionEvolutionPolicyCheckpointSetEligibility: Equatable, Sendable {
    let checkpointIDs: [String]
    let reviewCheckpointIDs: [String]
    let automaticCheckpointIDs: [String]
    let lineageCheckpointIDs: [String]
    let restorableCheckpointID: String?
    let allowsLocalMutationActions: Bool

    var canApproveCheckpoints: Bool {
        allowsLocalMutationActions && !reviewCheckpointIDs.isEmpty
    }

    var canMarkCheckpointsForReview: Bool {
        allowsLocalMutationActions && !automaticCheckpointIDs.isEmpty
    }

    var canClearCheckpointLineage: Bool {
        allowsLocalMutationActions && !lineageCheckpointIDs.isEmpty
    }
}

struct DecisionEvolutionPolicyPreviewState: Equatable, Sendable {
    let currentActiveCheckpointID: String?
    let projectedActiveCheckpointID: String?
    let currentReviewCheckpointID: String?
    let projectedReviewCheckpointID: String?
}

struct DecisionEvolutionPolicyOutput: Equatable, Sendable {
    let input: DecisionEvolutionPolicyInput
    let blockerOrder: [DecisionEvolutionPrimaryBlocker]
    let primaryBlocker: DecisionEvolutionPrimaryBlocker

    var actionAvailability: DecisionEvolutionPolicyActionAvailability {
        DecisionEvolutionPolicyActionAvailability(
            allowsLocalMutationActions: input.allowsLocalMutationActions,
            canRestoreActivePath: input.hasActiveCheckpoint && input.canRestoreActiveCheckpoint,
            canRollbackActivePath: input.hasRollbackTarget,
            canApprovePendingQueue: input.pendingReviewCount > 0,
            canClearPendingReviewLineage: input.pendingReviewLineageCount > 0
        )
    }

    var releaseGuidance: DecisionEvolutionReleasePathGuidancePresentation {
        DecisionEvolutionPrimaryBlockerPresentationSupport.releaseGuidance(
            blocker: primaryBlocker,
            input: input
        )
    }

    var primaryReason: String? {
        releaseGuidance.reasons.first
    }

    var widgetControlEntryKind: DecisionEvolutionWidgetControlEntryKind? {
        if attentionBlocker == .auditFindings {
            return .audit
        }

        switch attentionPresentation().severity {
        case .review:
            return .review
        case .blocked:
            return .control
        case .rollbackWatch:
            return .rollback
        case .none:
            return nil
        }
    }

    func widgetControlEntryPresentation(
        prompt: String,
        triggerReason: String? = nil,
        horizonDiagnosticsLines: [String] = []
    ) -> DecisionEvolutionWidgetControlEntryPresentation? {
        guard let widgetControlEntryKind else { return nil }
        let instruction = if widgetControlEntryKind == .audit {
            DecisionEvolutionHorizonTriggerReasonSupport.enrichedAuditInstruction(
                baseInstruction: DecisionEvolutionWidgetControlEntryLexiconSupport.instruction(
                    for: widgetControlEntryKind
                ),
                horizonDiagnosticsLines: horizonDiagnosticsLines
            )
        } else {
            String?.none
        }
        return DecisionEvolutionWidgetPresentationSupport.controlEntryPresentation(
            kind: widgetControlEntryKind,
            prompt: prompt,
            instruction: instruction,
            triggerReason: triggerReason
        )
    }

    func surfaceActionPlan(
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool
    ) -> DecisionEvolutionPolicySurfaceActionPlan {
        let allowsLocalMutationActions = input.allowsLocalMutationActions
        let showsAnyActionRow = if allowsLocalMutationActions {
            actionAvailability.hasAnyMutationWorkspaceAction
        } else {
            navigationOptions.showsAnyShortcut
        }

        return DecisionEvolutionPolicySurfaceActionPlan(
            allowsLocalMutationActions: allowsLocalMutationActions,
            showsAnyActionRow: showsAnyActionRow,
            quickActionsTitle: allowsLocalMutationActions && showsAnyActionRow
                ? DecisionEvolutionMutationHubPresentationSupport.quickActionsTitle
                : nil,
            guidedAction: surfaceGuidedAction(
                navigationOptions: navigationOptions,
                routesMutationsToControlCenter: routesMutationsToControlCenter
            )
        )
    }

    func operatorGuidance(
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionOperatorGuidance {
        let guidance = DecisionEvolutionPrimaryBlockerPresentationSupport.operatorGuidance(
            blocker: primaryBlocker,
            input: input,
            contract: contract
        )
        return DecisionEvolutionOperatorGuidance(
            headline: guidance.headline,
            primaryReason: guidance.detail
        )
    }

    func pilotGuidance() -> DecisionEvolutionPrimaryBlockerGuidancePresentation? {
        DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
            blocker: primaryBlocker,
            primaryReason: primaryReason,
            allowsLocalMutationActions: input.allowsLocalMutationActions
        )
    }

    func pilotGuidance(
        for blocker: DecisionEvolutionPrimaryBlocker
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation? {
        DecisionEvolutionPrimaryBlockerPresentationSupport.pilotGuidance(
            blocker: blocker,
            primaryReason: primaryReason,
            allowsLocalMutationActions: input.allowsLocalMutationActions
        )
    }

    func recommendedPilotStep(
        canNavigate: Bool
    ) -> (
        blocker: DecisionEvolutionPrimaryBlocker,
        action: DecisionEvolutionPolicyPilotAction,
        guidance: DecisionEvolutionPrimaryBlockerGuidancePresentation
    )? {
        for blocker in blockerOrder {
            guard let guidance = pilotGuidance(for: blocker) else { continue }

            if blocker == .pendingReview,
               input.allowsLocalMutationActions,
               actionAvailability.canApprovePendingQueue {
                return (blocker, .approvePendingQueue, guidance)
            }

            if canNavigate {
                return (blocker, .navigate, guidance)
            }
        }

        return nil
    }

    private func surfaceGuidedAction(
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool
    ) -> DecisionEvolutionPolicySurfaceGuidedAction? {
        let recommendedStep = recommendedPilotStep(
            canNavigate: navigationOptions.preferredDestination != nil
        )

        if recommendedStep?.action == .approvePendingQueue,
           let guidance = recommendedStep?.guidance,
           let detail = guidance.detail {
            return DecisionEvolutionPolicySurfaceGuidedAction(
                title: guidance.headline,
                detail: detail,
                actionTitle: DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle,
                route: .approvePendingQueue
            )
        }

        guard let guidance = recommendedStep?.guidance,
              let detail = guidance.detail,
              let destination = navigationOptions.preferredDestination else {
            return nil
        }

        return DecisionEvolutionPolicySurfaceGuidedAction(
            title: guidance.headline,
            detail: detail,
            actionTitle: destination.actionTitle(
                routesMutationsToControlCenter: routesMutationsToControlCenter
            ),
            route: .navigate(destination)
        )
    }

    func attentionPresentation() -> DecisionEvolutionAttentionPresentation {
        switch attentionBlocker {
        case .activeKillSwitches:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchDetail,
                pendingReviewCount: input.pendingReviewCount,
                killSwitches: input.activeKillSwitches,
                rollbackReady: input.canRollbackActiveCheckpoint
            )
        case .recommendedKillSwitches:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchDetail,
                pendingReviewCount: input.pendingReviewCount,
                killSwitches: input.recommendedKillSwitches,
                rollbackReady: input.canRollbackActiveCheckpoint
            )
        case .pendingReview:
            return DecisionEvolutionAttentionPresentation(
                severity: .review,
                badgeValue: DecisionEvolutionAttentionPresentationSupport.reviewBadgeValue(
                    pendingReviewCount: input.pendingReviewCount
                ),
                headline: DecisionEvolutionReviewPathPresentationSupport.reviewWaitingHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.attentionPendingReviewDetail(
                    pendingReviewCount: input.pendingReviewCount
                ),
                pendingReviewCount: input.pendingReviewCount,
                killSwitches: [],
                rollbackReady: input.canRollbackActiveCheckpoint
            )
        case .auditFindings:
            return DecisionEvolutionAttentionPresentation(
                severity: .review,
                badgeValue: "!",
                headline: DecisionEvolutionReleaseStagePresentationSupport.watchingAuditFindingsHeadline,
                detail: input.reviewAuditFindings.first,
                pendingReviewCount: input.pendingReviewCount,
                killSwitches: [],
                rollbackReady: input.canRollbackActiveCheckpoint
            )
        case .runtimeGuardrails:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
                detail: input.runtimeBlockerSignals.first,
                pendingReviewCount: input.pendingReviewCount,
                killSwitches: [],
                rollbackReady: input.canRollbackActiveCheckpoint
            )
        case nil:
            if input.canRollbackActiveCheckpoint {
                return DecisionEvolutionAttentionPresentation(
                    severity: .rollbackWatch,
                    badgeValue: "↺",
                    headline: DecisionEvolutionAttentionPresentationSupport.rollbackReadyHeadline,
                    detail: DecisionEvolutionAttentionPresentationSupport.rollbackReadyDetail,
                    pendingReviewCount: 0,
                    killSwitches: [],
                    rollbackReady: true
                )
            }

            return DecisionEvolutionAttentionPresentation(
                severity: .none,
                badgeValue: nil,
                headline: DecisionEvolutionAttentionPresentationSupport.quietHeadline,
                detail: nil,
                pendingReviewCount: 0,
                killSwitches: [],
                rollbackReady: false
            )
        default:
            if input.canRollbackActiveCheckpoint {
                return DecisionEvolutionAttentionPresentation(
                    severity: .rollbackWatch,
                    badgeValue: "↺",
                    headline: DecisionEvolutionAttentionPresentationSupport.rollbackReadyHeadline,
                    detail: DecisionEvolutionAttentionPresentationSupport.rollbackReadyDetail,
                    pendingReviewCount: 0,
                    killSwitches: [],
                    rollbackReady: true
                )
            }

            return DecisionEvolutionAttentionPresentation(
                severity: .none,
                badgeValue: nil,
                headline: DecisionEvolutionAttentionPresentationSupport.quietHeadline,
                detail: nil,
                pendingReviewCount: 0,
                killSwitches: [],
                rollbackReady: false
            )
        }
    }

    private var attentionBlocker: DecisionEvolutionPrimaryBlocker? {
        if !input.activeKillSwitches.isEmpty {
            return .activeKillSwitches
        }

        if !input.recommendedKillSwitches.isEmpty {
            return .recommendedKillSwitches
        }

        if input.pendingReviewCount > 0 {
            return .pendingReview
        }

        if !input.runtimeBlockerSignals.isEmpty {
            return .runtimeGuardrails
        }

        if !input.reviewAuditFindings.isEmpty {
            return .auditFindings
        }

        return nil
    }
}

enum DecisionEvolutionPolicyEngine {
    static func evaluate(
        _ input: DecisionEvolutionPolicyInput
    ) -> DecisionEvolutionPolicyOutput {
        var blockerOrder = orderedPriorities(for: input.blockerContext)

        if let preferredPrimaryBlocker = input.preferredPrimaryBlocker {
            blockerOrder = [preferredPrimaryBlocker]
                + blockerOrder.filter { $0 != preferredPrimaryBlocker }
        }

        if blockerOrder.isEmpty {
            blockerOrder = [.ready]
        }

        return DecisionEvolutionPolicyOutput(
            input: input,
            blockerOrder: blockerOrder,
            primaryBlocker: blockerOrder.first ?? .ready
        )
    }

    static func input(
        _ context: DecisionEvolutionPrimaryBlockerContext,
        activeCheckpointID: String? = nil,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource = .none,
        pendingReviewLineageCount: Int = 0,
        queueAuditFindings: [String] = [],
        queueKillSwitches: [String] = [],
        hasRollbackTarget: Bool = false,
        allowsLocalMutationActions: Bool = false,
        preferredPrimaryBlocker: DecisionEvolutionPrimaryBlocker? = nil
    ) -> DecisionEvolutionPolicyInput {
        DecisionEvolutionPolicyInput(
            activeCheckpointID: activeCheckpointID,
            activeCheckpointSource: activeCheckpointSource,
            pendingReviewCount: context.pendingReviewCount,
            pendingReviewLineageCount: pendingReviewLineageCount,
            canRestoreActiveCheckpoint: context.canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: context.canRollbackActiveCheckpoint,
            hasRollbackTarget: hasRollbackTarget,
            activeKillSwitches: context.activeKillSwitches,
            recommendedKillSwitches: context.recommendedKillSwitches,
            reviewAuditFindings: context.reviewAuditFindings,
            queueAuditFindings: queueAuditFindings,
            queueKillSwitches: queueKillSwitches,
            runtimeBlockerSignals: context.runtimeBlockers,
            allowsLocalMutationActions: allowsLocalMutationActions,
            preferredPrimaryBlocker: preferredPrimaryBlocker
        )
    }

    static func input(
        workspace: DecisionEvolutionWorkspaceSnapshot,
        allowsLocalMutationActions: Bool = false
    ) -> DecisionEvolutionPolicyInput {
        if let releaseSummary = workspace.releaseSummary {
            let preferredPrimaryBlocker = preferredPrimaryBlocker(
                from: releaseSummary
            )
            let releaseAuditFindings = preferredPrimaryBlocker == .auditFindings
                ? releaseSummary.reasons
                : []
            return DecisionEvolutionPolicyInput(
                activeCheckpointID: releaseSummary.activeCheckpointID,
                activeCheckpointSource: releaseSummary.activeCheckpointSource,
                pendingReviewCount: releaseSummary.pendingReviewCount,
                pendingReviewLineageCount: workspace.controlSurface.pendingReviewLineagePresentations.count,
                canRestoreActiveCheckpoint: releaseSummary.canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: releaseSummary.canRollbackActiveCheckpoint,
                hasRollbackTarget: workspace.controlSurface.activeRollbackCheckpointID != nil,
                activeKillSwitches: releaseSummary.activeKillSwitches,
                recommendedKillSwitches: releaseSummary.recommendedKillSwitches,
                reviewAuditFindings: releaseAuditFindings,
                queueAuditFindings: workspace.controlSurface.queueAuditFindings,
                queueKillSwitches: workspace.controlSurface.queueKillSwitches,
                runtimeBlockerSignals: preferredPrimaryBlocker == .runtimeGuardrails
                    ? releaseSummary.reasons
                    : [],
                allowsLocalMutationActions: allowsLocalMutationActions,
                preferredPrimaryBlocker: preferredPrimaryBlocker
            )
        }

        let facts = workspace.facts
        return DecisionEvolutionPolicyInput(
            activeCheckpointID: workspace.activePresentation?.checkpointID,
            activeCheckpointSource: workspace.controlSurface.activeCheckpointSource,
            pendingReviewCount: facts.pendingReviewCount,
            pendingReviewLineageCount: workspace.controlSurface.pendingReviewLineagePresentations.count,
            canRestoreActiveCheckpoint: facts.canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: facts.canRollbackActiveCheckpoint,
            hasRollbackTarget: workspace.controlSurface.activeRollbackCheckpointID != nil,
            activeKillSwitches: facts.activeKillSwitches,
            recommendedKillSwitches: facts.recommendedKillSwitches,
            reviewAuditFindings: workspace.controlSurface.reviewAuditFindings,
            queueAuditFindings: workspace.controlSurface.queueAuditFindings,
            queueKillSwitches: workspace.controlSurface.queueKillSwitches,
            runtimeBlockerSignals: [],
            allowsLocalMutationActions: allowsLocalMutationActions,
            preferredPrimaryBlocker: nil
        )
    }

    static func input(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary?,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        reviewAuditFindings: [String]? = nil,
        runtimeBlockerSignals: [String] = [],
        canRestoreActiveCheckpoint: Bool,
        canRollbackActiveCheckpoint: Bool,
        allowsLocalMutationActions: Bool = false
    ) -> DecisionEvolutionPolicyInput {
        if let releaseSummary {
            let preferredPrimaryBlocker = preferredPrimaryBlocker(
                from: releaseSummary
            )
            let releaseAuditFindings = preferredPrimaryBlocker == .auditFindings
                ? releaseSummary.reasons
                : []
            return DecisionEvolutionPolicyInput(
                activeCheckpointID: releaseSummary.activeCheckpointID,
                activeCheckpointSource: releaseSummary.activeCheckpointSource,
                pendingReviewCount: releaseSummary.pendingReviewCount,
                pendingReviewLineageCount: controlSurface.pendingReviewLineagePresentations.count,
                canRestoreActiveCheckpoint: releaseSummary.canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: releaseSummary.canRollbackActiveCheckpoint,
                hasRollbackTarget: controlSurface.activeRollbackCheckpointID != nil,
                activeKillSwitches: releaseSummary.activeKillSwitches,
                recommendedKillSwitches: releaseSummary.recommendedKillSwitches,
                reviewAuditFindings: releaseAuditFindings,
                queueAuditFindings: controlSurface.queueAuditFindings,
                queueKillSwitches: controlSurface.queueKillSwitches,
                runtimeBlockerSignals: preferredPrimaryBlocker == .runtimeGuardrails
                    ? releaseSummary.reasons
                    : [],
                allowsLocalMutationActions: allowsLocalMutationActions,
                preferredPrimaryBlocker: preferredPrimaryBlocker
            )
        }

        return DecisionEvolutionPolicyInput(
            activeCheckpointID: controlSurface.activePresentation?.checkpointID,
            activeCheckpointSource: controlSurface.activeCheckpointSource,
            pendingReviewCount: controlSurface.pendingReviewCount,
            pendingReviewLineageCount: controlSurface.pendingReviewLineagePresentations.count,
            canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: canRollbackActiveCheckpoint,
            hasRollbackTarget: controlSurface.activeRollbackCheckpointID != nil,
            activeKillSwitches: activeKillSwitches,
            recommendedKillSwitches: recommendedKillSwitches,
            reviewAuditFindings: reviewAuditFindings ?? controlSurface.reviewAuditFindings,
            queueAuditFindings: controlSurface.queueAuditFindings,
            queueKillSwitches: controlSurface.queueKillSwitches,
            runtimeBlockerSignals: runtimeBlockerSignals,
            allowsLocalMutationActions: allowsLocalMutationActions,
            preferredPrimaryBlocker: nil
        )
    }

    static func checkpointActionAvailability(
        allowsLocalMutationActions: Bool,
        applyReady: Bool,
        approvalState: DecisionEvolutionApprovalState?,
        hasLineage: Bool
    ) -> DecisionEvolutionPolicyCheckpointActionAvailability {
        DecisionEvolutionPolicyCheckpointActionAvailability(
            showsMutationActions: allowsLocalMutationActions,
            canApply: allowsLocalMutationActions && applyReady,
            secondaryActionKind: allowsLocalMutationActions
                ? (approvalState == .reviewSuggested ? .approve : .markForReview)
                : nil,
            canClearLineage: allowsLocalMutationActions && hasLineage
        )
    }

    static func checkpointSetEligibility(
        allowsLocalMutationActions: Bool,
        presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> DecisionEvolutionPolicyCheckpointSetEligibility {
        let orderedPresentations = orderedUniquePresentations(presentations)
        return DecisionEvolutionPolicyCheckpointSetEligibility(
            checkpointIDs: orderedPresentations.map(\.checkpointID),
            reviewCheckpointIDs: orderedPresentations
                .filter { $0.approvalState == .reviewSuggested }
                .map(\.checkpointID),
            automaticCheckpointIDs: orderedPresentations
                .filter { $0.approvalState == .automatic }
                .map(\.checkpointID),
            lineageCheckpointIDs: orderedPresentations
                .filter(\.hasLineage)
                .map(\.checkpointID),
            restorableCheckpointID: orderedPresentations.count == 1 && orderedPresentations.first?.applyReady == true
                ? orderedPresentations.first?.checkpointID
                : nil,
            allowsLocalMutationActions: allowsLocalMutationActions
        )
    }

    static func stablePreviewState(
        currentActiveCheckpointID: String?,
        currentReviewCheckpointID: String?
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: currentActiveCheckpointID,
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: currentReviewCheckpointID
        )
    }

    static func applyCheckpointPreviewState(
        targetCheckpointID: String,
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentActiveCheckpointID: String?,
        currentReviewCheckpointID: String?
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: projectedRestoredActiveCheckpointID(
                targetCheckpointID: targetCheckpointID,
                targetPresentation: targetPresentation,
                currentActiveCheckpointID: currentActiveCheckpointID
            ),
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: currentReviewCheckpointID == targetCheckpointID
                ? targetCheckpointID
                : currentReviewCheckpointID
        )
    }

    static func approveCheckpointPreviewState(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentActivePresentation: DecisionEvolutionCheckpointPresentation?,
        currentReviewCheckpointID: String?,
        remainingReviewQueue: [DecisionEvolutionCheckpointPresentation]
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActivePresentation?.checkpointID,
            projectedActiveCheckpointID: projectedActiveCheckpointIDAfterApproval(
                targetPresentation: targetPresentation,
                currentActivePresentation: currentActivePresentation
            ),
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: remainingReviewQueue.first?.checkpointID
        )
    }

    static func markCheckpointForReviewPreviewState(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentActiveCheckpointID: String?,
        currentReviewPresentation: DecisionEvolutionCheckpointPresentation?
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: projectedActiveCheckpointIDAfterMarkReview(
                targetCheckpointID: targetPresentation.checkpointID,
                currentActiveCheckpointID: currentActiveCheckpointID
            ),
            currentReviewCheckpointID: currentReviewPresentation?.checkpointID,
            projectedReviewCheckpointID: projectedReviewCheckpointIDAfterMarkReview(
                targetPresentation: targetPresentation,
                currentReviewPresentation: currentReviewPresentation
            )
        )
    }

    static func rollbackCheckpointPreviewState(
        rollbackCheckpointID: String,
        targetPresentation: DecisionEvolutionCheckpointPresentation?,
        currentActiveCheckpointID: String?,
        currentReviewCheckpointID: String?
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: projectedRestoredActiveCheckpointID(
                targetCheckpointID: rollbackCheckpointID,
                targetPresentation: targetPresentation,
                currentActiveCheckpointID: currentActiveCheckpointID
            ),
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: currentReviewCheckpointID
        )
    }

    static func approvePendingQueuePreviewState(
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource,
        currentActiveCheckpointID: String?,
        currentReviewCheckpointID: String?,
        projectedAutomaticCheckpointID: String?
    ) -> DecisionEvolutionPolicyPreviewState {
        let projectedActiveCheckpointID: String?
        switch activeCheckpointSource {
        case .pinnedHint:
            projectedActiveCheckpointID = currentActiveCheckpointID
        case .automaticFallback, .none:
            projectedActiveCheckpointID = projectedAutomaticCheckpointID
        }

        return DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: projectedActiveCheckpointID,
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: nil
        )
    }

    static func approveSelectedCheckpointsPreviewState(
        currentActiveCheckpointID: String?,
        currentReviewCheckpointID: String?,
        remainingReviewQueue: [DecisionEvolutionCheckpointPresentation]
    ) -> DecisionEvolutionPolicyPreviewState {
        DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: currentActiveCheckpointID,
            currentReviewCheckpointID: currentReviewCheckpointID,
            projectedReviewCheckpointID: remainingReviewQueue.first?.checkpointID
        )
    }

    static func markSelectedCheckpointsForReviewPreviewState(
        targetPresentations: [DecisionEvolutionCheckpointPresentation],
        currentActiveCheckpointID: String?,
        currentReviewPresentation: DecisionEvolutionCheckpointPresentation?
    ) -> DecisionEvolutionPolicyPreviewState {
        let targetIDs = Set(targetPresentations.map(\.checkpointID))
        return DecisionEvolutionPolicyPreviewState(
            currentActiveCheckpointID: currentActiveCheckpointID,
            projectedActiveCheckpointID: currentActiveCheckpointID.flatMap {
                targetIDs.contains($0) ? nil : $0
            },
            currentReviewCheckpointID: currentReviewPresentation?.checkpointID,
            projectedReviewCheckpointID: preferredCheckpointID(
                from: (currentReviewPresentation.map { [$0] } ?? []) + targetPresentations
            )
        )
    }

    private static func orderedUniquePresentations(
        _ presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        presentations.reduce(into: [DecisionEvolutionCheckpointPresentation]()) { uniquePresentations, presentation in
            guard !uniquePresentations.contains(where: { $0.checkpointID == presentation.checkpointID }) else {
                return
            }
            uniquePresentations.append(presentation)
        }
    }

    private static func preferredCheckpointID(
        from presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> String? {
        orderedUniquePresentations(presentations).max { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.checkpointID < rhs.checkpointID
        }?.checkpointID
    }

    private static func projectedRestoredActiveCheckpointID(
        targetCheckpointID: String,
        targetPresentation: DecisionEvolutionCheckpointPresentation?,
        currentActiveCheckpointID: String?
    ) -> String? {
        guard let targetPresentation else {
            return targetCheckpointID
        }

        if targetPresentation.approvalState == .automatic {
            return targetCheckpointID
        }

        return currentActiveCheckpointID
    }

    private static func projectedActiveCheckpointIDAfterApproval(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentActivePresentation: DecisionEvolutionCheckpointPresentation?
    ) -> String? {
        guard let currentActivePresentation else {
            return targetPresentation.checkpointID
        }

        if targetPresentation.createdAt != currentActivePresentation.createdAt {
            return targetPresentation.createdAt > currentActivePresentation.createdAt
                ? targetPresentation.checkpointID
                : currentActivePresentation.checkpointID
        }

        return targetPresentation.checkpointID > currentActivePresentation.checkpointID
            ? targetPresentation.checkpointID
            : currentActivePresentation.checkpointID
    }

    private static func projectedActiveCheckpointIDAfterMarkReview(
        targetCheckpointID: String,
        currentActiveCheckpointID: String?
    ) -> String? {
        guard currentActiveCheckpointID == targetCheckpointID else {
            return currentActiveCheckpointID
        }

        return nil
    }

    private static func projectedReviewCheckpointIDAfterMarkReview(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentReviewPresentation: DecisionEvolutionCheckpointPresentation?
    ) -> String? {
        guard let currentReviewPresentation else {
            return targetPresentation.checkpointID
        }

        if targetPresentation.createdAt != currentReviewPresentation.createdAt {
            return targetPresentation.createdAt > currentReviewPresentation.createdAt
                ? targetPresentation.checkpointID
                : currentReviewPresentation.checkpointID
        }

        return targetPresentation.checkpointID > currentReviewPresentation.checkpointID
            ? targetPresentation.checkpointID
            : currentReviewPresentation.checkpointID
    }

    static func orderedPriorities(
        for context: DecisionEvolutionPrimaryBlockerContext
    ) -> [DecisionEvolutionPrimaryBlocker] {
        var priorities: [DecisionEvolutionPrimaryBlocker] = []

        if !context.activeKillSwitches.isEmpty {
            priorities.append(.activeKillSwitches)
        }

        if !context.recommendedKillSwitches.isEmpty {
            priorities.append(.recommendedKillSwitches)
        }

        if !context.runtimeBlockers.isEmpty {
            priorities.append(.runtimeGuardrails)
        }

        if !context.hasActiveCheckpoint {
            priorities.append(.missingActiveCheckpoint)
        }

        if context.hasActiveCheckpoint, !context.canRestoreActiveCheckpoint {
            priorities.append(.nonRestorableActiveCheckpoint)
        }

        if context.pendingReviewCount > 0 {
            priorities.append(.pendingReview)
        }

        if !context.reviewAuditFindings.isEmpty {
            priorities.append(.auditFindings)
        }

        if context.hasActiveCheckpoint, !context.canRollbackActiveCheckpoint {
            priorities.append(.rollbackNotReady)
        }

        if priorities.isEmpty {
            priorities.append(.ready)
        }

        return priorities
    }

    static func preferredPrimaryBlocker(
        from releaseSummary: DecisionSystemReleaseControlSummary
    ) -> DecisionEvolutionPrimaryBlocker? {
        releaseSummary.primaryBlocker
            ?? legacyPrimaryBlocker(from: releaseSummary.headline)
    }

    private static func legacyPrimaryBlocker(
        from headline: String
    ) -> DecisionEvolutionPrimaryBlocker? {
        switch headline {
        case DecisionEvolutionReleasePathPresentationSupport.blockedActiveKillSwitchHeadline:
            .activeKillSwitches
        case DecisionEvolutionReleasePathPresentationSupport.watchingRecommendedKillSwitchesHeadline:
            .recommendedKillSwitches
        case DecisionEvolutionReleasePathPresentationSupport.blockedRuntimeGuardrailsHeadline:
            .runtimeGuardrails
        case DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline:
            .missingActiveCheckpoint
        case DecisionEvolutionReleasePathPresentationSupport.blockedUntilRestorableHeadline:
            .nonRestorableActiveCheckpoint
        case DecisionEvolutionReleasePathPresentationSupport.watchingPendingReviewHeadline:
            .pendingReview
        case DecisionEvolutionReleasePathPresentationSupport.watchingAuditFindingsHeadline:
            .auditFindings
        case DecisionEvolutionReleasePathPresentationSupport.watchingRollbackReadinessHeadline:
            .rollbackNotReady
        case DecisionEvolutionReleasePathPresentationSupport.readyForGuardedPilotHeadline:
            .ready
        default:
            nil
        }
    }
}
