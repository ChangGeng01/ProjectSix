import Foundation
import BASHostKit

enum DecisionIntelligenceProviderPipeline {
    private static let registry = DecisionIntelligenceProviderRegistry.shared
    private static let responseCache = DecisionIntelligenceResponseCache.shared
    private typealias ProviderRequestObservationContext = BASAppleHostProviderObservationContext<
        DecisionIntelligenceTraceKind,
        DecisionFrontstageState,
        DecisionContextPreparedState,
        DecisionNeuralState,
        DecisionBrainState,
        DecisionAdaptiveTaskStrategy,
        DecisionIntelligencePromptContract.ContextBudget,
        DecisionIntelligenceAdmissionDecision
    >

    private static func providerObservationNarrative(
        for kind: DecisionIntelligenceTraceKind
    ) -> BASAppleProviderObservationNarrative? {
        BeforeProductCompatibility.providerObservationNarrative(
            forKindID: substrateObservationKindID(for: kind)
        )
    }

    private static func substrateObservationKindID(
        for kind: DecisionIntelligenceTraceKind
    ) -> String {
        DecisionIntelligenceTaskRouter.substrateTraceKind(kind).identifier
    }

    static func orderedKinds(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true,
        excluding suspendedKinds: Set<DecisionModelProviderKind> = [],
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) -> [DecisionModelProviderKind] {
        BASReferenceProviderRuntime.orderedProviderIDs(
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            suspendedProviderIDs: Set(suspendedKinds.map(\.rawValue)),
            routingPolicy: BeforeProductCompatibility.requireProviderRoutingPolicy(from: runtimePolicyResolution)
        )
        .compactMap(DecisionModelProviderKind.init(rawValue:))
    }

    static func runtimeStatus(
        preferences: BeforePreferences,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = defaultStatusesByKind(),
        device: DeviceCapabilitySnapshot = .current,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) -> DecisionModelRuntimeStatus {
        DecisionIntelligenceCoordinator.runtimeCoordination(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            runtimePolicyResolution: runtimePolicyResolution,
            statusesByKind: statusesByKind
        ).runtimeStatus
    }

    private struct HorizonCachePolicy: Sendable {
        let blocksReuse: Bool
        let blocksStore: Bool
        let quarantinesExistingEntries: Bool

        static let permissive = HorizonCachePolicy(
            blocksReuse: false,
            blocksStore: false,
            quarantinesExistingEntries: false
        )
    }

    private static func horizonCachePolicy(
        for brainState: DecisionBrainState?
    ) -> HorizonCachePolicy {
        guard let brainState else {
            return .permissive
        }

        let retrievalTags = Set(brainState.retrievalTags.map { $0.lowercased() })
        let sessionBiases = Set(brainState.sessionBiases.map { $0.lowercased() })
        let riskFlags = Set(brainState.verificationSnapshot.riskFlags)

        let requiresExternalRefresh =
            riskFlags.contains(.externalRefreshGuardTriggered) ||
            retrievalTags.contains("external_refresh") ||
            retrievalTags.contains("volatile") ||
            sessionBiases.contains("horizon-external-refresh")

        let requiresObservationQuarantine =
            riskFlags.contains(.observationOnlyQuarantine) ||
            retrievalTags.contains("quarantine") ||
            retrievalTags.contains("quarantined") ||
            retrievalTags.contains("tool_observation") ||
            sessionBiases.contains("horizon-tool-quarantine")

        guard requiresExternalRefresh || requiresObservationQuarantine else {
            return .permissive
        }

        return HorizonCachePolicy(
            blocksReuse: true,
            blocksStore: true,
            quarantinesExistingEntries: true
        )
    }

    private static func loadCachedResultIfAllowed<Value>(
        cacheKey: String,
        policy: HorizonCachePolicy,
        load: @escaping (String) async -> Value?,
        quarantine: @escaping (String) async -> Void
    ) async -> Value? {
        guard policy.blocksReuse == false else {
            if policy.quarantinesExistingEntries {
                await quarantine(cacheKey)
            }
            return nil
        }

        return await load(cacheKey)
    }

