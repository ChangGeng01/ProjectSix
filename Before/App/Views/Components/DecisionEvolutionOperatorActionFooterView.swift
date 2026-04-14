import SwiftUI

struct DecisionEvolutionOperatorActionFooterView: View {
    let interactionMode: DecisionEvolutionControlInteractionMode
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let routesMutationsToControlCenter: Bool
    let showsDetail: Bool
    let controlCenterStyle: BeforeActionButton.Style
    let adjacentShortcutStyle: BeforeActionButton.Style

    init(
        interactionMode: DecisionEvolutionControlInteractionMode,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool,
        showsDetail: Bool = true,
        controlCenterStyle: BeforeActionButton.Style = .primary,
        adjacentShortcutStyle: BeforeActionButton.Style = .secondary
    ) {
        self.interactionMode = interactionMode
        self.navigationOptions = navigationOptions
        self.routesMutationsToControlCenter = routesMutationsToControlCenter
        self.showsDetail = showsDetail
        self.controlCenterStyle = controlCenterStyle
        self.adjacentShortcutStyle = adjacentShortcutStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(interactionMode.operatorHeadline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            if showsDetail {
                Text(interactionMode.operatorDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if navigationOptions.showsAnyShortcut {
                DecisionEvolutionNavigationActionRow(
                    navigationOptions: navigationOptions,
                    routesMutationsToControlCenter: routesMutationsToControlCenter,
                    controlCenterStyle: controlCenterStyle,
                    adjacentShortcutStyle: adjacentShortcutStyle
                )
            }
        }
    }
}
