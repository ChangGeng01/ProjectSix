import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

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

public struct BASCheckpointRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var workflowID: UUID
    public var status: BASWorkflowStatus
    public var brainState: BASCurrentBrainState
    public var timestamp: Date

    public init(id: UUID = UUID(), workflowID: UUID, status: BASWorkflowStatus, brainState: BASCurrentBrainState, timestamp: Date = .now) {
        self.id = id
        self.workflowID = workflowID
        self.status = status
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
        checkpoints.append(BASCheckpointRecord(workflowID: id, status: status, brainState: brainState))
    }
}
