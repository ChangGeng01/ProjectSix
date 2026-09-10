import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASEntryIntentKind: String, Codable, Sendable {
    case capture
    case present
    case reopen
    case predictiveIntervention
    case resume
}

public enum BASEntryIntentSurface: String, Codable, Sendable {
    case app
    case watch
    case widget
    case shortcut
    case siri
    case notification
}

public enum BASWorkflowStatus: String, Codable, Sendable {
    case idle
    case running
    case paused
    case completed
    case failed
}

public enum BASApprovalRequirement: Codable, Sendable, Equatable {
    case none
    case manual(reason: String)
}

public enum BASIntentEntryKind: String, Codable, Sendable {
    case capture
    case reopen
    case predictive
    case resume
}

public enum BASIntentSurface: String, Codable, Sendable {
    case app
    case widget
    case watch
    case notification
    case shortcut
    case system
}

public struct BASIntentEnvelope: Codable, Sendable, Equatable {
    public var id: UUID
    public var entryKind: BASIntentEntryKind
    public var surface: BASIntentSurface
    public var taskKind: BASTaskKind?
    public var routeKind: BASRouteKind?
    public var riskLevel: BASRiskLevel
    public var payloadSummary: String
    public var resumeHint: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        entryKind: BASIntentEntryKind,
        surface: BASIntentSurface,
        taskKind: BASTaskKind? = nil,
        routeKind: BASRouteKind? = nil,
        riskLevel: BASRiskLevel,
        payloadSummary: String,
        resumeHint: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.entryKind = entryKind
        self.surface = surface
        self.taskKind = taskKind
        self.routeKind = routeKind
        self.riskLevel = riskLevel
        self.payloadSummary = payloadSummary
        self.resumeHint = resumeHint
        self.createdAt = createdAt
    }

    public var shouldCheckpoint: Bool {
        switch entryKind {
        case .capture, .reopen:
            return true
        case .predictive, .resume:
            return false
        }
    }

    public var shouldResume: Bool {
        entryKind == .resume || entryKind == .reopen
    }

    public var shouldPredict: Bool {
        entryKind == .predictive
    }

    public var isForegroundPreferred: Bool {
        switch surface {
        case .watch, .notification:
            return true
        case .app, .widget, .shortcut, .system:
            return riskLevel == .high || shouldResume
        }
    }

    public var workflowNodeID: String {
        switch entryKind {
        case .capture:
            return "capture"
        case .reopen:
            return "reopen"
        case .predictive:
            return "predictive"
        case .resume:
            return "resume"
        }
    }
}

public struct BASOrchestrationEntryPlan: Codable, Sendable, Equatable {
    public var envelopeID: UUID
    public var workflowStatus: BASWorkflowStatus
    public var currentNodeID: String
    public var shouldCheckpoint: Bool
    public var shouldResume: Bool
    public var shouldPredict: Bool
    public var approvalRequirement: BASApprovalRequirement
    public var surface: BASIntentSurface
    public var taskKind: BASTaskKind?
    public var routeKind: BASRouteKind?
    public var resumeHint: String?
    public var createdAt: Date

    public init(
        envelopeID: UUID,
        workflowStatus: BASWorkflowStatus,
        currentNodeID: String,
        shouldCheckpoint: Bool,
        shouldResume: Bool,
        shouldPredict: Bool,
        approvalRequirement: BASApprovalRequirement,
        surface: BASIntentSurface,
        taskKind: BASTaskKind?,
        routeKind: BASRouteKind?,
        resumeHint: String?,
        createdAt: Date = .now
    ) {
        self.envelopeID = envelopeID
        self.workflowStatus = workflowStatus
        self.currentNodeID = currentNodeID
        self.shouldCheckpoint = shouldCheckpoint
        self.shouldResume = shouldResume
        self.shouldPredict = shouldPredict
        self.approvalRequirement = approvalRequirement
        self.surface = surface
        self.taskKind = taskKind
        self.routeKind = routeKind
        self.resumeHint = resumeHint
        self.createdAt = createdAt
    }
}

public struct BASCheckpointRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var workflowID: UUID
    public var status: BASWorkflowStatus
    public var currentNodeID: String?
    public var brainState: BASCurrentBrainState
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        workflowID: UUID,
        status: BASWorkflowStatus,
        currentNodeID: String? = nil,
        brainState: BASCurrentBrainState,
        timestamp: Date = .now
    ) {
        self.id = id
        self.workflowID = workflowID
        self.status = status
        self.currentNodeID = currentNodeID
        self.brainState = brainState
        self.timestamp = timestamp
    }
}

