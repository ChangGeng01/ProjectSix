import Foundation

protocol DecisionIntelligenceProviding: Sendable {
    var kind: DecisionModelProviderKind { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult?

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate?
}

protocol DecisionOpenModelAdapting: Sendable {
    var descriptor: DecisionOpenModelDescriptor { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult?

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate?
}

struct DecisionOpenModelDescriptor: Equatable, Sendable {
    let stableID: String
    let family: String
    let version: String
    let title: String
    let detail: String
}

enum DecisionModelProviderTrack: String, Equatable, Sendable {
    case builtInOpenModel
    case builtInSystem
    case testingOnly
    case deterministic
}

struct DecisionModelProviderDescriptor: Equatable, Sendable {
    let kind: DecisionModelProviderKind
    let title: String
    let detail: String
    let track: DecisionModelProviderTrack
    let openModel: DecisionOpenModelDescriptor?
}

struct OpenModelDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    let kind: DecisionModelProviderKind
    let adapter: any DecisionOpenModelAdapting

    var availabilityStatus: DecisionModelProviderStatus {
        adapter.availabilityStatus
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await adapter.refineQuickResult(base: base, input: input)
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await adapter.refineBalanceResult(base: base, input: input)
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await adapter.refineMirrorResult(base: base, input: input)
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        await adapter.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
    }
}

struct GemmaOpenModelAdapter: DecisionOpenModelAdapting {
    let descriptor = DecisionOpenModelDescriptor(
        stableID: "google/gemma-4-e4b-it",
        family: "Gemma 4",
        version: "E4B",
        title: "Gemma 4 E4B",
        detail: "Built-in open-model adapter. Future bundled open-source runtimes can plug into the same provider contract without changing the intelligence pipeline."
    )

    var availabilityStatus: DecisionModelProviderStatus {
        GemmaE4BIntelligenceService.availabilityStatus
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await GemmaE4BIntelligenceService.refineQuickResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await GemmaE4BIntelligenceService.refineBalanceResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await GemmaE4BIntelligenceService.refineMirrorResult(
            base: base,
            input: input,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        await GemmaE4BIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }
}

struct ReservedOpenModelAdapter: DecisionOpenModelAdapting {
    let descriptor = DecisionOpenModelDescriptor(
        stableID: "before/open-model-slot",
        family: "Open model runtime",
        version: "reserved",
        title: "Open model runtime",
        detail: "Reserved integration slot for future bundled or open-source local models. Replace this adapter to add a new model without rewriting the intelligence pipeline."
    )

    var availabilityStatus: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered yet. This slot is ready for future bundled or open-source local model adapters."
        )
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        nil
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        nil
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        nil
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        nil
    }
}

struct FoundationDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .foundationModels }
    var availabilityStatus: DecisionModelProviderStatus { FoundationModelsIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await FoundationModelsIntelligenceService.refineQuickResult(base: base, input: input)
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await FoundationModelsIntelligenceService.refineBalanceResult(base: base, input: input)
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await FoundationModelsIntelligenceService.refineMirrorResult(base: base, input: input)
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        await FoundationModelsIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
    }
}

final class DecisionIntelligenceProviderRegistry: @unchecked Sendable {
    static let shared = DecisionIntelligenceProviderRegistry()

    private let lock = NSLock()
    private var providersByKind: [DecisionModelProviderKind: any DecisionIntelligenceProviding]
    private var descriptorsByKind: [DecisionModelProviderKind: DecisionModelProviderDescriptor]

    init(
        providersByKind: [DecisionModelProviderKind: any DecisionIntelligenceProviding]? = nil,
        descriptorsByKind: [DecisionModelProviderKind: DecisionModelProviderDescriptor]? = nil
    ) {
        self.providersByKind = providersByKind ?? Self.defaultProvidersByKind()
        self.descriptorsByKind = descriptorsByKind ?? Self.defaultDescriptorsByKind()
    }

    func provider(for kind: DecisionModelProviderKind) -> (any DecisionIntelligenceProviding)? {
        lock.lock()
        defer { lock.unlock() }
        return providersByKind[kind]
    }

    func providers(for kinds: [DecisionModelProviderKind]) -> [any DecisionIntelligenceProviding] {
        lock.lock()
        defer { lock.unlock() }
        return kinds.compactMap { providersByKind[$0] }
    }

    func statusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        lock.lock()
        defer { lock.unlock() }
        return providersByKind.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.availabilityStatus
        }
    }

    func descriptors() -> [DecisionModelProviderDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByKind.values.sorted { lhs, rhs in
            lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    func descriptor(for kind: DecisionModelProviderKind) -> DecisionModelProviderDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByKind[kind]
    }

    func replace(
        provider: any DecisionIntelligenceProviding,
        descriptor: DecisionModelProviderDescriptor
    ) {
        lock.lock()
        defer { lock.unlock() }
        providersByKind[provider.kind] = provider
        descriptorsByKind[provider.kind] = descriptor
    }

    func registerOpenModel(
        kind: DecisionModelProviderKind,
        adapter: any DecisionOpenModelAdapting
    ) {
        replace(
            provider: OpenModelDecisionIntelligenceProvider(kind: kind, adapter: adapter),
            descriptor: DecisionModelProviderDescriptor(
                kind: kind,
                title: adapter.descriptor.title,
                detail: adapter.descriptor.detail,
                track: .builtInOpenModel,
                openModel: adapter.descriptor
            )
        )
    }

    private static func defaultProvidersByKind() -> [DecisionModelProviderKind: any DecisionIntelligenceProviding] {
        [
            .gemmaE4B: OpenModelDecisionIntelligenceProvider(kind: .gemmaE4B, adapter: GemmaOpenModelAdapter()),
            .foundationModels: FoundationDecisionIntelligenceProvider(),
            .openModel: OpenModelDecisionIntelligenceProvider(kind: .openModel, adapter: ReservedOpenModelAdapter())
        ]
    }

    private static func defaultDescriptorsByKind() -> [DecisionModelProviderKind: DecisionModelProviderDescriptor] {
        let gemmaDescriptor = GemmaOpenModelAdapter().descriptor
        let reservedOpenModelDescriptor = ReservedOpenModelAdapter().descriptor

        return [
            .gemmaE4B: DecisionModelProviderDescriptor(
                kind: .gemmaE4B,
                title: gemmaDescriptor.title,
                detail: gemmaDescriptor.detail,
                track: .builtInOpenModel,
                openModel: gemmaDescriptor
            ),
            .foundationModels: DecisionModelProviderDescriptor(
                kind: .foundationModels,
                title: "Apple Foundation Model",
                detail: "Built-in system-managed language provider.",
                track: .builtInSystem,
                openModel: nil
            ),
            .openModel: DecisionModelProviderDescriptor(
                kind: .openModel,
                title: reservedOpenModelDescriptor.title,
                detail: reservedOpenModelDescriptor.detail,
                track: .builtInOpenModel,
                openModel: reservedOpenModelDescriptor
            )
        ]
    }
}
