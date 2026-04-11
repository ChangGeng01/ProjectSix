import Foundation
import BASAppleAdapters

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()

    static func executionProfile(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        openModelStatus: DecisionModelProviderStatus = DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered."
        ),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionIntelligenceExecutionProfile {
        DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: preferences,
            device: device,
            openModelStatus: openModelStatus,
            foundationStatus: foundationStatus,
            gemmaStatus: gemmaStatus,
            testingStubProfile: testingStubProfile
        )
    }

    static func runtimeStatus(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        openModelStatus: DecisionModelProviderStatus = DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered."
        ),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionModelRuntimeStatus {
        let profile = executionProfile(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            openModelStatus: openModelStatus,
            gemmaStatus: gemmaStatus,
            foundationStatus: foundationStatus
        )
        let statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = [
            .openModel: openModelStatus,
            .gemmaE4B: gemmaStatus,
            .foundationModels: foundationStatus
        ]
        let summary = BASAppleProviderRuntimeStatusAdapter.hostVisibleRuntimeStatus(
            from: BASAppleHostVisibleRuntimeStatusInput(
                requestedProviderID: preferences.preferredIntelligenceProvider.kind.rawValue,
                effectiveProviderID: profile.effectiveProviderPreference.kind.rawValue,
                allowFallbacks: profile.allowFallbacks,
                runtimeEnabled: preferences.onDeviceIntelligenceMode.isEnabled,
                statusesByID: BASAppleProviderHostBridge.statusRecords(
                    statusesByKind,
                    keyID: \.rawValue,
                    isAvailable: \.isAvailable,
                    title: \.title,
                    detail: \.detail
                ),
                testingOverrideEnabled: testingStubProfile != nil,
                testingOverrideTitle: testingStubProfile?.title,
                profileDetail: profile.detail
            )
        )

        return DecisionModelRuntimeStatus(
            preferred: preferences.preferredIntelligenceProvider.kind,
            active: DecisionModelProviderKind(rawValue: summary.activeProviderID) ?? .template,
            fallback: summary.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:)),
            detail: summary.detail
        )
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
        let reminderStrategy = profile.strategy(for: .reminder)
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              reminderStrategy.allowsModelInvocation,
              !trimmedPrompt.isEmpty else {
            return deterministic
        }

        let ranked = ReminderSelectionPolicy.ranked(reminders: reminders.filter { $0.scenario == scenario })
        let candidates = ranked.enumerated().map { index, reminder in
            ReminderSelectionCandidate(
                id: reminder.id,
                content: reminder.content,
                rank: index,
                source: reminder.source,
                useCount: reminder.useCount
            )
        }

        guard let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: trimmedPrompt,
            mode: mode,
            strategy: reminderStrategy,
            preference: reminderStrategy.preferredProvider,
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
        brainState: DecisionBrainState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> QuickCheckResult? {
        let profile = executionProfile(preferences: preferences)
        let quickStrategy = profile
            .strategy(for: .quick)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              quickStrategy.allowsModelInvocation else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            strategy: quickStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            preference: quickStrategy.preferredProvider,
            allowFallbacks: profile.allowFallbacks
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> BalanceBoardResult? {
        let profile = executionProfile(preferences: preferences)
        let balanceStrategy = profile
            .strategy(for: .balance)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              balanceStrategy.allowsModelInvocation else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            strategy: balanceStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            preference: balanceStrategy.preferredProvider,
            allowFallbacks: profile.allowFallbacks
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences()
    ) async -> MirrorResult? {
        let profile = executionProfile(preferences: preferences)
        let mirrorStrategy = profile
            .strategy(for: .mirror)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        guard preferences.onDeviceIntelligenceMode.isEnabled,
              mirrorStrategy.allowsModelInvocation else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineMirrorResult(
            base: base,
            input: input,
            strategy: mirrorStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            preference: mirrorStrategy.preferredProvider,
            allowFallbacks: profile.allowFallbacks
        )
    }
}
