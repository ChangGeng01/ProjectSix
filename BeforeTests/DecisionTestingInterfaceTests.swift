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
        #expect(snapshot.executionProfile.effectiveProviderPreference == .template)
        #expect(snapshot.inferenceBackendPolicy == .auto)
        #expect(snapshot.gemmaBackendResolution.policy == .auto)
        #expect(snapshot.runtimeStatus == DecisionIntelligenceCoordinator.runtimeStatus(
            preferences: preferences,
            testingStubProfile: nil,
            device: snapshot.deviceCapabilities
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
        let telemetryStore = DecisionIntelligenceTelemetryStore()
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
        await telemetryStore.record(
            kind: .quick,
            outcome: .providerSuccess,
            activeProvider: .foundationModels,
            attemptedProviders: [.foundationModels],
            usedFallback: false,
            durationMs: 90
        )

        await DecisionTestingInterface.resetTransientIntelligenceState(
            store: store,
            telemetryStore: telemetryStore
        )

        #expect(store.traces.isEmpty)
        #expect(await telemetryStore.snapshot().totalRequests == 0)
        let cached = await DecisionIntelligenceResponseCache.shared.reminder(for: "cache-key")
        #expect(cached == nil)
    }

    @Test
    func telemetrySnapshotsExposePipelineAndCacheState() async {
        let telemetryStore = DecisionIntelligenceTelemetryStore()
        await telemetryStore.record(
            kind: .balance,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            durationMs: 180,
            promptBudget: DecisionIntelligencePromptContract.ContextBudget(
                targetCharacters: 1_000,
                prefixCharacters: 200,
                suffixCharacters: 320
            ),
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: true,
                pressure: .elevated,
                reason: "Allowed for testing.",
                skipReason: nil
            ),
            gemmaBackendResolution: InferenceBackendResolver.resolve(
                policy: .cpuOnly,
                device: DeviceCapabilitySnapshot(
                    isSimulator: true,
                    supportsMetal: true,
                    supportsCoreMLAcceleration: false
                )
            )
        )

        let cache = DecisionIntelligenceResponseCache(limit: 2)
        await cache.storeReminder(
            ReminderSelectionCandidate(id: UUID(), content: "Reminder"),
            for: "cache-key"
        )
        _ = await cache.reminder(for: "cache-key")

        let telemetrySnapshot = await DecisionTestingInterface.intelligenceTelemetrySnapshot(
            store: telemetryStore
        )
        let cacheSnapshot = await DecisionTestingInterface.cacheTelemetrySnapshot(cache: cache)

        #expect(telemetrySnapshot.totalRequests == 1)
        #expect(telemetrySnapshot.activeProviderCount[.gemmaE4B] == 1)
        #expect(telemetrySnapshot.gemmaBackendCount[.cpu] == 1)
        #expect(telemetrySnapshot.averageRequestDurationMs == 180)
        #expect(telemetrySnapshot.slowRequestRate == 0)
        #expect(telemetrySnapshot.averagePromptCharactersByKind[.balance] == 520)
        #expect(telemetrySnapshot.averagePrefixCharactersByKind[.balance] == 200)
        #expect(telemetrySnapshot.averageImmutablePrefixCharactersByKind[.balance] == 200)
        #expect(telemetrySnapshot.averageAdaptivePrefixCharactersByKind[.balance] == 0)
        #expect(telemetrySnapshot.averageSuffixCharactersByKind[.balance] == 320)
        #expect(abs((telemetrySnapshot.averageStablePrefixShareByKind[.balance] ?? 0) - (200.0 / 520.0)) < 0.0001)
        #expect(telemetrySnapshot.admissionSkipRate == 0)
        #expect(telemetrySnapshot.providerBypassRate == 0)
        #expect(telemetrySnapshot.lowPressureModelCallRate == 0)
        #expect(cacheSnapshot.hitCountByKind[.reminder] == 1)
        #expect(cacheSnapshot.storeCountByKind[.reminder] == 1)
    }

    @Test
    func runtimeExportBundlesSnapshotTelemetryTracesAndReplay() async {
        let debugStore = DecisionIntelligenceDebugStore()
        let telemetryStore = DecisionIntelligenceTelemetryStore()
        let cache = DecisionIntelligenceResponseCache(limit: 2)

        let quickTrace = DecisionIntelligenceTrace(
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            contextState: DecisionContextPreparedState(
                rebuiltSession: true,
                generation: 4,
                activeFields: [.quickNote],
                staleFields: []
            ),
            neuralState: DecisionNeuralState(
                mode: .quick,
                dominantActivations: [
                    DecisionActivation(signal: .urgency, strength: 0.88)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .waitBuffer, score: 0.88)
                ],
                suppressedBehaviors: ["long_explanation"],
                detail: "Quick neural routing is active."
            ),
            prompt: "Quick prompt",
            outputPreview: "Quick output",
            detail: "Quick detail"
        )
        debugStore.record(quickTrace)

        await telemetryStore.record(
            kind: .quick,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            durationMs: 220,
            promptBudget: DecisionIntelligencePromptContract.ContextBudget(
                targetCharacters: 1_200,
                prefixCharacters: 180,
                suffixCharacters: 300
            ),
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: true,
                pressure: .low,
                reason: "Allowed for testing.",
                skipReason: nil
            ),
            gemmaBackendResolution: InferenceBackendResolver.resolve(
                policy: .cpuOnly,
                device: DeviceCapabilitySnapshot(
                    isSimulator: true,
                    supportsMetal: true,
                    supportsCoreMLAcceleration: false
                )
            )
        )
        await cache.storeQuickResult(
            QuickCheckResult(
                currentPerspective: "Current",
                afterPerspective: "After",
                verdict: .pause,
                primaryAction: .wait90s,
                secondaryActions: []
            ),
            for: "quick"
        )

        let event = CheckEvent(
            createdAt: .now,
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "note",
            currentPerspective: "Current",
            afterPerspective: "After",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [event],
            balance: [],
            mirror: [],
            preferences: .default,
            environment: DecisionTestingInterface.launchEnvironment(
                preferredProvider: .gemmaE4B,
                inferenceBackendPolicy: .cpuOnly
            ),
            traceLimit: 4,
            replayLimit: 4,
            debugStore: debugStore,
            telemetryStore: telemetryStore,
            cache: cache
        )

        #expect(export.runtimeSnapshot.runtimeStatus.preferred == .gemmaE4B)
        #expect(export.intelligenceTelemetry.totalRequests == 1)
        #expect(export.cacheTelemetry.storeCountByKind[.quick] == 1)
        #expect(export.recentTraces.count == 1)
        #expect(export.recentReplay.count == 1)
        #expect(export.summary.activeProvider == export.runtimeSnapshot.runtimeStatus.active)
        #expect(export.summary.totalRequests == 1)
        #expect(export.summary.totalCacheEntries == 1)
        #expect(export.summary.dominantGemmaBackend == .cpu)
        #expect(export.summary.admissionSkipRate == 0)
        #expect(export.summary.providerBypassRate == 0)
        #expect(abs((export.summary.providerBypassRateByKind[.quick] ?? 0) - 0) < 0.0001)
        #expect(export.summary.lowPressureModelCallRate == 1)
        #expect(export.summary.lowPressureModelCallRateByKind[.quick] == 1)
        #expect(export.summary.averageRequestDurationMs == 220)
        #expect(export.summary.averageRequestDurationMsByKind[.quick] == 220)
        #expect(export.summary.averageRequestDurationMsByGemmaBackend[.cpu] == 220)
        #expect(export.summary.averagePromptCharactersByKind[.quick] == 480)
        #expect(export.summary.averageImmutablePrefixCharactersByKind[.quick] == 180)
        #expect(export.summary.averageAdaptivePrefixCharactersByKind[.quick] == 0)
        #expect(export.summary.slowRequestRate == 0)
        #expect(export.summary.slowRequestRateByKind[.quick] == 0)
        #expect(export.lifecycleSummary.contextAwareTraceCount == 1)
        #expect(export.lifecycleSummary.rebuildCount == 1)
        #expect(export.lifecycleSummary.latestGenerationByKind[.quick] == 4)
        #expect(export.summary.contextAwareTraceCount == 1)
        #expect(export.summary.lifecycleRebuildCount == 1)
        #expect(export.summary.staleFieldDropCount == 0)
        #expect(export.neuralSummary.neuralTraceCount == 1)
        #expect(export.neuralSummary.suppressedBehaviorCount == 1)
        #expect(export.neuralSummary.dominantActionByKind[.quick] == .waitBuffer)
        #expect(export.neuralSummary.strongestSignalByKind[.quick] == .urgency)
        #expect(export.summary.neuralTraceCount == 1)
        #expect(export.summary.suppressedBehaviorCount == 1)
    }
}
