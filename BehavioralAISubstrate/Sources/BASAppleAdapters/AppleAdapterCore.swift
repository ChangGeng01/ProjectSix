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

public enum BASAppleEntryIntentActionKind: String, Codable, Sendable {
    case capture
    case present
    case predictiveIntervention
    case restore
}

public enum BASAppleBrainRefreshTriggerKind: String, Codable, Sendable {
    case explicitRefresh
    case watchHandoff
}

public struct BASAppleEntryIntentActionPlan: Codable, Sendable, Equatable {
    public var actionKind: BASAppleEntryIntentActionKind
    public var preferredModeID: String?
    public var promptSeed: String
    public var scenarioID: String?
    public var riskLevelID: String?
    public var triggerReason: String?
    public var sourceSurface: BASAppleSurface
    public var shouldSelectBoxTab: Bool
    public var refreshTriggerKind: BASAppleBrainRefreshTriggerKind

    public init(
        actionKind: BASAppleEntryIntentActionKind,
        preferredModeID: String?,
        promptSeed: String,
        scenarioID: String?,
        riskLevelID: String?,
        triggerReason: String?,
        sourceSurface: BASAppleSurface,
        shouldSelectBoxTab: Bool,
        refreshTriggerKind: BASAppleBrainRefreshTriggerKind
    ) {
        self.actionKind = actionKind
        self.preferredModeID = preferredModeID
        self.promptSeed = promptSeed
        self.scenarioID = scenarioID
        self.riskLevelID = riskLevelID
        self.triggerReason = triggerReason
        self.sourceSurface = sourceSurface
        self.shouldSelectBoxTab = shouldSelectBoxTab
        self.refreshTriggerKind = refreshTriggerKind
    }
}

public enum BASAppleEntryIntentPlanBuilder {
    public static func plan(
        kindID: String,
        surfaceID: String,
        preferredModeID: String?,
        scenarioID: String?,
        promptSeed: String?,
        riskLevelID: String?,
        triggerReason: String?
    ) -> BASAppleEntryIntentActionPlan {
        let surface = surface(from: surfaceID)
        let kind = actionKind(from: kindID)
        return BASAppleEntryIntentActionPlan(
            actionKind: kind,
            preferredModeID: preferredModeID,
            promptSeed: promptSeed ?? "",
            scenarioID: scenarioID,
            riskLevelID: riskLevelID,
            triggerReason: triggerReason,
            sourceSurface: surface,
            shouldSelectBoxTab: kindID == "reopenTomorrowItem" || kindID == "reopen",
            refreshTriggerKind: surface == .watch ? .watchHandoff : .explicitRefresh
        )
    }

    private static func actionKind(from rawValue: String) -> BASAppleEntryIntentActionKind {
        switch rawValue {
        case "quickCapture", "capture":
            .capture
        case "predictiveIntervention":
            .predictiveIntervention
        case "resumeCurrentDecision", "resume":
            .restore
        case "openMode", "reopenTomorrowItem", "present", "reopen":
            .present
        default:
            .present
        }
    }

    private static func surface(from rawValue: String) -> BASAppleSurface {
        switch rawValue {
        case BASAppleSurface.watch.rawValue:
            .watch
        case BASAppleSurface.widget.rawValue:
            .widget
        case BASAppleSurface.notification.rawValue:
            .notification
        case "siri", BASAppleSurface.shortcut.rawValue:
            .shortcut
        default:
            .app
        }
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

public enum BASAppleHandoffBridgeBuilder {
    public static func envelope(
        id: UUID,
        surfaceID: String,
        preferredWorkflowID: String?,
        riskLevelID: String?,
        payloadSummary: String,
        createdAt: Date
    ) -> BASAppleHandoffEnvelope {
        BASAppleHandoffEnvelope(
            id: id,
            surface: surface(from: surfaceID),
            taskKind: taskKind(from: preferredWorkflowID),
            riskLevel: BASRiskLevel(rawValue: riskLevelID ?? "") ?? .low,
            payloadSummary: payloadSummary,
            createdAt: createdAt
        )
    }

    public static func summary(
        id: UUID,
        surfaceID: String,
        preferredWorkflowID: String?,
        riskLevelID: String?,
        payloadSummary: String,
        createdAt: Date,
        route: BASModelRoute? = nil
    ) -> BASAppleHandoffSummary {
        BASDefaultAppleHandoffSummarizer().summarize(
            envelope(
                id: id,
                surfaceID: surfaceID,
                preferredWorkflowID: preferredWorkflowID,
                riskLevelID: riskLevelID,
                payloadSummary: payloadSummary,
                createdAt: createdAt
            ),
            route: route
        )
    }

    private static func surface(from rawValue: String) -> BASAppleSurface {
        switch rawValue {
        case BASAppleSurface.app.rawValue:
            .app
        case BASAppleSurface.watch.rawValue:
            .watch
        case BASAppleSurface.widget.rawValue:
            .widget
        case BASAppleSurface.notification.rawValue:
            .notification
        case "siri", BASAppleSurface.shortcut.rawValue:
            .shortcut
        default:
            .app
        }
    }

    private static func taskKind(from preferredWorkflowID: String?) -> BASTaskKind {
        switch preferredWorkflowID {
        case "balance":
            .plan
        case "mirror":
            .retrieve
        default:
            .chat
        }
    }
}
