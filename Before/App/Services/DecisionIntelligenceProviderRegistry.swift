import Foundation
import BASHostKit

typealias DecisionModelCapability = BASProviderCapability
typealias DecisionModelLatencyClass = BASProviderLatencyClass
typealias DecisionModelMemoryClass = BASProviderMemoryClass
typealias DecisionModelCapabilityProfile = BASProviderCapabilityProfile
typealias DecisionOpenModelDescriptor = BASOpenModelDescriptor
typealias DecisionModelProviderTrack = BASProviderTrack

protocol DecisionIntelligenceProviding: Sendable {
    var kind: DecisionModelProviderKind { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult?

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate?
}

protocol DecisionOpenModelAdapting: Sendable {
    var descriptor: DecisionOpenModelDescriptor { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult?

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate?
}

struct DecisionModelProviderDescriptor: Equatable, Sendable {
    let kind: DecisionModelProviderKind
    private let basDescriptor: BASProviderDescriptor

    var title: String { basDescriptor.title }
    var detail: String { basDescriptor.detail }
    var track: DecisionModelProviderTrack { basDescriptor.track }
    var openModel: DecisionOpenModelDescriptor? { basDescriptor.openModel }
    var capabilityProfile: DecisionModelCapabilityProfile { basDescriptor.capabilityProfile }
    var taskAffinities: [DecisionIntelligenceTraceKind: Int] {
        Dictionary(
            uniqueKeysWithValues: basDescriptor.taskAffinities.map { entry in
                (DecisionIntelligenceTaskRouter.hostTraceKind(entry.key), entry.value)
            }
        )
    }

    init(
        kind: DecisionModelProviderKind,
        title: String,
        detail: String,
        track: DecisionModelProviderTrack,
        openModel: DecisionOpenModelDescriptor?,
        taskAffinities: [DecisionIntelligenceTraceKind: Int],
        capabilityProfile: DecisionModelCapabilityProfile? = nil
    ) {
        self.kind = kind
        self.basDescriptor = BASProviderDescriptor(
            providerID: kind.rawValue,
            title: title,
            detail: detail,
            track: track,
            openModel: openModel,
            taskAffinities: Dictionary(
                uniqueKeysWithValues: taskAffinities.map { entry in
                    (DecisionIntelligenceTaskRouter.substrateTraceKind(entry.key), entry.value)
                }
            ),
            capabilityProfile: capabilityProfile ?? openModel?.capabilityProfile ?? .generic(
                modelID: kind.rawValue,
                bestFor: taskAffinities.keys.map(DecisionIntelligenceTaskRouter.substrateTraceKind)
            )
        )
    }

    init(kind: DecisionModelProviderKind, basDescriptor: BASProviderDescriptor) {
        self.kind = kind
        self.basDescriptor = basDescriptor
    }

    func affinity(for task: DecisionIntelligenceTraceKind) -> Int {
        basDescriptor.affinity(for: DecisionIntelligenceTaskRouter.substrateTraceKind(task))
    }

    var substrateDescriptor: BASProviderDescriptor { basDescriptor }
}

struct OpenModelDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    let kind: DecisionModelProviderKind
    let adapter: any DecisionOpenModelAdapting

    var availabilityStatus: DecisionModelProviderStatus {
        adapter.availabilityStatus
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        await adapter.refineQuickResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        await adapter.refineBalanceResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        await adapter.refineMirrorResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        await adapter.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy
        )
    }
}

