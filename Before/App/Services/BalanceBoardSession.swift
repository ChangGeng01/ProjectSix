import Foundation
import BASHostKit

@MainActor
final class BalanceBoardSession: ObservableObject, Identifiable {
    let id = UUID()
    let entrySource: EntrySource
    var sessionEngineSessionID: String?
    var sessionEngineBindingTask: Task<String?, Never>?

    @Published var prompt: String {
        didSet {
            intelligenceLifecycle.touch(field: .balancePrompt, value: prompt)
        }
    }
    @Published var desire: String = "" {
        didSet {
            intelligenceLifecycle.touch(field: .balanceDesire, value: desire)
        }
    }
    @Published var concern: String = "" {
        didSet {
            intelligenceLifecycle.touch(field: .balanceConcern, value: concern)
        }
    }
    @Published var constraint: String = "" {
        didSet {
            intelligenceLifecycle.touch(field: .balanceConstraint, value: constraint)
        }
    }
    @Published var longTerm: String = "" {
        didSet {
            intelligenceLifecycle.touch(field: .balanceLongTerm, value: longTerm)
        }
    }
    @Published var result: BalanceBoardResult?
    @Published var isRefiningWithModel = false
    @Published private(set) var brainState: DecisionBrainState?
    @Published private(set) var lastEvaluationEBrainTurn: BASEBrainTurnResult?
    private let intelligenceLifecycle: DecisionContextLifecycle

    init(entrySource: EntrySource, prompt: String = "") {
        self.entrySource = entrySource
        self.intelligenceLifecycle = DecisionContextLifecycle()
        self.prompt = prompt
        intelligenceLifecycle.touch(field: .balancePrompt, value: prompt)
    }

    var canEvaluate: Bool {
        !trimmed(prompt).isEmpty && populatedFieldCount >= 2
    }

    func evaluate() {
        guard canEvaluate else { return }
        lastEvaluationEBrainTurn = nil
        result = DecisionIntelligenceCoordinator.balanceResult(
            for: BalanceBoardInput(
                prompt: trimmed(prompt),
                desire: trimmed(desire),
                concern: trimmed(concern),
                constraint: trimmed(constraint),
                longTerm: trimmed(longTerm)
            )
        )
    }

    func evaluateWithIntelligence(
        preferences: BeforePreferences = BeforePreferencesStore.load(),
        eBrainTurn: BASEBrainTurnResult? = nil,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async {
        guard canEvaluate else { return }
        lastEvaluationEBrainTurn = eBrainTurn

        let input = BalanceBoardInput(
            prompt: trimmed(prompt),
            desire: trimmed(desire),
            concern: trimmed(concern),
            constraint: trimmed(constraint),
            longTerm: trimmed(longTerm)
        )

        let base = DecisionIntelligenceCoordinator.balanceResult(for: input, preferences: preferences)
        let shouldProtectBeforePublishing = eBrainTurn?.hasProtectiveSurfaceGuidance == true
        let shouldRefine = preferences.onDeviceIntelligenceMode.isEnabled || shouldProtectBeforePublishing
        guard shouldRefine else {
            result = base
            return
        }

        isRefiningWithModel = true
        defer { isRefiningWithModel = false }

        let prepared = intelligenceLifecycle.prepareBalanceInput(input)
        let neuralState = DecisionNeuralEngine.balanceState(
            input: prepared.input,
            contextState: prepared.state,
            brainState: brainState
        )
        if let refined = await DecisionIntelligenceCoordinator.refineBalanceResult(
            base: base,
            input: prepared.input,
            contextState: prepared.state,
            neuralState: neuralState,
            brainState: brainState,
            eBrainTurn: eBrainTurn,
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        ) {
            result = refined
        } else {
            result = base
        }
    }

    var intelligenceLifecycleSnapshot: DecisionContextLifecycleSnapshot {
        intelligenceLifecycle.snapshot
    }

    func restoreIntelligenceLifecycle(_ snapshot: DecisionContextLifecycleSnapshot) {
        intelligenceLifecycle.restore(snapshot)
    }

    func loadBrainState(_ brainState: DecisionBrainState?) {
        self.brainState = brainState
    }

    func restoreEvaluationEBrainTurn(_ turn: BASEBrainTurnResult?) {
        lastEvaluationEBrainTurn = turn
    }

    private var populatedFieldCount: Int {
        [desire, concern, constraint, longTerm]
            .map(trimmed)
            .filter { !$0.isEmpty }
            .count
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
