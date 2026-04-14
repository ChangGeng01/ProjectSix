import Foundation

enum DecisionEvolutionAttentionSeverity: String, Equatable, Sendable {
    case none
    case review
    case blocked
    case rollbackWatch
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
        let facts = workspace.facts

        if facts.hasRecommendedKillSwitches {
            return DecisionEvolutionAttentionSignal(
                severity: .blocked,
                badgeValue: "!",
                headline: "Evolution is blocked by active kill switches",
                detail: "Open Evolution Control to clear the blocked review path before release work continues.",
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: facts.recommendedKillSwitches,
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        }

        if facts.hasPendingReview {
            return DecisionEvolutionAttentionSignal(
                severity: .review,
                badgeValue: facts.pendingReviewCount > 9
                    ? "9+"
                    : String(facts.pendingReviewCount),
                headline: "Evolution review is waiting",
                detail: "\(facts.pendingReviewCount) checkpoint(s) still need review before the queue is clear.",
                pendingReviewCount: facts.pendingReviewCount,
                killSwitches: [],
                rollbackReady: facts.canRollbackActiveCheckpoint
            )
        }

        if facts.canRollbackActiveCheckpoint {
            return DecisionEvolutionAttentionSignal(
                severity: .rollbackWatch,
                badgeValue: "↺",
                headline: "Rollback-ready active checkpoint is available",
                detail: "Evolution Control can restore the previous checkpoint without rebuilding the full lineage path.",
                pendingReviewCount: 0,
                killSwitches: [],
                rollbackReady: true
            )
        }

        return DecisionEvolutionAttentionSignal(
            severity: .none,
            badgeValue: nil,
            headline: "Evolution is quiet",
            detail: nil,
            pendingReviewCount: 0,
            killSwitches: [],
            rollbackReady: false
        )
    }
}
