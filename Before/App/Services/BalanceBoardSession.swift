import Foundation

@MainActor
final class BalanceBoardSession: ObservableObject, Identifiable {
    let id = UUID()
    let entrySource: EntrySource

    @Published var prompt: String
    @Published var desire: String = ""
    @Published var concern: String = ""
    @Published var constraint: String = ""
    @Published var longTerm: String = ""
    @Published var result: BalanceBoardResult?
    @Published var isRefiningWithModel = false

    init(entrySource: EntrySource, prompt: String = "") {
        self.entrySource = entrySource
        self.prompt = prompt
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

        if let refined = await DecisionIntelligenceCoordinator.refineBalanceResult(
            base: base,
            input: input,
            preferences: preferences
        ) {
            result = refined
        }
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
