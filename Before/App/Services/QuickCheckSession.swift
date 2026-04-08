import Foundation

@MainActor
final class QuickCheckSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var scenario: ScenarioType = .buy
    @Published var motivation: MotivationChoice?
    @Published var expectedOutcome: OutcomeChoice?
    @Published var controlLevel: ControlChoice?
    @Published var note: String = ""
    @Published var result: QuickCheckResult?
    @Published var selectedAction: CheckAction?
    @Published var isShowingWaitSheet = false

    let entrySource: EntrySource

    init(entrySource: EntrySource, initialNote: String = "") {
        self.entrySource = entrySource
        self.note = initialNote
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
        result = CheckRuleEngine.evaluate(input)
    }
}
