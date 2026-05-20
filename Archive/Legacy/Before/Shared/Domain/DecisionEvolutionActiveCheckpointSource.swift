import Foundation

enum DecisionEvolutionActiveCheckpointSource: String, Equatable, Sendable {
    case none
    case pinnedHint
    case automaticFallback

    var title: String {
        switch self {
        case .none:
            "No active source"
        case .pinnedHint:
            "Pinned active"
        case .automaticFallback:
            "Recovered active"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            "NONE"
        case .pinnedHint:
            "PINNED"
        case .automaticFallback:
            "RECOVERED"
        }
    }

    var visibleTitle: String? {
        self == .none ? nil : title
    }

    var visibleCheckpointHeadline: String {
        switch self {
        case .pinnedHint:
            "Pinned active checkpoint is visible"
        case .automaticFallback:
            "Recovered active checkpoint is visible"
        case .none:
            "Active checkpoint is visible"
        }
    }

    var visibleCheckpointReason: String {
        switch self {
        case .pinnedHint:
            "The host-pinned active checkpoint can be inspected without leaving this surface."
        case .automaticFallback:
            "The recovered automatic checkpoint can be inspected without leaving this surface."
        case .none:
            "The active checkpoint can be inspected without leaving this surface."
        }
    }
}
