import Foundation

@MainActor
final class QuickCheckSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var scenario: ScenarioType = .buy
    @Published var motivation: MotivationChoice?
    @Published var expectedOutcome: OutcomeChoice?
    @Published var controlLevel: ControlChoice?
    @Published var note: String = "" {
        didSet {
            intelligenceLifecycle.touch(field: .quickNote, value: note)
        }
    }
    @Published var result: QuickCheckResult?
    @Published var selectedAction: CheckAction?
    @Published var isShowingWaitSheet = false
    @Published var isRefiningWithModel = false
    @Published private(set) var brainState: DecisionBrainState?

    let entrySource: EntrySource
    private let intelligenceLifecycle: DecisionContextLifecycle

    init(entrySource: EntrySource, initialNote: String = "") {
        self.entrySource = entrySource
        self.intelligenceLifecycle = DecisionContextLifecycle()
        self.note = initialNote
        intelligenceLifecycle.touch(field: .quickNote, value: initialNote)
    }

    var canEvaluate: Bool {
        motivation != nil && expectedOutcome != nil && controlLevel != nil
    }

    func evaluate() {
        guard let motivation, let expectedOutcome, let controlLevel else { return }
        let input = QuickCheckInput(
            scenario: scenario,
            motivation: motivation,
            expectedOutcome: expectedOutcome,
            controlLevel: controlLevel,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        result = DecisionIntelligenceCoordinator.quickResult(for: input)
    }

    func evaluateWithIntelligence(preferences: BeforePreferences = BeforePreferencesStore.load()) async {
        guard let motivation, let expectedOutcome, let controlLevel else { return }

        let input = QuickCheckInput(
            scenario: scenario,
            motivation: motivation,
            expectedOutcome: expectedOutcome,
            controlLevel: controlLevel,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let base = DecisionIntelligenceCoordinator.quickResult(for: input, preferences: preferences)
        result = base
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return }

        isRefiningWithModel = true
        defer { isRefiningWithModel = false }

        let prepared = intelligenceLifecycle.prepareQuickInput(input)
        let neuralState = DecisionNeuralEngine.quickState(
            input: prepared.input,
            contextState: prepared.state
        )
        if let refined = await DecisionIntelligenceCoordinator.refineQuickResult(
            base: base,
            input: prepared.input,
            contextState: prepared.state,
            neuralState: neuralState,
            brainState: brainState,
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

    func loadBrainState(_ brainState: DecisionBrainState?) {
        self.brainState = brainState
    }
}
