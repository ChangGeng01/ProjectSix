import Foundation

public enum BASRouteKind: String, Codable, Sendable {
    case local
    case cloud
    case hybrid
}

public enum BASRuntimeGear: String, Codable, Sendable {
    case low
    case balanced
    case high
}

public enum BASTaskKind: String, Codable, Sendable {
    case chat
    case plan
    case retrieve
    case tool
    case summarize
}

public enum BASPrivacyMode: String, Codable, Sendable {
    case localOnly
    case localFirst
    case cloudAllowed
}

public enum BASRiskLevel: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high

    public static func < (lhs: BASRiskLevel, rhs: BASRiskLevel) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    public var normalizedScore: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 1.0
        }
    }
}

public struct BASDeviceProfile: Codable, Sendable, Equatable {
    public var modelName: String
    public var memoryMB: Int
    public var batteryLevel: Double
    public var lowPowerMode: Bool
    public var thermalState: String

    public init(modelName: String, memoryMB: Int, batteryLevel: Double, lowPowerMode: Bool, thermalState: String) {
        self.modelName = modelName
        self.memoryMB = memoryMB
        self.batteryLevel = batteryLevel
        self.lowPowerMode = lowPowerMode
        self.thermalState = thermalState
    }
}

public struct BASExecutionBudget: Codable, Sendable, Equatable {
    public var contextTokens: Int
    public var outputTokens: Int
    public var retrievalItems: Int
    public var toolCalls: Int
    public var timeBudgetMs: Int

    public init(contextTokens: Int, outputTokens: Int, retrievalItems: Int, toolCalls: Int, timeBudgetMs: Int) {
        self.contextTokens = contextTokens
        self.outputTokens = outputTokens
        self.retrievalItems = retrievalItems
        self.toolCalls = toolCalls
        self.timeBudgetMs = timeBudgetMs
    }
}

public enum BASExecutionLaneKind: String, Codable, Sendable, CaseIterable {
    case deterministic
    case generative
    case retrievalAssisted
}

public struct BASExecutionLane: Codable, Sendable, Equatable {
    public var kind: BASExecutionLaneKind
    public var summary: String
    public var preferredRouteKinds: [BASRouteKind]
    public var requiresModelInvocation: Bool
    public var requiresRetrieval: Bool
    public var contextBudgetMultiplier: Double
    public var outputBudgetMultiplier: Double
    public var retrievalBudgetMultiplier: Double
    public var traceHeadline: String

    public init(
        kind: BASExecutionLaneKind,
        summary: String,
        preferredRouteKinds: [BASRouteKind],
        requiresModelInvocation: Bool,
        requiresRetrieval: Bool,
        contextBudgetMultiplier: Double,
        outputBudgetMultiplier: Double,
        retrievalBudgetMultiplier: Double,
        traceHeadline: String
    ) {
        self.kind = kind
        self.summary = summary
        self.preferredRouteKinds = preferredRouteKinds
        self.requiresModelInvocation = requiresModelInvocation
        self.requiresRetrieval = requiresRetrieval
        self.contextBudgetMultiplier = contextBudgetMultiplier
        self.outputBudgetMultiplier = outputBudgetMultiplier
        self.retrievalBudgetMultiplier = retrievalBudgetMultiplier
        self.traceHeadline = traceHeadline
    }

    public static func deterministic(
        preferredRouteKinds: [BASRouteKind] = [.local],
        summary: String = "Deterministic lane keeps the run template-first and model-light."
    ) -> BASExecutionLane {
        BASExecutionLane(
            kind: .deterministic,
            summary: summary,
            preferredRouteKinds: preferredRouteKinds,
            requiresModelInvocation: false,
            requiresRetrieval: false,
            contextBudgetMultiplier: 0.75,
            outputBudgetMultiplier: 0.7,
            retrievalBudgetMultiplier: 0,
            traceHeadline: "Deterministic lane stays inside stable contracts."
        )
    }

