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
        XCTAssertTrue(openModelDescriptor?.detail.contains("Import or download a compatible local asset") == true)
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

    func testOpenModelRuntimeRegistrationUsesConfiguredImportedAssetWhenAvailable() throws {
        let sourceDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let sourceURL = temporaryFileURL(
            in: sourceDirectory,
            name: "mistral-7b.gguf",
            size: 4_200
        )
        let imported = try OpenModelAssetCatalog.importModel(
            from: sourceURL,
            baseDirectoryURL: libraryDirectory
        )
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

        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: imported.assetID,
            registry: registry,
            baseDirectoryURL: libraryDirectory
        )

        let status = registry.statusesByKind()[.openModel]
        let descriptor = registry.descriptor(for: .openModel)

        XCTAssertEqual(status?.kind, .openModel)
        XCTAssertTrue(status?.isAvailable == true)
        XCTAssertEqual(descriptor?.openModel?.stableID, imported.generatedStableID)
        XCTAssertEqual(descriptor?.title, imported.displayTitle)
    }

    func testOpenModelRuntimeRegistrationFallsBackToReservedSlotWhenLibraryIsEmpty() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [.openModel: OpenModelDecisionIntelligenceProvider(kind: .openModel, adapter: FakeOpenModelAdapter())],
            descriptorsByKind: [
                .openModel: DecisionModelProviderDescriptor(
                    kind: .openModel,
                    title: "Future open model",
                    detail: "Fake slot.",
                    track: .builtInOpenModel,
                    openModel: FakeOpenModelAdapter().descriptor,
                    taskAffinities: [
                        .quick: 82,
                        .balance: 87,
                        .mirror: 92,
                        .reminder: 80
                    ]
                )
            ]
        )

        DecisionOpenModelRuntimeRegistration.syncRegistry(
            preferredAssetID: nil,
            registry: registry,
            baseDirectoryURL: temporaryDirectoryURL()
        )

        let descriptor = registry.descriptor(for: .openModel)
        let status = registry.statusesByKind()[.openModel]
        XCTAssertEqual(descriptor?.openModel?.stableID, "before/open-model-slot")
        XCTAssertEqual(status?.title, "Waiting for import")
        XCTAssertTrue(status?.detail.contains("Import or download a compatible local model") == true)
    }

    func testConfiguredOpenModelPreviewAdapterReusesLocalHeuristicQuickEnhancement() async {
        let adapter = ConfiguredOpenModelPreviewAdapter(asset: makeOpenModelAsset())
        let heuristic = TemplateLocalModelAdapter()
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "After a rough day I want a shopping reward."
        )
        let base = QuickCheckResult(
            currentPerspective: "Base current perspective.",
            afterPerspective: "Base after perspective.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.leaveStimulus]
        )

        let refined = await adapter.refineQuickResult(
            base: base,
            input: input,
            strategy: nil,
            contextState: nil,
            neuralState: nil,
            brainState: nil
        )

        XCTAssertEqual(refined, heuristic.enhanceQuickResult(base, input: input))
        XCTAssertNotEqual(refined, base)
    }

    func testConfiguredOpenModelPreviewAdapterReusesLocalHeuristicBalanceAndMirrorEnhancement() async {
        let adapter = ConfiguredOpenModelPreviewAdapter(asset: makeOpenModelAsset())
        let heuristic = TemplateLocalModelAdapter()
        let balanceInput = BalanceBoardInput(
            prompt: "Should I accept the trip?",
            desire: "I want the trip",
            concern: "losing recovery time",
            constraint: "my budget is tight this month",
            longTerm: "I do not want to regret overspending later"
        )
        let balanceBase = BalanceBoardResult(
            headline: "Base balance headline.",
            summary: "Base balance summary.",
            focusTitle: "Let reality lead first",
            focusDescription: "Base focus description.",
            nextAction: "Base next action."
        )
        let mirrorInput = MirrorInput(
            prompt: "Should I keep doing this?",
            emotion: "afraid of losing them",
            relationship: "this relationship keeps asking me to get smaller",
            reality: "rent and family pressure are real",
            longTerm: "I do not want this pattern again",
            selfLens: "I feel unseen and unsafe"
        )
        let mirrorBase = MirrorResult(
            headline: "Base mirror headline.",
            coreTension: "Base mirror tension.",
            nextActionTitle: "Base mirror action title.",
            nextAction: "Base mirror action."
        )

        let refinedBalance = await adapter.refineBalanceResult(
            base: balanceBase,
            input: balanceInput,
            strategy: nil,
            contextState: nil,
            neuralState: nil,
            brainState: nil
        )
        let refinedMirror = await adapter.refineMirrorResult(
            base: mirrorBase,
            input: mirrorInput,
            strategy: nil,
            contextState: nil,
            neuralState: nil,
            brainState: nil
        )

        XCTAssertEqual(refinedBalance, heuristic.enhanceBalanceResult(balanceBase, input: balanceInput))
        XCTAssertEqual(refinedMirror, heuristic.enhanceMirrorResult(mirrorBase, input: mirrorInput))
        XCTAssertNotEqual(refinedBalance, balanceBase)
        XCTAssertNotEqual(refinedMirror, mirrorBase)
    }

    func testConfiguredOpenModelPreviewAdapterUsesLocalHeuristicReminderSelection() async {
        let adapter = ConfiguredOpenModelPreviewAdapter(asset: makeOpenModelAsset())
        let heuristic = TemplateLocalModelAdapter()
        let candidates = [
            ReminderSelectionCandidate(
                id: UUID(),
                content: "Treat yourself. You had a hard day.",
                rank: 0
            ),
            ReminderSelectionCandidate(
                id: UUID(),
                content: "Only replace what is actually needed.",
                rank: 1
            ),
            ReminderSelectionCandidate(
                id: UUID(),
                content: "Scroll a little more before deciding.",
                rank: 2
            )
        ]

        let selected = await adapter.pickReminder(
            from: candidates,
            scenario: .buy,
            prompt: "My charger is broken and I need a practical replacement.",
            mode: .quick,
            strategy: nil
        )

        let expectedContent = heuristic.pickReminder(
            from: candidates.map(\.content),
            scenario: .buy,
            prompt: "My charger is broken and I need a practical replacement.",
            mode: .quick
        )

        XCTAssertEqual(selected?.content, expectedContent)
        XCTAssertEqual(selected?.content, "Only replace what is actually needed.")
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
                            .primary: 98,
                            .comparative: 92,
                            .reflective: 90,
                            .selection: 88
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
                            bestFor: [.primary, .selection]
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
                        bestFor: [.comparative, .reflective]
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
                        bestFor: [.primary]
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
                        bestFor: [.reflective]
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
                        bestFor: [.primary, .comparative]
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
                        bestFor: [.comparative, .reflective]
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

    func testTaskRouterRejectsProviderThatCannotSatisfyStructuredOutputRequirement() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [:],
            descriptorsByKind: [
                .openModel: DecisionModelProviderDescriptor(
                    kind: .openModel,
                    title: "Loose open model",
                    detail: "Fast but not schema-safe.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [.balance: 98],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "lab/loose-open",
                        strengths: [.shortDialogue, .lowLatency],
                        weaknesses: [.structuredOutput],
                        latencyClass: .low,
                        memoryClass: .low,
                        supportedResponseLanguages: [.english],
                        supportsThinking: false,
                        supportsStructuredOutput: false,
                        supportsToolUse: true,
                        bestFor: [.primary]
                    )
                ),
                .gemmaE4B: DecisionModelProviderDescriptor(
                    kind: .gemmaE4B,
                    title: "Gemma",
                    detail: "Schema-safe runtime.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [.balance: 90],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "google/gemma",
                        strengths: [.structuredOutput, .deepReflection],
                        weaknesses: [],
                        latencyClass: .medium,
                        memoryClass: .medium,
                        supportedResponseLanguages: [.english],
                        supportsThinking: true,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.comparative]
                    )
                )
            ]
        )

        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .balance,
            entropy: .medium,
            runtimeGear: .balanced,
            preferredProvider: .openModel,
            contextBudget: 320,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .structuredBoard,
            tone: .groundedDirect,
            actionSpace: ["surface_priority", "next_step"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .balance,
            preference: .openModel,
            allowFallbacks: true,
            registry: registry,
            strategy: strategy
        )

        XCTAssertEqual(ordered.first, .gemmaE4B)
        XCTAssertFalse(ordered.contains(DecisionModelProviderKind.openModel))
    }

    func testTaskRouterReturnsNoFallbackCandidatesWhenAllAreIncompatible() {
        let registry = DecisionIntelligenceProviderRegistry(
            providersByKind: [:],
            descriptorsByKind: [
                .foundationModels: DecisionModelProviderDescriptor(
                    kind: .foundationModels,
                    title: "Foundation",
                    detail: "English-only and no thinking.",
                    track: .builtInSystem,
                    openModel: nil,
                    taskAffinities: [.mirror: 100],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "apple/foundation",
                        strengths: [.shortDialogue, .structuredOutput, .lowLatency],
                        weaknesses: [.deepReflection, .multilingualChinese],
                        latencyClass: .low,
                        memoryClass: .low,
                        supportedResponseLanguages: [.english],
                        supportsThinking: false,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.primary]
                    )
                ),
                .gemmaE4B: DecisionModelProviderDescriptor(
                    kind: .gemmaE4B,
                    title: "Gemma",
                    detail: "English-only and no gated thinking.",
                    track: .builtInOpenModel,
                    openModel: nil,
                    taskAffinities: [.mirror: 96],
                    capabilityProfile: DecisionModelCapabilityProfile(
                        modelID: "google/gemma-lite",
                        strengths: [.structuredOutput],
                        weaknesses: [.multilingualChinese, .deepReflection],
                        latencyClass: .medium,
                        memoryClass: .medium,
                        supportedResponseLanguages: [.english],
                        supportsThinking: false,
                        supportsStructuredOutput: true,
                        supportsToolUse: true,
                        bestFor: [.comparative]
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
            actionSpace: ["name_boundary"],
            responseLanguage: .chinese,
            allowsModelInvocation: true
        )

        let ordered = DecisionIntelligenceTaskRouter.orderedKinds(
            for: .mirror,
            preference: .foundationModels,
            allowFallbacks: true,
            registry: registry,
            strategy: strategy
        )

        XCTAssertTrue(ordered.isEmpty)
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
            bestFor: [.primary]
        )

        XCTAssertTrue(profile.supports(responseLanguage: .mixed))
    }
}

private extension DecisionIntelligenceProviderRegistryTests {
    func makeOpenModelAsset() -> OpenModelAsset {
        OpenModelAsset(
            fileName: "mistral-7b.gguf",
            fileSizeBytes: 4_200
        )
    }

    func temporaryDirectoryURL() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    func temporaryFileURL(in directory: URL, name: String, size: Int) -> URL {
        let url = directory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: UInt64(size))
            try? handle.close()
        }
        return url
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
            .primary: 82,
            .comparative: 87,
            .reflective: 92,
            .selection: 80
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
