import XCTest
@testable import Before

final class DecisionIntelligenceProviderRegistryTests: XCTestCase {
    func testBuiltInRegistryExposesReservedOpenModelSlot() {
        let descriptors = DecisionIntelligenceProviderRegistry.shared.descriptors()

        let openModelDescriptor = descriptors.first { $0.kind == .openModel }
        let gemmaDescriptor = descriptors.first { $0.kind == .gemmaE4B }
        let foundationDescriptor = descriptors.first { $0.kind == .foundationModels }

        XCTAssertNotNil(openModelDescriptor)
        XCTAssertEqual(openModelDescriptor?.track, .builtInOpenModel)
        XCTAssertEqual(openModelDescriptor?.openModel?.stableID, "before/open-model-slot")
        XCTAssertEqual(gemmaDescriptor?.affinity(for: .mirror), 100)
        XCTAssertEqual(foundationDescriptor?.affinity(for: .quick), 100)
        XCTAssertEqual(gemmaDescriptor?.capabilityProfile.modelID, "google/gemma-4-e4b-it")
        XCTAssertEqual(foundationDescriptor?.capabilityProfile.latencyClass, .low)
    }

    func testRegistryCanSwapOpenModelAdapterWithoutChangingPipelineKinds() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [.openModel: OpenModelDecisionIntelligenceProvider(kind: .openModel, adapter: ReservedOpenModelAdapter())],
            descriptorsByKind: [
                .openModel: DecisionModelProviderDescriptor(
                    kind: .openModel,
                    title: "Open model runtime",
                    detail: "Reserved slot.",
                    track: .builtInOpenModel,
                    openModel: ReservedOpenModelAdapter().descriptor,
                    taskAffinities: [
                        .quick: 88,
                        .balance: 90,
                        .mirror: 92,
                        .reminder: 86
                    ]
                )
            ]
        )

        registry.registerOpenModel(kind: .openModel, adapter: FakeOpenModelAdapter())

        let status = registry.statusesByKind()[.openModel]
        let descriptor = registry.descriptor(for: .openModel)

        XCTAssertEqual(status?.kind, .openModel)
        XCTAssertEqual(status?.isAvailable, true)
        XCTAssertEqual(descriptor?.openModel?.stableID, "lab/future-open-model")
        XCTAssertEqual(descriptor?.title, "Future open model")
        XCTAssertEqual(descriptor?.affinity(for: .mirror), 92)
    }

    func testTaskRouterPrefersFoundationForQuickLatency() {
        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .quick,
            preference: .gemmaE4B,
            allowFallbacks: true
        )

        XCTAssertEqual(ordered.first, .foundationModels)
    }

    func testTaskRouterPrefersGemmaForMirrorDepth() {
        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .mirror,
            preference: .foundationModels,
            allowFallbacks: true
        )

        XCTAssertEqual(ordered.first, .gemmaE4B)
    }

    func testTaskRouterKeepsPinnedProviderWhenFallbacksAreOff() {
        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .mirror,
            preference: .foundationModels,
            allowFallbacks: false
        )

        XCTAssertEqual(ordered, [.foundationModels])
    }

    func testTaskRouterCanUseCapabilityProfileToDemoteOpenModelWhenLanguageDoesNotFit() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [:],
            descriptorsByKind: [
                .openModel: DecisionModelProviderDescriptor(
                    kind: .openModel,
                    title: "Open model runtime",
                    detail: "Reserved slot.",
                    track: .builtInOpenModel,
                    openModel: DecisionOpenModelDescriptor(
                        stableID: "lab/open-en",
                        family: "Lab",
                        version: "1",
                        title: "Open EN",
                        detail: "English-only experimental runtime.",
                        taskAffinities: [
                            .quick: 98,
                            .balance: 92,
                            .mirror: 90,
                            .reminder: 88
                        ],
                        capabilityProfile: DecisionModelCapabilityProfile(
                            modelID: "lab/open-en",
                            strengths: [.shortDialogue, .structuredOutput, .lowLatency],
                            weaknesses: [.multilingualChinese],
                            latencyClass: .low,
                            memoryClass: .low,
                            supportedResponseLanguages: [.english],
                            supportsThinking: false,
                            supportsStructuredOutput: true,
                            supportsToolUse: true,
                            bestFor: [.quick, .reminder]
                        )
                    ),
                    taskAffinities: [
                        .quick: 98,
                        .balance: 92,
                        .mirror: 90,
                        .reminder: 88
                    ]
                ),
                .gemmaE4B: DecisionModelProviderDescriptor(
                    kind: .gemmaE4B,
                    title: "Gemma",
                    detail: "Multilingual runtime.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [
                        .quick: 88,
                        .balance: 90,
                        .mirror: 94,
                        .reminder: 86
                    ],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "google/gemma",
                        strengths: [.structuredOutput, .multilingualChinese],
                        weaknesses: [],
                        latencyClass: .medium,
                        memoryClass: .medium,
                        supportedResponseLanguages: [.english, .chinese, .mixed],
                        supportsThinking: true,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.balance, .mirror]
                    )
                )
            ]
        )

        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            preferredProvider: .openModel,
            contextBudget: 220,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            responseLanguage: .chinese,
            allowsModelInvocation: true
        )

        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .quick,
            preference: .openModel,
            allowFallbacks: true,
            registry: registry,
            strategy: strategy
        )

        XCTAssertEqual(ordered.first, .gemmaE4B)
    }

    func testTaskRouterCanUseCapabilityProfileToPromoteThinkingReadyProvider() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [:],
            descriptorsByKind: [
                .foundationModels: DecisionModelProviderDescriptor(
                    kind: .foundationModels,
                    title: "Foundation",
                    detail: "Fast runtime.",
                    track: .builtInSystem,
                    openModel: nil,
                    taskAffinities: [
                        .mirror: 100
                    ],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "apple/foundation",
                        strengths: [.shortDialogue, .structuredOutput, .lowLatency],
                        weaknesses: [.deepReflection],
                        latencyClass: .low,
                        memoryClass: .low,
                        supportedResponseLanguages: [.english, .mixed],
                        supportsThinking: false,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.quick]
                    )
                ),
                .gemmaE4B: DecisionModelProviderDescriptor(
                    kind: .gemmaE4B,
                    title: "Gemma",
                    detail: "Reflective runtime.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [
                        .mirror: 96
                    ],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "google/gemma",
                        strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                        weaknesses: [],
                        latencyClass: .medium,
                        memoryClass: .medium,
                        supportedResponseLanguages: [.english, .mixed],
                        supportsThinking: true,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.mirror]
                    )
                )
            ]
        )

        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .high,
            preferredProvider: .foundationModels,
            contextBudget: 540,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern", "name_boundary"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .mirror,
            preference: .foundationModels,
            allowFallbacks: true,
            registry: registry,
            strategy: strategy
        )

        XCTAssertEqual(ordered.first, .gemmaE4B)
    }

    func testTaskRouterCanUseLowGearStrategyToPromoteLowLatencyProviderForBalance() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [:],
            descriptorsByKind: [
                .foundationModels: DecisionModelProviderDescriptor(
                    kind: .foundationModels,
                    title: "Foundation",
                    detail: "Fast runtime.",
                    track: .builtInSystem,
                    openModel: nil,
                    taskAffinities: [
                        .balance: 84
                    ],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "apple/foundation",
                        strengths: [.shortDialogue, .structuredOutput, .lowLatency, .lowMemory],
                        weaknesses: [.deepReflection],
                        latencyClass: .low,
                        memoryClass: .low,
                        supportedResponseLanguages: [.english, .mixed],
                        supportsThinking: false,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.quick, .balance]
                    )
                ),
                .gemmaE4B: DecisionModelProviderDescriptor(
                    kind: .gemmaE4B,
                    title: "Gemma",
                    detail: "Reflective runtime.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [
                        .balance: 96
                    ],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "google/gemma",
                        strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                        weaknesses: [],
                        latencyClass: .high,
                        memoryClass: .high,
                        supportedResponseLanguages: [.english, .mixed],
                        supportsThinking: true,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.balance, .mirror]
                    )
                )
            ]
        )

        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .balance,
            entropy: .medium,
            runtimeGear: .low,
            preferredProvider: .gemmaE4B,
            contextBudget: 260,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .structuredBoard,
            tone: .briefWarm,
            actionSpace: ["surface_priority", "save_state"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .balance,
            preference: .gemmaE4B,
            allowFallbacks: true,
            registry: registry,
            strategy: strategy
        )

        XCTAssertEqual(ordered.first, .foundationModels)
    }

    func testCapabilityProfileTreatsBilingualSupportAsMixedLanguageReady() {
        let profile = DecisionModelCapabilityProfile(
            modelID: "lab/bilingual",
            strengths: [.structuredOutput, .multilingualChinese],
            weaknesses: [],
            latencyClass: .medium,
            memoryClass: .medium,
            supportedResponseLanguages: [.english, .chinese],
            supportsThinking: false,
            supportsStructuredOutput: true,
            supportsToolUse: false,
            bestFor: [.quick]
        )

        XCTAssertTrue(profile.supports(responseLanguage: .mixed))
    }
}

private struct FakeOpenModelAdapter: DecisionOpenModelAdapting {
    let descriptor = DecisionOpenModelDescriptor(
        stableID: "lab/future-open-model",
        family: "Future family",
        version: "vNext",
        title: "Future open model",
        detail: "A fake adapter used to verify that the registry can swap open-model runtimes.",
        taskAffinities: [
            .quick: 82,
            .balance: 87,
            .mirror: 92,
            .reminder: 80
        ]
    )

    var availabilityStatus: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: true,
            title: "Ready",
            detail: "Future open model is ready."
        )
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        base
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        base
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        base
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        candidates.first
    }
}
