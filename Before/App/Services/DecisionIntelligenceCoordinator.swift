import Foundation

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()

    static func runtimeStatus(
        preferences: BeforePreferences = BeforePreferencesStore.load(),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionModelRuntimeStatus {
        guard preferences.onDeviceIntelligenceMode.isEnabled else {
            return DecisionModelRuntimeStatus(
                preferred: preferredKind(for: preferences.preferredIntelligenceProvider),
                active: .template,
                fallback: nil,
                detail: "On-device intelligence is off, so Before is using the deterministic decision system only."
            )
        }

        let preferred = preferredKind(for: preferences.preferredIntelligenceProvider)
        let orderedStatuses = orderedStatuses(
            for: preferences.preferredIntelligenceProvider,
            gemmaStatus: gemmaStatus,
            foundationStatus: foundationStatus
        )

        if let active = orderedStatuses.first(where: \.isAvailable) {
            let fallback = active.kind == preferred ? nil : active.kind
            let detail: String
            if active.kind == preferred {
                detail = "\(active.title). \(active.detail)"
            } else {
                detail = "\(providerTitle(for: preferred)) is not available. Before is using \(active.title.lowercased()) instead."
            }

            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: active.kind,
                fallback: fallback,
                detail: detail
            )
        }

        let fallbackSource = orderedStatuses.first(where: { !$0.isAvailable && $0.kind == preferred }) ?? orderedStatuses.first
        let detail = fallbackSource.map { "\(providerTitle(for: preferred)) is not available. \($0.detail) Before is falling back to deterministic local copy." }
            ?? "No assistive provider is available. Before is falling back to deterministic local copy."

        return DecisionModelRuntimeStatus(
            preferred: preferred,
            active: .template,
            fallback: .template,
            detail: detail
        )
    }

    static func route(
        prompt: String,
        scenario: ScenarioType? = nil,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> RoutedDecision {
        let fallback = DecisionModeRouter.route(prompt: prompt, scenario: scenario)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.route(prompt: prompt, scenario: scenario, fallback: fallback)
    }

    static func quickResult(
        for input: QuickCheckInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> QuickCheckResult {
        let fallback = CheckRuleEngine.evaluate(input)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.enhanceQuickResult(fallback, input: input)
    }

    static func balanceResult(
        for input: BalanceBoardInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> BalanceBoardResult {
        let fallback = BalanceBoardEngine.evaluate(input)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.enhanceBalanceResult(fallback, input: input)
    }

    static func mirrorResult(
        for input: MirrorInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> MirrorResult {
        let fallback = MirrorEngine.evaluate(input)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.enhanceMirrorResult(fallback, input: input)
    }

    static func bestReminder(
        from reminders: [SelfReminder],
        scenario: ScenarioType,
        prompt: String = "",
        mode: DecisionMode? = nil,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) -> SelfReminder? {
        let ranked = ReminderSelectionPolicy.ranked(reminders: reminders.filter { $0.scenario == scenario })
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return ranked.first }

        guard let selected = adapter.pickReminder(
            from: ranked.map(\.content),
            scenario: scenario,
            prompt: prompt,
            mode: mode
        ) else {
            return ranked.first
        }

        return ranked.first(where: { $0.content == selected }) ?? ranked.first
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) async -> QuickCheckResult? {
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return nil }
        return await refineUsingPreferredProvider(preference: preferences.preferredIntelligenceProvider) { provider in
            switch provider {
            case .gemmaE4B:
                await GemmaE4BIntelligenceService.refineQuickResult(base: base, input: input)
            case .foundationModels:
                await FoundationModelsIntelligenceService.refineQuickResult(base: base, input: input)
            case .template:
                nil
            }
        }
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) async -> BalanceBoardResult? {
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return nil }
        return await refineUsingPreferredProvider(preference: preferences.preferredIntelligenceProvider) { provider in
            switch provider {
            case .gemmaE4B:
                await GemmaE4BIntelligenceService.refineBalanceResult(base: base, input: input)
            case .foundationModels:
                await FoundationModelsIntelligenceService.refineBalanceResult(base: base, input: input)
            case .template:
                nil
            }
        }
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) async -> MirrorResult? {
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return nil }
        return await refineUsingPreferredProvider(preference: preferences.preferredIntelligenceProvider) { provider in
            switch provider {
            case .gemmaE4B:
                await GemmaE4BIntelligenceService.refineMirrorResult(base: base, input: input)
            case .foundationModels:
                await FoundationModelsIntelligenceService.refineMirrorResult(base: base, input: input)
            case .template:
                nil
            }
        }
    }

    private static func preferredKind(for preference: DecisionModelProviderPreference) -> DecisionModelProviderKind {
        switch preference {
        case .gemmaE4B:
            .gemmaE4B
        case .foundationModels:
            .foundationModels
        }
    }

    private static func providerTitle(for kind: DecisionModelProviderKind) -> String {
        kind.title
    }

    private static func orderedStatuses(
        for preference: DecisionModelProviderPreference,
        gemmaStatus: DecisionModelProviderStatus,
        foundationStatus: DecisionModelProviderStatus
    ) -> [DecisionModelProviderStatus] {
        switch preference {
        case .gemmaE4B:
            [gemmaStatus, foundationStatus]
        case .foundationModels:
            [foundationStatus, gemmaStatus]
        }
    }

    private static func orderedProviders(
        for preference: DecisionModelProviderPreference
    ) -> [DecisionModelProviderKind] {
        switch preference {
        case .gemmaE4B:
            [.gemmaE4B, .foundationModels]
        case .foundationModels:
            [.foundationModels, .gemmaE4B]
        }
    }

    private static func refineUsingPreferredProvider<T>(
        preference: DecisionModelProviderPreference,
        attempt: @escaping (DecisionModelProviderKind) async -> T?
    ) async -> T? {
        for provider in orderedProviders(for: preference) {
            if let refined = await attempt(provider) {
                return refined
            }
        }

        return nil
    }
}
