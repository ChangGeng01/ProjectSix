import Foundation
import SwiftData
import SwiftUI
import WidgetKit
import BASHostKit

struct DecisionSignal {
    let eyebrow: String
    let title: String
    let detail: String
}

private struct InspectionBrainSnapshot {
    let currentBrain: CurrentBrainState?
    let projection: DecisionMemorySystem.BrainStateProjection?
    let now: Date
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
    @Published var isEvolutionControlCenterPresented = false
    @Published var startupNotice: String?
    @Published var supportSurface: SupportSurfaceTarget = .buddy
    @Published private(set) var preferences: BeforePreferences
    @Published private(set) var evolutionControlMutationEpoch: Int = 0
    @Published private(set) var latestEvolutionMutationOutcome: DecisionEvolutionMutationOutcome?
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    let supportInbox: SupportInboxStore
    let sharedLifeStore: SharedLifeStore
    private let hostRuntime = BeforeProductCompatibility.makeHostRuntime()
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
        executeLifecyclePhase(.initialAppearance, syncWidgetSnapshot: true)
    }

    func dismissStartupNotice() {
        startupNotice = nil
    }

    func dismissEvolutionMutationOutcome() {
        latestEvolutionMutationOutcome = nil
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
        activateQuickSession(session)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startBalanceBoard(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        let session = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        activateBalanceSession(session)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func startMirrorWorkspace(entrySource: EntrySource, prompt: String = "") {
        clearActiveDecisionFlows()
        let session = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        activateMirrorSession(session)
        selectedTab = .home
        persistActiveWorkspaceState()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            executeLifecyclePhase(.sceneActive)
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

    private func executeLifecyclePhase(
        _ phase: BASHostLifecyclePhase,
        syncWidgetSnapshot shouldSyncWidgetSnapshot: Bool = false
    ) {
        hostRuntime.executeLifecyclePhase(
            phase,
            refreshMemoryProjection: { refreshDecisionMemoryStore() },
            refreshCurrentBrain: { triggerID in
                refreshGlobalBrainState(
                    source: BrainStateUpdateSource(rawValue: triggerID) ?? .explicitRefresh
                )
            },
            presentPendingReflection: { presentPendingReflectionIfNeeded() },
            consumeHandoff: { WatchHandoffCoordinator.consume() },
            handleHandoff: { envelope in
                BehavioralAISubstrateBridge.consumeDecisionIntentEnvelope(
                    envelope,
                    performCapture: { envelope, scenario, prompt in
                        startQuickCheck(
                            entrySource: envelope.entrySource,
                            scenario: scenario,
                            prompt: prompt
                        )
                    },
                    performPresent: { envelope, mode, shouldSelectBoxTab, prompt in
                        if shouldSelectBoxTab {
                            selectedTab = .box
                        }
                        startDecisionMode(
                            mode,
                            entrySource: envelope.entrySource,
                            prompt: prompt
                        )
                    },
                    performPredictiveIntervention: { suggestion in
                        interventionCandidate = suggestion.map(makeInterventionCandidate(from:))
                    },
                    performRestore: { restoreActiveWorkspaceIfNeeded() },
                    refreshCurrentBrain: { source in
                        refreshGlobalBrainState(source: source)
                    }
                )
            },
            consumePendingRequest: { PendingLaunchRequestStore.consume() },
            handlePendingRequest: { request in
                BASApplePendingLaunchRuntimeExecutor.execute(
                    input: BASApplePendingLaunchRuntimeInput(
                        preferredModeID: DecisionMode.fromSubstrateModeID(request.preferredModeRaw)?.substrateModeID ?? request.preferredModeRaw,
                        scenarioID: request.scenarioRaw,
                        promptSeed: request.prompt
                    ),
                    performCapture: { plan in
                        startQuickCheck(
                            entrySource: request.entrySource,
                            scenario: plan.scenarioID.flatMap(ScenarioType.init(rawValue:)),
                            prompt: plan.promptSeed
                        )
                    },
                    performPresent: { plan in
                        startDecisionMode(
                            DecisionMode.fromSubstrateModeID(plan.preferredModeID) ?? .quick,
                            entrySource: request.entrySource,
                            prompt: plan.promptSeed
                        )
                    },
                    performRoutedInput: { plan in
                        _ = routeDecision(prompt: plan.promptSeed, entrySource: request.entrySource)
                    }
                )
            },
            restoreActiveWorkspace: { restoreActiveWorkspaceIfNeeded() },
            refreshPredictedIntervention: { refreshPredictedIntervention() },
            syncWidgetSnapshot: {
                guard shouldSyncWidgetSnapshot else { return }
                syncWidgetSnapshot()
            }
        )
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

        recordCurrentEBrainReplayTurn(now: event.createdAt)

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
        recordCurrentEBrainReplayTurn(now: record.updatedAt)
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
        recordCurrentEBrainReplayTurn(now: record.updatedAt)
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
        hostRuntime.reopenHeldItem(
            modeID: item.mode.substrateModeID,
            promptSeed: item.prompt,
            hasDraft: item.draft != nil,
            title: item.title,
            detail: item.detail,
            riskLevelID: item.riskLevel?.rawValue,
            reopenHint: item.reopenHint,
            templateHint: item.templateHint,
            interventionHistorySummary: item.interventionHistorySummary,
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            activatePrimaryFromDraft: {
                guard let draft = item.draft else { return }
                activateQuickSession(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparativeFromDraft: {
                guard let draft = item.draft else { return }
                activateBalanceSession(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflectiveFromDraft: {
                guard let draft = item.draft else { return }
                activateMirrorSession(draft.restoreMirrorSession(entrySource: .app))
            },
            startPrimary: { prompt in
                startQuickCheck(entrySource: .app, prompt: prompt)
            },
            startComparative: { prompt in
                startBalanceBoard(entrySource: .app, prompt: prompt)
            },
            startReflective: { prompt in
                startMirrorWorkspace(entrySource: .app, prompt: prompt)
            },
            removeItem: {
                removeTomorrowBoxItem(item)
            },
            applyInterventionSuggestion: { suggestion in
                interventionCandidate = suggestion.map(makeInterventionCandidate(from:))
            },
            refreshPredictedIntervention: { refreshPredictedIntervention() },
            selectHomeTab: {
                selectedTab = .home
            },
            persistActiveWorkspaceState: { persistActiveWorkspaceState() }
        )
    }

    func refreshQuickBrainState(_ session: QuickCheckSession) {
        activateQuickSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func refreshBalanceBrainState(_ session: BalanceBoardSession) {
        activateBalanceSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func refreshMirrorBrainState(_ session: MirrorWorkspaceSession) {
        activateMirrorSession(session)
        refreshActiveTaskGraphSnapshot()
    }

    func evaluateQuickSessionWithIntelligence(_ session: QuickCheckSession) async {
        refreshQuickBrainState(session)
        let turn = currentLiveEBrainTurn(now: .now)
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn
        )
    }

    func evaluateBalanceSessionWithIntelligence(_ session: BalanceBoardSession) async {
        refreshBalanceBrainState(session)
        let turn = currentLiveEBrainTurn(now: .now)
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn
        )
    }

    func evaluateMirrorSessionWithIntelligence(_ session: MirrorWorkspaceSession) async {
        refreshMirrorBrainState(session)
        let turn = currentLiveEBrainTurn(now: .now)
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn
        )
    }

    func reopenCheckEvent(_ event: CheckEvent) {
        hostRuntime.reopenSimpleItem(
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            reopen: {
                activateQuickSession(event.restoredSession())
            },
            selectHomeTab: {
                selectedTab = .home
            },
            persistActiveWorkspaceState: { persistActiveWorkspaceState() }
        )
    }

    func reopenBalanceRecord(_ record: BalanceDecisionRecord) {
        hostRuntime.reopenSimpleItem(
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            reopen: {
                activateBalanceSession(record.restoredSession())
            },
            selectHomeTab: {
                selectedTab = .home
            },
            persistActiveWorkspaceState: { persistActiveWorkspaceState() }
        )
    }

    func reopenMirrorRecord(_ record: MirrorDecisionRecord) {
        hostRuntime.reopenSimpleItem(
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            reopen: {
                activateMirrorSession(record.restoredSession())
            },
            selectHomeTab: {
                selectedTab = .home
            },
            persistActiveWorkspaceState: { persistActiveWorkspaceState() }
        )
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
                riskLevel: InterventionRiskLevel(
                    rawValue: BASAppleReflectionAdaptationAdvisor.riskLevel(
                        finalActionID: event.finalAction.rawValue,
                        outcomeID: outcome.rawValue
                    ).rawValue
                ) ?? .medium,
                languageMode: DecisionLanguageMode.detect(
                    preferredLanguages: Locale.preferredLanguages,
                    sampleTexts: [event.note, trimmedNote]
                ),
                chosenArmID: BASAppleReflectionAdaptationAdvisor.chosenArmID(
                    finalActionID: event.finalAction.rawValue
                ),
                reward: BASAppleReflectionAdaptationAdvisor.reward(outcomeID: outcome.rawValue)
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

    @MainActor
    func approveEvolutionCheckpoint(checkpointID: String) {
        let updated = updateEvolutionCheckpoint {
            BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
                checkpointID,
                to: .automatic,
                in: $0
            )
        }
        guard updated != nil else {
            publishEvolutionMutationOutcome(
                kind: .approveCheckpoint,
                title: "Approve checkpoint",
                message: "Checkpoint \(checkpointID) could not be approved for automatic evolution.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: [checkpointID]
            )
            return
        }
        publishEvolutionMutationOutcome(
            kind: .approveCheckpoint,
            title: "Approve checkpoint",
            message: "Checkpoint \(checkpointID) is now back on the automatic evolution path.",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: [checkpointID]
        )
        publishStartupNotice("Checkpoint \(checkpointID) approved for automatic evolution.")
    }

    @MainActor
    func markEvolutionCheckpointForReview(checkpointID: String) {
        let updated = updateEvolutionCheckpoint {
            BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
                checkpointID,
                to: .reviewSuggested,
                in: $0
            )
        }
        guard updated != nil else {
            publishEvolutionMutationOutcome(
                kind: .markCheckpointForReview,
                title: "Mark review",
                message: "Checkpoint \(checkpointID) could not be moved into the review queue.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: [checkpointID]
            )
            return
        }
        publishEvolutionMutationOutcome(
            kind: .markCheckpointForReview,
            title: "Mark review",
            message: "Checkpoint \(checkpointID) is now queued for explicit host review.",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: [checkpointID]
        )
        publishStartupNotice("Checkpoint \(checkpointID) marked for review.")
    }

    @MainActor
    func clearEvolutionCheckpointLineage(checkpointID: String) {
        let updated = updateEvolutionCheckpoint {
            BehavioralAISubstrateBridge.clearEvolutionCheckpointLineage(
                checkpointID,
                in: $0
            )
        }
        guard updated != nil else {
            publishEvolutionMutationOutcome(
                kind: .clearCheckpointLineage,
                title: "Clear lineage",
                message: "Checkpoint \(checkpointID) had no persisted lineage available to clear.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: [checkpointID]
            )
            return
        }
        publishEvolutionMutationOutcome(
            kind: .clearCheckpointLineage,
            title: "Clear lineage",
            message: "Persisted lineage was cleared for checkpoint \(checkpointID) while the checkpoint record stayed in place.",
            isSuccess: true,
            isDestructive: true,
            checkpointIDs: [checkpointID]
        )
        publishStartupNotice("Cleared persisted lineage for checkpoint \(checkpointID).")
    }

    @MainActor
    func approveEvolutionCheckpoints(checkpointIDs explicitCheckpointIDs: [String]) {
        let checkpointIDs = uniqueEvolutionCheckpointIDs(explicitCheckpointIDs)
        guard !checkpointIDs.isEmpty else {
            publishEvolutionMutationOutcome(
                kind: .approveSelectedCheckpoints,
                title: "Approve selected",
                message: "No selected review checkpoints were available to approve.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: []
            )
            return
        }

        guard let updated = updateEvolutionCheckpoints(checkpointIDs, mutation: { checkpointID, context in
            BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
                checkpointID,
                to: .automatic,
                in: context
            )
        }) else {
            publishEvolutionMutationOutcome(
                kind: .approveSelectedCheckpoints,
                title: "Approve selected",
                message: "The selected checkpoints could not be approved.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: checkpointIDs
            )
            return
        }

        let updatedCheckpointIDs = updated.updatedCheckpointIDs
        let suffix = updatedCheckpointIDs.count == 1 ? "" : "s"
        publishEvolutionMutationOutcome(
            kind: .approveSelectedCheckpoints,
            title: "Approve selected",
            message: "Approved \(updatedCheckpointIDs.count) selected checkpoint\(suffix).",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: updatedCheckpointIDs
        )
        publishStartupNotice("Approved \(updatedCheckpointIDs.count) selected checkpoint\(suffix).")
    }

    @MainActor
    func markEvolutionCheckpointsForReview(checkpointIDs explicitCheckpointIDs: [String]) {
        let checkpointIDs = uniqueEvolutionCheckpointIDs(explicitCheckpointIDs)
        guard !checkpointIDs.isEmpty else {
            publishEvolutionMutationOutcome(
                kind: .markSelectedCheckpointsForReview,
                title: "Mark selected",
                message: "No automatic checkpoints were selected for review.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: []
            )
            return
        }

        guard let updated = updateEvolutionCheckpoints(checkpointIDs, mutation: { checkpointID, context in
            BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
                checkpointID,
                to: .reviewSuggested,
                in: context
            )
        }) else {
            publishEvolutionMutationOutcome(
                kind: .markSelectedCheckpointsForReview,
                title: "Mark selected",
                message: "The selected checkpoints could not be moved into the review queue.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: checkpointIDs
            )
            return
        }

        let updatedCheckpointIDs = updated.updatedCheckpointIDs
        let suffix = updatedCheckpointIDs.count == 1 ? "" : "s"
        publishEvolutionMutationOutcome(
            kind: .markSelectedCheckpointsForReview,
            title: "Mark selected",
            message: "Moved \(updatedCheckpointIDs.count) selected checkpoint\(suffix) into the review queue.",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: updatedCheckpointIDs
        )
        publishStartupNotice("Moved \(updatedCheckpointIDs.count) selected checkpoint\(suffix) into the review queue.")
    }

    @MainActor
    func clearEvolutionCheckpointLineages(checkpointIDs explicitCheckpointIDs: [String]) {
        let checkpointIDs = uniqueEvolutionCheckpointIDs(explicitCheckpointIDs)
        guard !checkpointIDs.isEmpty else {
            publishEvolutionMutationOutcome(
                kind: .clearSelectedCheckpointLineages,
                title: "Clear selected lineage",
                message: "No lineage-backed checkpoints were selected to clear.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: []
            )
            return
        }

        guard let updated = updateEvolutionCheckpoints(checkpointIDs, mutation: { checkpointID, context in
            BehavioralAISubstrateBridge.clearEvolutionCheckpointLineage(
                checkpointID,
                in: context
            )
        }) else {
            publishEvolutionMutationOutcome(
                kind: .clearSelectedCheckpointLineages,
                title: "Clear selected lineage",
                message: "Persisted lineage could not be cleared from the selected checkpoints.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: checkpointIDs
            )
            return
        }

        let updatedCheckpointIDs = updated.updatedCheckpointIDs
        let suffix = updatedCheckpointIDs.count == 1 ? "" : "s"
        publishEvolutionMutationOutcome(
            kind: .clearSelectedCheckpointLineages,
            title: "Clear selected lineage",
            message: "Cleared persisted lineage from \(updatedCheckpointIDs.count) selected checkpoint\(suffix).",
            isSuccess: true,
            isDestructive: true,
            checkpointIDs: updatedCheckpointIDs
        )
        publishStartupNotice("Cleared persisted lineage from \(updatedCheckpointIDs.count) selected checkpoint\(suffix).")
    }

    @MainActor
    func approvePendingEvolutionCheckpoints(checkpointIDs explicitCheckpointIDs: [String]? = nil) {
        let checkpointIDs = resolvedPendingReviewCheckpointIDs(
            explicitCheckpointIDs: explicitCheckpointIDs
        )
        guard !checkpointIDs.isEmpty else {
            publishEvolutionMutationOutcome(
                kind: .approvePendingCheckpoints,
                title: "Approve pending",
                message: explicitCheckpointIDs == nil
                    ? "No pending review checkpoints were available to approve."
                    : "None of the selected checkpoints remained in the pending review queue.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: []
            )
            return
        }

        guard let updated = updateEvolutionCheckpoints(checkpointIDs, mutation: { checkpointID, context in
            BehavioralAISubstrateBridge.setEvolutionCheckpointApproval(
                checkpointID,
                to: .automatic,
                in: context
            )
        }) else {
            publishEvolutionMutationOutcome(
                kind: .approvePendingCheckpoints,
                title: "Approve pending",
                message: "The pending review queue could not be approved.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: checkpointIDs
            )
            return
        }

        let updatedCheckpointIDs = updated.updatedCheckpointIDs
        let suffix = updatedCheckpointIDs.count == 1 ? "" : "s"
        publishEvolutionMutationOutcome(
            kind: .approvePendingCheckpoints,
            title: "Approve pending",
            message: "Approved \(updatedCheckpointIDs.count) pending review checkpoint\(suffix).",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: updatedCheckpointIDs
        )
        publishStartupNotice("Approved \(updatedCheckpointIDs.count) pending review checkpoint\(suffix).")
    }

    @MainActor
    func clearPendingEvolutionCheckpointLineages(checkpointIDs explicitCheckpointIDs: [String]? = nil) {
        let checkpointIDs = resolvedPendingReviewLineageCheckpointIDs(
            explicitCheckpointIDs: explicitCheckpointIDs
        )
        guard !checkpointIDs.isEmpty else {
            publishEvolutionMutationOutcome(
                kind: .clearPendingReviewLineage,
                title: "Clear review lineage",
                message: explicitCheckpointIDs == nil
                    ? "No lineage-backed review checkpoints were available to clear."
                    : "None of the selected checkpoints still carried pending-review lineage.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: []
            )
            return
        }

        guard let updated = updateEvolutionCheckpoints(checkpointIDs, mutation: { checkpointID, context in
            BehavioralAISubstrateBridge.clearEvolutionCheckpointLineage(
                checkpointID,
                in: context
            )
        }) else {
            publishEvolutionMutationOutcome(
                kind: .clearPendingReviewLineage,
                title: "Clear review lineage",
                message: "Persisted lineage could not be cleared from the pending review queue.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: checkpointIDs
            )
            return
        }

        let updatedCheckpointIDs = updated.updatedCheckpointIDs
        let suffix = updatedCheckpointIDs.count == 1 ? "" : "s"
        publishEvolutionMutationOutcome(
            kind: .clearPendingReviewLineage,
            title: "Clear review lineage",
            message: "Cleared persisted lineage from \(updatedCheckpointIDs.count) pending review checkpoint\(suffix) while preserving review membership.",
            isSuccess: true,
            isDestructive: true,
            checkpointIDs: updatedCheckpointIDs
        )
        publishStartupNotice("Cleared persisted lineage for \(updatedCheckpointIDs.count) pending review checkpoint\(suffix).")
    }

    @MainActor
    func rollbackActiveEvolutionCheckpoint(to checkpointID: String? = nil, now: Date = .now) {
        let resolvedCheckpointID = checkpointID ?? makeEvolutionControlSurface().activeRollbackCheckpointID
        guard let resolvedCheckpointID else {
            publishEvolutionMutationOutcome(
                kind: .rollbackActiveCheckpoint,
                title: "Rollback active",
                message: "No rollback-ready checkpoint is currently available.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: []
            )
            return
        }
        guard restoreEvolutionCheckpoint(checkpointID: resolvedCheckpointID, now: now) else {
            publishEvolutionMutationOutcome(
                kind: .rollbackActiveCheckpoint,
                title: "Rollback active",
                message: "Checkpoint \(resolvedCheckpointID) could not be restored as the rollback target.",
                isSuccess: false,
                isDestructive: true,
                checkpointIDs: [resolvedCheckpointID]
            )
            return
        }

        publishEvolutionMutationOutcome(
            kind: .rollbackActiveCheckpoint,
            title: "Rollback active",
            message: "Rolled the active brain state back to checkpoint \(resolvedCheckpointID).",
            isSuccess: true,
            isDestructive: true,
            checkpointIDs: [resolvedCheckpointID]
        )
        publishStartupNotice("Rolled back the active checkpoint to \(resolvedCheckpointID).")
    }

    @MainActor
    func applyEvolutionCheckpoint(checkpointID: String, now: Date = .now) {
        guard restoreEvolutionCheckpoint(checkpointID: checkpointID, now: now) else {
            publishEvolutionMutationOutcome(
                kind: .applyCheckpoint,
                title: "Apply checkpoint",
                message: "Checkpoint \(checkpointID) could not be restored as the active brain state.",
                isSuccess: false,
                isDestructive: false,
                checkpointIDs: [checkpointID]
            )
            return
        }

        publishEvolutionMutationOutcome(
            kind: .applyCheckpoint,
            title: "Apply checkpoint",
            message: "Checkpoint \(checkpointID) is now active and its restored brain state has been loaded into the host.",
            isSuccess: true,
            isDestructive: false,
            checkpointIDs: [checkpointID]
        )
        publishStartupNotice("Applied checkpoint \(checkpointID). The restored brain state is now active.")
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

    @MainActor
    func systemFlightDeck() async -> DecisionSystemFlightDeck {
        let inspection = await substrateInspectionSnapshot()
        return inspection.flightDeck
    }

    @MainActor
    func makeEvolutionControlSurface(
        currentBrainOverride: CurrentBrainState? = nil
    ) -> DecisionEvolutionControlSurface {
        let context = modelContainer.mainContext
        let inventory = evolutionCheckpointInventory(
            in: context,
            currentBrain: currentBrainOverride ?? currentBrainState
        )

        return inventory.buildControlSurface()
    }

    func presentEvolutionControlCenter() {
        isEvolutionControlCenterPresented = true
    }

    func dismissEvolutionControlCenter() {
        isEvolutionControlCenterPresented = false
    }

    @MainActor
    func substrateConsoleSnapshot() async -> BASHostConsoleSnapshot {
        let inspection = await substrateInspectionSnapshot()
        return inspection.consoleSnapshot(currentBrainState: currentBrainState)
    }

    @MainActor
    func substrateEBrainTurn() async -> BASEBrainTurnResult? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.eBrainTurn
    }

    @MainActor
    func substrateInspectionSnapshot() async -> DecisionTestingSubstrateInspectionSnapshot {
        let inspectionBrain = inspectionBrainSnapshot(now: .now)
        let runtimeSnapshot = DecisionTestingInterface.runtimeSnapshot(preferences: preferences)
        let turn = BehavioralAISubstrateBridge.eBrainTurn(
            hostRuntime: hostRuntime,
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession,
            currentBrainState: inspectionBrain.currentBrain,
            projection: inspectionBrain.projection,
            runtimeSnapshot: runtimeSnapshot,
            now: inspectionBrain.now
        )

        let export = await decisionRuntimeExport(
            runtimeSnapshot: runtimeSnapshot,
            currentBrainOverride: inspectionBrain.currentBrain
        )

        return DecisionTestingSubstrateInspectionSnapshot(
            export: export,
            eBrainTurn: turn
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

        guard hostRuntime.reopenDraftedItem(
            modeID: mode.substrateModeID,
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            activatePrimary: {
                activateQuickSession(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparative: {
                activateBalanceSession(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflective: {
                activateMirrorSession(draft.restoreMirrorSession(entrySource: .app))
            },
            afterSuccessfulReopen: {
                supportInbox.markHeard(request.id)
                selectedTab = .home
                persistActiveWorkspaceState()
            }
        ) else {
            return
        }
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

        guard hostRuntime.reopenDraftedItem(
            modeID: mode.substrateModeID,
            clearActiveDecisionFlows: { clearActiveDecisionFlows() },
            activatePrimary: {
                activateQuickSession(draft.restoreQuickSession(entrySource: .app))
            },
            activateComparative: {
                activateBalanceSession(draft.restoreBalanceSession(entrySource: .app))
            },
            activateReflective: {
                activateMirrorSession(draft.restoreMirrorSession(entrySource: .app))
            },
            afterSuccessfulReopen: {
                sharedLifeStore.markReviewing(item.id)
                selectedTab = .home
                persistActiveWorkspaceState()
            }
        ) else {
            return
        }
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
        isEvolutionControlCenterPresented = false
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
        hostRuntime.restoreActiveWorkspaceIfNeeded(
            restoreEnabled: preferences.restoreInProgressWorkspaces,
            hasActivePrimaryWorkflow: activeQuickSession != nil,
            hasActiveComparativeWorkflow: activeBalanceSession != nil,
            hasActiveReflectiveWorkflow: activeMirrorSession != nil,
            hasReflectionContext: reflectionContext != nil,
            loadState: { ActiveDecisionWorkspaceStore.load() },
            modeID: { $0.modeRaw },
            restorePrimary: { state in
                activateQuickSession(state.restoreQuickSession())
            },
            restoreComparative: { state in
                activateBalanceSession(state.restoreBalanceSession())
            },
            restoreReflective: { state in
                activateMirrorSession(state.restoreMirrorSession())
            },
            selectHomeTab: {
                selectedTab = .home
            },
            afterRestore: {
                refreshActiveTaskGraphSnapshot()
                refreshPredictedIntervention()
            }
        )
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
        hostRuntime.resolveProjectionRefresh(
            using: {
                BehavioralAISubstrateBridge.resolveMemoryProjection(
                    force: force,
                    cachedProjection: memoryProjection,
                    isDirty: isMemoryProjectionDirty,
                    context: modelContainer.mainContext
                )
            },
            commitProjection: { memoryProjection = $0 },
            setProjectionDirty: { isMemoryProjectionDirty = $0 },
            publishNotice: publishStartupNotice
        )
    }

    private func activateQuickSession(_ session: QuickCheckSession) {
        hostRuntime.resolveAndActivateSession(
            session: session,
            using: {
                BehavioralAISubstrateBridge.activateQuickSession(
                    session,
                    preferences: preferences,
                    context: modelContainer.mainContext,
                    cachedProjection: memoryProjection,
                    isProjectionDirty: isMemoryProjectionDirty,
                    now: .now
                )
            },
            loadBrainState: { session, currentBrain in
                session.loadBrainState(currentBrain.brainState)
            },
            commitProjection: { memoryProjection = $0 },
            setProjectionDirty: { isMemoryProjectionDirty = $0 },
            publishNotice: publishStartupNotice,
            commitCurrentBrain: { currentBrainState = $0 },
            commitSession: { activeQuickSession = $0 }
        )
    }

    private func activateBalanceSession(_ session: BalanceBoardSession) {
        hostRuntime.resolveAndActivateSession(
            session: session,
            using: {
                BehavioralAISubstrateBridge.activateBalanceSession(
                    session,
                    preferences: preferences,
                    context: modelContainer.mainContext,
                    cachedProjection: memoryProjection,
                    isProjectionDirty: isMemoryProjectionDirty,
                    now: .now
                )
            },
            loadBrainState: { session, currentBrain in
                session.loadBrainState(currentBrain.brainState)
            },
            commitProjection: { memoryProjection = $0 },
            setProjectionDirty: { isMemoryProjectionDirty = $0 },
            publishNotice: publishStartupNotice,
            commitCurrentBrain: { currentBrainState = $0 },
            commitSession: { activeBalanceSession = $0 }
        )
    }

    private func activateMirrorSession(_ session: MirrorWorkspaceSession) {
        hostRuntime.resolveAndActivateSession(
            session: session,
            using: {
                BehavioralAISubstrateBridge.activateMirrorSession(
                    session,
                    preferences: preferences,
                    context: modelContainer.mainContext,
                    cachedProjection: memoryProjection,
                    isProjectionDirty: isMemoryProjectionDirty,
                    now: .now
                )
            },
            loadBrainState: { session, currentBrain in
                session.loadBrainState(currentBrain.brainState)
            },
            commitProjection: { memoryProjection = $0 },
            setProjectionDirty: { isMemoryProjectionDirty = $0 },
            publishNotice: publishStartupNotice,
            commitCurrentBrain: { currentBrainState = $0 },
            commitSession: { activeMirrorSession = $0 }
        )
    }

    @MainActor
    private func decisionRuntimeExport(
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        currentBrainOverride: CurrentBrainState? = nil
    ) async -> DecisionTestingRuntimeExport {
        let context = modelContainer.mainContext
        let resolvedCurrentBrain = currentBrainOverride ?? currentBrainState
        let controlSurface = makeEvolutionControlSurface(
            currentBrainOverride: resolvedCurrentBrain
        )
        let inventory = evolutionCheckpointInventory(
            in: context,
            currentBrain: resolvedCurrentBrain
        )
        return await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: preferences,
            runtimeSnapshot: runtimeSnapshot,
            persistedCheckpointLineages: inventory.persistedLineages,
            pendingReviewCheckpoints: controlSurface.pendingReviewQueue,
            activeCheckpointHint: controlSurface.activeCheckpoint,
            restorableCheckpointIDs: controlSurface.restorableCheckpointIDs
        )
    }

    @MainActor
    private func persistedCheckpointLineages(
        in context: ModelContext,
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DecisionEvolutionLineageSnapshot] {
        let checkpoints = (try? context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())) ?? []
        return checkpoints
            .compactMap { checkpoint in
                guard let lineageSummary = checkpoint.lineageSummary else {
                    return nil
                }
                return DecisionEvolutionLineageSnapshot(
                    checkpointID: checkpoint.id,
                    previousCheckpointID: checkpoint.previousCheckpointID,
                    createdAt: checkpoint.createdAt,
                    mode: checkpoint.mode,
                    approvalState: checkpoint.approvalState,
                    rollbackReady: checkpoint.rollbackReady,
                    hasBrainStateSnapshot: checkpoint.brainStateSnapshot != nil,
                    diffSummary: checkpoint.diffSummary,
                    eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
                )
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.checkpointID > rhs.checkpointID
                }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    @MainActor
    private func evolutionCheckpointInventory(
        in context: ModelContext,
        currentBrain: CurrentBrainState?
    ) -> DecisionEvolutionControlSurfaceInventory {
        let allCheckpoints = evolutionCheckpointSnapshots(in: context)
        let persistedLineages = persistedCheckpointLineages(in: context)
        let pendingReviewQueue = allCheckpoints.filter { $0.approvalState == .reviewSuggested }
        let activeCheckpoint = resolveActiveEvolutionCheckpoint(
            currentBrain: currentBrain,
            allSnapshots: allCheckpoints,
            persistedLineages: persistedLineages
        )

        return DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: pendingReviewQueue,
            persistedLineages: persistedLineages,
            activeCheckpoint: activeCheckpoint,
            restorableCheckpointIDs: Set(allCheckpoints.filter(\.hasBrainStateSnapshot).map(\.checkpointID))
        )
    }

    @MainActor
    private func evolutionCheckpointSnapshots(
        in context: ModelContext
    ) -> [DecisionReviewCheckpointSnapshot] {
        let checkpoints = (try? context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())) ?? []
        return checkpoints
            .map(DecisionReviewCheckpointSnapshot.init(checkpoint:))
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.checkpointID > rhs.checkpointID
            }
    }

    @MainActor
    private func resolveActiveEvolutionCheckpoint(
        currentBrain: CurrentBrainState?,
        allSnapshots: [DecisionReviewCheckpointSnapshot]
    ) -> DecisionReviewCheckpointSnapshot? {
        resolveActiveEvolutionCheckpoint(
            currentBrain: currentBrain,
            allSnapshots: allSnapshots,
            persistedLineages: []
        )
    }

    @MainActor
    private func resolveActiveEvolutionCheckpoint(
        currentBrain: CurrentBrainState?,
        allSnapshots: [DecisionReviewCheckpointSnapshot],
        persistedLineages: [DecisionEvolutionLineageSnapshot]
    ) -> DecisionReviewCheckpointSnapshot? {
        if let latestCheckpoint = currentBrain?.evolutionState.latestCheckpoint,
           latestCheckpoint.approvalState == .automatic {
            let persisted = allSnapshots.first(where: { $0.checkpointID == latestCheckpoint.id })

            return DecisionReviewCheckpointSnapshot(
                checkpointID: latestCheckpoint.id,
                previousCheckpointID: latestCheckpoint.previousCheckpointID ?? persisted?.previousCheckpointID,
                createdAt: latestCheckpoint.createdAt,
                mode: persisted?.mode ?? currentBrain?.mode ?? .quick,
                approvalState: latestCheckpoint.approvalState,
                rollbackReady: latestCheckpoint.rollbackReady,
                hasBrainStateSnapshot: persisted?.hasBrainStateSnapshot ?? false,
                diffSummary: latestCheckpoint.diffSummary,
                eBrain: latestCheckpoint.lineageSummary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:))
                    ?? persisted?.eBrain,
                fallbackRiskLevel: persisted?.fallbackRiskLevel,
                fallbackPermitMode: persisted?.fallbackPermitMode
            )
        }

        if let latestAutomaticSnapshot = allSnapshots.first(where: { $0.approvalState == .automatic }) {
            return latestAutomaticSnapshot
        }

        if let persistedActiveID = persistedLineages.first(where: { $0.approvalState == .automatic })?.checkpointID,
           let persistedActive = allSnapshots.first(where: { $0.checkpointID == persistedActiveID }) {
            return persistedActive
        }

        return nil
    }

    @MainActor
    private func inspectionBrainSnapshot(
        now: Date
    ) -> InspectionBrainSnapshot {
        if memoryProjection == nil || isMemoryProjectionDirty {
            refreshDecisionMemoryStore()
        }

        if let currentBrainState {
            return InspectionBrainSnapshot(
                currentBrain: currentBrainState,
                projection: memoryProjection,
                now: now
            )
        }

        let outcome = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession,
            taskGraph: activeTaskGraph,
            preferences: preferences,
            context: modelContainer.mainContext,
            cachedProjection: memoryProjection,
            isProjectionDirty: isMemoryProjectionDirty,
            source: .explicitRefresh,
            now: now
        )

        return InspectionBrainSnapshot(
            currentBrain: outcome.currentBrain,
            projection: outcome.projection,
            now: now
        )
    }

    @MainActor
    private func recordCurrentEBrainReplayTurn(now: Date = .now) {
        _ = currentLiveEBrainTurn(
            runtimeSnapshot: DecisionTestingInterface.runtimeSnapshot(preferences: preferences),
            persistLineage: true,
            now: now
        )
    }

    @MainActor
    func currentLiveEBrainTurn(
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        persistLineage: Bool = true,
        now: Date = .now
    ) -> BASEBrainTurnResult? {
        if memoryProjection == nil || isMemoryProjectionDirty {
            refreshDecisionMemoryStore()
        }
        if currentBrainState == nil {
            refreshGlobalBrainState(source: .explicitRefresh)
        }

        let resolvedRuntimeSnapshot = runtimeSnapshot ?? DecisionTestingInterface.runtimeSnapshot(preferences: preferences)
        guard let turn = BehavioralAISubstrateBridge.eBrainTurn(
            hostRuntime: hostRuntime,
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession,
            currentBrainState: currentBrainState,
            projection: memoryProjection,
            runtimeSnapshot: resolvedRuntimeSnapshot,
            now: now
        ) else {
            return nil
        }

        EBrainTurnDebugStore.shared.record(turn)

        let loadedCheckpointID = currentBrainState?.evolutionState.latestCheckpoint?.id

        guard persistLineage,
              let evolutionState = BehavioralAISubstrateBridge.persistEBrainLineage(
                turn,
                targeting: loadedCheckpointID,
                in: modelContainer.mainContext
              ),
              let currentBrainState else {
            return turn
        }

        commitCurrentBrain(currentBrainState.replacingEvolutionState(evolutionState))
        persistActiveWorkspaceState()
        return turn
    }

    private func refreshGlobalBrainState(source: BrainStateUpdateSource) {
        hostRuntime.resolveCurrentBrainProjection(
            using: {
                BehavioralAISubstrateBridge.refreshCurrentBrainState(
                    activeQuickSession: activeQuickSession,
                    activeBalanceSession: activeBalanceSession,
                    activeMirrorSession: activeMirrorSession,
                    taskGraph: activeTaskGraph,
                    preferences: preferences,
                    context: modelContainer.mainContext,
                    cachedProjection: memoryProjection,
                    isProjectionDirty: isMemoryProjectionDirty,
                    source: source
                )
            },
            commitProjection: { memoryProjection = $0 },
            setProjectionDirty: { isMemoryProjectionDirty = $0 },
            publishNotice: publishStartupNotice,
            commitCurrentBrain: { currentBrainState = $0 }
        )
    }

    private func refreshPredictedIntervention() {
        let next = InterventionPredictionEngine.predictCandidate(
            currentBrainState: currentBrainState,
            context: modelContainer.mainContext,
            preferences: preferences,
            now: .now
        )
        let reconciled = hostRuntime.reconcilePredictiveIntervention(
            existing: interventionCandidate.map(predictiveInterventionSummary(from:)),
            next: next.map(predictiveInterventionSummary(from:))
        )
        interventionCandidate = reconciled.map(makeInterventionCandidate(from:))
    }

    private func schedulePredictiveInterventionIfNeeded() {
        let summary = interventionCandidate.map(predictiveInterventionSummary(from:))
        let policyAllowed: Bool
        if BASApplePredictiveInterventionDeliveryPlanner.shouldEvaluatePolicy(
            candidate: summary,
            predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled
        ), let candidate = interventionCandidate {
            policyAllowed = InterventionNotificationPolicyEngine.decide(
                candidate: candidate,
                preferences: preferences,
                currentBrainState: currentBrainState,
                context: modelContainer.mainContext,
                now: .now,
                calendar: .autoupdatingCurrent
            ).isAllowed
        } else {
            policyAllowed = false
        }

        hostRuntime.executePredictiveInterventionDelivery(
            candidate: summary,
            predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled,
            policyAllowed: policyAllowed,
            upsertTrigger: { summary, wasDelivered in
                upsertInterventionTrigger(
                    makeInterventionCandidate(from: summary),
                    wasDelivered: wasDelivered
                )
            },
            cancelNotification: { candidateID in
                NotificationService.shared.cancelPredictiveInterventionNotification(candidateID: candidateID)
            },
            scheduleNotification: { summary in
                let candidate = makeInterventionCandidate(from: summary)
                Task {
                    await NotificationService.shared.schedulePredictiveInterventionNotification(candidate)
                }
            }
        )
    }

    private func refreshActiveTaskGraphSnapshot() {
        activeTaskGraph = hostRuntime.refreshActiveTaskGraph(
            snapshotsInPriorityOrder: [
                { [self] in activeQuickSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
                { [self] in activeBalanceSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) },
                { [self] in activeMirrorSession.flatMap(DecisionTaskGraphSnapshot.capture(from:)) }
            ],
            saveSnapshot: { snapshot in
                DecisionTaskGraphStore.save(snapshot)
            },
            clearSnapshot: {
                DecisionTaskGraphStore.clear()
            }
        )
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

    @MainActor
    private func updateEvolutionCheckpoint(
        mutation: (ModelContext) -> DecisionEvolutionState?
    ) -> DecisionEvolutionState? {
        let context = modelContainer.mainContext
        guard let evolutionState = mutation(context) else {
            return nil
        }

        if let currentBrainState {
            let reconciledEvolutionState = BehavioralAISubstrateBridge.reconciledEvolutionState(
                evolutionState,
                preservingLoadedCheckpointID: currentBrainState.evolutionState.latestCheckpoint?.id,
                in: context
            )
            commitCurrentBrain(currentBrainState.replacingEvolutionState(reconciledEvolutionState))
            persistActiveWorkspaceState()
        }

        advanceEvolutionControlMutationEpoch()

        return evolutionState
    }

    private struct EvolutionCheckpointBatchUpdateResult {
        let evolutionState: DecisionEvolutionState
        let updatedCheckpointIDs: [String]
    }

    @MainActor
    private func updateEvolutionCheckpoints(
        _ checkpointIDs: [String],
        mutation: (String, ModelContext) -> DecisionEvolutionState?
    ) -> EvolutionCheckpointBatchUpdateResult? {
        let context = modelContainer.mainContext
        var latestEvolutionState: DecisionEvolutionState?
        var updatedCheckpointIDs: [String] = []

        for checkpointID in uniqueEvolutionCheckpointIDs(checkpointIDs) {
            if let state = mutation(checkpointID, context) {
                latestEvolutionState = state
                updatedCheckpointIDs.append(checkpointID)
            }
        }

        guard let latestEvolutionState, !updatedCheckpointIDs.isEmpty else {
            return nil
        }

        if let currentBrainState {
            let reconciledEvolutionState = BehavioralAISubstrateBridge.reconciledEvolutionState(
                latestEvolutionState,
                preservingLoadedCheckpointID: currentBrainState.evolutionState.latestCheckpoint?.id,
                in: context
            )
            commitCurrentBrain(currentBrainState.replacingEvolutionState(reconciledEvolutionState))
            persistActiveWorkspaceState()
        }

        advanceEvolutionControlMutationEpoch()

        return EvolutionCheckpointBatchUpdateResult(
            evolutionState: latestEvolutionState,
            updatedCheckpointIDs: updatedCheckpointIDs
        )
    }

    @MainActor
    private func resolvedPendingReviewCheckpointIDs(
        explicitCheckpointIDs: [String]? = nil
    ) -> [String] {
        let pendingReviewPresentations = makeEvolutionControlSurface().pendingReviewPresentations
        let pendingReviewCheckpointIDs = Set(pendingReviewPresentations.map(\.checkpointID))
        guard let explicitCheckpointIDs else {
            return pendingReviewPresentations.map(\.checkpointID)
        }

        return uniqueEvolutionCheckpointIDs(explicitCheckpointIDs).filter { pendingReviewCheckpointIDs.contains($0) }
    }

    @MainActor
    private func resolvedPendingReviewLineageCheckpointIDs(
        explicitCheckpointIDs: [String]? = nil
    ) -> [String] {
        let pendingLineagePresentations = makeEvolutionControlSurface().pendingReviewLineagePresentations
        let pendingLineageCheckpointIDs = Set(pendingLineagePresentations.map(\.checkpointID))
        guard let explicitCheckpointIDs else {
            return pendingLineagePresentations.map(\.checkpointID)
        }

        return uniqueEvolutionCheckpointIDs(explicitCheckpointIDs).filter { pendingLineageCheckpointIDs.contains($0) }
    }

    @MainActor
    private func restoreEvolutionCheckpoint(
        checkpointID: String,
        now: Date = .now
    ) -> Bool {
        let context = modelContainer.mainContext
        guard let restoredBrain = BehavioralAISubstrateBridge.restoreEvolutionCheckpoint(
            checkpointID,
            currentBrainState: currentBrainState,
            taskGraph: activeTaskGraph,
            in: context,
            now: now
        ) else {
            return false
        }

        commitCurrentBrain(restoredBrain)
        isMemoryProjectionDirty = true
        persistActiveWorkspaceState()
        advanceEvolutionControlMutationEpoch()
        return true
    }

    @MainActor
    private func commitCurrentBrain(_ currentBrain: CurrentBrainState) {
        currentBrainState = currentBrain
        activeQuickSession?.loadBrainState(currentBrain.brainState)
        activeBalanceSession?.loadBrainState(currentBrain.brainState)
        activeMirrorSession?.loadBrainState(currentBrain.brainState)
    }

    private func advanceEvolutionControlMutationEpoch() {
        evolutionControlMutationEpoch &+= 1
    }

    private func publishEvolutionMutationOutcome(
        kind: DecisionEvolutionMutationKind,
        title: String,
        message: String,
        isSuccess: Bool,
        isDestructive: Bool,
        checkpointIDs: [String],
        recordedAt: Date = .now
    ) {
        latestEvolutionMutationOutcome = DecisionEvolutionMutationOutcome(
            kind: kind,
            title: title,
            message: message,
            isSuccess: isSuccess,
            isDestructive: isDestructive,
            affectedCheckpointIDs: uniqueEvolutionCheckpointIDs(checkpointIDs),
            recordedAt: recordedAt
        )
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

    private func uniqueEvolutionCheckpointIDs(_ checkpointIDs: [String]) -> [String] {
        checkpointIDs.reduce(into: [String]()) { uniqueIDs, checkpointID in
            guard !uniqueIDs.contains(checkpointID) else { return }
            uniqueIDs.append(checkpointID)
        }
    }

    private func makeInterventionCandidate(
        from suggestion: BASApplePredictiveInterventionSuggestion
    ) -> InterventionPredictionCandidate {
        InterventionPredictionCandidate(
            riskLevel: InterventionRiskLevel(rawValue: suggestion.riskLevelID) ?? .medium,
            title: suggestion.title,
            detail: suggestion.detail,
            evidenceSignalCount: suggestion.evidenceSignalCount,
            suggestedMode: DecisionMode.fromSubstrateModeID(suggestion.preferredModeID),
            reason: suggestion.reason,
            expiresAt: suggestion.expiresAt
        )
    }

    private func makeInterventionCandidate(
        from suggestion: BASAppleReopenInterventionSuggestion
    ) -> InterventionPredictionCandidate {
        InterventionPredictionCandidate(
            riskLevel: InterventionRiskLevel(rawValue: suggestion.riskLevelID) ?? .medium,
            title: suggestion.title,
            detail: suggestion.detail ?? "",
            evidenceSignalCount: suggestion.evidenceSignalCount,
            suggestedMode: DecisionMode.fromSubstrateModeID(suggestion.suggestedModeID),
            reason: suggestion.reason,
            expiresAt: suggestion.expiresAt
        )
    }

    private func makeInterventionCandidate(
        from summary: BASApplePredictiveInterventionCandidateSummary
    ) -> InterventionPredictionCandidate {
        InterventionPredictionCandidate(
            id: summary.id,
            riskLevel: InterventionRiskLevel(rawValue: summary.riskLevelID) ?? .medium,
            title: summary.title,
            detail: summary.detail,
            evidenceSignalCount: summary.evidenceSignalCount,
            suggestedMode: DecisionMode.fromSubstrateModeID(summary.preferredModeID),
            reason: summary.reason,
            createdAt: summary.createdAt,
            expiresAt: summary.expiresAt
        )
    }

    private func predictiveInterventionSummary(
        from candidate: InterventionPredictionCandidate
    ) -> BASApplePredictiveInterventionCandidateSummary {
        BASApplePredictiveInterventionCandidateSummary(
            id: candidate.id,
            riskLevelID: candidate.riskLevel.rawValue,
            title: candidate.title,
            detail: candidate.detail,
            evidenceSignalCount: candidate.evidenceSignalCount,
            preferredModeID: candidate.suggestedMode?.substrateModeID,
            reason: candidate.reason,
            createdAt: candidate.createdAt,
            expiresAt: candidate.expiresAt
        )
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
