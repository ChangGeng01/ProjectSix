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
    public var modelID: String
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
        modelID: String = "",
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
        self.modelID = modelID
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

    public static func generic(
        modelID: String,
        bestFor: [BASAdaptiveTraceKind] = []
    ) -> BASProviderCapabilityProfile {
        BASProviderCapabilityProfile(
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

public enum BASProviderTrack: String, Codable, Equatable, Sendable {
    case builtInOpenModel
    case builtInSystem
    case testingOnly
    case deterministic
}

public struct BASOpenModelDescriptor: Codable, Equatable, Sendable {
    public var stableID: String
    public var family: String
    public var version: String
    public var title: String
    public var detail: String
    public var taskAffinities: [BASAdaptiveTraceKind: Int]
    public var capabilityProfile: BASProviderCapabilityProfile

    public init(
        stableID: String,
        family: String,
        version: String,
        title: String,
        detail: String,
        taskAffinities: [BASAdaptiveTraceKind: Int],
        capabilityProfile: BASProviderCapabilityProfile? = nil
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

public struct BASProviderDescriptor: Codable, Equatable, Sendable, Identifiable {
    public var id: String { providerID }
    public var providerID: String
    public var title: String
    public var detail: String
    public var track: BASProviderTrack
    public var openModel: BASOpenModelDescriptor?
    public var taskAffinities: [BASAdaptiveTraceKind: Int]
    public var capabilityProfile: BASProviderCapabilityProfile

    public init(
        providerID: String,
        title: String? = nil,
        detail: String? = nil,
        track: BASProviderTrack = .testingOnly,
        openModel: BASOpenModelDescriptor? = nil,
        taskAffinities: [BASAdaptiveTraceKind: Int],
        capabilityProfile: BASProviderCapabilityProfile
    ) {
        self.providerID = providerID
        self.title = title ?? openModel?.title ?? providerID
        self.detail = detail ?? openModel?.detail ?? ""
        self.track = track
        self.openModel = openModel
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
    public var appliedRoutingPolicyVersion: String?
    public var appliedRoutingRegistryVersion: String?
    public var rationale: [String]

    public init(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        orderedProviderIDs: [String],
        compatibleProviderIDs: [String],
        incompatibleProviderIDs: [String],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        rationale: [String]
    ) {
        self.task = task
        self.preferredProviderID = preferredProviderID
        self.orderedProviderIDs = orderedProviderIDs
        self.compatibleProviderIDs = compatibleProviderIDs
        self.incompatibleProviderIDs = incompatibleProviderIDs
        self.appliedRoutingPolicyVersion = appliedRoutingPolicyVersion
        self.appliedRoutingRegistryVersion = appliedRoutingRegistryVersion
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

public struct BASProviderRoutingPolicy: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var deterministicProviderID: String
    public var testingOverrideProviderID: String?
    public var preferenceOrderings: [BASProviderPreferenceOrdering]

    public init(
        schemaVersion: String,
        deterministicProviderID: String,
        testingOverrideProviderID: String? = nil,
        preferenceOrderings: [BASProviderPreferenceOrdering]
    ) {
        self.schemaVersion = schemaVersion
        self.deterministicProviderID = deterministicProviderID
        self.testingOverrideProviderID = testingOverrideProviderID
        self.preferenceOrderings = preferenceOrderings
    }

    public static let missing = BASProviderRoutingPolicy(
        schemaVersion: "provider-routing.missing.v1",
        deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
        preferenceOrderings: []
    )
}

public struct BASProviderRoutingPolicyRegistry: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var defaultPolicyID: String
    public var policiesByID: [String: BASProviderRoutingPolicy]

    public init(
        schemaVersion: String,
        defaultPolicyID: String,
        policiesByID: [String: BASProviderRoutingPolicy]
    ) {
        self.schemaVersion = schemaVersion
        self.defaultPolicyID = defaultPolicyID
        self.policiesByID = policiesByID
    }

    public func policyOrMissing(for policyID: String? = nil) -> BASProviderRoutingPolicy {
        if let policy = policyIfAvailable(for: policyID) {
            return policy
        }

        return .missing
    }

    @available(*, unavailable, renamed: "policyOrMissing(for:)", message: "Use policyIfAvailable(for:) for production code or policyOrMissing(for:) when an explicit missing sentinel is truly intended.")
    public func policy(for policyID: String? = nil) -> BASProviderRoutingPolicy {
        policyOrMissing(for: policyID)
    }

    public func policyIfAvailable(for policyID: String? = nil) -> BASProviderRoutingPolicy? {
        if let policyID {
            return policiesByID[policyID]
        }

        return policiesByID[defaultPolicyID]
    }
}

public struct BASProviderRoutingPolicySource: Codable, Equatable, Sendable {
    public var registry: BASProviderRoutingPolicyRegistry
    public var policyID: String?

    public init(
        registry: BASProviderRoutingPolicyRegistry,
        policyID: String? = nil
    ) {
        self.registry = registry
        self.policyID = policyID
    }

    public var registryVersion: String {
        registry.schemaVersion
    }

    public var resolvedPolicyOrMissing: BASProviderRoutingPolicy {
        registry.policyOrMissing(for: policyID)
    }

    public var resolvedPolicyIfAvailable: BASProviderRoutingPolicy? {
        registry.policyIfAvailable(for: policyID)
    }

    @available(*, unavailable, renamed: "resolvedPolicyOrMissing", message: "Use resolvedPolicyIfAvailable for production code or resolvedPolicyOrMissing when an explicit missing sentinel is truly intended.")
    public var resolvedPolicy: BASProviderRoutingPolicy {
        resolvedPolicyOrMissing
    }
}

public enum BASReferenceProviderRuntime {
    public static let gemmaE4BProviderID = "gemmaE4B"
    public static let openModelProviderID = "openModel"
    public static let foundationModelsProviderID = "foundationModels"
    public static let testingStubProviderID = "testingStub"
    public static let templateProviderID = "template"

    public static let fixtureRoutingPolicyID = "reference-provider-policy.v1"
    public static let fixtureRoutingRegistry = BASProviderRoutingPolicyRegistry(
        schemaVersion: "reference-provider-registry.v1",
        defaultPolicyID: fixtureRoutingPolicyID,
        policiesByID: [
            fixtureRoutingPolicyID: BASProviderRoutingPolicy(
                schemaVersion: fixtureRoutingPolicyID,
                deterministicProviderID: templateProviderID,
                testingOverrideProviderID: testingStubProviderID,
                preferenceOrderings: [
                    BASProviderPreferenceOrdering(
                        preferredProviderID: gemmaE4BProviderID,
                        orderedProviderIDs: [
                            gemmaE4BProviderID,
                            foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: openModelProviderID,
                        orderedProviderIDs: [
                            openModelProviderID,
                            gemmaE4BProviderID,
                            foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: foundationModelsProviderID,
                        orderedProviderIDs: [
                            foundationModelsProviderID,
                            gemmaE4BProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: templateProviderID,
                        orderedProviderIDs: [
                            templateProviderID
                        ]
                    )
                ]
            )
        ]
    )

    public static var fixtureRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingRegistry.policyOrMissing()
    }

    public static var fixtureRoutingSource: BASProviderRoutingPolicySource {
        BASProviderRoutingPolicySource(
            registry: fixtureRoutingRegistry,
            policyID: fixtureRoutingPolicyID
        )
    }

    public static func resolvedRoutingPolicyIfAvailable(
        policyID: String? = nil,
        registry: BASProviderRoutingPolicyRegistry
    ) -> BASProviderRoutingPolicy? {
        registry.policyIfAvailable(for: policyID)
    }

    public static func resolvedRoutingPolicyOrMissing(
        policyID: String? = nil,
        registry: BASProviderRoutingPolicyRegistry
    ) -> BASProviderRoutingPolicy {
        registry.policyOrMissing(for: policyID)
    }

    @available(*, unavailable, renamed: "resolvedRoutingPolicyOrMissing(policyID:registry:)", message: "Use resolvedRoutingPolicyIfAvailable(policyID:registry:) for production code or resolvedRoutingPolicyOrMissing(policyID:registry:) when an explicit missing sentinel is truly intended.")
    public static func resolvedRoutingPolicy(
        policyID: String? = nil,
        registry: BASProviderRoutingPolicyRegistry
    ) -> BASProviderRoutingPolicy {
        resolvedRoutingPolicyOrMissing(policyID: policyID, registry: registry)
    }

    public static func resolvedRoutingSource(
        policyID: String? = nil,
        registry: BASProviderRoutingPolicyRegistry
    ) -> BASProviderRoutingPolicySource {
        BASProviderRoutingPolicySource(
            registry: registry,
            policyID: policyID
        )
    }

    public static var fixturePreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixtureRoutingPolicy.preferenceOrderings
    }

    public static func registryUsesFixtureCatalog(
        _ registry: BASProviderRoutingPolicyRegistry,
        policyID: String? = nil
    ) -> Bool {
        if registry.schemaVersion == fixtureRoutingRegistry.schemaVersion ||
            registry.defaultPolicyID == fixtureRoutingPolicyID ||
            policyID == fixtureRoutingPolicyID {
            return true
        }

        return registry.policyIfAvailable(for: policyID) == fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingPolicyID", message: "Use fixtureRoutingPolicyID only for package fixtures; production code should inject a routing registry.")
    public static let referenceRoutingPolicyID = fixtureRoutingPolicyID

    @available(*, unavailable, renamed: "fixtureRoutingRegistry", message: "Use fixtureRoutingRegistry only for package fixtures; production code should inject a routing registry.")
    public static let referenceRoutingRegistry = fixtureRoutingRegistry

    @available(*, unavailable, renamed: "fixtureRoutingPolicy", message: "Use fixtureRoutingPolicy only for package fixtures; production code should inject a routing policy source.")
    public static var referenceRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingSource", message: "Use fixtureRoutingSource only for package fixtures; production code should inject a routing policy source.")
    public static var referenceRoutingSource: BASProviderRoutingPolicySource {
        fixtureRoutingSource
    }

    @available(*, unavailable, renamed: "fixturePreferenceOrderings", message: "Use fixturePreferenceOrderings only for package fixtures; production code should inject a routing policy source.")
    public static var referencePreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixturePreferenceOrderings
    }

    @available(*, unavailable, renamed: "fixtureRoutingPolicyID", message: "Use fixtureRoutingPolicyID only for package fixtures; production code should inject a routing registry.")
    public static let fallbackRoutingPolicyID = fixtureRoutingPolicyID

    @available(*, unavailable, renamed: "fixtureRoutingRegistry", message: "Use fixtureRoutingRegistry only for package fixtures; production code should inject a routing registry.")
    public static let fallbackRoutingRegistry = fixtureRoutingRegistry

    @available(*, unavailable, renamed: "fixtureRoutingPolicy", message: "Use fixtureRoutingPolicy only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingSource", message: "Use fixtureRoutingSource only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackRoutingSource: BASProviderRoutingPolicySource {
        fixtureRoutingSource
    }

    @available(*, unavailable, renamed: "fixturePreferenceOrderings", message: "Use fixturePreferenceOrderings only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackPreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixturePreferenceOrderings
    }

    public static func orderedProviderIDs(
        preferredProviderID: String,
        allowFallbacks: Bool = true,
        suspendedProviderIDs: Set<String> = [],
        routingPolicy: BASProviderRoutingPolicy
    ) -> [String] {
        BASProviderOrderingResolver.orderedProviderIDs(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: routingPolicy.deterministicProviderID,
            preferenceOrderings: routingPolicy.preferenceOrderings,
            suspendedProviderIDs: suspendedProviderIDs
        )
    }

    public static func runtimeStatusSummary(
        preferredProviderID: String,
        allowFallbacks: Bool,
        runtimeEnabled: Bool,
        statusesByID: [String: BASProviderStatusRecord],
        suspendedProviderIDs: Set<String> = [],
        testingOverrideEnabled: Bool = false,
        testingOverrideTitle: String? = nil,
        routingRegistryVersion: String? = nil,
        routingPolicy: BASProviderRoutingPolicy
    ) -> BASRuntimeStatusSummary {
        BASRuntimeStatusResolver.resolve(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            runtimeEnabled: runtimeEnabled,
            deterministicProviderID: routingPolicy.deterministicProviderID,
            preferenceOrderings: routingPolicy.preferenceOrderings,
            appliedRoutingPolicyVersion: routingPolicy.schemaVersion,
            appliedRoutingRegistryVersion: routingRegistryVersion,
            statusesByID: statusesByID,
            suspendedProviderIDs: suspendedProviderIDs,
            testingOverrideProviderID: testingOverrideEnabled
                ? (routingPolicy.testingOverrideProviderID ?? testingStubProviderID)
                : nil,
            testingOverrideTitle: testingOverrideTitle
        )
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
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor]
    ) -> BASProviderSelectionPlan {
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        let descriptorByID = Dictionary(
            descriptors.map { ($0.providerID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        let baseIndexByID = Dictionary(
            baseOrderedProviderIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
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
        if let appliedRoutingPolicyVersion {
            if let appliedRoutingRegistryVersion {
                rationale.append("Applied routing policy \(appliedRoutingPolicyVersion) from registry \(appliedRoutingRegistryVersion).")
            } else {
                rationale.append("Applied routing policy \(appliedRoutingPolicyVersion).")
            }
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
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
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

public enum BASProviderRouteResolver {
    public static func resolve(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        allowFallbacks: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        suspendedProviderIDs: Set<String> = [],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor]
    ) -> BASProviderSelectionPlan {
        let baseOrderedProviderIDs = BASProviderOrderingResolver.orderedProviderIDs(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: deterministicProviderID,
            preferenceOrderings: preferenceOrderings,
            suspendedProviderIDs: suspendedProviderIDs
        )

        guard allowFallbacks, baseOrderedProviderIDs.count > 1 else {
            let rationale: [String]
            if !allowFallbacks {
                rationale = ["Fallbacks disabled, so runtime stays pinned to the preferred provider lane."]
            } else {
                rationale = ["Only one provider remains after base ordering, so no task-aware reordering was applied."]
            }

            return BASProviderSelectionPlan(
                task: task,
                preferredProviderID: preferredProviderID,
                orderedProviderIDs: baseOrderedProviderIDs,
                compatibleProviderIDs: baseOrderedProviderIDs,
                incompatibleProviderIDs: [],
                appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
                appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
                rationale: rationale
            )
        }

        return BASProviderPlanner.plan(
            task: task,
            preferredProviderID: preferredProviderID,
            baseOrderedProviderIDs: baseOrderedProviderIDs,
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
            strategy: strategy,
            descriptors: descriptors
        )
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
            return "On-device intelligence is off, so the host runtime is using the deterministic decision system only."
        case .testingOverride:
            return "Testing stub profile '\(testingOverrideTitle ?? "Unknown")' is overriding live providers so the assistive path can be verified without a model runtime."
        case .templatePinned:
            return "Deterministic local copy is pinned, so the host runtime is not using a model provider for assistive refinement."
        case .preferredProvider:
            return statusesByID[plan.preferredProviderID].map { "\($0.title). \($0.detail)" }
                ?? "\(preferredTitle) is active."
        case .fallbackProvider:
            return statusesByID[plan.activeProviderID].map {
                "\(preferredTitle) is not available. The host runtime is using \($0.title.lowercased()) instead."
            } ?? "\(preferredTitle) is not available. The host runtime is using \(activeTitle.lowercased()) instead."
        case .deterministicFallback:
            if !allowFallbacks {
                return "\(preferredTitle) is not available. Automatic model fallback is off, so the host runtime is using deterministic local copy instead."
            }

            let orderedStatuses = orderedProviderIDs.compactMap { statusesByID[$0] }
            let fallbackSource = orderedStatuses.first(where: {
                !$0.isAvailable && $0.providerID == plan.preferredProviderID
            }) ?? orderedStatuses.first

            return fallbackSource.map {
                "\(preferredTitle) is not available. \($0.detail) The host runtime is falling back to deterministic local copy."
            } ?? "No assistive provider is available. The host runtime is falling back to deterministic local copy."
        }
    }
}

public enum BASProviderTraceNarrator {
    public static func detail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        let base: String
        if activeTitle == preferredTitle {
            base = allowFallbacks
                ? "The host runtime used the preferred provider without needing a fallback."
                : "The host runtime used the pinned provider with fallback disabled."
        } else {
            base = "The host runtime switched away from \(preferredTitle) and used \(activeTitle) for this refinement."
        }

        guard let activeResolutionDetail, !activeResolutionDetail.isEmpty else {
            return base
        }

        return "\(base) \(activeResolutionDetail)"
    }

    public static func cachedDetail(base: String) -> String {
        base + " The host runtime served the response from the structured prompt cache instead of recomputing it."
    }

    public static func deterministicFallbackDetail(
        base: String,
        suspendedProviderTitles: [String]
    ) -> String {
        guard !suspendedProviderTitles.isEmpty else { return base }
        return "\(base) Active runtime cooldown: \(suspendedProviderTitles.joined(separator: ", "))."
    }
}

public struct BASRuntimeStatusSummary: Codable, Equatable, Sendable {
    public var preferredProviderID: String
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var appliedRoutingPolicyVersion: String?
    public var appliedRoutingRegistryVersion: String?
    public var detail: String
    public var orderedProviderIDs: [String]

    public init(
        preferredProviderID: String,
        activeProviderID: String,
        fallbackProviderID: String?,
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        detail: String,
        orderedProviderIDs: [String]
    ) {
        self.preferredProviderID = preferredProviderID
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.appliedRoutingPolicyVersion = appliedRoutingPolicyVersion
        self.appliedRoutingRegistryVersion = appliedRoutingRegistryVersion
        self.detail = detail
        self.orderedProviderIDs = orderedProviderIDs
    }
}

public enum BASRuntimeStatusResolver {
    public static func resolve(
        preferredProviderID: String,
        allowFallbacks: Bool,
        runtimeEnabled: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        statusesByID: [String: BASProviderStatusRecord],
        suspendedProviderIDs: Set<String> = [],
        testingOverrideProviderID: String? = nil,
        testingOverrideTitle: String? = nil
    ) -> BASRuntimeStatusSummary {
        let orderedProviderIDs = BASProviderOrderingResolver.orderedProviderIDs(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: deterministicProviderID,
            preferenceOrderings: preferenceOrderings,
            suspendedProviderIDs: suspendedProviderIDs
        )
        let plan = BASRuntimeAvailabilityResolver.resolve(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            runtimeEnabled: runtimeEnabled,
            deterministicProviderID: deterministicProviderID,
            orderedProviderIDs: orderedProviderIDs,
            statusesByID: statusesByID,
            testingOverrideProviderID: testingOverrideProviderID
        )
        let detail = BASRuntimeAvailabilityNarrator.detail(
            plan: plan,
            allowFallbacks: allowFallbacks,
            statusesByID: statusesByID,
            orderedProviderIDs: orderedProviderIDs,
            testingOverrideTitle: testingOverrideTitle
        )

        return BASRuntimeStatusSummary(
            preferredProviderID: preferredProviderID,
            activeProviderID: plan.activeProviderID,
            fallbackProviderID: plan.fallbackProviderID,
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
            detail: detail,
            orderedProviderIDs: orderedProviderIDs
        )
    }
}
