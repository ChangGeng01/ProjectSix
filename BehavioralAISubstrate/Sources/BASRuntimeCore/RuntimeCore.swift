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
