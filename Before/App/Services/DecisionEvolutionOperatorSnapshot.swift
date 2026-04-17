import Foundation

enum DecisionEvolutionKillSwitchPresentationSupport {
    static let queueHeadline = "Watching queue kill switches"
    static let queueReason = "Queue kill switches remain active until the review path is cleared."
    static let blockedReleaseHeadline = "Blocked by active kill switches"
    static let blockedReleaseReason = "Kill switches are active on the current release path."
    static let recommendedReleaseHeadline = "Watching recommended kill switches"
    static let blockedReviewHeadline = "Evolution is blocked by active kill switches"
    static let blockedReviewDetail = "Open Evolution Control to clear the blocked review path before release work continues."
    static let recommendedReleaseReason = "Recommended kill switches are waiting for operator review before wider rollout."
    static let pilotHeadline = "Kill switches are holding the release path"
    static let pilotDetail = "Inspect the active checkpoint and its guardrails before trying to widen rollout."
    static let activeLineTitle = "Active kill switches"
    static let recommendedLineTitle = "Recommended kill switches"
    static let suggestedLineTitle = "Suggested kill switches"
    static let queueReasonPrefix = "Pending review kill switches"

    static func queueReasonLine(
        killSwitches: [String]
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: queueReasonPrefix,
            values: killSwitches
        ) ?? queueReasonPrefix
    }

    static func line(
        title: String,
        killSwitches: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: title,
            values: killSwitches
        )
    }

    static func activeLine(
        killSwitches: [String]
    ) -> String? {
        line(title: activeLineTitle, killSwitches: killSwitches)
    }

    static func recommendedLine(
        killSwitches: [String]
    ) -> String? {
        line(title: recommendedLineTitle, killSwitches: killSwitches)
    }

    static func suggestedLine(
        killSwitches: [String]
    ) -> String? {
        line(title: suggestedLineTitle, killSwitches: killSwitches)
    }
}

enum DecisionEvolutionPendingReviewPresentationSupport {
    static let reviewWaitingHeadline = "Evolution review is waiting"
    static let mutationWorkspaceHeadline = "Queue mutation workspace is ready"
    static let readOnlyHeadline = "Pending review remains visible from this read-first surface"
    static let releaseHeadline = "Watching the pending review queue"
    static let pilotHeadline = "Pending review is the next blocker"
    static let approveQueueActionTitle = "Approve review queue"
    static let attentionDetailSuffix = "still need review before the queue is clear."
    static let directQueueWorkSuffix = "are ready for direct queue work here."
    static let releasePathCleanSuffix = "still require review before the release path is clean."
    static let beforePromotionSuffix = "still require review before promotion."
    static let stillRequireReviewSuffix = "still require review."
    static let pendingReviewFindingsPrefix = "Pending review findings"
    static let reviewAuditPrefix = "Review audit"
    static let pilotMutationDetail = "Clear or approve the review queue before treating this release path as ready."
    static let pilotReadOnlyDetail = "This surface stays read-first. Open Evolution Control and work the queue there before widening rollout."

    static func attentionDetail(
        pendingReviewCount: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
            pendingReviewCount,
            suffix: attentionDetailSuffix
        )
    }

    static func operatorReason(
        pendingReviewCount: Int,
        allowsMutations: Bool
    ) -> String {
        allowsMutations
            ? DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
                pendingReviewCount,
                suffix: directQueueWorkSuffix
            )
            : DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
                pendingReviewCount,
                suffix: releasePathCleanSuffix
            )
    }

    static func releaseReason(
        pendingReviewCount: Int,
        beforePromotion: Bool
    ) -> String {
        beforePromotion
            ? DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
                pendingReviewCount,
                suffix: beforePromotionSuffix
            )
            : DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
                pendingReviewCount,
                suffix: stillRequireReviewSuffix
            )
    }

    static func pilotDetail(
        allowsMutations: Bool
    ) -> String {
        allowsMutations
            ? pilotMutationDetail
            : pilotReadOnlyDetail
    }

    static func auditFindingsReasonLine(
        auditFindings: [String]
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: pendingReviewFindingsPrefix,
            values: auditFindings
        ) ?? pendingReviewFindingsPrefix
    }

    static func auditLine(
        auditFindings: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: reviewAuditPrefix,
            values: auditFindings
        )
    }

    static func guidanceReasonLines(
        auditFindings: [String],
        killSwitches: [String]
    ) -> [String] {
        var reasons: [String] = []

        if !killSwitches.isEmpty {
            reasons.append(
                DecisionEvolutionKillSwitchPresentationSupport.queueReasonLine(
                    killSwitches: killSwitches
                )
            )
        }

        if !auditFindings.isEmpty {
            reasons.append(
                auditFindingsReasonLine(
                    auditFindings: auditFindings
                )
            )
        }

        return reasons
    }
}

