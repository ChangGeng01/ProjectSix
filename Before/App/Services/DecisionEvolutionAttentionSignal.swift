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
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionAttentionSignal {
        if !controlSurface.queueKillSwitches.isEmpty {
            return DecisionEvolutionAttentionSignal(
                severity: .blocked,
                badgeValue: "!",
                headline: "Evolution is blocked by active kill switches",
                detail: "Open Evolution Control to clear the blocked review path before release work continues.",
                pendingReviewCount: controlSurface.pendingReviewCount,
                killSwitches: controlSurface.queueKillSwitches,
                rollbackReady: controlSurface.canRollbackActiveCheckpoint
            )
        }

        if controlSurface.pendingReviewCount > 0 {
            return DecisionEvolutionAttentionSignal(
                severity: .review,
                badgeValue: controlSurface.pendingReviewCount > 9
                    ? "9+"
                    : String(controlSurface.pendingReviewCount),
                headline: "Evolution review is waiting",
                detail: "\(controlSurface.pendingReviewCount) checkpoint(s) still need review before the queue is clear.",
                pendingReviewCount: controlSurface.pendingReviewCount,
                killSwitches: [],
                rollbackReady: controlSurface.canRollbackActiveCheckpoint
            )
        }

        if controlSurface.canRollbackActiveCheckpoint {
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
