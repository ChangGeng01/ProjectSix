import Foundation

enum DecisionModelCapability: String, CaseIterable, Codable, Sendable {
    case shortDialogue = "short_dialogue"
    case structuredOutput = "structured_output"
    case lightToolUse = "light_tool_use"
    case deepReflection = "deep_reflection"
    case retrievalGrounding = "retrieval_grounding"
    case multilingualChinese = "multilingual_chinese"
    case lowLatency = "low_latency"
    case lowMemory = "low_memory"
}

enum DecisionModelLatencyClass: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

enum DecisionModelMemoryClass: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

struct DecisionModelCapabilityProfile: Equatable, Sendable {
    let modelID: String
    let strengths: [DecisionModelCapability]
    let weaknesses: [DecisionModelCapability]
    let latencyClass: DecisionModelLatencyClass
    let memoryClass: DecisionModelMemoryClass
    let supportedResponseLanguages: [DecisionAdaptiveResponseLanguage]
    let supportsThinking: Bool
    let supportsStructuredOutput: Bool
    let supportsToolUse: Bool
    let bestFor: [DecisionIntelligenceTraceKind]

    func supports(_ capability: DecisionModelCapability) -> Bool {
        strengths.contains(capability) && !weaknesses.contains(capability)
    }

    func supports(responseLanguage: DecisionAdaptiveResponseLanguage) -> Bool {
        if supportedResponseLanguages.contains(responseLanguage) {
            return true
        }

        if responseLanguage == .mixed {
            return supportedResponseLanguages.contains(.english) &&
                supportedResponseLanguages.contains(.chinese)
        }

        return false
    }

    static func generic(
        modelID: String,
        bestFor: [DecisionIntelligenceTraceKind] = []
    ) -> DecisionModelCapabilityProfile {
        DecisionModelCapabilityProfile(
            modelID: modelID,
            strengths: [.structuredOutput],
            weaknesses: [],
            latencyClass: .medium,
            memoryClass: .medium,
            supportedResponseLanguages: [.english],
            supportsThinking: false,
            supportsStructuredOutput: true,
            supportsToolUse: false,
            bestFor: bestFor
        )
    }
}

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

struct DecisionOpenModelDescriptor: Equatable, Sendable {
    let stableID: String
    let family: String
    let version: String
    let title: String
    let detail: String
    let taskAffinities: [DecisionIntelligenceTraceKind: Int]
    let capabilityProfile: DecisionModelCapabilityProfile