enum DecisionEvolutionRestorabilityPresentationSupport {
    static let waitingForFirstActiveCheckpointHeadline = "Watching for the first active checkpoint"
    static let blockedUntilRestorableHeadline = "Blocked until the active checkpoint is restorable"
    static let watchingRollbackReadinessHeadline = "Watching rollback readiness"
    static let noActiveCheckpointReason = "No active checkpoint is attached to the current release path yet."
    static let blockedReason = "The active checkpoint does not currently have a restorable brain-state snapshot."
    static let pilotHeadline = "The active path is not restorable yet"
    static let pilotDetail = "Open the control surface and recover a checkpoint with a valid brain-state snapshot."

    static func activeCheckpointRestorableReason(
        checkpointID: String?
    ) -> String {
        if let checkpointID {
            return "Active checkpoint \(checkpointID) is restorable."
        }
        return "The active checkpoint is restorable."
    }
}

enum DecisionEvolutionReleaseStagePresentationSupport {
    static let blockedRuntimeGuardrailsHeadline = "Blocked by runtime guardrails"
    static let watchingAuditFindingsHeadline = "Watching audit findings before wider rollout"
    static let readyForGuardedPilotHeadline = "Ready for guarded pilot rollout"
    static let rollbackNotReadyReason = "The active checkpoint does not currently expose a previous checkpoint for rollback."
    static let pilotRuntimeGuardrailsDetail = "Inspect the active checkpoint and its guardrails before trying to widen rollout."
    static let pilotAuditFindingsDetail = "Resolve the active review findings before widening rollout."

    static func auditReasonLines(
        auditFindings: [String]
    ) -> [String] {
        auditFindings
    }
}

enum DecisionEvolutionPrimaryBlocker: Equatable, Sendable {
    case activeKillSwitches
    case recommendedKillSwitches
    case runtimeGuardrails
    case missingActiveCheckpoint
    case nonRestorableActiveCheckpoint
    case pendingReview
    case auditFindings
    case rollbackNotReady
    case ready
}

struct DecisionEvolutionPrimaryBlockerContext: Equatable, Sendable {
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let runtimeBlockers: [String]
    let hasActiveCheckpoint: Bool
    let canRestoreActiveCheckpoint: Bool
    let pendingReviewCount: Int
    let reviewAuditFindings: [String]
    let canRollbackActiveCheckpoint: Bool
}

enum DecisionEvolutionPrimaryBlockerEvaluator {
    static func evaluate(
        _ context: DecisionEvolutionPrimaryBlockerContext
    ) -> DecisionEvolutionPrimaryBlocker {
        orderedPriorities(for: context).first ?? .ready
    }