    public static func generative(
        preferredRouteKinds: [BASRouteKind] = [.local, .hybrid, .cloud],
        summary: String = "Generative lane spends model budget on synthesis."
    ) -> BASExecutionLane {
        BASExecutionLane(
            kind: .generative,
            summary: summary,
            preferredRouteKinds: preferredRouteKinds,
            requiresModelInvocation: true,
            requiresRetrieval: false,
            contextBudgetMultiplier: 1.0,
            outputBudgetMultiplier: 1.0,
            retrievalBudgetMultiplier: 0.4,
            traceHeadline: "Generative lane keeps synthesis as the primary work."
        )
    }

    public static func retrievalAssisted(
        preferredRouteKinds: [BASRouteKind] = [.local, .hybrid],
        summary: String = "Retrieval-assisted lane anchors generation in retrieved evidence."
    ) -> BASExecutionLane {
        BASExecutionLane(
            kind: .retrievalAssisted,
            summary: summary,
            preferredRouteKinds: preferredRouteKinds,
            requiresModelInvocation: true,
            requiresRetrieval: true,
            contextBudgetMultiplier: 1.1,
            outputBudgetMultiplier: 0.9,
            retrievalBudgetMultiplier: 1.4,
            traceHeadline: "Retrieval-assisted lane keeps evidence in front of synthesis."
        )
    }
}

public struct BASModelCapabilities: Codable, Sendable, Equatable {
    public var supportsGeneration: Bool
    public var supportsEmbeddings: Bool
    public var supportsTools: Bool
    public var supportsStructuredOutput: Bool
    public var supportsHybridRouting: Bool
    public var latencyClass: String

    public init(
        supportsGeneration: Bool,
        supportsEmbeddings: Bool,
        supportsTools: Bool,
        supportsStructuredOutput: Bool,
        supportsHybridRouting: Bool,
        latencyClass: String
    ) {
        self.supportsGeneration = supportsGeneration
        self.supportsEmbeddings = supportsEmbeddings
        self.supportsTools = supportsTools
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsHybridRouting = supportsHybridRouting
        self.latencyClass = latencyClass
    }
}

public struct BASModelDescriptor: Codable, Sendable, Equatable, Identifiable {
    public var id: String { modelID }
    public var modelID: String
    public var routeKind: BASRouteKind
    public var capabilities: BASModelCapabilities
    public var supportedTaskKinds: [BASTaskKind]
    public var relativeCostScore: Double
    public var maximumContextTokens: Int

    public init(
        modelID: String,
        routeKind: BASRouteKind,
        capabilities: BASModelCapabilities,
        supportedTaskKinds: [BASTaskKind],
        relativeCostScore: Double,
        maximumContextTokens: Int
    ) {
        self.modelID = modelID
        self.routeKind = routeKind
        self.capabilities = capabilities
        self.supportedTaskKinds = supportedTaskKinds
        self.relativeCostScore = relativeCostScore
        self.maximumContextTokens = maximumContextTokens
    }

    public func supports(taskKind: BASTaskKind) -> Bool {
        supportedTaskKinds.contains(taskKind)
    }
}

public struct BASFallbackStage: Codable, Sendable, Equatable {
    public var modelID: String
    public var routeKind: BASRouteKind
    public var timeoutMs: Int

    public init(modelID: String, routeKind: BASRouteKind, timeoutMs: Int) {
        self.modelID = modelID
        self.routeKind = routeKind
        self.timeoutMs = timeoutMs
    }
}

public struct BASFallbackGraph: Codable, Sendable, Equatable {
    public var primary: BASFallbackStage
    public var fallbacks: [BASFallbackStage]

    public init(primary: BASFallbackStage, fallbacks: [BASFallbackStage] = []) {
        self.primary = primary
        self.fallbacks = fallbacks
    }

    public var orderedStages: [BASFallbackStage] {
        [primary] + fallbacks
    }
}

public struct BASRouteAdvisory: Codable, Sendable, Equatable {
    public var route: BASModelRoute
    public var fallbackGraph: BASFallbackGraph
    public var executionLane: BASExecutionLane
    public var rationale: [String]

