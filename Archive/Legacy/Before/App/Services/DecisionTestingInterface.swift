import Foundation
import SwiftData
import BASHostKit

struct DecisionTestingRuntimeSnapshot: Equatable, Sendable {
    let preferences: BeforePreferences
    let testingStubProfile: DecisionTestingStubProfile?
    let executionProfile: DecisionIntelligenceExecutionProfile
    let runtimePolicyResolution: BeforeRuntimePolicyResolution
    let activeTaskGraph: DecisionTaskGraphSnapshot?
    let inferenceBackendPolicy: InferenceBackendPolicy
    let deviceCapabilities: DeviceCapabilitySnapshot
    let gemmaBackendResolution: InferenceBackendResolution
    let runtimeStatus: DecisionModelRuntimeStatus
    let foundationStatus: DecisionModelProviderStatus
    let gemmaProviderStatus: DecisionModelProviderStatus
    let openModelProviderStatus: DecisionModelProviderStatus
    let openModelRuntimeStatus: OpenModelLocalRuntimeStatus?
    let gemmaBundleStatus: GemmaModelBundleStatus
    let gemmaRuntimeStatus: GemmaLocalRuntimeStatus
    let registeredProviders: [DecisionModelProviderDescriptor]
    let localModelLibrary: DecisionLocalModelLibrarySnapshot

    var runtimePolicyLineage: BeforeRuntimePolicyLineage {
        runtimePolicyResolution.lineage
    }

    var runtimePolicyIssues: [BeforeRuntimePolicyIssue] {
        runtimePolicyResolution.issues
    }

    var hostRuntime: BASHostRuntime {
        BeforeProductCompatibility.makeHostRuntime(
            runtimePolicyResolution: runtimePolicyResolution,
            vitalMonitor: DecisionTestingRuntimeSnapshotVitalMonitor(snapshot: self)
        )
    }

    var executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame {
        DecisionEBrainExecutionCapabilityFrame.build(
            runtimeSnapshot: self,
            registeredProviders: registeredProviders
        )
    }
}

private struct DecisionTestingRuntimeSnapshotVitalMonitor: BASVitalMonitorServicing {
    let snapshot: DecisionTestingRuntimeSnapshot

    func currentDeviceState(now: Date) -> BASDeviceState {
        let capabilities = snapshot.deviceCapabilities
        let memoryFreeMB = max(1_024, capabilities.physicalMemoryGB * 768)
        let batteryLevel = capabilities.isLowPowerModeEnabled ? 0.24 : 0.76
        let networkState: BASNetworkState =
            snapshot.preferences.onDeviceIntelligenceMode.isEnabled ? .constrained : .online

        let gpuLoad: Double
        switch snapshot.gemmaBackendResolution.effectiveBackend {
        case .metal:
            gpuLoad = 0.34
        case .coreML, .systemManaged:
            gpuLoad = 0.14
        case .cpu:
            gpuLoad = 0.06
        }

        let cpuLoad: Double
        switch snapshot.executionProfile.tier {
        case .off, .simulator, .conservativeDeterministic:
            cpuLoad = 0.12
        case .balancedGemma, .fullGemma, .systemManaged, .testingOverride:
            cpuLoad = 0.20
        }

        let latencyBudgetMs: Int
        switch snapshot.executionProfile.adaptationMatrix.runtimeGear {
        case .low:
            latencyBudgetMs = 1_200
        case .balanced:
            latencyBudgetMs = 1_500
        case .high:
            latencyBudgetMs = 1_800
        }

        return BASDeviceState(
            batteryLevel: batteryLevel,
            thermalLevel: thermalLevel(
                isLowPowerModeEnabled: capabilities.isLowPowerModeEnabled
            ),
            memoryFreeMB: memoryFreeMB,
            networkState: networkState,
            foregroundState: .foreground,
            cpuLoad: cpuLoad,
            gpuLoad: gpuLoad,
            npuAvailable: capabilities.supportsCoreMLAcceleration,
            latencyBudgetMs: latencyBudgetMs
        )
    }