    static func evaluate(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionPrimaryBlocker {
        let facts = workspace.facts
        return evaluate(
            DecisionEvolutionPrimaryBlockerContext(
                activeKillSwitches: facts.activeKillSwitches,
                recommendedKillSwitches: facts.recommendedKillSwitches,
                runtimeBlockers: [],
                hasActiveCheckpoint: workspace.activePresentation != nil,
                canRestoreActiveCheckpoint: facts.canRestoreActiveCheckpoint,
                pendingReviewCount: facts.pendingReviewCount,
                reviewAuditFindings: workspace.controlSurface.reviewAuditFindings,
                canRollbackActiveCheckpoint: facts.canRollbackActiveCheckpoint
            )
        )
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

    static func orderedPriorities(
        releaseSummary: DecisionSystemReleaseControlSummary,
        reviewAuditFindings: [String]
    ) -> [DecisionEvolutionPrimaryBlocker] {
        let context = DecisionEvolutionPrimaryBlockerContext(
            activeKillSwitches: releaseSummary.activeKillSwitches,
            recommendedKillSwitches: releaseSummary.recommendedKillSwitches,
            runtimeBlockers: stage(from: releaseSummary.headline) == .runtimeGuardrails
                ? releaseSummary.reasons
                : [],
            hasActiveCheckpoint: releaseSummary.activeCheckpointID != nil,
            canRestoreActiveCheckpoint: releaseSummary.canRestoreActiveCheckpoint,
            pendingReviewCount: releaseSummary.pendingReviewCount,
            reviewAuditFindings: reviewAuditFindings,
            canRollbackActiveCheckpoint: releaseSummary.canRollbackActiveCheckpoint
        )
        let fallbackPriorities = orderedPriorities(for: context)

        guard let summaryStage = stage(from: releaseSummary.headline) else {
            return fallbackPriorities
        }

        return [summaryStage] + fallbackPriorities.filter { $0 != summaryStage }
    }

    static func orderedPriorities(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary?,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        canRestoreActiveCheckpoint: Bool,
        canRollbackActiveCheckpoint: Bool
    ) -> [DecisionEvolutionPrimaryBlocker] {
        if let releaseSummary {
            return orderedPriorities(
                releaseSummary: releaseSummary,
                reviewAuditFindings: controlSurface.reviewAuditFindings
            )
        }

        return orderedPriorities(
            for: DecisionEvolutionPrimaryBlockerContext(
                activeKillSwitches: activeKillSwitches,
                recommendedKillSwitches: recommendedKillSwitches,
                runtimeBlockers: [],
                hasActiveCheckpoint: controlSurface.activePresentation != nil,
                canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
                pendingReviewCount: controlSurface.pendingReviewCount,
                reviewAuditFindings: controlSurface.reviewAuditFindings,
                canRollbackActiveCheckpoint: canRollbackActiveCheckpoint
            )
        )
    }

    private static func stage(
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

enum DecisionEvolutionReviewPathPresentationSupport {
    static let queueKillSwitchHeadline = DecisionEvolutionKillSwitchPresentationSupport.queueHeadline
    static let queueKillSwitchReason = DecisionEvolutionKillSwitchPresentationSupport.queueReason
    static let blockedKillSwitchHeadline = DecisionEvolutionKillSwitchPresentationSupport.blockedReviewHeadline
    static let blockedKillSwitchDetail = DecisionEvolutionKillSwitchPresentationSupport.blockedReviewDetail
    static let reviewWaitingHeadline = DecisionEvolutionPendingReviewPresentationSupport.reviewWaitingHeadline
    static let pendingReviewMutationHeadline = DecisionEvolutionPendingReviewPresentationSupport.mutationWorkspaceHeadline
    static let pendingReviewReadOnlyHeadline = DecisionEvolutionPendingReviewPresentationSupport.readOnlyHeadline
    static let recommendedKillSwitchesReleaseReason = DecisionEvolutionKillSwitchPresentationSupport.recommendedReleaseReason
    static let pilotPendingReviewHeadline = DecisionEvolutionPendingReviewPresentationSupport.pilotHeadline
    static let approveReviewQueueActionTitle = DecisionEvolutionPendingReviewPresentationSupport.approveQueueActionTitle
    static let pilotKillSwitchHeadline = DecisionEvolutionKillSwitchPresentationSupport.pilotHeadline
    static let pilotKillSwitchDetail = DecisionEvolutionKillSwitchPresentationSupport.pilotDetail
    static let pilotNotRestorableHeadline = DecisionEvolutionRestorabilityPresentationSupport.pilotHeadline
    static let pilotNotRestorableDetail = DecisionEvolutionRestorabilityPresentationSupport.pilotDetail

    static func attentionPendingReviewDetail(
        pendingReviewCount: Int
    ) -> String {
        DecisionEvolutionPendingReviewPresentationSupport.attentionDetail(
            pendingReviewCount: pendingReviewCount
        )
    }

    static func operatorPendingReviewReason(
        pendingReviewCount: Int,
        allowsMutations: Bool
    ) -> String {
        DecisionEvolutionPendingReviewPresentationSupport.operatorReason(
            pendingReviewCount: pendingReviewCount,
            allowsMutations: allowsMutations
        )
    }

    static func releasePendingReviewReason(
        pendingReviewCount: Int,
        beforePromotion: Bool
    ) -> String {
        DecisionEvolutionPendingReviewPresentationSupport.releaseReason(
            pendingReviewCount: pendingReviewCount,
            beforePromotion: beforePromotion
        )
    }

    static func pilotPendingReviewDetail(
        allowsMutations: Bool
    ) -> String {
        DecisionEvolutionPendingReviewPresentationSupport.pilotDetail(
            allowsMutations: allowsMutations
        )
    }

    static var blockedKillSwitchGuidance: DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: blockedKillSwitchHeadline,
            detail: blockedKillSwitchDetail
        )
    }

    static var queueKillSwitchGuidance: DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: queueKillSwitchHeadline,
            detail: queueKillSwitchReason
        )
    }

