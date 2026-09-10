import AppIntents
import Foundation

struct OpenQuickCheckIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Before Quick Check"
    static let description = IntentDescription("Open the quick judgment flow in Before.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Entry Source", default: .shortcut)
    var entrySource: EntrySource

    @Parameter(title: "Scenario")
    var scenario: ScenarioType?

    init() {
        entrySource = .shortcut
    }

    init(entrySource: EntrySource, scenario: ScenarioType? = nil) {
        self.entrySource = entrySource
        self.scenario = scenario
    }

    func perform() async throws -> some IntentResult {
        DecisionIntentEnvelopeStore.enqueue(
            .quickCapture(
                entrySource: entrySource,
                scenario: scenario,
                riskLevel: .low
            )
        )
        return .result()
    }
}

struct OpenDecisionModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Before"
    static let description = IntentDescription("Open Before in quick, balance, or mirror mode.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Mode", default: .quick)
    var mode: DecisionMode

    @Parameter(title: "Question")
    var prompt: String?

    @Parameter(title: "Entry Source", default: .shortcut)
    var entrySource: EntrySource

    init() {
        mode = .quick
        entrySource = .shortcut
        prompt = nil
    }

    init(mode: DecisionMode, prompt: String? = nil, entrySource: EntrySource) {
        self.mode = mode
        self.prompt = prompt
        self.entrySource = entrySource
    }

    func perform() async throws -> some IntentResult {
        DecisionIntentEnvelopeStore.enqueue(
            .openMode(
                entrySource: entrySource,
                mode: mode,
                promptSeed: prompt
            )
        )
        return .result()
    }
}

struct OpenEvolutionControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Before Evolution Control"
    static let description = IntentDescription("Open Before directly into the Evolution Control mutation hub.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Entry Source", default: .shortcut)
    var entrySource: EntrySource

    @Parameter(title: "Headline")
    var prompt: String?

    @Parameter(title: "Instruction")
    var instructionDetail: String?

    @Parameter(title: "Trigger Reason")
    var triggerReason: String?

    @Parameter(title: "Control Entry Kind")
    var controlEntryKindID: String?

    init() {
        entrySource = .shortcut
        prompt = nil
        instructionDetail = nil
        triggerReason = nil
        controlEntryKindID = nil
    }

    init(
        entrySource: EntrySource,
        prompt: String? = nil,
        instructionDetail: String? = nil,
        triggerReason: String? = nil,
        controlEntryKindID: String? = nil
    ) {
        self.entrySource = entrySource
        self.prompt = prompt
        self.instructionDetail = instructionDetail
        self.triggerReason = triggerReason
        self.controlEntryKindID = controlEntryKindID
    }

    init(
        entrySource: EntrySource,
        controlEntry: DecisionEvolutionWidgetControlEntryPresentation
    ) {
        self.init(
            entrySource: entrySource,
            prompt: controlEntry.prompt,
            instructionDetail: controlEntry.instruction,
            triggerReason: controlEntry.triggerReason,
            controlEntryKindID: controlEntry.kindID
        )
    }

    init(
        entrySource: EntrySource,
        primaryAction: DecisionEvolutionWidgetPrimaryActionPresentation
    ) {
        self.init(
            entrySource: entrySource,
            prompt: primaryAction.prompt,
            instructionDetail: primaryAction.instructionDetail,
            triggerReason: primaryAction.triggerReason,
            controlEntryKindID: primaryAction.controlEntryKindID
        )
    }

    func perform() async throws -> some IntentResult {
        DecisionIntentEnvelopeStore.enqueue(
            .openEvolutionControl(
                entrySource: entrySource,
                promptSeed: prompt,
                instructionDetail: instructionDetail,
                triggerReason: triggerReason,
                controlEntryKindID: controlEntryKindID
            )
        )
        return .result()
    }
}

struct BeforeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenQuickCheckIntent(entrySource: .siri),
            phrases: [
                "Open quick check in \(.applicationName)",
                "Help me decide fast in \(.applicationName)"
            ],
            shortTitle: "Quick Check",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: OpenDecisionModeIntent(mode: .balance, entrySource: .shortcut),
            phrases: [
                "Open balance board in \(.applicationName)",
                "Help me weigh this in \(.applicationName)"
            ],
            shortTitle: "Balance Board",
            systemImageName: "slider.horizontal.3"
        )
        AppShortcut(
            intent: OpenDecisionModeIntent(mode: .mirror, entrySource: .shortcut),
            phrases: [
                "Open mirror in \(.applicationName)",
                "Help me look at this clearly in \(.applicationName)"
            ],
            shortTitle: "Mirror",
            systemImageName: "square.split.2x1"
        )
        AppShortcut(
            intent: OpenEvolutionControlIntent(entrySource: .shortcut),
            phrases: [
                "Open evolution control in \(.applicationName)",
                "Review checkpoints in \(.applicationName)"
            ],
            shortTitle: "Evolution Control",
            systemImageName: "shield.lefthalf.filled"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
