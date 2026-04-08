import Foundation

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()

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
}
