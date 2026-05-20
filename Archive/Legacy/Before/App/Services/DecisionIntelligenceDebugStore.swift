import Foundation
import BASHostKit

enum DecisionIntelligenceTracePrivacy {
    static func allowsSensitivePayload(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        considerRuntimeTestingContext: Bool = true
    ) -> Bool {
        BASAppleObservabilityAdapter.allowsSensitivePayload(
            environment: environment,
            considerRuntimeTestingContext: considerRuntimeTestingContext,
            runtimeTestingContextDetected: NSClassFromString("XCTestCase") != nil,
            testingOverridePresent: DecisionTestingInterface.environmentOverride(environment: environment) != nil
        )
    }

    static func sanitizedPrompt(
        detail: String,
        semanticPromptFingerprint: String?,
        stablePrefixFingerprint: String?,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget?
    ) -> String {
        BASAppleObservabilityAdapter.sanitizedPrompt(
            detail: detail,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            promptBudget: promptBudget
        )
    }

    static func sanitizedOutputPreview(
        outputPreview: String
    ) -> String {
        BASAppleObservabilityAdapter.sanitizedOutputPreview(outputPreview: outputPreview)
    }
}

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

    var substrateKindID: String {
        switch self {
        case .quick:
            BASAdaptiveTraceKind.primary.identifier
        case .balance:
            BASAdaptiveTraceKind.comparative.identifier
        case .mirror:
            BASAdaptiveTraceKind.reflective.identifier
        case .reminder:
            BASAdaptiveTraceKind.selection.identifier
        }
    }

    init?(substrateKindID: String) {
        switch substrateKindID {
        case BASAdaptiveTraceKind.primary.identifier, "quick":
            self = .quick
        case BASAdaptiveTraceKind.comparative.identifier, "balance":
            self = .balance
        case BASAdaptiveTraceKind.reflective.identifier, "mirror":
            self = .mirror
        case BASAdaptiveTraceKind.selection.identifier, "selection", "reminder":
            self = .reminder
        default:
            return nil
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
    let consistencyCheck: BASConsistencyCheckResult?
    let consistencyRejected: Bool
    let substrateTrace: BASExecutionTrace?
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
        consistencyCheck: BASConsistencyCheckResult? = nil,
        consistencyRejected: Bool = false,
        substrateTrace: BASExecutionTrace? = nil,
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
        self.consistencyCheck = consistencyCheck
        self.consistencyRejected = consistencyRejected
        self.substrateTrace = substrateTrace
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

private extension BASEBrainTurnResult {
    var replayLineageFingerprint: String {
        [
            runtimeTrace.sessionID,
            thoughtFold.checksum,
            riskCard.riskLevel.rawValue,
            actionPermit.mode.rawValue,
            renderedOutput.mode.rawValue
        ].joined(separator: "|")
    }
}

@MainActor
final class EBrainTurnDebugStore: ObservableObject {
    static let shared = EBrainTurnDebugStore()

    @Published private(set) var turns: [BASEBrainTurnResult] = []

    func record(_ turn: BASEBrainTurnResult) {
        if turns.first?.replayLineageFingerprint == turn.replayLineageFingerprint {
            return
        }

        turns.insert(turn, at: 0)
        if turns.count > BeforePolicy.Settings.developerReplayLimit {
            turns.removeLast(turns.count - BeforePolicy.Settings.developerReplayLimit)
        }
    }

    func clear() {
        turns.removeAll()
    }
}
