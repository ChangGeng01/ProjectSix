import Foundation

extension DecisionEvolutionNavigationDestination {
    @MainActor
    func perform(using appModel: BeforeAppModel) {
        switch self {
        case .controlCenter:
            Task { @MainActor in
                await appModel.presentEvolutionControlCenterForCurrentSurface()
            }
        case .history:
            appModel.selectedTab = .history
        case .portrait:
            appModel.selectedTab = .portrait
        }
    }
}
