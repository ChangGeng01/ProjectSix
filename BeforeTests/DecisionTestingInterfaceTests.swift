import Foundation
import Testing
@testable import Before

@MainActor
struct DecisionTestingInterfaceTests {
    @Test
    func configuredPreferencesOnlyTouchesModelControls() {
        let base = BeforePreferences(
            homePromptAction: .mirror,
            quickBufferDuration: .tenMinutes,
            restoreInProgressWorkspaces: false,
            showReviewInsights: false,
            onDeviceIntelligenceMode: .off,
            preferredIntelligenceProvider: .template,
            allowModelFallbacks: false
        )

        let configured = DecisionTestingInterface.configuredPreferences(
            from: base,
            intelligenceMode: .assistive,
            preferredProvider: .foundationModels,
            allowFallbacks: true
        )

        #expect(configured.homePromptAction == .mirror)
        #expect(configured.quickBufferDuration == .tenMinutes)
        #expect(configured.restoreInProgressWorkspaces == false)
        #expect(configured.showReviewInsights == false)
        #expect(configured.onDeviceIntelligenceMode == .assistive)
        #expect(configured.preferredIntelligenceProvider == .foundationModels)
        #expect(configured.allowModelFallbacks == true)
    }

    @Test
    func runtimeSnapshotUsesSameCoordinatorStatus() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .template,
            allowModelFallbacks: true
        )

        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            environment: [:]
        )

        #expect(snapshot.preferences == preferences)
        #expect(snapshot.testingStubProfile == nil)
        #expect(snapshot.inferenceBackendPolicy == .auto)
        #expect(snapshot.gemmaBackendResolution.policy == .auto)
        #expect(snapshot.runtimeStatus == DecisionIntelligenceCoordinator.runtimeStatus(
            preferences: preferences,
            testingStubProfile: nil
        ))
        #expect(snapshot.runtimeStatus.active == .template)
    }

    @Test
    func launchEnvironmentUsesStableTestingKeys() {
        let environment = DecisionTestingInterface.launchEnvironment(
            intelligenceMode: .assistive,
            preferredProvider: .gemmaE4B,
            allowFallbacks: false,
            stubProfile: .smoke,
            inferenceBackendPolicy: .cpuOnly,
            skipOnboarding: true,
            cleanLaunch: true
        )

        #expect(environment[DecisionTestingInterface.EnvironmentKey.intelligenceMode] == "assistive")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.preferredProvider] == "gemmaE4B")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.allowFallbacks] == "0")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.stubProfile] == "smoke")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.inferenceBackend] == "cpuOnly")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.skipOnboarding] == "1")
        #expect(environment[DecisionTestingInterface.EnvironmentKey.cleanLaunch] == "1")
    }

    @Test
    func effectivePreferencesAppliesEnvironmentOverrideWithoutChangingOtherFields() {
        let stored = BeforePreferences(
            homePromptAction: .mirror,
            quickBufferDuration: .fiveMinutes,
            restoreInProgressWorkspaces: false,
            showReviewInsights: false,
            onDeviceIntelligenceMode: .off,
            preferredIntelligenceProvider: .template,
            allowModelFallbacks: false
        )
        let environment = DecisionTestingInterface.launchEnvironment(
            intelligenceMode: .assistive,
            preferredProvider: .foundationModels,
            allowFallbacks: true
        )

        let effective = DecisionTestingInterface.effectivePreferences(
            stored: stored,
            environment: environment
        )

        #expect(effective.homePromptAction == .mirror)
        #expect(effective.quickBufferDuration == .fiveMinutes)
        #expect(effective.restoreInProgressWorkspaces == false)
        #expect(effective.showReviewInsights == false)
        #expect(effective.onDeviceIntelligenceMode == .assistive)
        #expect(effective.preferredIntelligenceProvider == .foundationModels)
        #expect(effective.allowModelFallbacks == true)
    }

    @Test
    func environmentOverrideParsesTestingStubProfile() {
        let environment = DecisionTestingInterface.launchEnvironment(
            intelligenceMode: .assistive,
            preferredProvider: .gemmaE4B,
            allowFallbacks: true,
            stubProfile: .smoke,
            inferenceBackendPolicy: .metalPreferred
        )

        let override = DecisionTestingInterface.environmentOverride(environment: environment)

        #expect(override?.stubProfile == .smoke)
        #expect(override?.inferenceBackendPolicy == .metalPreferred)
    }

    @Test
    func effectiveInferenceBackendPolicyDefaultsToAuto() {
        #expect(DecisionTestingInterface.effectiveInferenceBackendPolicy(environment: [:]) == .auto)
    }

    @Test
    func effectiveInferenceBackendPolicyUsesEnvironmentOverride() {
        let environment = DecisionTestingInterface.launchEnvironment(
            inferenceBackendPolicy: .coreMLPreferred
        )

        #expect(
            DecisionTestingInterface.effectiveInferenceBackendPolicy(environment: environment) == .coreMLPreferred
        )
    }

    @Test
    func launchOptionsParseStableTestingFlags() {
        let environment = DecisionTestingInterface.launchEnvironment(
            stubProfile: .smoke,
            skipOnboarding: true,
            cleanLaunch: true
        )

        let options = DecisionTestingInterface.launchOptions(environment: environment)

        #expect(options.skipOnboarding == true)
        #expect(options.cleanLaunch == true)
    }

    @Test
    func recentTracesAndClearWorkWithInjectedStore() {
        let store = DecisionIntelligenceDebugStore()
        store.record(
            DecisionIntelligenceTrace(
                kind: .quick,
                preferredProvider: .gemmaE4B,
                activeProvider: .gemmaE4B,
                attemptedProviders: [.gemmaE4B],
                allowFallbacks: true,
                usedFallback: false,
                prompt: "Newest",
                outputPreview: "Output",
                detail: "Detail"
            )
        )
        store.record(
            DecisionIntelligenceTrace(
                kind: .balance,
                preferredProvider: .foundationModels,
                activeProvider: .foundationModels,
                attemptedProviders: [.foundationModels],
                allowFallbacks: false,
                usedFallback: false,
                prompt: "Older",
                outputPreview: "Output",
                detail: "Detail"
            )
        )

        let traces = DecisionTestingInterface.recentTraces(limit: 1, store: store)
        #expect(traces.count == 1)
        #expect(traces.first?.prompt == "Older")

        DecisionTestingInterface.clearTraces(store: store)
        #expect(store.traces.isEmpty)
    }

    @Test
    func resetTransientIntelligenceStateClearsTraceAndResponseCache() async {
        let store = DecisionIntelligenceDebugStore()
        store.record(
            DecisionIntelligenceTrace(
                kind: .quick,
                preferredProvider: .gemmaE4B,
                activeProvider: .gemmaE4B,
                attemptedProviders: [.gemmaE4B],
                allowFallbacks: true,
                usedFallback: false,
                prompt: "Prompt",
                outputPreview: "Output",
                detail: "Detail"
            )
        )

        await DecisionIntelligenceResponseCache.shared.storeReminder(
            ReminderSelectionCandidate(id: UUID(), content: "Reminder"),
            for: "cache-key"
        )

        await DecisionTestingInterface.resetTransientIntelligenceState(store: store)

        #expect(store.traces.isEmpty)
        let cached = await DecisionIntelligenceResponseCache.shared.reminder(for: "cache-key")
        #expect(cached == nil)
    }
}
