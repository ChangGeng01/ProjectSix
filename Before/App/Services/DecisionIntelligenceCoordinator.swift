import Foundation

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()

    static func runtimeStatus(
        preferences: BeforePreferences = BeforePreferencesStore.load(),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionModelRuntimeStatus {
        DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: preferences,
            statusesByKind: [
                .gemmaE4B: gemmaStatus,
                .foundationModels: foundationStatus
            ]
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
        return await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: preferences.preferredIntelligenceProvider,
            allowFallbacks: preferences.allowModelFallbacks
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) async -> BalanceBoardResult? {
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            preference: preferences.preferredIntelligenceProvider,
            allowFallbacks: preferences.allowModelFallbacks
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        preferences: BeforePreferences = BeforePreferencesStore.load()
    ) async -> MirrorResult? {
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineMirrorResult(
            base: base,
            input: input,
            preference: preferences.preferredIntelligenceProvider,
            allowFallbacks: preferences.allowModelFallbacks
        )
    }
}
