import Foundation
import BASHostKit

typealias DecisionQuickRefinementHook = @Sendable (
    QuickCheckResult,
    QuickCheckInput,
    DecisionContextPreparedState?,
    DecisionNeuralState?,
    DecisionBrainState?,
    BASEBrainTurnResult?,
    BeforePreferences,
    BeforeRuntimePolicyResolution
) async -> QuickCheckResult?

typealias DecisionBalanceRefinementHook = @Sendable (
    BalanceBoardResult,
    BalanceBoardInput,
    DecisionContextPreparedState?,
    DecisionNeuralState?,
    DecisionBrainState?,
    BASEBrainTurnResult?,
    BeforePreferences,
    BeforeRuntimePolicyResolution
) async -> BalanceBoardResult?

typealias DecisionMirrorRefinementHook = @Sendable (
    MirrorResult,
    MirrorInput,
    DecisionContextPreparedState?,
    DecisionNeuralState?,
    DecisionBrainState?,
    BASEBrainTurnResult?,
    BeforePreferences,
    BeforeRuntimePolicyResolution
) async -> MirrorResult?

private actor DecisionIntelligenceCoordinatorTestingHookStore {
    private var quickRefinement: DecisionQuickRefinementHook?
    private var balanceRefinement: DecisionBalanceRefinementHook?
    private var mirrorRefinement: DecisionMirrorRefinementHook?

    func setQuickRefinement(_ handler: DecisionQuickRefinementHook?) {
        quickRefinement = handler
    }

    func quickRefinementHandler() -> DecisionQuickRefinementHook? {
        quickRefinement
    }

    func setBalanceRefinement(_ handler: DecisionBalanceRefinementHook?) {
        balanceRefinement = handler
    }

    func balanceRefinementHandler() -> DecisionBalanceRefinementHook? {
        balanceRefinement
    }

    func setMirrorRefinement(_ handler: DecisionMirrorRefinementHook?) {
        mirrorRefinement = handler
    }

    func mirrorRefinementHandler() -> DecisionMirrorRefinementHook? {
        mirrorRefinement
    }

    func reset() {
        quickRefinement = nil
        balanceRefinement = nil
        mirrorRefinement = nil
    }
}

struct DecisionIntelligenceRuntimeCoordination: Equatable, Sendable {
    let executionProfile: DecisionIntelligenceExecutionProfile
    let runtimeStatus: DecisionModelRuntimeStatus
    let runtimePolicyResolution: BeforeRuntimePolicyResolution

    var allowFallbacks: Bool {
        executionProfile.allowFallbacks
    }

    func strategy(for kind: DecisionIntelligenceTraceKind) -> DecisionAdaptiveTaskStrategy {
        executionProfile.strategy(for: kind)
    }

    func retrievalMode(for mode: DecisionMode) -> DecisionRetrievalMode {
        let traceKind = DecisionIntelligenceTraceKind(substrateKindID: mode.substrateModeID) ?? .quick
        return strategy(for: traceKind).retrievalMode
    }

    var retrievalModesByModeID: [String: String] {
        [
            DecisionMode.quick.substrateModeID: retrievalMode(for: .quick).rawValue,
            DecisionMode.balance.substrateModeID: retrievalMode(for: .balance).rawValue,
            DecisionMode.mirror.substrateModeID: retrievalMode(for: .mirror).rawValue
        ]
    }
}

enum DecisionIntelligenceCoordinator {
    private static let adapter: any LocalModelAdapting = TemplateLocalModelAdapter()
    private static let testingHooks = DecisionIntelligenceCoordinatorTestingHookStore()
    private static let fallbackOpenModelStatus = DecisionModelProviderStatus(
        kind: .openModel,
        isAvailable: false,
        title: "Reserved",
        detail: "No open-model runtime is registered."
    )

