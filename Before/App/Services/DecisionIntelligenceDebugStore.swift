import Foundation

enum DecisionIntelligenceTraceKind: String, CaseIterable, Identifiable, Sendable {
    case quick
    case balance
    case mirror
    case reminder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: "Quick refinement"
        case .balance: "Balance refinement"
        case .mirror: "Mirror refinement"
        case .reminder: "Reminder selection"
        }
    }
}

struct DecisionIntelligenceTrace: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let kind: DecisionIntelligenceTraceKind
    let preferredProvider: DecisionModelProviderKind
    let activeProvider: DecisionModelProviderKind?
    let attemptedProviders: [DecisionModelProviderKind]
    let allowFallbacks: Bool
    let usedFallback: Bool
    let frontstageState: DecisionFrontstageState?
    let contextState: DecisionContextPreparedState?
    let neuralState: DecisionNeuralState?
    let brainState: DecisionBrainState?
    let runtimeStrategy: DecisionAdaptiveTaskStrategy?
    let promptBudget: DecisionIntelligencePromptContract.ContextBudget?
    let admissionDecision: DecisionIntelligenceAdmissionDecision?
    let semanticPromptFingerprint: String?
    let stablePrefixFingerprint: String?
    let prompt: String
    let outputPreview: String
    let detail: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kind: DecisionIntelligenceTraceKind,
        preferredProvider: DecisionModelProviderKind,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        allowFallbacks: Bool,
        usedFallback: Bool,
        frontstageState: DecisionFrontstageState? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        runtimeStrategy: DecisionAdaptiveTaskStrategy? = nil,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        prompt: String,
        outputPreview: String,
        detail: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.preferredProvider = preferredProvider
        self.activeProvider = activeProvider
        self.attemptedProviders = attemptedProviders
        self.allowFallbacks = allowFallbacks
        self.usedFallback = usedFallback
        self.frontstageState = frontstageState
        self.contextState = contextState
        self.neuralState = neuralState
        self.brainState = brainState
        self.runtimeStrategy = runtimeStrategy
        self.promptBudget = promptBudget
        self.admissionDecision = admissionDecision
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.prompt = prompt
        self.outputPreview = outputPreview
        self.detail = detail
    }
}

@MainActor
final class DecisionIntelligenceDebugStore: ObservableObject {
    static let shared = DecisionIntelligenceDebugStore()

    @Published private(set) var traces: [DecisionIntelligenceTrace] = []

    func record(_ trace: DecisionIntelligenceTrace) {
        traces.insert(trace, at: 0)
        if traces.count > BeforePolicy.Settings.developerTraceLimit {
            traces.removeLast(traces.count - BeforePolicy.Settings.developerTraceLimit)
        }
    }

    func clear() {
        traces.removeAll()
    }
}
