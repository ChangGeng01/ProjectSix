import Foundation

enum DecisionIntelligenceProviderPipeline {
    private static let registry = DecisionIntelligenceProviderRegistry.shared
    private static let responseCache = DecisionIntelligenceResponseCache.shared

    static func orderedKinds(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true,
        excluding suspendedKinds: Set<DecisionModelProviderKind> = []
    ) -> [DecisionModelProviderKind] {
        if preference != .template, suspendedKinds.contains(preference.kind), !allowFallbacks {
            return []
        }

        if !allowFallbacks {
            return suspendedKinds.contains(preference.kind) ? [] : [preference.kind]
        }

        let ordered: [DecisionModelProviderKind] = switch preference {
        case .gemmaE4B:
            [.gemmaE4B, .foundationModels]
        case .openModel:
            [.openModel, .gemmaE4B, .foundationModels]
        case .foundationModels:
            [.foundationModels, .gemmaE4B]
        case .template:
            [.template]
        }

        return ordered.filter { !suspendedKinds.contains($0) }
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
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.quickResult(for: cacheKey) {
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
                    promptBudget: envelope.budget,
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

            if let refined = await provider.refineQuickResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
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
                    promptBudget: envelope.budget,
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
            promptBudget: envelope.budget,
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
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.balanceResult(for: cacheKey) {
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
                    promptBudget: envelope.budget,
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

            if let refined = await provider.refineBalanceResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
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
                    promptBudget: envelope.budget,
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
            promptBudget: envelope.budget,
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
        let suspendedKinds = await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders
        var actualAttemptedKinds: [DecisionModelProviderKind] = []

        for provider in providers {
            actualAttemptedKinds.append(provider.kind)
            let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
                provider: provider.kind,
                envelope: envelope
            )
            if let cached = await responseCache.mirrorResult(for: cacheKey) {
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
                    promptBudget: envelope.budget,
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

            if let refined = await provider.refineMirrorResult(
                base: base,
                input: input,
                strategy: strategy,
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            ) {
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
                    promptBudget: envelope.budget,
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
            promptBudget: envelope.budget,
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
                promptBudget: selection.prompt.budget
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
                    promptBudget: selection.prompt.budget,
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
                mode: mode,
                strategy: strategy
            ) {
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
                    promptBudget: selection.prompt.budget,
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
            promptBudget: selection.prompt.budget,
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
        if let testingStubProfile, preference != .template {
            return [TestingDecisionIntelligenceProvider(profile: testingStubProfile)]
        }
        let suspendedKinds = Set(await DecisionIntelligenceCircuitBreaker.shared.snapshot().activeProviders)
        return DecisionIntelligenceTaskRouter.orderedKinds(
            for: task,
            preference: preference,
            allowFallbacks: allowFallbacks,
            excluding: suspendedKinds,
            registry: registry,
            strategy: strategy
        )
        .compactMap { registry.provider(for: $0) }
        .filter { $0.availabilityStatus.isAvailable }
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
            brainState: brainState,
            runtimeStrategy: runtimeStrategy,
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