    static var pilotKillSwitchGuidance: DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: pilotKillSwitchHeadline,
            detail: pilotKillSwitchDetail
        )
    }

    static var pilotNotRestorableGuidance: DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: pilotNotRestorableHeadline,
            detail: pilotNotRestorableDetail
        )
    }

    static func operatorPendingReviewGuidance(
        pendingReviewCount: Int,
        allowsMutations: Bool
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: allowsMutations
                ? pendingReviewMutationHeadline
                : pendingReviewReadOnlyHeadline,
            detail: operatorPendingReviewReason(
                pendingReviewCount: pendingReviewCount,
                allowsMutations: allowsMutations
            )
        )
    }

    static func pilotPendingReviewGuidance(
        allowsMutations: Bool
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation {
        DecisionEvolutionPrimaryBlockerGuidancePresentation(
            headline: pilotPendingReviewHeadline,
            detail: pilotPendingReviewDetail(
                allowsMutations: allowsMutations
            )
        )
    }

    static func queueKillSwitchReasonLine(
        killSwitches: [String]
    ) -> String {
        DecisionEvolutionKillSwitchPresentationSupport.queueReasonLine(
            killSwitches: killSwitches
        )
    }

    static func queueAuditFindingsReasonLine(
        auditFindings: [String]
    ) -> String {
        DecisionEvolutionPendingReviewPresentationSupport.auditFindingsReasonLine(
            auditFindings: auditFindings
        )
    }
}

struct DecisionEvolutionOperatorGuidance: Equatable, Sendable {
    let headline: String
    let primaryReason: String?
}

struct DecisionEvolutionPrimaryBlockerGuidancePresentation: Equatable, Sendable {
    let headline: String
    let detail: String?
}

struct DecisionEvolutionReleasePathGuidancePresentation: Equatable, Sendable {
    let state: DecisionSystemReleaseState
    let headline: String
    let reasons: [String]
}

