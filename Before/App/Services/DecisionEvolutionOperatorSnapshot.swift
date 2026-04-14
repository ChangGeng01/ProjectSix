import Foundation

struct DecisionEvolutionOperatorGuidance: Equatable, Sendable {
    let headline: String
    let primaryReason: String?
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
        let facts = self.facts

        if facts.hasPendingReview {
            if contract.allowsMutations,
               facts.hasRecommendedKillSwitches {
                return DecisionEvolutionOperatorGuidance(
                    headline: "Watching queue kill switches",
                    primaryReason: "Queue kill switches remain active until the review path is cleared."
                )
            }

            return DecisionEvolutionOperatorGuidance(
                headline: contract.allowsMutations
                    ? "Queue mutation workspace is ready"
                    : "Pending review remains visible from this read-first surface",
                primaryReason: contract.allowsMutations
                    ? "\(facts.pendingReviewCount) checkpoint(s) are ready for direct queue work here."
                    : "\(facts.pendingReviewCount) checkpoint(s) still require review before the release path is clean."
            )
        }

        if facts.hasRecommendedKillSwitches {
            return DecisionEvolutionOperatorGuidance(
                headline: "Watching queue kill switches",
                primaryReason: "Queue kill switches remain active until the review path is cleared."
            )
        }

        if activePresentation != nil {
            let headline = switch controlSurface.activeCheckpointSource {
            case .pinnedHint:
                "Pinned active checkpoint is visible"
            case .automaticFallback:
                "Recovered active checkpoint is visible"
            case .none:
                "Active checkpoint is visible"
            }

            let primaryReason = switch controlSurface.activeCheckpointSource {
            case .pinnedHint:
                "The host-pinned active checkpoint can be inspected without leaving this surface."
            case .automaticFallback:
                "The recovered automatic checkpoint can be inspected without leaving this surface."
            case .none:
                "The active checkpoint can be inspected without leaving this surface."
            }

            return DecisionEvolutionOperatorGuidance(
                headline: headline,
                primaryReason: primaryReason
            )
        }

        return DecisionEvolutionOperatorGuidance(
            headline: "No persisted checkpoint lineage is attached yet",
            primaryReason: nil
        )
    }
}
