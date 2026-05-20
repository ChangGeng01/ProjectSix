import Foundation
import BASHostKit

@MainActor
final class QuickCheckSession: ObservableObject, Identifiable {
    let id = UUID()
    var sessionEngineSessionID: String?
    var sessionEngineBindingTask: Task<String?, Never>?
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
    @Published private(set) var lastEvaluationEBrainTurn: BASEBrainTurnResult?

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
        lastEvaluationEBrainTurn = nil
        let input = QuickCheckInput(
            scenario: scenario,
            motivation: motivation,
            expectedOutcome: expectedOutcome,
            controlLevel: controlLevel,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        result = DecisionIntelligenceCoordinator.quickResult(for: input)
    }

    func evaluateWithIntelligence(
        preferences: BeforePreferences = BeforePreferencesStore.load(),
        eBrainTurn: BASEBrainTurnResult? = nil,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async {
        guard let motivation, let expectedOutcome, let controlLevel else { return }
        lastEvaluationEBrainTurn = eBrainTurn

        let input = QuickCheckInput(
            scenario: scenario,
            motivation: motivation,
            expectedOutcome: expectedOutcome,
            controlLevel: controlLevel,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let base = DecisionIntelligenceCoordinator.quickResult(for: input, preferences: preferences)
        let shouldProtectBeforePublishing = eBrainTurn?.hasProtectiveSurfaceGuidance == true
        let shouldRefine = preferences.onDeviceIntelligenceMode.isEnabled || shouldProtectBeforePublishing
        guard shouldRefine else {
            result = base
            return
        }

        isRefiningWithModel = true
        defer { isRefiningWithModel = false }

        let prepared = intelligenceLifecycle.prepareQuickInput(input)
        let neuralState = DecisionNeuralEngine.quickState(
            input: prepared.input,
            contextState: prepared.state,
            brainState: brainState
        )
        if let refined = await DecisionIntelligenceCoordinator.refineQuickResult(
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
}