enum DecisionEvolutionPrimaryBlockerPresentationSupport {
    static func operatorGuidance(
        blocker: DecisionEvolutionPrimaryBlocker,
        workspace: DecisionEvolutionWorkspaceSnapshot,
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation {
        let facts = workspace.facts

        switch blocker {
        case .activeKillSwitches:
            return DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchGuidance
        case .recommendedKillSwitches:
            return DecisionEvolutionReviewPathPresentationSupport.queueKillSwitchGuidance
        case .runtimeGuardrails:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
                detail: nil
            )
        case .missingActiveCheckpoint:
            if facts.pendingReviewCount == 0,
               facts.killSwitches.isEmpty,
               workspace.controlSurface.reviewAuditFindings.isEmpty {
                return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                    headline: DecisionEvolutionCheckpointRecoverySupport.noPersistedLineageHeadline,
                    detail: nil
                )
            }

            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason
            )
        case .nonRestorableActiveCheckpoint:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.blockedUntilRestorableHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.activeCheckpointNotRestorableReason
            )
        case .pendingReview:
            return DecisionEvolutionReviewPathPresentationSupport.operatorPendingReviewGuidance(
                pendingReviewCount: facts.pendingReviewCount,
                allowsMutations: contract.allowsMutations
            )
        case .auditFindings:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingAuditFindingsHeadline,
                detail: workspace.controlSurface.reviewAuditFindings.first
            )
        case .rollbackNotReady:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingRollbackReadinessHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason
            )
        case .ready:
            if workspace.activePresentation != nil {
                return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                    headline: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointHeadline(
                        source: workspace.controlSurface.activeCheckpointSource
                    ),
                    detail: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointReason(
                        source: workspace.controlSurface.activeCheckpointSource
                    )
                )
            }

            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionCheckpointRecoverySupport.noPersistedLineageHeadline,
                detail: nil
            )
        }
    }

    static func pilotGuidance(
        blocker: DecisionEvolutionPrimaryBlocker,
        primaryReason: String?,
        allowsLocalMutationActions: Bool
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation? {
        switch blocker {
        case .activeKillSwitches, .recommendedKillSwitches:
            return DecisionEvolutionReviewPathPresentationSupport.pilotKillSwitchGuidance
        case .runtimeGuardrails:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
                detail: primaryReason ?? DecisionEvolutionReleaseStagePresentationSupport.pilotRuntimeGuardrailsDetail
            )
        case .missingActiveCheckpoint:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason
            )
        case .nonRestorableActiveCheckpoint:
            return DecisionEvolutionReviewPathPresentationSupport.pilotNotRestorableGuidance
        case .pendingReview:
            return DecisionEvolutionReviewPathPresentationSupport.pilotPendingReviewGuidance(
                allowsMutations: allowsLocalMutationActions
            )
        case .auditFindings:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingAuditFindingsHeadline,
                detail: primaryReason ?? DecisionEvolutionReleaseStagePresentationSupport.pilotAuditFindingsDetail
            )
        case .rollbackNotReady:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingRollbackReadinessHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason
            )
        case .ready:
            return nil
        }
    }

    static func releaseGuidance(
        blocker: DecisionEvolutionPrimaryBlocker,
        blockerSignals: [String],
        controlSurface: DecisionEvolutionControlSurface,
        queueAuditFindings: [String],
        queueKillSwitches: [String]
    ) -> DecisionEvolutionReleasePathGuidancePresentation {
        DecisionEvolutionReleasePathGuidancePresentation(
            state: releaseState(for: blocker),
            headline: releaseHeadline(for: blocker),
            reasons: releaseReasons(
                for: blocker,
                blockerSignals: blockerSignals,
                controlSurface: controlSurface,
                queueAuditFindings: queueAuditFindings,
                queueKillSwitches: queueKillSwitches
            )
        )
    }

    static func releaseState(
        for blocker: DecisionEvolutionPrimaryBlocker
    ) -> DecisionSystemReleaseState {
        switch blocker {
        case .activeKillSwitches, .runtimeGuardrails, .nonRestorableActiveCheckpoint:
            .blocked
        case .recommendedKillSwitches, .missingActiveCheckpoint, .pendingReview, .auditFindings, .rollbackNotReady:
            .watch
        case .ready:
            .ready
        }
    }

    static func releaseHeadline(
        for blocker: DecisionEvolutionPrimaryBlocker
    ) -> String {
        switch blocker {
        case .activeKillSwitches:
            DecisionEvolutionReleasePathPresentationSupport.blockedActiveKillSwitchHeadline
        case .recommendedKillSwitches:
            DecisionEvolutionReleasePathPresentationSupport.watchingRecommendedKillSwitchesHeadline
        case .runtimeGuardrails:
            DecisionEvolutionReleasePathPresentationSupport.blockedRuntimeGuardrailsHeadline
        case .missingActiveCheckpoint:
            DecisionEvolutionReleasePathPresentationSupport.watchingFirstActiveCheckpointHeadline
        case .nonRestorableActiveCheckpoint:
            DecisionEvolutionReleasePathPresentationSupport.blockedUntilRestorableHeadline
        case .pendingReview:
            DecisionEvolutionReleasePathPresentationSupport.watchingPendingReviewHeadline
        case .auditFindings:
            DecisionEvolutionReleasePathPresentationSupport.watchingAuditFindingsHeadline
        case .rollbackNotReady:
            DecisionEvolutionReleasePathPresentationSupport.watchingRollbackReadinessHeadline
        case .ready:
            DecisionEvolutionReleasePathPresentationSupport.readyForGuardedPilotHeadline
        }
    }

    static func releaseReasons(
        for blocker: DecisionEvolutionPrimaryBlocker,
        blockerSignals: [String],
        controlSurface: DecisionEvolutionControlSurface,
        queueAuditFindings: [String],
        queueKillSwitches: [String]
    ) -> [String] {
        switch blocker {
        case .activeKillSwitches:
            return [DecisionEvolutionReleasePathPresentationSupport.activeKillSwitchReason]
        case .recommendedKillSwitches:
            return [DecisionEvolutionReviewPathPresentationSupport.recommendedKillSwitchesReleaseReason]
                + DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                    auditFindings: queueAuditFindings,
                    killSwitches: queueKillSwitches
                )
        case .runtimeGuardrails:
            return blockerSignals
        case .missingActiveCheckpoint:
            return missingActiveCheckpointReleaseReasons(
                controlSurface: controlSurface,
                queueAuditFindings: queueAuditFindings,
                queueKillSwitches: queueKillSwitches
            )
        case .nonRestorableActiveCheckpoint:
            return [DecisionEvolutionReleasePathPresentationSupport.activeCheckpointNotRestorableReason]
        case .pendingReview:
            return [
                DecisionEvolutionReviewPathPresentationSupport.releasePendingReviewReason(
                    pendingReviewCount: controlSurface.pendingReviewCount,
                    beforePromotion: false
                )
            ] + DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                auditFindings: queueAuditFindings,
                killSwitches: queueKillSwitches
            )
        case .auditFindings:
            return DecisionEvolutionReleaseStagePresentationSupport.auditReasonLines(
                auditFindings: controlSurface.reviewAuditFindings
            )
        case .rollbackNotReady:
            return [DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason]
        case .ready:
            return [
                DecisionEvolutionReleasePathPresentationSupport.activeCheckpointRestorableReason(
                    checkpointID: controlSurface.activePresentation?.checkpointID
                )
            ]
        }
    }

    private static func missingActiveCheckpointReleaseReasons(
        controlSurface: DecisionEvolutionControlSurface,
        queueAuditFindings: [String],
        queueKillSwitches: [String]
    ) -> [String] {
        var reasons = [DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason]
        if controlSurface.pendingReviewCount > 0 {
            reasons.append(
                DecisionEvolutionReviewPathPresentationSupport.releasePendingReviewReason(
                    pendingReviewCount: controlSurface.pendingReviewCount,
                    beforePromotion: true
                )
            )
            reasons.append(
                contentsOf: DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                    auditFindings: queueAuditFindings,
                    killSwitches: queueKillSwitches
                )
            )
        }
        return reasons
    }
}

