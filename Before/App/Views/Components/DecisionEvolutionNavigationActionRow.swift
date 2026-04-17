import SwiftUI

struct DecisionEvolutionNavigationActionRow: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let routesMutationsToControlCenter: Bool
    let controlCenterTitle: String
    let controlCenterStyle: BeforeActionButton.Style
    let adjacentShortcutStyle: BeforeActionButton.Style
    let historyTitle: String
    let portraitTitle: String

    init(
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        routesMutationsToControlCenter: Bool = true,
        controlCenterTitle: String? = nil,
        controlCenterStyle: BeforeActionButton.Style = .primary,
        adjacentShortcutStyle: BeforeActionButton.Style = .secondary,
        historyTitle: String = DecisionEvolutionNavigationRowPresentationSupport.historyTitle,
        portraitTitle: String = DecisionEvolutionNavigationRowPresentationSupport.portraitTitle
    ) {
        self.navigationOptions = navigationOptions
        self.routesMutationsToControlCenter = routesMutationsToControlCenter
        self.controlCenterTitle = controlCenterTitle
            ?? DecisionEvolutionNavigationDestination.controlCenter.actionTitle(
                routesMutationsToControlCenter: routesMutationsToControlCenter
            )
        self.controlCenterStyle = controlCenterStyle
        self.adjacentShortcutStyle = adjacentShortcutStyle
        self.historyTitle = historyTitle
        self.portraitTitle = portraitTitle
    }

    init(presentation: DecisionEvolutionNavigationRowPresentation) {
        self.init(
            navigationOptions: presentation.navigationOptions,
            routesMutationsToControlCenter: presentation.routesMutationsToControlCenter,
            controlCenterTitle: presentation.controlCenterTitle,
            controlCenterStyle: presentation.controlCenterStyle.buttonStyle,
            adjacentShortcutStyle: presentation.adjacentShortcutStyle.buttonStyle,
            historyTitle: presentation.historyTitle,
            portraitTitle: presentation.portraitTitle
        )
    }

    var body: some View {
        if navigationOptions.showsAnyShortcut {
            HStack(spacing: 10) {
                if navigationOptions.showControlCenterShortcut {
                    BeforeActionButton(controlCenterTitle, style: controlCenterStyle) {
                        DecisionEvolutionNavigationDestination.controlCenter.perform(using: appModel)
                    }
                }

                if navigationOptions.showHistoryShortcut {
                    BeforeActionButton(historyTitle, style: adjacentShortcutStyle) {
                        DecisionEvolutionNavigationDestination.history.perform(using: appModel)
                    }
                }

                if navigationOptions.showPortraitShortcut {
                    BeforeActionButton(portraitTitle, style: adjacentShortcutStyle) {
                        DecisionEvolutionNavigationDestination.portrait.perform(using: appModel)
                    }
                }
            }
        }
    }
}
