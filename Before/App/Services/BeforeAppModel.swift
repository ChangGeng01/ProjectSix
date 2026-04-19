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

private struct DecisionSessionEngineEvaluationContext {
    let sessionID: String
    let stepID: String?
}

private struct BeforeAppRuntimeContext {
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let hostRuntime: BASHostRuntime
}

struct DecisionSessionEnginePendingImportDraft: Identifiable, Sendable {
    let sourceFileName: String
    let bundleData: Data
    let preview: DecisionSessionImportBundlePreview

    var id: String { "\(sourceFileName)|\(preview.id)" }
    var presentation: DecisionSessionEngineImportPreviewPresentation {
        DecisionSessionEnginePendingImportPreview(
            sourceFileName: sourceFileName,
            preview: preview
        ).presentation
    }
}

@MainActor
final class BeforeAppModel: ObservableObject {
    private static var deferredSessionEngineTasks: [UUID: Task<Void, Never>] = [:]

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
    @Published var isSessionEngineControlCenterPresented = false
    @Published var startupNotice: String?
    @Published var supportSurface: SupportSurfaceTarget = .buddy
    @Published private(set) var preferences: BeforePreferences
    @Published private(set) var evolutionControlMutationEpoch: Int = 0
    @Published private(set) var latestEvolutionMutationOutcome: DecisionEvolutionMutationOutcome?
    @Published private(set) var activeEvolutionKillSwitches: [BASKillSwitchID]
    @Published private(set) var gemmaLibraryMutationEpoch: Int = 0
    @Published private(set) var isDownloadingGemmaModel = false
    @Published private(set) var isDownloadingOpenModel = false
    @Published private(set) var pendingSessionEngineImportDraft: DecisionSessionEnginePendingImportDraft?
    @Published private(set) var sessionEngineBundleIssue: String?
    @AppStorage("before.hasSeenOnboarding") var hasSeenOnboarding = false

    let modelContainer: ModelContainer
    let supportInbox: SupportInboxStore
    let sharedLifeStore: SharedLifeStore
    private var hostRuntime: BASHostRuntime {
        resolvedRuntimeContext().hostRuntime
    }
    private var memoryProjection: DecisionMemorySystem.BrainStateProjection?
    private var isMemoryProjectionDirty = true
    private var shouldPromptReflectionAfterBackground = false
    private var pendingReflectionContext: ReflectionContext?