enum DecisionEvolutionOperatorSummaryPresentationSupport {
    static let activePrefix = "Active"
    static let reviewPrefix = "Review"
    static let pendingPrefix = "Pending"
    static let rollbackReadyPrefix = "Rollback-ready"
    static let killSwitchesPrefix = "Kill switches"

    static func surfaceTitle(
        for surfaceKind: DecisionEvolutionSurfaceKind
    ) -> String {
        DecisionEvolutionSurfaceTitleLexiconSupport.title(for: surfaceKind)
    }

    static func checkpointToken(_ checkpointID: String?) -> String {
        DecisionEvolutionCheckpointLexiconSupport.checkpointToken(checkpointID)
    }

    static func modeLine(
        surfaceKind: DecisionEvolutionSurfaceKind,
        interactionMode: DecisionEvolutionControlInteractionMode
    ) -> String {
        "\(surfaceTitle(for: surfaceKind)) • \(interactionMode.operatorHeadline)"
    }

    static func countsLine(
        activeCheckpointID: String?,
        reviewCheckpointID: String?,
        pendingReviewCount: Int,
        rollbackReadyCount: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "\(activePrefix) \(checkpointToken(activeCheckpointID))",
            "\(reviewPrefix) \(checkpointToken(reviewCheckpointID))",
            "\(pendingPrefix) \(pendingReviewCount)",
            "\(rollbackReadyPrefix) \(rollbackReadyCount)"
        ])
    }

    static func killSwitchesLine(
        _ killSwitches: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: killSwitchesPrefix,
            values: killSwitches
        )
    }
}

