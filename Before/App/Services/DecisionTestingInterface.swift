import Foundation

struct DecisionTestingRuntimeSnapshot: Equatable, Sendable {
    let preferences: BeforePreferences
    let runtimeStatus: DecisionModelRuntimeStatus
    let foundationStatus: DecisionModelProviderStatus
    let gemmaProviderStatus: DecisionModelProviderStatus
    let gemmaBundleStatus: GemmaModelBundleStatus
    let gemmaRuntimeStatus: GemmaLocalRuntimeStatus
}

@MainActor
enum DecisionTestingInterface {
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

    static func persistPreferences(_ preferences: BeforePreferences) {
        BeforePreferencesStore.save(preferences)
    }

    static func runtimeSnapshot(
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> DecisionTestingRuntimeSnapshot {
        DecisionTestingRuntimeSnapshot(
            preferences: preferences,
            runtimeStatus: DecisionIntelligenceCoordinator.runtimeStatus(preferences: preferences),
            foundationStatus: FoundationModelsIntelligenceService.availabilityStatus,
            gemmaProviderStatus: GemmaE4BIntelligenceService.availabilityStatus,
            gemmaBundleStatus: GemmaE4BIntelligenceService.modelBundleStatus,
            gemmaRuntimeStatus: GemmaE4BIntelligenceService.localRuntimeStatus
        )
    }

    static func recentTraces(
        limit: Int = BeforePolicy.Settings.developerTraceLimit,
        store: DecisionIntelligenceDebugStore = .shared
    ) -> [DecisionIntelligenceTrace] {
        Array(store.traces.prefix(limit))
    }

    static func clearTraces(store: DecisionIntelligenceDebugStore = .shared) {
        store.clear()
    }

    static func recentReplay(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace]? = nil,
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        DeveloperDecisionReplayBuilder.build(
            quick: quick,
            balance: balance,
            mirror: mirror,
            traces: traces ?? DecisionIntelligenceDebugStore.shared.traces,
            limit: limit
        )
    }
}
