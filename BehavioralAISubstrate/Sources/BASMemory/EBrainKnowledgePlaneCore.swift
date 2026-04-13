import Foundation
import BASRuntimeCore

public struct BASHostRiskThresholds: Codable, Equatable, Sendable {
    public var caution: Double
    public var protective: Double
    public var block: Double

    public init(
        caution: Double = 0.45,
        protective: Double = 0.7,
        block: Double = 0.9
    ) {
        self.caution = caution
        self.protective = protective
        self.block = block
    }
}

public struct BASMemoryPermissions: Codable, Equatable, Sendable {
    public var allowHotWrites: Bool
    public var allowWarmWrites: Bool
    public var allowColdWrites: Bool
    public var requireReviewForColdWrites: Bool

    public init(
        allowHotWrites: Bool = true,
        allowWarmWrites: Bool = true,
        allowColdWrites: Bool = false,
        requireReviewForColdWrites: Bool = true
    ) {
        self.allowHotWrites = allowHotWrites
        self.allowWarmWrites = allowWarmWrites
        self.allowColdWrites = allowColdWrites
        self.requireReviewForColdWrites = requireReviewForColdWrites
    }
}

public struct BASHostUpdatePolicy: Codable, Equatable, Sendable {
    public var requiresReview: Bool
    public var allowsRollback: Bool
    public var allowsDelete: Bool
    public var allowsFreeze: Bool

    public init(
        requiresReview: Bool = true,
        allowsRollback: Bool = true,
        allowsDelete: Bool = true,
        allowsFreeze: Bool = true
    ) {
        self.requiresReview = requiresReview
        self.allowsRollback = allowsRollback
        self.allowsDelete = allowsDelete
        self.allowsFreeze = allowsFreeze
    }
}

public struct BASHostProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hostID: String
    public var identityTags: [String]
    public var tonePreference: String
    public var longTermGoals: [String]
    public var noGoZones: [String]
    public var riskThresholds: BASHostRiskThresholds
    public var memoryPermissions: BASMemoryPermissions
    public var workRoutines: [String]
    public var relationshipRefs: [String]
    public var styleConstraints: [String]
    public var updatePolicy: BASHostUpdatePolicy
    public var activeVersion: String

    public init(
        schemaVersion: String = BASHostProfile.currentSchemaVersion,
        hostID: String,
        identityTags: [String] = [],
        tonePreference: String = "grounded_clear",
        longTermGoals: [String] = [],
        noGoZones: [String] = [],
        riskThresholds: BASHostRiskThresholds = BASHostRiskThresholds(),
        memoryPermissions: BASMemoryPermissions = BASMemoryPermissions(),
        workRoutines: [String] = [],
        relationshipRefs: [String] = [],
        styleConstraints: [String] = [],
        updatePolicy: BASHostUpdatePolicy = BASHostUpdatePolicy(),
        activeVersion: String = "host.v1"
    ) {
        self.schemaVersion = schemaVersion
        self.hostID = hostID
        self.identityTags = identityTags
        self.tonePreference = tonePreference
        self.longTermGoals = longTermGoals
        self.noGoZones = noGoZones
        self.riskThresholds = riskThresholds
        self.memoryPermissions = memoryPermissions
        self.workRoutines = workRoutines
        self.relationshipRefs = relationshipRefs
        self.styleConstraints = styleConstraints
        self.updatePolicy = updatePolicy
        self.activeVersion = activeVersion
    }
}

public struct BASHostVersion: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var versionID: String
    public var createdAt: Date
    public var changedFields: [String]
    public var reason: String
    public var rollbackRef: String?
    public var approvedByPolicy: Bool

    public init(
        schemaVersion: String = BASHostVersion.currentSchemaVersion,
        versionID: String,
        createdAt: Date = .now,
        changedFields: [String],
        reason: String,
        rollbackRef: String? = nil,
        approvedByPolicy: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.versionID = versionID
        self.createdAt = createdAt
        self.changedFields = changedFields
        self.reason = reason
        self.rollbackRef = rollbackRef
        self.approvedByPolicy = approvedByPolicy
    }
}

public enum BASMemoryAtomContentType: String, Codable, CaseIterable, Sendable {
    case hot
    case warm
    case cold
    case relation
    case routine
    case rule
}

public enum BASPromotionState: String, Codable, CaseIterable, Sendable {
    case candidate
    case admitted
    case frozen
    case retired
}

public struct BASMemoryAtom: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var memoryID: String
    public var summary: String
    public var contentType: BASMemoryAtomContentType
    public var source: String
    public var timestamp: Date
    public var confidence: Double
    public var emotionalWeight: Double
    public var riskRelevance: Double
    public var hostRelevance: Double
    public var conflictFingerprint: String
    public var promotionState: BASPromotionState
    public var frozen: Bool

    public init(
        schemaVersion: String = BASMemoryAtom.currentSchemaVersion,
        memoryID: String,
        summary: String,
        contentType: BASMemoryAtomContentType,
        source: String,
        timestamp: Date = .now,
        confidence: Double,
        emotionalWeight: Double = 0,
        riskRelevance: Double = 0,
        hostRelevance: Double = 0,
        conflictFingerprint: String,
        promotionState: BASPromotionState = .candidate,
        frozen: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.memoryID = memoryID
        self.summary = summary
        self.contentType = contentType
        self.source = source
        self.timestamp = timestamp
        self.confidence = confidence
        self.emotionalWeight = emotionalWeight
        self.riskRelevance = riskRelevance
        self.hostRelevance = hostRelevance
        self.conflictFingerprint = conflictFingerprint
        self.promotionState = promotionState
        self.frozen = frozen
    }
}

public struct BASMemoryBundle: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var atoms: [BASMemoryAtom]
    public var retrievalTags: [String]
    public var conflictRefs: [String]
    public var retrievedAt: Date
    public var activeHostVersion: String?

    public init(
        schemaVersion: String = BASMemoryBundle.currentSchemaVersion,
        atoms: [BASMemoryAtom],
        retrievalTags: [String] = [],
        conflictRefs: [String] = [],
        retrievedAt: Date = .now,
        activeHostVersion: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.atoms = atoms
        self.retrievalTags = retrievalTags
        self.conflictRefs = conflictRefs
        self.retrievedAt = retrievedAt
        self.activeHostVersion = activeHostVersion
    }
}

public enum BASRuleApprovalState: String, Codable, CaseIterable, Sendable {
    case candidate
    case inReview
    case approved
    case rejected
    case rolledBack
}

public struct BASRuleCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var ruleID: String
    public var summary: String
    public var sourceTicketIDs: [String]
    public var scope: String
    public var positiveCases: [String]
    public var negativeCases: [String]
    public var conflictRefs: [String]
    public var confidence: Double
    public var approvalState: BASRuleApprovalState

    public init(
        schemaVersion: String = BASRuleCandidate.currentSchemaVersion,
        ruleID: String,
        summary: String,
        sourceTicketIDs: [String] = [],
        scope: String,
        positiveCases: [String] = [],
        negativeCases: [String] = [],
        conflictRefs: [String] = [],
        confidence: Double,
        approvalState: BASRuleApprovalState = .candidate
    ) {
        self.schemaVersion = schemaVersion
        self.ruleID = ruleID
        self.summary = summary
        self.sourceTicketIDs = sourceTicketIDs
        self.scope = scope
        self.positiveCases = positiveCases
        self.negativeCases = negativeCases
        self.conflictRefs = conflictRefs
        self.confidence = confidence
        self.approvalState = approvalState
    }
}