    private static func storeCachedResultIfAllowed<Value>(
        _ value: Value,
        cacheKey: String,
        policy: HorizonCachePolicy,
        store: @escaping (Value, String) async -> Void,
        quarantine: @escaping (String) async -> Void
    ) async {
        guard policy.blocksStore == false else {
            if policy.quarantinesExistingEntries {
                await quarantine(cacheKey)
            }
            return
        }

        await store(value, cacheKey)
    }

    private static func relevantCacheProviders(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution,
        testingStubProfile: DecisionTestingStubProfile?
    ) -> [DecisionModelProviderKind] {
        var providers = orderedKinds(
            for: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution
        )

        if testingStubProfile != nil, preference != .template {
            providers.insert(.testingStub, at: 0)
        }

        var uniqueProviders: [DecisionModelProviderKind] = []
        for provider in providers where !uniqueProviders.contains(provider) {
            uniqueProviders.append(provider)
        }

        return uniqueProviders
    }

    private static func preemptivelyQuarantineCachesIfNeeded(
        policy: HorizonCachePolicy,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution,
        testingStubProfile: DecisionTestingStubProfile?,
        envelope: DecisionIntelligencePromptContract.PromptEnvelope,
        quarantine: @escaping (String) async -> Void
    ) async {
        guard policy.quarantinesExistingEntries else {
            return
        }

        for provider in relevantCacheProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile
        ) {
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider,
                envelope: envelope
            )
            await quarantine(cacheKey)
        }
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> QuickCheckResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        // Protective overlay must run whenever the stub provider
        // will NOT actually take over the refine result. The stub
        // is injected only when `testingStubProfile != nil AND
        // preference != .template` (see
        // `BehavioralAISubstrateBridge.swift:753-754`). So we
        // apply the overlay when EITHER no stub profile is set
        // (production path) OR the preference is `.template` —
        // in the latter case the stub wouldn't fire even with a
        // profile, and without the overlay we'd return nil on
        // protective turns.
        if (testingStubProfile == nil || preference == .template),
           let eBrainTurn,
           shouldUseProtectiveOverlay(for: eBrainTurn) {
            return protectiveQuickResult(base: base, turn: eBrainTurn)
        }
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: base,
            input: input,
            strategy: adjustedStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let cachePolicy = horizonCachePolicy(for: brainState)
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext: ProviderRequestObservationContext = BASAppleHostProviderObservationBridge.context(
            kind: .quick,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: adjustedStrategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: substrateObservationKindID(for: .quick),
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: BehavioralAISubstrateBridge.providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                selectionNeedID: admissionDecision.selectionNeed?.rawValue,
                runtimeTimeBudgetMs: adjustedStrategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                narrativeOverride: providerObservationNarrative(for: .quick),
                prompt: envelope.debugPrompt,
                baselineOutputPreview: quickPreview(from: base),
                deterministicFallbackOutputPreview: quickPreview(from: base),
                recordsTemplatePinnedTrace: true
            )
        )
        await preemptivelyQuarantineCachesIfNeeded(
            policy: cachePolicy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            envelope: envelope,
            quarantine: { cacheKey in
                await responseCache.quarantineQuickResult(for: cacheKey)
            }
        )
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .quick,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            observationContext: observationContext,
            requestStart: requestStart,
            clock: clock,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await loadCachedResultIfAllowed(
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    load: { cacheKey in
                        await responseCache.quickResult(for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineQuickResult(for: cacheKey)
                    }
                )
            },
            assessCachedResult: { cached in
                providerAttemptVerdict(
                    kind: .quick,
                    outputPreview: quickPreview(from: cached),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            quarantineCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await responseCache.quarantineQuickResult(for: cacheKey)
            },
            invokeProvider: { provider in
                await provider.refineQuickResult(
                    base: base,
                    input: input,
                    strategy: adjustedStrategy,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState
                )
            },
            assessProviderResult: { refined in
                providerAttemptVerdict(
                    kind: .quick,
                    outputPreview: quickPreview(from: refined),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            storeResolvedResult: { provider, refined in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await storeCachedResultIfAllowed(
                    refined,
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    store: { refined, cacheKey in
                        await responseCache.storeQuickResult(refined, for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineQuickResult(for: cacheKey)
                    }
                )
            }
        )

        switch outcome {
        case .resolved(let resolution):
            return resolution.execution.result
        case .templatePinned, .admissionSkipped, .noResult:
            return nil
        }
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> BalanceBoardResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        // Protective overlay must run whenever the stub provider
        // will NOT actually take over the refine result. The stub
        // is injected only when `testingStubProfile != nil AND
        // preference != .template` (see
        // `BehavioralAISubstrateBridge.swift:753-754`). So we
        // apply the overlay when EITHER no stub profile is set
        // (production path) OR the preference is `.template` —
        // in the latter case the stub wouldn't fire even with a
        // profile, and without the overlay we'd return nil on
        // protective turns.
        if (testingStubProfile == nil || preference == .template),
           let eBrainTurn,
           shouldUseProtectiveOverlay(for: eBrainTurn) {
            return protectiveBalanceResult(base: base, turn: eBrainTurn)
        }
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: base,
            input: input,
            strategy: adjustedStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let cachePolicy = horizonCachePolicy(for: brainState)
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext: ProviderRequestObservationContext = BASAppleHostProviderObservationBridge.context(
            kind: .balance,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: adjustedStrategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: substrateObservationKindID(for: .balance),
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: BehavioralAISubstrateBridge.providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                selectionNeedID: admissionDecision.selectionNeed?.rawValue,
                runtimeTimeBudgetMs: adjustedStrategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                narrativeOverride: providerObservationNarrative(for: .balance),
                prompt: envelope.debugPrompt,
                baselineOutputPreview: balancePreview(from: base),
                deterministicFallbackOutputPreview: balancePreview(from: base),
                recordsTemplatePinnedTrace: true
            )
        )
        await preemptivelyQuarantineCachesIfNeeded(
            policy: cachePolicy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            envelope: envelope,
            quarantine: { cacheKey in
                await responseCache.quarantineBalanceResult(for: cacheKey)
            }
        )
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .balance,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            observationContext: observationContext,
            requestStart: requestStart,
            clock: clock,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await loadCachedResultIfAllowed(
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    load: { cacheKey in
                        await responseCache.balanceResult(for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineBalanceResult(for: cacheKey)
                    }
                )
            },
            assessCachedResult: { cached in
                providerAttemptVerdict(
                    kind: .balance,
                    outputPreview: balancePreview(from: cached),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            quarantineCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await responseCache.quarantineBalanceResult(for: cacheKey)
            },
            invokeProvider: { provider in
                await provider.refineBalanceResult(
                    base: base,
                    input: input,
                    strategy: adjustedStrategy,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState
                )
            },
            assessProviderResult: { refined in
                providerAttemptVerdict(
                    kind: .balance,
                    outputPreview: balancePreview(from: refined),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            storeResolvedResult: { provider, refined in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await storeCachedResultIfAllowed(
                    refined,
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    store: { refined, cacheKey in
                        await responseCache.storeBalanceResult(refined, for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineBalanceResult(for: cacheKey)
                    }
                )
            }
        )

        switch outcome {
        case .resolved(let resolution):
            return resolution.execution.result
        case .templatePinned, .admissionSkipped, .noResult:
            return nil
        }
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> MirrorResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        // Protective overlay must run whenever the stub provider
        // will NOT actually take over the refine result. The stub
        // is injected only when `testingStubProfile != nil AND
        // preference != .template` (see
        // `BehavioralAISubstrateBridge.swift:753-754`). So we
        // apply the overlay when EITHER no stub profile is set
        // (production path) OR the preference is `.template` —
        // in the latter case the stub wouldn't fire even with a
        // profile, and without the overlay we'd return nil on
        // protective turns.
        if (testingStubProfile == nil || preference == .template),
           let eBrainTurn,
           shouldUseProtectiveOverlay(for: eBrainTurn) {
            return protectiveMirrorResult(base: base, turn: eBrainTurn)
        }
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: base,
            input: input,
            strategy: adjustedStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let cachePolicy = horizonCachePolicy(for: brainState)
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext: ProviderRequestObservationContext = BASAppleHostProviderObservationBridge.context(
            kind: .mirror,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: adjustedStrategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: substrateObservationKindID(for: .mirror),
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: BehavioralAISubstrateBridge.providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                selectionNeedID: admissionDecision.selectionNeed?.rawValue,
                runtimeTimeBudgetMs: adjustedStrategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                narrativeOverride: providerObservationNarrative(for: .mirror),
                prompt: envelope.debugPrompt,
                baselineOutputPreview: mirrorPreview(from: base),
                deterministicFallbackOutputPreview: mirrorPreview(from: base),
                recordsTemplatePinnedTrace: true
            )
        )
        await preemptivelyQuarantineCachesIfNeeded(
            policy: cachePolicy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            envelope: envelope,
            quarantine: { cacheKey in
                await responseCache.quarantineMirrorResult(for: cacheKey)
            }
        )
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .mirror,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            observationContext: observationContext,
            requestStart: requestStart,
            clock: clock,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await loadCachedResultIfAllowed(
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    load: { cacheKey in
                        await responseCache.mirrorResult(for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineMirrorResult(for: cacheKey)
                    }
                )
            },
            assessCachedResult: { cached in
                providerAttemptVerdict(
                    kind: .mirror,
                    outputPreview: mirrorPreview(from: cached),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            quarantineCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await responseCache.quarantineMirrorResult(for: cacheKey)
            },
            invokeProvider: { provider in
                await provider.refineMirrorResult(
                    base: base,
                    input: input,
                    strategy: adjustedStrategy,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState
                )
            },
            assessProviderResult: { refined in
                providerAttemptVerdict(
                    kind: .mirror,
                    outputPreview: mirrorPreview(from: refined),
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
            },
            storeResolvedResult: { provider, refined in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                await storeCachedResultIfAllowed(
                    refined,
                    cacheKey: cacheKey,
                    policy: cachePolicy,
                    store: { refined, cacheKey in
                        await responseCache.storeMirrorResult(refined, for: cacheKey)
                    },
                    quarantine: { cacheKey in
                        await responseCache.quarantineMirrorResult(for: cacheKey)
                    }
                )
            }
        )

        switch outcome {
        case .resolved(let resolution):
            return resolution.execution.result
        case .templatePinned, .admissionSkipped, .noResult:
            return nil
        }
    }

    static func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> ReminderSelectionCandidate? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let selection = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: selection.prompt)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: selection.prompt)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let clippedCandidates = selection.candidates
        let selectionAssessment = ReminderSelectionPolicy.assessSelectionNeed(
            candidates: clippedCandidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
        guard !clippedCandidates.isEmpty else { return nil }
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: selection.prompt)
        } ?? DecisionIntelligenceAdmissionController.decide(
            for: selection.prompt,
            selectionCandidateCount: clippedCandidates.count,
            selectionAssessment: selectionAssessment
        )
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext: ProviderRequestObservationContext = BASAppleHostProviderObservationBridge.context(
            kind: .reminder,
            frontstageState: selection.prompt.frontstageState,
            contextState: nil,
            neuralState: nil,
            brainState: nil,
            runtimeStrategy: strategy,
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision,
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: substrateObservationKindID(for: .reminder),
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: BehavioralAISubstrateBridge.providerProfiles(),
                promptBudget: selection.prompt.budget,
                brainState: nil,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                selectionNeedID: admissionDecision.selectionNeed?.rawValue,
                runtimeTimeBudgetMs: strategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                narrativeOverride: providerObservationNarrative(for: .reminder),
                prompt: selection.prompt.debugPrompt,
                baselineOutputPreview: "Deterministic reminder ordering kept",
                deterministicFallbackOutputPreview: "No reminder selected",
                recordsTemplatePinnedTrace: false
            )
        )
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .reminder,
            strategy: strategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            observationContext: observationContext,
            requestStart: requestStart,
            clock: clock,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: selection.prompt
                )
                let cached = await responseCache.reminder(for: cacheKey)
                guard let cached,
                      clippedCandidates.contains(where: { $0.id == cached.id }) else {
                    return nil
                }
                return cached
            },
            assessCachedResult: { cached in
                providerAttemptVerdict(
                    kind: .reminder,
                    outputPreview: selectionPreview(from: cached),
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    selectionMode: mode
                )
            },
            quarantineCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: selection.prompt
                )
                await responseCache.quarantineReminder(for: cacheKey)
            },
            invokeProvider: { provider in
                await provider.pickReminder(
                    from: clippedCandidates,
                    scenario: scenario,
                    prompt: prompt,
                    mode: mode,
                    strategy: strategy
                )
            },
            assessProviderResult: { selected in
                providerAttemptVerdict(
                    kind: .reminder,
                    outputPreview: selectionPreview(from: selected),
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    selectionMode: mode
                )
            },
            storeResolvedResult: { provider, selected in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: selection.prompt
                )
                await responseCache.storeReminder(selected, for: cacheKey)
            }
        )

        switch outcome {
        case .resolved(let resolution):
            return resolution.execution.result
        case .templatePinned, .admissionSkipped, .noResult:
            return nil
        }
    }

    static func defaultStatusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        registry.statusesByKind()
    }

    private static func quickPreview(from result: QuickCheckResult) -> String {
        BASAppleProviderReleaseAdapter.keyedPreview(
            fields: BeforeProductLanguage.Preview.primaryFields(from: result)
        )
    }

    private static func balancePreview(from result: BalanceBoardResult) -> String {
        BASAppleProviderReleaseAdapter.keyedPreview(
            fields: BeforeProductLanguage.Preview.comparativeFields(from: result)
        )
    }

    private static func mirrorPreview(from result: MirrorResult) -> String {
        BASAppleProviderReleaseAdapter.keyedPreview(
            fields: BeforeProductLanguage.Preview.reflectiveFields(from: result)
        )
    }

    private static func selectionPreview(from candidate: ReminderSelectionCandidate) -> String {
        BASAppleProviderReleaseAdapter.selectionPreview(content: candidate.content)
    }

    private static func providerAttemptVerdict(
        kind: DecisionIntelligenceTraceKind,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: DecisionBrainState?,
        selectionMode: DecisionMode? = nil
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        BASAppleProviderReleaseAdapter.verdict(
            traceKindRawValue: kind.substrateKindID,
            outputPreview: outputPreview,
            kernelSnapshot: kernelSnapshot,
            brainState: brainState,
            selectionSurfaceModeRawValue: selectionMode?.substrateModeID,
            structuredTruthBehavior: BeforeProductCompatibility.referencePromptBehavior.structuredTruthBehavior
        )
    }

    private static func elapsedMilliseconds(
        since start: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> Double {
        let duration = start.duration(to: clock.now)
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return (seconds + attoseconds) * 1_000
    }

}