struct GemmaOpenModelAdapter: DecisionOpenModelAdapting {
    let descriptor = DecisionOpenModelDescriptor(
        stableID: "google/gemma-4-e4b-it",
        family: "Gemma 4",
        version: "E4B",
        title: "Gemma 4 E4B",
        detail: "Built-in open-model adapter. Future bundled open-source runtimes can plug into the same provider contract without changing the intelligence pipeline.",
        taskAffinities: [
            .primary: 70,
            .comparative: 94,
            .reflective: 100,
            .selection: 84
        ],
        capabilityProfile: DecisionModelCapabilityProfile(
            modelID: "google/gemma-4-e4b-it",
            strengths: [
                .structuredOutput,
                .deepReflection,
                .retrievalGrounding,
                .multilingualChinese
            ],
            weaknesses: [],
            latencyClass: .medium,
            memoryClass: .medium,
            supportedResponseLanguages: [.english, .chinese, .mixed],
            supportsThinking: true,
            supportsStructuredOutput: true,
            supportsToolUse: true,
            bestFor: [.comparative, .reflective, .selection]
        )
    )

    var availabilityStatus: DecisionModelProviderStatus {
        GemmaE4BIntelligenceService.availabilityStatus
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        await GemmaE4BIntelligenceService.refineQuickResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        await GemmaE4BIntelligenceService.refineBalanceResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        await GemmaE4BIntelligenceService.refineMirrorResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            backendPolicy: DecisionTestingInterface.effectiveInferenceBackendPolicy()
        )
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        await GemmaE4BIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy,
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
        detail: "Reserved integration slot for future bundled or open-source local models. Replace this adapter to add a new model without rewriting the intelligence pipeline.",
        taskAffinities: [
            .primary: 88,
            .comparative: 90,
            .reflective: 92,
            .selection: 86
        ],
        capabilityProfile: DecisionModelCapabilityProfile(
            modelID: "before/open-model-slot",
            strengths: [
                .shortDialogue,
                .structuredOutput,
                .lightToolUse
            ],
            weaknesses: [
                .deepReflection
            ],
            latencyClass: .low,
            memoryClass: .low,
            supportedResponseLanguages: [.english],
            supportsThinking: false,
            supportsStructuredOutput: true,
            supportsToolUse: true,
            bestFor: [.primary, .selection]
        )
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
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        nil
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        nil
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        nil
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        nil
    }
}

struct FoundationDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .foundationModels }
    var availabilityStatus: DecisionModelProviderStatus { FoundationModelsIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        await FoundationModelsIntelligenceService.refineQuickResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        await FoundationModelsIntelligenceService.refineBalanceResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        await FoundationModelsIntelligenceService.refineMirrorResult(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        await FoundationModelsIntelligenceService.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy
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
                openModel: adapter.descriptor,
                taskAffinities: Dictionary(
                    uniqueKeysWithValues: adapter.descriptor.taskAffinities.map { entry in
                        (DecisionIntelligenceTaskRouter.hostTraceKind(entry.key), entry.value)
                    }
                ),
                capabilityProfile: adapter.descriptor.capabilityProfile
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
        BASReferenceProviderCatalog.defaultDescriptorsByID().reduce(into: [:]) { partialResult, entry in
            guard let kind = DecisionModelProviderKind(rawValue: entry.key) else { return }
            partialResult[kind] = DecisionModelProviderDescriptor(kind: kind, basDescriptor: entry.value)
        }
    }

    private static func defaultTaskAffinities(
        for kind: DecisionModelProviderKind
    ) -> [DecisionIntelligenceTraceKind: Int] {
        Dictionary(
            uniqueKeysWithValues: BASReferenceProviderCatalog.defaultTaskAffinities(providerID: kind.rawValue).map { entry in
                (DecisionIntelligenceTaskRouter.hostTraceKind(entry.key), entry.value)
            }
        )
    }
}

