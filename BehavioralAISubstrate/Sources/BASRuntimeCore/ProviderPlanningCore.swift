import Foundation

public enum BASProviderCapability: String, CaseIterable, Codable, Sendable {
    case shortDialogue = "short_dialogue"
    case structuredOutput = "structured_output"
    case lightToolUse = "light_tool_use"
    case deepReflection = "deep_reflection"
    case retrievalGrounding = "retrieval_grounding"
    case multilingualChinese = "multilingual_chinese"
    case lowLatency = "low_latency"
    case lowMemory = "low_memory"
}

public enum BASProviderLatencyClass: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public enum BASProviderMemoryClass: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public struct BASProviderCapabilityProfile: Codable, Equatable, Sendable {
    public var strengths: [BASProviderCapability]
    public var weaknesses: [BASProviderCapability]
    public var latencyClass: BASProviderLatencyClass
    public var memoryClass: BASProviderMemoryClass
    public var supportedResponseLanguages: [BASAdaptiveResponseLanguage]
    public var supportsThinking: Bool
    public var supportsStructuredOutput: Bool
    public var supportsToolUse: Bool
    public var bestFor: [BASAdaptiveTraceKind]

    public init(
        strengths: [BASProviderCapability],
        weaknesses: [BASProviderCapability] = [],
        latencyClass: BASProviderLatencyClass,
        memoryClass: BASProviderMemoryClass,
        supportedResponseLanguages: [BASAdaptiveResponseLanguage],
        supportsThinking: Bool,
        supportsStructuredOutput: Bool,
        supportsToolUse: Bool,
        bestFor: [BASAdaptiveTraceKind]
    ) {
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.latencyClass = latencyClass
        self.memoryClass = memoryClass
        self.supportedResponseLanguages = supportedResponseLanguages
        self.supportsThinking = supportsThinking
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsToolUse = supportsToolUse
        self.bestFor = bestFor
    }

    public func supports(_ capability: BASProviderCapability) -> Bool {
        strengths.contains(capability) && !weaknesses.contains(capability)
    }

    public func supports(responseLanguage: BASAdaptiveResponseLanguage) -> Bool {
        if supportedResponseLanguages.contains(responseLanguage) {
            return true
        }

        if responseLanguage == .mixed {
            return supportedResponseLanguages.contains(.english) &&
                supportedResponseLanguages.contains(.chinese)
        }

        return false
    }
}

public struct BASProviderDescriptor: Codable, Equatable, Sendable, Identifiable {
    public var id: String { providerID }
    public var providerID: String
    public var taskAffinities: [BASAdaptiveTraceKind: Int]
    public var capabilityProfile: BASProviderCapabilityProfile

    public init(
        providerID: String,
        taskAffinities: [BASAdaptiveTraceKind: Int],
        capabilityProfile: BASProviderCapabilityProfile
    ) {
        self.providerID = providerID
        self.taskAffinities = taskAffinities
        self.capabilityProfile = capabilityProfile
    }

    public func affinity(for task: BASAdaptiveTraceKind) -> Int {
        taskAffinities[task] ?? 0
    }
}

public struct BASProviderSelectionPlan: Codable, Equatable, Sendable {
    public var task: BASAdaptiveTraceKind
    public var preferredProviderID: String
    public var orderedProviderIDs: [String]
    public var compatibleProviderIDs: [String]
    public var incompatibleProviderIDs: [String]
    public var rationale: [String]

    public init(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        orderedProviderIDs: [String],
        compatibleProviderIDs: [String],
        incompatibleProviderIDs: [String],
        rationale: [String]
    ) {
        self.task = task
        self.preferredProviderID = preferredProviderID
        self.orderedProviderIDs = orderedProviderIDs
        self.compatibleProviderIDs = compatibleProviderIDs
        self.incompatibleProviderIDs = incompatibleProviderIDs
        self.rationale = rationale
    }
}

public struct BASProviderStatusRecord: Codable, Equatable, Sendable {
    public var providerID: String
    public var isAvailable: Bool
    public var title: String
    public var detail: String

    public init(
        providerID: String,
        isAvailable: Bool,
        title: String,
        detail: String
    ) {
        self.providerID = providerID
        self.isAvailable = isAvailable
        self.title = title
        self.detail = detail
    }
}

public struct BASProviderPreferenceOrdering: Codable, Equatable, Sendable {
    public var preferredProviderID: String
    public var orderedProviderIDs: [String]

    public init(
        preferredProviderID: String,
        orderedProviderIDs: [String]
    ) {
        self.preferredProviderID = preferredProviderID
        self.orderedProviderIDs = orderedProviderIDs
    }
}

