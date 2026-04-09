import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy

public enum BASAppleSurface: String, Codable, Sendable {
    case app
    case widget
    case watch
    case notification
    case shortcut
}

public struct BASAppleHandoffEnvelope: Codable, Sendable, Equatable {
    public var id: UUID
    public var surface: BASAppleSurface
    public var taskKind: BASTaskKind
    public var riskLevel: BASRiskLevel
    public var payloadSummary: String
    public var createdAt: Date

    public init(id: UUID = UUID(), surface: BASAppleSurface, taskKind: BASTaskKind, riskLevel: BASRiskLevel, payloadSummary: String, createdAt: Date = .now) {
        self.id = id
        self.surface = surface
        self.taskKind = taskKind
        self.riskLevel = riskLevel
        self.payloadSummary = payloadSummary
        self.createdAt = createdAt
    }
}

public struct BASAppleDeviceProfileSnapshot: Codable, Sendable, Equatable {
    public var modelName: String
    public var lowPowerMode: Bool
    public var batteryLevel: Double
    public var thermalState: String
    public var pairedWatchAvailable: Bool

    public init(modelName: String, lowPowerMode: Bool, batteryLevel: Double, thermalState: String, pairedWatchAvailable: Bool) {
        self.modelName = modelName
        self.lowPowerMode = lowPowerMode
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
        self.pairedWatchAvailable = pairedWatchAvailable
    }
}

public protocol BASAppleProtectedStateAdapter: Sendable {
    func save(data: Data, key: String) throws
    func load(key: String) throws -> Data?
    func remove(key: String) throws
}

public protocol BASAppleHandoffAdapter: Sendable {
    func handoff(_ envelope: BASAppleHandoffEnvelope) throws
}
