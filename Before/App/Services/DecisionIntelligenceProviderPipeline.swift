import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

enum DecisionIntelligenceProviderPipeline {
    private static let registry = DecisionIntelligenceProviderRegistry.shared
    private static let responseCache = DecisionIntelligenceResponseCache.shared
    private static let preferenceOrderings: [BASProviderPreferenceOrdering] = [
        BASProviderPreferenceOrdering(
            preferredProviderID: DecisionModelProviderKind.gemmaE4B.rawValue,
            orderedProviderIDs: [
                DecisionModelProviderKind.gemmaE4B.rawValue,
                DecisionModelProviderKind.foundationModels.rawValue
            ]
        ),
        BASProviderPreferenceOrdering(
            preferredProviderID: DecisionModelProviderKind.openModel.rawValue,
            orderedProviderIDs: [
                DecisionModelProviderKind.openModel.rawValue,
                DecisionModelProviderKind.gemmaE4B.rawValue,
                DecisionModelProviderKind.foundationModels.rawValue
            ]
        ),
        BASProviderPreferenceOrdering(
            preferredProviderID: DecisionModelProviderKind.foundationModels.rawValue,
            orderedProviderIDs: [
                DecisionModelProviderKind.foundationModels.rawValue,
                DecisionModelProviderKind.gemmaE4B.rawValue
            ]
        ),
        BASProviderPreferenceOrdering(
            preferredProviderID: DecisionModelProviderKind.template.rawValue,
            orderedProviderIDs: [
                DecisionModelProviderKind.template.rawValue
            ]
        )
    ]

    static func orderedKinds(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true,
        excluding suspendedKinds: Set<DecisionModelProviderKind> = []
    ) -> [DecisionModelProviderKind] {
        BASProviderOrderingResolver.orderedProviderIDs(
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: DecisionModelProviderKind.template.rawValue,
            preferenceOrderings: preferenceOrderings,
            suspendedProviderIDs: Set(suspendedKinds.map(\.rawValue))
        )
        .compactMap(DecisionModelProviderKind.init(rawValue:))
    }

    static func runtimeStatus(
        preferences: BeforePreferences,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = defaultStatusesByKind(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) -> DecisionModelRuntimeStatus {
        let preferred = preferences.preferredIntelligenceProvider.kind
        let plan = BASRuntimeAvailabilityResolver.resolve(
            preferredProviderID: preferred.rawValue,
            allowFallbacks: preferences.allowModelFallbacks,
            runtimeEnabled: preferences.onDeviceIntelligenceMode.isEnabled,
            deterministicProviderID: DecisionModelProviderKind.template.rawValue,
            orderedProviderIDs: orderedKinds(
                for: preferences.preferredIntelligenceProvider,
                allowFallbacks: preferences.allowModelFallbacks
            ).map(\.rawValue),
            statusesByID: Dictionary(
                uniqueKeysWithValues: statusesByKind.map { entry in
                    (
                        entry.key.rawValue,
                        BASProviderStatusRecord(
                            providerID: entry.key.rawValue,
                            isAvailable: entry.value.isAvailable,
                            title: entry.value.title,
                            detail: entry.value.detail
                        )
                    )
                }
            ),
            testingOverrideProviderID: testingStubProfile.map { _ in DecisionModelProviderKind.testingStub.rawValue }
        )

        let active = DecisionModelProviderKind(rawValue: plan.activeProviderID) ?? .template
        let fallback = plan.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:))
        let detail = BASRuntimeAvailabilityNarrator.detail(
            plan: plan,
            allowFallbacks: preferences.allowModelFallbacks,
            statusesByID: Dictionary(
                uniqueKeysWithValues: statusesByKind.map { entry in
                    (
                        entry.key.rawValue,
                        BASProviderStatusRecord(
                            providerID: entry.key.rawValue,
                            isAvailable: entry.value.isAvailable,
                            title: entry.value.title,
                            detail: entry.value.detail
                        )
                    )
                }
            ),
            orderedProviderIDs: orderedKinds(
                for: preferences.preferredIntelligenceProvider,
                allowFallbacks: preferences.allowModelFallbacks
            ).map(\.rawValue),
            testingOverrideTitle: testingStubProfile?.title
        )

