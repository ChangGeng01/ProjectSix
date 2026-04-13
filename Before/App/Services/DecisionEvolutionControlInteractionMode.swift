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
            "Operate mutations here"
        case .observeAndRoute:
            "Mutations are centralized in Evolution Control"
        }
    }

    var operatorDetail: String {
        switch self {
        case .mutationHub:
            "Apply, approve, rollback, and lineage-clearing actions stay available in this dedicated control surface."
        case .observeAndRoute:
            "This surface stays aligned as a read-first status view. Open the control center to mutate checkpoints without splitting review facts across multiple shells."
        }
    }
}
