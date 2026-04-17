import Foundation

enum DecisionEvolutionAttentionSeverity: String, Equatable, Sendable {
    case none
    case review
    case blocked
    case rollbackWatch
}

enum DecisionEvolutionAttentionPresentationSupport {
    static let rollbackReadyHeadline = "Rollback-ready active checkpoint is available"
    static let rollbackReadyDetail = "Evolution Control can restore the previous checkpoint without rebuilding the full lineage path."
    static let quietHeadline = "Evolution is quiet"

    static func reviewBadgeValue(
        pendingReviewCount: Int
    ) -> String {
        pendingReviewCount > 9 ? "9+" : String(pendingReviewCount)
    }
}

struct DecisionEvolutionAttentionPresentation: Equatable, Sendable {
    let severity: DecisionEvolutionAttentionSeverity
    let badgeValue: String?
    let headline: String
    let detail: String?
    let pendingReviewCount: Int
    let killSwitches: [String]
    let rollbackReady: Bool

    static func build(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionAttentionPresentation {
        let facts = workspace.facts
        let primaryBlocker = primaryAttentionBlocker(
            workspace: workspace
        )

        switch primaryBlocker {
        case .activeKillSwitches:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchDetail,
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: facts.activeKillSwitches,
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        case .recommendedKillSwitches:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.blockedKillSwitchDetail,
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: facts.recommendedKillSwitches,
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        case .pendingReview:
            return DecisionEvolutionAttentionPresentation(
                severity: .review,
                badgeValue: DecisionEvolutionAttentionPresentationSupport.reviewBadgeValue(
                    pendingReviewCount: facts.pendingReviewCount
                ),
                headline: DecisionEvolutionReviewPathPresentationSupport.reviewWaitingHeadline,
                detail: DecisionEvolutionReviewPathPresentationSupport.attentionPendingReviewDetail(
                    pendingReviewCount: facts.pendingReviewCount
                ),
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: [],
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        case .runtimeGuardrails:
            return DecisionEvolutionAttentionPresentation(
                severity: .blocked,
                badgeValue: "!",
                headline: DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline,
                detail: workspace.releaseSummary?.reasons.first,
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: [],
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        case .missingActiveCheckpoint,
                .nonRestorableActiveCheckpoint,
                .auditFindings,
                .rollbackNotReady,
                .ready:
            if facts.canRollbackActiveCheckpoint {
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

    private static func primaryAttentionBlocker(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionPrimaryBlocker {
        if let releaseSummary = workspace.releaseSummary {
            return DecisionEvolutionPrimaryBlockerEvaluator.orderedPriorities(
                releaseSummary: releaseSummary,
                reviewAuditFindings: workspace.controlSurface.reviewAuditFindings
            ).first ?? .ready
        }

        let facts = workspace.facts
        if !facts.activeKillSwitches.isEmpty {
            return .activeKillSwitches
        }

        if !facts.recommendedKillSwitches.isEmpty {
            return .recommendedKillSwitches
        }

        if facts.pendingReviewCount > 0 {
            return .pendingReview
        }

        return DecisionEvolutionPrimaryBlockerEvaluator.evaluate(
            workspace: workspace
        )
    }
}

struct DecisionEvolutionAttentionSignal: Equatable, Sendable {
    let severity: DecisionEvolutionAttentionSeverity
    let badgeValue: String?
    let headline: String
    let detail: String?
    let pendingReviewCount: Int
    let killSwitches: [String]
    let rollbackReady: Bool

    var requiresAttention: Bool {
        severity != .none
    }

    static func build(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionAttentionSignal {
        let presentation = DecisionEvolutionAttentionPresentation.build(
            workspace: workspace
        )

        return DecisionEvolutionAttentionSignal(
            severity: presentation.severity,
            badgeValue: presentation.badgeValue,
            headline: presentation.headline,
            detail: presentation.detail,
            pendingReviewCount: presentation.pendingReviewCount,
            killSwitches: presentation.killSwitches,
            rollbackReady: presentation.rollbackReady
        )
    }
}
