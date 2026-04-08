import Foundation

enum DecisionModelProviderKind: String, Sendable {
    case gemmaE4B
    case foundationModels
    case template

    var title: String {
        switch self {
        case .gemmaE4B: "Gemma 4 E4B"
        case .foundationModels: "Apple Foundation Model"
        case .template: "Deterministic fallback"
        }
    }
}

struct DecisionModelProviderStatus: Equatable, Sendable {
    let kind: DecisionModelProviderKind
    let isAvailable: Bool
    let title: String
    let detail: String
}

struct DecisionModelRuntimeStatus: Equatable, Sendable {
    let preferred: DecisionModelProviderKind
    let active: DecisionModelProviderKind
    let fallback: DecisionModelProviderKind?
    let detail: String
}

struct ReminderSelectionCandidate: Equatable, Identifiable, Sendable {
    let id: UUID
    let content: String
}