public enum BASRuntimeAvailabilitySource: String, Codable, Equatable, Sendable {
    case runtimeDisabled
    case testingOverride
    case templatePinned
    case preferredProvider
    case fallbackProvider
    case deterministicFallback
}

public enum BASProviderOrderingResolver {
    public static func orderedProviderIDs(
        preferredProviderID: String,
        allowFallbacks: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        suspendedProviderIDs: Set<String> = []
    ) -> [String] {
        if preferredProviderID != deterministicProviderID,
           suspendedProviderIDs.contains(preferredProviderID),
           !allowFallbacks {
            return []
        }

        if !allowFallbacks {
            return suspendedProviderIDs.contains(preferredProviderID) ? [] : [preferredProviderID]
        }

        let baseOrdered = preferenceOrderings.first(where: {
            $0.preferredProviderID == preferredProviderID
        })?.orderedProviderIDs ?? [preferredProviderID]

        return baseOrdered.filter { !suspendedProviderIDs.contains($0) }
    }
}

public struct BASRuntimeAvailabilityPlan: Codable, Equatable, Sendable {
    public var preferredProviderID: String
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var source: BASRuntimeAvailabilitySource
    public var unavailableProviderID: String?

    public init(
        preferredProviderID: String,
        activeProviderID: String,
        fallbackProviderID: String?,
        source: BASRuntimeAvailabilitySource,
        unavailableProviderID: String? = nil
    ) {
        self.preferredProviderID = preferredProviderID
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.source = source
        self.unavailableProviderID = unavailableProviderID
    }
}

