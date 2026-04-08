import Foundation

protocol DecisionIntelligenceProviding: Sendable {
    var kind: DecisionModelProviderKind { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult?

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate?
}

struct GemmaDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .gemmaE4B }
    var availabilityStatus: DecisionModelProviderStatus { GemmaE4BIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await GemmaE4BIntelligenceService.refineQuickResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await GemmaE4BIntelligenceService.refineBalanceResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await GemmaE4BIntelligenceService.refineMirrorResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        await GemmaE4BIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }
}

struct FoundationDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .foundationModels }
    var availabilityStatus: DecisionModelProviderStatus { FoundationModelsIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await FoundationModelsIntelligenceService.refineQuickResult(base: base, input: input)
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await FoundationModelsIntelligenceService.refineBalanceResult(base: base, input: input)
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await FoundationModelsIntelligenceService.refineMirrorResult(base: base, input: input)
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        await FoundationModelsIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
    }
}

enum DecisionIntelligenceProviderPipeline {
    private static let providersByKind: [DecisionModelProviderKind: any DecisionIntelligenceProviding] = [
        .gemmaE4B: GemmaDecisionIntelligenceProvider(),
        .foundationModels: FoundationDecisionIntelligenceProvider()
    ]
    private static let responseCache = DecisionIntelligenceResponseCache.shared

    static func orderedKinds(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true
    ) -> [DecisionModelProviderKind] {
        if !allowFallbacks {
            return [preference.kind]
        }

        switch preference {
        case .gemmaE4B:
            return [.gemmaE4B, .foundationModels]
        case .foundationModels:
            return [.foundationModels, .gemmaE4B]
        case .template:
            return [.template]
        }
    }

    static func runtimeStatus(
        preferences: BeforePreferences,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = defaultStatusesByKind(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) -> DecisionModelRuntimeStatus {
        let preferred = preferences.preferredIntelligenceProvider.kind

        guard preferences.onDeviceIntelligenceMode.isEnabled else {
            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .template,
                fallback: nil,
                detail: "On-device intelligence is off, so Before is using the deterministic decision system only."
            )
        }

        if let testingStubProfile, preferred != .template {
            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .testingStub,
                fallback: .testingStub,
                detail: "Testing stub profile '\(testingStubProfile.title)' is overriding live providers so the AI path can be verified without a model runtime."
            )
        }

        if preferred == .template {
            return DecisionModelRuntimeStatus(
                preferred: .template,
                active: .template,
                fallback: nil,
                detail: "Deterministic local copy is pinned, so Before is not using a model provider for assistive refinement."
            )
        }

        let orderedStatuses = orderedKinds(
            for: preferences.preferredIntelligenceProvider,
            allowFallbacks: preferences.allowModelFallbacks
        )
            .compactMap { statusesByKind[$0] }

