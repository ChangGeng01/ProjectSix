import Foundation
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
final class BeforeAppModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var activeSession: QuickCheckSession?
    @Published var reflectionContext: ReflectionContext?
    @Published var startupNotice: String?
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    private var shouldPromptReflectionAfterBackground = false
    private var pendingReflectionContext: ReflectionContext?

    init(modelContainer: ModelContainer, startupNotice: String? = nil) {
        self.modelContainer = modelContainer
        self.startupNotice = startupNotice
        restorePendingReflectionState()
    }

    func handleInitialAppearance() {
        presentPendingReflectionIfNeeded()
        consumePendingLaunchRequestIfNeeded()
        syncWidgetSnapshot()
    }

    func dismissStartupNotice() {
        startupNotice = nil
    }

    func startQuickCheck(entrySource: EntrySource) {
        activeSession = QuickCheckSession(entrySource: entrySource)
    }

    func startQuickCheck(entrySource: EntrySource, scenario: ScenarioType) {
        let session = QuickCheckSession(entrySource: entrySource)
        session.scenario = scenario
        activeSession = session
    }

    func consumePendingLaunchRequestIfNeeded() {
        guard let request = PendingLaunchRequestStore.consume() else { return }
        startQuickCheck(entrySource: request.entrySource)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            presentPendingReflectionIfNeeded()
            consumePendingLaunchRequestIfNeeded()
        case .background:
            if pendingReflectionContext != nil {
                shouldPromptReflectionAfterBackground = true
                persistPendingReflectionState()
            }
        default:
            break
        }
    }

    func completeCheck(using session: QuickCheckSession, action: CheckAction) async {
        guard let result = session.result,
              let motivation = session.motivation,
              let expectedOutcome = session.expectedOutcome,
              let controlLevel = session.controlLevel else { return }

        let context = modelContainer.mainContext
        let event = CheckEvent(
            scenario: session.scenario,
            motivation: motivation,
            expectedOutcome: expectedOutcome,
            controlLevel: controlLevel,
            note: session.note.trimmingCharacters(in: .whitespacesAndNewlines),
            currentPerspective: result.currentPerspective,
            afterPerspective: result.afterPerspective,
            verdict: result.verdict,
            finalAction: action,
            entrySource: session.entrySource
        )
        context.insert(event)
        try? context.save()

        switch action {
        case .decideTomorrow:
            await NotificationService.shared.scheduleTomorrowNotification(
                eventID: event.id,
                from: event.createdAt
            )
        default:
            break
        }

        refreshWidgetSurfaces()

        pendingReflectionContext = ReflectionContext(
            id: UUID(),
            eventID: event.id,
            scenario: event.scenario,
            finalAction: event.finalAction
        )
        persistPendingReflectionState()
        reflectionContext = nil
        activeSession = nil
    }

    func submitReflection(
        outcome: ReflectionOutcome,
        note: String,
        reminderText: String?,
        reminderSource: ReminderSourceType,
        scenario: ScenarioType,
        for eventID: UUID
    ) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<CheckEvent>(
            predicate: #Predicate { $0.id == eventID }
        )
        if let event = try? context.fetch(descriptor).first {
            event.reflectionOutcomeRaw = outcome.rawValue
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            event.reflectionNote = trimmedNote.isEmpty ? nil : trimmedNote
        }

        if let reminderText {
            let trimmed = String(
                reminderText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(BeforePolicy.Reflection.reminderMaxCharacters)
            )
            if !trimmed.isEmpty {
                let reminder = SelfReminder(
                    content: trimmed,
                    scenario: scenario,
                    source: reminderSource,
                    createdAt: .now,
                    lastUsedAt: .now,
                    useCount: 0
                )
                context.insert(reminder)
                trimReminders(in: context)
            }
        }

        try? context.save()
        refreshWidgetSurfaces()
        pendingReflectionContext = nil
        shouldPromptReflectionAfterBackground = false
        reflectionContext = nil
        persistPendingReflectionState()
    }

    func skipReflection() {
        pendingReflectionContext = nil
        shouldPromptReflectionAfterBackground = false
        reflectionContext = nil
        persistPendingReflectionState()
    }

    func reminders(for scenario: ScenarioType) -> [SelfReminder] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SelfReminder>()

        let fetched = (try? context.fetch(descriptor)) ?? []
        return ReminderSelectionPolicy.ranked(reminders: fetched.filter { $0.scenario == scenario })
    }

    func bestReminder(for scenario: ScenarioType) -> String? {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SelfReminder>()
        let reminders = (try? context.fetch(descriptor)) ?? []
        return ReminderSelectionPolicy.bestReminder(in: reminders, for: scenario)?.content
    }

    func latestEvents(limit: Int = BeforePolicy.QuickCheck.recentHistoryLimit) -> [CheckEvent] {
        let descriptor = FetchDescriptor<CheckEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let events = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        return Array(events.prefix(limit))
    }

    func clearHistory() {
        let context = modelContainer.mainContext
        deleteAll(CheckEvent.self, in: context)

        resetTransientState()
        refreshWidgetSurfaces()
    }

    func clearReminders() {
        let context = modelContainer.mainContext
        deleteAll(SelfReminder.self, in: context)

        refreshWidgetSurfaces()
    }

    func resetLocalData() {
        let context = modelContainer.mainContext
        deleteAll(CheckEvent.self, in: context)
        deleteAll(SelfReminder.self, in: context)

        PendingLaunchRequestStore.clear()
        WidgetSnapshotStore.clear()
        resetTransientState()
        refreshWidgetSurfaces()
    }

    func syncWidgetSnapshot() {
        let events = latestEvents(limit: 1)
        let latest = events.first
        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeCopy.message(
                for: latest?.scenario,
                verdict: latest?.verdict
            ),
            latestVerdict: latest?.verdict,
            latestScenario: latest?.scenario,
            updatedAt: .now
        )
        WidgetSnapshotStore.save(snapshot)
    }

    private func trimReminders(in context: ModelContext) {
        let descriptor = FetchDescriptor<SelfReminder>()
        guard let reminders = try? context.fetch(descriptor) else { return }
        ReminderSelectionPolicy.remindersToTrim(from: reminders).forEach { context.delete($0) }
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) {
        let descriptor = FetchDescriptor<Model>()
        ((try? context.fetch(descriptor)) ?? []).forEach { context.delete($0) }
        try? context.save()
    }

    private func refreshWidgetSurfaces() {
        syncWidgetSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func resetTransientState() {
        activeSession = nil
        reflectionContext = nil
        pendingReflectionContext = nil
        shouldPromptReflectionAfterBackground = false
        persistPendingReflectionState()
    }

    private func restorePendingReflectionState() {
        let state = PendingReflectionStore.load()
        pendingReflectionContext = state.context
        shouldPromptReflectionAfterBackground = state.shouldPromptOnNextActive
    }

    private func presentPendingReflectionIfNeeded() {
        guard shouldPromptReflectionAfterBackground, reflectionContext == nil else { return }
        reflectionContext = pendingReflectionContext
        shouldPromptReflectionAfterBackground = false
        persistPendingReflectionState()
    }

    private func persistPendingReflectionState() {
        guard pendingReflectionContext != nil else {
            PendingReflectionStore.clear()
            return
        }

        PendingReflectionStore.save(
            PendingReflectionState(
                context: pendingReflectionContext,
                shouldPromptOnNextActive: shouldPromptReflectionAfterBackground
            )
        )
    }
}
