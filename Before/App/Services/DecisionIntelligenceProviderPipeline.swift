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
        excluding suspendedKinds: Set<DecisionModelProviderKind> = []
    ) -> [DecisionModelProviderKind] {
        BASAppleProviderHostBridge.orderedProviderIDs(
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            excluding: Set(suspendedKinds.map(\.rawValue))
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
                statusesByID: BASAppleProviderHostBridge.statusRecords(
                    statusesByKind,
                    keyID: \.rawValue,
                    isAvailable: \.isAvailable,
                    title: \.title,
                    detail: \.detail
                ),
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
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> QuickCheckResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        if let eBrainTurn, eBrainTurn.actionPermit.mode.isProtective {
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
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .quick,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
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
                await responseCache.storeQuickResult(refined, for: cacheKey)
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
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> BalanceBoardResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        if let eBrainTurn, eBrainTurn.actionPermit.mode.isProtective {
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
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .balance,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
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
                await responseCache.storeBalanceResult(refined, for: cacheKey)
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
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> MirrorResult? {
        let adjustedStrategy = strategy?.clamped(using: eBrainTurn)
        if let eBrainTurn, eBrainTurn.actionPermit.mode.isProtective {
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
        let outcome = await BehavioralAISubstrateBridge.executeObservedProviderRequest(
            task: .mirror,
            strategy: adjustedStrategy,
            preference: preference,
            allowFallbacks: allowFallbacks,
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
                await responseCache.storeMirrorResult(refined, for: cacheKey)
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
        case .delay, .block, .replace:
            return true
        case .answer, .compare:
            return false
        }
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
        let gearCap: DecisionRuntimeGear = switch budget.runMode {
        case .dormant, .sentinel:
            .low
        case .engage:
            .balanced
        case .deepLoop:
            .high
        case .guarded:
            .low
        }

        let runtimeGear = [runtimeGear, gearCap].min { $0.rank < $1.rank } ?? runtimeGear
        let cappedContextBudget = min(contextBudget, max(40, budget.maxCandidates * 100 + budget.maxLoops * 60))
        let cappedOutputBudget = min(outputCharacterBudget, max(80, budget.maxDecodeTokens * 2))
        let cappedTimeBudget = min(timeBudgetMs, max(250, budget.maxLoops * 320 + budget.retrievalDepth * 120))
        let cappedToolBudget = min(toolCallBudget, budget.maintenanceAllowed ? toolCallBudget : 1)
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
    static func protectiveQuickResult(
        base: QuickCheckResult,
        turn: BASEBrainTurnResult
    ) -> QuickCheckResult {
        let rendered = turn.renderedOutput
        let verdict: CheckVerdict = switch rendered.mode {
        case .delay, .replace:
            .pause
        case .block:
            .notRecommended
        case .compare, .answer:
            base.verdict
        }
        let primaryAction: CheckAction = switch rendered.mode {
        case .delay:
            .wait90s
        case .block:
            .leaveStimulus
        case .replace:
            .decideTomorrow
        case .compare, .answer:
            base.primaryAction
        }
        let secondaryActions: [CheckAction] = switch rendered.mode {
        case .delay:
            [.decideTomorrow, .continueMindfully]
        case .block:
            [.leaveStimulus, .decideTomorrow]
        case .replace:
            [.continueMindfully, .decideTomorrow]
        case .compare, .answer:
            base.secondaryActions
        }

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
        let nextAction = rendered.alternativeActions.lazy.compactMap(nonEmpty).first ?? base.nextAction
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
        let nextAction = rendered.alternativeActions.lazy.compactMap(nonEmpty).first ?? base.nextAction
        let nextActionTitle: String = switch rendered.mode {
        case .delay:
            "Delay the move"
        case .block:
            "Hold the boundary"
        case .replace:
            "Use the safer step"
        case .compare, .answer:
            base.nextActionTitle
        }
        return MirrorResult(
            headline: nonEmpty(rendered.headline) ?? base.headline,
            coreTension: nonEmpty(rendered.body) ?? base.coreTension,
            nextActionTitle: nextActionTitle,
            nextAction: nextAction
        )
    }

    static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
