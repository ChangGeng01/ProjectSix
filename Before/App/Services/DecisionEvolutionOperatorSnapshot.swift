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
        killSwitches: [String],
        courtLines: [String] = []
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

        courtLines.forEach { courtLine in
            guard !reasons.contains(courtLine) else { return }
            reasons.append(courtLine)
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
        DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(context)
        ).primaryBlocker
    }

    static func evaluate(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionPrimaryBlocker {
        workspace.policy().primaryBlocker
    }

    static func orderedPriorities(
        for context: DecisionEvolutionPrimaryBlockerContext
    ) -> [DecisionEvolutionPrimaryBlocker] {
        DecisionEvolutionPolicyEngine.orderedPriorities(for: context)
    }

    static func orderedPriorities(
        releaseSummary: DecisionSystemReleaseControlSummary,
        reviewAuditFindings: [String]
    ) -> [DecisionEvolutionPrimaryBlocker] {
        DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyInput(
                activeCheckpointID: releaseSummary.activeCheckpointID,
                activeCheckpointSource: releaseSummary.activeCheckpointSource,
                pendingReviewCount: releaseSummary.pendingReviewCount,
                pendingReviewLineageCount: 0,
                canRestoreActiveCheckpoint: releaseSummary.canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: releaseSummary.canRollbackActiveCheckpoint,
                hasRollbackTarget: false,
                activeKillSwitches: releaseSummary.activeKillSwitches,
                recommendedKillSwitches: releaseSummary.recommendedKillSwitches,
                reviewAuditFindings: reviewAuditFindings,
                queueAuditFindings: reviewAuditFindings,
                queueKillSwitches: releaseSummary.recommendedKillSwitches,
                runtimeBlockerSignals: DecisionEvolutionPolicyEngine.preferredPrimaryBlocker(
                    from: releaseSummary
                ) == .runtimeGuardrails
                    ? releaseSummary.reasons
                    : [],
                allowsLocalMutationActions: false,
                preferredPrimaryBlocker: DecisionEvolutionPolicyEngine.preferredPrimaryBlocker(
                    from: releaseSummary
                )
            )
        ).blockerOrder
    }

    static func orderedPriorities(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary?,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        canRestoreActiveCheckpoint: Bool,
        canRollbackActiveCheckpoint: Bool
    ) -> [DecisionEvolutionPrimaryBlocker] {
        DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: releaseSummary,
                activeKillSwitches: activeKillSwitches,
                recommendedKillSwitches: recommendedKillSwitches,
                canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: canRollbackActiveCheckpoint
            )
        ).blockerOrder
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
        input: DecisionEvolutionPolicyInput,
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation {
        if input.hasActiveCheckpoint,
           input.activeCheckpointSource != .none,
           input.pendingReviewCount == 0,
           input.activeKillSwitches.isEmpty,
           input.recommendedKillSwitches.isEmpty,
           input.reviewAuditFindings.isEmpty,
           input.runtimeBlockerSignals.isEmpty {
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointHeadline(
                    source: input.activeCheckpointSource
                ),
                detail: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointReason(
                    source: input.activeCheckpointSource
                )
            )
        }

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
            if input.pendingReviewCount == 0,
               input.activeKillSwitches.isEmpty,
               input.recommendedKillSwitches.isEmpty,
               input.reviewAuditFindings.isEmpty {
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
                pendingReviewCount: input.pendingReviewCount,
                allowsMutations: contract.allowsMutations
            )
        case .auditFindings:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingAuditFindingsHeadline,
                detail: input.reviewAuditFindings.first
            )
        case .rollbackNotReady:
            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionReleasePathPresentationSupport.watchingRollbackReadinessHeadline,
                detail: DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason
            )
        case .ready:
            if input.hasActiveCheckpoint {
                return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                    headline: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointHeadline(
                        source: input.activeCheckpointSource
                    ),
                    detail: DecisionEvolutionCheckpointRecoverySupport.activeCheckpointReason(
                        source: input.activeCheckpointSource
                    )
                )
            }

            return DecisionEvolutionPrimaryBlockerGuidancePresentation(
                headline: DecisionEvolutionCheckpointRecoverySupport.noPersistedLineageHeadline,
                detail: nil
            )
        }
    }

    static func operatorGuidance(
        blocker: DecisionEvolutionPrimaryBlocker,
        workspace: DecisionEvolutionWorkspaceSnapshot,
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionPrimaryBlockerGuidancePresentation {
        operatorGuidance(
            blocker: blocker,
            input: DecisionEvolutionPolicyEngine.input(
                workspace: workspace,
                allowsLocalMutationActions: contract.allowsMutations
            ),
            contract: contract
        )
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
        input: DecisionEvolutionPolicyInput
    ) -> DecisionEvolutionReleasePathGuidancePresentation {
        DecisionEvolutionReleasePathGuidancePresentation(
            state: releaseState(for: blocker),
            headline: releaseHeadline(for: blocker),
            reasons: releaseReasons(
                for: blocker,
                input: input
            )
        )
    }

    static func releaseGuidance(
        blocker: DecisionEvolutionPrimaryBlocker,
        blockerSignals: [String],
        controlSurface: DecisionEvolutionControlSurface,
        queueAuditFindings: [String],
        queueKillSwitches: [String]
    ) -> DecisionEvolutionReleasePathGuidancePresentation {
        releaseGuidance(
            blocker: blocker,
            input: DecisionEvolutionPolicyInput(
                activeCheckpointID: controlSurface.activePresentation?.checkpointID,
                activeCheckpointSource: controlSurface.activeCheckpointSource,
                pendingReviewCount: controlSurface.pendingReviewCount,
                pendingReviewLineageCount: controlSurface.pendingReviewLineagePresentations.count,
                canRestoreActiveCheckpoint: controlSurface.activePresentation?.applyReady == true,
                canRollbackActiveCheckpoint: controlSurface.canRollbackActiveCheckpoint,
                hasRollbackTarget: controlSurface.activeRollbackCheckpointID != nil,
                activeKillSwitches: controlSurface.activeKillSwitches,
                recommendedKillSwitches: queueKillSwitches,
                reviewAuditFindings: controlSurface.reviewAuditFindings,
                queueAuditFindings: queueAuditFindings,
                queueKillSwitches: queueKillSwitches,
                runtimeBlockerSignals: blockerSignals,
                allowsLocalMutationActions: false,
                preferredPrimaryBlocker: nil
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
        input: DecisionEvolutionPolicyInput
    ) -> [String] {
        switch blocker {
        case .activeKillSwitches:
            return [DecisionEvolutionReleasePathPresentationSupport.activeKillSwitchReason]
        case .recommendedKillSwitches:
            return [DecisionEvolutionReviewPathPresentationSupport.recommendedKillSwitchesReleaseReason]
                + DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                    auditFindings: input.queueAuditFindings,
                    killSwitches: input.queueKillSwitches
                )
        case .runtimeGuardrails:
            return input.runtimeBlockerSignals
        case .missingActiveCheckpoint:
            return missingActiveCheckpointReleaseReasons(input: input)
        case .nonRestorableActiveCheckpoint:
            return [DecisionEvolutionReleasePathPresentationSupport.activeCheckpointNotRestorableReason]
        case .pendingReview:
            return [
                DecisionEvolutionReviewPathPresentationSupport.releasePendingReviewReason(
                    pendingReviewCount: input.pendingReviewCount,
                    beforePromotion: false
                )
            ] + DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                auditFindings: input.queueAuditFindings,
                killSwitches: input.queueKillSwitches
            )
        case .auditFindings:
            return DecisionEvolutionReleaseStagePresentationSupport.auditReasonLines(
                auditFindings: input.reviewAuditFindings
            )
        case .rollbackNotReady:
            return [DecisionEvolutionReleasePathPresentationSupport.rollbackNotReadyReason]
        case .ready:
            return [
                DecisionEvolutionReleasePathPresentationSupport.activeCheckpointRestorableReason(
                    checkpointID: input.activeCheckpointID
                )
            ]
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
                    killSwitches: queueKillSwitches,
                    courtLines: controlSurface.queueCourtLines
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
                killSwitches: queueKillSwitches,
                courtLines: controlSurface.queueCourtLines
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
        input: DecisionEvolutionPolicyInput
    ) -> [String] {
        var reasons = [DecisionEvolutionReleasePathPresentationSupport.noActiveCheckpointReason]
        if input.pendingReviewCount > 0 {
            reasons.append(
                DecisionEvolutionReviewPathPresentationSupport.releasePendingReviewReason(
                    pendingReviewCount: input.pendingReviewCount,
                    beforePromotion: true
                )
            )
            reasons.append(
                contentsOf: DecisionEvolutionPendingReviewPresentationSupport.guidanceReasonLines(
                    auditFindings: input.queueAuditFindings,
                    killSwitches: input.queueKillSwitches
                )
            )
        }
        return reasons
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
                    killSwitches: queueKillSwitches,
                    courtLines: controlSurface.queueCourtLines
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
    let sovereignPostureTitle: String?
    let sovereignPostureLines: [String]
    let horizonDiagnosticsTitle: String?
    let horizonDiagnosticsLines: [String]
    let presenceTitle: String?
    let presenceLines: [String]
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let furnaceContributionTitle: String?
    let furnaceContributionLines: [String]
    let furnaceChecklistTitle: String?
    let furnaceChecklistLines: [String]
    let furnaceNextStepTitle: String?
    let furnaceNextStepDetail: String?
    let furnaceNextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation?
    let furnaceWorkbenchPresentation: DecisionEvolutionFurnaceWorkbenchPresentation?
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
    let presenceLine: String?
    let summaryReasons: [String]
    let furnacePresentationBundle: DecisionEvolutionFurnacePresentationBundle?

    var furnaceWorkbenchPresentation: DecisionEvolutionFurnaceWorkbenchPresentation? {
        furnacePresentationBundle?.review.workbenchPresentation
    }

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
        let sovereignPostureLines = DecisionEvolutionSovereignPosturePresentationSupport.lines(
            from: summaryReasons
        )
        let horizonDiagnosticsLines = DecisionEvolutionHorizonDiagnosticsPresentationSupport.lines(
            from: summaryReasons
        )
        let presenceLines = DecisionEvolutionPresencePresentationSupport.lines(
            presenceLine: presenceLine,
            reasons: summaryReasons
        )
        let foldedLungLines = DecisionEvolutionFoldedLungPresentationSupport.lines(
            from: summaryReasons
        )
        let furnaceContributionSection = furnacePresentationBundle?.contributionSection
            ?? {
                let lines = DecisionEvolutionFurnaceContributionPresentationSupport.lines(
                    from: summaryReasons
                )
                return lines.isEmpty
                    ? nil
                    : DecisionEvolutionFurnaceLinesSectionPresentation(
                        title: DecisionEvolutionFurnaceContributionPresentationSupport.title,
                        lines: lines
                    )
            }()
        let furnaceChecklistSection = furnacePresentationBundle?.review.checklistSection
            ?? {
                let lines = DecisionEvolutionFurnaceChecklistPresentationSupport.lines(
                    from: summaryReasons
                )
                return lines.isEmpty
                    ? nil
                    : DecisionEvolutionFurnaceLinesSectionPresentation(
                        title: DecisionEvolutionFurnaceChecklistPresentationSupport.title,
                        lines: lines
                    )
            }()
        let furnaceNextStepSection = furnacePresentationBundle?.review.nextStepSection
            ?? {
                let detail = furnaceWorkbenchPresentation?.detail
                    ?? DecisionEvolutionFurnaceNextStepPresentationSupport.detail(
                        from: furnaceChecklistSection?.lines ?? []
                    )
                let action = furnaceWorkbenchPresentation?.nextStepAction

                return detail.map {
                    DecisionEvolutionFurnaceNextStepSectionPresentation(
                        title: DecisionEvolutionFurnaceNextStepPresentationSupport.title,
                        detail: $0,
                        action: action
                    )
                }
            }()
        let furnaceContributionLines = furnaceContributionSection?.lines ?? []
        let furnaceChecklistLines = furnaceChecklistSection?.lines ?? []
        let furnaceNextStepDetail = furnaceNextStepSection?.detail
        let furnaceNextStepAction = furnaceNextStepSection?.action

        return DecisionEvolutionOperatorSummaryPresentation(
            headline: headline,
            primaryReason: primaryReason,
            sovereignPostureTitle: sovereignPostureLines.isEmpty
                ? nil
                : DecisionEvolutionSovereignPosturePresentationSupport.title,
            sovereignPostureLines: sovereignPostureLines,
            horizonDiagnosticsTitle: horizonDiagnosticsLines.isEmpty
                ? nil
                : DecisionEvolutionHorizonDiagnosticsPresentationSupport.title,
            horizonDiagnosticsLines: horizonDiagnosticsLines,
            presenceTitle: presenceLines.isEmpty
                ? nil
                : DecisionEvolutionPresencePresentationSupport.title,
            presenceLines: presenceLines,
            foldedLungTitle: foldedLungLines.isEmpty
                ? nil
                : DecisionEvolutionFoldedLungPresentationSupport.title,
            foldedLungLines: foldedLungLines,
            furnaceContributionTitle: furnaceContributionSection?.title,
            furnaceContributionLines: furnaceContributionLines,
            furnaceChecklistTitle: furnaceChecklistSection?.title,
            furnaceChecklistLines: furnaceChecklistLines,
            furnaceNextStepTitle: furnaceNextStepSection?.title,
            furnaceNextStepDetail: furnaceNextStepDetail,
            furnaceNextStepAction: furnaceNextStepAction,
            furnaceWorkbenchPresentation: furnaceWorkbenchPresentation,
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
        build(
            surfaceKind: surfaceKind,
            workspace: workspace,
            contract: contract,
            policy: workspace.policy(for: contract)
        )
    }

    static func build(
        surfaceKind: DecisionEvolutionSurfaceKind,
        workspace: DecisionEvolutionWorkspaceSnapshot,
        contract: DecisionEvolutionSurfaceContract,
        policy: DecisionEvolutionPolicyOutput
    ) -> DecisionEvolutionOperatorSnapshot {
        let releaseSummary = workspace.releaseSummary
        let operatorGuidance = policy.operatorGuidance(contract: contract)
        let furnacePresentationBundle = releaseSummary.map { releaseSummary in
            DecisionEvolutionFurnacePresentationSupport.build(
                releaseSummary: releaseSummary,
                controlSurface: workspace.controlSurface,
                surfaceContract: contract
            )
        }

        return DecisionEvolutionOperatorSnapshot(
            surfaceKind: surfaceKind,
            interactionMode: contract.interactionMode,
            releaseState: releaseSummary?.state,
            headline: releaseSummary?.headline ?? operatorGuidance.headline,
            primaryReason: releaseSummary.map {
                DecisionEvolutionPrimaryReasonPresentationSupport.primaryReason(
                    from: $0.reasons
                )
            } ?? operatorGuidance.primaryReason,
            pendingReviewCount: workspace.facts.pendingReviewCount,
            rollbackReadyCount: workspace.facts.rollbackReadyCount,
            activeCheckpointID: workspace.activePresentation?.checkpointID,
            activeCheckpointSource: workspace.controlSurface.activeCheckpointSource,
            reviewCheckpointID: workspace.reviewPresentation?.checkpointID,
            killSwitches: workspace.facts.killSwitches,
            presenceLine: releaseSummary?.presenceLine,
            summaryReasons: releaseSummary?.reasons ?? [],
            furnacePresentationBundle: furnacePresentationBundle
        )
    }
}

extension DecisionEvolutionWorkspaceSnapshot {
    func operatorGuidance(for contract: DecisionEvolutionSurfaceContract) -> DecisionEvolutionOperatorGuidance {
        policy(
            for: contract
        ).operatorGuidance(
            contract: contract
        )
    }
}
