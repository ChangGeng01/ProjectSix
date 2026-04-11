import Foundation
import BASAppleAdapters
import BASOrchestration
import BASObservability
import BASPolicy
import BASRuntimeCore

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

    static func orderedKinds(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true,
        excluding suspendedKinds: Set<DecisionModelProviderKind> = []
    ) -> [DecisionModelProviderKind] {
        BASReferenceProviderRuntime.orderedProviderIDs(
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
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
        let summary = BASAppleProviderRuntimeStatusAdapter.runtimeStatus(
            from: BASAppleProviderRuntimeStatusInput(
                preferredProviderID: preferred.rawValue,
                allowFallbacks: preferences.allowModelFallbacks,
                runtimeEnabled: preferences.onDeviceIntelligenceMode.isEnabled,
                statusesByID: substrateStatuses(statusesByKind),
                testingOverrideEnabled: testingStubProfile != nil,
                testingOverrideTitle: testingStubProfile?.title
            )
        )
        let active = DecisionModelProviderKind(rawValue: summary.activeProviderID) ?? .template
        let fallback = summary.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:))

        return DecisionModelRuntimeStatus(
            preferred: preferred,
            active: active,
            fallback: fallback,
            detail: summary.detail
        )
    }

    static func substrateStatuses(
        _ statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus]
    ) -> [String: BASProviderStatusRecord] {
        Dictionary(
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
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext = ProviderRequestObservationContext(
            kind: .quick,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: strategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            substrateContext: BASAppleProviderObservationContextBuilder.build(
                from: BASAppleProviderObservationSourceInput(
                kind: DecisionIntelligenceTraceKind.quick.rawValue,
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                reminderSelectionNeedID: admissionDecision.reminderSelectionNeed?.rawValue,
                runtimeTimeBudgetMs: strategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                baselineOutputPreview: quickPreview(from: base),
                deterministicFallbackOutputPreview: quickPreview(from: base),
                recordsTemplatePinnedTrace: true
            ))
        )
        let outcome = await executeProviderRequest(
            task: .quick,
            strategy: strategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await responseCache.quickResult(for: cacheKey)
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
                    strategy: strategy,
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
            observeEvent: { event in
                await observeProviderRequestEvent(
                    event,
                    context: observationContext,
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    storeResolvedResult: { provider, refined in
                        let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                            provider: provider.kind,
                            envelope: envelope
                        )
                        await responseCache.storeQuickResult(refined, for: cacheKey)
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
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext = ProviderRequestObservationContext(
            kind: .balance,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: strategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            substrateContext: BASAppleProviderObservationContextBuilder.build(
                from: BASAppleProviderObservationSourceInput(
                kind: DecisionIntelligenceTraceKind.balance.rawValue,
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                reminderSelectionNeedID: admissionDecision.reminderSelectionNeed?.rawValue,
                runtimeTimeBudgetMs: strategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                baselineOutputPreview: balancePreview(from: base),
                deterministicFallbackOutputPreview: balancePreview(from: base),
                recordsTemplatePinnedTrace: true
            ))
        )
        let outcome = await executeProviderRequest(
            task: .balance,
            strategy: strategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await responseCache.balanceResult(for: cacheKey)
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
                    strategy: strategy,
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
            observeEvent: { event in
                await observeProviderRequestEvent(
                    event,
                    context: observationContext,
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    storeResolvedResult: { provider, refined in
                        let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                            provider: provider.kind,
                            envelope: envelope
                        )
                        await responseCache.storeBalanceResult(refined, for: cacheKey)
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
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)
        } ?? DecisionIntelligenceAdmissionController.decide(for: envelope)
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext = ProviderRequestObservationContext(
            kind: .mirror,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: strategy,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            substrateContext: BASAppleProviderObservationContextBuilder.build(
                from: BASAppleProviderObservationSourceInput(
                kind: DecisionIntelligenceTraceKind.mirror.rawValue,
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: providerProfiles(),
                promptBudget: envelope.budget,
                brainState: brainState,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                reminderSelectionNeedID: admissionDecision.reminderSelectionNeed?.rawValue,
                runtimeTimeBudgetMs: strategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: envelope.debugPrompt,
                baselineOutputPreview: mirrorPreview(from: base),
                deterministicFallbackOutputPreview: mirrorPreview(from: base),
                recordsTemplatePinnedTrace: true
            ))
        )
        let outcome = await executeProviderRequest(
            task: .mirror,
            strategy: strategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
            loadCachedResult: { provider in
                let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                    provider: provider.kind,
                    envelope: envelope
                )
                return await responseCache.mirrorResult(for: cacheKey)
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
                    strategy: strategy,
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
            observeEvent: { event in
                await observeProviderRequestEvent(
                    event,
                    context: observationContext,
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    storeResolvedResult: { provider, refined in
                        let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                            provider: provider.kind,
                            envelope: envelope
                        )
                        await responseCache.storeMirrorResult(refined, for: cacheKey)
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
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: selection.prompt)
        } ?? DecisionIntelligenceAdmissionController.decide(
            for: selection.prompt,
            reminderCandidateCount: clippedCandidates.count,
            reminderSelectionAssessment: reminderSelectionAssessment
        )
        let admissionEvaluatedMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observationContext = ProviderRequestObservationContext(
            kind: .reminder,
            frontstageState: selection.prompt.frontstageState,
            contextState: nil,
            neuralState: nil,
            brainState: nil,
            runtimeStrategy: strategy,
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision,
            substrateContext: BASAppleProviderObservationContextBuilder.build(
                from: BASAppleProviderObservationSourceInput(
                kind: DecisionIntelligenceTraceKind.reminder.rawValue,
                preferredProviderID: preference.kind.rawValue,
                allowFallbacks: allowFallbacks,
                providerProfilesByID: providerProfiles(),
                promptBudget: selection.prompt.budget,
                brainState: nil,
                admissionPressureID: admissionDecision.pressure.rawValue,
                admissionSkipReasonID: admissionDecision.skipReason?.rawValue,
                reminderSelectionNeedID: admissionDecision.reminderSelectionNeed?.rawValue,
                runtimeTimeBudgetMs: strategy?.timeBudgetMs,
                admissionReason: admissionDecision.reason,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                prompt: selection.prompt.debugPrompt,
                baselineOutputPreview: "Deterministic reminder ordering kept",
                deterministicFallbackOutputPreview: "No reminder selected",
                recordsTemplatePinnedTrace: false
            ))
        )
        let outcome = await executeProviderRequest(
            task: .reminder,
            strategy: strategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile,
            admissionAllowed: admissionDecision.isAllowed,
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
                    outputPreview: reminderPreview(from: cached),
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    reminderMode: mode
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
                    outputPreview: reminderPreview(from: selected),
                    kernelSnapshot: selection.prompt.assembly.kernelSnapshot,
                    brainState: nil,
                    reminderMode: mode
                )
            },
            observeEvent: { event in
                await observeProviderRequestEvent(
                    event,
                    context: observationContext,
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    storeResolvedResult: { provider, selected in
                        let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                            provider: provider.kind,
                            envelope: selection.prompt
                        )
                        await responseCache.storeReminder(selected, for: cacheKey)
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

    static func defaultStatusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        registry.statusesByKind()
    }

    private static func observeProviderRequestEvent<Result: Sendable>(
        _ event: BASProviderRequestEvent<any DecisionIntelligenceProviding, Result, BASProviderReleaseAssessment>,
        context: ProviderRequestObservationContext,
        requestStart: ContinuousClock.Instant,
        clock: ContinuousClock,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        storeResolvedResult: (((any DecisionIntelligenceProviding), Result) async -> Void)? = nil
    ) async {
        if case .providerSuccess(let attempt) = event {
            await storeResolvedResult?(attempt.provider, attempt.result)
        }

        let durationMs = elapsedMilliseconds(since: requestStart, clock: clock)
        let observation = BASAppleProviderOutcomeObserver.observeEvent(
            event,
            context: context.substrateContext,
            durationMs: durationMs,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerID: { $0.kind.rawValue }
        )

        for circuitEvent in observation.circuitEvents {
            await recordCircuitEvent(circuitEvent)
        }

        if let telemetryObservation = observation.telemetryObservation {
            await DecisionIntelligenceTelemetryStore.shared.record(
                observation: telemetryObservation
            )
        }

        if let trace = observation.trace {
            recordTrace(
                context: context,
                observedTrace: trace
            )
        }
    }

    private static func executeProviderRequest<Result: Sendable>(
        task: DecisionIntelligenceTraceKind,
        strategy: DecisionAdaptiveTaskStrategy?,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile?,
        admissionAllowed: Bool,
        loadCachedResult: @escaping ((any DecisionIntelligenceProviding)) async -> Result?,
        assessCachedResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
        quarantineCachedResult: @escaping ((any DecisionIntelligenceProviding)) async -> Void,
        invokeProvider: @escaping ((any DecisionIntelligenceProviding)) async -> Result?,
        assessProviderResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
        observeEvent: ((BASProviderRequestEvent<any DecisionIntelligenceProviding, Result, BASProviderReleaseAssessment>) async -> Void)? = nil
    ) async -> BASProviderRequestOutcome<Result, BASProviderReleaseAssessment> {
        let suspendedProviderIDs = Set(
            await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders.map(\.rawValue)
        )

        return await BASProviderRequestRunner.executeObserved(
            task: DecisionIntelligenceTaskRouter.substrateTraceKind(task),
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
            preferenceOrderings: BASReferenceProviderRuntime.preferenceOrderings,
            suspendedProviderIDs: suspendedProviderIDs,
            strategy: strategy.map(DecisionIntelligenceTaskRouter.substrateAdaptiveStrategy),
            descriptors: registry.descriptors().map(DecisionIntelligenceTaskRouter.substrateProviderDescriptor),
            testingOverrideProvider: testingOverrideProvider(
                for: preference,
                testingStubProfile: testingStubProfile
            ),
            providerID: { $0.kind.rawValue },
            providerForID: { providerID in
                DecisionModelProviderKind(rawValue: providerID).flatMap(registry.provider(for:))
            },
            isAvailable: { $0.availabilityStatus.isAvailable },
            admissionAllowed: admissionAllowed,
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
            observe: observeEvent
        )
    }

    private static func testingOverrideProvider(
        for preference: DecisionModelProviderPreference,
        testingStubProfile: DecisionTestingStubProfile?
    ) -> (any DecisionIntelligenceProviding)? {
        testingStubProfile.flatMap { profile in
            preference != .template ? TestingDecisionIntelligenceProvider(profile: profile) : nil
        }
    }

    private static func recordTrace(
        context: ProviderRequestObservationContext,
        observedTrace: BASAppleObservedProviderTrace
    ) {
        let traceRecord = BASAppleHostProviderObservationBridge.traceRecord(
            context: context,
            observedTrace: observedTrace
        )
        let preferredProvider = DecisionModelProviderKind(
            rawValue: traceRecord.preferredProviderID
        ) ?? .template
        let activeProvider = traceRecord.activeProviderID.flatMap(DecisionModelProviderKind.init(rawValue:))
        let attemptedProviders = traceRecord.attemptedProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:))

        let trace = DecisionIntelligenceTrace(
            kind: traceRecord.kind,
            preferredProvider: preferredProvider,
            activeProvider: activeProvider,
            attemptedProviders: attemptedProviders,
            allowFallbacks: traceRecord.allowFallbacks,
            usedFallback: traceRecord.usedFallback,
            frontstageState: traceRecord.frontstageState,
            contextState: traceRecord.contextState,
            neuralState: traceRecord.neuralState,
            brainState: traceRecord.brainState,
            runtimeStrategy: traceRecord.runtimeStrategy,
            promptBudget: traceRecord.promptBudget,
            admissionDecision: traceRecord.admissionDecision,
            semanticPromptFingerprint: traceRecord.semanticPromptFingerprint,
            stablePrefixFingerprint: traceRecord.stablePrefixFingerprint,
            consistencyCheck: traceRecord.consistencyCheck,
            consistencyRejected: traceRecord.consistencyRejected,
            substrateTrace: traceRecord.substrateTrace,
            prompt: traceRecord.prompt,
            outputPreview: traceRecord.outputPreview,
            detail: traceRecord.detail
        )

        Task { @MainActor in
            DecisionIntelligenceDebugStore.shared.record(trace)
        }
    }

    private static func quickPreview(from result: QuickCheckResult) -> String {
        BASAppleProviderReleaseAdapter.quickPreview(
            currentPerspective: result.currentPerspective,
            afterPerspective: result.afterPerspective
        )
    }

    private static func balancePreview(from result: BalanceBoardResult) -> String {
        BASAppleProviderReleaseAdapter.balancePreview(
            headline: result.headline,
            focusDescription: result.focusDescription,
            nextAction: result.nextAction
        )
    }

    private static func mirrorPreview(from result: MirrorResult) -> String {
        BASAppleProviderReleaseAdapter.mirrorPreview(
            headline: result.headline,
            coreTension: result.coreTension,
            nextAction: result.nextAction
        )
    }

    private static func reminderPreview(from candidate: ReminderSelectionCandidate) -> String {
        BASAppleProviderReleaseAdapter.reminderPreview(content: candidate.content)
    }

    private static func providerAttemptVerdict(
        kind: DecisionIntelligenceTraceKind,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: DecisionBrainState?,
        reminderMode: DecisionMode? = nil
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        BASAppleProviderReleaseAdapter.verdict(
            traceKindRawValue: kind.rawValue,
            outputPreview: outputPreview,
            kernelSnapshot: kernelSnapshot,
            brainState: brainState,
            reminderSurfaceModeRawValue: reminderMode?.rawValue
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

    private static func providerProfiles() -> [String: BASAppleProviderProfile] {
        BASAppleHostProviderObservationBridge.providerProfiles(
            descriptors: registry.descriptors(),
            providerID: { $0.kind.rawValue },
            title: { $0.kind.title },
            activeResolutionDetail: { descriptor in
                guard descriptor.kind == .gemmaE4B else { return nil }
                let resolution = GemmaE4BIntelligenceService.backendResolution(
                    policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                )
                return "\(resolution.title): \(resolution.detail)"
            },
            activeBackendID: { descriptor in
                guard descriptor.kind == .gemmaE4B else { return nil }
                return GemmaE4BIntelligenceService.backendResolution(
                    policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                ).effectiveBackend.rawValue
            }
        )
    }

    private static func recordCircuitEvent(
        _ event: BASAppleProviderCircuitEvent
    ) async {
        await BASAppleHostProviderObservationBridge.applyCircuitEvent(
            event,
            providerForID: DecisionModelProviderKind.init(rawValue:),
            kindForID: DecisionIntelligenceTraceKind.init(rawValue:),
            onCacheHit: { provider in
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider,
                    event: .cacheHit
                )
            },
            onProviderFailure: { provider in
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider,
                    event: .providerFailure
                )
            },
            onProviderSuccess: { provider, kind, durationMs in
                await DecisionIntelligenceCircuitBreaker.shared.record(
                    provider: provider,
                    event: .providerSuccess(
                        kind: kind,
                        durationMs: durationMs
                    )
                )
            }
        )
    }
}