struct DecisionEvolutionOperatorSummaryPresentation: Equatable, Sendable {
    let headline: String
    let primaryReason: String?
    let modeLine: String
    let countsLine: String
    let killSwitchesLine: String?
}

struct DecisionEvolutionOperatorSnapshot: Equatable, Sendable {
    let surfaceKind: DecisionEvolutionSurfaceKind
    let interactionMode: DecisionEvolutionControlInteractionMode
    let releaseState: DecisionSystemReleaseState?
    let headline: String
    let primaryReason: String?
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let activeCheckpointID: String?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let reviewCheckpointID: String?
    let killSwitches: [String]

    var surfaceTitle: String {
        DecisionEvolutionOperatorSummaryPresentationSupport.surfaceTitle(
            for: surfaceKind
        )
    }

    var operatorHeadline: String {
        interactionMode.operatorHeadline
    }

    var operatorDetail: String {
        interactionMode.operatorDetail
    }

    var summaryPresentation: DecisionEvolutionOperatorSummaryPresentation {
        DecisionEvolutionOperatorSummaryPresentation(
            headline: headline,
            primaryReason: primaryReason,
            modeLine: DecisionEvolutionOperatorSummaryPresentationSupport.modeLine(
                surfaceKind: surfaceKind,
                interactionMode: interactionMode
            ),
            countsLine: DecisionEvolutionOperatorSummaryPresentationSupport.countsLine(
                activeCheckpointID: activeCheckpointID,
                reviewCheckpointID: reviewCheckpointID,
                pendingReviewCount: pendingReviewCount,
                rollbackReadyCount: rollbackReadyCount
            ),
            killSwitchesLine: DecisionEvolutionOperatorSummaryPresentationSupport.killSwitchesLine(
                killSwitches
            )
        )
    }

    static func build(
        surfaceKind: DecisionEvolutionSurfaceKind,
        workspace: DecisionEvolutionWorkspaceSnapshot,
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionOperatorSnapshot {
        let releaseSummary = workspace.releaseSummary
        let operatorGuidance = workspace.operatorGuidance(for: contract)

        return DecisionEvolutionOperatorSnapshot(
            surfaceKind: surfaceKind,
            interactionMode: contract.interactionMode,
            releaseState: releaseSummary?.state,
            headline: releaseSummary?.headline ?? operatorGuidance.headline,
            primaryReason: releaseSummary?.reasons.first ?? operatorGuidance.primaryReason,
            pendingReviewCount: workspace.facts.pendingReviewCount,
            rollbackReadyCount: workspace.facts.rollbackReadyCount,
            activeCheckpointID: workspace.activePresentation?.checkpointID,
            activeCheckpointSource: workspace.controlSurface.activeCheckpointSource,
            reviewCheckpointID: workspace.reviewPresentation?.checkpointID,
            killSwitches: workspace.facts.killSwitches
        )
    }
}

extension DecisionEvolutionWorkspaceSnapshot {
    func operatorGuidance(for contract: DecisionEvolutionSurfaceContract) -> DecisionEvolutionOperatorGuidance {
        if releaseSummary == nil,
           activePresentation != nil,
           controlSurface.activeCheckpointSource != .none,
           facts.pendingReviewCount == 0,
           facts.killSwitches.isEmpty,
           controlSurface.reviewAuditFindings.isEmpty {
            return DecisionEvolutionOperatorGuidance(
                headline: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointHeadline(
                    source: controlSurface.activeCheckpointSource
                ),
                primaryReason: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointReason(
                    source: controlSurface.activeCheckpointSource
                )
            )
        }

        let blocker = DecisionEvolutionPrimaryBlockerEvaluator.evaluate(workspace: self)
        let guidance = DecisionEvolutionPrimaryBlockerPresentationSupport.operatorGuidance(
            blocker: blocker,
            workspace: self,
            contract: contract
        )

        return DecisionEvolutionOperatorGuidance(
            headline: guidance.headline,
            primaryReason: guidance.detail
        )
    }
}
