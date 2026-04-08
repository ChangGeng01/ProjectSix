import Foundation

enum DecisionModelProviderKind: String, Sendable {
    case gemmaE4B
    case openModel
    case foundationModels
    case testingStub
    case template

    var title: String {
        switch self {
        case .gemmaE4B: "Gemma 4 E4B"
        case .openModel: "Open model runtime"
        case .foundationModels: "Apple Foundation Model"
        case .testingStub: "Testing stub"
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
    let rank: Int
    let source: ReminderSourceType
    let useCount: Int

    init(
        id: UUID,
        content: String,
        rank: Int = 0,
        source: ReminderSourceType = .template,
        useCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.rank = rank
        self.source = source
        self.useCount = useCount
    }
}
