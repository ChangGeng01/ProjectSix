import Foundation

@MainActor
final class BalanceBoardSession: ObservableObject, Identifiable {
    let id = UUID()
    let entrySource: EntrySource

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

    func evaluateWithIntelligence(preferences: BeforePreferences = BeforePreferencesStore.load()) async {
        guard canEvaluate else { return }

        let input = BalanceBoardInput(
            prompt: trimmed(prompt),
            desire: trimmed(desire),
            concern: trimmed(concern),
            constraint: trimmed(constraint),
            longTerm: trimmed(longTerm)
        )

        let base = DecisionIntelligenceCoordinator.balanceResult(for: input, preferences: preferences)
        result = base
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return }

        isRefiningWithModel = true
        defer { isRefiningWithModel = false }

        let prepared = intelligenceLifecycle.prepareBalanceInput(input)
        let neuralState = DecisionNeuralEngine.balanceState(
            input: prepared.input,
            contextState: prepared.state
        )
        if let refined = await DecisionIntelligenceCoordinator.refineBalanceResult(
            base: base,
            input: prepared.input,
            contextState: prepared.state,
            neuralState: neuralState,
            preferences: preferences
        ) {
            result = refined
        }
    }

    var intelligenceLifecycleSnapshot: DecisionContextLifecycleSnapshot {
        intelligenceLifecycle.snapshot
    }

    func restoreIntelligenceLifecycle(_ snapshot: DecisionContextLifecycleSnapshot) {
        intelligenceLifecycle.restore(snapshot)
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
