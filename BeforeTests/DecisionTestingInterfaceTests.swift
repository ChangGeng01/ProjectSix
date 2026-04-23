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
    func runtimeSnapshotCarriesExecutionCapabilityFrameAlignedWithProfileAndStatus() {
        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: .default,
            environment: [:]
        )

        #expect(snapshot.executionCapabilityFrame.executionTier == snapshot.executionProfile.tier)
        #expect(snapshot.executionCapabilityFrame.activeProvider == snapshot.runtimeStatus.active)
        #expect(snapshot.executionCapabilityFrame.preferredProvider == snapshot.executionProfile.effectiveProviderPreference)
        #expect(snapshot.executionCapabilityFrame.fallbackProvider == snapshot.runtimeStatus.fallback)
    }

    @Test
    func runtimeSnapshotHostRuntimeUsesSnapshotVitalMonitor() throws {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .foundationModels,
            allowModelFallbacks: true
        )
        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            environment: [:]
        )

        let result = try snapshot.hostRuntime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Use the snapshot-bound vital monitor.",
                title: "Snapshot vitals",
                riskLevel: .low
            )
        )
        let turn = try #require(result.eBrainTurn)
        let expectedBattery = snapshot.deviceCapabilities.isLowPowerModeEnabled ? 0.24 : 0.76
        let expectedMemoryFreeMB = max(1_024, snapshot.deviceCapabilities.physicalMemoryGB * 768)

        #expect(turn.deviceState.batteryLevel == expectedBattery)
        #expect(turn.deviceState.memoryFreeMB == expectedMemoryFreeMB)
        #expect(turn.deviceState.npuAvailable == snapshot.deviceCapabilities.supportsCoreMLAcceleration)
        #expect(turn.deviceState.networkState == .constrained)
    }

    @Test
    func runtimeSnapshotExecutionCapabilityFrameExposesFoundationPostureAndBoundary() {
        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: .default,
            environment: [:]
        )

        #expect(snapshot.executionCapabilityFrame.foundationPosture == .trustedProduction)
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.priorID == "worldPriorFabric")
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.posture == .trustedProduction)
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.boundaryID == "externalTraining")
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.hostIsolationID == "hostIsolated")
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.sessionIsolationID == "sessionIsolated")
        #expect(snapshot.executionCapabilityFrame.worldPriorContract.toolTruthModeID == "toolRefreshRequired")
        #expect(snapshot.executionCapabilityFrame.stabilityTier == .invariant)
        #expect(snapshot.executionCapabilityFrame.evidenceGradient == .grounded)
        #expect(snapshot.executionCapabilityFrame.temporalKnowledgeContract.tier == .invariant)
        #expect(snapshot.executionCapabilityFrame.temporalKnowledgeContract.refreshRequirement == .embedded)
        #expect(snapshot.executionCapabilityFrame.temporalKnowledgeContract.decayPolicy == .none)
        #expect(snapshot.executionCapabilityFrame.temporalKnowledgeContract.timeScope == .crossSession)
        #expect(snapshot.executionCapabilityFrame.evidenceContract.gradient == .grounded)
        #expect(snapshot.executionCapabilityFrame.evidenceContract.claimType == .worldStructure)
        #expect(snapshot.executionCapabilityFrame.evidenceContract.requiresCaveat == false)
        #expect(snapshot.executionCapabilityFrame.evidenceContract.requiresExternalRefresh == false)
        #expect(snapshot.executionCapabilityFrame.repositoryBoundaryID == "externalTraining")
        #expect(snapshot.executionCapabilityFrame.hostIsolationID == "hostIsolated")
        #expect(snapshot.executionCapabilityFrame.sessionIsolationID == "sessionIsolated")
        #expect(snapshot.executionCapabilityFrame.toolTruthModeID == "toolRefreshRequired")
        #expect(
            snapshot.executionCapabilityFrame.horizonLine
                == "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        )
        #expect(
            snapshot.executionCapabilityFrame.temporalLine
                == "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
        )
        #expect(
            snapshot.executionCapabilityFrame.evidenceLine
                == "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
        )
    }

    @Test
    func horizonPersistencePolicyFollowsExecutionCapabilityContracts() {
        let stableFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .foundationModels,
            preferredProvider: .foundationModels,
            fallbackProvider: .gemmaE4B,
            providerTrack: .builtInSystem,
            executionTier: .systemManaged,
            foundationTier: .systemManaged,
            reasonCodes: []
        )
        let volatileFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelHeuristic,
            reasonCodes: []
        )

        let stablePolicy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: stableFrame
        )
        let volatilePolicy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: volatileFrame
        )

        #expect(stablePolicy.volatileClaimWriteMode == .admitDirectly)
        #expect(stablePolicy.contaminatedWriteMode == .quarantineCandidate)
        #expect(volatilePolicy.volatileClaimWriteMode == .stageCandidate)
        #expect(volatilePolicy.contaminatedWriteMode == .quarantineCandidate)
    }

    @Test
    func runtimeSnapshotIncludesOpenModelStatusAndRegisteredProviders() {
        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: .default,
            environment: [:]
        )

        #expect(snapshot.openModelProviderStatus.kind == .openModel)
        #expect(snapshot.openModelProviderStatus.title == "Waiting for import")
        #expect(snapshot.openModelProviderStatus.detail.contains("Import or download a compatible local model"))
        #expect(snapshot.openModelRuntimeStatus == nil)
        #expect(snapshot.registeredProviders.contains(where: { $0.kind == .foundationModels }))
        #expect(snapshot.registeredProviders.contains(where: { $0.kind == .gemmaE4B }))
        #expect(snapshot.registeredProviders.contains(where: { $0.kind == .openModel }))
        #expect(snapshot.localModelLibrary.openModelSlot?.stableID != nil)
        #expect(snapshot.localModelLibrary.openModelRuntimeStatus == nil)
        #expect(snapshot.localModelLibrary.preferredProvider == .foundationModels)
    }

    @Test
    func flightDeckSurfaceHelpersPreferSharedSummaryLines() {
        let blockerReport = DecisionSystemLayerReport(
            layer: .runtime,
            score: 61,
            health: .watch,
            headline: "Runtime is watchful",
            signals: ["Session Engine folded_lung • Sessions 2 • Active 1 • Stalled 1"],
            blockers: ["Guardrail review is blocking writes"]
        )
        #expect(blockerReport.surfaceSummaryLine == "Blocker: Guardrail review is blocking writes")
        #expect(blockerReport.surfaceSummaryUsesHealthTint == true)

        let signalReport = DecisionSystemLayerReport(
            layer: .data,
            score: 84,
            health: .strong,
            headline: "Data is steady",
            signals: ["Branches 3 • Merge-ready sessions 1 • Merge-ready branches 2"],
            blockers: []
        )
        #expect(signalReport.surfaceSummaryLine == "Branches 3 • Merge-ready sessions 1 • Merge-ready branches 2")
        #expect(signalReport.surfaceSummaryUsesHealthTint == false)

        let runtimeSnapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: .default,
            environment: [:]
        )
        let localModelSummary = DecisionSystemLocalModelLibrarySummary.summary(
            from: runtimeSnapshot.localModelLibrary
        )
        #expect(localModelSummary.overviewLine == localModelSummary.headline)
    }

    @Test
    func runtimeSnapshotAndExportReflectImportedPreferredOpenModelAsset() async throws {
        let sourceURL = try makeTemporaryOpenModelFile(named: "mistral-\(UUID().uuidString).gguf")
        let imported = try OpenModelAssetCatalog.importModel(from: sourceURL)
        defer { try? OpenModelAssetCatalog.removeImportedModel(named: imported.fileName) }

        var preferences = BeforePreferences.default
        preferences.preferredOpenModelAssetID = imported.assetID

        let snapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            environment: [:]
        )

        #expect(snapshot.localModelLibrary.preferredOpenModelAsset?.assetID == imported.assetID)
        #expect(snapshot.openModelRuntimeStatus?.mode == .heuristicPreview)
        #expect(snapshot.localModelLibrary.openModelRuntimeAssetFileName == imported.fileName)
        #expect(snapshot.openModelProviderStatus.detail.contains("local heuristic adapter"))
        #expect(snapshot.registeredProviders.contains(where: {
            $0.kind == .openModel &&
            $0.openModel?.stableID == imported.generatedStableID &&
            $0.detail.contains("local heuristic adapter")
        }))

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: preferences,
            sessionEngineSnapshot: nil,
            debugStore: DecisionIntelligenceDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.runtimeSnapshot.localModelLibrary.preferredOpenModelAsset?.assetID == imported.assetID)
        #expect(export.runtimeSnapshot.openModelProviderStatus.detail.contains("local heuristic adapter"))
        #expect(export.runtimeSnapshot.openModelRuntimeStatus?.title == "Heuristic preview")
        #expect(export.flightDeck.localModelLibrarySummary?.openModelRuntimeTitle == "Heuristic preview")
        #expect(export.flightDeck.localModelLibrarySummary?.openModelRuntimeAssetFileName == imported.fileName)
        #expect(export.flightDeck.localModelLibrarySummary?.signals.contains(where: { $0.contains(imported.fileName) }) == true)
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

        #expect(export.runtimeSnapshot.runtimeStatus.preferred == .foundationModels)
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
    func runtimeExportAttachesSessionEngineSnapshotToFlightDeck() async throws {
        let sessionEngineSnapshot = DecisionSessionRuntimeSnapshot(
            layerPlacement: .foldedLung,
            sessions: 2,
            activeSessions: 1,
            stalledSessions: 1,
            mergeReadySessions: 1,
            mergeableBranches: 1,
            branches: 3,
            checkpoints: 5,
            events: 34,
            steps: 4,
            recentSessions: [
                DecisionSessionRuntimeInspectionSession(
                    sessionID: "sess-inspection",
                    title: "parser repair",
                    status: .active,
                    updatedAt: date("2026-04-14T09:40:00Z"),
                    headBranchID: "branch-recovery",
                    latestCheckpointID: "ckpt-42",
                    latestCheckpointSeq: 28,
                    latestCheckpointGoal: "repair parser",
                    latestCheckpointBudgetLine: "eBrain budget: engage • loops 2 • candidates 2 • decode 192 • thermal watch",
                    latestCheckpointRouteLine: "eBrain route: npu • precision mixed • retrieval 3",
                    latestCheckpointDecisionLine: "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold42abc",
                    latestCheckpointTaskLine: "Review update ticket: preserve parser-only correction",
                    latestCheckpointPressureLine: "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
                    latestCheckpointAuditLine: "eBrain audit findings: 2",
                    latestCheckpointActiveKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
                    latestCheckpointKillSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
                    latestEventID: "evt-201",
                    latestEventSeq: 29,
                    latestEventType: .sessionRecovered,
                    latestEventDetail: "Recovered from checkpoint ckpt-42",
                    openStepCount: 0,
                    openStepStatus: nil,
                    stalledStepCount: 0,
                    branchCount: 2,
                    mergeableBranchCount: 1,
                    recoveryCount: 1,
                    latestRecoveryAt: date("2026-04-14T09:39:00Z")
                )
            ]
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            sessionEngineSnapshot: sessionEngineSnapshot,
            debugStore: DecisionIntelligenceDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let runtimeReport = export.flightDeck.layerReports.first(where: { $0.layer == .runtime })
        let dataReport = export.flightDeck.layerReports.first(where: { $0.layer == .data })
        let deliveryReport = export.flightDeck.layerReports.first(where: { $0.layer == .delivery })
        let localModelSummary = try #require(export.flightDeck.localModelLibrarySummary)
        let expectedLocalModelSummary = DecisionSystemLocalModelLibrarySummary.summary(
            from: export.runtimeSnapshot.localModelLibrary
        )

        #expect(export.sessionEngineSnapshot == sessionEngineSnapshot)
        #expect(export.flightDeck.sessionEngineSummary?.layerPlacement == .foldedLung)
        #expect(export.flightDeck.sessionEngineSummary?.sessions == 2)
        #expect(export.flightDeck.sessionEngineSummary?.mergeReadySessions == 1)
        #expect(export.flightDeck.sessionEngineSummary?.mergeableBranches == 1)
        #expect(export.flightDeck.sessionEngineSummary?.activeSession?.title == "parser repair")
        #expect(localModelSummary == expectedLocalModelSummary)
        #expect(localModelSummary.preferredProvider == .foundationModels)
        #expect(localModelSummary.openModelSlotStableID != nil)
        #expect(localModelSummary.runtimeLayerSignals == [
            localModelSummary.headline,
            localModelSummary.preferredLine
        ])
        #expect(localModelSummary.dataLayerSignals == [
            localModelSummary.bundledLine,
            localModelSummary.openModelSlotLine,
            localModelSummary.openModelRuntimeLine,
            localModelSummary.openModelAssetLine
        ])
        #expect(localModelSummary.deliveryLayerSignals == [
            localModelSummary.openModelSlotLine
        ])
        #expect(runtimeReport?.signals.contains(where: { $0.contains("Session Engine L3.folded_lung") }) == true)
        #expect(localModelSummary.runtimeLayerSignals.allSatisfy { signal in
            runtimeReport?.signals.contains(signal) == true
        })
        #expect(dataReport?.signals.contains(where: { $0.contains("Branches 3") && $0.contains("Merge-ready branches 1") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("parser repair") && $0.contains("Checkpoint ckpt-42") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("parser repair") && $0.contains("eBrain budget: engage") && $0.contains("thermal watch") && $0.contains("eBrain route: npu") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("parser repair") && $0.contains("eBrain risk: guarded") && $0.contains("Review update ticket: preserve parser-only correction") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("parser repair") && $0.contains("eBrain pressure: latency 82/1200ms") && $0.contains("thermal nominal -> watch") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("parser repair") && $0.contains("eBrain audit findings: 2") && $0.contains("force_guard_mode") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("Merge review 1") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("Merge review queue") && $0.contains("Merge-ready branches 1") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("Replay anchor ready") && $0.contains("Checkpoint ckpt-42") }) == true)
        #expect(dataReport?.signals.contains(where: { $0.contains("Checkpoint recovery") && $0.contains("Replay session sess-inspection") }) == true)
        #expect(localModelSummary.dataLayerSignals.allSatisfy { signal in
            dataReport?.signals.contains(signal) == true
        })
        #expect(localModelSummary.deliveryLayerSignals.allSatisfy { signal in
            deliveryReport?.signals.contains(signal) == true
        })
        #expect(export.summary.localModelPreferredProvider == .foundationModels)
        #expect(export.summary.localModelOpenModelSlotStableID != nil)
    }

    @Test
    func runtimeExportFallsBackToPersistedCheckpointLineageWhenEBrainStoreIsEmpty() async throws {
        let container = try makePersistenceContainer()
        let context = container.mainContext
        let now = date("2026-04-11T09:00:00Z")
        context.insert(
            CheckEvent(
                createdAt: now,
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
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-quick",
                createdAt: now.addingTimeInterval(-4),
                fingerprint: "fingerprint-quick",
                previousCheckpointID: nil,
                mode: .quick,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Quick checkpoint should win on mode"],
                approvalState: .automatic,
                rollbackReady: true,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: now.addingTimeInterval(-6),
                    sessionID: "before.quick.lineage",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 78,
                    thoughtFoldChecksum: "fold-checksum",
                    updateTicketSummaries: ["Hold before sending"],
                    guardrailFindings: ["Guardrail matched"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        context.insert(
            DecisionEvolutionCheckpoint(
                id: "checkpoint-mirror",
                createdAt: now.addingTimeInterval(-2),
                fingerprint: "fingerprint-mirror",
                previousCheckpointID: "checkpoint-quick",
                mode: .mirror,
                source: .explicitRefresh,
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["Mirror checkpoint is newer but should lose"],
                approvalState: .reviewSuggested,
                rollbackReady: true,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: now.addingTimeInterval(-3),
                    sessionID: "before.mirror.lineage",
                    taskType: "reflection",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 61,
                    thoughtFoldChecksum: "fold-mirror",
                    updateTicketSummaries: ["capture calmer follow-up"],
                    guardrailFindings: ["Recovered lineage available"],
                    recommendedKillSwitches: []
                )
            )
        )
        try context.save()

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: try context
                .fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
                .compactMap { checkpoint in
                    guard let lineageSummary = checkpoint.lineageSummary else {
                        return nil
                    }
                    return DecisionEvolutionLineageSnapshot(
                        checkpointID: checkpoint.id,
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
                },
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.eBrainTurn == nil)
        #expect(export.latestCheckpointLineage?.checkpointID == "checkpoint-quick")
        #expect(export.effectiveEBrainSource == .persistedCheckpoint)
        #expect(export.recentReplay.count == 2)
        #expect(export.recentReplay.first?.mode == .quick)
        #expect(export.recentReplay.first?.entrySource == .app)
        #expect(export.recentReplay.first?.eBrain?.source == .persistedCheckpoint)
        #expect(export.recentReplay.first?.eBrain?.permitMode == "delay")
        #expect(export.recentReplay.first?.matchedPersistedCheckpointID == "checkpoint-quick")
        #expect(export.preferredCheckpointSelectionContext?.explicitCheckpointID == "checkpoint-quick")
        #expect(export.flightDeck.eBrainSummary?.taskType == "conflict")
        #expect(export.flightDeck.eBrainSummary?.source == .persistedCheckpoint)
        #expect(export.flightDeck.eBrainSummary?.permitMode == "delay")
        #expect(export.flightDeck.eBrainSummary?.riskLevel == "high")
        #expect(export.flightDeck.eBrainSummary?.checkpointID == "checkpoint-quick")
        #expect(export.flightDeck.eBrainSummary?.checkpointApprovalState == "automatic")
        #expect(export.flightDeck.eBrainSummary?.checkpointApplyReady == false)
        #expect(export.effectiveEBrainFactsBundle?.summaryLine.contains("Checkpoint recovery") == true)
        #expect(export.effectiveEBrainFactsBundle?.taskLine == "Review: Hold before sending")
        #expect(export.runtimeAuditFindings == ["Guardrail matched"])
        #expect(export.recommendedKillSwitches == ["host-write"])
        #expect(export.thoughtFoldChecksum == "fold-checksum")
        #expect(export.flightDeck.layerReports.first(where: { $0.layer == .data })?.signals.contains(where: {
            $0.contains("Review: Hold before sending")
        }) == true)
    }

    @Test
    func runtimeExportCarriesPendingSessionEngineImportPreviewIntoFlightDeck() async {
        let pendingImport = DecisionSessionEnginePendingImportPreview(
            sourceFileName: "parser-session.json",
            preview: DecisionSessionImportBundlePreview(
                id: "preview-1",
                sourceSessionId: "sess-exported",
                sourceTitle: "Parser repair",
                importedTitle: "Parser repair (Imported)",
                exportedAt: date("2026-04-14T09:45:00Z"),
                countsLine: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1",
                integrityLine: "Validated schema v1 • fingerprint abcdef123456",
                checkpointLine: "Latest checkpoint ckpt-7 • repair parser",
                branchLine: "Head main • Layer folded_lung",
                unfinishedStepCount: 1,
                unfinishedStepsLine: "Open steps 1 • unfinished work will import as failed recovery facts.",
                headline: "Importing creates a new paused recovery-safe session.",
                branchPreviews: []
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            pendingSessionEngineImportPreview: pendingImport,
            debugStore: DecisionIntelligenceDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.pendingSessionEngineImportPreview == pendingImport)
        #expect(export.flightDeck.sessionEngineSummary?.pendingImportPreview?.bundleLine == "Bundle parser-session.json")
        #expect(export.flightDeck.sessionEngineSummary?.pendingImportPreview?.unfinishedWorkSummary.title == "Open work will be normalized")
        #expect(export.flightDeck.layerReports.first(where: { $0.layer == .runtime })?.signals.contains(where: {
            $0.contains("Pending import") && $0.contains("parser-session.json")
        }) == true)
    }

    @Test
    func runtimeExportChoosesMostRecentCheckpointLineageWhenReplayContextIsAbsent() async throws {
        let older = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-quick-older",
            createdAt: date("2026-04-10T20:20:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Older quick checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:20:00.000Z"),
                    sessionID: "before.quick.older",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 44,
                    thoughtFoldChecksum: "fold-older",
                    updateTicketSummaries: ["older ticket"],
                    guardrailFindings: ["Older guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let newer = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-quick-newer",
            createdAt: date("2026-04-10T21:55:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Newer quick checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:55:00.000Z"),
                    sessionID: "before.quick.newer",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 88,
                    thoughtFoldChecksum: "fold-newer",
                    updateTicketSummaries: ["newer ticket"],
                    guardrailFindings: ["Newer guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [older, newer],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.latestCheckpointLineage?.checkpointID == "checkpoint-quick-newer")
        #expect(export.flightDeck.eBrainSummary?.taskType == "conflict")
        #expect(export.flightDeck.eBrainSummary?.permitMode == "delay")
        #expect(export.flightDeck.eBrainSummary?.checkpointID == "checkpoint-quick-newer")
        #expect(export.flightDeck.eBrainSummary?.checkpointApplyReady == true)
        #expect(export.thoughtFoldChecksum == "fold-newer")
    }

    @Test
    func runtimeExportUsesSessionCheckpointAnchorWhenReplayContextIsCheckpointOnly() async throws {
        let targetDirective = "Review memory write: Keep the parser-only correction local."
        let target = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-session-anchor-target",
            createdAt: date("2026-04-10T20:20:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Target checkpoint should win on structured anchor metadata"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:20:00.000Z"),
                    sessionID: "before.quick.anchor",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 77,
                    thoughtFoldChecksum: "fold-shared",
                    updateTicketSummaries: ["preserve parser-only correction"],
                    reviewDirectiveLine: targetDirective,
                    guardrailFindings: ["Anchor-aligned guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        let closerButWrongMetadata = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-session-anchor-closer",
            createdAt: date("2026-04-10T20:21:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Closer checkpoint should lose because metadata diverges"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:21:00.000Z"),
                    sessionID: "before.quick.anchor",
                    taskType: "conflict",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 61,
                    thoughtFoldChecksum: "fold-shared",
                    updateTicketSummaries: ["broaden reflection"],
                    reviewDirectiveLine: "Review reflection draft: broaden the guidance.",
                    guardrailFindings: ["Closer-but-misaligned guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let sessionEngineSnapshot = DecisionSessionRuntimeSnapshot(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            branches: 1,
            checkpoints: 2,
            events: 8,
            steps: 1,
            recentSessions: [
                DecisionSessionRuntimeInspectionSession(
                    sessionID: "sess-anchor",
                    title: "parser repair",
                    status: .active,
                    updatedAt: date("2026-04-10T20:21:30.000Z"),
                    headBranchID: "branch-main",
                    latestCheckpointID: "ckpt-42",
                    latestCheckpointSeq: 42,
                    latestCheckpointGoal: "repair parser",
                    latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                        sessionID: "before.quick.anchor",
                        thoughtFoldChecksum: "fold-shared",
                        riskLevel: "high",
                        permitMode: "delay",
                        hostGatePercent: 77,
                        reviewDirectiveLine: targetDirective,
                        executionCapability: DecisionSessionCheckpointExecutionCapability(
                            activeProviderID: DecisionModelProviderKind.foundationModels.rawValue,
                            preferredProviderID: DecisionModelProviderPreference.foundationModels.rawValue,
                            fallbackProviderID: DecisionModelProviderKind.gemmaE4B.rawValue,
                            providerTrackID: DecisionModelProviderTrack.builtInSystem.rawValue,
                            executionTierID: DecisionIntelligenceExecutionTier.systemManaged.rawValue,
                            foundationTierID: DecisionEBrainFoundationTier.systemManaged.rawValue,
                            reasonCodes: [
                                "tier:\(DecisionIntelligenceExecutionTier.systemManaged.rawValue)",
                                "active:\(DecisionModelProviderKind.foundationModels.rawValue)",
                                "preferred:\(DecisionModelProviderPreference.foundationModels.rawValue)"
                            ]
                        )
                    ),
                    latestEventID: nil,
                    latestEventSeq: nil,
                    latestEventType: nil,
                    latestEventDetail: nil,
                    openStepCount: 0,
                    openStepStatus: nil,
                    stalledStepCount: 0,
                    branchCount: 1,
                    recoveryCount: 0,
                    latestRecoveryAt: nil
                )
            ]
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            sessionEngineSnapshot: sessionEngineSnapshot,
            traceLimit: 0,
            persistedCheckpointLineages: [target, closerButWrongMetadata],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.eBrainTurn == nil)
        #expect(export.recentReplay.count == 2)
        #expect(export.preferredCheckpointSelectionContext?.sessionID == "before.quick.anchor")
        #expect(export.preferredCheckpointSelectionContext?.thoughtFoldChecksum == "fold-shared")
        #expect(export.preferredCheckpointSelectionContext?.riskLevel == "high")
        #expect(export.preferredCheckpointSelectionContext?.permitMode == "delay")
        #expect(export.preferredCheckpointSelectionContext?.hostGatePercent == 77)
        #expect(export.preferredCheckpointSelectionContext?.reviewDirectiveLine == targetDirective)
        #expect(export.latestCheckpointLineage?.checkpointID == "checkpoint-session-anchor-target")
        #expect(export.flightDeck.eBrainSummary?.checkpointID == "checkpoint-session-anchor-target")
        #expect(export.flightDeck.eBrainSummary?.riskLevel == "high")
        #expect(export.flightDeck.eBrainSummary?.hostGatePercent == 77)
        #expect(export.effectiveEBrainFactsBundle?.taskLine == targetDirective)
        #expect(
            export.effectiveEBrainFactsBundle?.executionCapabilityLine
                == "Capability systemManaged • Foundation systemManaged • Posture trustedProduction • Boundary externalTraining • Active Apple Foundation Model • Preferred Apple Foundation Model • Track builtInSystem • Fallback Gemma 4 E4B"
        )
        #expect(
            export.effectiveEBrainFactsBundle?.horizonLine
                == "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        )
        #expect(
            export.effectiveEBrainFactsBundle?.temporalLine
                == "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
        )
        #expect(
            export.effectiveEBrainFactsBundle?.evidenceLine
                == "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.horizonLine
                == "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.temporalLine
                == "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.evidenceLine
                == "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
            ) == true
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
            ) == true
        )
        #expect(
            export.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
            ) == true
        )
        let coverage = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil
        )
        #expect(coverage.executionTierID == export.executionCapabilityFrame.executionTierID)
        #expect(coverage.foundationTierID == export.executionCapabilityFrame.foundationTierID)
        #expect(coverage.executionTierID == export.flightDeck.eBrainSummary?.executionCapabilityFrame?.executionTierID)
        #expect(coverage.foundationTierID == export.flightDeck.eBrainSummary?.executionCapabilityFrame?.foundationTierID)
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
    func runtimeExportIncludesCheckpointOnlyReplayWhenNoDecisionRecordMatches() async throws {
        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T21:15:00.000Z"),
            sessionID: "before.mirror.lineage",
            taskType: "reflection",
            riskLevel: "medium",
            permitMode: "compare",
            hostGatePercent: 61,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["capture calmer follow-up"],
            guardrailFindings: ["Recovered lineage available"],
            recommendedKillSwitches: []
        )
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-standalone",
            createdAt: date("2026-04-10T21:16:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Recovered persisted checkpoint without matching replay record"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.recentReplay.count == 1)
        #expect(export.recentReplay.first?.mode == .mirror)
        #expect(export.recentReplay.first?.title == "Recovered Mirror lineage")
        #expect(export.recentReplay.first?.eBrain?.source == .persistedCheckpoint)
        #expect(export.recentReplay.first?.eBrain?.sessionID == "before.mirror.lineage")
    }

    @Test
    func runtimeExportSurfacesPendingReviewQueueThroughFlightDeck() async throws {
        let approved = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-approved",
            createdAt: date("2026-04-10T20:00:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Approved checkpoint should not enter the queue"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:00:00.000Z"),
                    sessionID: "before.quick.approved",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 45,
                    thoughtFoldChecksum: "fold-approved",
                    updateTicketSummaries: ["approved ticket"],
                    guardrailFindings: ["Approved guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let queueOldest = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-1",
            createdAt: date("2026-04-10T20:15:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: false,
            diffSummary: ["Oldest review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:15:00.000Z"),
                    sessionID: "before.quick.review-1",
                    taskType: "conflict",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 52,
                    thoughtFoldChecksum: "fold-review-1",
                    updateTicketSummaries: ["review ticket 1"],
                    guardrailFindings: ["Review guardrail 1"],
                    recommendedKillSwitches: []
                )
            )
        )
        let queueMiddle = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-2",
            createdAt: date("2026-04-10T20:30:00.000Z"),
            mode: .balance,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Middle review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:30:00.000Z"),
                    sessionID: "before.balance.review-2",
                    taskType: "tradeoff",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 71,
                    thoughtFoldChecksum: "fold-review-2",
                    updateTicketSummaries: ["review ticket 2"],
                    guardrailFindings: ["Review guardrail 2"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        let queueNewest = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-3",
            createdAt: date("2026-04-10T20:45:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Newest review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:45:00.000Z"),
                    sessionID: "before.mirror.review-3",
                    taskType: "reflection",
                    riskLevel: "high",
                    permitMode: "replace",
                    hostGatePercent: 83,
                    thoughtFoldChecksum: "fold-review-3",
                    updateTicketSummaries: ["review ticket 3"],
                    guardrailFindings: ["Review guardrail 3"],
                    recommendedKillSwitches: ["tool-call"]
                )
            )
        )
        let queueOverflow = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-4",
            createdAt: date("2026-04-10T21:00:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Overflow review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:00:00.000Z"),
                    sessionID: "before.quick.review-4",
                    taskType: "conflict",
                    riskLevel: "extreme",
                    permitMode: "block",
                    hostGatePercent: 91,
                    thoughtFoldChecksum: "fold-review-4",
                    updateTicketSummaries: ["review ticket 4"],
                    guardrailFindings: ["Review guardrail 4"],
                    recommendedKillSwitches: ["external-tools"],
                    foldedLungSummary: Self.sampleFoldedLungSummary(
                        checkpointID: "checkpoint-review-4"
                    )
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [
                approved,
                queueOldest,
                queueMiddle,
                queueNewest,
                queueOverflow
            ],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.pendingReviewCheckpointCount == 4)
        #expect(export.pendingReviewCheckpointLineages.map { $0.checkpointID } == [
            "checkpoint-review-4",
            "checkpoint-review-3",
            "checkpoint-review-2",
            "checkpoint-review-1"
        ])
        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-approved")
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-review-4")
        #expect(export.evolutionControlSurface.pendingReviewCount == 4)
        #expect(export.evolutionControlSurface.rollbackReadyCount == 0)
        #expect(export.evolutionControlSurface.reviewAuditFindings == ["Review guardrail 4"])
        #expect(export.evolutionControlSurface.reviewKillSwitches == ["external-tools"])
        #expect(export.evolutionControlSurface.queueAuditFindings == [
            "Review guardrail 4",
            "Review guardrail 3",
            "Review guardrail 2",
            "Review guardrail 1"
        ])
        #expect(export.evolutionControlSurface.queueKillSwitches == [
            "external-tools",
            "tool-call",
            "host-write"
        ])
        #expect(export.flightDeck.pendingReviewCheckpointCount == 4)
        #expect(export.flightDeck.pendingReviewQueue.map { $0.checkpointID } == [
            "checkpoint-review-4",
            "checkpoint-review-3",
            "checkpoint-review-2"
        ])
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointID == "checkpoint-approved")
        #expect(export.flightDeck.evolutionControlSurface == export.evolutionControlSurface)
        #expect(export.flightDeck.pendingReviewQueue.first?.primarySummary == "Overflow review checkpoint")
        #expect(export.flightDeck.pendingReviewQueue.first?.applyReady == false)
        #expect(export.flightDeck.pendingReviewQueue.last?.applyReady == true)
        #expect(export.flightDeck.pendingReviewQueue.first?.permitMode == "block")
        #expect(export.flightDeck.pendingReviewQueue.first?.foldedLungTitle == "Folded lung")
        #expect(
            export.flightDeck.pendingReviewQueue.first?.foldedLungLines == [
                "L3 compression runtime • breath guard • phase exchange • anchor rollback-checkpoint-review-4",
                "Breath guard • Phase exchange • Restore 84%",
                "Morph graph morph-checkpoint-review-4 • organs riskSpine, stubCore • route ane • thermal guarded",
                "Integrity weave verified • checks 1/1 • hash abc123def456",
                "Rollback anchor rollback-checkpoint-review-4 • snapshot snapshot-checkpoint-review-4"
            ]
        )
    }

    @Test
    func runtimeExportSplitsActiveCheckpointFromPendingReviewHead() async throws {
        let automaticLatest = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active-latest",
            previousCheckpointID: "checkpoint-active-previous",
            createdAt: date("2026-04-10T21:40:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Latest active checkpoint should remain separate from review head."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:40:00.000Z"),
                    sessionID: "before.quick.active-latest",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 44,
                    thoughtFoldChecksum: "fold-active-latest",
                    updateTicketSummaries: ["latest active ticket"],
                    guardrailFindings: ["Active checkpoint guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let reviewHead = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-pending-review-head",
            createdAt: date("2026-04-10T20:45:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Pending review head should stay separate from latest active checkpoint."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:45:00.000Z"),
                    sessionID: "before.mirror.pending-review-head",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 81,
                    thoughtFoldChecksum: "fold-pending-review-head",
                    updateTicketSummaries: ["pending review ticket"],
                    guardrailFindings: ["Pending review guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [automaticLatest, reviewHead],
            restorableCheckpointIDs: ["checkpoint-active-latest", "checkpoint-active-previous"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-active-latest")
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-pending-review-head")
        #expect(export.evolutionControlSurface.reviewAuditFindings == ["Pending review guardrail"])
        #expect(export.evolutionControlSurface.reviewKillSwitches == ["host-write"])
        #expect(export.evolutionControlSurface.latestPersistedLineage?.checkpointID == "checkpoint-active-latest")
        #expect(export.evolutionControlSurface.pendingReviewCount == 1)
        #expect(export.evolutionControlSurface.rollbackReadyCount == 0)
        #expect(export.evolutionControlSurface.activeRollbackCheckpointID == "checkpoint-active-previous")
    }

    @Test
    func runtimeExportPrefersExplicitActiveCheckpointHintOverRecoveredLineage() async throws {
        let recoveredActive = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-recovered-active",
            previousCheckpointID: "checkpoint-recovered-prior",
            createdAt: date("2026-04-10T22:30:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Recovered checkpoint should not override the explicit active hint."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:30:00.000Z"),
                    sessionID: "before.quick.recovered-active",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 41,
                    thoughtFoldChecksum: "fold-recovered-active",
                    updateTicketSummaries: ["recovered active ticket"],
                    guardrailFindings: ["Recovered checkpoint guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let reviewHead = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-head",
            previousCheckpointID: nil,
            createdAt: date("2026-04-10T22:10:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review head stays separate from the explicit active hint."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:10:00.000Z"),
                    sessionID: "before.mirror.review-head",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 78,
                    thoughtFoldChecksum: "fold-review-head",
                    updateTicketSummaries: ["review head ticket"],
                    guardrailFindings: ["Review head guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )
        let explicitActiveHint = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-current-brain",
            previousCheckpointID: "checkpoint-recovered-active",
            createdAt: date("2026-04-10T22:45:00.000Z"),
            mode: .balance,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Current brain checkpoint should remain the active release fact source."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:45:00.000Z"),
                    sessionID: "before.balance.current-brain",
                    taskType: "tradeoff",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 63,
                    thoughtFoldChecksum: "fold-current-brain",
                    updateTicketSummaries: ["current brain ticket"],
                    guardrailFindings: ["Current brain guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [recoveredActive, reviewHead],
            pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot(lineage: reviewHead)],
            activeCheckpointHint: explicitActiveHint,
            restorableCheckpointIDs: ["checkpoint-current-brain", "checkpoint-recovered-active"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let facts = DecisionCapabilityCoverageBuilder.evolutionFacts(
            from: export,
            currentBrainState: nil
        )

        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-current-brain")
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-review-head")
        #expect(export.evolutionControlSurface.activeRollbackCheckpointID == "checkpoint-recovered-active")
        #expect(facts.recoveredCheckpoint?.checkpointID == "checkpoint-current-brain")
        #expect(facts.recoveredAuditFindingCount == 1)
        #expect(facts.recoveredTicketCount == 1)
    }

    @Test
    func runtimeExportFlightDeckReleaseSummaryBecomesReadyForRestorableActiveCheckpoint() async throws {
        let active = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active-ready",
            previousCheckpointID: "checkpoint-active-prior",
            createdAt: date("2026-04-10T22:00:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Ready checkpoint should produce a guarded-ready release state."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:00:00.000Z"),
                    sessionID: "before.quick.release-ready",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 37,
                    thoughtFoldChecksum: "fold-release-ready",
                    updateTicketSummaries: ["ready ticket"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [active],
            restorableCheckpointIDs: ["checkpoint-active-ready", "checkpoint-active-prior"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.flightDeck.releaseControlSummary.state == .ready)
        #expect(export.flightDeck.releaseControlSummary.canRestoreActiveCheckpoint == true)
        #expect(export.flightDeck.releaseControlSummary.canRollbackActiveCheckpoint == true)
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointID == "checkpoint-active-ready")
        #expect(export.flightDeck.releaseControlSummary.reviewCheckpointID == nil)
    }

    @Test
    func runtimeExportFlightDeckReleaseSummaryStaysInWatchWhenRollbackTargetIsNotRestorable() async throws {
        let active = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active-watch",
            previousCheckpointID: "checkpoint-active-missing",
            createdAt: date("2026-04-10T22:05:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Checkpoint stays watch-only when its previous target cannot be restored."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:05:00.000Z"),
                    sessionID: "before.quick.release-watch",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 37,
                    thoughtFoldChecksum: "fold-release-watch",
                    updateTicketSummaries: ["watch ticket"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [active],
            restorableCheckpointIDs: ["checkpoint-active-watch"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.evolutionControlSurface.canRollbackActiveCheckpoint == false)
        #expect(export.evolutionControlSurface.activeRollbackCheckpointID == nil)
        #expect(export.flightDeck.releaseControlSummary.state == .watch)
        #expect(export.flightDeck.releaseControlSummary.canRestoreActiveCheckpoint == true)
        #expect(export.flightDeck.releaseControlSummary.canRollbackActiveCheckpoint == false)
    }

    @Test
    func runtimeExportAttachingPreservesRestorableCheckpointIDs() async throws {
        let active = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-attach-active",
            previousCheckpointID: "checkpoint-attach-previous",
            createdAt: date("2026-04-10T22:06:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Attaching a live turn must not drop rollback restore facts."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:06:00.000Z"),
                    sessionID: "before.quick.attach-active",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 36,
                    thoughtFoldChecksum: "fold-attach-active",
                    updateTicketSummaries: ["attach active"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [active],
            restorableCheckpointIDs: ["checkpoint-attach-active", "checkpoint-attach-previous"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let attached = export.attaching(eBrainTurn: nil)

        #expect(attached.restorableCheckpointIDs == export.restorableCheckpointIDs)
        #expect(attached.evolutionControlSurface.canRollbackActiveCheckpoint == export.evolutionControlSurface.canRollbackActiveCheckpoint)
        #expect(attached.evolutionControlSurface.activeRollbackCheckpointID == export.evolutionControlSurface.activeRollbackCheckpointID)
        #expect(attached.flightDeck.releaseControlSummary.canRollbackActiveCheckpoint == export.flightDeck.releaseControlSummary.canRollbackActiveCheckpoint)
    }

    @Test
    func runtimeExportFlightDeckReleaseSummaryWatchesRecommendedKillSwitchesWithoutTreatingThemAsActivePolicy() async throws {
        let active = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active-blocked",
            previousCheckpointID: "checkpoint-active-prior",
            createdAt: date("2026-04-10T22:15:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Kill switches should block release."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T22:15:00.000Z"),
                    sessionID: "before.quick.release-blocked",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 79,
                    thoughtFoldChecksum: "fold-release-blocked",
                    updateTicketSummaries: ["blocked ticket"],
                    guardrailFindings: ["blocked guardrail"],
                    recommendedKillSwitches: ["disableHighRiskAutoAction"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [active],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.flightDeck.releaseControlSummary.state == .watch)
        #expect(export.flightDeck.releaseControlSummary.activeKillSwitches.isEmpty)
        #expect(export.flightDeck.releaseControlSummary.recommendedKillSwitches == ["disableHighRiskAutoAction"])
        #expect(export.flightDeck.releaseControlSummary.killSwitches == ["disableHighRiskAutoAction"])
    }

    @Test
    func runtimeExportEvolutionControlSurfaceAlignsWithCoverageFacts() async throws {
        let approved = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-approved",
            createdAt: date("2026-04-10T20:00:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Approved checkpoint should not enter the queue"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:00:00.000Z"),
                    sessionID: "before.quick.approved",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 45,
                    thoughtFoldChecksum: "fold-approved",
                    updateTicketSummaries: ["approved ticket"],
                    guardrailFindings: ["Approved guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )
        let reviewSuggested = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-1",
            createdAt: date("2026-04-10T20:15:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T20:15:00.000Z"),
                    sessionID: "before.quick.review-1",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 82,
                    thoughtFoldChecksum: "fold-review-1",
                    updateTicketSummaries: ["review ticket 1"],
                    guardrailFindings: ["Review guardrail 1"],
                    recommendedKillSwitches: ["external-tools"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [approved, reviewSuggested],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let surface = export.evolutionControlSurface
        let facts = DecisionCapabilityCoverageBuilder.evolutionFacts(
            from: export,
            currentBrainState: nil
        )
        let directReport = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil,
            evolutionFacts: facts
        )
        let convenienceReport = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil
        )

        #expect(surface.reviewCheckpoint?.checkpointID == "checkpoint-review-1")
        #expect(surface.pendingReviewCount == 1)
        #expect(surface.rollbackReadyCount == 0)
        #expect(surface.reviewAuditFindings == ["Review guardrail 1"])
        #expect(surface.reviewKillSwitches == ["external-tools"])
        #expect(facts.recoveredCheckpoint?.checkpointID == surface.activeCheckpoint?.checkpointID)
        #expect(facts.latestPersistedLineage?.checkpointID == surface.latestPersistedLineage?.checkpointID)
        #expect(facts.recoveredEBrainAvailable == true)
        #expect(facts.recoveredAuditFindingCount == surface.activeCheckpoint?.auditFindings.count)
        #expect(facts.recoveredTicketCount == surface.activeCheckpoint?.updateTicketSummaries.count)
        #expect(directReport == convenienceReport)
    }

    @Test
    func runtimeExportEvolutionCoverageFactsPreferCurrentBrainAutomaticCheckpoint() async throws {
        let recoveredActive = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-recovered-active",
            createdAt: date("2026-04-10T19:00:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Recovered active checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T19:00:00.000Z"),
                    sessionID: "before.quick.recovered-active",
                    taskType: "summary",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 57,
                    thoughtFoldChecksum: "fold-recovered-active",
                    updateTicketSummaries: ["checkpoint recovery"],
                    guardrailFindings: ["Recovered active guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [recoveredActive],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        var brainState = DecisionBrainState(
            profileCore: ["Stay reflective."],
            activeGoals: ["Slow the decision down."],
            relevantMemories: ["Reflection benefits from a pause."],
            sessionBiases: ["Prefer delay over haste."],
            retrievalTags: ["reflection"],
            reactionWeights: .defaults(for: .mirror),
            loadedAt: date("2026-04-10T21:20:00.000Z")
        )
        brainState.evolutionState = DecisionEvolutionState(
            latestCheckpoint: DecisionEvolutionCheckpointSummary(
                id: "checkpoint-current-brain-automatic",
                previousCheckpointID: nil,
                createdAt: date("2026-04-10T21:20:00.000Z"),
                diffSummary: ["Current brain automatic checkpoint"],
                rollbackReady: false,
                approvalState: .automatic,
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:20:00.000Z"),
                    sessionID: "before.mirror.current-brain",
                    taskType: "reflection",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 84,
                    thoughtFoldChecksum: "fold-current-brain",
                    updateTicketSummaries: ["current brain recovery"],
                    guardrailFindings: ["Current brain guardrail"],
                    recommendedKillSwitches: []
                )
            ),
            checkpointCount: 1,
            rollbackReady: false,
            pendingReviewCount: 0,
            recentDiffSummary: ["Current brain automatic checkpoint"]
        )
        let currentBrainState = CurrentBrainState(
            source: .launch,
            sourceSurface: .app,
            mode: .mirror,
            riskLevel: .high,
            taskGraph: nil,
            brainState: brainState,
            dominantGoal: "Slow the decision down.",
            activeConstraints: ["Prefer delay over haste."],
            activeTemplateIDs: [],
            failureGuardIDs: [],
            sourceIntentEnvelope: nil,
            loadedAt: date("2026-04-10T21:20:00.000Z")
        )

        let facts = export.evolutionCoverageFacts(currentBrainState: currentBrainState)

        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-recovered-active")
        #expect(facts.recoveredCheckpoint?.checkpointID == "checkpoint-current-brain-automatic")
        #expect(facts.latestPersistedLineage?.checkpointID == "checkpoint-recovered-active")
        #expect(facts.recoveredAuditFindingCount == 1)
        #expect(facts.recoveredTicketCount == 1)
    }

    @Test
    func runtimeExportPreservesPendingReviewQueueWithoutPersistedLineage() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            pendingReviewCheckpoints: [
                DecisionReviewCheckpointSnapshot(
                    checkpointID: "checkpoint-review-legacy",
                    createdAt: date("2026-04-10T21:10:00.000Z"),
                    mode: .quick,
                    approvalState: .reviewSuggested,
                    rollbackReady: true,
                    hasBrainStateSnapshot: true,
                    diffSummary: ["Legacy review checkpoint without lineage"],
                    eBrain: nil
                )
            ],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.pendingReviewCheckpointCount == 1)
        #expect(export.effectivePendingReviewCheckpoints.map(\.checkpointID) == ["checkpoint-review-legacy"])
        #expect(export.evolutionControlSurface.activeCheckpoint == nil)
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-review-legacy")
        #expect(export.evolutionControlSurface.pendingReviewCount == 1)
        #expect(export.evolutionControlSurface.reviewAuditFindings.isEmpty)
        #expect(export.evolutionControlSurface.queueAuditFindings.isEmpty)
        #expect(export.evolutionControlSurface.queueKillSwitches.isEmpty)
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointID == nil)
        #expect(export.flightDeck.pendingReviewCheckpointCount == 1)
        #expect(export.flightDeck.pendingReviewQueue.first?.checkpointID == "checkpoint-review-legacy")
        #expect(export.flightDeck.pendingReviewQueue.first?.primarySummary == "Legacy review checkpoint without lineage")
        #expect(export.flightDeck.pendingReviewQueue.first?.applyReady == true)
        #expect(export.flightDeck.pendingReviewQueue.first?.riskLevel == nil)
        #expect(export.flightDeck.pendingReviewQueue.first?.foldedLungTitle == nil)
        #expect(export.flightDeck.pendingReviewQueue.first?.foldedLungLines.isEmpty == true)
        #expect(export.flightDeck.evolutionControlSurface == export.evolutionControlSurface)
    }

    @Test
    func runtimeExportDoesNotPromoteReviewOnlyLineageToActiveCheckpoint() async throws {
        let reviewHead = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-only",
            previousCheckpointID: nil,
            createdAt: date("2026-04-10T21:10:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review-only lineage should stay out of the active release slot."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:10:00.000Z"),
                    sessionID: "before.mirror.review-only",
                    taskType: "reflection",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 79,
                    thoughtFoldChecksum: "fold-review-only",
                    updateTicketSummaries: ["review-only ticket"],
                    guardrailFindings: ["Review-only guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [reviewHead],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let facts = DecisionCapabilityCoverageBuilder.evolutionFacts(
            from: export,
            currentBrainState: nil
        )

        #expect(export.evolutionControlSurface.activeCheckpoint == nil)
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-review-only")
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointID == nil)
        #expect(export.flightDeck.releaseControlSummary.reviewCheckpointID == "checkpoint-review-only")
        #expect(export.flightDeck.releaseControlSummary.state == .watch)
        #expect(facts.recoveredCheckpoint == nil)
        #expect(facts.latestPersistedLineage?.checkpointID == "checkpoint-review-only")
        #expect(facts.recoveredEBrainAvailable == true)
    }

    @Test
    func runtimeExportPreservesPinnedActiveCheckpointSourceAcrossControlSurfaceAndFlightDeck() async throws {
        let active = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-active-pinned",
            previousCheckpointID: "checkpoint-active-prior",
            createdAt: date("2026-04-10T21:30:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Pinned active checkpoint should survive export."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:30:00.000Z"),
                    sessionID: "before.quick.active-pinned",
                    taskType: "summary",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 71,
                    thoughtFoldChecksum: "fold-active-pinned",
                    updateTicketSummaries: ["pinned active ticket"],
                    guardrailFindings: ["Pinned active guardrail"],
                    recommendedKillSwitches: []
                )
            )
        )

        let automaticFallback = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active-fallback",
            previousCheckpointID: "checkpoint-active-prior",
            createdAt: date("2026-04-10T21:20:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Older automatic fallback should not replace a pinned hint."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:20:00.000Z"),
                    sessionID: "before.quick.active-fallback",
                    taskType: "summary",
                    riskLevel: "low",
                    permitMode: "answer",
                    hostGatePercent: 55,
                    thoughtFoldChecksum: "fold-active-fallback",
                    updateTicketSummaries: ["fallback ticket"],
                    guardrailFindings: [],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            persistedCheckpointLineages: [automaticFallback],
            activeCheckpointHint: active,
            activeCheckpointSource: .pinnedHint,
            restorableCheckpointIDs: ["checkpoint-active-prior"],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        #expect(export.activeCheckpointSource == .pinnedHint)
        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-active-pinned")
        #expect(export.evolutionControlSurface.activeCheckpointSource == .pinnedHint)
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointID == "checkpoint-active-pinned")
        #expect(export.flightDeck.releaseControlSummary.activeCheckpointSource == .pinnedHint)
    }

    @Test
    func checkpointPresentationFallsBackToPersistedBoundaryAndCalibrationWithoutLineage() {
        let checkpoint = DecisionEvolutionCheckpoint(
            id: "checkpoint-presentation-fallback",
            createdAt: date("2026-04-11T02:00:00.000Z"),
            fingerprint: "fingerprint-presentation-fallback",
            previousCheckpointID: nil,
            mode: .mirror,
            source: .explicitRefresh,
            identityRole: .reflectiveWitness,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .watch,
            diffSummary: ["Fallback presentation should stay readable in history."],
            approvalState: .reviewSuggested,
            rollbackReady: true,
            lineageSummary: nil
        )

        let presentation = checkpoint.presentation

        #expect(presentation.displayRiskLevel == "watch")
        #expect(presentation.displayPermitMode == "local_only_protective")
        #expect(presentation.hasLineage == false)
        #expect(presentation.lineageRiskLevel == nil)
        #expect(presentation.lineagePermitMode == nil)
        #expect(presentation.summaryText == "WATCH → LOCAL ONLY PROTECTIVE")
        #expect(presentation.usesSecondarySummaryTone == true)
        #expect(presentation.queueItem.hasLineage == false)
        #expect(presentation.queueItem.riskLevel == nil)
        #expect(presentation.queueItem.permitMode == nil)
        #expect(presentation.primarySummary == "Fallback presentation should stay readable in history.")
    }

    @Test
    func checkpointPresentationKeepsQueueAndHistoryFactsAlignedWhenLineageExists() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-presentation-lineage",
            createdAt: date("2026-04-11T03:00:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Lineage-backed review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-11T03:00:00.000Z"),
                    sessionID: "before.quick.presentation-lineage",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 82,
                    thoughtFoldChecksum: "fold-lineage",
                    updateTicketSummaries: ["lineage ticket"],
                    guardrailFindings: ["lineage guardrail"],
                    recommendedKillSwitches: ["external-tools"],
                    foldedLungSummary: Self.sampleFoldedLungSummary(
                        checkpointID: "checkpoint-presentation-lineage"
                    ),
                    governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                        experienceCandidateCount: 0,
                        shadowTrialCount: 0,
                        pendingShadowTrialCount: 0,
                        sealCount: 0,
                        pendingSealCount: 0,
                        versionDeltaCount: 0,
                        retractionOrderCount: 0,
                        pendingRetractionCount: 0,
                        dreamLoopRemandTargets: ["L9"],
                        dreamLoopReservationMode: "delayRight"
                    )
                )
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "local_only_protective"
        )

        let presentation = snapshot.presentation
        let queueItem = presentation.queueItem

        #expect(presentation.displayRiskLevel == "high")
        #expect(presentation.displayPermitMode == "delay")
        #expect(presentation.hasLineage == true)
        #expect(presentation.summaryText == "HIGH → DELAY")
        #expect(presentation.metadataText == "Session before.quick.presentation-lineage • Host gate 82% • Fold fold-lineage • Dream loop reserve delay right • remand L9")
        #expect(presentation.courtSummaryLine == "Court: agency delay right • remand L9")
        #expect(queueItem.hasLineage == true)
        #expect(queueItem.primarySummary == presentation.primarySummary)
        #expect(queueItem.summaryText == presentation.summaryText)
        #expect(queueItem.metadataText == presentation.metadataText)
        #expect(queueItem.courtLine == "Court: agency delay right • remand L9")
        #expect(queueItem.riskLevel == "high")
        #expect(queueItem.permitMode == "delay")
        #expect(queueItem.hostGatePercent == 82)
        #expect(queueItem.updateTicketSummaries == ["lineage ticket"])
        #expect(queueItem.auditFindings == ["lineage guardrail"])
        #expect(queueItem.killSwitches == ["external-tools"])
        #expect(queueItem.foldedLungTitle == "Folded lung")
        #expect(
            queueItem.foldedLungLines == [
                "L3 compression runtime • breath guard • phase exchange • anchor rollback-checkpoint-presentation-lineage",
                "Breath guard • Phase exchange • Restore 84%",
                "Morph graph morph-checkpoint-presentation-lineage • organs riskSpine, stubCore • route ane • thermal guarded",
                "Integrity weave verified • checks 1/1 • hash abc123def456",
                "Rollback anchor rollback-checkpoint-presentation-lineage • snapshot snapshot-checkpoint-presentation-lineage"
            ]
        )
    }

    @Test
    func checkpointPresentationAppendsWindGateMetadataWhenLineageCarriesL11Facts() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-presentation-wind-gate",
            createdAt: date("2026-04-11T03:05:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Wind-gated review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-11T03:05:00.000Z"),
                    sessionID: "before.quick.wind-gate-lineage",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 76,
                    thoughtFoldChecksum: "fold-wind-gate",
                    updateTicketSummaries: ["wind gate ticket"],
                    guardrailFindings: ["wind gate guardrail"],
                    recommendedKillSwitches: ["external-tools"],
                    assertionCeiling: "guarded",
                    delayType: "cool_down",
                    substituteType: "draft",
                    sovereignHintLevel: "elevated"
                )
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "local_only_protective"
        )

        let presentation = snapshot.presentation
        let queueItem = presentation.queueItem

        #expect(
            presentation.metadataText
                == "Session before.quick.wind-gate-lineage • Host gate 76% • Fold fold-wind-gate • Wind gate primary delay • assert guarded • delay cool down • substitute draft • sovereign elevated"
        )
        #expect(queueItem.metadataText == presentation.metadataText)
    }

    @Test
    func checkpointPresentationAppendsDreamLoopMetadataWhenLineageCarriesL9Facts() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-presentation-dream-loop",
            createdAt: date("2026-04-11T03:10:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Dream-loop review checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-11T03:10:00.000Z"),
                    sessionID: "before.quick.dream-loop-lineage",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 76,
                    thoughtFoldChecksum: "fold-dream-loop",
                    updateTicketSummaries: ["dream loop ticket"],
                    guardrailFindings: ["dream loop guardrail"],
                    recommendedKillSwitches: ["external-tools"],
                    governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                        experienceCandidateCount: 0,
                        shadowTrialCount: 0,
                        pendingShadowTrialCount: 0,
                        sealCount: 0,
                        pendingSealCount: 0,
                        versionDeltaCount: 0,
                        retractionOrderCount: 0,
                        pendingRetractionCount: 0,
                        dreamLoopStoppingMode: "guardTakeover",
                        dreamLoopSignalRefs: ["dream_loop:evidence_debt", "dream_loop:breakpoint"],
                        dreamLoopRemandTargets: ["L9", "L14"],
                        dreamLoopReservationMode: "delayRight",
                        dreamLoopMaxEvidenceDebtPercent: 81
                    )
                )
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "local_only_protective"
        )

        let presentation = snapshot.presentation
        let queueItem = presentation.queueItem

        #expect(
            presentation.metadataText
                == "Session before.quick.dream-loop-lineage • Host gate 76% • Fold fold-dream-loop • Dream loop stop guard takeover • reserve delay right • remand L9, L14 • debt 81% • signals evidence debt, breakpoint"
        )
        #expect(queueItem.metadataText == presentation.metadataText)
    }

    @Test
    func checkpointPresentationPrefersReviewDirectiveForPrimarySummaryWhenDiffIsEmpty() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-presentation-review-directive",
            createdAt: date("2026-04-11T03:30:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: [],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-11T03:30:00.000Z"),
                    sessionID: "before.mirror.review-directive",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 77,
                    thoughtFoldChecksum: "fold-review-directive",
                    updateTicketSummaries: ["legacy ticket summary"],
                    reviewDirectiveLine: "Review memory write: Keep the boundary signal in warm memory.",
                    guardrailFindings: ["directive guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let presentation = snapshot.presentation

        #expect(snapshot.primarySummary == "Review memory write: Keep the boundary signal in warm memory.")
        #expect(presentation.primarySummary == "Review memory write: Keep the boundary signal in warm memory.")
        #expect(presentation.queueItem.primarySummary == "Review memory write: Keep the boundary signal in warm memory.")
    }

    @Test
    func checkpointPresentationFallsBackToTicketSummaryWhenReviewDirectiveIsBlank() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-presentation-blank-review-directive",
            createdAt: date("2026-04-11T03:45:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: [],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-11T03:45:00.000Z"),
                    sessionID: "before.mirror.blank-review-directive",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 77,
                    thoughtFoldChecksum: "fold-blank-review-directive",
                    updateTicketSummaries: ["legacy ticket summary"],
                    reviewDirectiveLine: "   ",
                    guardrailFindings: ["directive guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let presentation = snapshot.presentation

        #expect(snapshot.primarySummary == "legacy ticket summary")
        #expect(presentation.primarySummary == "legacy ticket summary")
        #expect(presentation.queueItem.primarySummary == "legacy ticket summary")
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
            DecisionEvolutionCheckpoint.self,
            configurations: configuration
        )
    }

    private static func sampleFoldedLungSummary(
        checkpointID: String
    ) -> BASEvolutionFoldedLungSummary {
        BASEvolutionFoldedLungSummary(
            morphGraphID: "morph-\(checkpointID)",
            hotColdMapID: "hotcold-\(checkpointID)",
            precisionProfileID: "precision-\(checkpointID)",
            lungStateRef: "lung-\(checkpointID)",
            integrityWeaveID: "integrity-\(checkpointID)",
            breathMode: "guard",
            breathPhase: "exchange",
            thermalPressure: 63,
            cachePressure: 48,
            restoreReadinessPercent: 84,
            resumeID: "resume-\(checkpointID)",
            sourceFoldID: "fold-\(checkpointID)",
            resumeDepth: 1,
            fallbackMode: "rollbackAnchor",
            rollbackAnchorID: "rollback-\(checkpointID)",
            safeSnapshotRef: "snapshot-\(checkpointID)",
            foldRefs: ["fold-\(checkpointID)"],
            integrityHash: "abc123def456",
            morphActiveOrganIDs: ["riskSpine", "stubCore"],
            morphExecutionOrder: ["riskSpine", "stubCore"],
            morphDeviceRouteMap: ["riskSpine": "ane"],
            morphThermalProfile: ["guarded"],
            hotOrganIDs: ["stubCore"],
            warmOrganIDs: ["riskSpine"],
            coldOrganIDs: ["simuRing"],
            thermalExchangeMode: "predictive_guard",
            thermalPredictedBand: "warm",
            thermalCoolingActions: ["trim_batch"],
            integrityRequiredChecks: ["fold_checksum"],
            integrityCompletedChecks: ["fold_checksum"],
            integrityPurityState: "verified",
            integrityVerificationHash: "abc123def456",
            precisionDegradationOrder: ["fp16", "int8"],
            precisionGuardSafeFloorID: "int8"
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: value) {
            return parsed
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? .distantPast
    }

    private func makeTemporaryOpenModelFile(named fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DecisionTestingInterfaceTests", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try Data("open-model".utf8).write(to: url)
        return url
    }
}
