import Foundation

enum DecisionEvolutionControlInteractionMode: String, Equatable, Sendable {
    case mutationHub
    case observeAndRoute

    var allowsMutations: Bool {
        self == .mutationHub
    }

    var operatorHeadline: String {
        switch self {
        case .mutationHub:
            DecisionEvolutionMutationHubPresentationSupport.headline
        case .observeAndRoute:
            DecisionEvolutionControlSurfaceLexiconSupport.mutationCentralizedHeadline
        }
    }

    var operatorDetail: String {
        switch self {
        case .mutationHub:
            DecisionEvolutionMutationHubPresentationSupport.operatorDetail
        case .observeAndRoute:
            DecisionEvolutionMutationRoutingPresentationSupport.readFirstOperatorDetail
        }
    }
}
