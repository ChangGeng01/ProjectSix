import Foundation
import SwiftData
import SwiftUI
import WidgetKit

struct DecisionSignal {
    let eyebrow: String
    let title: String
    let detail: String
}

@MainActor
final class BeforeAppModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var activeQuickSession: QuickCheckSession?
    @Published var activeBalanceSession: BalanceBoardSession?
    @Published var activeMirrorSession: MirrorWorkspaceSession?
    @Published var reflectionContext: ReflectionContext?
    @Published var startupNotice: String?
    @Published private(set) var preferences: BeforePreferences
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    private var shouldPromptReflectionAfterBackground = false
    private var pendingReflectionContext: ReflectionContext?

    init(modelContainer: ModelContainer, startupNotice: String? = nil) {
        self.modelContainer = modelContainer
        self.startupNotice = startupNotice
        self.preferences = BeforePreferencesStore.load()
        restorePendingReflectionState()
    }

    func handleInitialAppearance() {
        presentPendingReflectionIfNeeded()
        consumePendingLaunchRequestIfNeeded()
        restoreActiveWorkspaceIfNeeded()
        syncWidgetSnapshot()
    }

    func dismissStartupNotice() {
        startupNotice = nil
    }

    func startDecisionMode(
        _ mode: DecisionMode,
        entrySource: EntrySource,
        prompt: String = ""
    ) {
        switch mode {
        case .quick:
            startQuickCheck(entrySource: entrySource, prompt: prompt)
        case .balance:
            startBalanceBoard(entrySource: entrySource, prompt: prompt)
        case .mirror:
            startMirrorWorkspace(entrySource: entrySource, prompt: prompt)
        }
    }

    func routeDecision(prompt: String, entrySource: EntrySource) -> RoutedDecision {
        let route = DecisionModeRouter.route(prompt: prompt)
        startDecisionMode(route.mode, entrySource: entrySource, prompt: prompt)
        return route
    }

    func submitHomePrompt(_ prompt: String, entrySource: EntrySource) -> RoutedDecision {
        switch preferences.homePromptAction {
        case .autoRoute:
            return routeDecision(prompt: prompt, entrySource: entrySource)
        case .quick:
            startQuickCheck(entrySource: entrySource, prompt: prompt)
            return RoutedDecision(mode: .quick, reason: "Preferred quick judgment")
        case .balance:
            startBalanceBoard(entrySource: entrySource, prompt: prompt)
            return RoutedDecision(mode: .balance, reason: "Preferred balance board")
        case .mirror:
            startMirrorWorkspace(entrySource: entrySource, prompt: prompt)
            return RoutedDecision(mode: .mirror, reason: "Preferred mirror")
        }
    }

    func updatePreferences(_ transform: (inout BeforePreferences) -> Void) {
        var updated = preferences
        transform(&updated)
        preferences = updated
        BeforePreferencesStore.save(updated)

        if updated.restoreInProgressWorkspaces {
            persistActiveWorkspaceState()
        } else {
            ActiveDecisionWorkspaceStore.clear()
        }
    }

    func startQuickCheck(
        entrySource: EntrySource,
        scenario: ScenarioType? = nil,
        prompt: String = ""
    ) {
        clearActiveDecisionFlows()

        let session = QuickCheckSession(entrySource: entrySource, initialNote: prompt)
        if let scenario {
            session.scenario = scenario
        }
        activeQuickSession = session
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func startBalanceBoard(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        activeBalanceSession = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func startMirrorWorkspace(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        activeMirrorSession = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func consumePendingLaunchRequestIfNeeded() {
        guard let request = PendingLaunchRequestStore.consume() else { return }
        switch LaunchRequestResolver.resolve(request) {
        case let .quick(scenario, prompt):
            startQuickCheck(
                entrySource: request.entrySource,
                scenario: scenario,
                prompt: prompt
            )
        case let .mode(mode, prompt):
            startDecisionMode(mode, entrySource: request.entrySource, prompt: prompt)
        case let .routedPrompt(prompt):
            _ = routeDecision(prompt: prompt, entrySource: request.entrySource)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            presentPendingReflectionIfNeeded()
            consumePendingLaunchRequestIfNeeded()
            restoreActiveWorkspaceIfNeeded()
        case .background:
            if pendingReflectionContext != nil {
                shouldPromptReflectionAfterBackground = true
                persistPendingReflectionState()
            }
            persistActiveWorkspaceState()
        case .inactive:
            persistActiveWorkspaceState()
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
            let tomorrowItem = makeTomorrowBoxItem(
                from: session,
                result: result,
                eventID: event.id
            )
            context.insert(tomorrowItem)
            await NotificationService.shared.scheduleTomorrowNotification(
                eventID: event.id,
                from: event.createdAt
            )
            selectedTab = 1
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
        activeQuickSession = nil
        persistActiveWorkspaceState()
    }

    func saveBalanceBoard(_ session: BalanceBoardSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let record = BalanceDecisionRecord(
            prompt: trimmed(session.prompt),
            desire: trimmed(session.desire),
            concern: trimmed(session.concern),
            constraint: trimmed(session.constraint),
            longTerm: trimmed(session.longTerm),
            focusTitle: result.focusTitle,
            focusSummary: result.summary,
            nextAction: result.nextAction,
            entrySource: session.entrySource
        )
        context.insert(record)
        try? context.save()
        activeBalanceSession = nil
        persistActiveWorkspaceState()
    }

    func moveBalanceBoardToTomorrow(_ session: BalanceBoardSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        context.insert(makeTomorrowBoxItem(from: session, result: result))
        try? context.save()
        activeBalanceSession = nil
        selectedTab = 1
        persistActiveWorkspaceState()
    }

    func saveMirrorWorkspace(_ session: MirrorWorkspaceSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let record = MirrorDecisionRecord(
            prompt: trimmed(session.prompt),
            emotion: trimmed(session.emotion),
            relationship: trimmed(session.relationship),
            reality: trimmed(session.reality),
            longTerm: trimmed(session.longTerm),
            selfLens: trimmed(session.selfLens),
            coreTension: result.coreTension,
            nextActionTitle: result.nextActionTitle,
            nextAction: result.nextAction,
            entrySource: session.entrySource
        )
        context.insert(record)
        try? context.save()
        activeMirrorSession = nil
        persistActiveWorkspaceState()
    }

    func moveMirrorWorkspaceToTomorrow(_ session: MirrorWorkspaceSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        context.insert(makeTomorrowBoxItem(from: session, result: result))
        try? context.save()
        activeMirrorSession = nil
        selectedTab = 1
        persistActiveWorkspaceState()
    }

    func reopenTomorrowBoxItem(_ item: TomorrowBoxItem) {
        clearActiveDecisionFlows()

        switch item.mode {
        case .quick:
            if let draft = item.draft {
                activeQuickSession = draft.restoreQuickSession(entrySource: .app)
            } else {
                startQuickCheck(entrySource: .app, prompt: item.prompt)
            }
        case .balance:
            if let draft = item.draft {
                activeBalanceSession = draft.restoreBalanceSession(entrySource: .app)
            } else {
                startBalanceBoard(entrySource: .app, prompt: item.prompt)
            }
        case .mirror:
            if let draft = item.draft {
                activeMirrorSession = draft.restoreMirrorSession(entrySource: .app)
            } else {
                startMirrorWorkspace(entrySource: .app, prompt: item.prompt)
            }
        }

        removeTomorrowBoxItem(item)
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func reopenCheckEvent(_ event: CheckEvent) {
        clearActiveDecisionFlows()
        activeQuickSession = event.restoredSession()
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func reopenBalanceRecord(_ record: BalanceDecisionRecord) {
        clearActiveDecisionFlows()
        activeBalanceSession = record.restoredSession()
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func reopenMirrorRecord(_ record: MirrorDecisionRecord) {
        clearActiveDecisionFlows()
        activeMirrorSession = record.restoredSession()
        selectedTab = 0
        persistActiveWorkspaceState()
    }

    func moveCheckEventToTomorrow(_ event: CheckEvent) {
        let context = modelContainer.mainContext
        context.insert(event.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = 1
    }

    func moveBalanceRecordToTomorrow(_ record: BalanceDecisionRecord) {
        let context = modelContainer.mainContext
        context.insert(record.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = 1
    }

    func moveMirrorRecordToTomorrow(_ record: MirrorDecisionRecord) {
        let context = modelContainer.mainContext
        context.insert(record.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = 1
    }

    func removeTomorrowBoxItem(_ item: TomorrowBoxItem) {
        if let eventID = item.linkedCheckEventID {
            NotificationService.shared.cancelTomorrowNotification(eventID: eventID)
        }

        let context = modelContainer.mainContext
        context.delete(item)
        try? context.save()
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

    func latestSignal() -> DecisionSignal? {
        let context = modelContainer.mainContext

        let latestQuick = try? context.fetch(
            FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        ).first

        let latestBalance = try? context.fetch(
            FetchDescriptor<BalanceDecisionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).first

        let latestMirror = try? context.fetch(
            FetchDescriptor<MirrorDecisionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).first

        let candidates: [(Date, DecisionSignal)] = [
            latestQuick.map {
                (
                    $0.createdAt,
                    DecisionSignal(
                        eyebrow: $0.verdict.title,
                        title: $0.currentPerspective,
                        detail: $0.afterPerspective
                    )
                )
            },
            latestBalance.map {
                (
                    $0.updatedAt,
                    DecisionSignal(
                        eyebrow: "Balance board",
                        title: $0.focusTitle,
                        detail: $0.focusSummary
                    )
                )
            },
            latestMirror.map {
                (
                    $0.updatedAt,
                    DecisionSignal(
                        eyebrow: "Mirror",
                        title: $0.nextActionTitle,
                        detail: $0.coreTension
                    )
                )
            }
        ]
        .compactMap { $0 }

        return candidates.max(by: { $0.0 < $1.0 })?.1
    }

    func clearHistory() {
        let context = modelContainer.mainContext
        deleteAll(CheckEvent.self, in: context)
        deleteAll(BalanceDecisionRecord.self, in: context)
        deleteAll(MirrorDecisionRecord.self, in: context)

        resetTransientState()
        refreshWidgetSurfaces()
    }

    func clearReminders() {
        let context = modelContainer.mainContext
        deleteAll(SelfReminder.self, in: context)
        refreshWidgetSurfaces()
    }

    func clearTomorrowBox() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<TomorrowBoxItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        items.compactMap(\.linkedCheckEventID).forEach {
            NotificationService.shared.cancelTomorrowNotification(eventID: $0)
        }
        items.forEach { context.delete($0) }
        try? context.save()
    }

    func resetLocalData() {
        let context = modelContainer.mainContext
        deleteAll(CheckEvent.self, in: context)
        deleteAll(BalanceDecisionRecord.self, in: context)
        deleteAll(MirrorDecisionRecord.self, in: context)
        deleteAll(SelfReminder.self, in: context)
        clearTomorrowBox()

        PendingLaunchRequestStore.clear()
        WidgetSnapshotStore.clear()
        resetTransientState()
        refreshWidgetSurfaces()
    }

    func syncWidgetSnapshot() {
        let latest = latestEvents(limit: 1).first
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

    func syncWorkspacePersistence() {
        persistActiveWorkspaceState()
    }

    private func clearActiveDecisionFlows() {
        activeQuickSession = nil
        activeBalanceSession = nil
        activeMirrorSession = nil
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

    private func makeTomorrowBoxItem(
        from session: QuickCheckSession,
        result: QuickCheckResult,
        eventID: UUID? = nil
    ) -> TomorrowBoxItem {
        let prompt = trimmed(session.note)
        let title = prompt.isEmpty ? "\(session.scenario.title) later" : prompt
        return TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .quick,
            title: title,
            detail: result.afterPerspective,
            prompt: prompt,
            entrySource: session.entrySource,
            linkedCheckEventID: eventID,
            draft: .quick(from: session)
        )
    }

    private func makeTomorrowBoxItem(
        from session: BalanceBoardSession,
        result: BalanceBoardResult
    ) -> TomorrowBoxItem {
        TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .balance,
            title: trimmed(session.prompt),
            detail: result.summary,
            prompt: trimmed(session.prompt),
            entrySource: session.entrySource,
            draft: .balance(from: session)
        )
    }

    private func makeTomorrowBoxItem(
        from session: MirrorWorkspaceSession,
        result: MirrorResult
    ) -> TomorrowBoxItem {
        TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .mirror,
            title: trimmed(session.prompt),
            detail: result.coreTension,
            prompt: trimmed(session.prompt),
            entrySource: session.entrySource,
            draft: .mirror(from: session)
        )
    }

    private func resetTransientState() {
        clearActiveDecisionFlows()
        reflectionContext = nil
        pendingReflectionContext = nil
        shouldPromptReflectionAfterBackground = false
        persistPendingReflectionState()
        ActiveDecisionWorkspaceStore.clear()
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

    private func restoreActiveWorkspaceIfNeeded() {
        guard
            preferences.restoreInProgressWorkspaces,
            activeQuickSession == nil,
            activeBalanceSession == nil,
            activeMirrorSession == nil,
            reflectionContext == nil,
            let state = ActiveDecisionWorkspaceStore.load(),
            let mode = state.mode
        else {
            return
        }

        switch mode {
        case .quick:
            activeQuickSession = state.restoreQuickSession()
        case .balance:
            activeBalanceSession = state.restoreBalanceSession()
        case .mirror:
            activeMirrorSession = state.restoreMirrorSession()
        }

        selectedTab = 0
    }

    private func persistActiveWorkspaceState() {
        let state: ActiveDecisionWorkspaceState?

        if let session = activeQuickSession {
            state = ActiveDecisionWorkspaceState.capture(from: session)
        } else if let session = activeBalanceSession {
            state = ActiveDecisionWorkspaceState.capture(from: session)
        } else if let session = activeMirrorSession {
            state = ActiveDecisionWorkspaceState.capture(from: session)
        } else {
            state = nil
        }

        if let state {
            ActiveDecisionWorkspaceStore.save(state)
        } else {
            ActiveDecisionWorkspaceStore.clear()
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
