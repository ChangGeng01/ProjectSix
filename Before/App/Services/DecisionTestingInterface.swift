import Foundation

struct DecisionTestingRuntimeSnapshot: Equatable, Sendable {
    let preferences: BeforePreferences
    let testingStubProfile: DecisionTestingStubProfile?
    let runtimeStatus: DecisionModelRuntimeStatus
    let foundationStatus: DecisionModelProviderStatus
    let gemmaProviderStatus: DecisionModelProviderStatus
    let gemmaBundleStatus: GemmaModelBundleStatus
    let gemmaRuntimeStatus: GemmaLocalRuntimeStatus
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

    var isEmpty: Bool {
        intelligenceMode == nil && preferredProvider == nil && allowFallbacks == nil && stubProfile == nil
    }
}

enum DecisionTestingInterface {
    enum EnvironmentKey {
        static let intelligenceMode = "BEFORE_TEST_INTELLIGENCE_MODE"
        static let preferredProvider = "BEFORE_TEST_MODEL_PROVIDER"
        static let allowFallbacks = "BEFORE_TEST_ALLOW_FALLBACKS"
        static let stubProfile = "BEFORE_TEST_MODEL_STUB_PROFILE"
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
                .flatMap(DecisionTestingStubProfile.init(rawValue:))
        )

        return override.isEmpty ? nil : override
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
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DecisionTestingRuntimeSnapshot {
        let stubProfile = environmentOverride(environment: environment)?.stubProfile
        return DecisionTestingRuntimeSnapshot(
            preferences: preferences,
            testingStubProfile: stubProfile,
            runtimeStatus: DecisionIntelligenceCoordinator.runtimeStatus(
                preferences: preferences,
                testingStubProfile: stubProfile
            ),
            foundationStatus: FoundationModelsIntelligenceService.availabilityStatus,
            gemmaProviderStatus: GemmaE4BIntelligenceService.availabilityStatus,
            gemmaBundleStatus: GemmaE4BIntelligenceService.modelBundleStatus,
            gemmaRuntimeStatus: GemmaE4BIntelligenceService.localRuntimeStatus
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

    @MainActor
    static func resetTransientIntelligenceState(store: DecisionIntelligenceDebugStore = .shared) async {
        clearTraces(store: store)
        await clearResponseCache()
    }

    @MainActor
    static func recentReplay(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace]? = nil,
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        let resolvedTraces = traces ?? DecisionIntelligenceDebugStore.shared.traces
        return DeveloperDecisionReplayBuilder.build(
            quick: quick,
            balance: balance,
            mirror: mirror,
            traces: resolvedTraces,
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
