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
    let routesMutationsToControlCenter: Bool

    var allowsMutations: Bool {
        !routesMutationsToControlCenter
    }

    var showsControlCenterShortcut: Bool {
        routesMutationsToControlCenter
    }

    var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        switch kind {
        case .home, .settings:
            navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        case .history:
            navigationSurfaceOptions(showPortraitShortcut: true)
        case .portrait:
            navigationSurfaceOptions(showHistoryShortcut: true)
        case .controlCenter:
            navigationSurfaceOptions()
        }
    }

    static let home = DecisionEvolutionSurfaceContract(
        kind: .home,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let history = DecisionEvolutionSurfaceContract(
        kind: .history,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let portrait = DecisionEvolutionSurfaceContract(
        kind: .portrait,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let settings = DecisionEvolutionSurfaceContract(
        kind: .settings,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false,
        routesMutationsToControlCenter: true
    )

    static let controlCenter = DecisionEvolutionSurfaceContract(
        kind: .controlCenter,
        interactionMode: .mutationHub,
        releaseSummaryMode: .mutationHub,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false,
        routesMutationsToControlCenter: false
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

    func summarySurfaceOptions(
        showCheckpointActionBar overrideShowCheckpointActionBar: Bool? = nil,
        showControlCenterShortcut overrideShowControlCenterShortcut: Bool? = nil,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false
    ) -> DecisionEvolutionSummarySurfaceOptions {
        let navigationOptions = navigationSurfaceOptions(
            showControlCenterShortcut: overrideShowControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
        return DecisionEvolutionSummarySurfaceOptions(
            showCheckpointActionBar: overrideShowCheckpointActionBar ?? showsCheckpointActionBarInSummary,
            showControlCenterShortcut: navigationOptions.showControlCenterShortcut,
            showHistoryShortcut: navigationOptions.showHistoryShortcut,
            showPortraitShortcut: navigationOptions.showPortraitShortcut
        )
    }

    func summarySurfaceOptions(
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        showCheckpointActionBar overrideShowCheckpointActionBar: Bool? = nil
    ) -> DecisionEvolutionSummarySurfaceOptions {
        DecisionEvolutionSummarySurfaceOptions(
            showCheckpointActionBar: overrideShowCheckpointActionBar ?? showsCheckpointActionBarInSummary,
            showControlCenterShortcut: navigationOptions.showControlCenterShortcut,
            showHistoryShortcut: navigationOptions.showHistoryShortcut,
            showPortraitShortcut: navigationOptions.showPortraitShortcut
        )
    }

    func navigationSurfaceOptions(
        showControlCenterShortcut overrideShowControlCenterShortcut: Bool? = nil,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false
    ) -> DecisionEvolutionNavigationSurfaceOptions {
        DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: overrideShowControlCenterShortcut ?? showsControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
    }
}

struct DecisionEvolutionNavigationSurfaceOptions: Equatable, Sendable {
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool

    var showsAnyShortcut: Bool {
        showControlCenterShortcut || showHistoryShortcut || showPortraitShortcut
    }

    var preferredDestination: DecisionEvolutionNavigationDestination? {
        if showControlCenterShortcut {
            return .controlCenter
        }

        if showHistoryShortcut {
            return .history
        }

        if showPortraitShortcut {
            return .portrait
        }

        return nil
    }
}

enum DecisionEvolutionNavigationDestination: String, Equatable, Sendable {
    case controlCenter
    case history
    case portrait

    func actionTitle(routesMutationsToControlCenter: Bool) -> String {
        switch self {
        case .controlCenter:
            return routesMutationsToControlCenter ? "Open control center" : "Control center"
        case .history:
            return "Open History"
        case .portrait:
            return "Open Portrait"
        }
    }
}

struct DecisionEvolutionSummarySurfaceOptions: Equatable, Sendable {
    let showCheckpointActionBar: Bool
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool

    var navigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: showControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
    }
}