    init(
        stableID: String,
        family: String,
        version: String,
        title: String,
        detail: String,
        taskAffinities: [DecisionIntelligenceTraceKind: Int],
        capabilityProfile: DecisionModelCapabilityProfile? = nil
    ) {
        self.stableID = stableID
        self.family = family
        self.version = version
        self.title = title
        self.detail = detail
        self.taskAffinities = taskAffinities
        self.capabilityProfile = capabilityProfile ?? .generic(
            modelID: stableID,
            bestFor: Array(taskAffinities.keys)
        )
    }
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
    let taskAffinities: [DecisionIntelligenceTraceKind: Int]
    let capabilityProfile: DecisionModelCapabilityProfile

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
        self.title = title
        self.detail = detail
        self.track = track
        self.openModel = openModel
        self.taskAffinities = taskAffinities
        self.capabilityProfile = capabilityProfile ?? openModel?.capabilityProfile ?? .generic(
            modelID: kind.rawValue,
            bestFor: Array(taskAffinities.keys)
        )
    }

    func affinity(for task: DecisionIntelligenceTraceKind) -> Int {
        taskAffinities[task] ?? 0
    }
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
            .quick: 70,
            .balance: 94,
            .mirror: 100,
            .reminder: 84
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
            bestFor: [.balance, .mirror, .reminder]
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
            .quick: 88,
            .balance: 90,
            .mirror: 92,
            .reminder: 86
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
            bestFor: [.quick, .reminder]
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
                taskAffinities: adapter.descriptor.taskAffinities,
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
        let gemmaDescriptor = GemmaOpenModelAdapter().descriptor
        let reservedOpenModelDescriptor = ReservedOpenModelAdapter().descriptor

        return [
            .gemmaE4B: DecisionModelProviderDescriptor(
                kind: .gemmaE4B,
                title: gemmaDescriptor.title,
                detail: gemmaDescriptor.detail,
                track: .builtInOpenModel,
                openModel: gemmaDescriptor,
                taskAffinities: gemmaDescriptor.taskAffinities,
                capabilityProfile: gemmaDescriptor.capabilityProfile
            ),
            .foundationModels: DecisionModelProviderDescriptor(
                kind: .foundationModels,
                title: "Apple Foundation Model",
                detail: "Built-in system-managed language provider.",
                track: .builtInSystem,
                openModel: nil,
                taskAffinities: defaultTaskAffinities(for: .foundationModels),
                capabilityProfile: DecisionModelCapabilityProfile(
                    modelID: "apple/foundation-model-default",
                    strengths: [
                        .shortDialogue,
                        .structuredOutput,
                        .lightToolUse,
                        .lowLatency,
                        .lowMemory,
                        .multilingualChinese
                    ],
                    weaknesses: [],
                    latencyClass: .low,
                    memoryClass: .low,
                    supportedResponseLanguages: [.english, .chinese, .mixed],
                    supportsThinking: false,
                    supportsStructuredOutput: true,
                    supportsToolUse: true,
                    bestFor: [.quick, .reminder]
                )
            ),
            .openModel: DecisionModelProviderDescriptor(
                kind: .openModel,
                title: reservedOpenModelDescriptor.title,
                detail: reservedOpenModelDescriptor.detail,
                track: .builtInOpenModel,
                openModel: reservedOpenModelDescriptor,
                taskAffinities: reservedOpenModelDescriptor.taskAffinities,
                capabilityProfile: reservedOpenModelDescriptor.capabilityProfile
            )
        ]
    }

    private static func defaultTaskAffinities(
        for kind: DecisionModelProviderKind
    ) -> [DecisionIntelligenceTraceKind: Int] {
        switch kind {
        case .gemmaE4B:
            [
                .quick: 70,
                .balance: 94,
                .mirror: 100,
                .reminder: 84
            ]
        case .openModel:
            [
                .quick: 88,
                .balance: 90,
                .mirror: 92,
                .reminder: 86
            ]
        case .foundationModels:
            [
                .quick: 100,
                .balance: 78,
                .mirror: 72,
                .reminder: 92
            ]
        case .testingStub:
            [
                .quick: 100,
                .balance: 100,
                .mirror: 100,
                .reminder: 100
            ]
        case .template:
            [
                .quick: 0,
                .balance: 0,
                .mirror: 0,
                .reminder: 0
            ]
        }
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
        let baseKinds = DecisionIntelligenceProviderPipeline.orderedKinds(
            for: preference,
            allowFallbacks: allowFallbacks,
            excluding: suspendedKinds
        )

        guard allowFallbacks, baseKinds.count > 1 else { return baseKinds }

        let descriptorByKind = Dictionary(
            uniqueKeysWithValues: registry.descriptors().map { ($0.kind, $0) }
        )
        let baseIndexByKind = Dictionary(
            uniqueKeysWithValues: baseKinds.enumerated().map { ($0.element, $0.offset) }
        )
        let compatibleKinds = strategy.map { strategy in
            baseKinds.filter { kind in
                isCompatible(
                    with: strategy,
                    descriptor: descriptorByKind[kind]
                )
            }
        } ?? baseKinds

        guard !compatibleKinds.isEmpty else { return [] }

        return compatibleKinds.sorted { lhs, rhs in
            let lhsScore = routingScore(
                kind: lhs,
                task: task,
                preferredKind: preference.kind,
                descriptor: descriptorByKind[lhs],
                baseIndex: baseIndexByKind[lhs] ?? 0,
                strategy: strategy
            )
            let rhsScore = routingScore(
                kind: rhs,
                task: task,
                preferredKind: preference.kind,
                descriptor: descriptorByKind[rhs],
                baseIndex: baseIndexByKind[rhs] ?? 0,
                strategy: strategy
            )

            if lhsScore == rhsScore {
                return (baseIndexByKind[lhs] ?? 0) < (baseIndexByKind[rhs] ?? 0)
            }

            return lhsScore > rhsScore
        }
    }

    private static func isCompatible(
        with strategy: DecisionAdaptiveTaskStrategy,
        descriptor: DecisionModelProviderDescriptor?
    ) -> Bool {
        guard let profile = descriptor?.capabilityProfile else { return true }

        if !profile.supports(responseLanguage: strategy.responseLanguage) {
            return false
        }

        if strategy.thinkingMode == .gated, !profile.supportsThinking {
            return false
        }

        if strategy.outputMode != .deterministicTemplate, !profile.supportsStructuredOutput {
            return false
        }

        return true
    }

    private static func routingScore(
        kind: DecisionModelProviderKind,
        task: DecisionIntelligenceTraceKind,
        preferredKind: DecisionModelProviderKind,
        descriptor: DecisionModelProviderDescriptor?,
        baseIndex: Int,
        strategy: DecisionAdaptiveTaskStrategy?
    ) -> Int {
        let affinity = descriptor?.affinity(for: task) ?? 0
        let preferredBias = kind == preferredKind ? 8 : 0
        let baseBias = max(0, 24 - (baseIndex * 12))
        let capabilityBias = strategy.map {
            capabilityScore(for: $0, descriptor: descriptor)
        } ?? 0
        return (affinity * 10) + preferredBias + baseBias + capabilityBias
    }

    private static func capabilityScore(
        for strategy: DecisionAdaptiveTaskStrategy,
        descriptor: DecisionModelProviderDescriptor?
    ) -> Int {
        guard let profile = descriptor?.capabilityProfile else { return 0 }

        var score = 0

        if profile.bestFor.contains(strategy.kind) {
            score += 14
        }

        if strategy.outputMode != .deterministicTemplate {
            score += profile.supportsStructuredOutput ? 12 : -120
        }

        if strategy.thinkingMode == .gated {
            score += profile.supportsThinking ? 18 : -120
        }

        if strategy.retrievalMode == .adaptive {
            score += profile.supports(.retrievalGrounding) ? 10 : -8
        }

        switch strategy.entropy {
        case .low:
            switch profile.latencyClass {
            case .low: score += 10
            case .medium: score += 4
            case .high: score -= 6
            }
        case .medium:
            score += profile.supports(.structuredOutput) ? 6 : 0
        case .high:
            score += profile.supports(.deepReflection) ? 14 : -10
            switch profile.memoryClass {
            case .high: score += 6
            case .medium: score += 2
            case .low: score -= 4
            }
        }

        switch strategy.runtimeGear {
        case .low:
            switch profile.latencyClass {
            case .low: score += 24
            case .medium: score += 8
            case .high: score -= 36
            }
            switch profile.memoryClass {
            case .low: score += 18
            case .medium: score += 4
            case .high: score -= 34
            }
            score += profile.supports(.lowLatency) ? 14 : -6
            score += profile.supports(.lowMemory) ? 14 : -6
        case .balanced:
            switch profile.latencyClass {
            case .low: score += 6
            case .medium: score += 8
            case .high: break
            }
            switch profile.memoryClass {
            case .low: score += 4
            case .medium: score += 6
            case .high: break
            }
        case .high:
            switch profile.latencyClass {
            case .low: score += 2
            case .medium: score += 6
            case .high: score += 8
            }
            switch profile.memoryClass {
            case .low: score -= 2
            case .medium: score += 4
            case .high: score += 8
            }
            score += profile.supports(.deepReflection) ? 12 : -6
        }

        if profile.supports(responseLanguage: strategy.responseLanguage) {
            score += 12
        } else {
            score -= 260
        }

        if strategy.actionSpace.contains("stay_brief") {
            score += profile.supports(.lowLatency) ? 6 : 0
            score += profile.supports(.lowMemory) ? 6 : 0
        }

        return score
    }
}