public struct BASWorkflowNode: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var actionClass: BASPolicyActionClass
    public var approvalRequirement: BASApprovalRequirement

    public init(id: String, title: String, actionClass: BASPolicyActionClass, approvalRequirement: BASApprovalRequirement = .none) {
        self.id = id
        self.title = title
        self.actionClass = actionClass
        self.approvalRequirement = approvalRequirement
    }
}

public struct BASResolvedEnvelope: Codable, Sendable, Equatable {
    public var id: UUID
    public var taskKind: BASTaskKind
    public var route: BASModelRoute
    public var policyDecision: BASPolicyDecisionRecord
    public var riskLevel: BASRiskLevel
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        taskKind: BASTaskKind,
        route: BASModelRoute,
        policyDecision: BASPolicyDecisionRecord,
        riskLevel: BASRiskLevel,
        timestamp: Date = .now
    ) {
        self.id = id
        self.taskKind = taskKind
        self.route = route
        self.policyDecision = policyDecision
        self.riskLevel = riskLevel
        self.timestamp = timestamp
    }
}

public struct BASEntryIntentEnvelope: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: BASEntryIntentKind
    public var surface: BASEntryIntentSurface
    public var taskKind: BASTaskKind
    public var preferredWorkflowID: String?
    public var promptSeed: String?
    public var riskLevel: BASRiskLevel?
    public var triggerReason: String?
    public var continuityToken: String?
    public var requestedAt: Date
    public var expiresAt: Date

    public init(
        id: UUID = UUID(),
        kind: BASEntryIntentKind,
        surface: BASEntryIntentSurface,
        taskKind: BASTaskKind,
        preferredWorkflowID: String? = nil,
        promptSeed: String? = nil,
        riskLevel: BASRiskLevel? = nil,
        triggerReason: String? = nil,
        continuityToken: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.surface = surface
        self.taskKind = taskKind
        self.preferredWorkflowID = preferredWorkflowID
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
        self.triggerReason = triggerReason
        self.continuityToken = continuityToken
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt
    }

    public func isExpired(at now: Date = .now) -> Bool {
        expiresAt <= now
    }
}

public struct BASEntryIntentSummary: Codable, Sendable, Equatable {
    public var headline: String
    public var detail: String
    public var requiresResume: Bool

    public init(headline: String, detail: String, requiresResume: Bool) {
        self.headline = headline
        self.detail = detail
        self.requiresResume = requiresResume
    }
}

public enum BASEntryIntentSummarizer {
    public static func summarize(_ envelope: BASEntryIntentEnvelope) -> BASEntryIntentSummary {
        let headline = "\(envelope.surface.rawValue.capitalized) \(envelope.kind.rawValue)"
        let prompt = envelope.promptSeed.map { String($0.prefix(80)) } ?? "No prompt seed"
        let detail = "\(prompt) • task \(envelope.taskKind.rawValue) • risk \(envelope.riskLevel?.rawValue ?? "unknown")"
        let requiresResume = envelope.kind == .resume || envelope.taskKind == .plan || envelope.riskLevel == .high
        return BASEntryIntentSummary(
            headline: headline,
            detail: detail,
            requiresResume: requiresResume
        )
    }
}