        if let active = orderedStatuses.first(where: \.isAvailable) {
            let fallback = active.kind == preferred ? nil : active.kind
            let detail: String
            if active.kind == preferred {
                detail = "\(active.title). \(active.detail)"
            } else {
                detail = "\(preferred.title) is not available. Before is using \(active.title.lowercased()) instead."
            }

            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: active.kind,
                fallback: fallback,
                detail: detail
            )
        }

        if !preferences.allowModelFallbacks {
            let detail = "\(preferred.title) is not available. Automatic model fallback is off, so Before is using deterministic local copy instead."

            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .template,
                fallback: .template,
                detail: detail
            )
        }

        let fallbackSource = orderedStatuses.first(where: { !$0.isAvailable && $0.kind == preferred }) ?? orderedStatuses.first
        let detail = fallbackSource.map { "\(preferred.title) is not available. \($0.detail) Before is falling back to deterministic local copy." }
            ?? "No assistive provider is available. Before is falling back to deterministic local copy."

        return DecisionModelRuntimeStatus(
            preferred: preferred,
            active: .template,
            fallback: .template,
            detail: detail
        )
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> QuickCheckResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        guard preference != .template else {
            await recordTelemetry(
                kind: .quick,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget
            )
            recordTrace(
                kind: .quick,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .quick,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .quick,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.quickResult(for: cacheKey) {
                await recordTelemetry(
                    kind: .quick,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: quickPreview(from: cached),
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineQuickResult(base: base, input: input) {
                await responseCache.storeQuickResult(refined, for: cacheKey)
                await recordTelemetry(
                    kind: .quick,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: quickPreview(from: refined),
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }
        }

        await recordTelemetry(
            kind: .quick,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .quick,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: quickPreview(from: base),
            detail: "No provider returned a refined quick result, so Before kept the deterministic copy."
        )
        return nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> BalanceBoardResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        guard preference != .template else {
            await recordTelemetry(
                kind: .balance,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget
            )
            recordTrace(
                kind: .balance,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .balance,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .balance,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.balanceResult(for: cacheKey) {
                await recordTelemetry(
                    kind: .balance,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: balancePreview(from: cached),
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineBalanceResult(base: base, input: input) {
                await responseCache.storeBalanceResult(refined, for: cacheKey)
                await recordTelemetry(
                    kind: .balance,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: balancePreview(from: refined),
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }
        }

        await recordTelemetry(
            kind: .balance,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .balance,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: balancePreview(from: base),
            detail: "No provider returned a refined balance board, so Before kept the deterministic copy."
        )
        return nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> MirrorResult? {
        let clock = ContinuousClock()
        let requestStart = clock.now
        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: envelope)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: envelope)
        guard preference != .template else {
            await recordTelemetry(
                kind: .mirror,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget
            )
            recordTrace(
                kind: .mirror,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .mirror,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: envelope.budget,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .mirror,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
                frontstageState: envelope.frontstageState,
                contextState: contextState,
                neuralState: neuralState,
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

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.mirrorResult(for: cacheKey) {
                await recordTelemetry(
                    kind: .mirror,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: mirrorPreview(from: cached),
                    detail: cachedDetail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return cached
            }

            if let refined = await provider.refineMirrorResult(base: base, input: input) {
                await responseCache.storeMirrorResult(refined, for: cacheKey)
                await recordTelemetry(
                    kind: .mirror,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: envelope.frontstageState,
                    contextState: contextState,
                    neuralState: neuralState,
                    promptBudget: envelope.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: envelope.debugPrompt,
                    outputPreview: mirrorPreview(from: refined),
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return refined
            }
        }

        await recordTelemetry(
            kind: .mirror,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .mirror,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            frontstageState: envelope.frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            promptBudget: envelope.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: envelope.debugPrompt,
            outputPreview: mirrorPreview(from: base),
            detail: "No provider returned a refined mirror, so Before kept the deterministic copy."
        )
        return nil
    }

    static func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
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
            mode: mode
        )
        let semanticPromptFingerprint = DecisionIntelligencePromptContract.semanticFingerprint(for: selection.prompt)
        let stablePrefixFingerprint = DecisionIntelligencePromptContract.stablePrefixFingerprint(for: selection.prompt)
        let clippedCandidates = selection.candidates
        guard !clippedCandidates.isEmpty else { return nil }
        guard preference != .template else {
            await recordTelemetry(
                kind: .reminder,
                outcome: .templatePinned,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: selection.prompt.budget
            )
            return nil
        }
        let admissionDecision = testingStubProfile.map {
            _ in DecisionIntelligenceAdmissionController.testingStubDecision(for: selection.prompt)
        } ?? DecisionIntelligenceAdmissionController.decide(
            for: selection.prompt,
            reminderCandidateCount: clippedCandidates.count
        )
        guard admissionDecision.isAllowed else {
            await recordTelemetry(
                kind: .reminder,
                outcome: .admissionSkipped,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                promptBudget: selection.prompt.budget,
                admissionDecision: admissionDecision
            )
            recordTrace(
                kind: .reminder,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [],
                allowFallbacks: allowFallbacks,
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
        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: selection.prompt
            )
            if let cached = await responseCache.reminder(for: cacheKey),
               clippedCandidates.contains(where: { $0.id == cached.id }) {
                await recordTelemetry(
                    kind: .reminder,
                    outcome: .cacheHit,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: selection.prompt.frontstageState,
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: selection.prompt.debugPrompt,
                    outputPreview: reminderPreview(from: cached),
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
                mode: mode
            ) {
                await responseCache.storeReminder(selected, for: cacheKey)
                await recordTelemetry(
                    kind: .reminder,
                    outcome: .providerSuccess,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: actualAttemptedKinds,
                    durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision
                )
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
                    frontstageState: selection.prompt.frontstageState,
                    promptBudget: selection.prompt.budget,
                    admissionDecision: admissionDecision,
                    semanticPromptFingerprint: semanticPromptFingerprint,
                    stablePrefixFingerprint: stablePrefixFingerprint,
                    prompt: selection.prompt.debugPrompt,
                    outputPreview: reminderPreview(from: selected),
                    detail: detail(
                        preferred: preference.kind,
                        active: provider.kind,
                        allowFallbacks: allowFallbacks
                    )
                )
                return selected
            }
        }

        await recordTelemetry(
            kind: .reminder,
            outcome: .deterministicFallback,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: actualAttemptedKinds,
            durationMs: elapsedMilliseconds(since: requestStart, clock: clock),
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision
        )
        recordTrace(
            kind: .reminder,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            frontstageState: selection.prompt.frontstageState,
            promptBudget: selection.prompt.budget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: selection.prompt.debugPrompt,
            outputPreview: "No reminder selected",
            detail: "No provider returned a reminder selection, so Before kept the deterministic reminder ordering."
        )
        return nil
    }

    static func defaultStatusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        providersByKind.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.availabilityStatus
        }
    }

    private static func orderedProviders(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile?
    ) -> [any DecisionIntelligenceProviding] {
        if let testingStubProfile, preference != .template {
            return [TestingDecisionIntelligenceProvider(profile: testingStubProfile)]
        }
        return orderedKinds(for: preference, allowFallbacks: allowFallbacks).compactMap { providersByKind[$0] }
    }

    private static func recordTrace(
        kind: DecisionIntelligenceTraceKind,
        preferredProvider: DecisionModelProviderKind,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        allowFallbacks: Bool,
        frontstageState: DecisionFrontstageState? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        prompt: String,
        outputPreview: String,
        detail: String
    ) {
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
            promptBudget: promptBudget,
            admissionDecision: admissionDecision,
            semanticPromptFingerprint: semanticPromptFingerprint,
            stablePrefixFingerprint: stablePrefixFingerprint,
            prompt: prompt,
            outputPreview: outputPreview,
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

    private static func recordTelemetry(
        kind: DecisionIntelligenceTraceKind,
        outcome: DecisionIntelligenceRequestOutcome,
        preferredProvider: DecisionModelProviderKind,
        activeProvider: DecisionModelProviderKind?,
        attemptedProviders: [DecisionModelProviderKind],
        durationMs: Double,
        promptBudget: DecisionIntelligencePromptContract.ContextBudget? = nil,
        admissionDecision: DecisionIntelligenceAdmissionDecision? = nil
    ) async {
        await DecisionIntelligenceTelemetryStore.shared.record(
            kind: kind,
            outcome: outcome,
            activeProvider: activeProvider,
            attemptedProviders: attemptedProviders,
            usedFallback: activeProvider != nil && activeProvider != preferredProvider,
            durationMs: durationMs,
            promptBudget: promptBudget,
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
}
