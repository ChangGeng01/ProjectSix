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

        let snapshot = DecisionTestingInterface.runtimeSnapshot(preferences: preferences)

        #expect(snapshot.preferences == preferences)
        #expect(snapshot.runtimeStatus == DecisionIntelligenceCoordinator.runtimeStatus(preferences: preferences))
        #expect(snapshot.runtimeStatus.active == .template)
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
}