public enum BASProviderPlanner {
    public static func plan(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        baseOrderedProviderIDs: [String],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor]
    ) -> BASProviderSelectionPlan {
        let descriptorByID = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.providerID, $0) }
        )
        let baseIndexByID = Dictionary(
            uniqueKeysWithValues: baseOrderedProviderIDs.enumerated().map { ($0.element, $0.offset) }
        )

        let compatibleProviderIDs = strategy.map { strategy in
            baseOrderedProviderIDs.filter { providerID in
                isCompatible(
                    with: strategy,
                    descriptor: descriptorByID[providerID]
                )
            }
        } ?? baseOrderedProviderIDs

        let incompatibleProviderIDs = baseOrderedProviderIDs.filter { !compatibleProviderIDs.contains($0) }
        let orderedProviderIDs = compatibleProviderIDs.sorted { lhs, rhs in
            let lhsScore = routingScore(
                providerID: lhs,
                task: task,
                preferredProviderID: preferredProviderID,
                descriptor: descriptorByID[lhs],
                baseIndex: baseIndexByID[lhs] ?? 0,
                strategy: strategy
            )
            let rhsScore = routingScore(
                providerID: rhs,
                task: task,
                preferredProviderID: preferredProviderID,
                descriptor: descriptorByID[rhs],
                baseIndex: baseIndexByID[rhs] ?? 0,
                strategy: strategy
            )

            if lhsScore == rhsScore {
                return (baseIndexByID[lhs] ?? 0) < (baseIndexByID[rhs] ?? 0)
            }

            return lhsScore > rhsScore
        }

        var rationale: [String] = []
        if let strategy {
            rationale.append("Planning \(task.title) for runtime gear \(strategy.runtimeGear.rawValue) with \(strategy.responseLanguage.rawValue) output.")
        } else {
            rationale.append("Planning \(task.title) without an adaptive strategy override.")
        }
        if !incompatibleProviderIDs.isEmpty {
            rationale.append("Filtered incompatible providers: \(incompatibleProviderIDs.joined(separator: ", ")).")
        }
        if let selected = orderedProviderIDs.first, selected != preferredProviderID {
            rationale.append("Selected \(selected) ahead of the preferred provider because capability scoring outweighed preference bias.")
        }

        return BASProviderSelectionPlan(
            task: task,
            preferredProviderID: preferredProviderID,
            orderedProviderIDs: orderedProviderIDs,
            compatibleProviderIDs: compatibleProviderIDs,
            incompatibleProviderIDs: incompatibleProviderIDs,
            rationale: rationale
        )
    }

    private static func isCompatible(
        with strategy: BASAdaptiveTaskStrategy,
        descriptor: BASProviderDescriptor?
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
        providerID: String,
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        descriptor: BASProviderDescriptor?,
        baseIndex: Int,
        strategy: BASAdaptiveTaskStrategy?
    ) -> Int {
        let affinity = descriptor?.affinity(for: task) ?? 0
        let preferredBias = providerID == preferredProviderID ? 8 : 0
        let baseBias = max(0, 24 - (baseIndex * 12))
        let capabilityBias = strategy.map {
            capabilityScore(for: $0, descriptor: descriptor)
        } ?? 0
        return (affinity * 10) + preferredBias + baseBias + capabilityBias
    }

    private static func capabilityScore(
        for strategy: BASAdaptiveTaskStrategy,
        descriptor: BASProviderDescriptor?
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

public enum BASRuntimeAvailabilityResolver {
    public static func resolve(
        preferredProviderID: String,
        allowFallbacks: Bool,
        runtimeEnabled: Bool,
        deterministicProviderID: String,
        orderedProviderIDs: [String],
        statusesByID: [String: BASProviderStatusRecord],
        testingOverrideProviderID: String? = nil
    ) -> BASRuntimeAvailabilityPlan {
        guard runtimeEnabled else {
            return BASRuntimeAvailabilityPlan(
                preferredProviderID: preferredProviderID,
                activeProviderID: deterministicProviderID,
                fallbackProviderID: nil,
                source: .runtimeDisabled
            )
        }

        if let testingOverrideProviderID, preferredProviderID != deterministicProviderID {
            return BASRuntimeAvailabilityPlan(
                preferredProviderID: preferredProviderID,
                activeProviderID: testingOverrideProviderID,
                fallbackProviderID: testingOverrideProviderID,
                source: .testingOverride
            )
        }

        if preferredProviderID == deterministicProviderID {
            return BASRuntimeAvailabilityPlan(
                preferredProviderID: preferredProviderID,
                activeProviderID: deterministicProviderID,
                fallbackProviderID: nil,
                source: .templatePinned
            )
        }

        let orderedStatuses = orderedProviderIDs.compactMap { statusesByID[$0] }
        if let active = orderedStatuses.first(where: \.isAvailable) {
            let source: BASRuntimeAvailabilitySource = active.providerID == preferredProviderID
                ? .preferredProvider
                : .fallbackProvider

            return BASRuntimeAvailabilityPlan(
                preferredProviderID: preferredProviderID,
                activeProviderID: active.providerID,
                fallbackProviderID: active.providerID == preferredProviderID ? nil : active.providerID,
                source: source,
                unavailableProviderID: source == .fallbackProvider ? preferredProviderID : nil
            )
        }

        return BASRuntimeAvailabilityPlan(
            preferredProviderID: preferredProviderID,
            activeProviderID: deterministicProviderID,
            fallbackProviderID: deterministicProviderID,
            source: .deterministicFallback,
            unavailableProviderID: preferredProviderID
        )
    }
}

public enum BASRuntimeAvailabilityNarrator {
    public static func detail(
        plan: BASRuntimeAvailabilityPlan,
        allowFallbacks: Bool,
        statusesByID: [String: BASProviderStatusRecord],
        orderedProviderIDs: [String],
        testingOverrideTitle: String? = nil
    ) -> String {
        let preferredTitle = statusesByID[plan.preferredProviderID]?.title ?? plan.preferredProviderID
        let activeTitle = statusesByID[plan.activeProviderID]?.title ?? plan.activeProviderID

        switch plan.source {
        case .runtimeDisabled:
            return "On-device intelligence is off, so Before is using the deterministic decision system only."
        case .testingOverride:
            return "Testing stub profile '\(testingOverrideTitle ?? "Unknown")' is overriding live providers so the AI path can be verified without a model runtime."
        case .templatePinned:
            return "Deterministic local copy is pinned, so Before is not using a model provider for assistive refinement."
        case .preferredProvider:
            return statusesByID[plan.preferredProviderID].map { "\($0.title). \($0.detail)" }
                ?? "\(preferredTitle) is active."
        case .fallbackProvider:
            return statusesByID[plan.activeProviderID].map {
                "\(preferredTitle) is not available. Before is using \($0.title.lowercased()) instead."
            } ?? "\(preferredTitle) is not available. Before is using \(activeTitle.lowercased()) instead."
        case .deterministicFallback:
            if !allowFallbacks {
                return "\(preferredTitle) is not available. Automatic model fallback is off, so Before is using deterministic local copy instead."
            }

            let orderedStatuses = orderedProviderIDs.compactMap { statusesByID[$0] }
            let fallbackSource = orderedStatuses.first(where: {
                !$0.isAvailable && $0.providerID == plan.preferredProviderID
            }) ?? orderedStatuses.first

            return fallbackSource.map {
                "\(preferredTitle) is not available. \($0.detail) Before is falling back to deterministic local copy."
            } ?? "No assistive provider is available. Before is falling back to deterministic local copy."
        }
    }
}
