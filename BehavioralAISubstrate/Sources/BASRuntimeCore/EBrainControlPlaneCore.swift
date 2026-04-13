import Foundation

public protocol BASSchemaVersioned: Codable, Equatable, Sendable {
    static var currentSchemaVersion: String { get }
    var schemaVersion: String { get }
}

public enum BASThermalLevel: String, Codable, CaseIterable, Sendable {
    case nominal
    case warm
    case hot
    case critical
}

public enum BASNetworkState: String, Codable, CaseIterable, Sendable {
    case offline
    case constrained
    case online
}

public enum BASForegroundState: String, Codable, CaseIterable, Sendable {
    case foreground
    case background
    case suspended
}

public enum BASEBrainRunMode: String, Codable, CaseIterable, Sendable {
    case dormant
    case sentinel
    case engage
    case deepLoop
    case guarded = "guard"
}

public enum BASPrecisionProfile: String, Codable, CaseIterable, Sendable {
    case minimal
    case balanced
    case protected
    case full
}

public enum BASDeviceRoute: String, Codable, CaseIterable, Sendable {
    case scoutCPU
    case scoutGPU
    case scoutNPU
    case coreGPU
    case coreNPU
    case hybridLocal
}

public enum BASThermalGuardLevel: String, Codable, CaseIterable, Sendable {
    case nominal
    case watch
    case throttle
    case emergency
}

public struct BASDeviceState: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var batteryLevel: Double
    public var thermalLevel: BASThermalLevel
    public var memoryFreeMB: Int
    public var networkState: BASNetworkState
    public var foregroundState: BASForegroundState
    public var cpuLoad: Double
    public var gpuLoad: Double
    public var npuAvailable: Bool
    public var latencyBudgetMs: Int

    public init(
        schemaVersion: String = BASDeviceState.currentSchemaVersion,
        batteryLevel: Double,
        thermalLevel: BASThermalLevel,
        memoryFreeMB: Int,
        networkState: BASNetworkState,
        foregroundState: BASForegroundState,
        cpuLoad: Double,
        gpuLoad: Double,
        npuAvailable: Bool,
        latencyBudgetMs: Int
    ) {
        self.schemaVersion = schemaVersion
        self.batteryLevel = batteryLevel
        self.thermalLevel = thermalLevel
        self.memoryFreeMB = memoryFreeMB
        self.networkState = networkState
        self.foregroundState = foregroundState
        self.cpuLoad = cpuLoad
        self.gpuLoad = gpuLoad
        self.npuAvailable = npuAvailable
        self.latencyBudgetMs = latencyBudgetMs
    }
}

public extension BASDeviceState {
    init(
        profile: BASDeviceProfile,
        memoryFreeMB: Int,
        networkState: BASNetworkState = .constrained,
        foregroundState: BASForegroundState = .foreground,
        cpuLoad: Double = 0,
        gpuLoad: Double = 0,
        npuAvailable: Bool = true,
        latencyBudgetMs: Int = 1_500
    ) {
        let thermalLevel: BASThermalLevel
        switch profile.thermalState.lowercased() {
        case let value where value.contains("critical"):
            thermalLevel = .critical
        case let value where value.contains("serious") || value.contains("hot"):
            thermalLevel = .hot
        case let value where value.contains("fair") || value.contains("warm"):
            thermalLevel = .warm
        default:
            thermalLevel = .nominal
        }

        self.init(
            batteryLevel: profile.batteryLevel,
            thermalLevel: thermalLevel,
            memoryFreeMB: memoryFreeMB,
            networkState: networkState,
            foregroundState: foregroundState,
            cpuLoad: cpuLoad,
            gpuLoad: gpuLoad,
            npuAvailable: npuAvailable,
            latencyBudgetMs: latencyBudgetMs
        )
    }
}

public struct BASBudgetFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var runMode: BASEBrainRunMode
    public var maxLoops: Int
    public var maxCandidates: Int
    public var maxDecodeTokens: Int
    public var retrievalDepth: Int
    public var precisionProfile: BASPrecisionProfile
    public var deviceRoute: BASDeviceRoute
    public var thermalGuardLevel: BASThermalGuardLevel
    public var maintenanceAllowed: Bool

    public init(
        schemaVersion: String = BASBudgetFrame.currentSchemaVersion,
        runMode: BASEBrainRunMode,
        maxLoops: Int,
        maxCandidates: Int,
        maxDecodeTokens: Int,
        retrievalDepth: Int,
        precisionProfile: BASPrecisionProfile,
        deviceRoute: BASDeviceRoute,
        thermalGuardLevel: BASThermalGuardLevel,
        maintenanceAllowed: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.runMode = runMode
        self.maxLoops = max(0, maxLoops)
        self.maxCandidates = max(1, maxCandidates)
        self.maxDecodeTokens = max(0, maxDecodeTokens)
        self.retrievalDepth = max(0, retrievalDepth)
        self.precisionProfile = precisionProfile
        self.deviceRoute = deviceRoute
        self.thermalGuardLevel = thermalGuardLevel
        self.maintenanceAllowed = maintenanceAllowed
    }
}

public extension BASBudgetFrame {
    static func guardedLocal(
        maxLoops: Int = 1,
        maxCandidates: Int = 2,
        maxDecodeTokens: Int = 192,
        retrievalDepth: Int = 2
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guarded,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: maxDecodeTokens,
            retrievalDepth: retrievalDepth,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false
        )
    }
}