public enum BASEntryIntentBridgeBuilder {
    public static func envelope(
        kindID: String,
        surfaceID: String,
        preferredWorkflowID: String?,
        promptSeed: String?,
        riskLevelID: String?,
        triggerReason: String?,
        continuityToken: String?,
        requestedAt: Date,
        expiresAt: Date
    ) -> BASEntryIntentEnvelope {
        BASEntryIntentEnvelope(
            kind: kind(from: kindID),
            surface: surface(from: surfaceID),
            taskKind: taskKind(from: preferredWorkflowID),
            preferredWorkflowID: preferredWorkflowID,
            promptSeed: promptSeed,
            riskLevel: riskLevelID.flatMap(BASRiskLevel.init(rawValue:)),
            triggerReason: triggerReason,
            continuityToken: continuityToken,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    public static func summary(
        kindID: String,
        surfaceID: String,
        preferredWorkflowID: String?,
        promptSeed: String?,
        riskLevelID: String?,
        triggerReason: String?,
        continuityToken: String?,
        requestedAt: Date,
        expiresAt: Date
    ) -> BASEntryIntentSummary {
        BASEntryIntentSummarizer.summarize(
            envelope(
                kindID: kindID,
                surfaceID: surfaceID,
                preferredWorkflowID: preferredWorkflowID,
                promptSeed: promptSeed,
                riskLevelID: riskLevelID,
                triggerReason: triggerReason,
                continuityToken: continuityToken,
                requestedAt: requestedAt,
                expiresAt: expiresAt
            )
        )
    }

    private static func kind(from rawValue: String) -> BASEntryIntentKind {
        switch rawValue {
        case "capture":
            .capture
        case "present":
            .present
        case "reopen":
            .reopen
        case "resume":
            .resume
        case BASEntryIntentKind.predictiveIntervention.rawValue:
            .predictiveIntervention
        default:
            // audit orchestration LOW-3: an unrecognized boundary raw value collapses to the most
            // CONSERVATIVE kind — `.capture` (a passive record), never an action-bearing kind like
            // `.present` / `.predictiveIntervention`. Deliberate fail-safe, not an accidental default.
            .capture
        }
    }

    private static func surface(from rawValue: String) -> BASEntryIntentSurface {
        BASEntryIntentSurface(rawValue: rawValue) ?? .app
    }

    private static func taskKind(from preferredWorkflowID: String?) -> BASTaskKind {
        switch preferredWorkflowID.flatMap(BASDecisionMode.init(identifier:)) {
        case .comparative?:
            .plan
        case .reflective?:
            .retrieve
        default:
            .chat
        }
    }
}

public struct BASWorkflowState: Codable, Sendable, Equatable {
    public var id: UUID
    public var status: BASWorkflowStatus
    public var currentNodeID: String?
    public var nodes: [BASWorkflowNode]
    public var checkpoints: [BASCheckpointRecord]
    public var resolvedEnvelope: BASResolvedEnvelope?

    public init(
        id: UUID = UUID(),
        status: BASWorkflowStatus = .idle,
        currentNodeID: String? = nil,
        nodes: [BASWorkflowNode] = [],
        checkpoints: [BASCheckpointRecord] = [],
        resolvedEnvelope: BASResolvedEnvelope? = nil
    ) {
        self.id = id
        self.status = status
        self.currentNodeID = currentNodeID
        self.nodes = nodes
        self.checkpoints = checkpoints
        self.resolvedEnvelope = resolvedEnvelope
    }

    public mutating func checkpoint(brainState: BASCurrentBrainState) {
        checkpoints.append(
            BASCheckpointRecord(
                workflowID: id,
                status: status,
                currentNodeID: currentNodeID,
                brainState: brainState
            )
        )
    }

    public mutating func apply(
        _ plan: BASOrchestrationEntryPlan,
        nodes: [BASWorkflowNode] = [],
        resolvedEnvelope: BASResolvedEnvelope? = nil
    ) {
        status = plan.workflowStatus
        currentNodeID = plan.currentNodeID
        if !nodes.isEmpty {
            self.nodes = nodes
        }
        if let resolvedEnvelope {
            self.resolvedEnvelope = resolvedEnvelope
        }
    }

    public mutating func pause(at nodeID: String? = nil) {
        status = .paused
        if let nodeID {
            currentNodeID = nodeID
        }
    }

    public mutating func resume(at nodeID: String? = nil) {
        status = .running
        if let nodeID {
            currentNodeID = nodeID
        }
    }

    public mutating func complete(at nodeID: String? = nil) {
        status = .completed
        if let nodeID {
            currentNodeID = nodeID
        }
    }

    @discardableResult
    public mutating func rewind(to checkpointID: UUID) -> Bool {
        guard let index = checkpoints.firstIndex(where: { $0.id == checkpointID }) else {
            return false
        }

        let checkpoint = checkpoints[index]
        status = checkpoint.status
        currentNodeID = checkpoint.currentNodeID
        checkpoints = Array(checkpoints.prefix(index + 1))
        return true
    }

    public func plan(for intent: BASIntentEnvelope) -> BASOrchestrationEntryPlan {
        let status: BASWorkflowStatus
        switch intent.entryKind {
        case .capture, .resume:
            status = .running
        case .reopen, .predictive:
            status = .paused
        }

        let approvalRequirement: BASApprovalRequirement
        if intent.riskLevel == .high {
            approvalRequirement = .manual(reason: "high risk intent requires review")
        } else if intent.entryKind == .reopen {
            approvalRequirement = .manual(reason: "reopen requires explicit resume context")
        } else {
            approvalRequirement = .none
        }

        return BASOrchestrationEntryPlan(
            envelopeID: intent.id,
            workflowStatus: status,
            currentNodeID: intent.workflowNodeID,
            shouldCheckpoint: intent.shouldCheckpoint,
            shouldResume: intent.shouldResume,
            shouldPredict: intent.shouldPredict,
            approvalRequirement: approvalRequirement,
            surface: intent.surface,
            taskKind: intent.taskKind,
            routeKind: intent.routeKind,
            resumeHint: intent.resumeHint,
            createdAt: intent.createdAt
        )
    }
}
