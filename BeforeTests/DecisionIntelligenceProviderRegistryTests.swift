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
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        base
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        base
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        base
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        candidates.first
    }
}