extension BASActionPermitMode {
    var isProtective: Bool {
        switch self {
        case .delay, .draftOnly, .localOnly, .block, .replace, .escalate:
            return true
        case .answer, .mirror, .compare:
            return false
        }
    }
}

extension BASRenderedOutput {
    var protectiveSurfaceMode: BASActionPermitMode? {
        if mode.isProtective {
            return mode
        }

        guard let guide = surfaceGuide else {
            return nil
        }

        if let stackedProtective = guide.stackedModes.first(where: { $0.isProtective }) {
            return stackedProtective
        }
        if guide.sovereignEscalationHint != nil {
            return .escalate
        }
        if guide.delayReservation != nil || guide.delayWindow != nil || guide.agency.delayAvailable {
            return .delay
        }
        if guide.agency.prefersDraftOnly {
            return .draftOnly
        }
        if guide.agency.localOnlyPreferred {
            return .localOnly
        }
        if guide.protectiveSubstitute != nil {
            return .replace
        }

        return nil
    }

    var hasProtectiveSurfaceGuidance: Bool {
        protectiveSurfaceMode != nil
    }
}

extension BASEBrainTurnResult {
    var protectiveSurfaceMode: BASActionPermitMode? {
        if actionPermit.mode.isProtective {
            return actionPermit.mode
        }
        if let stackedProtective = actionPermit.stackedModes.first(where: { $0.isProtective }) {
            return stackedProtective
        }
        if let renderedProtectiveMode = renderedOutput.protectiveSurfaceMode {
            return renderedProtectiveMode
        }
        if actionPermit.delayWindow != nil {
            return .delay
        }
        if actionPermit.substituteRequired {
            return .replace
        }

        return nil
    }