    public init(
        route: BASModelRoute,
        fallbackGraph: BASFallbackGraph,
        executionLane: BASExecutionLane = .deterministic(),
        rationale: [String]
    ) {
        self.route = route
        self.fallbackGraph = fallbackGraph
        self.executionLane = executionLane
        self.rationale = rationale
    }
}

public struct BASCapabilityRegistry: Codable, Sendable, Equatable {
    public var descriptors: [BASModelDescriptor]

    public init(descriptors: [BASModelDescriptor] = []) {
        self.descriptors = descriptors
    }

    public func descriptors(
        supporting taskKind: BASTaskKind,
        allowedRoutes: Set<BASRouteKind>? = nil
    ) -> [BASModelDescriptor] {
        descriptors.filter { descriptor in
            descriptor.supports(taskKind: taskKind) &&
            (allowedRoutes == nil || allowedRoutes?.contains(descriptor.routeKind) == true)
        }
    }
}

public struct BASRuntimeContext: Codable, Sendable, Equatable {
    public var taskKind: BASTaskKind
    public var gear: BASRuntimeGear
    public var deviceProfile: BASDeviceProfile
    public var privacyMode: BASPrivacyMode
    public var riskLevel: BASRiskLevel
    public var networkAvailable: Bool
    public var budget: BASExecutionBudget

    public init(
        taskKind: BASTaskKind,
        gear: BASRuntimeGear,
        deviceProfile: BASDeviceProfile,
        privacyMode: BASPrivacyMode,
        riskLevel: BASRiskLevel,
        networkAvailable: Bool,
        budget: BASExecutionBudget
    ) {
        self.taskKind = taskKind
        self.gear = gear
        self.deviceProfile = deviceProfile
        self.privacyMode = privacyMode
        self.riskLevel = riskLevel
        self.networkAvailable = networkAvailable
        self.budget = budget
    }
}

public struct BASModelRoute: Codable, Sendable, Equatable {
    public var routeKind: BASRouteKind
    public var preferredModelID: String
    public var fallbackModelIDs: [String]

    public init(routeKind: BASRouteKind, preferredModelID: String, fallbackModelIDs: [String] = []) {
        self.routeKind = routeKind
        self.preferredModelID = preferredModelID
        self.fallbackModelIDs = fallbackModelIDs
    }

    public static func local(_ modelID: String, fallbackModelIDs: [String] = []) -> BASModelRoute {
        BASModelRoute(routeKind: .local, preferredModelID: modelID, fallbackModelIDs: fallbackModelIDs)
    }

    public static func cloud(_ modelID: String, fallbackModelIDs: [String] = []) -> BASModelRoute {
        BASModelRoute(routeKind: .cloud, preferredModelID: modelID, fallbackModelIDs: fallbackModelIDs)
    }

    public static func hybrid(local modelID: String, fallbackModelIDs: [String] = []) -> BASModelRoute {
        BASModelRoute(routeKind: .hybrid, preferredModelID: modelID, fallbackModelIDs: fallbackModelIDs)
    }

    public var isLocalOnly: Bool { routeKind == .local }
}

