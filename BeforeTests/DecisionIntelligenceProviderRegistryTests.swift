import XCTest
@testable import Before

final class DecisionIntelligenceProviderRegistryTests: XCTestCase {
    func testBuiltInRegistryExposesReservedOpenModelSlot() {
        let descriptors = DecisionIntelligenceProviderRegistry.shared.descriptors()

        let openModelDescriptor = descriptors.first { $0.kind == .openModel }

        XCTAssertNotNil(openModelDescriptor)
        XCTAssertEqual(openModelDescriptor?.track, .builtInOpenModel)
        XCTAssertEqual(openModelDescriptor?.openModel?.stableID, "before/open-model-slot")
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
                    openModel: ReservedOpenModelAdapter().descriptor
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
    }
}

private struct FakeOpenModelAdapter: DecisionOpenModelAdapting {
    let descriptor = DecisionOpenModelDescriptor(
        stableID: "lab/future-open-model",
        family: "Future family",
        version: "vNext",
        title: "Future open model",
        detail: "A fake adapter used to verify that the registry can swap open-model runtimes."
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
