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
    @Published var selectedTab: AppTab = .home
    @Published var activeQuickSession: QuickCheckSession?
    @Published var activeBalanceSession: BalanceBoardSession?
    @Published var activeMirrorSession: MirrorWorkspaceSession?
    @Published var reflectionContext: ReflectionContext?
    @Published var startupNotice: String?
    @Published var supportSurface: SupportSurfaceTarget = .buddy
    @Published private(set) var preferences: BeforePreferences
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    let supportInbox: SupportInboxStore
    let sharedLifeStore: SharedLifeStore
    private var shouldPromptReflectionAfterBackground = false
    private var pendingReflectionContext: ReflectionContext?

    init(modelContainer: ModelContainer, startupNotice: String? = nil) {
        self.modelContainer = modelContainer
        self.startupNotice = startupNotice
        self.preferences = BeforePreferencesStore.load()
        self.supportInbox = SupportInboxStore()
        self.sharedLifeStore = SharedLifeStore()
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
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startBalanceBoard(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        activeBalanceSession = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startMirrorWorkspace(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        activeMirrorSession = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        selectedTab = .home
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
            let tomorrowItem = TomorrowBoxItemFactory.makeQuickItem(
                from: session,
                result: result,
                eventID: event.id
            )
            context.insert(tomorrowItem)
            await NotificationService.shared.scheduleTomorrowNotification(
                eventID: event.id,
                from: event.createdAt
            )
            selectedTab = .box
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
        context.insert(TomorrowBoxItemFactory.makeBalanceItem(from: session, result: result))
        try? context.save()
        activeBalanceSession = nil
        selectedTab = .box
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
        context.insert(TomorrowBoxItemFactory.makeMirrorItem(from: session, result: result))
        try? context.save()
        activeMirrorSession = nil
        selectedTab = .box
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
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func reopenCheckEvent(_ event: CheckEvent) {
        clearActiveDecisionFlows()
        activeQuickSession = event.restoredSession()
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func reopenBalanceRecord(_ record: BalanceDecisionRecord) {
        clearActiveDecisionFlows()
        activeBalanceSession = record.restoredSession()
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func reopenMirrorRecord(_ record: MirrorDecisionRecord) {
        clearActiveDecisionFlows()
        activeMirrorSession = record.restoredSession()
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveCheckEventToTomorrow(_ event: CheckEvent) {
        let context = modelContainer.mainContext
        context.insert(event.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = .box
    }

    func moveBalanceRecordToTomorrow(_ record: BalanceDecisionRecord) {
        let context = modelContainer.mainContext
        context.insert(record.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = .box
    }

    func moveMirrorRecordToTomorrow(_ record: MirrorDecisionRecord) {
        let context = modelContainer.mainContext
        context.insert(record.makeTomorrowBoxItem())
        try? context.save()
        selectedTab = .box
    }

    func removeTomorrowBoxItem(_ item: TomorrowBoxItem) {
        if let eventID = item.linkedCheckEventID {
            NotificationService.shared.cancelTomorrowNotification(eventID: eventID)
        }

        let context = modelContainer.mainContext
        context.delete(item)
        try? context.save()
    }

    func delayTomorrowBoxItem(_ item: TomorrowBoxItem, by delay: TomorrowBoxDelay) {
        item.dueAt = delay.reschedule(from: item.dueAt > .now ? item.dueAt : .now)
        try? modelContainer.mainContext.save()

        if let eventID = item.linkedCheckEventID {
            Task {
                await NotificationService.shared.scheduleTomorrowNotification(
                    eventID: eventID,
                    at: item.dueAt
                )
            }
        }
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
        supportInbox.clearAll()
        sharedLifeStore.clearAll()

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

    @MainActor
    func sendQuickSessionToSupport(_ session: QuickCheckSession, result: QuickCheckResult? = nil) {
        let request = SupportRequestFactory.makeQuickRequest(from: session, result: result)
        supportInbox.insert(request)
        activeQuickSession = nil
        supportSurface = .buddy
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    @MainActor
    func sendBalanceSessionToSupport(_ session: BalanceBoardSession) {
        let request = SupportRequestFactory.makeBalanceRequest(from: session)
        supportInbox.insert(request)
        activeBalanceSession = nil
        supportSurface = .buddy
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    @MainActor
    func sendMirrorSessionToSupport(_ session: MirrorWorkspaceSession) {
        let request = SupportRequestFactory.makeMirrorRequest(from: session)
        supportInbox.insert(request)
        activeMirrorSession = nil
        supportSurface = .buddy
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    func reopenSupportRequest(_ request: SupportRequest) {
        guard let mode = request.mode, let draft = request.draft else { return }

        clearActiveDecisionFlows()
        switch mode {
        case .quick:
            activeQuickSession = draft.restoreQuickSession(entrySource: .app)
        case .balance:
            activeBalanceSession = draft.restoreBalanceSession(entrySource: .app)
        case .mirror:
            activeMirrorSession = draft.restoreMirrorSession(entrySource: .app)
        }

        supportInbox.markHeard(request.id)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveSupportRequestToTomorrow(_ request: SupportRequest) {
        guard let item = TomorrowBoxItemFactory.makeSupportItem(from: request) else { return }
        let context = modelContainer.mainContext
        context.insert(item)
        try? context.save()
        supportInbox.markHeard(request.id)
        selectedTab = .box
    }

    @MainActor
    func sendQuickSessionToSharedLife(_ session: QuickCheckSession, result: QuickCheckResult? = nil) {
        sharedLifeStore.insert(SharedLifeItemFactory.makeQuickItem(from: session, result: result))
        activeQuickSession = nil
        supportSurface = .sharedLife
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    @MainActor
    func sendBalanceSessionToSharedLife(_ session: BalanceBoardSession) {
        sharedLifeStore.insert(SharedLifeItemFactory.makeBalanceItem(from: session))
        activeBalanceSession = nil
        supportSurface = .sharedLife
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    @MainActor
    func sendMirrorSessionToSharedLife(_ session: MirrorWorkspaceSession) {
        sharedLifeStore.insert(SharedLifeItemFactory.makeMirrorItem(from: session))
        activeMirrorSession = nil
        supportSurface = .sharedLife
        selectedTab = .support
        ActiveDecisionWorkspaceStore.clear()
    }

    func reopenSharedLifeItem(_ item: SharedLifeBoxItem) {
        guard let mode = item.mode, let draft = item.draft else { return }

        clearActiveDecisionFlows()
        switch mode {
        case .quick:
            activeQuickSession = draft.restoreQuickSession(entrySource: .app)
        case .balance:
            activeBalanceSession = draft.restoreBalanceSession(entrySource: .app)
        case .mirror:
            activeMirrorSession = draft.restoreMirrorSession(entrySource: .app)
        }

        sharedLifeStore.markReviewing(item.id)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveSharedLifeItemToTomorrow(_ item: SharedLifeBoxItem) {
        guard let tomorrowItem = TomorrowBoxItemFactory.makeSharedLifeItem(from: item) else { return }
        let context = modelContainer.mainContext
        context.insert(tomorrowItem)
        try? context.save()
        sharedLifeStore.deferItem(item.id)
        selectedTab = .box
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

        selectedTab = .home
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