public enum BASDefaultRoutingPlanner {
    public static func plan(
        context: BASRuntimeContext,
        registry: BASCapabilityRegistry
    ) -> BASRouteAdvisory {
        let allowedRoutes = allowedRoutes(for: context)
        let candidates = registry.descriptors(
            supporting: context.taskKind,
            allowedRoutes: allowedRoutes
        )
        .sorted { lhs, rhs in
            let lhsScore = score(lhs, in: context)
            let rhsScore = score(rhs, in: context)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.modelID < rhs.modelID
        }

        guard let primary = candidates.first else {
            let placeholder = BASFallbackStage(modelID: "unavailable", routeKind: .local, timeoutMs: timeoutMs(for: context, routeKind: .local))
            return BASRouteAdvisory(
                route: .local("unavailable"),
                fallbackGraph: BASFallbackGraph(primary: placeholder),
                executionLane: .deterministic(
                    preferredRouteKinds: [.local],
                    summary: "No matching model descriptor was available, so the deterministic lane is used."
                ),
                rationale: ["No matching model descriptor was available for this runtime context."]
            )
        }

        let fallbackStages = candidates.dropFirst().map {
            BASFallbackStage(
                modelID: $0.modelID,
                routeKind: $0.routeKind,
                timeoutMs: timeoutMs(for: context, routeKind: $0.routeKind)
            )
        }

        let route = BASModelRoute(
            routeKind: primary.routeKind,
            preferredModelID: primary.modelID,
            fallbackModelIDs: fallbackStages.map(\.modelID)
        )
        let executionLane = BASExecutionLanePlanner.classify(
            context: context,
            route: route,
            capabilities: primary.capabilities
        )

        var rationale: [String] = []
        switch context.privacyMode {
        case .localOnly:
            rationale.append("Privacy mode requires a fully local route.")
        case .localFirst:
            rationale.append("Local-first mode prefers on-device execution until budgets are exceeded.")
        case .cloudAllowed:
            rationale.append("Cloud-capable execution is allowed for this host policy.")
        }

        if context.deviceProfile.lowPowerMode {
            rationale.append("Low power mode prefers lower-latency descriptors.")
        }
        if context.deviceProfile.thermalState.lowercased().contains("serious") ||
            context.deviceProfile.thermalState.lowercased().contains("critical") {
            rationale.append("Thermal pressure downgraded the route toward cooler execution.")
        }
        if !context.networkAvailable {
            rationale.append("Network is unavailable, so remote-only routes are excluded.")
        }
        if context.riskLevel == .high {
            rationale.append("High risk keeps routing conservative and structured.")
        }
        rationale.append(executionLane.traceHeadline)

        return BASRouteAdvisory(
            route: route,
            fallbackGraph: BASFallbackGraph(
                primary: BASFallbackStage(
                    modelID: primary.modelID,
                    routeKind: primary.routeKind,
                    timeoutMs: timeoutMs(for: context, routeKind: primary.routeKind)
                ),
                fallbacks: fallbackStages
            ),
            executionLane: executionLane,
            rationale: rationale
        )
    }

    private static func allowedRoutes(for context: BASRuntimeContext) -> Set<BASRouteKind> {
        switch context.privacyMode {
        case .localOnly:
            return [.local]
        case .localFirst:
            if context.networkAvailable && !context.deviceProfile.lowPowerMode {
                return [.local, .hybrid, .cloud]
            }
            return [.local, .hybrid]
        case .cloudAllowed:
            if context.networkAvailable {
                return [.local, .hybrid, .cloud]
            }
            return [.local, .hybrid]
        }
    }

    private static func score(_ descriptor: BASModelDescriptor, in context: BASRuntimeContext) -> Double {
        var total = 0.0

        switch descriptor.routeKind {
        case .local:
            total += 4.0
        case .hybrid:
            total += context.networkAvailable ? 2.5 : -4.0
        case .cloud:
            total += context.networkAvailable ? 1.0 : -8.0
        }

        switch context.gear {
        case .low:
            if descriptor.capabilities.latencyClass == "fast" || descriptor.capabilities.latencyClass == "ultra" {
                total += 2.0
            } else {
                total -= 1.0
            }
        case .balanced:
            total += descriptor.capabilities.supportsStructuredOutput ? 1.0 : 0.0
        case .high:
            if descriptor.capabilities.supportsHybridRouting {
                total += 1.0
            }
            if descriptor.capabilities.latencyClass == "slow" {
                total += 0.5
            }
        }

        if context.deviceProfile.lowPowerMode {
            total -= descriptor.relativeCostScore * 1.5
        } else {
            total -= descriptor.relativeCostScore * 0.5
        }

        if descriptor.maximumContextTokens < context.budget.contextTokens {
            total -= 6.0
        }

        if context.riskLevel == .high && !descriptor.capabilities.supportsStructuredOutput {
            total -= 4.0
        }

        if context.taskKind == .tool && !descriptor.capabilities.supportsTools {
            total -= 5.0
        }

        if descriptor.capabilities.supportsGeneration {
            total += 0.5
        }

        return total
    }

