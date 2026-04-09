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

    public var metadata: BASAppleHandoffMetadata {
        BASAppleHandoffMetadata(
            surface: surface,
            taskKind: taskKind,
            riskLevel: riskLevel,
            payloadDigest: String(payloadSummary.prefix(120)),
            requiresResume: taskKind == .plan || riskLevel >= .medium
        )
    }
}

public struct BASAppleHandoffMetadata: Codable, Sendable, Equatable {
    public var surface: BASAppleSurface
    public var taskKind: BASTaskKind
    public var riskLevel: BASRiskLevel
    public var payloadDigest: String
    public var requiresResume: Bool

    public init(
        surface: BASAppleSurface,
        taskKind: BASTaskKind,
        riskLevel: BASRiskLevel,
        payloadDigest: String,
        requiresResume: Bool
    ) {
        self.surface = surface
        self.taskKind = taskKind
        self.riskLevel = riskLevel
        self.payloadDigest = payloadDigest
        self.requiresResume = requiresResume
    }
}

public struct BASAppleHandoffSummary: Codable, Sendable, Equatable {
    public var envelopeID: UUID
    public var surface: BASAppleSurface
    public var taskKind: BASTaskKind
    public var riskLevel: BASRiskLevel
    public var routeKind: BASRouteKind?
    public var headline: String
    public var detail: String
    public var requiresResume: Bool

    public init(
        envelopeID: UUID,
        surface: BASAppleSurface,
        taskKind: BASTaskKind,
        riskLevel: BASRiskLevel,
        routeKind: BASRouteKind?,
        headline: String,
        detail: String,
        requiresResume: Bool
    ) {
        self.envelopeID = envelopeID
        self.surface = surface
        self.taskKind = taskKind
        self.riskLevel = riskLevel
        self.routeKind = routeKind
        self.headline = headline
        self.detail = detail
        self.requiresResume = requiresResume
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

public protocol BASAppleHandoffSummarizing: Sendable {
    func summarize(_ envelope: BASAppleHandoffEnvelope, route: BASModelRoute?) -> BASAppleHandoffSummary
}

public struct BASDefaultAppleHandoffSummarizer: BASAppleHandoffSummarizing {
    public init() {}

    public func summarize(_ envelope: BASAppleHandoffEnvelope, route: BASModelRoute?) -> BASAppleHandoffSummary {
        let metadata = envelope.metadata
        let routeLabel = route?.routeKind.rawValue ?? "pending"
        let headline = "\(metadata.surface.rawValue.capitalized) \(metadata.taskKind.rawValue)"
        let detail = "\(metadata.payloadDigest) • route \(routeLabel) • risk \(metadata.riskLevel.rawValue)"

        return BASAppleHandoffSummary(
            envelopeID: envelope.id,
            surface: metadata.surface,
            taskKind: metadata.taskKind,
            riskLevel: metadata.riskLevel,
            routeKind: route?.routeKind,
            headline: headline,
            detail: detail,
            requiresResume: metadata.requiresResume
        )
    }
}