    var hasProtectiveSurfaceGuidance: Bool {
        protectiveSurfaceMode != nil
    }
}

extension DecisionRuntimeGear {
    var rank: Int {
        switch self {
        case .low:
            return 0
        case .balanced:
            return 1
        case .high:
            return 2
        }
    }
}

extension DecisionAdaptiveTaskStrategy {
    func clamped(using eBrainTurn: BASEBrainTurnResult?) -> DecisionAdaptiveTaskStrategy {
        guard let eBrainTurn else { return self }

        let budget = eBrainTurn.budgetFrame
        let hasActiveLease = eBrainTurn.runLease?.isActive(asOf: eBrainTurn.runtimeTrace.recordedAt) ?? budget.hasActiveLease(asOf: eBrainTurn.runtimeTrace.recordedAt)
        let gearCap: DecisionRuntimeGear = switch budget.runMode {
        case .dormant, .pulse, .sentinel, .recovery, .quarantine, .lockdown:
            .low
        case .engage, .reflect:
            .balanced
        case .deepLoop:
            hasActiveLease ? .high : .balanced
        case .guard:
            .low
        }

        let runtimeGear = [runtimeGear, gearCap].min { $0.rank < $1.rank } ?? runtimeGear
        let cappedContextBudget = min(contextBudget, max(40, budget.maxCandidates * 100 + budget.maxLoops * 60))
        let cappedOutputBudget = min(outputCharacterBudget, max(80, budget.maxDecodeTokens * 2))
        let cappedTimeBudget = min(timeBudgetMs, max(250, budget.maxLoops * 320 + budget.retrievalDepth * 120))
        let toolBudgetCap: Int = switch budget.runMode {
        case .pulse, .sentinel, .recovery, .quarantine, .lockdown:
            0
        case .guard:
            1
        case .engage, .reflect:
            min(toolCallBudget, 1)
        case .deepLoop:
            hasActiveLease ? toolCallBudget : 0
        case .dormant:
            0
        }
        let cappedToolBudget = min(toolCallBudget, toolBudgetCap)
        let cappedRetrievalBudget = min(retrievalItemBudget, max(1, budget.retrievalDepth + max(0, budget.maxCandidates / 2)))

        return DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy,
            runtimeGear: runtimeGear,
            preferredProvider: preferredProvider,
            contextBudget: cappedContextBudget,
            outputCharacterBudget: cappedOutputBudget,
            timeBudgetMs: cappedTimeBudget,
            toolCallBudget: cappedToolBudget,
            retrievalItemBudget: cappedRetrievalBudget,
            retrievalMode: retrievalMode,
            thinkingMode: thinkingMode,
            outputMode: outputMode,
            tone: tone,
            actionSpace: actionSpace,
            responseLanguage: responseLanguage,
            allowsModelInvocation: allowsModelInvocation
        )
    }
}