    private func thermalLevel(
        isLowPowerModeEnabled: Bool
    ) -> BASThermalLevel {
        let processThermal = ProcessInfo.processInfo.thermalState
        switch processThermal {
        case .nominal:
            return isLowPowerModeEnabled ? .warm : .nominal
        case .fair:
            return .warm
        case .serious:
            return .hot
        case .critical:
            return .critical
        @unknown default:
            return isLowPowerModeEnabled ? .warm : .nominal
        }
    }
}

struct DecisionTestingLaunchOptions: Equatable, Sendable {
    var skipOnboarding = false
    var cleanLaunch = false

    var isEmpty: Bool {
        !skipOnboarding && !cleanLaunch
    }
}

struct DecisionTestingEnvironmentOverride: Equatable, Sendable {
    var intelligenceMode: OnDeviceIntelligenceMode?
    var preferredProvider: DecisionModelProviderPreference?
    var allowFallbacks: Bool?
    var stubProfile: DecisionTestingStubProfile?
    var inferenceBackendPolicy: InferenceBackendPolicy?

    var isEmpty: Bool {
        intelligenceMode == nil &&
            preferredProvider == nil &&
            allowFallbacks == nil &&
            stubProfile == nil &&
            inferenceBackendPolicy == nil
    }
}

enum DecisionTestingInterface {
    enum EnvironmentKey {
        static let intelligenceMode = "BEFORE_TEST_INTELLIGENCE_MODE"
        static let preferredProvider = "BEFORE_TEST_MODEL_PROVIDER"
        static let allowFallbacks = "BEFORE_TEST_ALLOW_FALLBACKS"
        static let stubProfile = "BEFORE_TEST_MODEL_STUB_PROFILE"
        static let inferenceBackend = "BEFORE_TEST_INFERENCE_BACKEND"
        static let skipOnboarding = "BEFORE_TEST_SKIP_ONBOARDING"
        static let cleanLaunch = "BEFORE_TEST_CLEAN_LAUNCH"
    }

    static func configuredPreferences(
        from base: BeforePreferences = .default,
        intelligenceMode: OnDeviceIntelligenceMode? = nil,
        preferredProvider: DecisionModelProviderPreference? = nil,
        allowFallbacks: Bool? = nil
    ) -> BeforePreferences {
        var updated = base
        if let intelligenceMode {
            updated.onDeviceIntelligenceMode = intelligenceMode
        }
        if let preferredProvider {
            updated.preferredIntelligenceProvider = preferredProvider
        }
        if let allowFallbacks {
            updated.allowModelFallbacks = allowFallbacks
        }
        return updated
    }

    static func launchEnvironment(
        intelligenceMode: OnDeviceIntelligenceMode? = nil,
        preferredProvider: DecisionModelProviderPreference? = nil,
        allowFallbacks: Bool? = nil,
        stubProfile: DecisionTestingStubProfile? = nil,
        inferenceBackendPolicy: InferenceBackendPolicy? = nil,
        skipOnboarding: Bool = false,
        cleanLaunch: Bool = false
    ) -> [String: String] {
        var environment: [String: String] = [:]
        if let intelligenceMode {
            environment[EnvironmentKey.intelligenceMode] = intelligenceMode.rawValue
        }
        if let preferredProvider {
            environment[EnvironmentKey.preferredProvider] = preferredProvider.rawValue
        }
        if let allowFallbacks {
            environment[EnvironmentKey.allowFallbacks] = allowFallbacks ? "1" : "0"
        }
        if let stubProfile {
            environment[EnvironmentKey.stubProfile] = stubProfile.rawValue
        }
        if let inferenceBackendPolicy {
            environment[EnvironmentKey.inferenceBackend] = inferenceBackendPolicy.rawValue
        }
        if skipOnboarding {
            environment[EnvironmentKey.skipOnboarding] = "1"
        }
        if cleanLaunch {
            environment[EnvironmentKey.cleanLaunch] = "1"
        }
        return environment
    }