    private static func timeoutMs(for context: BASRuntimeContext, routeKind: BASRouteKind) -> Int {
        switch routeKind {
        case .local:
            return max(400, context.budget.timeBudgetMs / 2)
        case .hybrid:
            return max(600, Int(Double(context.budget.timeBudgetMs) * 0.65))
        case .cloud:
            return max(800, Int(Double(context.budget.timeBudgetMs) * 0.8))
        }
    }
}

public enum BASExecutionLanePlanner {
    public static func classify(
        context: BASRuntimeContext,
        route: BASModelRoute,
        capabilities: BASModelCapabilities? = nil
    ) -> BASExecutionLane {
        let supportsGeneration = capabilities?.supportsGeneration ?? true
        let supportsEmbeddings = capabilities?.supportsEmbeddings ?? false

        if context.taskKind == .retrieve ||
            context.budget.retrievalItems > 0 ||
            (supportsEmbeddings && context.taskKind == .plan) {
            return BASExecutionLane.retrievalAssisted(
                preferredRouteKinds: route.routeKind == .cloud ? [.local, .hybrid, .cloud] : [.local, .hybrid]
            )
        }

        if !supportsGeneration ||
            context.taskKind == .summarize ||
            context.budget.outputTokens <= 180 ||
            route.isLocalOnly && context.privacyMode == .localOnly {
            return BASExecutionLane.deterministic(
                preferredRouteKinds: route.isLocalOnly ? [.local] : [route.routeKind],
                summary: route.isLocalOnly
                    ? "Deterministic lane keeps the run local and tightly bounded."
                    : "Deterministic lane keeps the run structured even on a mixed route."
            )
        }

        return BASExecutionLane.generative(
            preferredRouteKinds: route.routeKind == .local ? [.local, .hybrid] : [route.routeKind, .local],
            summary: route.routeKind == .cloud
                ? "Generative lane can spend remote budget on synthesis."
                : "Generative lane can spend local budget on synthesis."
        )
    }

    public static func classify(
        traceKind: BASAdaptiveTraceKind,
        runtimeGear: BASRuntimeGear,
        retrievalMode: BASRetrievalMode,
        outputMode: BASOutputMode,
        allowsModelInvocation: Bool
    ) -> BASExecutionLane {
        if !allowsModelInvocation {
            return BASExecutionLane.deterministic(
                preferredRouteKinds: [.local],
                summary: "Deterministic lane runs without model invocation."
            )
        }

        if retrievalMode != .off {
            return BASExecutionLane.retrievalAssisted(
                preferredRouteKinds: [.local, .hybrid],
                summary: "\(traceKind.title) is anchored by retrieval before synthesis."
            )
        }

        if outputMode == .deterministicTemplate || outputMode == .jsonShort || traceKind == .primary {
            return BASExecutionLane.deterministic(
                preferredRouteKinds: [.local],
                summary: "\(traceKind.title) is best served by a deterministic lane."
            )
        }

        return BASExecutionLane.generative(
            preferredRouteKinds: runtimeGear == .high ? [.local, .hybrid, .cloud] : [.local, .hybrid],
            summary: "\(traceKind.title) can spend a generative lane on synthesis."
        )
    }
}

public protocol BASModelProvider: Sendable {
    var modelID: String { get }
    func capabilities() -> BASModelCapabilities
}

public protocol BASEmbeddingProvider: Sendable {
    var embeddingModelID: String { get }
    func capabilities() -> BASModelCapabilities
}

public protocol BASToolExecutor: Sendable {
    func canExecute(toolName: String, in context: BASRuntimeContext) -> Bool
}

public protocol BASRoutingPolicy: Sendable {
    func selectRoute(for context: BASRuntimeContext, availableModels: [BASModelCapabilities]) -> BASModelRoute
}
