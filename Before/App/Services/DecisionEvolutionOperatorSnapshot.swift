import Foundation

struct DecisionEvolutionOperatorSnapshot: Equatable, Sendable {
    let surfaceKind: DecisionEvolutionSurfaceKind
    let interactionMode: DecisionEvolutionControlInteractionMode
    let releaseState: DecisionSystemReleaseState?
    let headline: String
    let primaryReason: String?
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let activeCheckpointID: String?
    let reviewCheckpointID: String?
    let killSwitches: [String]

    var surfaceTitle: String {
        switch surfaceKind {
        case .home:
            "Home runtime"
        case .history:
            "History workbench"
        case .portrait:
            "Portrait overview"
        case .settings:
            "Settings monitor"
        case .controlCenter:
            "Evolution Control"
        }
    }

    var operatorHeadline: String {
        interactionMode.operatorHeadline
    }

    var operatorDetail: String {
        interactionMode.operatorDetail
    }

    static func build(
        surfaceKind: DecisionEvolutionSurfaceKind,
        workspace: DecisionEvolutionWorkspaceSnapshot,
        contract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionOperatorSnapshot {
        let releaseSummary = workspace.releaseSummary

        return DecisionEvolutionOperatorSnapshot(
            surfaceKind: surfaceKind,
            interactionMode: contract.interactionMode,
            releaseState: releaseSummary?.state,
            headline: releaseSummary?.headline
                ?? fallbackHeadline(for: workspace.controlSurface, contract: contract),
            primaryReason: releaseSummary?.reasons.first
                ?? fallbackReason(for: workspace.controlSurface, contract: contract),
            pendingReviewCount: workspace.controlSurface.pendingReviewCount,
            rollbackReadyCount: workspace.controlSurface.rollbackReadyCount,
            activeCheckpointID: workspace.activePresentation?.checkpointID,
            reviewCheckpointID: workspace.reviewPresentation?.checkpointID,
            killSwitches: releaseSummary?.killSwitches ?? workspace.controlSurface.queueKillSwitches
        )
    }

    private static func fallbackHeadline(
        for controlSurface: DecisionEvolutionControlSurface,
        contract: DecisionEvolutionSurfaceContract
    ) -> String {
        if controlSurface.pendingReviewCount > 0 {
            if contract.interactionMode.allowsMutations,
               !controlSurface.queueKillSwitches.isEmpty {
                return "Watching queue kill switches"
            }

            return contract.interactionMode.allowsMutations
                ? "Queue mutation workspace is ready"
                : "Pending review remains visible from this read-first surface"
        }

        if !controlSurface.queueKillSwitches.isEmpty {
            return "Watching queue kill switches"
        }

        if controlSurface.activePresentation != nil {
            return "Recovered active checkpoint is visible"
        }

        return "No persisted checkpoint lineage is attached yet"
    }

    private static func fallbackReason(
        for controlSurface: DecisionEvolutionControlSurface,
        contract: DecisionEvolutionSurfaceContract
    ) -> String? {
        if controlSurface.pendingReviewCount > 0 {
            if contract.interactionMode.allowsMutations,
               !controlSurface.queueKillSwitches.isEmpty {
                return "Queue kill switches remain active until the review path is cleared."
            }

            return contract.interactionMode.allowsMutations
                ? "\(controlSurface.pendingReviewCount) checkpoint(s) are ready for direct queue work here."
                : "\(controlSurface.pendingReviewCount) checkpoint(s) still require review before the release path is clean."
        }

        if !controlSurface.queueKillSwitches.isEmpty {
            return "Queue kill switches remain active until the review path is cleared."
        }

        if controlSurface.activePresentation != nil {
            return "The active checkpoint can be inspected without leaving this surface."
        }

        return nil
    }
}
