import Foundation
import BASAppleAdapters
import BASOrchestration
import BASObservability
import BASPolicy
import BASRuntimeCore

enum DecisionIntelligenceProviderPipeline {
    private static let registry = DecisionIntelligenceProviderRegistry.shared
    private static let responseCache = DecisionIntelligenceResponseCache.shared

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
        let summary = BASReferenceProviderRuntime.runtimeStatusSummary(
            preferredProviderID: preferred.rawValue,
            allowFallbacks: preferences.allowModelFallbacks,
            runtimeEnabled: preferences.onDeviceIntelligenceMode.isEnabled,
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
            testingOverrideEnabled: testingStubProfile != nil,
            testingOverrideTitle: testingStubProfile?.title
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
            preferredProvider: preference.kind,
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
            templatePinnedOutputPreview: quickPreview(from: base),
            admissionSkippedOutputPreview: quickPreview(from: base),
            deterministicFallbackOutputPreview: quickPreview(from: base),
            templatePinnedDetail: "Template mode is pinned, so no model provider was used for quick refinement.",
            admissionSkippedDetailPrefix: "Admission controller skipped quick refinement.",
            deterministicFallbackBase: "No provider returned a refined quick result, so Before kept the deterministic copy.",
            cachedConsistencySource: "cached quick refinement",
            providerConsistencySource: "provider quick refinement",
            recordsTemplatePinnedTrace: true
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
            preferredProvider: preference.kind,
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
            templatePinnedOutputPreview: balancePreview(from: base),
            admissionSkippedOutputPreview: balancePreview(from: base),
            deterministicFallbackOutputPreview: balancePreview(from: base),
            templatePinnedDetail: "Template mode is pinned, so no model provider was used for balance refinement.",
            admissionSkippedDetailPrefix: "Admission controller skipped balance refinement.",
            deterministicFallbackBase: "No provider returned a refined balance board, so Before kept the deterministic copy.",
            cachedConsistencySource: "cached balance refinement",
            providerConsistencySource: "provider balance refinement",
            recordsTemplatePinnedTrace: true
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
            preferredProvider: preference.kind,
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
            templatePinnedOutputPreview: mirrorPreview(from: base),
            admissionSkippedOutputPreview: mirrorPreview(from: base),
            deterministicFallbackOutputPreview: mirrorPreview(from: base),
            templatePinnedDetail: "Template mode is pinned, so no model provider was used for mirror refinement.",
            admissionSkippedDetailPrefix: "Admission controller skipped mirror refinement.",
            deterministicFallbackBase: "No provider returned a refined mirror, so Before kept the deterministic copy.",
            cachedConsistencySource: "cached mirror refinement",
            providerConsistencySource: "provider mirror refinement",
            recordsTemplatePinnedTrace: true
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
            preferredProvider: preference.kind,
            allowFallbacks: allowFallbacks,
            runtimeStrategy: strategy,
            frontstageState: selection.prompt.frontstageState,
            contextState: nil,
            neuralState: nil,
            brainState: nil,
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: selection.prompt.debugPrompt,
            templatePinnedOutputPreview: "Deterministic reminder ordering kept",
            admissionSkippedOutputPreview: "Deterministic reminder ordering kept",
            deterministicFallbackOutputPreview: "No reminder selected",
            templatePinnedDetail: "Template mode is pinned, so no model provider was used for reminder selection.",
            admissionSkippedDetailPrefix: "Admission controller skipped reminder selection.",
            deterministicFallbackBase: "No provider returned a reminder selection, so Before kept the deterministic reminder ordering.",
            cachedConsistencySource: "cached reminder selection",
            providerConsistencySource: "provider reminder selection",
            recordsTemplatePinnedTrace: false
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

    private struct ProviderRequestObservationContext {
        let kind: DecisionIntelligenceTraceKind
        let preferredProvider: DecisionModelProviderKind
        let allowFallbacks: Bool
        let runtimeStrategy: DecisionAdaptiveTaskStrategy?
        let frontstageState: DecisionFrontstageState?
        let contextState: DecisionContextPreparedState?
        let neuralState: DecisionNeuralState?
        let brainState: DecisionBrainState?
        let promptBudget: DecisionIntelligencePromptContract.ContextBudget?
        let admissionDecision: DecisionIntelligenceAdmissionDecision?
        let semanticPromptFingerprint: String?
        let stablePrefixFingerprint: String?
        let prompt: String
        let templatePinnedOutputPreview: String
        let admissionSkippedOutputPreview: String
        let deterministicFallbackOutputPreview: String
        let templatePinnedDetail: String
        let admissionSkippedDetailPrefix: String
        let deterministicFallbackBase: String
        let cachedConsistencySource: String
        let providerConsistencySource: String
        let recordsTemplatePinnedTrace: Bool
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
        switch event {
        case .templatePinned:
            await recordTelemetry(
                kind: context.kind,
                outcome: .templatePinned,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs
                ),
                promptBudget: context.promptBudget,
                runtimeStrategy: context.runtimeStrategy
            )
            guard context.recordsTemplatePinnedTrace else {
                return
            }
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                prompt: context.prompt,
                outputPreview: context.templatePinnedOutputPreview,
                detail: context.templatePinnedDetail
            )
        case .admissionSkipped:
            await recordTelemetry(
                kind: context.kind,
                outcome: .admissionSkipped,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs
                ),
                promptBudget: context.promptBudget,
                runtimeStrategy: context.runtimeStrategy,
                admissionDecision: context.admissionDecision
            )
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                prompt: context.prompt,
                outputPreview: context.admissionSkippedOutputPreview,
                detail: "\(context.admissionSkippedDetailPrefix) \(context.admissionDecision?.reason ?? "")"
            )
        case .cachedRejected(let attempt):
            guard let consistencyCheck = attempt.assessment.consistencyCheck else {
                return
            }
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                consistencyCheck: consistencyCheck,
                consistencyRejected: true,
                prompt: context.prompt,
                outputPreview: attempt.assessment.outputPreview,
                detail: rejectedConsistencyDetail(
                    base: cachedDetail(
                        preferred: context.preferredProvider,
                        active: attempt.provider.kind,
                        allowFallbacks: context.allowFallbacks
                    ),
                    result: consistencyCheck,
                    source: context.cachedConsistencySource
                )
            )
        case .cacheHit(let attempt):
            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: attempt.provider.kind,
                event: .cacheHit
            )
            await recordTelemetry(
                kind: context.kind,
                outcome: .cacheHit,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    providerSelectionMs: Double(attempt.planSummary.providerSelectionDurationMs)
                ),
                promptBudget: context.promptBudget,
                runtimeStrategy: context.runtimeStrategy,
                admissionDecision: context.admissionDecision
            )
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                consistencyCheck: attempt.assessment.consistencyCheck,
                prompt: context.prompt,
                outputPreview: attempt.assessment.outputPreview,
                detail: cachedDetail(
                    preferred: context.preferredProvider,
                    active: attempt.provider.kind,
                    allowFallbacks: context.allowFallbacks
                )
            )
        case .providerRejected(let attempt):
            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: attempt.provider.kind,
                event: .providerFailure
            )
            guard let consistencyCheck = attempt.assessment.consistencyCheck else {
                return
            }
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                consistencyCheck: consistencyCheck,
                consistencyRejected: true,
                prompt: context.prompt,
                outputPreview: attempt.assessment.outputPreview,
                detail: rejectedConsistencyDetail(
                    base: detail(
                        preferred: context.preferredProvider,
                        active: attempt.provider.kind,
                        allowFallbacks: context.allowFallbacks
                    ),
                    result: consistencyCheck,
                    source: context.providerConsistencySource
                )
            )
        case .providerSuccess(let attempt):
            await storeResolvedResult?(attempt.provider, attempt.result)
            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: attempt.provider.kind,
                event: .providerSuccess(
                    kind: context.kind,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock)
                )
            )
            await recordTelemetry(
                kind: context.kind,
                outcome: .providerSuccess,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    providerSelectionMs: Double(attempt.planSummary.providerSelectionDurationMs)
                ),
                promptBudget: context.promptBudget,
                runtimeStrategy: context.runtimeStrategy,
                admissionDecision: context.admissionDecision
            )
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: attempt.provider.kind,
                attemptedProviders: attemptedKinds(from: attempt.attemptedProviderIDs),
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                consistencyCheck: attempt.assessment.consistencyCheck,
                prompt: context.prompt,
                outputPreview: attempt.assessment.outputPreview,
                detail: detail(
                    preferred: context.preferredProvider,
                    active: attempt.provider.kind,
                    allowFallbacks: context.allowFallbacks
                )
            )
        case .providerMiss(let miss):
            await DecisionIntelligenceCircuitBreaker.shared.record(
                provider: miss.provider.kind,
                event: .providerFailure
            )
        case .noResult(let noResult):
            let actualAttemptedKinds = attemptedKinds(from: noResult.attemptedProviderIDs)
            let suspendedKinds = noResult.planSummary.suspendedProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:))
            await recordTelemetry(
                kind: context.kind,
                outcome: .deterministicFallback,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: actualAttemptedKinds,
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                lifecycleMetrics: lifecycleMetrics(
                    requestStart: requestStart,
                    clock: clock,
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    providerSelectionMs: Double(noResult.planSummary.providerSelectionDurationMs)
                ),
                promptBudget: context.promptBudget,
                runtimeStrategy: context.runtimeStrategy,
                admissionDecision: context.admissionDecision
            )
            recordTrace(
                kind: context.kind,
                preferredProvider: context.preferredProvider,
                activeProvider: nil,
                attemptedProviders: actualAttemptedKinds,
                allowFallbacks: context.allowFallbacks,
                runtimeStrategy: context.runtimeStrategy,
                frontstageState: context.frontstageState,
                contextState: context.contextState,
                neuralState: context.neuralState,
                brainState: context.brainState,
                promptBudget: context.promptBudget,
                admissionDecision: context.admissionDecision,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                prompt: context.prompt,
                outputPreview: context.deterministicFallbackOutputPreview,
                detail: deterministicFallbackDetail(
                    base: context.deterministicFallbackBase,
                    suspendedKinds: suspendedKinds
                )
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

    private static func deterministicFallbackDetail(
        base: String,
        suspendedKinds: [DecisionModelProviderKind]
    ) -> String {
        BASAppleProviderOutcomeObserver.deterministicFallbackDetail(
            base: base,
            suspendedProviderTitles: suspendedKinds.map(\.title)
        )
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
        let traceObservation = BASAppleProviderOutcomeObserver.traceObservation(
            from: BASAppleProviderTraceInput(
                testingOverridePresent: DecisionTestingInterface.environmentOverride() != nil,
                kind: kind.rawValue,
                preferredProviderID: preferredProvider.rawValue,
                activeProviderID: activeProvider?.rawValue,
                attemptedProviderIDs: attemptedProviders.map(\.rawValue),
                allowFallbacks: allowFallbacks,
                prompt: prompt,
                outputPreview: outputPreview,
                detail: detail,
                semanticPromptFingerprint: semanticPromptFingerprint,
                stablePrefixFingerprint: stablePrefixFingerprint,
                promptBudget: promptBudget,
                brainState: brainState,
                consistencyRejected: consistencyRejected,
                consistencyViolationKinds: consistencyCheck?.violations.map(\.kind.rawValue) ?? []
            )
        )

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
            substrateTrace: traceObservation.compilation.executionTrace,
            prompt: traceObservation.compilation.storedPrompt,
            outputPreview: traceObservation.compilation.storedOutputPreview,
            detail: traceObservation.detail
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
        BASAppleProviderOutcomeObserver.providerDetail(
            preferredTitle: preferred.title,
            activeTitle: active.title,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: active == .gemmaE4B
                ? {
                    let resolution = GemmaE4BIntelligenceService.backendResolution(
                        policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                    )
                    return "\(resolution.title): \(resolution.detail)"
                }()
                : nil
        )
    }

    private static func cachedDetail(
        preferred: DecisionModelProviderKind,
        active: DecisionModelProviderKind,
        allowFallbacks: Bool
    ) -> String {
        BASAppleProviderOutcomeObserver.cachedProviderDetail(
            preferredTitle: preferred.title,
            activeTitle: active.title,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: active == .gemmaE4B
                ? {
                    let resolution = GemmaE4BIntelligenceService.backendResolution(
                        policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                    )
                    return "\(resolution.title): \(resolution.detail)"
                }()
                : nil
        )
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

    private static func attemptedKinds(
        from providerIDs: [String]
    ) -> [DecisionModelProviderKind] {
        providerIDs.compactMap(DecisionModelProviderKind.init(rawValue:))
    }

    private static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        BASAppleProviderOutcomeObserver.rejectedConsistencyDetail(
            base: base,
            result: result,
            source: source
        )
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
            observation: BASAppleProviderOutcomeObserver.telemetryObservation(
                from: BASAppleTelemetryRecordInput(
                    kind: kind.rawValue,
                    outcome: outcome,
                    activeProviderID: activeProvider?.rawValue,
                    attemptedProviderIDs: attemptedProviders.map(\.rawValue),
                    usedFallback: activeProvider != nil && activeProvider != preferredProvider,
                    durationMs: durationMs,
                    lifecycleMetrics: lifecycleMetrics,
                    promptBudget: promptBudget,
                    runtimeTimeBudgetMs: runtimeStrategy?.timeBudgetMs,
                    admissionPressureID: admissionDecision?.pressure.rawValue,
                    admissionSkipReasonID: admissionDecision?.skipReason?.rawValue,
                    reminderSelectionNeedID: admissionDecision?.reminderSelectionNeed?.rawValue,
                    activeBackendID: activeProvider == .gemmaE4B
                        ? GemmaE4BIntelligenceService.backendResolution(
                            policy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
                        ).effectiveBackend.rawValue
                        : nil
                )
            )
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
        BASAppleProviderOutcomeObserver.lifecycleMetrics(
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerSelectionMs: providerSelectionMs,
            firstPresentableMs: elapsedMilliseconds(since: requestStart, clock: clock)
        )
    }
}
