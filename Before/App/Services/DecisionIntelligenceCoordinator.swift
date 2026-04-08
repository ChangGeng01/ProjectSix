import Foundation

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()

    static func executionProfile(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionIntelligenceExecutionProfile {
        DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: preferences,
            device: device,
            foundationStatus: foundationStatus,
            gemmaStatus: gemmaStatus,
            testingStubProfile: testingStubProfile
        )
    }

    static func runtimeStatus(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionModelRuntimeStatus {
        let profile = executionProfile(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            gemmaStatus: gemmaStatus,
            foundationStatus: foundationStatus
        )
        let runtimePreferences = BeforePreferences(
            homePromptAction: preferences.homePromptAction,
            quickBufferDuration: preferences.quickBufferDuration,
            restoreInProgressWorkspaces: preferences.restoreInProgressWorkspaces,
            showReviewInsights: preferences.showReviewInsights,
            onDeviceIntelligenceMode: preferences.onDeviceIntelligenceMode,
            preferredIntelligenceProvider: profile.effectiveProviderPreference,
            allowModelFallbacks: profile.allowFallbacks
        )

        var status = DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: runtimePreferences,
            statusesByKind: [
                .gemmaE4B: gemmaStatus,
                .foundationModels: foundationStatus
            ],
            testingStubProfile: testingStubProfile
        )

        if status.active == .template || profile.effectiveProviderPreference != preferences.preferredIntelligenceProvider {
            let fallback: DecisionModelProviderKind?
            if status.active == .template && preferences.preferredIntelligenceProvider != .template {
                fallback = .template
            } else if status.active != preferences.preferredIntelligenceProvider.kind {
                fallback = status.active
            } else {
                fallback = status.fallback
            }

            status = DecisionModelRuntimeStatus(
                preferred: preferences.preferredIntelligenceProvider.kind,
                active: status.active,
                fallback: fallback,
                detail: profile.detail
            )
        }

        return status
    }

    static func route(
        prompt: String,
        scenario: ScenarioType? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) -> RoutedDecision {
        let fallback = DecisionModeRouter.route(prompt: prompt, scenario: scenario)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.route(prompt: prompt, scenario: scenario, fallback: fallback)
    }

    static func quickResult(
        for input: QuickCheckInput,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) -> QuickCheckResult {
        let fallback = CheckRuleEngine.evaluate(input)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.enhanceQuickResult(fallback, input: input)
    }

    static func balanceResult(
        for input: BalanceBoardInput,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) -> BalanceBoardResult {
        let fallback = BalanceBoardEngine.evaluate(input)
        guard preferences.onDeviceIntelligenceMode.isEnabled else { return fallback }
        return adapter.enhanceBalanceResult(fallback, input: input)
    }

    static func mirrorResult(
        for input: MirrorInput,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
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
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
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

    @MainActor
    static func bestReminderWithIntelligence(
        from reminders: [SelfReminder],
        scenario: ScenarioType,
        prompt: String = "",
        mode: DecisionMode? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> SelfReminder? {
        let deterministic = bestReminder(
            from: reminders,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            preferences: preferences
        )

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = executionProfile(preferences: preferences)
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              profile.allowsReminderSelection,
              profile.effectiveProviderPreference != .template,
              !trimmedPrompt.isEmpty else {
            return deterministic
        }

        let ranked = ReminderSelectionPolicy.ranked(reminders: reminders.filter { $0.scenario == scenario })
        let candidates = ranked.map { ReminderSelectionCandidate(id: $0.id, content: $0.content) }

        guard let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: trimmedPrompt,
            mode: mode,
            preference: profile.effectiveProviderPreference,
            allowFallbacks: profile.allowFallbacks
        ) else {
            return deterministic
        }

        return ranked.first(where: { $0.id == selected.id }) ?? deterministic
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> QuickCheckResult? {
        let profile = executionProfile(preferences: preferences)
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              profile.allowsQuickRefinement else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            preference: profile.effectiveProviderPreference,
            allowFallbacks: profile.allowFallbacks
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> BalanceBoardResult? {
        let profile = executionProfile(preferences: preferences)
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              profile.allowsBalanceRefinement else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            preference: profile.effectiveProviderPreference,
            allowFallbacks: profile.allowFallbacks
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> MirrorResult? {
        let profile = executionProfile(preferences: preferences)
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              profile.allowsMirrorRefinement else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineMirrorResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            preference: profile.effectiveProviderPreference,
            allowFallbacks: profile.allowFallbacks
        )
    }
}