private extension DecisionIntelligenceProviderPipeline {
    static func shouldUseProtectiveOverlay(
        for turn: BASEBrainTurnResult
    ) -> Bool {
        turn.hasProtectiveSurfaceGuidance
    }

    static func protectiveQuickResult(
        base: QuickCheckResult,
        turn: BASEBrainTurnResult
    ) -> QuickCheckResult {
        let rendered = turn.renderedOutput
        let verdict = protectiveVerdict(for: rendered, fallback: base.verdict)
        let primaryAction = protectivePrimaryAction(for: rendered, fallback: base.primaryAction)
        let secondaryActions = protectiveSecondaryActions(for: rendered, fallback: base.secondaryActions)

        return QuickCheckResult(
            currentPerspective: nonEmpty(rendered.headline) ?? base.currentPerspective,
            afterPerspective: nonEmpty(rendered.body) ?? base.afterPerspective,
            verdict: verdict,
            primaryAction: primaryAction,
            secondaryActions: secondaryActions
        )
    }

    static func protectiveBalanceResult(
        base: BalanceBoardResult,
        turn: BASEBrainTurnResult
    ) -> BalanceBoardResult {
        let rendered = turn.renderedOutput
        let nextAction = protectiveGuidanceLine(for: rendered) ?? base.nextAction
        return BalanceBoardResult(
            headline: nonEmpty(rendered.headline) ?? base.headline,
            summary: nonEmpty(rendered.body) ?? base.summary,
            focusTitle: base.focusTitle,
            focusDescription: base.focusDescription,
            nextAction: nextAction
        )
    }

