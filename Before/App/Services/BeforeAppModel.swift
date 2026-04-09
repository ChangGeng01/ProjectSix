import Foundation
import SwiftData
import SwiftUI
import WidgetKit
import BASAdmin

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
    @Published private(set) var activeTaskGraph: DecisionTaskGraphSnapshot?
    @Published private(set) var currentBrainState: CurrentBrainState?
    @Published var interventionCandidate: InterventionPredictionCandidate?
    @Published var reflectionContext: ReflectionContext?
    @Published var letGoContext: LetGoContext?
    @Published var startupNotice: String?
    @Published var supportSurface: SupportSurfaceTarget = .buddy
    @Published private(set) var preferences: BeforePreferences
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    let supportInbox: SupportInboxStore
    let sharedLifeStore: SharedLifeStore
    private var memoryProjection: DecisionMemorySystem.BrainStateProjection?
    private var isMemoryProjectionDirty = true
    private var shouldPromptReflectionAfterBackground = false
    private var pendingReflectionContext: ReflectionContext?

    init(modelContainer: ModelContainer, startupNotice: String? = nil) {
        let testingLaunchOptions = DecisionTestingInterface.launchOptions()
        self.modelContainer = modelContainer
        self.startupNotice = testingLaunchOptions.cleanLaunch ? nil : startupNotice
        self.preferences = DecisionTestingInterface.effectivePreferences()
        self.supportInbox = SupportInboxStore()
        self.sharedLifeStore = SharedLifeStore()
        self.activeTaskGraph = (testingLaunchOptions.cleanLaunch || !preferences.restoreInProgressWorkspaces)
            ? nil
            : DecisionTaskGraphStore.load()
        applyTestingLaunchOptions(testingLaunchOptions)
        restorePendingReflectionState()
    }

    var intelligenceRuntimeStatus: DecisionModelRuntimeStatus {
        DecisionIntelligenceCoordinator.runtimeStatus(preferences: preferences)
    }

    var foundationModelStatus: DecisionModelProviderStatus {
        FoundationModelsIntelligenceService.availabilityStatus
    }

    var gemmaModelStatus: DecisionModelProviderStatus {
        GemmaE4BIntelligenceService.availabilityStatus
    }

    var gemmaBundleStatus: GemmaModelBundleStatus {
        GemmaE4BIntelligenceService.modelBundleStatus
    }

    var gemmaRuntimeStatus: GemmaLocalRuntimeStatus {
        GemmaE4BIntelligenceService.localRuntimeStatus
    }

    var gemmaBundledAsset: GemmaModelAsset? {
        GemmaE4BIntelligenceService.bundledModel
    }

    func handleInitialAppearance() {
        refreshDecisionMemoryStore()
        refreshGlobalBrainState(source: .launch)
        presentPendingReflectionIfNeeded()
        consumePendingLaunchRequestIfNeeded()
        restoreActiveWorkspaceIfNeeded()
        refreshPredictedIntervention()
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
        let route = DecisionIntelligenceCoordinator.route(prompt: prompt, preferences: preferences)
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
        BeforePreferencesStore.save(updated)
        preferences = DecisionTestingInterface.effectivePreferences(stored: updated)

        if updated.restoreInProgressWorkspaces {
            persistActiveWorkspaceState()
        } else {
            ActiveDecisionWorkspaceStore.clear()
            DecisionTaskGraphStore.clear()
            activeTaskGraph = nil
        }
    }

    func refreshPreferencesFromTestingInterface() {
        preferences = DecisionTestingInterface.effectivePreferences()
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
        refreshDecisionMemoryStore()
        primeQuickSession(session)
        activeQuickSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startBalanceBoard(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        let session = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        refreshDecisionMemoryStore()
        primeBalanceSession(session)
        activeBalanceSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startMirrorWorkspace(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        let session = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        refreshDecisionMemoryStore()
        primeMirrorSession(session)
        activeMirrorSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func consumePendingLaunchRequestIfNeeded() {
        if let envelope = WatchHandoffCoordinator.consume() {
            consumeDecisionIntentEnvelope(envelope)
            return
        }
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
            refreshDecisionMemoryStore()
            refreshGlobalBrainState(source: .sceneActive)
            presentPendingReflectionIfNeeded()
            consumePendingLaunchRequestIfNeeded()
            restoreActiveWorkspaceIfNeeded()
            refreshPredictedIntervention()
        case .background:
            if pendingReflectionContext != nil {
                shouldPromptReflectionAfterBackground = true
                persistPendingReflectionState()
            }
            persistActiveWorkspaceState()
            schedulePredictiveInterventionIfNeeded()
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
        persistContext(context, operation: "saving the completed quick check")

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
            presentLetGo(for: tomorrowItem)
        case .leaveStimulus:
            presentLetGo(
                LetGoCopyLibrary.quickStepAwayContext(
                    for: session,
                    result: result
                )
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
        persistContext(context, operation: "saving the balance board")
        activeBalanceSession = nil
        presentLetGo( LetGoCopyLibrary.savedBalanceContext(for: record) )
        persistActiveWorkspaceState()
    }

    func moveBalanceBoardToTomorrow(_ session: BalanceBoardSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let tomorrowItem = TomorrowBoxItemFactory.makeBalanceItem(from: session, result: result)
        context.insert(tomorrowItem)
        persistContext(context, operation: "moving the balance board into Tomorrow Box")
        activeBalanceSession = nil
        presentLetGo(for: tomorrowItem)
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
        persistContext(context, operation: "saving the mirror workspace")
        activeMirrorSession = nil
        presentLetGo( LetGoCopyLibrary.savedMirrorContext(for: record) )
        persistActiveWorkspaceState()
    }

    func moveMirrorWorkspaceToTomorrow(_ session: MirrorWorkspaceSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let tomorrowItem = TomorrowBoxItemFactory.makeMirrorItem(from: session, result: result)
        context.insert(tomorrowItem)
        persistContext(context, operation: "moving the mirror workspace into Tomorrow Box")
        activeMirrorSession = nil
        presentLetGo(for: tomorrowItem)
        persistActiveWorkspaceState()
    }

    func reopenTomorrowBoxItem(_ item: TomorrowBoxItem) {
        clearActiveDecisionFlows()
        refreshDecisionMemoryStore()

        switch item.mode {
        case .quick:
            if let draft = item.draft {
                let session = draft.restoreQuickSession(entrySource: .app)
                primeQuickSession(session)
                activeQuickSession = session
            } else {
                startQuickCheck(entrySource: .app, prompt: item.prompt)
            }
        case .balance:
            if let draft = item.draft {
                let session = draft.restoreBalanceSession(entrySource: .app)
                primeBalanceSession(session)
                activeBalanceSession = session
            } else {
                startBalanceBoard(entrySource: .app, prompt: item.prompt)
            }
        case .mirror:
            if let draft = item.draft {
                let session = draft.restoreMirrorSession(entrySource: .app)
                primeMirrorSession(session)
                activeMirrorSession = session
            } else {
                startMirrorWorkspace(entrySource: .app, prompt: item.prompt)
            }
        }

        removeTomorrowBoxItem(item)
        if let riskLevel = item.riskLevel, riskLevel != .low {
            interventionCandidate = InterventionPredictionCandidate(
                riskLevel: riskLevel,
                title: item.reopenHint ?? item.title,
                detail: item.interventionHistorySummary ?? item.detail,
                evidenceSignalCount: item.interventionHistorySummary == nil ? 1 : 2,
                suggestedMode: item.mode,
                reason: item.templateHint ?? "A previous hold suggests reopening this with more structure.",
                expiresAt: .now.addingTimeInterval(60 * 30)
            )
        } else {
            refreshPredictedIntervention()
        }
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func refreshQuickBrainState(_ session: QuickCheckSession) {
        refreshDecisionMemoryStore()
        primeQuickSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func refreshBalanceBrainState(_ session: BalanceBoardSession) {
        refreshDecisionMemoryStore()
        primeBalanceSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func refreshMirrorBrainState(_ session: MirrorWorkspaceSession) {
        refreshDecisionMemoryStore()
        primeMirrorSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func reopenCheckEvent(_ event: CheckEvent) {
        clearActiveDecisionFlows()
        let session = event.restoredSession()
        refreshDecisionMemoryStore()
        primeQuickSession(session)
        activeQuickSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func reopenBalanceRecord(_ record: BalanceDecisionRecord) {
        clearActiveDecisionFlows()
        let session = record.restoredSession()
        refreshDecisionMemoryStore()
        primeBalanceSession(session)
        activeBalanceSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func reopenMirrorRecord(_ record: MirrorDecisionRecord) {
        clearActiveDecisionFlows()
        let session = record.restoredSession()
        refreshDecisionMemoryStore()
        primeMirrorSession(session)
        activeMirrorSession = session
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveCheckEventToTomorrow(_ event: CheckEvent) {
        let context = modelContainer.mainContext
        let tomorrowItem = event.makeTomorrowBoxItem()
        context.insert(tomorrowItem)
        persistContext(
            context,
            operation: "moving the quick check into Tomorrow Box",
            refreshMemoryProjection: false
        )
        presentLetGo(for: tomorrowItem)
    }

    func moveBalanceRecordToTomorrow(_ record: BalanceDecisionRecord) {
        let context = modelContainer.mainContext
        let tomorrowItem = record.makeTomorrowBoxItem()
        context.insert(tomorrowItem)
        persistContext(
            context,
            operation: "moving the balance record into Tomorrow Box",
            refreshMemoryProjection: false
        )
        presentLetGo(for: tomorrowItem)
    }

    func moveMirrorRecordToTomorrow(_ record: MirrorDecisionRecord) {
        let context = modelContainer.mainContext
        let tomorrowItem = record.makeTomorrowBoxItem()
        context.insert(tomorrowItem)
        persistContext(
            context,
            operation: "moving the mirror record into Tomorrow Box",
            refreshMemoryProjection: false
        )
        presentLetGo(for: tomorrowItem)
    }

    func removeTomorrowBoxItem(_ item: TomorrowBoxItem) {
        if let eventID = item.linkedCheckEventID {
            NotificationService.shared.cancelTomorrowNotification(eventID: eventID)
        }

        let context = modelContainer.mainContext
        context.delete(item)
        persistContext(
            context,
            operation: "removing a Tomorrow Box item",
            refreshMemoryProjection: false
        )
    }

    func delayTomorrowBoxItem(_ item: TomorrowBoxItem, by delay: TomorrowBoxDelay) {
        item.dueAt = delay.reschedule(from: item.dueAt > .now ? item.dueAt : .now)
        persistContext(
            modelContainer.mainContext,
            operation: "rescheduling a Tomorrow Box item",
            refreshMemoryProjection: false
        )

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
            DecisionReactionBanditStore.update(
                mode: .quick,
                riskLevel: inferredRiskLevel(for: event, outcome: outcome),
                languageMode: DecisionLanguageMode.detect(
                    preferredLanguages: Locale.preferredLanguages,
                    sampleTexts: [event.note, trimmedNote]
                ),
                chosenArmID: chosenArmID(for: event.finalAction),
                reward: reflectionReward(outcome)
            )
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

        persistContext(context, operation: "saving reflection follow-up")
        refreshGlobalBrainState(source: .explicitRefresh)
        refreshPredictedIntervention()
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

    func bestReminder(for scenario: ScenarioType) async -> String? {
        await bestReminder(for: scenario, prompt: "", mode: nil)
    }

    func bestReminder(for scenario: ScenarioType, prompt: String, mode: DecisionMode?) async -> String? {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SelfReminder>()
        let reminders = (try? context.fetch(descriptor)) ?? []
        return await DecisionIntelligenceCoordinator.bestReminderWithIntelligence(
            from: reminders,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            preferences: preferences
        )?.content
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
        deleteAll(DecisionMemoryRecord.self, in: context)
        deleteAll(DecisionMemoryCandidateRecord.self, in: context)

        resetTransientState()
        refreshWidgetSurfaces()
    }

    func clearReminders() {
        let context = modelContainer.mainContext
        deleteAll(SelfReminder.self, in: context)
        refreshDecisionMemoryStore()
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
        persistContext(context, operation: "clearing Tomorrow Box", refreshMemoryProjection: false)
    }

    func resetLocalData() {
        let context = modelContainer.mainContext
        deleteAll(CheckEvent.self, in: context)
        deleteAll(BalanceDecisionRecord.self, in: context)
        deleteAll(MirrorDecisionRecord.self, in: context)
        deleteAll(SelfReminder.self, in: context)
        deleteAll(DecisionMemoryRecord.self, in: context)
        deleteAll(DecisionMemoryCandidateRecord.self, in: context)
        deleteAll(BrainStateUpdate.self, in: context)
        deleteAll(DecisionEvolutionCheckpoint.self, in: context)
        deleteAll(InterventionTrigger.self, in: context)
        deleteAll(InterventionTemplateRecord.self, in: context)
        deleteAll(FailurePatternRecord.self, in: context)
        clearTomorrowBox()
        supportInbox.clearAll()
        sharedLifeStore.clearAll()

        PendingLaunchRequestStore.clear()
        DecisionIntentEnvelopeStore.clear()
        DecisionReactionBanditStore.clear()
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

    func dismissInterventionCandidate() {
        if let interventionCandidate {
            NotificationService.shared.cancelPredictiveInterventionNotification(candidateID: interventionCandidate.id)
            markInterventionTriggerDismissed(candidateID: interventionCandidate.id)
        }
        interventionCandidate = nil
    }

    func applyInterventionCandidate(_ candidate: InterventionPredictionCandidate) {
        interventionCandidate = nil
        switch candidate.riskLevel {
        case .low:
            selectedTab = .box
        case .medium, .high:
            if let mode = candidate.suggestedMode {
                startDecisionMode(mode, entrySource: .app, prompt: candidate.title)
            } else {
                selectedTab = .box
            }
        }
    }

    func portraitPanelState() -> BrainPortraitPanelState {
        let context = modelContainer.mainContext
        let records = DecisionMemorySystem.fetchMemoryRecords(in: context)
        let candidates = DecisionMemorySystem.fetchCandidateRecords(in: context)
        let memories =
            records.map {
                BrainPortraitMemoryItem(
                    id: $0.id,
                    title: $0.headline,
                    detail: $0.provenanceSummary,
                    source: $0.source,
                    confidence: $0.confidence,
                    tier: $0.tier,
                    isPending: false,
                    lastConfirmedAt: $0.lastConfirmedAt,
                    governanceStatus: .admitted
                )
            } +
            candidates.map {
                BrainPortraitMemoryItem(
                    id: $0.id,
                    title: $0.headline,
                    detail: $0.provenanceSummary,
                    source: $0.source,
                    confidence: $0.confidence,
                    tier: $0.tier,
                    isPending: true,
                    lastConfirmedAt: $0.lastObservedAt,
                    governanceStatus: $0.lastGovernanceDecision == .deferred ? .deferred : .pending
                )
            }

        return BrainPortraitPanelState(
            currentBrainState: currentBrainState,
            memories: memories.sorted { $0.confidence > $1.confidence },
            templates: InterventionTemplateStore.selectTemplates(
                in: context,
                mode: currentBrainState?.mode ?? .quick,
                riskLevel: interventionCandidate?.riskLevel ?? .low,
                recommendedArmIDs: currentBrainState?.activeTemplateIDs ?? []
            )
            .map {
                BrainPortraitTemplateItem(
                    id: $0.id,
                    title: $0.title,
                    summary: $0.summary,
                    body: $0.body,
                    mode: $0.mode,
                    riskLevel: $0.riskLevel,
                    isPinned: $0.isPinned,
                    successCount: $0.successCount
                )
            },
            failurePatterns: FailurePatternStore.selectedFailurePatterns(
                in: context,
                mode: currentBrainState?.mode ?? .quick
            )
            .map {
                BrainPortraitFailurePatternItem(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    mode: $0.mode,
                    cadenceTag: $0.cadenceTag,
                    suppressionWeight: $0.suppressionWeight,
                    evidenceCount: $0.evidenceCount
                )
            },
            generatedAt: .now
        )
    }

    func systemFlightDeck() async -> DecisionSystemFlightDeck {
        let export = await decisionRuntimeExport()
        return export.flightDeck
    }

    func substrateConsoleSnapshot() async -> BASConsoleSnapshot {
        let export = await decisionRuntimeExport()
        return BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: currentBrainState
        )
    }

    func deleteBrainPortraitMemory(id: String) {
        let context = modelContainer.mainContext
        if let record = DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == id }) {
            context.delete(record)
        }
        if let candidate = DecisionMemorySystem.fetchCandidateRecords(in: context).first(where: { $0.id == id }) {
            context.delete(candidate)
        }
        persistContext(context, operation: "deleting portrait memory", refreshMemoryProjection: true)
        refreshGlobalBrainState(source: .explicitRefresh)
    }

    func downgradeBrainPortraitMemory(id: String) {
        let context = modelContainer.mainContext
        if let record = DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == id }) {
            record.confidence = max(0.2, record.confidence - 0.2)
            record.priority = max(0.2, record.priority - 0.2)
            record.lifecycleStateRaw = DecisionMemoryLifecycleState.aging.rawValue
        }
        if let candidate = DecisionMemorySystem.fetchCandidateRecords(in: context).first(where: { $0.id == id }) {
            candidate.confidence = max(0.2, candidate.confidence - 0.2)
        }
        persistContext(context, operation: "downgrading portrait memory", refreshMemoryProjection: true)
        refreshGlobalBrainState(source: .explicitRefresh)
    }

    func markBrainPortraitMemoryAsNotMe(id: String) {
        let context = modelContainer.mainContext
        if let record = DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == id }) {
            record.lifecycleStateRaw = DecisionMemoryLifecycleState.retired.rawValue
            record.priority = 0
        }
        if let candidate = DecisionMemorySystem.fetchCandidateRecords(in: context).first(where: { $0.id == id }) {
            context.delete(candidate)
        }
        persistContext(context, operation: "retiring portrait memory", refreshMemoryProjection: true)
        refreshGlobalBrainState(source: .explicitRefresh)
    }

    func pinInterventionTemplate(id: String) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<InterventionTemplateRecord>()
        if let template = (try? context.fetch(descriptor))?.first(where: { $0.id == id }) {
            template.isPinned = true
            persistContext(context, operation: "pinning intervention template")
            refreshGlobalBrainState(source: .explicitRefresh)
        }
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
            let session = draft.restoreQuickSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeQuickSession(session)
            activeQuickSession = session
        case .balance:
            let session = draft.restoreBalanceSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeBalanceSession(session)
            activeBalanceSession = session
        case .mirror:
            let session = draft.restoreMirrorSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeMirrorSession(session)
            activeMirrorSession = session
        }

        supportInbox.markHeard(request.id)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveSupportRequestToTomorrow(_ request: SupportRequest) {
        guard let item = TomorrowBoxItemFactory.makeSupportItem(from: request) else { return }
        let context = modelContainer.mainContext
        context.insert(item)
        persistContext(
            context,
            operation: "moving a support request into Tomorrow Box",
            refreshMemoryProjection: false
        )
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
            let session = draft.restoreQuickSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeQuickSession(session)
            activeQuickSession = session
        case .balance:
            let session = draft.restoreBalanceSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeBalanceSession(session)
            activeBalanceSession = session
        case .mirror:
            let session = draft.restoreMirrorSession(entrySource: .app)
            refreshDecisionMemoryStore()
            primeMirrorSession(session)
            activeMirrorSession = session
        }

        sharedLifeStore.markReviewing(item.id)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func moveSharedLifeItemToTomorrow(_ item: SharedLifeBoxItem) {
        guard let tomorrowItem = TomorrowBoxItemFactory.makeSharedLifeItem(from: item) else { return }
        let context = modelContainer.mainContext
        context.insert(tomorrowItem)
        persistContext(
            context,
            operation: "moving a shared-life item into Tomorrow Box",
            refreshMemoryProjection: false
        )
        sharedLifeStore.deferItem(item.id)
        selectedTab = .box
    }

    func dismissLetGo(to target: AppTab) {
        selectedTab = target
        letGoContext = nil
    }

    func presentDeveloperLetGoPreview() {
        presentLetGo(LetGoCopyLibrary.developerPreviewContext())
    }

    private func clearActiveDecisionFlows() {
        activeQuickSession = nil
        activeBalanceSession = nil
        activeMirrorSession = nil
        activeTaskGraph = nil
        currentBrainState = nil
        DecisionTaskGraphStore.clear()
    }

    private func presentLetGo(for item: TomorrowBoxItem) {
        selectedTab = .home
        letGoContext = LetGoCopyLibrary.tomorrowBoxContext(for: item)
    }

    private func presentLetGo(_ context: LetGoContext) {
        selectedTab = .home
        letGoContext = context
    }

    private func trimReminders(in context: ModelContext) {
        let descriptor = FetchDescriptor<SelfReminder>()
        guard let reminders = try? context.fetch(descriptor) else { return }
        ReminderSelectionPolicy.remindersToTrim(from: reminders).forEach { context.delete($0) }
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) {
        let descriptor = FetchDescriptor<Model>()
        ((try? context.fetch(descriptor)) ?? []).forEach { context.delete($0) }
        persistContext(
            context,
            operation: "clearing \(String(describing: type)) records",
            refreshMemoryProjection: false
        )
    }

    private func refreshWidgetSurfaces() {
        syncWidgetSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func resetTransientState() {
        clearActiveDecisionFlows()
        reflectionContext = nil
        letGoContext = nil
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
            let session = state.restoreQuickSession()
            refreshDecisionMemoryStore()
            primeQuickSession(session)
            activeQuickSession = session
        case .balance:
            let session = state.restoreBalanceSession()
            refreshDecisionMemoryStore()
            primeBalanceSession(session)
            activeBalanceSession = session
        case .mirror:
            let session = state.restoreMirrorSession()
            refreshDecisionMemoryStore()
            primeMirrorSession(session)
            activeMirrorSession = session
        }

        selectedTab = .home
        refreshActiveTaskGraphSnapshot()
        refreshPredictedIntervention()
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

        refreshActiveTaskGraphSnapshot()
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyTestingLaunchOptions(_ options: DecisionTestingLaunchOptions) {
        guard !options.isEmpty else { return }

        if options.cleanLaunch {
            PendingLaunchRequestStore.clear()
            PendingReflectionStore.clear()
            ActiveDecisionWorkspaceStore.clear()
            DecisionTaskGraphStore.clear()
            WidgetSnapshotStore.clear()
            Task {
                await DecisionTestingInterface.resetTransientIntelligenceState()
            }

            let context = modelContainer.mainContext
            deleteAll(CheckEvent.self, in: context)
            deleteAll(BalanceDecisionRecord.self, in: context)
            deleteAll(MirrorDecisionRecord.self, in: context)
            deleteAll(SelfReminder.self, in: context)
            deleteAll(DecisionMemoryRecord.self, in: context)
            deleteAll(DecisionMemoryCandidateRecord.self, in: context)
            deleteAll(TomorrowBoxItem.self, in: context)

            supportInbox.clearAll()
            sharedLifeStore.clearAll()
            reflectionContext = nil
            letGoContext = nil
            pendingReflectionContext = nil
            shouldPromptReflectionAfterBackground = false
            activeTaskGraph = nil
        }

        if options.skipOnboarding {
            hasSeenOnboarding = true
        }
    }

    private func refreshDecisionMemoryStore(force: Bool = false) {
        guard force || isMemoryProjectionDirty || memoryProjection == nil else { return }
        let context = modelContainer.mainContext
        InterventionTemplateStore.ensureDefaults(in: context)
        FailurePatternStore.syncFromHistory(in: context)
        memoryProjection = DecisionMemorySystem.refreshProjection(in: context)
        isMemoryProjectionDirty = false
        if let notice = PersistenceIssueRecorder.latestNotice() ?? StateStorageIssueRecorder.latestNotice() {
            publishStartupNotice(notice)
        }
    }

    private func decisionRuntimeExport() async -> DecisionTestingRuntimeExport {
        let context = modelContainer.mainContext
        return await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: preferences
        )
    }

    private func primeQuickSession(_ session: QuickCheckSession) {
        refreshDecisionMemoryStore()
        let strategy = DecisionIntelligenceCoordinator
            .executionProfile(preferences: preferences)
            .strategy(for: .quick)
        currentBrainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: quickPromptSeed(for: session),
            source: .sessionPrime,
            taskGraph: activeTaskGraph,
            context: modelContainer.mainContext,
            projection: currentMemoryProjection(),
            retrievalMode: strategy.retrievalMode
        )
        session.loadBrainState(currentBrainState?.brainState)
    }

    private func primeBalanceSession(_ session: BalanceBoardSession) {
        refreshDecisionMemoryStore()
        let strategy = DecisionIntelligenceCoordinator
            .executionProfile(preferences: preferences)
            .strategy(for: .balance)
        currentBrainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .balance,
            prompt: balancePromptSeed(for: session),
            source: .sessionPrime,
            taskGraph: activeTaskGraph,
            context: modelContainer.mainContext,
            projection: currentMemoryProjection(),
            retrievalMode: strategy.retrievalMode
        )
        session.loadBrainState(currentBrainState?.brainState)
    }

    private func primeMirrorSession(_ session: MirrorWorkspaceSession) {
        refreshDecisionMemoryStore()
        let strategy = DecisionIntelligenceCoordinator
            .executionProfile(preferences: preferences)
            .strategy(for: .mirror)
        currentBrainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .mirror,
            prompt: mirrorPromptSeed(for: session),
            source: .sessionPrime,
            taskGraph: activeTaskGraph,
            context: modelContainer.mainContext,
            projection: currentMemoryProjection(),
            retrievalMode: strategy.retrievalMode
        )
        session.loadBrainState(currentBrainState?.brainState)
    }

    private func quickPromptSeed(for session: QuickCheckSession) -> String {
        [
            session.scenario.title,
            session.note,
            session.motivation?.title ?? "",
            session.expectedOutcome?.title ?? "",
            session.controlLevel?.title ?? ""
        ]
        .map(trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func balancePromptSeed(for session: BalanceBoardSession) -> String {
        [
            session.prompt,
            session.desire,
            session.concern,
            session.constraint,
            session.longTerm
        ]
        .map(trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func mirrorPromptSeed(for session: MirrorWorkspaceSession) -> String {
        [
            session.prompt,
            session.emotion,
            session.relationship,
            session.reality,
            session.longTerm,
            session.selfLens
        ]
        .map(trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func refreshGlobalBrainState(source: BrainStateUpdateSource) {
        refreshDecisionMemoryStore()

        let mode: DecisionMode
        let promptSeed: String

        if let activeQuickSession {
            mode = .quick
            promptSeed = quickPromptSeed(for: activeQuickSession)
        } else if let activeBalanceSession {
            mode = .balance
            promptSeed = balancePromptSeed(for: activeBalanceSession)
        } else if let activeMirrorSession {
            mode = .mirror
            promptSeed = mirrorPromptSeed(for: activeMirrorSession)
        } else if let activeTaskGraph, let taskMode = activeTaskGraph.mode {
            mode = taskMode
            promptSeed = activeTaskGraph.promptSeed
        } else {
            mode = .quick
            promptSeed = ""
        }

        let traceKind: DecisionIntelligenceTraceKind
        switch mode {
        case .quick:
            traceKind = .quick
        case .balance:
            traceKind = .balance
        case .mirror:
            traceKind = .mirror
        }

        let strategy = DecisionIntelligenceCoordinator
            .executionProfile(preferences: preferences)
            .strategy(for: traceKind)

        currentBrainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: mode,
            prompt: promptSeed,
            source: source,
            taskGraph: activeTaskGraph,
            context: modelContainer.mainContext,
            projection: currentMemoryProjection(),
            retrievalMode: strategy.retrievalMode
        )
    }

    private func consumeDecisionIntentEnvelope(_ envelope: DecisionIntentEnvelope) {
        switch envelope.kind {
        case .quickCapture:
            startQuickCheck(
                entrySource: envelope.entrySource,
                scenario: envelope.scenario,
                prompt: envelope.promptSeed ?? ""
            )
        case .openMode:
            startDecisionMode(
                envelope.preferredMode ?? .quick,
                entrySource: envelope.entrySource,
                prompt: envelope.promptSeed ?? ""
            )
        case .reopenTomorrowItem:
            selectedTab = .box
            startDecisionMode(
                envelope.preferredMode ?? .quick,
                entrySource: envelope.entrySource,
                prompt: envelope.promptSeed ?? ""
            )
        case .predictiveIntervention:
            interventionCandidate = InterventionPredictionCandidate(
                riskLevel: envelope.riskLevel ?? .medium,
                title: envelope.promptSeed ?? "Pause before you decide.",
                detail: "A predicted pattern says a slower move is safer here.",
                evidenceSignalCount: envelope.triggerReason == nil ? 1 : 2,
                suggestedMode: envelope.preferredMode,
                reason: envelope.triggerReason ?? "A recent pattern suggests more friction before acting.",
                expiresAt: envelope.expiresAt
            )
        case .resumeCurrentDecision:
            restoreActiveWorkspaceIfNeeded()
        }

        refreshGlobalBrainState(source: envelope.sourceSurface == .watch ? .watchHandoff : .explicitRefresh)
    }

    private func refreshPredictedIntervention() {
        let next = InterventionPredictionEngine.predictCandidate(
            currentBrainState: currentBrainState,
            context: modelContainer.mainContext,
            preferences: preferences
        )
        if let existing = interventionCandidate, let next,
           existing.riskLevel == next.riskLevel,
           existing.title == next.title,
           existing.detail == next.detail,
           existing.evidenceSignalCount == next.evidenceSignalCount,
           existing.reason == next.reason,
           existing.suggestedMode == next.suggestedMode {
            interventionCandidate = existing
        } else {
            interventionCandidate = next
        }
    }

    private func schedulePredictiveInterventionIfNeeded() {
        guard preferences.predictiveInterventionsEnabled,
              let interventionCandidate,
              interventionCandidate.riskLevel != .low else {
            return
        }

        let context = modelContainer.mainContext
        let policyDecision = InterventionNotificationPolicyEngine.decide(
            candidate: interventionCandidate,
            preferences: preferences,
            context: context
        )
        upsertInterventionTrigger(
            interventionCandidate,
            wasDelivered: policyDecision.isAllowed
        )

        guard policyDecision.isAllowed else {
            NotificationService.shared.cancelPredictiveInterventionNotification(candidateID: interventionCandidate.id)
            return
        }

        Task {
            await NotificationService.shared.schedulePredictiveInterventionNotification(interventionCandidate)
        }
    }

    private func reflectionReward(_ outcome: ReflectionOutcome) -> Bool {
        switch outcome {
        case .betterThanExpected, .okay, .notNeeded:
            true
        case .regrettedIt, .feltEmptier:
            false
        }
    }

    private func chosenArmID(for action: CheckAction) -> String {
        switch action {
        case .decideTomorrow, .wait90s:
            "tomorrow_box_interrupt"
        case .leaveStimulus:
            "slow_delay_guard"
        case .goAheadAnyway, .continueMindfully:
            "brief_warm_nudge"
        }
    }

    private func inferredRiskLevel(
        for event: CheckEvent,
        outcome: ReflectionOutcome
    ) -> InterventionRiskLevel {
        switch outcome {
        case .regrettedIt, .feltEmptier:
            .high
        case .okay:
            .medium
        case .betterThanExpected, .notNeeded:
            switch event.finalAction {
            case .goAheadAnyway, .continueMindfully:
                .medium
            case .wait90s, .leaveStimulus, .decideTomorrow:
                .low
            }
        }
    }

    private func refreshActiveTaskGraphSnapshot() {
        let snapshot: DecisionTaskGraphSnapshot?

        if let session = activeQuickSession {
            snapshot = DecisionTaskGraphSnapshot.capture(from: session)
        } else if let session = activeBalanceSession {
            snapshot = DecisionTaskGraphSnapshot.capture(from: session)
        } else if let session = activeMirrorSession {
            snapshot = DecisionTaskGraphSnapshot.capture(from: session)
        } else {
            snapshot = nil
        }

        activeTaskGraph = snapshot

        if let snapshot {
            DecisionTaskGraphStore.save(snapshot)
        } else {
            DecisionTaskGraphStore.clear()
        }
    }

    private func currentMemoryProjection() -> DecisionMemorySystem.BrainStateProjection {
        if let memoryProjection {
            return memoryProjection
        }
        refreshDecisionMemoryStore(force: true)
        return memoryProjection ?? DecisionMemorySystem.refreshProjection(in: modelContainer.mainContext)
    }

    private func persistContext(
        _ context: ModelContext,
        operation: String,
        refreshMemoryProjection: Bool = false
    ) {
        do {
            try context.save()
            isMemoryProjectionDirty = true
            if refreshMemoryProjection {
                refreshDecisionMemoryStore(force: true)
            }
        } catch {
            let notice = PersistenceIssueRecorder.record(error: error, operation: operation)
            publishStartupNotice(notice)
        }
    }

    private func publishStartupNotice(_ notice: String) {
        guard !notice.isEmpty else { return }
        if let startupNotice {
            guard !startupNotice.contains(notice) else { return }
            self.startupNotice = "\(startupNotice)\n\n\(notice)"
            return
        }
        startupNotice = notice
    }

    private func upsertInterventionTrigger(
        _ candidate: InterventionPredictionCandidate,
        wasDelivered: Bool
    ) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<InterventionTrigger>(
            predicate: #Predicate<InterventionTrigger> { trigger in
                trigger.id == candidate.id
            }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.createdAt = candidate.createdAt
            existing.riskLevelRaw = candidate.riskLevel.rawValue
            existing.title = candidate.title
            existing.detail = candidate.detail
            existing.reason = candidate.reason
            existing.suggestedModeRaw = candidate.suggestedMode?.rawValue
            existing.wasDelivered = wasDelivered
        } else {
            context.insert(
                InterventionTrigger(
                    id: candidate.id,
                    createdAt: candidate.createdAt,
                    riskLevel: candidate.riskLevel,
                    title: candidate.title,
                    detail: candidate.detail,
                    reason: candidate.reason,
                    suggestedMode: candidate.suggestedMode,
                    wasDelivered: wasDelivered
                )
            )
        }
        persistContext(context, operation: "recording predictive intervention trigger")
    }

    private func markInterventionTriggerDismissed(candidateID: UUID) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<InterventionTrigger>(
            predicate: #Predicate<InterventionTrigger> { trigger in
                trigger.id == candidateID
            }
        )
        guard let trigger = (try? context.fetch(descriptor))?.first else { return }
        trigger.wasDismissed = true
        persistContext(context, operation: "recording predictive intervention dismissal")
    }
}
