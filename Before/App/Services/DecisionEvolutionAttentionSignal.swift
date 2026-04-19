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
        workspace.policy().attentionPresentation()
    }

    static func build(
        policy: DecisionEvolutionPolicyOutput
    ) -> DecisionEvolutionAttentionPresentation {
        policy.attentionPresentation()
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

    func resolvedTriggerReason(
        fallback: String?
    ) -> String? {
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDetail, !trimmedDetail.isEmpty {
            return trimmedDetail
        }
        return fallback
    }

    static func build(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionAttentionSignal {
        build(
            policy: workspace.policy()
        )
    }

    static func build(
        policy: DecisionEvolutionPolicyOutput
    ) -> DecisionEvolutionAttentionSignal {
        let presentation = DecisionEvolutionAttentionPresentation.build(
            policy: policy
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