    private static func openModelStatus(
        from statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus]
    ) -> DecisionModelProviderStatus {
        statusesByKind[.openModel]
        ?? DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel]
        ?? fallbackOpenModelStatus
    }

    private static func gemmaStatus(
        from statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus]
    ) -> DecisionModelProviderStatus {
        statusesByKind[.gemmaE4B] ?? GemmaE4BIntelligenceService.availabilityStatus
    }

    private static func foundationStatus(
        from statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus]
    ) -> DecisionModelProviderStatus {
        statusesByKind[.foundationModels] ?? FoundationModelsIntelligenceService.availabilityStatus
    }

    static func setTestingQuickRefinementHandler(
        _ handler: DecisionQuickRefinementHook?
    ) async {
        await testingHooks.setQuickRefinement(handler)
    }

    static func setTestingBalanceRefinementHandler(
        _ handler: DecisionBalanceRefinementHook?
    ) async {
        await testingHooks.setBalanceRefinement(handler)
    }

    static func setTestingMirrorRefinementHandler(
        _ handler: DecisionMirrorRefinementHook?
    ) async {
        await testingHooks.setMirrorRefinement(handler)
    }

    static func resetTestingRefinementHandlers() async {
        await testingHooks.reset()
    }

    static func runtimeCoordination(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        openModelStatus: DecisionModelProviderStatus = DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered."
        ),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionIntelligenceRuntimeCoordination {
        let profile = executionProfile(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            openModelStatus: openModelStatus,
            gemmaStatus: gemmaStatus,
            foundationStatus: foundationStatus
        )

        return DecisionIntelligenceRuntimeCoordination(
            executionProfile: profile,
            runtimeStatus: runtimeStatus(
                profile: profile,
                preferences: preferences,
                testingStubProfile: testingStubProfile,
                runtimePolicyResolution: runtimePolicyResolution,
                openModelStatus: openModelStatus,
                gemmaStatus: gemmaStatus,
                foundationStatus: foundationStatus
            ),
            runtimePolicyResolution: runtimePolicyResolution
        )
    }

    static func runtimeCoordination(
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        device: DeviceCapabilitySnapshot = .current,
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus]
    ) -> DecisionIntelligenceRuntimeCoordination {
        runtimeCoordination(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            runtimePolicyResolution: runtimePolicyResolution,
            openModelStatus: openModelStatus(from: statusesByKind),
            gemmaStatus: gemmaStatus(from: statusesByKind),
            foundationStatus: foundationStatus(from: statusesByKind)
        )
    }

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
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy,
        openModelStatus: DecisionModelProviderStatus = DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered."
        ),
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus
    ) -> DecisionModelRuntimeStatus {
        runtimeCoordination(
            preferences: preferences,
            testingStubProfile: testingStubProfile,
            device: device,
            runtimePolicyResolution: runtimePolicyResolution,
            openModelStatus: openModelStatus,
            gemmaStatus: gemmaStatus,
            foundationStatus: foundationStatus
        ).runtimeStatus
    }

    private static func runtimeStatus(
        profile: DecisionIntelligenceExecutionProfile,
        preferences: BeforePreferences,
        testingStubProfile: DecisionTestingStubProfile?,
        runtimePolicyResolution: BeforeRuntimePolicyResolution,
        openModelStatus: DecisionModelProviderStatus,
        gemmaStatus: DecisionModelProviderStatus,
        foundationStatus: DecisionModelProviderStatus
    ) -> DecisionModelRuntimeStatus {
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
                routingPolicy: BeforeProductCompatibility.requireProviderRoutingPolicy(from: runtimePolicyResolution),
                routingRegistryVersion: runtimePolicyResolution.lineage.providerRoutingRegistryVersion,
                testingOverrideEnabled: testingStubProfile != nil,
                testingOverrideTitle: testingStubProfile?.title,
                profileDetail: profile.detail
            )
        )

        return DecisionModelRuntimeStatus(
            preferred: preferences.preferredIntelligenceProvider.kind,
            active: DecisionModelProviderKind(rawValue: summary.activeProviderID) ?? .template,
            fallback: summary.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:)),
            detail: summary.detail,
            policyLineage: runtimePolicyResolution.lineage
        )
    }

    static func route(
        prompt: String,
        scenario: ScenarioType? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        activeKillSwitches: [BASKillSwitchID] = []
    ) -> RoutedDecision {
        let fallback = DecisionModeRouter.route(prompt: prompt, scenario: scenario)
        let routed = if preferences.onDeviceIntelligenceMode.isEnabled {
            adapter.route(prompt: prompt, scenario: scenario, fallback: fallback)
        } else {
            fallback
        }
        return enforceRuntimeControlPlane(on: routed, activeKillSwitches: activeKillSwitches)
    }

    static func enforceRuntimeControlPlane(
        on routed: RoutedDecision,
        activeKillSwitches: [BASKillSwitchID]
    ) -> RoutedDecision {
        if activeKillSwitches.contains(.forceGuardMode), routed.mode != .mirror {
            return RoutedDecision(
                mode: .mirror,
                reason: "Runtime kill-switch policy forced guarded routing before the fast path could open."
            )
        }

        if activeKillSwitches.contains(.disableFastPath), routed.mode == .quick {
            return RoutedDecision(
                mode: .balance,
                reason: "Runtime kill-switch policy disabled the quick path and promoted this turn into a fuller review path."
            )
        }

        return routed
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
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async -> SelfReminder? {
        let deterministic = bestReminder(
            from: reminders,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            preferences: preferences
        )

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordination = runtimeCoordination(
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        )
        let reminderStrategy = coordination.strategy(for: .reminder)
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
            allowFallbacks: coordination.allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution
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
        eBrainTurn: BASEBrainTurnResult? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async -> QuickCheckResult? {
        if let testingHandler = await testingHooks.quickRefinementHandler() {
            return await testingHandler(
                base,
                input,
                contextState,
                neuralState,
                brainState,
                eBrainTurn,
                preferences,
                runtimePolicyResolution
            )
        }

        let coordination = runtimeCoordination(
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        )
        let quickStrategy = coordination
            .strategy(for: .quick)
            .clamped(using: eBrainTurn)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        let allowsProtectivePath = eBrainTurn?.actionPermit.mode.isProtective == true
        guard (preferences.onDeviceIntelligenceMode.isEnabled && quickStrategy.allowsModelInvocation)
                || allowsProtectivePath else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            strategy: quickStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            eBrainTurn: eBrainTurn,
            preference: quickStrategy.preferredProvider,
            allowFallbacks: coordination.allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async -> BalanceBoardResult? {
        if let testingHandler = await testingHooks.balanceRefinementHandler() {
            return await testingHandler(
                base,
                input,
                contextState,
                neuralState,
                brainState,
                eBrainTurn,
                preferences,
                runtimePolicyResolution
            )
        }

        let coordination = runtimeCoordination(
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        )
        let balanceStrategy = coordination
            .strategy(for: .balance)
            .clamped(using: eBrainTurn)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        let allowsProtectivePath = eBrainTurn?.actionPermit.mode.isProtective == true
        guard (preferences.onDeviceIntelligenceMode.isEnabled && balanceStrategy.allowsModelInvocation)
                || allowsProtectivePath else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            strategy: balanceStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            eBrainTurn: eBrainTurn,
            preference: balanceStrategy.preferredProvider,
            allowFallbacks: coordination.allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil,
        preferences: BeforePreferences = DecisionTestingInterface.effectivePreferences(),
        runtimePolicyResolution: BeforeRuntimePolicyResolution = BeforeProductCompatibility.resolvedRuntimePolicy
    ) async -> MirrorResult? {
        if let testingHandler = await testingHooks.mirrorRefinementHandler() {
            return await testingHandler(
                base,
                input,
                contextState,
                neuralState,
                brainState,
                eBrainTurn,
                preferences,
                runtimePolicyResolution
            )
        }

        let coordination = runtimeCoordination(
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        )
        let mirrorStrategy = coordination
            .strategy(for: .mirror)
            .clamped(using: eBrainTurn)
            .adapting(
                contextState: contextState,
                neuralState: neuralState,
                brainState: brainState
            )
        let allowsProtectivePath = eBrainTurn?.actionPermit.mode.isProtective == true
        guard (preferences.onDeviceIntelligenceMode.isEnabled && mirrorStrategy.allowsModelInvocation)
                || allowsProtectivePath else { return nil }
        return await DecisionIntelligenceProviderPipeline.refineMirrorResult(
            base: base,
            input: input,
            strategy: mirrorStrategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            eBrainTurn: eBrainTurn,
            preference: mirrorStrategy.preferredProvider,
            allowFallbacks: coordination.allowFallbacks,
            runtimePolicyResolution: runtimePolicyResolution
        )
    }
}