    static func protectiveMirrorResult(
        base: MirrorResult,
        turn: BASEBrainTurnResult
    ) -> MirrorResult {
        let rendered = turn.renderedOutput
        let nextAction = protectiveGuidanceLine(for: rendered) ?? base.nextAction
        let nextActionTitle = protectiveNextActionTitle(for: rendered, fallback: base.nextActionTitle)
        return MirrorResult(
            headline: nonEmpty(rendered.headline) ?? base.headline,
            coreTension: nonEmpty(rendered.body) ?? base.coreTension,
            nextActionTitle: nextActionTitle,
            nextAction: nextAction
        )
    }

    static func protectiveVerdict(
        for rendered: BASRenderedOutput,
        fallback: CheckVerdict
    ) -> CheckVerdict {
        if let guide = rendered.surfaceGuide {
            if guide.sovereignEscalationHint != nil {
                return .notRecommended
            }
            if guide.agency.prefersDraftOnly || guide.agency.localOnlyPreferred || guide.agency.delayAvailable {
                return .pause
            }
        }

        return switch rendered.mode {
        case .delay, .draftOnly, .localOnly, .replace:
            .pause
        case .block, .escalate:
            .notRecommended
        case .compare, .mirror, .answer:
            fallback
        }
    }

    static func protectivePrimaryAction(
        for rendered: BASRenderedOutput,
        fallback: CheckAction
    ) -> CheckAction {
        if let guide = rendered.surfaceGuide {
            if guide.sovereignEscalationHint != nil {
                return .leaveStimulus
            }
            if guide.agency.prefersDraftOnly {
                return .decideTomorrow
            }
            if guide.agency.localOnlyPreferred {
                return .continueMindfully
            }
            if guide.agency.delayAvailable {
                return .wait90s
            }
        }

        return switch rendered.mode {
        case .delay:
            .wait90s
        case .draftOnly:
            .decideTomorrow
        case .localOnly:
            .continueMindfully
        case .block:
            .leaveStimulus
        case .escalate:
            .leaveStimulus
        case .replace:
            .decideTomorrow
        case .compare, .mirror, .answer:
            fallback
        }
    }