        return DecisionModelRuntimeStatus(
            preferred: preferred,
            active: active,
            fallback: fallback,
            detail: detail
        )
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> QuickCheckResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard preference != .template else {
            await recordTelemetry(
                kind: .quick,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy
            )
            recordTrace(
                kind: .quick,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: quickPreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for quick refinement."
            )
            return nil
        }

        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .quick,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .quick,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: quickPreview(from: base),
                detail: "Admission controller skipped quick refinement. \(admissionDecision.reason)"
            )
            return nil
        }

        let providers = await orderedProviders(
            task: .quick,
            strategy: strategy,
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let providerSelectionMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.quickResult(for: cacheKey) {
                let preview = quickPreview(from: cached)
                let releaseDecision = releaseDecision(
                    kind: .quick,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await responseCache.quarantineQuickResult(for: cacheKey)
                    recordTrace(
                        kind: .quick,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: cachedDetail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "cached quick refinement"
                        )
                    )
                    continue
                }
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .cacheHit
                )
                await recordTelemetry(
                    kind: .quick,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineQuickResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
                let preview = quickPreview(from: refined)
                let releaseDecision = releaseDecision(
                    kind: .quick,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await DecisionIntelligenceCircuitBreaker.shared.record(
                        provider: provider.kind,
                        event: .providerFailure
                    )
                    recordTrace(
                        kind: .quick,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: detail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "provider quick refinement"
                        )
                    )
                    continue
                }
                await responseCache.storeQuickResult(refined, for: cacheKey)
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .providerSuccess(
                        kind: .quick,
                        durationMs: elapsedMilliseconds(since: requestStart, clock: clock)
                    )
                )
                await recordTelemetry(
                    kind: .quick,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }

            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: provider.kind,
                event: .providerFailure
            )
        }

        await recordTelemetry(
            kind: .quick,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            lifecycleMetrics: lifecycleMetrics(
                requestStart: requestStart,
                clock: clock,
                promptPreparedMs: promptPreparedMs,
                admissionEvaluatedMs: admissionEvaluatedMs,
                providerSelectionMs: providerSelectionMs
            ),
            promptBudget: envelope.budget,
            runtimeStrategy: strategy,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .quick,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            allowFallbacks: allowFallbacks,
            runtimeStrategy: strategy,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: quickPreview(from: base),
            detail: deterministicFallbackDetail(
                base: "No provider returned a refined quick result, so Before kept the deterministic copy.",
                suspendedKinds: suspendedKinds
            )
        )
        return nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> BalanceBoardResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard preference != .template else {
            await recordTelemetry(
                kind: .balance,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy
            )
            recordTrace(
                kind: .balance,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: balancePreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for balance refinement."
            )
            return nil
        }

        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .balance,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .balance,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: balancePreview(from: base),
                detail: "Admission controller skipped balance refinement. \(admissionDecision.reason)"
            )
            return nil
        }

        let providers = await orderedProviders(
            task: .balance,
            strategy: strategy,
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let providerSelectionMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.balanceResult(for: cacheKey) {
                let preview = balancePreview(from: cached)
                let releaseDecision = releaseDecision(
                    kind: .balance,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await responseCache.quarantineBalanceResult(for: cacheKey)
                    recordTrace(
                        kind: .balance,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: cachedDetail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "cached balance refinement"
                        )
                    )
                    continue
                }
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .cacheHit
                )
                await recordTelemetry(
                    kind: .balance,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineBalanceResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
                let preview = balancePreview(from: refined)
                let releaseDecision = releaseDecision(
                    kind: .balance,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await DecisionIntelligenceCircuitBreaker.shared.record(
                        provider: provider.kind,
                        event: .providerFailure
                    )
                    recordTrace(
                        kind: .balance,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: detail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "provider balance refinement"
                        )
                    )
                    continue
                }
                await responseCache.storeBalanceResult(refined, for: cacheKey)
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .providerSuccess(
                        kind: .balance,
                        durationMs: elapsedMilliseconds(since: requestStart, clock: clock)
                    )
                )
                await recordTelemetry(
                    kind: .balance,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }

            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: provider.kind,
                event: .providerFailure
            )
        }

        await recordTelemetry(
            kind: .balance,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            lifecycleMetrics: lifecycleMetrics(
                requestStart: requestStart,
                clock: clock,
                promptPreparedMs: promptPreparedMs,
                admissionEvaluatedMs: admissionEvaluatedMs,
                providerSelectionMs: providerSelectionMs
            ),
            promptBudget: envelope.budget,
            runtimeStrategy: strategy,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .balance,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            allowFallbacks: allowFallbacks,
            runtimeStrategy: strategy,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: balancePreview(from: base),
            detail: deterministicFallbackDetail(
                base: "No provider returned a refined balance board, so Before kept the deterministic copy.",
                suspendedKinds: suspendedKinds
            )
        )
        return nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> MirrorResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        let promptPreparedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard preference != .template else {
            await recordTelemetry(
                kind: .mirror,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy
            )
            recordTrace(
                kind: .mirror,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: mirrorPreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for mirror refinement."
            )
            return nil
        }

        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .mirror,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs
                ),
                promptBudget: envelope.budget,
                runtimeStrategy: strategy,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .mirror,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState,
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                outputPreview: mirrorPreview(from: base),
                detail: "Admission controller skipped mirror refinement. \(admissionDecision.reason)"
            )
            return nil
        }

        let providers = await orderedProviders(
            task: .mirror,
            strategy: strategy,
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let providerSelectionMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.mirrorResult(for: cacheKey) {
                let preview = mirrorPreview(from: cached)
                let releaseDecision = releaseDecision(
                    kind: .mirror,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await responseCache.quarantineMirrorResult(for: cacheKey)
                    recordTrace(
                        kind: .mirror,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: cachedDetail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "cached mirror refinement"
                        )
                    )
                    continue
                }
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .cacheHit
                )
                await recordTelemetry(
                    kind: .mirror,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineMirrorResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
                let preview = mirrorPreview(from: refined)
                let releaseDecision = releaseDecision(
                    kind: .mirror,
                    outputPreview: preview,
                    kernelSnapshot: envelope.assembly.kernelSnapshot,
                    brainState: brainState
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await DecisionIntelligenceCircuitBreaker.shared.record(
                        provider: provider.kind,
                        event: .providerFailure
                    )
                    recordTrace(
                        kind: .mirror,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: envelope.frontstageState,
                        contextState: contextState,
                        neuralState: neuralState,
                        brainState: brainState,
                        promptBudget: envelope.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: envelope.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: detail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "provider mirror refinement"
                        )
                    )
                    continue
                }
                await responseCache.storeMirrorResult(refined, for: cacheKey)
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .providerSuccess(
                        kind: .mirror,
                        durationMs: elapsedMilliseconds(since: requestStart, clock: clock)
                    )
                )
                await recordTelemetry(
                    kind: .mirror,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: envelope.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    brainState: brainState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: envelope.debugPrompt,
                    outputPreview: preview,
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }

            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: provider.kind,
                event: .providerFailure
            )
        }

        await recordTelemetry(
            kind: .mirror,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            lifecycleMetrics: lifecycleMetrics(
                requestStart: requestStart,
                clock: clock,
                promptPreparedMs: promptPreparedMs,
                admissionEvaluatedMs: admissionEvaluatedMs,
                providerSelectionMs: providerSelectionMs
            ),
            promptBudget: envelope.budget,
            runtimeStrategy: strategy,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .mirror,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            allowFallbacks: allowFallbacks,
            runtimeStrategy: strategy,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: mirrorPreview(from: base),
            detail: deterministicFallbackDetail(
                base: "No provider returned a refined mirror, so Before kept the deterministic copy.",
                suspendedKinds: suspendedKinds
            )
        )
        return nil
    }

    static func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
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
        let reminderSelectionAssessment = ReminderSelectionPolicy.assessSelectionNeed(
            candidates: clippedCandidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
        guard !clippedCandidates.isEmpty else { return nil }
        guard preference != .template else {
            await recordTelemetry(
                kind: .reminder,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs
                ),
                promptBudget: selection.prompt.budget,
                runtimeStrategy: strategy
            )
            return nil
        }
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: selection.prompt)
        } ?? DecisionIntelligenceAdmissionController.decide(
            for: selection.prompt,
            reminderCandidateCount: clippedCandidates.count,
            reminderSelectionAssessment: reminderSelectionAssessment
        )
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .reminder,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs
                ),
                promptBudget: selection.prompt.budget,
                runtimeStrategy: strategy,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .reminder,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                runtimeStrategy: strategy,
                frontstageState: selection.prompt.frontstageState,
                promptBudget: selection.prompt.budget,
                admissionDecision: admissionDecision,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: selection.prompt.debugPrompt,
                outputPreview: "Deterministic reminder ordering kept",
                detail: "Admission controller skipped reminder selection. \(admissionDecision.reason)"
            )
            return nil
        }
        let providers = await orderedProviders(
            task: .reminder,
            strategy: strategy,
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let providerSelectionMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: selection.prompt
            )
            if let cached = await responseCache.reminder(for: cacheKey),
               clippedCandidates.contains(where: { $0.id == cached.id }) {
                let preview = reminderPreview(from: cached)
                let releaseDecision = releaseDecision(
                    kind: .reminder,
                    outputPreview: preview,
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    reminderMode: mode
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await responseCache.quarantineReminder(for: cacheKey)
                    recordTrace(
                        kind: .reminder,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: selection.prompt.frontstageState,
                        promptBudget: selection.prompt.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: selection.prompt.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: cachedDetail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "cached reminder selection"
                        )
                    )
                    continue
                }
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .cacheHit
                )
                await recordTelemetry(
                    kind: .reminder,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: selection.prompt.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: selection.prompt.frontstageState,
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: selection.prompt.debugPrompt,
                    outputPreview: preview,
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let selected = await provider.pickReminder(
                from: clippedCandidates,
                scenario: scenario,
                prompt: prompt,
                mode: mode,
                strategy: strategy
            ) {
                let preview = reminderPreview(from: selected)
                let releaseDecision = releaseDecision(
                    kind: .reminder,
                    outputPreview: preview,
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    reminderMode: mode
                )
                let consistencyCheck = releaseDecision.consistencyCheck
                if releaseDecision.kind != .allow, let consistencyCheck {
                    await DecisionIntelligenceCircuitBreaker.shared.record(
                        provider: provider.kind,
                        event: .providerFailure
                    )
                    recordTrace(
                        kind: .reminder,
                        preferredProvider: preference.kind,
                        activeProvider: provider.kind,
                        attemptedProviders: actualAttemptedKinds,
                        allowFallbacks: allowFallbacks,
                        runtimeStrategy: strategy,
                        frontstageState: selection.prompt.frontstageState,
                        promptBudget: selection.prompt.budget,
                        admissionDecision: admissionDecision,
                        semanticPromptFingerprint: semanticPromptFingerprint,
                        stablePrefixFingerprint: stablePrefixFingerprint,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        prompt: selection.prompt.debugPrompt,
                        outputPreview: preview,
                        detail: rejectedConsistencyDetail(
                            base: detail(
                                preferred: preference.kind,
                                active: provider.kind,
                                allowFallbacks: allowFallbacks
                            ),
                            result: consistencyCheck,
                            source: "provider reminder selection"
                        )
                    )
                    continue
                }
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider.kind,
                    event: .providerSuccess(
                        kind: .reminder,
                        durationMs: elapsedMilliseconds(since: requestStart, clock: clock)
                    )
                )
                await responseCache.storeReminder(selected, for: cacheKey)
                await recordTelemetry(
                    kind: .reminder,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    lifecycleMetrics: lifecycleMetrics(
                        requestStart: requestStart,
                        clock: clock,
                        promptPreparedMs: promptPreparedMs,
                        admissionEvaluatedMs: admissionEvaluatedMs,
                        providerSelectionMs: providerSelectionMs
                    ),
                    promptBudget: selection.prompt.budget,
                    runtimeStrategy: strategy,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    allowFallbacks: allowFallbacks,
                    runtimeStrategy: strategy,
                    frontstageState: selection.prompt.frontstageState,
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    consistencyCheck: consistencyCheck,
                    prompt: selection.prompt.debugPrompt,
                    outputPreview: preview,
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return selected
            }

            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: provider.kind,
                event: .providerFailure
            )
        }

        await recordTelemetry(
            kind: .reminder,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            lifecycleMetrics: lifecycleMetrics(
                requestStart: requestStart,
                clock: clock,
                promptPreparedMs: promptPreparedMs,
                admissionEvaluatedMs: admissionEvaluatedMs,
                providerSelectionMs: providerSelectionMs
            ),
            promptBudget: selection.prompt.budget,
            runtimeStrategy: strategy,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .reminder,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            allowFallbacks: allowFallbacks,
            runtimeStrategy: strategy,
            frontstageState: selection.prompt.frontstageState,
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: selection.prompt.debugPrompt,
            outputPreview: "No reminder selected",
            detail: deterministicFallbackDetail(
                base: "No provider returned a reminder selection, so Before kept the deterministic reminder ordering.",
                suspendedKinds: suspendedKinds
            )
        )
        return nil
    }

    static func defaultStatusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        registry.statusesByKind()
    }

    private static func orderedProviders(
        task: DecisionIntelligenceTraceKind,
        strategy: DecisionAdaptiveTaskStrategy?,
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile?
    ) async -> [any DecisionIntelligenceProviding] {
        let suspendedKinds = Set(await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders)
        let orderedProviderIDs = DecisionIntelligenceTaskRouter.orderedKinds(
            for: task,
            preference: preference,
            allowFallbacks: allowFallbacks,
            excluding: suspendedKinds,
            registry: registry,
            strategy: strategy
        ).map(\.rawValue)
        let testingOverrideProvider: (any DecisionIntelligenceProviding)? = testingStubProfile.flatMap { profile in
            preference != .template ? TestingDecisionIntelligenceProvider(profile: profile) : nil
        }
        return BASExecutableProviderResolver.resolve(
            orderedProviderIDs: orderedProviderIDs,
            testingOverrideProvider: testingOverrideProvider,
            providerID: { $0.kind.rawValue },
            providerForID: { providerID in
                DecisionModelProviderKind(rawValue: providerID).flatMap(registry.provider(for:))
            },
            isAvailable: { $0.availabilityStatus.isAvailable }
        ).providers
    }

    private static func deterministicFallbackDetail(
        base: String,
        suspendedKinds: [DecisionModelProviderKind]
    ) -> String {
        guard !suspendedKinds.isEmpty else { return base }
        let titles = suspendedKinds.map(\.title).joined(separator: ", ")
        return "\(base) Active runtime cooldown: \(titles)."
    }

    private static func recordTrace(
        kind: DecisionIntelligenceTraceKind,
        preferredProvider: DecisionModelProviderKind,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        allowFallbacks: Bool,
        runtimeStrategy: DecisionAdaptiveTaskStrategy? = nil,
        frontstageState: DecisionFrontstageState? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        consistencyCheck: BASConsistencyCheckResult? = nil,
        consistencyRejected: Bool = false,
        prompt: String,
        outputPreview: String,
        detail: String
    ) {
        let allowsSensitivePayload = DecisionIntelligenceTracePrivacy.allowsSensitivePayload()
        let storedPrompt = allowsSensitivePayload
            ? prompt
            : DecisionIntelligenceTracePrivacy.sanitizedPrompt(
                detail: detail,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                promptBudget: promptBudget
            )
        let storedOutputPreview = allowsSensitivePayload
            ? outputPreview
            : DecisionIntelligenceTracePrivacy.sanitizedOutputPreview(outputPreview: outputPreview)

        let trace = DecisionIntelligenceTrace(
            kind: kind,
            preferredProvider: preferredProvider,
            activeProvider: activeProvider,
            attemptedProviders: attemptedProviders,
            allowFallbacks: allowFallbacks,
            usedFallback: activeProvider != nil && activeProvider != preferredProvider,
            frontstageState: frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: runtimeStrategy,
            promptBudget: promptBudget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            consistencyCheck: consistencyCheck,
            consistencyRejected: consistencyRejected,
            prompt: storedPrompt,
            outputPreview: storedOutputPreview,
            detail: detail
        )

        Task { @MainActor in
            DecisionIntelligenceDebugStore.shared.record(trace)
        }
    }

    private static func detail(
        preferred: DecisionModelProviderKind,
        active: DecisionModelProviderKind,
        allowFallbacks: Bool
    ) -> String {
        let base: String
        if active == preferred {
            base = allowFallbacks
                ? "Before used the preferred provider without needing a fallback."
                : "Before used the pinned provider with fallback disabled."
        } else {
            base = "Before switched away from \(preferred.title) and used \(active.title) for this refinement."
        }

        guard active == .gemmaE4B else { return base }

        let resolution = GemmaE4BIntelligenceService.backendResolution(
            policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
        return "\(base) \(resolution.title): \(resolution.detail)"
    }

    private static func cachedDetail(
        preferred: DecisionModelProviderKind,
        active: DecisionModelProviderKind,
        allowFallbacks: Bool
    ) -> String {
        detail(preferred: preferred, active: active, allowFallbacks: allowFallbacks)
            + " Before served the response from the structured prompt cache instead of recomputing it."
    }

    private static func quickPreview(from result: QuickCheckResult) -> String {
        "Current: \(result.currentPerspective)\nAfter: \(result.afterPerspective)"
    }

    private static func balancePreview(from result: BalanceBoardResult) -> String {
        "Headline: \(result.headline)\nFocus: \(result.focusDescription)\nNext: \(result.nextAction)"
    }

    private static func mirrorPreview(from result: MirrorResult) -> String {
        "Headline: \(result.headline)\nTension: \(result.coreTension)\nNext: \(result.nextAction)"
    }

    private static func reminderPreview(from candidate: ReminderSelectionCandidate) -> String {
        candidate.content
    }

    private static func releaseDecision(
        kind: DecisionIntelligenceTraceKind,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: DecisionBrainState?,
        reminderMode: DecisionMode? = nil
    ) -> BASCognitionKernelReleaseDecision {
        BASExecutionGovernance.releaseDecision(
            for: BASReleaseEvaluationRequest(
                kind: basTraceKind(for: kind),
                outputPreview: outputPreview,
                kernelSnapshot: kernelSnapshot,
                truthStateFallback: DecisionIntelligencePromptContract.consistencyTruthState(
                    for: kind,
                    brainState: brainState,
                    reminderMode: reminderMode
                ),
                referencedFacts: brainState?.activeGoals.first.map { ["current_goal": $0] } ?? [:]
            )
        )
    }

    private static func basTraceKind(
        for kind: DecisionIntelligenceTraceKind
    ) -> BASAdaptiveTraceKind {
        switch kind {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }

    private static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        let violations = result.violations
            .prefix(3)
            .map(\.message)
            .joined(separator: " ")
        return "\(base) Consistency harness rejected the \(source). \(violations)"
    }

    private static func recordTelemetry(
        kind: DecisionIntelligenceTraceKind,
        outcome: DecisionIntelligenceRequestOutcome,
        preferredProvider: DecisionModelProviderKind,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        durationMs: Double,
        lifecycleMetrics: DecisionRequestLifecycleMetrics? = nil,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        runtimeStrategy: DecisionAdaptiveTaskStrategy? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil
    ) async {
        await DecisionIntelligenceTelemetryStore.shared.record(
            kind: kind,
            outcome: outcome,
            activeProvider: activeProvider,
            attemptedProviders: attemptedProviders,
            usedFallback: activeProvider != nil && activeProvider != preferredProvider,
            durationMs: durationMs,
            lifecycleMetrics: lifecycleMetrics,
            promptBudget: promptBudget,
            runtimeStrategy: runtimeStrategy,
            admissionDecision: admissionDecision,
            gemmaBackendResolution: activeProvider == .gemmaE4B
                ? GemmaE4BIntelligenceService.backendResolution(
                    policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                )
                : nil
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

    private static func lifecycleMetrics(
        requestStart: ContinuousClock.Instant,
        clock: ContinuousClock,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerSelectionMs: Double? = nil
    ) -> DecisionRequestLifecycleMetrics {
        let firstPresentableMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let admissionStageMs = max(0, (admissionEvaluatedMs ?? promptPreparedMs) - promptPreparedMs)
        let providerStageMs = max(
            0,
            (providerSelectionMs ?? (admissionEvaluatedMs ?? promptPreparedMs)) -
                (admissionEvaluatedMs ?? promptPreparedMs)
        )
        let executionMs = max(0, firstPresentableMs - (providerSelectionMs ?? firstPresentableMs))

        return DecisionRequestLifecycleMetrics(
            promptAssemblyMs: max(0, promptPreparedMs),
            admissionEvaluationMs: admissionStageMs,
            providerSelectionMs: providerStageMs,
            firstPresentableMs: max(0, firstPresentableMs),
            executionMs: executionMs
        )
    }
}