    init(modelContainer: ModelContainer, startupNotice: String? = nil) {
        let testingLaunchOptions = DecisionTestingInterface.launchOptions()
        self.modelContainer = modelContainer
        self.startupNotice = testingLaunchOptions.cleanLaunch ? nil : startupNotice
        self.preferences = DecisionTestingInterface.effectivePreferences()
        self.activeEvolutionKillSwitches = DecisionEvolutionKillSwitchStore.load()
        self.supportInbox = SupportInboxStore()
        self.sharedLifeStore = SharedLifeStore()
        self.activeTaskGraph = (testingLaunchOptions.cleanLaunch || !preferences.restoreInProgressWorkspaces)
            ? nil
            : DecisionTaskGraphStore.load()
        applyTestingLaunchOptions(testingLaunchOptions)
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: preferences.preferredOpenModelAssetID
        )
        restorePendingReflectionState()
    }

    static func drainDeferredSessionEngineTasksForTesting() async {
        while deferredSessionEngineTasks.isEmpty == false {
            let tasks = Array(deferredSessionEngineTasks.values)
            for task in tasks {
                _ = await task.result
            }
        }
    }

    var runtimeSnapshot: DecisionTestingRuntimeSnapshot {
        DecisionTestingInterface.runtimeSnapshot(preferences: preferences)
    }

    var intelligenceRuntimeStatus: DecisionModelRuntimeStatus {
        runtimeSnapshot.runtimeStatus
    }

    var foundationModelStatus: DecisionModelProviderStatus {
        runtimeSnapshot.foundationStatus
    }

    var gemmaModelStatus: DecisionModelProviderStatus {
        runtimeSnapshot.gemmaProviderStatus
    }

    var openModelStatus: DecisionModelProviderStatus {
        runtimeSnapshot.openModelProviderStatus
    }

    var registeredProviderDescriptors: [DecisionModelProviderDescriptor] {
        runtimeSnapshot.registeredProviders
    }

    var preferredProviderDescriptor: DecisionModelProviderDescriptor? {
        registeredProviderDescriptors.first(where: { $0.kind == preferences.preferredIntelligenceProvider.kind })
    }

    var activeProviderDescriptor: DecisionModelProviderDescriptor? {
        registeredProviderDescriptors.first(where: { $0.kind == intelligenceRuntimeStatus.active })
    }

    var openModelProviderDescriptor: DecisionModelProviderDescriptor? {
        registeredProviderDescriptors.first(where: { $0.kind == .openModel })
    }

    var activeDecisionSessionEngineSessionID: String? {
        if let quickID = activeQuickSession?.sessionEngineSessionID {
            return quickID
        }
        if let balanceID = activeBalanceSession?.sessionEngineSessionID {
            return balanceID
        }
        return activeMirrorSession?.sessionEngineSessionID
    }

    var localModelLibrarySnapshot: DecisionLocalModelLibrarySnapshot {
        runtimeSnapshot.localModelLibrary
    }

    var localModelLibraryPresentation: DecisionLocalModelLibraryPresentation {
        DecisionLocalModelLibraryPresentation.build(from: localModelLibrarySnapshot)
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

    var gemmaPreferredAsset: GemmaModelAsset? {
        GemmaE4BIntelligenceService.preferredModel(preferredAssetID: preferences.preferredGemmaAssetID)
    }

    var gemmaImportedAssets: [GemmaModelAsset] {
        GemmaE4BIntelligenceService.importedModels
    }

    var preferredGemmaAssetID: String? {
        preferences.preferredGemmaAssetID
    }

    var openModelImportedAssets: [OpenModelAsset] {
        OpenModelAssetCatalog.importedAssets()
    }

    var openModelPreferredAsset: OpenModelAsset? {
        OpenModelAssetCatalog.preferredAsset(
            preferredAssetID: preferences.preferredOpenModelAssetID
        )
    }

    var preferredOpenModelAssetID: String? {
        preferences.preferredOpenModelAssetID
    }

    func handleInitialAppearance() {
        executeLifecyclePhase(.initialAppearance, syncWidgetSnapshot: true)
    }

    func suppressHostedTestPresentations() {
        hasSeenOnboarding = true
        activeQuickSession = nil
        activeBalanceSession = nil
        activeMirrorSession = nil
        reflectionContext = nil
        letGoContext = nil
        isEvolutionControlCenterPresented = false
        isSessionEngineControlCenterPresented = false
        pendingSessionEngineImportDraft = nil
        sessionEngineBundleIssue = nil
        latestEvolutionMutationOutcome = nil
        pendingReflectionContext = nil
        shouldPromptReflectionAfterBackground = false
    }

    func dismissStartupNotice() {
        startupNotice = nil
    }

    func dismissSessionEngineBundleIssue() {
        sessionEngineBundleIssue = nil
    }

    func presentSessionEngineBundleIssue(_ issue: String) {
        sessionEngineBundleIssue = issue
    }

    func clearPendingSessionEngineImportDraft() {
        pendingSessionEngineImportDraft = nil
    }

    func dismissEvolutionMutationOutcome() {
        latestEvolutionMutationOutcome = nil
    }

    @discardableResult
    func importGemmaModel(from sourceURL: URL) throws -> GemmaModelAsset {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let asset = try GemmaModelAssetCatalog.importModel(from: sourceURL)
        updatePreferences { $0.preferredGemmaAssetID = asset.assetID }
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Imported \(asset.fileName) into the local Gemma library.")
        return asset
    }

    @discardableResult
    func downloadGemmaModel(from remoteURL: URL) async throws -> GemmaModelAsset {
        isDownloadingGemmaModel = true
        defer { isDownloadingGemmaModel = false }

        let asset = try await GemmaModelDownloadService.downloadModel(from: remoteURL)
        updatePreferences { $0.preferredGemmaAssetID = asset.assetID }
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Downloaded \(asset.fileName) into the local Gemma library.")
        return asset
    }

    @discardableResult
    func importOpenModel(from sourceURL: URL) throws -> OpenModelAsset {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let asset = try OpenModelAssetCatalog.importModel(from: sourceURL)
        updatePreferences { $0.preferredOpenModelAssetID = asset.assetID }
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: asset.assetID
        )
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Imported \(asset.fileName) into the open-model library slot.")
        return asset
    }

    @discardableResult
    func downloadOpenModel(from remoteURL: URL) async throws -> OpenModelAsset {
        isDownloadingOpenModel = true
        defer { isDownloadingOpenModel = false }

        let asset = try await OpenModelDownloadService.downloadModel(from: remoteURL)
        updatePreferences { $0.preferredOpenModelAssetID = asset.assetID }
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: asset.assetID
        )
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Downloaded \(asset.fileName) into the open-model library slot.")
        return asset
    }

    func removeImportedGemmaModel(named fileName: String) throws {
        let removedAssetID = GemmaModelAsset(
            fileName: fileName,
            fileSizeBytes: 0,
            expectedSizeBytes: nil,
            source: .imported
        ).assetID
        try GemmaModelAssetCatalog.removeImportedModel(named: fileName)
        if preferences.preferredGemmaAssetID == removedAssetID {
            updatePreferences { $0.preferredGemmaAssetID = nil }
        }
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Removed \(fileName) from the local Gemma library.")
    }

    func setPreferredGemmaAssetID(_ assetID: String?) {
        guard preferences.preferredGemmaAssetID != assetID else { return }
        updatePreferences { $0.preferredGemmaAssetID = assetID }
        gemmaLibraryMutationEpoch &+= 1
        if let assetID,
           let selectedAsset = GemmaE4BIntelligenceService.preferredModel(preferredAssetID: assetID) {
            publishStartupNotice("Gemma will now prefer \(selectedAsset.sourceTitle.lowercased()) asset \(selectedAsset.fileName).")
        } else {
            publishStartupNotice("Gemma asset selection returned to automatic mode.")
        }
    }

    func removeImportedOpenModel(named fileName: String) throws {
        let removedAssetID = OpenModelAsset(
            fileName: fileName,
            fileSizeBytes: 0,
            source: .imported
        ).assetID
        try OpenModelAssetCatalog.removeImportedModel(named: fileName)
        if preferences.preferredOpenModelAssetID == removedAssetID {
            updatePreferences { $0.preferredOpenModelAssetID = nil }
        }
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: preferences.preferredOpenModelAssetID
        )
        gemmaLibraryMutationEpoch &+= 1
        publishStartupNotice("Removed \(fileName) from the open-model library slot.")
    }

    func setPreferredOpenModelAssetID(_ assetID: String?) {
        guard preferences.preferredOpenModelAssetID != assetID else { return }
        updatePreferences { $0.preferredOpenModelAssetID = assetID }
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: assetID
        )
        gemmaLibraryMutationEpoch &+= 1
        if let assetID,
           let selectedAsset = OpenModelAssetCatalog.preferredAsset(
            importedAssets: openModelImportedAssets,
            preferredAssetID: assetID
           ) {
            publishStartupNotice("Open model runtime will now prefer imported asset \(selectedAsset.fileName).")
        } else {
            publishStartupNotice("Open-model asset selection returned to automatic mode.")
        }
    }

    func setPreferredIntelligenceProvider(_ provider: DecisionModelProviderPreference) {
        guard preferences.preferredIntelligenceProvider != provider else { return }
        updatePreferences { $0.preferredIntelligenceProvider = provider }

        let notice: String
        switch provider {
        case .foundationModels:
            notice = "Preferred provider set to Apple Foundation Model. Before will try the Apple on-device model first."
        case .gemmaE4B:
            if let preferredAsset = gemmaPreferredAsset {
                notice = "Preferred provider set to Gemma 4 E4B. Before will use \(preferredAsset.sourceTitle.lowercased()) asset \(preferredAsset.fileName) when Gemma is active."
            } else {
                notice = "Preferred provider set to Gemma 4 E4B. Import or download a local `.litertlm` file to make Gemma available."
            }
        case .openModel:
            if let descriptor = openModelProviderDescriptor?.openModel {
                notice = "Preferred provider set to \(descriptor.title). Before will route to open-model runtime \(descriptor.stableID) when that adapter is available."
            } else {
                notice = "Preferred provider set to Open model runtime. Before will use the registered open-model adapter when one is available."
            }
        case .template:
            notice = "Preferred provider set to Deterministic local copy. Before will stay on the rule-based local layer unless you switch providers again."
        }

        publishStartupNotice(notice)
    }

    func setAllowModelFallbacks(_ enabled: Bool) {
        guard preferences.allowModelFallbacks != enabled else { return }
        updatePreferences { $0.allowModelFallbacks = enabled }
        publishStartupNotice(
            enabled
                ? "Provider fallbacks are now enabled. Before can step down to another local provider if the preferred one is unavailable."
                : "Provider fallbacks are now disabled. Before will stay on the preferred provider or deterministic local copy."
        )
    }

    func evolutionKillSwitchIsEnabled(_ killSwitchID: BASKillSwitchID) -> Bool {
        activeEvolutionKillSwitches.contains(killSwitchID)
    }

    @MainActor
    func setEvolutionKillSwitch(
        _ killSwitchID: BASKillSwitchID,
        enabled: Bool,
        now: Date = .now
    ) {
        activeEvolutionKillSwitches = DecisionEvolutionKillSwitchStore.setEnabled(
            killSwitchID,
            enabled: enabled,
            now: now
        )
        publishStartupNotice(
            enabled
                ? "\(killSwitchID.displayTitle) is now active."
                : "\(killSwitchID.displayTitle) is no longer active."
        )
        advanceEvolutionControlMutationEpoch()
    }

    @MainActor
    func applyRecommendedEvolutionKillSwitches(
        _ killSwitchIDs: [String],
        now: Date = .now
    ) {
        let resolvedKillSwitches = BASKillSwitchID.resolvePolicyIDs(killSwitchIDs)
        guard !resolvedKillSwitches.isEmpty else { return }

        let mergedKillSwitches = Array(Set(activeEvolutionKillSwitches + resolvedKillSwitches))
            .sorted { $0.rawValue < $1.rawValue }
        DecisionEvolutionKillSwitchStore.save(mergedKillSwitches, now: now)
        activeEvolutionKillSwitches = mergedKillSwitches
        publishStartupNotice("Applied \(resolvedKillSwitches.count) recommended kill switch(es) to the runtime control plane.")
        advanceEvolutionControlMutationEpoch()
    }

    @MainActor
    func clearEvolutionKillSwitches(now: Date = .now) {
        DecisionEvolutionKillSwitchStore.clear(now: now)
        activeEvolutionKillSwitches = []
        publishStartupNotice("Cleared all active runtime kill switches.")
        advanceEvolutionControlMutationEpoch()
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
        let route = DecisionIntelligenceCoordinator.route(
            prompt: prompt,
            preferences: preferences,
            activeKillSwitches: activeEvolutionKillSwitches
        )
        startDecisionMode(route.mode, entrySource: entrySource, prompt: prompt)
        return route
    }

    func submitHomePrompt(_ prompt: String, entrySource: EntrySource) -> RoutedDecision {
        switch preferences.homePromptAction {
        case .autoRoute:
            return routeDecision(prompt: prompt, entrySource: entrySource)
        case .quick:
            let routed = DecisionIntelligenceCoordinator.enforceRuntimeControlPlane(
                on: RoutedDecision(mode: .quick, reason: "Preferred quick judgment"),
                activeKillSwitches: activeEvolutionKillSwitches
            )
            startDecisionMode(routed.mode, entrySource: entrySource, prompt: prompt)
            return routed
        case .balance:
            let routed = DecisionIntelligenceCoordinator.enforceRuntimeControlPlane(
                on: RoutedDecision(mode: .balance, reason: "Preferred balance board"),
                activeKillSwitches: activeEvolutionKillSwitches
            )
            startDecisionMode(routed.mode, entrySource: entrySource, prompt: prompt)
            return routed
        case .mirror:
            let routed = DecisionIntelligenceCoordinator.enforceRuntimeControlPlane(
                on: RoutedDecision(mode: .mirror, reason: "Preferred mirror"),
                activeKillSwitches: activeEvolutionKillSwitches
            )
            startDecisionMode(routed.mode, entrySource: entrySource, prompt: prompt)
            return routed
        }
    }

    func updatePreferences(_ transform: (inout BeforePreferences) -> Void) {
        var updated = preferences
        transform(&updated)
        BeforePreferencesStore.save(updated)
        preferences = DecisionTestingInterface.effectivePreferences(stored: updated)
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: preferences.preferredOpenModelAssetID
        )

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
            persistActiveWorkspaceState(
                trackSessionEngineLifecycle: true,
                eBrainTurn: activeEvaluationEBrainTurn()
            )
            schedulePredictiveInterventionIfNeeded()
        case .inactive:
            persistActiveWorkspaceState(
                trackSessionEngineLifecycle: true,
                eBrainTurn: activeEvaluationEBrainTurn()
            )
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
                    performRoutedInput: { envelope, prompt in
                        _ = routeDecision(prompt: prompt, entrySource: envelope.entrySource)
                    },
                    performPredictiveIntervention: { suggestion in
                        interventionCandidate = suggestion.map(makeInterventionCandidate(from:))
                    },
                    performRestore: { restoreActiveWorkspaceIfNeeded() },
                    performOpenEvolutionControl: {
                        presentEvolutionControlCenter()
                    },
                    refreshCurrentBrain: { source in
                        refreshGlobalBrainState(source: source)
                    }
                )
            },
            consumePendingRequest: { PendingLaunchRequestStore.consumeEnvelope() },
            handlePendingRequest: { envelope in
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
                    performRoutedInput: { envelope, prompt in
                        _ = routeDecision(prompt: prompt, entrySource: envelope.entrySource)
                    },
                    performPredictiveIntervention: { suggestion in
                        interventionCandidate = suggestion.map(makeInterventionCandidate(from:))
                    },
                    performRestore: { restoreActiveWorkspaceIfNeeded() },
                    performOpenEvolutionControl: {
                        presentEvolutionControlCenter()
                    },
                    refreshCurrentBrain: { source in
                        refreshGlobalBrainState(source: source)
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

        let eBrainTurn = session.lastEvaluationEBrainTurn ?? currentLiveEBrainTurn(
            persistLineage: false,
            now: event.createdAt
        )
        recordCurrentEBrainReplayTurn(
            eBrainTurn: eBrainTurn,
            now: event.createdAt
        )

        refreshWidgetSurfaces()

        pendingReflectionContext = ReflectionContext(
            id: UUID(),
            eventID: event.id,
            scenario: event.scenario,
            finalAction: event.finalAction
        )
        persistPendingReflectionState()
        reflectionContext = nil
        await recordQuickSessionEngineAction(
            session,
            result: result,
            action: action,
            eBrainTurn: eBrainTurn,
            now: event.createdAt
        )
        activeQuickSession = nil
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: eBrainTurn
        )
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
        let eBrainTurn = session.lastEvaluationEBrainTurn ?? currentLiveEBrainTurn(
            persistLineage: false,
            now: record.updatedAt
        )
        recordCurrentEBrainReplayTurn(
            eBrainTurn: eBrainTurn,
            now: record.updatedAt
        )
        scheduleDeferredSessionEngineTask {
            await self.recordBalanceSessionEngineAction(
                session,
                result: result,
                actionSummary: "saved balance board",
                tool: "save_balance_board",
                argsPreview: [
                    "entrySource": session.entrySource.rawValue,
                    "focus": result.focusTitle
                ],
                eBrainTurn: eBrainTurn,
                now: record.updatedAt
            )
        }
        activeBalanceSession = nil
        presentLetGo( LetGoCopyLibrary.savedBalanceContext(for: record) )
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: eBrainTurn
        )
    }

    func moveBalanceBoardToTomorrow(_ session: BalanceBoardSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let tomorrowItem = TomorrowBoxItemFactory.makeBalanceItem(from: session, result: result)
        context.insert(tomorrowItem)
        persistContext(context, operation: "moving the balance board into Tomorrow Box")
        let eBrainTurn = session.lastEvaluationEBrainTurn ?? currentLiveEBrainTurn(
            persistLineage: false,
            now: tomorrowItem.createdAt
        )
        scheduleDeferredSessionEngineTask {
            await self.recordBalanceSessionEngineAction(
                session,
                result: result,
                actionSummary: "moved balance board to Tomorrow Box",
                tool: "move_balance_board_to_tomorrow",
                argsPreview: [
                    "entrySource": session.entrySource.rawValue,
                    "tomorrowItemID": tomorrowItem.id.uuidString
                ],
                eBrainTurn: eBrainTurn,
                now: tomorrowItem.createdAt
            )
        }
        activeBalanceSession = nil
        presentLetGo(for: tomorrowItem)
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: eBrainTurn
        )
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
        let eBrainTurn = session.lastEvaluationEBrainTurn ?? currentLiveEBrainTurn(
            persistLineage: false,
            now: record.updatedAt
        )
        recordCurrentEBrainReplayTurn(
            eBrainTurn: eBrainTurn,
            now: record.updatedAt
        )
        scheduleDeferredSessionEngineTask {
            await self.recordMirrorSessionEngineAction(
                session,
                result: result,
                actionSummary: "saved mirror workspace",
                tool: "save_mirror_workspace",
                argsPreview: [
                    "entrySource": session.entrySource.rawValue,
                    "nextActionTitle": result.nextActionTitle
                ],
                eBrainTurn: eBrainTurn,
                now: record.updatedAt
            )
        }
        activeMirrorSession = nil
        presentLetGo( LetGoCopyLibrary.savedMirrorContext(for: record) )
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: eBrainTurn
        )
    }

    func moveMirrorWorkspaceToTomorrow(_ session: MirrorWorkspaceSession) {
        guard let result = session.result else { return }

        let context = modelContainer.mainContext
        let tomorrowItem = TomorrowBoxItemFactory.makeMirrorItem(from: session, result: result)
        context.insert(tomorrowItem)
        persistContext(context, operation: "moving the mirror workspace into Tomorrow Box")
        let eBrainTurn = session.lastEvaluationEBrainTurn ?? currentLiveEBrainTurn(
            persistLineage: false,
            now: tomorrowItem.createdAt
        )
        scheduleDeferredSessionEngineTask {
            await self.recordMirrorSessionEngineAction(
                session,
                result: result,
                actionSummary: "moved mirror workspace to Tomorrow Box",
                tool: "move_mirror_workspace_to_tomorrow",
                argsPreview: [
                    "entrySource": session.entrySource.rawValue,
                    "tomorrowItemID": tomorrowItem.id.uuidString
                ],
                eBrainTurn: eBrainTurn,
                now: tomorrowItem.createdAt
            )
        }
        activeMirrorSession = nil
        presentLetGo(for: tomorrowItem)
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: eBrainTurn
        )
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
            persistActiveWorkspaceState: { persistActiveWorkspaceState(trackSessionEngineLifecycle: true) }
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
        guard session.canEvaluate else { return }
        refreshQuickBrainState(session)
        let sessionEngineContext = await beginQuickSessionEngineEvaluation(session)
        let runtimeContext = resolvedRuntimeContext()
        let turn = currentLiveEBrainTurn(
            runtimeSnapshot: runtimeContext.runtimeSnapshot,
            now: .now
        )
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn,
            runtimePolicyResolution: runtimeContext.runtimeSnapshot.runtimePolicyResolution
        )
        await finalizeQuickSessionEngineEvaluation(
            session,
            context: sessionEngineContext,
            eBrainTurn: turn
        )
    }

    func evaluateBalanceSessionWithIntelligence(_ session: BalanceBoardSession) async {
        guard session.canEvaluate else { return }
        refreshBalanceBrainState(session)
        let sessionEngineContext = await beginBalanceSessionEngineEvaluation(session)
        let runtimeContext = resolvedRuntimeContext()
        let turn = currentLiveEBrainTurn(
            runtimeSnapshot: runtimeContext.runtimeSnapshot,
            now: .now
        )
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn,
            runtimePolicyResolution: runtimeContext.runtimeSnapshot.runtimePolicyResolution
        )
        await finalizeBalanceSessionEngineEvaluation(
            session,
            context: sessionEngineContext,
            eBrainTurn: turn
        )
    }

    func evaluateMirrorSessionWithIntelligence(_ session: MirrorWorkspaceSession) async {
        guard session.canEvaluate else { return }
        refreshMirrorBrainState(session)
        let sessionEngineContext = await beginMirrorSessionEngineEvaluation(session)
        let runtimeContext = resolvedRuntimeContext()
        let turn = currentLiveEBrainTurn(
            runtimeSnapshot: runtimeContext.runtimeSnapshot,
            now: .now
        )
        await session.evaluateWithIntelligence(
            preferences: preferences,
            eBrainTurn: turn,
            runtimePolicyResolution: runtimeContext.runtimeSnapshot.runtimePolicyResolution
        )
        await finalizeMirrorSessionEngineEvaluation(
            session,
            context: sessionEngineContext,
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
            persistActiveWorkspaceState: { persistActiveWorkspaceState(trackSessionEngineLifecycle: true) }
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
            persistActiveWorkspaceState: { persistActiveWorkspaceState(trackSessionEngineLifecycle: true) }
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
            persistActiveWorkspaceState: { persistActiveWorkspaceState(trackSessionEngineLifecycle: true) }
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
    func performEvolutionMutation(
        _ intent: DecisionEvolutionMutationIntent,
        now: Date = .now
    ) {
        let targetCheckpointID = intent.preview.targetCheckpointIDs.first
        let targetCheckpointIDs = intent.preview.targetCheckpointIDs

        switch intent.kind {
        case .applyCheckpoint, .restoreActiveCheckpoint:
            guard let targetCheckpointID else { return }
            applyEvolutionCheckpoint(checkpointID: targetCheckpointID, now: now)
        case .approveCheckpoint:
            guard let targetCheckpointID else { return }
            approveEvolutionCheckpoint(checkpointID: targetCheckpointID)
        case .markCheckpointForReview:
            guard let targetCheckpointID else { return }
            markEvolutionCheckpointForReview(checkpointID: targetCheckpointID)
        case .clearCheckpointLineage:
            guard let targetCheckpointID else { return }
            clearEvolutionCheckpointLineage(checkpointID: targetCheckpointID)
        case .approveSelectedCheckpoints:
            approveEvolutionCheckpoints(checkpointIDs: targetCheckpointIDs)
        case .markSelectedCheckpointsForReview:
            markEvolutionCheckpointsForReview(checkpointIDs: targetCheckpointIDs)
        case .clearSelectedCheckpointLineages:
            clearEvolutionCheckpointLineages(checkpointIDs: targetCheckpointIDs)
        case .rollbackActiveCheckpoint:
            rollbackActiveEvolutionCheckpoint(to: targetCheckpointID, now: now)
        case .approvePendingCheckpoints:
            approvePendingEvolutionCheckpoints(
                checkpointIDs: targetCheckpointIDs.isEmpty ? nil : targetCheckpointIDs
            )
        case .clearPendingReviewLineage:
            clearPendingEvolutionCheckpointLineages(
                checkpointIDs: targetCheckpointIDs.isEmpty ? nil : targetCheckpointIDs
            )
        }
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
        DecisionEvolutionKillSwitchStore.clear()
        activeEvolutionKillSwitches = []

        PendingLaunchRequestStore.clear()
        DecisionIntentEnvelopeStore.clear()
        DecisionReactionBanditStore.clear()
        WidgetSnapshotStore.clear()
        resetTransientState()
        refreshWidgetSurfaces()
    }

    func syncWidgetSnapshot() {
        let latest = latestEvents(limit: 1).first
        let evolutionSurfaceState = makeEvolutionSurfaceState(contract: .home)
        let workspace = evolutionSurfaceState.workspace
        let workspaceFacts = workspace.facts
        let controlSurface = evolutionSurfaceState.controlSurface
        let attentionSignal = evolutionSurfaceState.attentionSignal
        let activeKillSwitchIDs = activeEvolutionKillSwitches.map(\.rawValue)
        let recommendedKillSwitchCount = workspaceFacts.recommendedKillSwitches.filter {
            !activeKillSwitchIDs.contains($0)
        }.count
        let widgetControlEntry = evolutionSurfaceState.policy.widgetControlEntryPresentation(
            prompt: attentionSignal.headline,
            triggerReason: attentionSignal.resolvedTriggerReason(
                fallback: evolutionSurfaceState.operatorSnapshot.primaryReason
            )
        )
        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeCopy.message(
                for: latest?.scenario,
                verdict: latest?.verdict
            ),
            latestVerdict: latest?.verdict,
            latestScenario: latest?.scenario,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: evolutionSurfaceState.policy.releaseGuidance.state.rawValue,
                activeCheckpointSourceID: evolutionSurfaceState.policy.input.activeCheckpointSource.rawValue,
                controlEntryKindID: evolutionSurfaceState.policy.widgetControlEntryKind?.rawValue,
                storedControlEntry: widgetControlEntry,
                headline: evolutionSurfaceState.operatorSnapshot.headline,
                primaryReason: evolutionSurfaceState.operatorSnapshot.primaryReason,
                attentionSeverityID: attentionSignal.severity.rawValue,
                attentionBadgeValue: attentionSignal.badgeValue,
                attentionHeadline: attentionSignal.headline,
                attentionDetail: attentionSignal.detail,
                hasActiveCheckpoint: controlSurface.activePresentation != nil,
                hasReviewCheckpoint: controlSurface.reviewPresentation != nil,
                pendingReviewCount: workspaceFacts.pendingReviewCount,
                rollbackReadyCount: workspaceFacts.rollbackReadyCount,
                activeKillSwitchCount: activeKillSwitchIDs.count,
                recommendedKillSwitchCount: recommendedKillSwitchCount
            ),
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
    func recentReplayEntries() async -> [DeveloperDecisionReplayEntry] {
        let export = await decisionRuntimeExport()
        return export.recentReplay
    }

    @MainActor
    func recentReplayDiagnosticsPresentations(
        limit: Int? = nil
    ) async -> [DecisionEvolutionReplayEntryPresentation] {
        let entries = await recentReplayEntries()
        let slice = limit.map { Array(entries.prefix($0)) } ?? entries
        return slice.map(\.diagnosticsPresentation)
    }

    @MainActor
    func replayEntry(matchingRecordID recordID: String) async -> DeveloperDecisionReplayEntry? {
        guard !recordID.isEmpty else { return nil }
        return await recentReplayEntries().first { $0.id == recordID }
    }

    @MainActor
    func replayDiagnosticsPresentation(
        matchingRecordID recordID: String
    ) async -> DecisionEvolutionReplayEntryPresentation? {
        await replayEntry(matchingRecordID: recordID)?.diagnosticsPresentation
    }

    @MainActor
    func replayEntriesByRecordID<S: Sequence>(
        matching recordIDs: S
    ) async -> [String: DeveloperDecisionReplayEntry] where S.Element == String {
        let requestedIDs = Set(recordIDs.filter { !$0.isEmpty })
        guard !requestedIDs.isEmpty else { return [:] }

        let replayEntries = await recentReplayEntries()
        return Dictionary(
            uniqueKeysWithValues: replayEntries.compactMap { replayEntry in
                guard requestedIDs.contains(replayEntry.id) else {
                    return nil
                }
                return (replayEntry.id, replayEntry)
            }
        )
    }

    @MainActor
    func replayDiagnosticsPresentationsByRecordID<S: Sequence>(
        matching recordIDs: S
    ) async -> [String: DecisionEvolutionReplayEntryPresentation] where S.Element == String {
        let replayEntries = await replayEntriesByRecordID(matching: recordIDs)
        return replayEntries.mapValues(\.diagnosticsPresentation)
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

    func presentSessionEngineControlCenter() {
        isSessionEngineControlCenterPresented = true
    }

    func dismissSessionEngineControlCenter() {
        isSessionEngineControlCenterPresented = false
    }

    @MainActor
    func sessionEngineControlSnapshot(
        selectedSessionID: String? = nil,
        selectedBranchID: String? = nil
    ) async -> DecisionSessionEngineControlSnapshot {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            return .build(
                runtimeSnapshot: nil,
                sessions: [],
                inspectionBySessionID: [:],
                selectedSessionID: nil,
                selectedBranchID: nil,
                selectedBranches: [],
                selectedCheckpoint: nil,
                selectedTimeline: nil,
                pendingImportPreview: pendingSessionEngineImportDraft?.presentation
            )
        }

        do {
            let runtimeSnapshot = try await sessionEngine.snapshot()
            let sessions = try await sessionEngine.listSessions(limit: 12)
            let selectedSession = sessions.first(where: { $0.id == selectedSessionID }) ?? sessions.first
            let selectedBranches: [DecisionSessionBranch]
            if let selectedSession {
                selectedBranches = try await sessionEngine.listBranches(sessionId: selectedSession.id)
            } else {
                selectedBranches = []
            }
            let resolvedBranchID: String?
            if let selectedSession {
                resolvedBranchID = selectedBranches.contains(where: { $0.id == selectedBranchID })
                    ? selectedBranchID
                    : selectedSession.headBranchId
            } else {
                resolvedBranchID = nil
            }
            let selectedCheckpoint: DecisionSessionCheckpoint?
            if let selectedSession, let resolvedBranchID {
                selectedCheckpoint = try await sessionEngine.getLatestCheckpoint(
                    sessionId: selectedSession.id,
                    branchId: resolvedBranchID
                )
            } else {
                selectedCheckpoint = nil
            }
            let selectedTimeline: DecisionSessionTimeline?
            if let selectedSession, let resolvedBranchID {
                selectedTimeline = try await sessionEngine.rebuildTimeline(
                    sessionId: selectedSession.id,
                    branchId: resolvedBranchID
                )
            } else {
                selectedTimeline = nil
            }

            return .build(
                runtimeSnapshot: runtimeSnapshot,
                sessions: sessions,
                inspectionBySessionID: Dictionary(
                    uniqueKeysWithValues: runtimeSnapshot.recentSessions.map { ($0.sessionID, $0) }
                ),
                selectedSessionID: selectedSession?.id,
                selectedBranchID: resolvedBranchID,
                selectedBranches: selectedBranches,
                selectedCheckpoint: selectedCheckpoint,
                selectedTimeline: selectedTimeline,
                pendingImportPreview: pendingSessionEngineImportDraft?.presentation
            )
        } catch {
            publishStartupNotice("Session Engine control surface could not load: \(error.localizedDescription)")
            return .build(
                runtimeSnapshot: nil,
                sessions: [],
                inspectionBySessionID: [:],
                selectedSessionID: nil,
                selectedBranchID: nil,
                selectedBranches: [],
                selectedCheckpoint: nil,
                selectedTimeline: nil,
                pendingImportPreview: pendingSessionEngineImportDraft?.presentation
            )
        }
    }

    @MainActor
    func pauseSessionEngineSession(_ sessionID: String) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.pauseSession(sessionID)
            publishStartupNotice("Paused session \(session.title).")
        } catch {
            publishStartupNotice("Unable to pause session \(sessionID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func resumeSessionEngineSession(_ sessionID: String) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.resumeSession(sessionID)
            publishStartupNotice("Resumed session \(session.title).")
        } catch {
            publishStartupNotice("Unable to resume session \(sessionID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func recoverSessionEngineSession(_ sessionID: String) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let recovery = try await sessionEngine.recoverSession(sessionID)
            publishStartupNotice(
                "Recovered session \(recovery.session.title) on branch \(recovery.recoveredBranch.name)."
            )
        } catch {
            publishStartupNotice("Unable to recover session \(sessionID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func restoreSessionEngineCheckpoint(_ checkpointID: String) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let checkpoint = try await sessionEngine.getCheckpointForHost(checkpointID)
            let recovery = try await sessionEngine.restoreFromCheckpoint(checkpointID)
            let checkpointDescriptor = checkpoint.summary.goal.isEmpty
                ? checkpoint.id
                : checkpoint.summary.goal
            publishStartupNotice(
                "Restored \(recovery.session.title) from checkpoint \(checkpointDescriptor) on branch \(recovery.recoveredBranch.name)."
            )
        } catch {
            publishStartupNotice("Unable to restore checkpoint \(checkpointID): \(error.localizedDescription)")
        }
    }

    @MainActor
    @discardableResult
    func exportSessionEngineSession(_ sessionID: String) async -> URL? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return nil
        }

        do {
            let exportURL = try await performTrackedSessionEngineToolLifecycle(
                sessionID: sessionID,
                tool: "export_session_engine_bundle",
                argsPreview: [
                    "sessionID": sessionID
                ]
            ) {
                try await sessionEngine.exportSession(sessionID)
            } resultSummary: { exportURL in
                "Exported Session Engine bundle \(exportURL.lastPathComponent)."
            }
            publishStartupNotice("Exported Session Engine bundle \(exportURL.lastPathComponent).")
            return exportURL
        } catch {
            publishStartupNotice("Unable to export session \(sessionID): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    @discardableResult
    func importSessionEngineBundle(from sourceURL: URL) async -> DecisionSession? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            sessionEngineBundleIssue = "Session Engine is unavailable."
            publishStartupNotice("Session Engine is unavailable.")
            return nil
        }

        do {
            let bundleData = try readSessionEngineBundleData(from: sourceURL)
            let preview = try await sessionEngine.inspectImportBundle(bundleData: bundleData)
            let trackedSessionID = await trackedSessionEngineLifecycleSessionID(
                preview.sourceSessionId,
                sessionEngine: sessionEngine
            )
            let session: DecisionSession
            if let trackedSessionID {
                session = try await performTrackedSessionEngineToolLifecycle(
                    sessionID: trackedSessionID,
                    tool: "import_session_engine_bundle",
                    argsPreview: [
                        "sourceFile": sourceURL.lastPathComponent,
                        "sourceSessionID": preview.sourceSessionId,
                        "importedTitle": preview.importedTitle
                    ]
                ) {
                    try await sessionEngine.importSession(bundleData: bundleData)
                } resultSummary: { importedSession in
                    "Imported Session Engine bundle as \(importedSession.title)."
                }
            } else {
                session = try await sessionEngine.importSession(bundleData: bundleData)
            }
            pendingSessionEngineImportDraft = nil
            sessionEngineBundleIssue = nil
            publishStartupNotice("Imported Session Engine bundle as \(session.title).")
            return session
        } catch {
            sessionEngineBundleIssue = "Unable to import Session Engine bundle: \(error.localizedDescription)"
            publishStartupNotice("Unable to import Session Engine bundle: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    @discardableResult
    func inspectSessionEngineBundle(from sourceURL: URL) async -> DecisionSessionImportBundlePreview? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            sessionEngineBundleIssue = "Session Engine is unavailable."
            publishStartupNotice("Session Engine is unavailable.")
            return nil
        }

        do {
            let bundleData = try readSessionEngineBundleData(from: sourceURL)
            let preview = try await sessionEngine.inspectImportBundle(bundleData: bundleData)
            sessionEngineBundleIssue = nil
            return preview
        } catch {
            sessionEngineBundleIssue = "Unable to inspect Session Engine bundle: \(error.localizedDescription)"
            publishStartupNotice("Unable to inspect Session Engine bundle: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    @discardableResult
    func stageSessionEngineBundleImport(from sourceURL: URL) async -> DecisionSessionEnginePendingImportDraft? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            sessionEngineBundleIssue = "Session Engine is unavailable."
            publishStartupNotice("Session Engine is unavailable.")
            return nil
        }

        do {
            let bundleData = try readSessionEngineBundleData(from: sourceURL)
            let preview = try await sessionEngine.inspectImportBundle(bundleData: bundleData)
            let draft = DecisionSessionEnginePendingImportDraft(
                sourceFileName: sourceURL.lastPathComponent,
                bundleData: bundleData,
                preview: preview
            )
            pendingSessionEngineImportDraft = draft
            sessionEngineBundleIssue = nil
            return draft
        } catch {
            pendingSessionEngineImportDraft = nil
            sessionEngineBundleIssue = "Unable to inspect Session Engine bundle: \(error.localizedDescription)"
            publishStartupNotice("Unable to inspect Session Engine bundle: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    @discardableResult
    func importStagedSessionEngineBundle() async -> DecisionSession? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            sessionEngineBundleIssue = "Session Engine is unavailable."
            publishStartupNotice("Session Engine is unavailable.")
            return nil
        }

        guard let draft = pendingSessionEngineImportDraft else {
            sessionEngineBundleIssue = "Choose a Session Engine bundle to import."
            return nil
        }

        do {
            let trackedSessionID = await trackedSessionEngineLifecycleSessionID(
                draft.preview.sourceSessionId,
                sessionEngine: sessionEngine
            )
            let session: DecisionSession
            if let trackedSessionID {
                session = try await performTrackedSessionEngineToolLifecycle(
                    sessionID: trackedSessionID,
                    tool: "import_session_engine_bundle",
                    argsPreview: [
                        "sourceFile": draft.sourceFileName,
                        "sourceSessionID": draft.preview.sourceSessionId,
                        "importedTitle": draft.preview.importedTitle
                    ]
                ) {
                    try await sessionEngine.importSession(bundleData: draft.bundleData)
                } resultSummary: { importedSession in
                    "Imported Session Engine bundle as \(importedSession.title)."
                }
            } else {
                session = try await sessionEngine.importSession(bundleData: draft.bundleData)
            }
            pendingSessionEngineImportDraft = nil
            sessionEngineBundleIssue = nil
            publishStartupNotice("Imported Session Engine bundle as \(session.title).")
            return session
        } catch {
            sessionEngineBundleIssue = "Unable to import Session Engine bundle: \(error.localizedDescription)"
            publishStartupNotice("Unable to import Session Engine bundle: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func archiveSessionEngineSession(_ sessionID: String) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.archiveSession(sessionID)
            publishStartupNotice("Archived session \(session.title).")
        } catch {
            publishStartupNotice("Unable to archive session \(sessionID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func appendSessionEngineCorrection(
        _ sessionID: String,
        targetEventID: String? = nil,
        newText: String,
        reason: String = "host correction branch"
    ) async {
        let correctionText = trimmed(newText)
        guard correctionText.isEmpty == false else {
            publishStartupNotice("Enter a correction before creating a new branch.")
            return
        }

        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.getSession(sessionID)
            let events = try await sessionEngine.listEvents(
                sessionId: sessionID,
                branchId: session.headBranchId
            )
            let explicitTargetEvent = targetEventID.flatMap { candidateID in
                events.first(where: { $0.id == candidateID })
            }
            guard let targetEvent = explicitTargetEvent ?? sessionEngineCorrectionTargetEvent(in: events) else {
                publishStartupNotice("Session Engine could not find a stable event to correct.")
                return
            }
            if targetEventID != nil, explicitTargetEvent == nil {
                publishStartupNotice("Session Engine could not find the selected history point to correct.")
                return
            }

            let correction = try await sessionEngine.appendCorrection(
                sessionId: sessionID,
                targetEventId: targetEvent.id,
                newText: correctionText,
                reason: reason
            )
            publishStartupNotice(
                "Created correction branch \(correction.branch.name) for \(session.title) from event \(targetEvent.seq)."
            )
        } catch {
            publishStartupNotice("Unable to create a correction branch: \(error.localizedDescription)")
        }
    }

    @MainActor
    func switchSessionEngineBranch(
        sessionID: String,
        branchID: String
    ) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.switchBranch(sessionId: sessionID, branchId: branchID)
            publishStartupNotice("Switched \(session.title) to branch \(branchID).")
        } catch {
            publishStartupNotice("Unable to switch branch \(branchID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func mergeSessionEngineBranch(
        sessionID: String,
        sourceBranchID: String
    ) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.getSession(sessionID)
            guard session.headBranchId != sourceBranchID else {
                publishStartupNotice("Switch to a different active head before merging this branch.")
                return
            }

            let mergedBranch = try await sessionEngine.mergeBranch(
                sourceBranchId: sourceBranchID,
                targetBranchId: session.headBranchId
            )
            publishStartupNotice(
                "Merged branch \(mergedBranch.name) into \(session.headBranchId)."
            )
        } catch {
            publishStartupNotice("Unable to merge branch \(sourceBranchID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func abandonSessionEngineBranch(
        sessionID: String,
        branchID: String
    ) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let session = try await sessionEngine.getSession(sessionID)
            guard session.headBranchId != branchID else {
                publishStartupNotice("Switch away from the current head before abandoning this branch.")
                return
            }

            let abandonedBranch = try await sessionEngine.abandonBranch(branchID)
            publishStartupNotice("Abandoned branch \(abandonedBranch.name).")
        } catch {
            publishStartupNotice("Unable to abandon branch \(branchID): \(error.localizedDescription)")
        }
    }

    @MainActor
    func sweepSessionEngineWatchdog() async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            publishStartupNotice("Session Engine is unavailable.")
            return
        }

        do {
            let actions = try await sessionEngine.sweepWatchdog()
            if actions.isEmpty {
                publishStartupNotice("Session Engine watchdog found no stalled steps.")
            } else {
                publishStartupNotice("Session Engine watchdog recovered \(actions.count) stalled step(s).")
            }
        } catch {
            publishStartupNotice("Session Engine watchdog sweep failed: \(error.localizedDescription)")
        }
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
    func substrateEBrainKernelFrame() async -> DecisionEBrainKernelFrame? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.liveEBrainKernelFrame
    }

    @MainActor
    func substrateEBrainPresentationFrame() async -> DecisionEBrainPresentationFrame? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.liveEBrainPresentationFrame
    }

    @MainActor
    func substrateEBrainFactsBundle() async -> DecisionEvolutionEBrainFactsBundle? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.effectiveEBrainFactsBundle
    }

    @MainActor
    func substrateLayerStackLines() async -> [String] {
        let inspection = await substrateInspectionSnapshot()
        return inspection.effectiveLayerStackLines
    }

    @MainActor
    func substrateLatestPersistenceIssue() async -> PersistenceIssueRecord? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.latestPersistenceIssue
    }

    @MainActor
    func substrateLatestPersistenceRemediationSnapshot() async -> PersistenceRemediationSnapshot? {
        let inspection = await substrateInspectionSnapshot()
        return inspection.latestPersistenceRemediationSnapshot
    }

    @MainActor
    func substrateRuntimePolicyLineage() async -> BeforeRuntimePolicyLineage {
        let inspection = await substrateInspectionSnapshot()
        return inspection.runtimePolicyLineage
    }

    @MainActor
    func substrateRuntimePolicyIssues() async -> [BeforeRuntimePolicyIssue] {
        let inspection = await substrateInspectionSnapshot()
        return inspection.runtimePolicyIssues
    }

    @MainActor
    func substrateInspectionSnapshot() async -> DecisionTestingSubstrateInspectionSnapshot {
        let inspectionReferenceDate =
            currentBrainState?.evolutionState.latestCheckpoint?.createdAt
            ?? EBrainTurnDebugStore.shared.turns.first?.runtimeTrace.recordedAt
            ?? .now
        let inspectionBrain = inspectionBrainSnapshot(now: inspectionReferenceDate)
        let runtimeContext = resolvedRuntimeContext()
        let runtimeSnapshot = runtimeContext.runtimeSnapshot
        let turn = BehavioralAISubstrateBridge.eBrainTurn(
            hostRuntime: runtimeContext.hostRuntime,
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession,
            currentBrainState: inspectionBrain.currentBrain,
            projection: inspectionBrain.projection,
            activeKillSwitches: activeEvolutionKillSwitches,
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
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    func sendBalanceSessionToSupport(_ session: BalanceBoardSession) {
        let request = SupportRequestFactory.makeBalanceRequest(from: session)
        supportInbox.insert(request)
        activeBalanceSession = nil
        supportSurface = .buddy
        selectedTab = .support
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    func sendMirrorSessionToSupport(_ session: MirrorWorkspaceSession) {
        let request = SupportRequestFactory.makeMirrorRequest(from: session)
        supportInbox.insert(request)
        activeMirrorSession = nil
        supportSurface = .buddy
        selectedTab = .support
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
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
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    func sendBalanceSessionToSharedLife(_ session: BalanceBoardSession) {
        sharedLifeStore.insert(SharedLifeItemFactory.makeBalanceItem(from: session))
        activeBalanceSession = nil
        supportSurface = .sharedLife
        selectedTab = .support
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    func sendMirrorSessionToSharedLife(_ session: MirrorWorkspaceSession) {
        sharedLifeStore.insert(SharedLifeItemFactory.makeMirrorItem(from: session))
        activeMirrorSession = nil
        supportSurface = .sharedLife
        selectedTab = .support
        persistActiveWorkspaceState(
            trackSessionEngineLifecycle: true,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
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
        var restoredWorkspaceState: ActiveDecisionWorkspaceState?

        hostRuntime.restoreActiveWorkspaceIfNeeded(
            restoreEnabled: preferences.restoreInProgressWorkspaces,
            hasActivePrimaryWorkflow: activeQuickSession != nil,
            hasActiveComparativeWorkflow: activeBalanceSession != nil,
            hasActiveReflectiveWorkflow: activeMirrorSession != nil,
            hasReflectionContext: reflectionContext != nil,
            loadState: { ActiveDecisionWorkspaceStore.load() },
            modeID: {
                $0.mode?.substrateModeID
                ?? DecisionMode.fromSubstrateModeID($0.modeRaw)?.substrateModeID
                ?? BeforeProductCompatibility.substrateModeID(rawValue: $0.modeRaw)
            },
            restorePrimary: { state in
                restoredWorkspaceState = state
                activateQuickSession(state.restoreQuickSession())
            },
            restoreComparative: { state in
                restoredWorkspaceState = state
                activateBalanceSession(state.restoreBalanceSession())
            },
            restoreReflective: { state in
                restoredWorkspaceState = state
                activateMirrorSession(state.restoreMirrorSession())
            },
            selectHomeTab: {
                selectedTab = .home
            },
            afterRestore: {
                refreshActiveTaskGraphSnapshot()
                refreshPredictedIntervention()
                if let restoredWorkspaceState {
                    recordActiveWorkspaceRestoreLifecycle(restoredWorkspaceState)
                }
            }
        )
    }

    private func persistActiveWorkspaceState(
        trackSessionEngineLifecycle: Bool = false,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        var state = capturedActiveWorkspaceState()
        let previousState = trackSessionEngineLifecycle ? ActiveDecisionWorkspaceStore.load() : nil

        if let eBrainTurn {
            state?.eBrainTurn = eBrainTurn
        }

        if let state {
            ActiveDecisionWorkspaceStore.save(state)
            if trackSessionEngineLifecycle {
                recordActiveWorkspacePersistenceLifecycle(
                    state,
                    eBrainTurn: eBrainTurn ?? state.eBrainTurn
                )
            }
        } else {
            ActiveDecisionWorkspaceStore.clear()
            if trackSessionEngineLifecycle, let previousState {
                recordActiveWorkspaceClearLifecycle(
                    previousState,
                    eBrainTurn: eBrainTurn ?? previousState.eBrainTurn
                )
            }
        }

        refreshActiveTaskGraphSnapshot()
    }

    private func capturedActiveWorkspaceState() -> ActiveDecisionWorkspaceState? {
        if let session = activeQuickSession {
            return ActiveDecisionWorkspaceState.capture(from: session)
        }
        if let session = activeBalanceSession {
            return ActiveDecisionWorkspaceState.capture(from: session)
        }
        if let session = activeMirrorSession {
            return ActiveDecisionWorkspaceState.capture(from: session)
        }
        return nil
    }

    private func activeEvaluationEBrainTurn() -> BASEBrainTurnResult? {
        activeQuickSession?.lastEvaluationEBrainTurn
            ?? activeBalanceSession?.lastEvaluationEBrainTurn
            ?? activeMirrorSession?.lastEvaluationEBrainTurn
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
        primeSessionEngineBinding(for: session)
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
        primeSessionEngineBinding(for: session)
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
        primeSessionEngineBinding(for: session)
    }

    private func primeSessionEngineBinding(for session: QuickCheckSession) {
        Task {
            _ = await ensureSessionEngineSession(
                existingID: { session.sessionEngineSessionID },
                bindingTask: { session.sessionEngineBindingTask },
                setBindingTask: { session.sessionEngineBindingTask = $0 },
                setSessionID: { session.sessionEngineSessionID = $0 },
                title: sessionEngineTitle(
                    prefix: "Quick",
                    seed: session.note,
                    fallback: "Quick - \(session.scenario.title)"
                )
            )
        }
    }

    private func primeSessionEngineBinding(for session: BalanceBoardSession) {
        Task {
            _ = await ensureSessionEngineSession(
                existingID: { session.sessionEngineSessionID },
                bindingTask: { session.sessionEngineBindingTask },
                setBindingTask: { session.sessionEngineBindingTask = $0 },
                setSessionID: { session.sessionEngineSessionID = $0 },
                title: sessionEngineTitle(
                    prefix: "Balance",
                    seed: session.prompt,
                    fallback: "Balance board"
                )
            )
        }
    }

    private func primeSessionEngineBinding(for session: MirrorWorkspaceSession) {
        Task {
            _ = await ensureSessionEngineSession(
                existingID: { session.sessionEngineSessionID },
                bindingTask: { session.sessionEngineBindingTask },
                setBindingTask: { session.sessionEngineBindingTask = $0 },
                setSessionID: { session.sessionEngineSessionID = $0 },
                title: sessionEngineTitle(
                    prefix: "Mirror",
                    seed: session.prompt,
                    fallback: "Mirror workspace"
                )
            )
        }
    }

    private func ensureSessionEngineSession(
        existingID: () -> String?,
        bindingTask: () -> Task<String?, Never>?,
        setBindingTask: (Task<String?, Never>?) -> Void,
        setSessionID: (String?) -> Void,
        title: String
    ) async -> String? {
        if let existingID = existingID() {
            return existingID
        }

        if let task = bindingTask() {
            let resolvedID = await task.value
            setBindingTask(nil)
            if let resolvedID, existingID() != resolvedID {
                setSessionID(resolvedID)
                persistActiveWorkspaceState(trackSessionEngineLifecycle: true)
            }
            return resolvedID
        }

        guard let sessionEngine = DecisionSessionEngine.shared else {
            return nil
        }

        let task = Task<String?, Never> {
            do {
                let session = try await sessionEngine.createSession(title: title)
                return session.id
            } catch {
                await MainActor.run {
                    publishStartupNotice("Session Engine could not create a local recovery session for \(title).")
                }
                return nil
            }
        }

        setBindingTask(task)
        let resolvedID = await task.value
        setBindingTask(nil)

        if let resolvedID, existingID() != resolvedID {
            setSessionID(resolvedID)
            persistActiveWorkspaceState(trackSessionEngineLifecycle: true)
        }

        return resolvedID
    }

    private func beginQuickSessionEngineEvaluation(
        _ session: QuickCheckSession
    ) async -> DecisionSessionEngineEvaluationContext? {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Quick",
                seed: session.note,
                fallback: "Quick - \(session.scenario.title)"
            )
        ) else {
            return nil
        }

        return await beginSessionEngineEvaluation(
            sessionID: sessionID,
            userText: quickSessionEventText(session),
            intent: "quick_check",
            checkpointDraft: quickSessionCheckpointDraft(session, result: nil)
        )
    }

    private func recordQuickSessionEngineAction(
        _ session: QuickCheckSession,
        result: QuickCheckResult,
        action: CheckAction,
        eBrainTurn: BASEBrainTurnResult? = nil,
        now: Date = .now
    ) async {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Quick",
                seed: session.note,
                fallback: "Quick - \(session.scenario.title)"
            )
        ) else {
            return
        }

        await recordSessionEngineToolLifecycle(
            sessionID: sessionID,
            tool: "complete_quick_check",
            argsPreview: [
                "action": action.rawValue,
                "scenario": session.scenario.rawValue,
                "entrySource": session.entrySource.rawValue
            ],
            resultSummary: "Completed quick check with action \(action.title(using: BeforePolicy.QuickCheck.defaultBufferDuration)).",
            checkpointDraft: sessionEngineCheckpointDraft(
                quickSessionCheckpointDraft(session, result: result),
                actionSummary: "completed quick check with action \(action.title(using: BeforePolicy.QuickCheck.defaultBufferDuration))",
                eBrainTurn: eBrainTurn
            ),
            now: now
        )
    }

    private func beginBalanceSessionEngineEvaluation(
        _ session: BalanceBoardSession
    ) async -> DecisionSessionEngineEvaluationContext? {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Balance",
                seed: session.prompt,
                fallback: "Balance board"
            )
        ) else {
            return nil
        }

        return await beginSessionEngineEvaluation(
            sessionID: sessionID,
            userText: balanceSessionEventText(session),
            intent: "balance_board",
            checkpointDraft: balanceSessionCheckpointDraft(session, result: nil)
        )
    }

    private func recordBalanceSessionEngineAction(
        _ session: BalanceBoardSession,
        result: BalanceBoardResult,
        actionSummary: String,
        tool: String,
        argsPreview: [String: String],
        eBrainTurn: BASEBrainTurnResult? = nil,
        now: Date = .now
    ) async {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Balance",
                seed: session.prompt,
                fallback: "Balance board"
            )
        ) else {
            return
        }

        await recordSessionEngineToolLifecycle(
            sessionID: sessionID,
            tool: tool,
            argsPreview: argsPreview,
            resultSummary: sessionEngineActionResultSummary(actionSummary),
            checkpointDraft: sessionEngineCheckpointDraft(
                balanceSessionCheckpointDraft(session, result: result),
                actionSummary: actionSummary,
                eBrainTurn: eBrainTurn
            ),
            now: now
        )
    }

    private func beginMirrorSessionEngineEvaluation(
        _ session: MirrorWorkspaceSession
    ) async -> DecisionSessionEngineEvaluationContext? {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Mirror",
                seed: session.prompt,
                fallback: "Mirror workspace"
            )
        ) else {
            return nil
        }

        return await beginSessionEngineEvaluation(
            sessionID: sessionID,
            userText: mirrorSessionEventText(session),
            intent: "mirror_workspace",
            checkpointDraft: mirrorSessionCheckpointDraft(session, result: nil)
        )
    }

    private func recordMirrorSessionEngineAction(
        _ session: MirrorWorkspaceSession,
        result: MirrorResult,
        actionSummary: String,
        tool: String,
        argsPreview: [String: String],
        eBrainTurn: BASEBrainTurnResult? = nil,
        now: Date = .now
    ) async {
        guard let sessionID = await ensureSessionEngineSession(
            existingID: { session.sessionEngineSessionID },
            bindingTask: { session.sessionEngineBindingTask },
            setBindingTask: { session.sessionEngineBindingTask = $0 },
            setSessionID: { session.sessionEngineSessionID = $0 },
            title: sessionEngineTitle(
                prefix: "Mirror",
                seed: session.prompt,
                fallback: "Mirror workspace"
            )
        ) else {
            return
        }

        await recordSessionEngineToolLifecycle(
            sessionID: sessionID,
            tool: tool,
            argsPreview: argsPreview,
            resultSummary: sessionEngineActionResultSummary(actionSummary),
            checkpointDraft: sessionEngineCheckpointDraft(
                mirrorSessionCheckpointDraft(session, result: result),
                actionSummary: actionSummary,
                eBrainTurn: eBrainTurn
            ),
            now: now
        )
    }

    private func beginSessionEngineEvaluation(
        sessionID: String,
        userText: String,
        intent: String,
        checkpointDraft: DecisionSessionCheckpointDraft
    ) async -> DecisionSessionEngineEvaluationContext? {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            return nil
        }

        do {
            _ = try await sessionEngine.appendUserMessage(
                sessionId: sessionID,
                text: userText,
                intent: intent,
                checkpointDraft: checkpointDraft
            )
            let step = try await sessionEngine.startStep(
                sessionId: sessionID,
                status: .planning
            )
            _ = try await sessionEngine.heartbeat(
                stepId: step.id,
                progress: 0.35,
                status: .acting
            )
            return DecisionSessionEngineEvaluationContext(
                sessionID: sessionID,
                stepID: step.id
            )
        } catch {
            publishStartupNotice("Session Engine could not record the start of this evaluation.")
            return DecisionSessionEngineEvaluationContext(
                sessionID: sessionID,
                stepID: nil
            )
        }
    }

    private func finalizeQuickSessionEngineEvaluation(
        _ session: QuickCheckSession,
        context: DecisionSessionEngineEvaluationContext?,
        eBrainTurn: BASEBrainTurnResult?
    ) async {
        guard let context else { return }
        guard let result = session.result else {
            await markSessionEngineStepStalled(
                context.stepID,
                errorCode: "quick_result_missing"
            )
            return
        }

        await finalizeSessionEngineEvaluation(
            context: context,
            assistantText: quickSessionResultText(result),
            summary: result.verdict.title,
            checkpointDraft: quickSessionCheckpointDraft(session, result: result),
            eBrainTurn: eBrainTurn
        )
    }

    private func finalizeBalanceSessionEngineEvaluation(
        _ session: BalanceBoardSession,
        context: DecisionSessionEngineEvaluationContext?,
        eBrainTurn: BASEBrainTurnResult?
    ) async {
        guard let context else { return }
        guard let result = session.result else {
            await markSessionEngineStepStalled(
                context.stepID,
                errorCode: "balance_result_missing"
            )
            return
        }

        await finalizeSessionEngineEvaluation(
            context: context,
            assistantText: balanceSessionResultText(result),
            summary: result.focusTitle,
            checkpointDraft: balanceSessionCheckpointDraft(session, result: result),
            eBrainTurn: eBrainTurn
        )
    }

    private func finalizeMirrorSessionEngineEvaluation(
        _ session: MirrorWorkspaceSession,
        context: DecisionSessionEngineEvaluationContext?,
        eBrainTurn: BASEBrainTurnResult?
    ) async {
        guard let context else { return }
        guard let result = session.result else {
            await markSessionEngineStepStalled(
                context.stepID,
                errorCode: "mirror_result_missing"
            )
            return
        }

        await finalizeSessionEngineEvaluation(
            context: context,
            assistantText: mirrorSessionResultText(result),
            summary: result.nextActionTitle,
            checkpointDraft: mirrorSessionCheckpointDraft(session, result: result),
            eBrainTurn: eBrainTurn
        )
    }

    private func finalizeSessionEngineEvaluation(
        context: DecisionSessionEngineEvaluationContext,
        assistantText: String,
        summary: String,
        checkpointDraft: DecisionSessionCheckpointDraft,
        eBrainTurn: BASEBrainTurnResult?
    ) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            return
        }

        do {
            let enrichedCheckpointDraft = sessionEngineCheckpointDraft(
                checkpointDraft,
                eBrainTurn: eBrainTurn
            )
            if let stepID = context.stepID {
                _ = try await sessionEngine.heartbeat(
                    stepId: stepID,
                    progress: 0.85,
                    status: .writing
                )
            }
            _ = try await sessionEngine.appendAssistantMessage(
                sessionId: context.sessionID,
                text: assistantText,
                summary: summary,
                checkpointDraft: enrichedCheckpointDraft
            )
            if let stepID = context.stepID {
                _ = try await sessionEngine.completeStep(stepId: stepID)
            }
        } catch {
            await markSessionEngineStepStalled(
                context.stepID,
                errorCode: "evaluation_commit_failed"
            )
            publishStartupNotice("Session Engine could not checkpoint this evaluation cleanly.")
        }
    }

    private func recordSessionEngineToolLifecycle(
        sessionID: String,
        tool: String,
        argsPreview: [String: String],
        resultSummary: String,
        checkpointDraft: DecisionSessionCheckpointDraft,
        eBrainTurn: BASEBrainTurnResult? = nil,
        now: Date = .now
    ) async {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            return
        }

        var toolStepID: String?
        var started = false
        var finished = false
        do {
            let toolStep = try await sessionEngine.startStep(
                sessionId: sessionID,
                status: .waitingTool,
                now: now
            )
            toolStepID = toolStep.id
            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.2,
                status: .waitingTool,
                now: now
            )
            _ = try await sessionEngine.appendToolCallStarted(
                sessionId: sessionID,
                tool: tool,
                argsPreview: argsPreview,
                now: now
            )
            started = true
            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.55,
                status: .acting,
                now: now
            )
            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.85,
                status: .writing,
                now: now
            )
            _ = try await sessionEngine.appendToolCallFinished(
                sessionId: sessionID,
                tool: tool,
                resultSummary: resultSummary,
                checkpointDraft: sessionEngineCheckpointDraft(
                    checkpointDraft,
                    eBrainTurn: eBrainTurn
                ),
                now: now
            )
            finished = true
            _ = try await sessionEngine.completeStep(stepId: toolStep.id, now: now)
        } catch {
            if started && !finished {
                _ = try? await sessionEngine.appendToolCallFailed(
                    sessionId: sessionID,
                    tool: tool,
                    errorCode: "tool_lifecycle_commit_failed",
                    recoverable: true,
                    now: now
                )
            }
            if let toolStepID {
                _ = try? await sessionEngine.markStepStalled(
                    stepId: toolStepID,
                    errorCode: "tool_lifecycle_commit_failed",
                    now: now
                )
            }
            let toolLabel = tool.replacingOccurrences(of: "_", with: " ")
            publishStartupNotice("Session Engine could not record \(toolLabel).")
        }
    }

    private func trackedSessionEngineLifecycleSessionID(
        _ sessionID: String,
        sessionEngine: DecisionSessionEngine
    ) async -> String? {
        guard !sessionID.isEmpty else {
            return nil
        }

        guard (try? await sessionEngine.getSession(sessionID)) != nil else {
            return nil
        }

        return sessionID
    }

    private func performTrackedSessionEngineToolLifecycle<Result>(
        sessionID: String,
        tool: String,
        argsPreview: [String: String],
        checkpointDraft: DecisionSessionCheckpointDraft? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        operation: () async throws -> Result,
        resultSummary: (Result) -> String
    ) async throws -> Result {
        guard let sessionEngine = DecisionSessionEngine.shared else {
            return try await operation()
        }

        var toolStepID: String?
        var started = false
        var finished = false

        do {
            let startedAt = Date.now
            let toolStep = try await sessionEngine.startStep(
                sessionId: sessionID,
                status: .waitingTool,
                now: startedAt
            )
            toolStepID = toolStep.id
            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.15,
                status: .waitingTool,
                now: startedAt
            )
            _ = try await sessionEngine.appendToolCallStarted(
                sessionId: sessionID,
                tool: tool,
                argsPreview: argsPreview,
                now: startedAt
            )
            started = true

            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.5,
                status: .acting,
                now: Date.now
            )

            let result = try await operation()

            _ = try await sessionEngine.heartbeat(
                stepId: toolStep.id,
                progress: 0.85,
                status: .writing,
                now: Date.now
            )
            let enrichedCheckpointDraft = checkpointDraft.map {
                sessionEngineCheckpointDraft($0, eBrainTurn: eBrainTurn)
            }
            _ = try await sessionEngine.appendToolCallFinished(
                sessionId: sessionID,
                tool: tool,
                resultSummary: resultSummary(result),
                checkpointDraft: enrichedCheckpointDraft,
                now: Date.now
            )
            finished = true
            _ = try await sessionEngine.completeStep(stepId: toolStep.id, now: Date.now)
            return result
        } catch {
            if started && !finished {
                _ = try? await sessionEngine.appendToolCallFailed(
                    sessionId: sessionID,
                    tool: tool,
                    errorCode: "tool_lifecycle_commit_failed",
                    recoverable: true,
                    now: Date.now
                )
            }
            if let toolStepID {
                _ = try? await sessionEngine.markStepStalled(
                    stepId: toolStepID,
                    errorCode: "tool_lifecycle_commit_failed",
                    now: Date.now
                )
            }
            throw error
        }
    }

    private func recordActiveWorkspacePersistenceLifecycle(
        _ state: ActiveDecisionWorkspaceState,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        recordActiveWorkspaceLifecycle(
            state,
            tool: "persist_active_workspace_state",
            actionSummary: "persisted active \(workspaceLifecycleModeLabel(state)) workspace state",
            now: state.savedAt,
            eBrainTurn: eBrainTurn
        )
    }

    private func recordActiveWorkspaceRestoreLifecycle(
        _ state: ActiveDecisionWorkspaceState,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        recordActiveWorkspaceLifecycle(
            state,
            tool: "restore_active_workspace_state",
            actionSummary: "restored active \(workspaceLifecycleModeLabel(state)) workspace state",
            now: .now,
            eBrainTurn: eBrainTurn ?? state.eBrainTurn
        )
    }

    private func recordActiveWorkspaceClearLifecycle(
        _ state: ActiveDecisionWorkspaceState,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        recordActiveWorkspaceLifecycle(
            state,
            tool: "clear_active_workspace_state",
            actionSummary: "cleared active \(workspaceLifecycleModeLabel(state)) workspace state",
            now: .now,
            eBrainTurn: eBrainTurn ?? state.eBrainTurn
        )
    }

    private func recordActiveWorkspaceLifecycle(
        _ state: ActiveDecisionWorkspaceState,
        tool: String,
        actionSummary: String,
        now: Date,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        guard let rawSessionID = state.sessionEngineSessionID,
              !rawSessionID.isEmpty else {
            return
        }

        let argsPreview = workspaceLifecycleArgsPreview(for: state)

        scheduleDeferredSessionEngineTask {
            guard let sessionEngine = DecisionSessionEngine.shared,
                  let sessionID = await self.trackedSessionEngineLifecycleSessionID(
                    rawSessionID,
                    sessionEngine: sessionEngine
                  ) else {
                return
            }

            let resolvedTurn = eBrainTurn ?? self.currentLiveEBrainTurn(
                persistLineage: false,
                now: now
            )
            let checkpointDraft = self.sessionEngineCheckpointDraft(
                self.workspaceStateCheckpointDraft(state),
                actionSummary: actionSummary,
                eBrainTurn: resolvedTurn
            )

            await self.recordSessionEngineToolLifecycle(
                sessionID: sessionID,
                tool: tool,
                argsPreview: argsPreview,
                resultSummary: self.sessionEngineActionResultSummary(actionSummary),
                checkpointDraft: checkpointDraft,
                now: now
            )
        }
    }

    private func scheduleDeferredSessionEngineTask(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        let taskID = UUID()
        let task = Task { @MainActor in
            defer { Self.deferredSessionEngineTasks[taskID] = nil }
            await operation()
        }
        Self.deferredSessionEngineTasks[taskID] = task
    }

    private func workspaceLifecycleArgsPreview(
        for state: ActiveDecisionWorkspaceState
    ) -> [String: String] {
        [
            "mode": state.mode?.rawValue ?? state.modeRaw,
            "entrySource": state.entrySource.rawValue,
            "evaluated": state.wasEvaluated ? "true" : "false",
            "savedAt": ISO8601DateFormatter().string(from: state.savedAt)
        ]
    }

    private func workspaceLifecycleModeLabel(
        _ state: ActiveDecisionWorkspaceState
    ) -> String {
        (state.mode?.rawValue ?? state.modeRaw)
            .replacingOccurrences(of: "_", with: " ")
    }

    private func workspaceStateCheckpointDraft(
        _ state: ActiveDecisionWorkspaceState
    ) -> DecisionSessionCheckpointDraft {
        switch state.mode ?? .quick {
        case .quick:
            return quickSessionCheckpointDraft(
                state.restoreQuickSession(),
                result: state.quickResult
            )
        case .balance:
            return balanceSessionCheckpointDraft(
                state.restoreBalanceSession(),
                result: state.balanceResult
            )
        case .mirror:
            return mirrorSessionCheckpointDraft(
                state.restoreMirrorSession(),
                result: state.mirrorResult
            )
        }
    }

    private func sessionEngineCheckpointDraft(
        _ draft: DecisionSessionCheckpointDraft,
        actionSummary: String
    ) -> DecisionSessionCheckpointDraft {
        sessionEngineCheckpointDraft(
            draft,
            actionSummary: actionSummary,
            eBrainTurn: nil
        )
    }

    private func sessionEngineCheckpointDraft(
        _ draft: DecisionSessionCheckpointDraft,
        actionSummary: String,
        eBrainTurn: BASEBrainTurnResult?
    ) -> DecisionSessionCheckpointDraft {
        var summary = draft.summary
        let fact = "action: \(actionSummary)"
        if !summary.confirmedFacts.contains(fact) {
            summary.confirmedFacts.append(fact)
        }
        guard let eBrainTurn else {
            return DecisionSessionCheckpointDraft(
                summary: summary,
                runtimeState: draft.runtimeState
            )
        }

        return sessionEngineCheckpointDraft(
            DecisionSessionCheckpointDraft(
                summary: summary,
                runtimeState: draft.runtimeState
            ),
            eBrainTurn: eBrainTurn
        )
    }

    private func sessionEngineCheckpointDraft(
        _ draft: DecisionSessionCheckpointDraft,
        eBrainTurn: BASEBrainTurnResult?
    ) -> DecisionSessionCheckpointDraft {
        guard let eBrainTurn else {
            return draft
        }

        let executionCapability = DecisionSessionCheckpointExecutionCapability(
            frame: self.runtimeSnapshot.executionCapabilityFrame
        )

        return eBrainTurn.sessionCheckpointFacts.applied(
            to: draft,
            executionCapability: executionCapability
        )
    }

    private func sessionEngineActionResultSummary(_ actionSummary: String) -> String {
        let trimmedSummary = trimmed(actionSummary)
        guard let first = trimmedSummary.first else {
            return "Recorded session action."
        }
        let remainder = trimmedSummary.dropFirst()
        return String(first).uppercased() + remainder + "."
    }

    private func readSessionEngineBundleData(from sourceURL: URL) throws -> Data {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: sourceURL)
    }

    private func markSessionEngineStepStalled(
        _ stepID: String?,
        errorCode: String
    ) async {
        guard let stepID,
              let sessionEngine = DecisionSessionEngine.shared else {
            return
        }
        _ = try? await sessionEngine.markStepStalled(
            stepId: stepID,
            errorCode: errorCode
        )
    }

    private func sessionEngineCorrectionTargetEvent(
        in events: [DecisionSessionEvent]
    ) -> DecisionSessionEvent? {
        let preferredTypes: Set<DecisionSessionEventType> = [
            .assistantMessage,
            .userMessage,
            .correctionAdded,
            .toolCallFinished,
            .toolCallFailed,
            .toolCallStarted
        ]

        return events.last(where: { preferredTypes.contains($0.type) }) ?? events.last
    }

    private func quickSessionEventText(_ session: QuickCheckSession) -> String {
        let lines = [
            "Scenario: \(session.scenario.title)",
            "Motivation: \(session.motivation?.title ?? "Unspecified")",
            "Expected outcome: \(session.expectedOutcome?.title ?? "Unspecified")",
            "Control level: \(session.controlLevel?.title ?? "Unspecified")",
            "Note: \(trimmed(session.note).isEmpty ? "None" : trimmed(session.note))"
        ]
        return lines.joined(separator: "\n")
    }

    private func balanceSessionEventText(_ session: BalanceBoardSession) -> String {
        let lines = [
            "Prompt: \(trimmed(session.prompt).isEmpty ? "None" : trimmed(session.prompt))",
            "Desire: \(trimmed(session.desire).isEmpty ? "None" : trimmed(session.desire))",
            "Concern: \(trimmed(session.concern).isEmpty ? "None" : trimmed(session.concern))",
            "Constraint: \(trimmed(session.constraint).isEmpty ? "None" : trimmed(session.constraint))",
            "Long term: \(trimmed(session.longTerm).isEmpty ? "None" : trimmed(session.longTerm))"
        ]
        return lines.joined(separator: "\n")
    }

    private func mirrorSessionEventText(_ session: MirrorWorkspaceSession) -> String {
        let lines = [
            "Prompt: \(trimmed(session.prompt).isEmpty ? "None" : trimmed(session.prompt))",
            "Emotion: \(trimmed(session.emotion).isEmpty ? "None" : trimmed(session.emotion))",
            "Relationship: \(trimmed(session.relationship).isEmpty ? "None" : trimmed(session.relationship))",
            "Reality: \(trimmed(session.reality).isEmpty ? "None" : trimmed(session.reality))",
            "Long term: \(trimmed(session.longTerm).isEmpty ? "None" : trimmed(session.longTerm))",
            "Self lens: \(trimmed(session.selfLens).isEmpty ? "None" : trimmed(session.selfLens))"
        ]
        return lines.joined(separator: "\n")
    }

    private func quickSessionResultText(_ result: QuickCheckResult) -> String {
        [
            "Verdict: \(result.verdict.title)",
            "Current perspective: \(result.currentPerspective)",
            "After perspective: \(result.afterPerspective)",
            "Primary action: \(result.primaryAction.title)"
        ].joined(separator: "\n")
    }

    private func balanceSessionResultText(_ result: BalanceBoardResult) -> String {
        [
            "Headline: \(result.headline)",
            "Focus: \(result.focusTitle)",
            "Summary: \(result.summary)",
            "Next action: \(result.nextAction)"
        ].joined(separator: "\n")
    }

    private func mirrorSessionResultText(_ result: MirrorResult) -> String {
        [
            "Headline: \(result.headline)",
            "Core tension: \(result.coreTension)",
            "Next action title: \(result.nextActionTitle)",
            "Next action: \(result.nextAction)"
        ].joined(separator: "\n")
    }

    private func quickSessionCheckpointDraft(
        _ session: QuickCheckSession,
        result: QuickCheckResult?
    ) -> DecisionSessionCheckpointDraft {
        var constraints = ["entry source: \(session.entrySource.rawValue)"]
        if let control = session.controlLevel?.title {
            constraints.append("control level: \(control)")
        }

        var facts = ["scenario: \(session.scenario.title)"]
        if let motivation = session.motivation?.title {
            facts.append("motivation: \(motivation)")
        }
        if let expectedOutcome = session.expectedOutcome?.title {
            facts.append("expected outcome: \(expectedOutcome)")
        }
        if let result {
            facts.append("verdict: \(result.verdict.title)")
        }

        var openTasks: [String] = []
        if let result {
            openTasks.append("Review primary action: \(result.primaryAction.title)")
        } else {
            openTasks.append("Produce a quick recommendation")
        }

        let goalSeed = trimmed(session.note)
        let goal = goalSeed.isEmpty
            ? "Run a quick check for \(session.scenario.title.lowercased())"
            : goalSeed

        return DecisionSessionCheckpointDraft(
            summary: DecisionSessionCheckpointSummary(
                goal: goal,
                acceptedConstraints: constraints,
                confirmedFacts: facts,
                openTasks: openTasks,
                currentScope: ["quick", session.scenario.rawValue]
            ),
            runtimeState: DecisionSessionCheckpointRuntimeState(
                workspacePath: nil,
                branchName: nil,
                activeFiles: [],
                currentMode: .chat
            )
        )
    }

    private func balanceSessionCheckpointDraft(
        _ session: BalanceBoardSession,
        result: BalanceBoardResult?
    ) -> DecisionSessionCheckpointDraft {
        var constraints = ["entry source: \(session.entrySource.rawValue)"]
        let constraintText = trimmed(session.constraint)
        if !constraintText.isEmpty {
            constraints.append("constraint: \(constraintText)")
        }

        var facts: [String] = []
        let desireText = trimmed(session.desire)
        let concernText = trimmed(session.concern)
        let longTermText = trimmed(session.longTerm)
        if !desireText.isEmpty {
            facts.append("desire: \(desireText)")
        }
        if !concernText.isEmpty {
            facts.append("concern: \(concernText)")
        }
        if !longTermText.isEmpty {
            facts.append("long term: \(longTermText)")
        }
        if let result {
            facts.append("focus: \(result.focusTitle)")
        }

        let promptText = trimmed(session.prompt)
        let goal = promptText.isEmpty ? "Work through a balance board" : promptText
        let openTasks = result.map { ["Review next action: \($0.nextAction)"] } ?? ["Compare the trade-off clearly"]

        return DecisionSessionCheckpointDraft(
            summary: DecisionSessionCheckpointSummary(
                goal: goal,
                acceptedConstraints: constraints,
                confirmedFacts: facts,
                openTasks: openTasks,
                currentScope: ["balance"]
            ),
            runtimeState: DecisionSessionCheckpointRuntimeState(
                workspacePath: nil,
                branchName: nil,
                activeFiles: [],
                currentMode: .review
            )
        )
    }

    private func mirrorSessionCheckpointDraft(
        _ session: MirrorWorkspaceSession,
        result: MirrorResult?
    ) -> DecisionSessionCheckpointDraft {
        let constraints = ["entry source: \(session.entrySource.rawValue)"]
        var facts: [String] = []
        let emotionText = trimmed(session.emotion)
        let relationshipText = trimmed(session.relationship)
        let realityText = trimmed(session.reality)
        let longTermText = trimmed(session.longTerm)
        let selfLensText = trimmed(session.selfLens)

        if !emotionText.isEmpty {
            facts.append("emotion: \(emotionText)")
        }
        if !relationshipText.isEmpty {
            facts.append("relationship: \(relationshipText)")
        }
        if !realityText.isEmpty {
            facts.append("reality: \(realityText)")
        }
        if !longTermText.isEmpty {
            facts.append("long term: \(longTermText)")
        }
        if !selfLensText.isEmpty {
            facts.append("self lens: \(selfLensText)")
        }
        if let result {
            facts.append("next action title: \(result.nextActionTitle)")
        }

        let promptText = trimmed(session.prompt)
        let goal = promptText.isEmpty ? "Reflect through a mirror workspace" : promptText
        let openTasks = result.map { ["Review next action: \($0.nextActionTitle)"] } ?? ["Name the core tension clearly"]

        return DecisionSessionCheckpointDraft(
            summary: DecisionSessionCheckpointSummary(
                goal: goal,
                acceptedConstraints: constraints,
                confirmedFacts: facts,
                openTasks: openTasks,
                currentScope: ["mirror"]
            ),
            runtimeState: DecisionSessionCheckpointRuntimeState(
                workspacePath: nil,
                branchName: nil,
                activeFiles: [],
                currentMode: .review
            )
        )
    }

    private func sessionEngineTitle(
        prefix: String,
        seed: String,
        fallback: String
    ) -> String {
        let trimmedSeed = trimmed(seed)
        guard !trimmedSeed.isEmpty else {
            return fallback
        }
        return "\(prefix) - \(String(trimmedSeed.prefix(48)))"
    }

    @MainActor
    private func decisionRuntimeExport(
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        currentBrainOverride: CurrentBrainState? = nil
    ) async -> DecisionTestingRuntimeExport {
        let context = modelContainer.mainContext
        let resolvedRuntimeSnapshot = runtimeSnapshot ?? self.runtimeSnapshot
        let resolvedCurrentBrain = currentBrainOverride ?? currentBrainState
        let sessionEngineSnapshot: DecisionSessionRuntimeSnapshot?
        if let sessionEngine = DecisionSessionEngine.shared {
            sessionEngineSnapshot = try? await sessionEngine.snapshot()
        } else {
            sessionEngineSnapshot = nil
        }
        let pendingSessionEngineImportPreview = pendingSessionEngineImportDraft.map {
            DecisionSessionEnginePendingImportPreview(
                sourceFileName: $0.sourceFileName,
                preview: $0.preview
            )
        }
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
            runtimeSnapshot: resolvedRuntimeSnapshot,
            sessionEngineSnapshot: sessionEngineSnapshot,
            pendingSessionEngineImportPreview: pendingSessionEngineImportPreview,
            activeKillSwitches: activeEvolutionKillSwitches.map(\.rawValue),
            persistedCheckpointLineages: inventory.persistedLineages,
            pendingReviewCheckpoints: controlSurface.pendingReviewQueue,
            activeCheckpointHint: controlSurface.activeCheckpoint,
            activeCheckpointSource: controlSurface.activeCheckpointSource,
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

    private struct ResolvedActiveEvolutionCheckpoint {
        let snapshot: DecisionReviewCheckpointSnapshot?
        let source: DecisionEvolutionActiveCheckpointSource
    }

    @MainActor
    private func evolutionCheckpointInventory(
        in context: ModelContext,
        currentBrain: CurrentBrainState?
    ) -> DecisionEvolutionControlSurfaceInventory {
        let allCheckpoints = evolutionCheckpointSnapshots(in: context)
        let persistedLineages = persistedCheckpointLineages(in: context)
        let pendingReviewQueue = allCheckpoints.filter { $0.approvalState == .reviewSuggested }
        let activeCheckpointResolution = resolveActiveEvolutionCheckpoint(
            currentBrain: currentBrain,
            allSnapshots: allCheckpoints,
            persistedLineages: persistedLineages
        )

        return DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: pendingReviewQueue,
            persistedLineages: persistedLineages,
            activeCheckpoint: activeCheckpointResolution.snapshot,
            activeCheckpointSource: activeCheckpointResolution.source,
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
    ) -> ResolvedActiveEvolutionCheckpoint {
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
    ) -> ResolvedActiveEvolutionCheckpoint {
        if let latestCheckpoint = currentBrain?.evolutionState.latestCheckpoint,
           latestCheckpoint.approvalState == .automatic {
            let persisted = allSnapshots.first(where: { $0.checkpointID == latestCheckpoint.id })

            return ResolvedActiveEvolutionCheckpoint(
                snapshot: DecisionReviewCheckpointSnapshot(
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
                ),
                source: .pinnedHint
            )
        }

        if let latestAutomaticSnapshot = allSnapshots.first(where: { $0.approvalState == .automatic }) {
            return ResolvedActiveEvolutionCheckpoint(
                snapshot: latestAutomaticSnapshot,
                source: .automaticFallback
            )
        }

        if let persistedActiveID = persistedLineages.first(where: { $0.approvalState == .automatic })?.checkpointID,
           let persistedActive = allSnapshots.first(where: { $0.checkpointID == persistedActiveID }) {
            return ResolvedActiveEvolutionCheckpoint(
                snapshot: persistedActive,
                source: .automaticFallback
            )
        }

        return ResolvedActiveEvolutionCheckpoint(
            snapshot: nil,
            source: .none
        )
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
        recordCurrentEBrainReplayTurn(
            eBrainTurn: nil,
            runtimeSnapshot: self.runtimeSnapshot,
            now: now
        )
    }

    @MainActor
    private func recordCurrentEBrainReplayTurn(
        eBrainTurn: BASEBrainTurnResult?,
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        now: Date = .now
    ) {
        if let eBrainTurn {
            _ = recordEBrainTurn(eBrainTurn, persistLineage: true)
            return
        }

        _ = currentLiveEBrainTurn(
            runtimeSnapshot: runtimeSnapshot,
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
        let runtimeContext = resolvedRuntimeContext(runtimeSnapshot: runtimeSnapshot)
        if memoryProjection == nil || isMemoryProjectionDirty {
            refreshDecisionMemoryStore()
        }
        if currentBrainState == nil {
            refreshGlobalBrainState(
                source: .explicitRefresh,
                hostRuntime: runtimeContext.hostRuntime
            )
        }

        guard let turn = BehavioralAISubstrateBridge.eBrainTurn(
            hostRuntime: runtimeContext.hostRuntime,
            activeQuickSession: activeQuickSession,
            activeBalanceSession: activeBalanceSession,
            activeMirrorSession: activeMirrorSession,
            currentBrainState: currentBrainState,
            projection: memoryProjection,
            activeKillSwitches: activeEvolutionKillSwitches,
            runtimeSnapshot: runtimeContext.runtimeSnapshot,
            now: now
        ) else {
            return nil
        }

        return recordEBrainTurn(turn, persistLineage: persistLineage)
    }

    @MainActor
    @discardableResult
    private func recordEBrainTurn(
        _ turn: BASEBrainTurnResult,
        persistLineage: Bool
    ) -> BASEBrainTurnResult {
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

    @MainActor
    private func resolvedRuntimeContext(
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil
    ) -> BeforeAppRuntimeContext {
        let resolvedRuntimeSnapshot = runtimeSnapshot ?? self.runtimeSnapshot
        return BeforeAppRuntimeContext(
            runtimeSnapshot: resolvedRuntimeSnapshot,
            hostRuntime: resolvedRuntimeSnapshot.hostRuntime
        )
    }

    private func refreshGlobalBrainState(
        source: BrainStateUpdateSource,
        hostRuntime: BASHostRuntime? = nil
    ) {
        let resolvedHostRuntime = hostRuntime ?? self.hostRuntime
        resolvedHostRuntime.resolveCurrentBrainProjection(
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
        if let checkpoint = fetchEvolutionCheckpoint(checkpointID: checkpointID, in: context),
           let lineageSummary = checkpoint.lineageSummary {
            let restoredKillSwitches = BASKillSwitchID.resolvePolicyIDs(lineageSummary.activeKillSwitches)
            DecisionEvolutionKillSwitchStore.save(restoredKillSwitches, now: now)
            activeEvolutionKillSwitches = restoredKillSwitches
        }
        isMemoryProjectionDirty = true
        persistActiveWorkspaceState()
        advanceEvolutionControlMutationEpoch()
        return true
    }

    @MainActor
    private func fetchEvolutionCheckpoint(
        checkpointID: String,
        in context: ModelContext
    ) -> DecisionEvolutionCheckpoint? {
        let descriptor = FetchDescriptor<DecisionEvolutionCheckpoint>(
            predicate: #Predicate { checkpoint in
                checkpoint.id == checkpointID
            }
        )
        return try? context.fetch(descriptor).first
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
        refreshWidgetSurfaces()
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