    static func protectiveSecondaryActions(
        for rendered: BASRenderedOutput,
        fallback: [CheckAction]
    ) -> [CheckAction] {
        if let guide = rendered.surfaceGuide {
            var actions: [CheckAction] = []
            if guide.sovereignEscalationHint != nil {
                actions += [.leaveStimulus, .wait90s]
            }
            if guide.agency.delayAvailable {
                actions += [.decideTomorrow, .continueMindfully]
            }
            if guide.agency.prefersDraftOnly {
                actions += [.wait90s, .continueMindfully]
            }
            if guide.agency.localOnlyPreferred {
                actions += [.continueMindfully, .decideTomorrow]
            }
            if actions.isEmpty == false {
                return uniqueActions(actions)
            }
        }

        return switch rendered.mode {
        case .delay:
            [.decideTomorrow, .continueMindfully]
        case .draftOnly:
            [.wait90s, .continueMindfully]
        case .localOnly:
            [.continueMindfully, .decideTomorrow]
        case .block:
            [.leaveStimulus, .decideTomorrow]
        case .escalate:
            [.leaveStimulus, .wait90s]
        case .replace:
            [.continueMindfully, .decideTomorrow]
        case .compare, .mirror, .answer:
            fallback
        }
    }

    static func protectiveGuidanceLine(for rendered: BASRenderedOutput) -> String? {
        if let action = rendered.alternativeActions.lazy.compactMap(nonEmpty).first {
            return action
        }
        if let substituteDescription = nonEmpty(rendered.surfaceGuide?.protectiveSubstitute?.description ?? "") {
            return substituteDescription
        }
        if let delayReservation = rendered.surfaceGuide?.delayReservation {
            return protectiveDelayGuidance(for: delayReservation)
        }
        if rendered.surfaceGuide?.agency.localOnlyPreferred == true {
            return "Keep the next step local and reversible."
        }
        if rendered.surfaceGuide?.agency.prefersDraftOnly == true {
            return "Keep the move in draft until the boundary is re-checked."
        }
        if rendered.surfaceGuide?.sovereignEscalationHint != nil {
            return "Pause release and escalate the decision boundary."
        }
        if rendered.surfaceGuide?.agency.requiresSecondCheck == true {
            return "Get a second confirmation before acting."
        }
        return nil
    }

