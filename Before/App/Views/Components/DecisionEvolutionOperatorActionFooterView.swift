import SwiftUI

struct DecisionEvolutionOperatorActionFooterView: View {
    let presentation: DecisionEvolutionOperatorFooterPresentation

    init(
        interactionMode: DecisionEvolutionControlInteractionMode,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool,
        showsDetail: Bool = true,
        controlCenterStyle: BeforeActionButton.Style = .primary,
        adjacentShortcutStyle: BeforeActionButton.Style = .secondary
    ) {
        self.presentation = DecisionEvolutionOperatorFooterPresentation(
            headline: interactionMode.operatorHeadline,
            detail: interactionMode.operatorDetail,
            interactionMode: interactionMode,
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: routesMutationsToControlCenter,
            showsDetail: showsDetail,
            controlCenterStyle: controlCenterStyle.role,
            adjacentShortcutStyle: adjacentShortcutStyle.role
        )
    }

    init(presentation: DecisionEvolutionOperatorFooterPresentation) {
        self.presentation = presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            if presentation.showsDetail {
                Text(presentation.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if presentation.navigationOptions.showsAnyShortcut {
                DecisionEvolutionNavigationActionRow(presentation: presentation.navigationRowPresentation)
            }
        }
    }
}

private extension BeforeActionButton.Style {
    var role: DecisionEvolutionOperatorFooterStyleRole {
        switch self {
        case .primary:
            .primary
        case .secondary:
            .secondary
        case .tertiary:
            .tertiary
        }
    }
}
