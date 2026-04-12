import Foundation
import SwiftData
import Testing
import BASHostKit
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
        DecisionTaskGraphStore.clear()
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
        #expect(snapshot.activeTaskGraph == nil)
        #expect(snapshot.inferenceBackendPolicy == .auto)
        #expect(snapshot.gemmaBackendResolution.policy == .auto)
        #expect(snapshot.runtimeStatus == DecisionIntelligenceCoordinator.runtimeStatus(
            preferences: preferences,
            testingStubProfile: nil,
            device: snapshot.deviceCapabilities
        ))
        #expect(snapshot.runtimeStatus.active == .template)
        #expect(snapshot.executionProfile.adaptationMatrix.runtimeGear == .low)
        #expect(snapshot.executionProfile.strategy(for: .quick).preferredProvider == .template)
        #expect(snapshot.executionProfile.strategy(for: .reminder).outputMode == .deterministicTemplate)
    }

    @Test
    func runtimeSnapshotIncludesPersistedTaskGraph() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        if let snapshot = DecisionTaskGraphSnapshot.capture(from: session) {
            DecisionTaskGraphStore.save(snapshot)
        }
        defer { DecisionTaskGraphStore.clear() }

        let runtimeSnapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: .default,
            environment: [:]
        )

        #expect(runtimeSnapshot.activeTaskGraph?.mode == .quick)
        #expect(runtimeSnapshot.activeTaskGraph?.tasks.count == 4)
    }

    @Test
    func runtimeSnapshotHidesPersistedTaskGraphWhenWorkspaceRestoreIsDisabled() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        if let snapshot = DecisionTaskGraphSnapshot.capture(from: session) {
            DecisionTaskGraphStore.save(snapshot)
        }
        defer { DecisionTaskGraphStore.clear() }

        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: false,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .template,
            allowModelFallbacks: true
        )

        let runtimeSnapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            environment: [:]
        )

        #expect(runtimeSnapshot.activeTaskGraph == nil)
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
        let breaker = DecisionIntelligenceCircuitBreaker()
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
        await breaker.record(provider: .foundationModels, event: .providerFailure)
        await breaker.record(provider: .foundationModels, event: .providerFailure)
        await breaker.record(provider: .foundationModels, event: .providerFailure)

        await DecisionTestingInterface.resetTransientIntelligenceState(
            store: store,
            telemetryStore: telemetryStore,
            circuitBreaker: breaker
        )

        #expect(store.traces.isEmpty)
        #expect(await telemetryStore.snapshot().totalRequests == 0)
        #expect(await breaker.snapshot().totalTripCount == 0)
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
        #expect(telemetrySnapshot.selectionKnowledgeNeedRate == 0)
        #expect(telemetrySnapshot.selectionControlOnlyRate == 0)
        #expect(telemetrySnapshot.selectionRetrievalBypassRate == 0)
        #expect(cacheSnapshot.hitCountByKind[.reminder] == 1)
        #expect(cacheSnapshot.storeCountByKind[.reminder] == 1)
        #expect(cacheSnapshot.totalRejectedStores == 0)
        #expect(cacheSnapshot.totalQuarantinedHits == 0)
    }

    @Test
    func runtimeExportBundlesSnapshotTelemetryTracesAndReplay() async {
        let debugStore = DecisionIntelligenceDebugStore()
        let telemetryStore = DecisionIntelligenceTelemetryStore()
        let cache = DecisionIntelligenceResponseCache(limit: 2)
        let breaker = DecisionIntelligenceCircuitBreaker()

        let quickTrace = DecisionIntelligenceTrace(
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            frontstageState: DecisionFrontstageState(
                focusGoal: "Interrupt the automatic reaction before it locks in.",
                activeStateSignalCount: 2,
                openTextSignalCount: 1,
                dangerSignals: ["Urgency", "Evidence filtered"],
                evidenceHeadlines: ["Current perspective: Quick relief."],
                anchorHeadlines: ["Quick note"],
                memoryHeadlines: ["Short, direct language lands better."],
                retainedEvidenceCount: 2,
                droppedEvidenceCount: 1,
                droppedInjectedEvidenceCount: 1,
                droppedDuplicateEvidenceCount: 0,
                droppedBudgetEvidenceCount: 0,
                suppressionHints: ["long_explanation"],
                sessionBiases: ["Keep the language short and concrete."]
            ),
            contextState: DecisionContextPreparedState(
                rebuiltSession: true,
                generation: 4,
                anchorFields: [.quickNote],
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
            brainState: DecisionBrainState(
                profileCore: ["Short, direct language lands better."],
                activeGoals: ["Sleep before midnight"],
                relevantMemories: ["Putting it into Tomorrow Box often breaks the loop."],
                sessionBiases: ["Keep the language short and concrete."],
                retrievalTags: ["quick", "buy", "night"],
                reactionWeights: DecisionReactionWeights(
                    briefLanguage: 0.92,
                    warmDirectTone: 0.71,
                    lowCognitiveLoad: 0.83,
                    interruptiveActionBias: 0.94,
                    boundaryNamingBias: 0.28,
                    tradeoffClarityBias: 0.33
                ),
                identityProfile: BeforeProductLanguage.identityProfile(for: .quick),
                memoryGovernance: DecisionMemoryGovernanceState(
                    totalRecordCount: 6,
                    totalCandidateCount: 3,
                    pendingCandidateCount: 1,
                    promotedCandidateCount: 2,
                    loadedPromotedMemoryCount: 3,
                    loadedPendingMemoryCount: 1,
                    loadedReasonCounts: [
                        .goalOverride: 1,
                        .defaultAllowed: 2,
                        .pendingTagOverlap: 1
                    ],
                    screenedOutReasonCounts: [
                        .confidenceNoOverlap: 1
                    ]
                ),
                loadedAt: .now
            ),
            runtimeStrategy: DecisionAdaptiveTaskStrategy(
                kind: .quick,
                entropy: .low,
                runtimeGear: .low,
                preferredProvider: .gemmaE4B,
                contextBudget: 220,
                retrievalMode: .off,
                thinkingMode: .off,
                outputMode: .guidedShort,
                tone: .briefWarm,
                actionSpace: ["encourage", "next_step", "fallback_to_template"],
                responseLanguage: .english,
                allowsModelInvocation: true
            ),
            semanticPromptFingerprint: "semantic-quick-1",
            stablePrefixFingerprint: "prefix-quick-1",
            consistencyCheck: BASConsistencyCheckResult(violations: []),
            consistencyRejected: false,
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
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)

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
            cache: cache,
            circuitBreaker: breaker
        )

        #expect(export.runtimeSnapshot.runtimeStatus.preferred == .gemmaE4B)
        #expect(export.intelligenceTelemetry.totalRequests == 1)
        #expect(export.cacheTelemetry.storeCountByKind[.quick] == 1)
        #expect(export.summary.totalCacheRejectedStores == 0)
        #expect(export.summary.totalCacheQuarantinedHits == 0)
        #expect(export.recentTraces.count == 1)
        #expect(export.recentReplay.count == 1)
        #expect(export.summary.activeProvider == export.runtimeSnapshot.runtimeStatus.active)
        #expect(export.summary.runtimeGear == export.runtimeSnapshot.executionProfile.adaptationMatrix.runtimeGear)
        #expect(export.summary.environmentClass == export.runtimeSnapshot.executionProfile.adaptationMatrix.environmentClass)
        #expect(export.summary.deviceClass == export.runtimeSnapshot.executionProfile.adaptationMatrix.deviceClass)
        #expect(export.summary.runtimeGearByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).runtimeGear)
        #expect(export.summary.contextBudgetByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).contextBudget)
        #expect(export.summary.outputCharacterBudgetByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).outputCharacterBudget)
        #expect(export.summary.timeBudgetMsByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).timeBudgetMs)
        #expect(export.summary.toolCallBudgetByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).toolCallBudget)
        #expect(export.summary.retrievalItemBudgetByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).retrievalItemBudget)
        #expect(export.summary.taskEntropyByKind[.mirror] == .high)
        #expect(export.summary.retrievalModeByKind[.mirror] == export.runtimeSnapshot.executionProfile.strategy(for: .mirror).retrievalMode)
        #expect(export.summary.outputModeByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).outputMode)
        #expect(export.summary.allowsModelInvocationByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).allowsModelInvocation)
        #expect(export.summary.actionSpaceByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).actionSpace)
        #expect(export.summary.responseLanguageByKind[.quick] == export.runtimeSnapshot.executionProfile.strategy(for: .quick).responseLanguage)
        #expect(export.summary.effectivePreferredProviderByKind[.quick] == .gemmaE4B)
        #expect(export.summary.effectiveRuntimeGearByKind[.quick] == .low)
        #expect(export.summary.effectiveContextBudgetByKind[.quick] == 220)
        #expect(export.summary.effectiveOutputCharacterBudgetByKind[.quick] == 180)
        #expect(export.summary.effectiveTimeBudgetMsByKind[.quick] == 500)
        #expect(export.summary.effectiveToolCallBudgetByKind[.quick] == 1)
        #expect(export.summary.effectiveRetrievalItemBudgetByKind[.quick] == 0)
        #expect(export.summary.effectiveRetrievalModeByKind[.quick] == .off)
        #expect(export.summary.effectiveThinkingModeByKind[.quick] == .off)
        #expect(export.summary.effectiveOutputModeByKind[.quick] == .guidedShort)
        #expect(export.summary.effectiveToneByKind[.quick] == .briefWarm)
        #expect(export.summary.effectiveActionSpaceByKind[.quick] == ["encourage", "next_step", "fallback_to_template"])
        #expect(export.summary.effectiveResponseLanguageByKind[.quick] == .english)
        #expect(export.summary.firstAttemptedProviderByKind[.quick] == .gemmaE4B)
        #expect(export.summary.effectiveProviderOrderByKind[.quick] == [.gemmaE4B])
        #expect(export.summary.totalRequests == 1)
        #expect(export.summary.totalCacheEntries == 1)
        #expect(export.summary.dominantGemmaBackend == .cpu)
        #expect(export.summary.registeredProviderCount >= 3)
        #expect(export.summary.registeredOpenModelProviderCount >= 2)
        #expect(export.registeredProviders.contains(where: { $0.kind == .openModel }))
        #expect(export.circuitBreakerSnapshot.activeProviders == [.gemmaE4B])
        #expect(export.summary.circuitOpenProviderCount == 1)
        #expect(export.summary.activeCircuitProviders == [.gemmaE4B])
        #expect(export.summary.circuitTripCount == 1)
        #expect(export.summary.circuitTripCountByProvider[.gemmaE4B] == 1)
        #expect(export.summary.circuitTripCountByReason[.repeatedProviderFailure] == 1)
        #expect(export.summary.consistencyCheckedTraceCount == 1)
        #expect(export.summary.consistencyRejectedTraceCount == 0)
        #expect(export.summary.consistencyCheckCoverageRate == 1)
        #expect(export.summary.consistencyRejectRate == 0)
        #expect(export.summary.consistencyRejectedCountByKind[.quick] == nil)
        #expect(export.summary.consistencyViolationCounts.isEmpty)
        #expect(export.summary.admissionSkipRate == 0)
        #expect(export.summary.providerBypassRate == 0)
        #expect(abs((export.summary.providerBypassRateByKind[.quick] ?? 0) - 0) < 0.0001)
        #expect(export.summary.lowPressureModelCallRate == 1)
        #expect(export.summary.lowPressureModelCallRateByKind[.quick] == 1)
        #expect(export.summary.avoidableModelCallRate == 0)
        #expect(export.summary.avoidableModelCallRateByKind[.quick] == 0)
        #expect(export.summary.selectionRequestCount == 0)
        #expect(export.summary.selectionKnowledgeNeedRate == 0)
        #expect(export.summary.selectionControlOnlyRate == 0)
        #expect(export.summary.selectionRetrievalBypassRate == 0)
        #expect(export.summary.averageRequestDurationMs == 220)
        #expect(export.summary.averageRequestDurationMsByKind[.quick] == 220)
        #expect(export.summary.averageRequestDurationMsByGemmaBackend[.cpu] == 220)
        #expect(export.summary.averagePromptCharactersByKind[.quick] == 480)
        #expect(export.summary.averageImmutablePrefixCharactersByKind[.quick] == 180)
        #expect(export.summary.averageAdaptivePrefixCharactersByKind[.quick] == 0)
        #expect(export.summary.semanticPromptVariantCountByKind[.quick] == 1)
        #expect(export.summary.semanticPromptReuseRateByKind[.quick] == 0)
        #expect(export.summary.stablePrefixVariantCountByKind[.quick] == 1)
        #expect(export.summary.stablePrefixReuseRateByKind[.quick] == 0)
        #expect(export.summary.stablePrefixPollutionRateByKind[.quick] == 0)
        #expect(export.summary.slowRequestRate == 0)
        #expect(export.summary.slowRequestRateByKind[.quick] == 0)
        #expect(export.summary.overTimeBudgetRate == 0)
        #expect(export.summary.overTimeBudgetRateByKind[.quick] == 0)
        #expect(export.lifecycleSummary.contextAwareTraceCount == 1)
        #expect(export.lifecycleSummary.rebuildCount == 1)
        #expect(export.lifecycleSummary.retainedEvidenceCount == 2)
        #expect(export.lifecycleSummary.droppedEvidenceCount == 1)
        #expect(export.lifecycleSummary.droppedEvidenceCountByKind[.quick] == 1)
        #expect(export.lifecycleSummary.droppedInjectedEvidenceCount == 1)
        #expect(export.lifecycleSummary.droppedInjectedEvidenceCountByKind[.quick] == 1)
        #expect(export.lifecycleSummary.droppedDuplicateEvidenceCount == 0)
        #expect(export.lifecycleSummary.droppedBudgetEvidenceCount == 0)
        #expect(export.lifecycleSummary.averageRetainedEvidenceCountByKind[.quick] == 2)
        #expect(export.lifecycleSummary.averageAnchorFieldCountByKind[.quick] == 1)
        #expect(export.lifecycleSummary.latestGenerationByKind[.quick] == 4)
        #expect(export.summary.contextAwareTraceCount == 1)
        #expect(export.summary.lifecycleRebuildCount == 1)
        #expect(export.summary.staleFieldDropCount == 0)
        #expect(export.summary.retainedEvidenceCount == 2)
        #expect(export.summary.evidenceRetentionRatio == 2.0 / 3.0)
        #expect(export.summary.droppedEvidenceCount == 1)
        #expect(export.summary.droppedInjectedEvidenceCount == 1)
        #expect(export.summary.droppedDuplicateEvidenceCount == 0)
        #expect(export.summary.droppedBudgetEvidenceCount == 0)
        #expect(abs(export.summary.evidencePollutionRate - (1.0 / 3.0)) < 0.0001)
        #expect(abs((export.summary.evidencePollutionRateByKind[.quick] ?? 0) - (1.0 / 3.0)) < 0.0001)
        #expect(export.summary.duplicateEvidenceDropRate == 0)
        #expect(export.summary.duplicateEvidenceDropRateByKind[.quick] == 0)
        #expect(export.summary.budgetTrimRate == 0)
        #expect(export.summary.budgetTrimRateByKind[.quick] == 0)
        #expect(export.neuralSummary.neuralTraceCount == 1)
        #expect(export.neuralSummary.suppressedBehaviorCount == 1)
        #expect(export.neuralSummary.dominantActionByKind[.quick] == .waitBuffer)
        #expect(export.neuralSummary.strongestSignalByKind[.quick] == .urgency)
        #expect(export.summary.neuralTraceCount == 1)
        #expect(export.summary.suppressedBehaviorCount == 1)
        #expect(export.brainSummary.brainTraceCount == 1)
        #expect(export.brainSummary.dominantReactionWeightByKind[.quick] == .interruptiveActionBias)
        #expect(export.brainSummary.averageProfileCoreCountByKind[.quick] == 1)
        #expect(export.brainSummary.averageActiveGoalCountByKind[.quick] == 1)
        #expect(export.brainSummary.averageRelevantMemoryCountByKind[.quick] == 1)
        #expect(export.brainSummary.averageLoadedPromotedMemoryCountByKind[.quick] == 3)
        #expect(export.brainSummary.averageLoadedPendingMemoryCountByKind[.quick] == 1)
        #expect(export.brainSummary.averagePendingCandidateCountByKind[.quick] == 1)
        #expect(export.brainSummary.averagePromotedRecordCountByKind[.quick] == 6)
        #expect(export.brainSummary.loadedEligibilityReasonCountsByKind[.quick]?[.goalOverride] == 1)
        #expect(export.brainSummary.screenedOutEligibilityReasonCountsByKind[.quick]?[.confidenceNoOverlap] == 1)
        #expect(export.brainSummary.pendingMemoryLoadRateByKind[.quick] == 0.25)
        #expect((export.brainSummary.latestSnapshotFingerprintByKind[.quick] ?? "").isEmpty == false)
        #expect(export.brainSummary.snapshotVariantCountByKind[.quick] == 1)
        #expect(export.brainSummary.lowTrustMemoryLoadRateByKind[.quick] == 0)
        #expect(export.brainSummary.identityRoleByKind[.quick] == .pauseCompanion)
        #expect(export.brainSummary.boundaryModeByKind[.quick] == .localOnlyAdvisory)
        #expect(export.brainSummary.boundaryConstraintCountsByKind[.quick]?[.lockSensitiveMemory] == 1)
        #expect(export.brainSummary.calibrationStatusByKind[.quick] == .stable)
        #expect(export.brainSummary.calibrationAlertCountsByKind[.quick]?.isEmpty == true)
        #expect(export.brainSummary.evolutionCheckpointCountByKind[.quick] == 0)
        #expect(export.brainSummary.evolutionPendingReviewCountByKind[.quick] == 0)
        #expect(export.brainSummary.evolutionRollbackReadyByKind[.quick] == false)
        #expect(export.summary.brainTraceCount == 1)
        #expect(export.summary.dominantReactionWeightByKind[.quick] == .interruptiveActionBias)
        #expect(export.summary.loadedEligibilityReasonCountsByKind[.quick]?[.goalOverride] == 1)
        #expect(export.summary.screenedOutEligibilityReasonCountsByKind[.quick]?[.confidenceNoOverlap] == 1)
        #expect(export.summary.pendingMemoryLoadRateByKind[.quick] == 0.25)
        #expect((export.summary.brainSnapshotFingerprintByKind[.quick] ?? "").isEmpty == false)
        #expect(export.summary.brainSnapshotVariantCountByKind[.quick] == 1)
        #expect(export.summary.lowTrustMemoryLoadRateByKind[.quick] == 0)
        #expect(export.summary.identityRoleByKind[.quick] == .pauseCompanion)
        #expect(export.summary.boundaryModeByKind[.quick] == .localOnlyAdvisory)
        #expect(export.summary.boundaryConstraintCountsByKind[.quick]?[.lockSensitiveMemory] == 1)
        #expect(export.summary.calibrationStatusByKind[.quick] == .stable)
        #expect(export.summary.calibrationAlertCountsByKind[.quick]?.isEmpty == true)
        #expect(export.summary.evolutionCheckpointCountByKind[.quick] == 0)
        #expect(export.summary.evolutionPendingReviewCountByKind[.quick] == 0)
        #expect(export.summary.evolutionRollbackReadyByKind[.quick] == false)
        #expect(export.flightDeck.layerReports.count == DecisionSystemLayer.allCases.count)
        #expect(export.flightDeck.overallScore > 0)
        #expect(export.flightDeck.isPureLocalClosedLoop == true)
        #expect(export.flightDeck.layerReports.contains(where: { $0.layer == .runtime }))
        #expect(export.flightDeck.layerReports.contains(where: { $0.layer == .delivery }))
        #expect(export.flightDeck.layerReports.contains(where: { $0.layer == .safety }))
        #expect(export.flightDeck.layerReports.contains(where: { $0.layer == .evaluation }))
        #expect(
            export.flightDeck.layerReports.first(where: { $0.layer == .observability })?.signals.contains(where: {
                $0.contains("Consistency checked")
            }) == true
        )
        #expect(
            export.flightDeck.layerReports.first(where: { $0.layer == .data })?.signals.contains(where: {
                $0.contains("Replay entries")
            }) == true
        )
    }

    @Test
    func runtimeExportFlightDeckSurfacesConsistencyRejectionSignal() async {
        let debugStore = DecisionIntelligenceDebugStore()
        debugStore.record(
            DecisionIntelligenceTrace(
                kind: .quick,
                preferredProvider: .gemmaE4B,
                activeProvider: .gemmaE4B,
                attemptedProviders: [.gemmaE4B],
                allowFallbacks: true,
                usedFallback: false,
                consistencyCheck: BASConsistencyCheckResult(
                    violations: [
                        BASConsistencyViolation(
                            kind: .forbiddenAction,
                            message: "Action render_local_guidance is forbidden in the current truth state."
                        )
                    ]
                ),
                consistencyRejected: true,
                prompt: "Prompt",
                outputPreview: "Output",
                detail: "Rejected by consistency harness"
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: debugStore,
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let safetyReport = export.flightDeck.layerReports.first(where: { $0.layer == .safety })
        let observabilityReport = export.flightDeck.layerReports.first(where: { $0.layer == .observability })

        #expect(export.summary.consistencyCheckedTraceCount == 1)
        #expect(export.summary.consistencyRejectedTraceCount == 1)
        #expect(export.summary.consistencyRejectRate == 1)
        #expect(export.summary.consistencyViolationCounts[.forbiddenAction] == 1)
        #expect(safetyReport?.signals.contains(where: { $0.contains("Consistency rejected: 1") }) == true)
        #expect(safetyReport?.blockers.contains(where: { $0.contains("forbidden actions") }) == true)
        #expect(observabilityReport?.signals.contains(where: { $0.contains("Consistency checked: 1") }) == true)
    }

    @Test
    func persistenceBootstrapFallsBackToRecoveredPersistentStore() throws {
        let expectedContainer = try makePersistenceContainer()
        var attemptedModes: [PersistenceBootstrap.LoadMode] = []
        var quarantined = false

        let bootstrap = PersistenceBootstrap.loadAppContainer(
            createContainer: { mode in
                attemptedModes.append(mode)
                switch mode {
                case .persistent:
                    throw CocoaError(.fileReadCorruptFile)
                case .recoveredPersistent:
                    return expectedContainer
                case .temporaryPersistent, .inMemoryRecovery, .unavailable:
                    throw CocoaError(.fileNoSuchFile)
                }
            },
            quarantinePrimaryStore: {
                quarantined = true
            }
        )

        #expect(quarantined == true)
        #expect(attemptedModes == [.persistent, .recoveredPersistent])
        #expect(bootstrap.container === expectedContainer)
        #expect(bootstrap.loadMode == .recoveredPersistent)
        #expect(bootstrap.recoveryMessage?.contains("clean local store") == true)
    }

    @Test
    func persistenceBootstrapFallsBackToInMemoryRecoveryAfterStorageFailures() throws {
        let expectedContainer = try makePersistenceContainer()
        var attemptedModes: [PersistenceBootstrap.LoadMode] = []

        let bootstrap = PersistenceBootstrap.loadAppContainer(
            createContainer: { mode in
                attemptedModes.append(mode)
                switch mode {
                case .persistent, .recoveredPersistent, .temporaryPersistent, .unavailable:
                    throw CocoaError(.fileReadCorruptFile)
                case .inMemoryRecovery:
                    return expectedContainer
                }
            },
            quarantinePrimaryStore: {}
        )

        #expect(attemptedModes == [.persistent, .recoveredPersistent, .temporaryPersistent, .inMemoryRecovery])
        #expect(bootstrap.container === expectedContainer)
        #expect(bootstrap.loadMode == .inMemoryRecovery)
        #expect(bootstrap.recoveryMessage?.contains("temporary recovery mode") == true)
    }

    @Test
    func persistenceBootstrapCanSurfaceUnavailableRecoveryState() {
        let bootstrap = PersistenceBootstrap.loadAppContainer(
            createContainer: { _ in
                throw CocoaError(.fileReadCorruptFile)
            },
            quarantinePrimaryStore: {}
        )

        #expect(bootstrap.container == nil)
        #expect(bootstrap.loadMode == .unavailable)
        #expect(bootstrap.recoveryMessage?.contains("could not start its local storage runtime") == true)
    }

    private func makePersistenceContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: CheckEvent.self,
            SelfReminder.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            TomorrowBoxItem.self,
            configurations: configuration
        )
    }
}