    static func protectiveNextActionTitle(
        for rendered: BASRenderedOutput,
        fallback: String
    ) -> String {
        if let guide = rendered.surfaceGuide {
            if guide.sovereignEscalationHint != nil {
                return "Escalate the boundary"
            }
            if guide.agency.prefersDraftOnly {
                return "Keep it in draft"
            }
            if guide.agency.localOnlyPreferred {
                return "Keep it local"
            }
            if guide.agency.delayAvailable {
                return "Delay the move"
            }
            if guide.protectiveSubstitute != nil {
                return "Use the safer step"
            }
        }

        return switch rendered.mode {
        case .delay:
            "Delay the move"
        case .draftOnly:
            "Keep it in draft"
        case .localOnly:
            "Keep it local"
        case .block:
            "Hold the boundary"
        case .escalate:
            "Escalate the boundary"
        case .replace:
            "Use the safer step"
        case .compare, .mirror, .answer:
            fallback
        }
    }

    static func protectiveDelayGuidance(
        for reservation: BASDelayReservation
    ) -> String {
        switch reservation.delayType {
        case "cool_down":
            return "Take a cool-down window before deciding."
        case "evidence_wait":
            return "Wait for one more piece of evidence before deciding."
        default:
            return "Wait before taking the next step."
        }
    }

    static func uniqueActions(_ actions: [CheckAction]) -> [CheckAction] {
        var seen = Set<String>()
        return actions.filter { seen.insert($0.rawValue).inserted }
    }

    static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