enum DecisionIntelligenceTaskRouter {
    static func orderedKinds(
        for task: DecisionIntelligenceTraceKind,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        excluding suspendedKinds: Set<DecisionModelProviderKind> = [],
        registry: DecisionIntelligenceProviderRegistry = .shared,
        strategy: DecisionAdaptiveTaskStrategy? = nil
    ) -> [DecisionModelProviderKind] {
        let plan = BASProviderRouteResolver.resolve(
            task: substrateTraceKind(task),
            preferredProviderID: preference.kind.rawValue,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
            preferenceOrderings: BASReferenceProviderRuntime.preferenceOrderings,
            suspendedProviderIDs: Set(suspendedKinds.map(\.rawValue)),
            strategy: strategy.map(substrateAdaptiveStrategy),
            descriptors: registry.descriptors().map(substrateProviderDescriptor)
        )

        return plan.orderedProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:))
    }

    static func substrateTraceKind(_ task: DecisionIntelligenceTraceKind) -> BASAdaptiveTraceKind {
        switch task {
        case .quick:
            .primary
        case .balance:
            .comparative
        case .mirror:
            .reflective
        case .reminder:
            .selection
        }
    }

    static func substrateAdaptiveStrategy(
        _ strategy: DecisionAdaptiveTaskStrategy
    ) -> BASAdaptiveTaskStrategy {
        let responseLanguage: BASAdaptiveResponseLanguage
        switch strategy.responseLanguage {
        case .english:
            responseLanguage = .english
        case .chinese:
            responseLanguage = .chinese
        case .mixed:
            responseLanguage = .mixed
        }

        let entropy: BASTaskEntropyClass
        switch strategy.entropy {
        case .low:
            entropy = .low
        case .medium:
            entropy = .medium
        case .high:
            entropy = .high
        }

        let runtimeGear: BASRuntimeGear
        switch strategy.runtimeGear {
        case .low:
            runtimeGear = .low
        case .balanced:
            runtimeGear = .balanced
        case .high:
            runtimeGear = .high
        }

        let retrievalMode: BASRetrievalMode
        switch strategy.retrievalMode {
        case .off:
            retrievalMode = .off
        case .filtered:
            retrievalMode = .filtered
        case .adaptive:
            retrievalMode = .adaptive
        }

        let thinkingMode: BASThinkingMode
        switch strategy.thinkingMode {
        case .off:
            thinkingMode = .off
        case .gated:
            thinkingMode = .gated
        }

        let outputMode: BASOutputMode
        switch strategy.outputMode {
        case .deterministicTemplate:
            outputMode = .deterministicTemplate
        case .guidedShort:
            outputMode = .guidedShort
        case .structuredBoard:
            outputMode = .structuredBoard
        case .reflectiveStructured:
            outputMode = .reflectiveStructured
        case .jsonShort:
            outputMode = .jsonShort
        }

        let tone: BASToneProfile
        switch strategy.tone {
        case .neutral:
            tone = .neutral
        case .briefWarm:
            tone = .briefWarm
        case .groundedDirect:
            tone = .groundedDirect
        case .reflectiveClear:
            tone = .reflectiveClear
        }

        return BASAdaptiveTaskStrategy(
            kind: substrateTraceKind(strategy.kind),
            entropy: entropy,
            runtimeGear: runtimeGear,
            contextBudget: strategy.contextBudget,
            outputCharacterBudget: strategy.outputCharacterBudget,
            timeBudgetMs: strategy.timeBudgetMs,
            toolCallBudget: strategy.toolCallBudget,
            retrievalItemBudget: strategy.retrievalItemBudget,
            retrievalMode: retrievalMode,
            thinkingMode: thinkingMode,
            outputMode: outputMode,
            tone: tone,
            actionSpace: strategy.actionSpace,
            responseLanguage: responseLanguage,
            allowsModelInvocation: strategy.allowsModelInvocation
        )
    }

    static func substrateProviderDescriptor(
        _ descriptor: DecisionModelProviderDescriptor
    ) -> BASProviderDescriptor {
        descriptor.substrateDescriptor
    }

    static func hostTraceKind(_ task: BASAdaptiveTraceKind) -> DecisionIntelligenceTraceKind {
        switch task {
        case .primary:
            .quick
        case .comparative:
            .balance
        case .reflective:
            .mirror
        case .selection:
            .reminder
        }
    }
}
