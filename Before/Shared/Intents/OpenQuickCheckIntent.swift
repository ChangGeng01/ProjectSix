import AppIntents
import Foundation

struct OpenQuickCheckIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Before"
    static let description = IntentDescription("Open the quick check flow in Before.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Entry Source", default: .shortcut)
    var entrySource: EntrySource

    init() {
        entrySource = .shortcut
    }

    init(entrySource: EntrySource) {
        self.entrySource = entrySource
    }

    func perform() async throws -> some IntentResult {
        PendingLaunchRequestStore.enqueue(
            PendingLaunchRequest(entrySource: entrySource, requestedAt: .now)
        )
        return .result()
    }
}

struct BeforeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenQuickCheckIntent(entrySource: .siri),
            phrases: [
                "Open Before in \(.applicationName)",
                "Help me decide in \(.applicationName)",
                "Pause me for a second in \(.applicationName)"
            ],
            shortTitle: "Open Before",
            systemImageName: "pause.circle"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
