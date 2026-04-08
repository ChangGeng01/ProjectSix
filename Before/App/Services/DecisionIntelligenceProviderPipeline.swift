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
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> QuickCheckResult? {
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(base: base, input: input)
        guard preference != .template else {
            recordTrace(
                kind: .quick,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                prompt: envelope.debugPrompt,
                outputPreview: quickPreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for quick refinement."
            )
            return nil
        }

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)

        for provider in providers {
            let cacheKey = cacheKey(provider: provider.kind, prompt: envelope.debugPrompt)
            if let cached = await responseCache.quickResult(for: cacheKey) {
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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
                recordTrace(
                    kind: .quick,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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

        recordTrace(
            kind: .quick,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            prompt: envelope.debugPrompt,
            outputPreview: quickPreview(from: base),
            detail: "No provider returned a refined quick result, so Before kept the deterministic copy."
        )
        return nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> BalanceBoardResult? {
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(base: base, input: input)
        guard preference != .template else {
            recordTrace(
                kind: .balance,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                prompt: envelope.debugPrompt,
                outputPreview: balancePreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for balance refinement."
            )
            return nil
        }

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)

        for provider in providers {
            let cacheKey = cacheKey(provider: provider.kind, prompt: envelope.debugPrompt)
            if let cached = await responseCache.balanceResult(for: cacheKey) {
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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
                recordTrace(
                    kind: .balance,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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

        recordTrace(
            kind: .balance,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
            prompt: envelope.debugPrompt,
            outputPreview: balancePreview(from: base),
            detail: "No provider returned a refined balance board, so Before kept the deterministic copy."
        )
        return nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile
    ) async -> MirrorResult? {
        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(base: base, input: input)
        guard preference != .template else {
            recordTrace(
                kind: .mirror,
                preferredProvider: preference.kind,
                activeProvider: nil,
                attemptedProviders: [.template],
                allowFallbacks: allowFallbacks,
                prompt: envelope.debugPrompt,
                outputPreview: mirrorPreview(from: base),
                detail: "Template mode is pinned, so no model provider was used for mirror refinement."
            )
            return nil
        }

        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)

        for provider in providers {
            let cacheKey = cacheKey(provider: provider.kind, prompt: envelope.debugPrompt)
            if let cached = await responseCache.mirrorResult(for: cacheKey) {
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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
                recordTrace(
                    kind: .mirror,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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

        recordTrace(
            kind: .mirror,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
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
        let selection = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
        let clippedCandidates = selection.candidates
        guard !clippedCandidates.isEmpty, preference != .template else { return nil }
        let providers = orderedProviders(
            for: preference,
            allowFallbacks: allowFallbacks,
            testingStubProfile: testingStubProfile
        )
        let attemptedKinds = providers.map(\.kind)

        for provider in providers {
            let cacheKey = cacheKey(provider: provider.kind, prompt: selection.prompt.debugPrompt)
            if let cached = await responseCache.reminder(for: cacheKey),
               clippedCandidates.contains(where: { $0.id == cached.id }) {
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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
                recordTrace(
                    kind: .reminder,
                    preferredProvider: preference.kind,
                    activeProvider: provider.kind,
                    attemptedProviders: attemptedKinds,
                    allowFallbacks: allowFallbacks,
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

        recordTrace(
            kind: .reminder,
            preferredProvider: preference.kind,
            activeProvider: nil,
            attemptedProviders: attemptedKinds,
            allowFallbacks: allowFallbacks,
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

    private static func cacheKey(provider: DecisionModelProviderKind, prompt: String) -> String {
        "\(provider.rawValue)\n\(prompt)"
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
}
