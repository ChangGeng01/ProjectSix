import Foundation

extension DecisionEvolutionNavigationDestination {
    @MainActor
    func perform(using appModel: BeforeAppModel) {
        switch self {
        case .controlCenter:
            appModel.presentEvolutionControlCenter()
        case .history:
            appModel.selectedTab = .history
        case .portrait:
            appModel.selectedTab = .portrait
        }
    }
}
