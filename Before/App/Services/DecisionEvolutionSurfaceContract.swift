import Foundation

enum DecisionEvolutionSurfaceKind: String, CaseIterable, Equatable, Sendable {
    case home
    case history
    case portrait
    case settings
    case controlCenter
}

struct DecisionEvolutionSurfaceContract: Equatable, Sendable {
    let kind: DecisionEvolutionSurfaceKind
    let interactionMode: DecisionEvolutionControlInteractionMode
    let releaseSummaryMode: DecisionEvolutionReleaseSummaryPresentationMode
    let showsEmbeddedReleaseSummaryInPilotPanel: Bool
    let showsCheckpointActionBarInSummary: Bool

    var routesMutationsToControlCenter: Bool {
        !interactionMode.allowsMutations
    }

    static let home = DecisionEvolutionSurfaceContract(
        kind: .home,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true
    )

    static let history = DecisionEvolutionSurfaceContract(
        kind: .history,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true
    )

    static let portrait = DecisionEvolutionSurfaceContract(
        kind: .portrait,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true
    )

    static let settings = DecisionEvolutionSurfaceContract(
        kind: .settings,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false
    )

    static let controlCenter = DecisionEvolutionSurfaceContract(
        kind: .controlCenter,
        interactionMode: .mutationHub,
        releaseSummaryMode: .mutationHub,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false
    )

    static func contract(for kind: DecisionEvolutionSurfaceKind) -> DecisionEvolutionSurfaceContract {
        switch kind {
        case .home:
            .home
        case .history:
            .history
        case .portrait:
            .portrait
        case .settings:
            .settings
        case .controlCenter:
            .controlCenter
        }
    }
}
