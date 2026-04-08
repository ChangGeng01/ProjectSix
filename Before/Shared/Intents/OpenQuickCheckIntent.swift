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
        PendingLaunchRequestStore.enqueue(
            PendingLaunchRequest(
                entrySource: entrySource,
                preferredMode: .quick,
                scenario: scenario,
                requestedAt: .now
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
        let cleanedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        PendingLaunchRequestStore.enqueue(
            PendingLaunchRequest(
                entrySource: entrySource,
                preferredMode: mode,
                prompt: cleanedPrompt?.isEmpty == true ? nil : cleanedPrompt,
                requestedAt: .now
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
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