    static func launchOptions(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DecisionTestingLaunchOptions {
        DecisionTestingLaunchOptions(
            skipOnboarding: environment[EnvironmentKey.skipOnboarding].flatMap(parseBoolOverride(_:)) ?? false,
            cleanLaunch: environment[EnvironmentKey.cleanLaunch].flatMap(parseBoolOverride(_:)) ?? false
        )
    }

    static func environmentOverride(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DecisionTestingEnvironmentOverride? {
        let override = DecisionTestingEnvironmentOverride(
            intelligenceMode: environment[EnvironmentKey.intelligenceMode]
                .flatMap(OnDeviceIntelligenceMode.init(rawValue:)),
            preferredProvider: environment[EnvironmentKey.preferredProvider]
                .flatMap(DecisionModelProviderPreference.init(rawValue:)),
            allowFallbacks: environment[EnvironmentKey.allowFallbacks]
                .flatMap(parseBoolOverride(_:)),
            stubProfile: environment[EnvironmentKey.stubProfile]
                .flatMap(DecisionTestingStubProfile.init(rawValue:)),
            inferenceBackendPolicy: environment[EnvironmentKey.inferenceBackend]
                .flatMap(InferenceBackendPolicy.init(rawValue:))
        )

        return override.isEmpty ? nil : override
    }

    static func effectiveInferenceBackendPolicy(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> InferenceBackendPolicy {
        environmentOverride(environment: environment)?.inferenceBackendPolicy ?? .auto
    }

    static func runtimeTestingContextDetected() -> Bool {
        NSClassFromString("XCTestCase") != nil
    }

    static func effectivePreferences(
        stored: BeforePreferences = BeforePreferencesStore.load(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> BeforePreferences {
        guard let override = environmentOverride(environment: environment) else {
            return stored
        }

        return configuredPreferences(
            from: stored,
            intelligenceMode: override.intelligenceMode,
            preferredProvider: override.preferredProvider,
            allowFallbacks: override.allowFallbacks
        )
    }

    static func persistPreferences(_ preferences: BeforePreferences) {
        BeforePreferencesStore.save(preferences)
    }

    static func runtimeSnapshot(
        preferences: BeforePreferences = effectivePreferences(),
        runtimePolicyResolution: BeforeRuntimePolicyResolution? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DecisionTestingRuntimeSnapshot {
        let override = environmentOverride(environment: environment)
        let stubProfile = override?.stubProfile
        let backendPolicy = override?.inferenceBackendPolicy ?? .auto
        let deviceCapabilities = DeviceCapabilitySnapshot.current
        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: preferences.preferredOpenModelAssetID
        )
        let registry = DecisionIntelligenceProviderRegistry.shared
        let registeredProviders = registry.descriptors()
        let openModelProviderStatus = registry.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Unavailable",
            detail: "No open-model runtime is registered."
        )
        let foundationStatus = FoundationModelsIntelligenceService.availabilityStatus
        let gemmaProviderStatus = GemmaE4BIntelligenceService.availabilityStatus
        let resolvedRuntimePolicyResolution =
            runtimePolicyResolution ?? BeforeProductCompatibility.resolvedRuntimePolicy
        let runtimeCoordination = DecisionIntelligenceCoordinator.runtimeCoordination(
            preferences: preferences,
            testingStubProfile: stubProfile,
            device: deviceCapabilities,
            runtimePolicyResolution: resolvedRuntimePolicyResolution,
            openModelStatus: openModelProviderStatus,
            gemmaStatus: gemmaProviderStatus,
            foundationStatus: foundationStatus
        )
        let localModelLibrary = DecisionLocalModelLibrarySnapshot.current(
            preferredProvider: preferences.preferredIntelligenceProvider,
            preferredGemmaAssetID: preferences.preferredGemmaAssetID,
            preferredGemmaAsset: GemmaE4BIntelligenceService.preferredModel(
                preferredAssetID: preferences.preferredGemmaAssetID
            ),
            importedGemmaAssets: GemmaE4BIntelligenceService.importedModels,
            bundledGemmaAsset: GemmaE4BIntelligenceService.bundledModel,
            preferredOpenModelAssetID: preferences.preferredOpenModelAssetID,
            preferredOpenModelAsset: OpenModelAssetCatalog.preferredAsset(
                preferredAssetID: preferences.preferredOpenModelAssetID
            ),
            importedOpenModelAssets: OpenModelAssetCatalog.importedAssets(),
            openModelDescriptor: registry.descriptor(for: .openModel)
        )
        let gemmaBackendResolution = GemmaE4BIntelligenceService.backendResolution(
            policy: backendPolicy,
            device: deviceCapabilities
        )
        return DecisionTestingRuntimeSnapshot(
            preferences: preferences,
            testingStubProfile: stubProfile,
            executionProfile: runtimeCoordination.executionProfile,
            runtimePolicyResolution: resolvedRuntimePolicyResolution,
            activeTaskGraph: preferences.restoreInProgressWorkspaces ? DecisionTaskGraphStore.load() : nil,
            inferenceBackendPolicy: backendPolicy,
            deviceCapabilities: deviceCapabilities,
            gemmaBackendResolution: gemmaBackendResolution,
            runtimeStatus: runtimeCoordination.runtimeStatus,
            foundationStatus: foundationStatus,
            gemmaProviderStatus: gemmaProviderStatus,
            openModelProviderStatus: openModelProviderStatus,
            openModelRuntimeStatus: localModelLibrary.openModelRuntimeStatus,
            gemmaBundleStatus: GemmaE4BIntelligenceService.modelBundleStatus,
            gemmaRuntimeStatus: GemmaE4BIntelligenceService.localRuntimeStatus,
            registeredProviders: registeredProviders,
            localModelLibrary: localModelLibrary
        )
    }

    @MainActor
    static func recentTraces(
        limit: Int = BeforePolicy.Settings.developerTraceLimit
    ) -> [DecisionIntelligenceTrace] {
        recentTraces(limit: limit, store: DecisionIntelligenceDebugStore.shared)
    }

    @MainActor
    static func recentTraces(
        limit: Int = BeforePolicy.Settings.developerTraceLimit,
        store: DecisionIntelligenceDebugStore
    ) -> [DecisionIntelligenceTrace] {
        Array(store.traces.prefix(limit))
    }

    @MainActor
    static func clearTraces() {
        clearTraces(store: DecisionIntelligenceDebugStore.shared)
    }

    @MainActor
    static func clearTraces(store: DecisionIntelligenceDebugStore) {
        store.clear()
    }

    static func clearResponseCache() async {
        await DecisionIntelligenceResponseCache.shared.clear()
    }

    static func intelligenceTelemetrySnapshot(
        store: DecisionIntelligenceTelemetryStore = .shared
    ) async -> DecisionIntelligenceTelemetrySnapshot {
        await store.snapshot()
    }

    static func cacheTelemetrySnapshot(
        cache: DecisionIntelligenceResponseCache = .shared
    ) async -> DecisionIntelligenceCacheTelemetrySnapshot {
        await cache.telemetrySnapshot()
    }

    static func circuitBreakerSnapshot(
        breaker: DecisionIntelligenceCircuitBreaker = .shared
    ) async -> DecisionIntelligenceCircuitBreakerSnapshot {
        await breaker.snapshot()
    }

    static func registeredProviderDescriptors(
        registry: DecisionIntelligenceProviderRegistry = .shared
    ) -> [DecisionModelProviderDescriptor] {
        registry.descriptors()
    }

    @MainActor
    static func runtimeExport(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        preferences: BeforePreferences = effectivePreferences(),
        runtimeSnapshot: DecisionTestingRuntimeSnapshot? = nil,
        sessionEngineSnapshot: DecisionSessionRuntimeSnapshot? = nil,
        pendingSessionEngineImportPreview: DecisionSessionEnginePendingImportPreview? = nil,
        activeKillSwitches: [String] = [],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        traceLimit: Int = BeforePolicy.Settings.developerTraceLimit,
        replayLimit: Int = BeforePolicy.Settings.developerReplayLimit,
        persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot] = [],
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot] = [],
        activeCheckpointHint: DecisionReviewCheckpointSnapshot? = nil,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource = .none,
        restorableCheckpointIDs: Set<String> = [],
        debugStore: DecisionIntelligenceDebugStore = .shared,
        eBrainStore: EBrainTurnDebugStore = .shared,
        telemetryStore: DecisionIntelligenceTelemetryStore = .shared,
        cache: DecisionIntelligenceResponseCache = .shared,
        circuitBreaker: DecisionIntelligenceCircuitBreaker = .shared,
        registry: DecisionIntelligenceProviderRegistry = .shared
    ) async -> DecisionTestingRuntimeExport {
        let snapshot = runtimeSnapshot ?? self.runtimeSnapshot(
            preferences: preferences,
            environment: environment
        )
        let traces = recentTraces(limit: traceLimit, store: debugStore)
        let replay = recentReplay(
            quick: quick,
            balance: balance,
            mirror: mirror,
            traces: traces,
            eBrainTurns: eBrainStore.turns,
            persistedCheckpointLineages: persistedCheckpointLineages,
            limit: replayLimit
        )

        return DecisionTestingRuntimeExport(
            generatedAt: .now,
            runtimeSnapshot: snapshot,
            sessionEngineSnapshot: sessionEngineSnapshot,
            pendingSessionEngineImportPreview: pendingSessionEngineImportPreview,
            registeredProviders: registry.descriptors(),
            intelligenceTelemetry: await telemetryStore.snapshot(),
            cacheTelemetry: await cache.telemetrySnapshot(),
            circuitBreakerSnapshot: await circuitBreaker.snapshot(),
            recentTraces: traces,
            recentReplay: replay,
            persistedCheckpointLineages: persistedCheckpointLineages,
            pendingReviewCheckpoints: pendingReviewCheckpoints,
            activeCheckpointHint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            restorableCheckpointIDs: restorableCheckpointIDs,
            activeKillSwitches: activeKillSwitches,
            eBrainTurn: nil
        )
    }

    @MainActor
    static func resetTransientIntelligenceState(
        store: DecisionIntelligenceDebugStore = .shared,
        eBrainStore: EBrainTurnDebugStore = .shared,
        telemetryStore: DecisionIntelligenceTelemetryStore = .shared,
        circuitBreaker: DecisionIntelligenceCircuitBreaker = .shared
    ) async {
        clearTraces(store: store)
        eBrainStore.clear()
        await telemetryStore.clear()
        await clearResponseCache()
        await circuitBreaker.clear()
    }

    @MainActor
    static func recentReplay(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace]? = nil,
        eBrainTurns: [BASEBrainTurnResult]? = nil,
        persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot] = [],
        eBrainStore: EBrainTurnDebugStore = .shared,
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        let resolvedTraces = traces ?? DecisionIntelligenceDebugStore.shared.traces
        let resolvedTurns = eBrainTurns ?? eBrainStore.turns
        return DeveloperDecisionReplayBuilder.build(
            quick: quick,
            balance: balance,
            mirror: mirror,
            traces: resolvedTraces,
            eBrainTurns: resolvedTurns,
            persistedLineages: persistedCheckpointLineages,
            limit: limit
        )
    }

    private static func parseBoolOverride(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            true
        case "0", "false", "no", "off":
            false
        default:
            nil
        }
    }
}
