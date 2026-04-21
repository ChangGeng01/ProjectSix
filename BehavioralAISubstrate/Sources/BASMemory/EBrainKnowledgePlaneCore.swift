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
    public var temporalField: BASTemporalMemoryField?

    public init(
        schemaVersion: String = BASMemoryBundle.currentSchemaVersion,
        atoms: [BASMemoryAtom],
        retrievalTags: [String] = [],
        conflictRefs: [String] = [],
        retrievedAt: Date = .now,
        activeHostVersion: String? = nil,
        temporalField: BASTemporalMemoryField? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.atoms = atoms
        self.retrievalTags = retrievalTags
        self.conflictRefs = conflictRefs
        self.retrievedAt = retrievedAt
        self.activeHostVersion = activeHostVersion
        self.temporalField = temporalField
    }
}

public enum BASTemporalMemoryType: String, Codable, CaseIterable, Sendable {
    case episode
    case relation
    case routine
    case boundary
    case unresolved
    case warning
    case temporary
}

public enum BASMemoryTemperatureBand: String, Codable, CaseIterable, Sendable {
    case hot
    case warm
    case cold
    case sealed
    case quarantine
}

public enum BASMemoryVerificationState: String, Codable, CaseIterable, Sendable {
    case unverified
    case pending
    case verified
    case conflicted
}

public enum BASMemoryConflictType: String, Codable, CaseIterable, Sendable {
    case factual
    case temporal
    case relation
    case authorization
    case interpretation
}

public enum BASMemoryReplayScope: String, Codable, CaseIterable, Sendable {
    case single
    case arc
    case version
    case conflict
    case deletion
    case rollback
}

public struct BASTemporalMemoryField: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var records: [BASTemporalMemoryRecord]
    public var temperatureProfiles: [BASMemoryTemperatureProfile]
    public var provenanceSeals: [BASMemoryProvenanceSeal]
    public var episodeArcs: [BASMemoryEpisodeArc]
    public var conflictClusters: [BASMemoryConflictCluster]
    public var continuityAnchors: [BASMemoryContinuityAnchor]
    public var replayFrames: [BASMemoryReplayFrame]
    public var quarantineRecords: [BASMemoryQuarantineRecord]
    public var sanctumEntries: [BASMemorySanctumEntry]
    public var forgetCascades: [BASMemoryForgetCascade]

    public init(
        schemaVersion: String = BASTemporalMemoryField.currentSchemaVersion,
        records: [BASTemporalMemoryRecord] = [],
        temperatureProfiles: [BASMemoryTemperatureProfile] = [],
        provenanceSeals: [BASMemoryProvenanceSeal] = [],
        episodeArcs: [BASMemoryEpisodeArc] = [],
        conflictClusters: [BASMemoryConflictCluster] = [],
        continuityAnchors: [BASMemoryContinuityAnchor] = [],
        replayFrames: [BASMemoryReplayFrame] = [],
        quarantineRecords: [BASMemoryQuarantineRecord] = [],
        sanctumEntries: [BASMemorySanctumEntry] = [],
        forgetCascades: [BASMemoryForgetCascade] = []
    ) {
        self.schemaVersion = schemaVersion
        self.records = records
        self.temperatureProfiles = temperatureProfiles
        self.provenanceSeals = provenanceSeals
        self.episodeArcs = episodeArcs
        self.conflictClusters = conflictClusters
        self.continuityAnchors = continuityAnchors
        self.replayFrames = replayFrames
        self.quarantineRecords = quarantineRecords
        self.sanctumEntries = sanctumEntries
        self.forgetCascades = forgetCascades
    }

    // Keep the pre-sanctum initializer ABI available for app targets that still
    // reference the older symbol while linking against the current package product.
    public init(
        schemaVersion: String = BASTemporalMemoryField.currentSchemaVersion,
        records: [BASTemporalMemoryRecord] = [],
        temperatureProfiles: [BASMemoryTemperatureProfile] = [],
        provenanceSeals: [BASMemoryProvenanceSeal] = [],
        episodeArcs: [BASMemoryEpisodeArc] = [],
        conflictClusters: [BASMemoryConflictCluster] = [],
        continuityAnchors: [BASMemoryContinuityAnchor] = [],
        replayFrames: [BASMemoryReplayFrame] = [],
        quarantineRecords: [BASMemoryQuarantineRecord] = []
    ) {
        self.init(
            schemaVersion: schemaVersion,
            records: records,
            temperatureProfiles: temperatureProfiles,
            provenanceSeals: provenanceSeals,
            episodeArcs: episodeArcs,
            conflictClusters: conflictClusters,
            continuityAnchors: continuityAnchors,
            replayFrames: replayFrames,
            quarantineRecords: quarantineRecords,
            sanctumEntries: [],
            forgetCascades: []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case records
        case temperatureProfiles
        case provenanceSeals
        case episodeArcs
        case conflictClusters
        case continuityAnchors
        case replayFrames
        case quarantineRecords
        case sanctumEntries
        case forgetCascades
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASTemporalMemoryField.currentSchemaVersion
        records = try container.decodeIfPresent([BASTemporalMemoryRecord].self, forKey: .records) ?? []
        temperatureProfiles = try container.decodeIfPresent([BASMemoryTemperatureProfile].self, forKey: .temperatureProfiles) ?? []
        provenanceSeals = try container.decodeIfPresent([BASMemoryProvenanceSeal].self, forKey: .provenanceSeals) ?? []
        episodeArcs = try container.decodeIfPresent([BASMemoryEpisodeArc].self, forKey: .episodeArcs) ?? []
        conflictClusters = try container.decodeIfPresent([BASMemoryConflictCluster].self, forKey: .conflictClusters) ?? []
        continuityAnchors = try container.decodeIfPresent([BASMemoryContinuityAnchor].self, forKey: .continuityAnchors) ?? []
        replayFrames = try container.decodeIfPresent([BASMemoryReplayFrame].self, forKey: .replayFrames) ?? []
        quarantineRecords = try container.decodeIfPresent([BASMemoryQuarantineRecord].self, forKey: .quarantineRecords) ?? []
        sanctumEntries = try container.decodeIfPresent([BASMemorySanctumEntry].self, forKey: .sanctumEntries) ?? []
        forgetCascades = try container.decodeIfPresent([BASMemoryForgetCascade].self, forKey: .forgetCascades) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(records, forKey: .records)
        try container.encode(temperatureProfiles, forKey: .temperatureProfiles)
        try container.encode(provenanceSeals, forKey: .provenanceSeals)
        try container.encode(episodeArcs, forKey: .episodeArcs)
        try container.encode(conflictClusters, forKey: .conflictClusters)
        try container.encode(continuityAnchors, forKey: .continuityAnchors)
        try container.encode(replayFrames, forKey: .replayFrames)
        try container.encode(quarantineRecords, forKey: .quarantineRecords)
        try container.encode(sanctumEntries, forKey: .sanctumEntries)
        try container.encode(forgetCascades, forKey: .forgetCascades)
    }
}

public struct BASTemporalMemoryRecord: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var memoryID: String
    public var summary: String
    public var memoryType: BASTemporalMemoryType
    public var sourceClass: String
    public var sourceRefs: [String]
    public var timestamp: Date
    public var certainty: Double
    public var evidenceStrength: Double
    public var emotionalWeight: Double
    public var hostScope: String
    public var sovereignScope: String
    public var sanctumFlag: Bool
    public var quarantineFlag: Bool
    public var lineageRefs: [String]
    public var temperatureProfileRef: String?
    public var provenanceSealRef: String?

    public init(
        schemaVersion: String = BASTemporalMemoryRecord.currentSchemaVersion,
        memoryID: String,
        summary: String,
        memoryType: BASTemporalMemoryType,
        sourceClass: String,
        sourceRefs: [String] = [],
        timestamp: Date = .now,
        certainty: Double,
        evidenceStrength: Double,
        emotionalWeight: Double = 0,
        hostScope: String,
        sovereignScope: String,
        sanctumFlag: Bool = false,
        quarantineFlag: Bool = false,
        lineageRefs: [String] = [],
        temperatureProfileRef: String? = nil,
        provenanceSealRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.memoryID = memoryID
        self.summary = summary
        self.memoryType = memoryType
        self.sourceClass = sourceClass
        self.sourceRefs = sourceRefs
        self.timestamp = timestamp
        self.certainty = certainty
        self.evidenceStrength = evidenceStrength
        self.emotionalWeight = emotionalWeight
        self.hostScope = hostScope
        self.sovereignScope = sovereignScope
        self.sanctumFlag = sanctumFlag
        self.quarantineFlag = quarantineFlag
        self.lineageRefs = lineageRefs
        self.temperatureProfileRef = temperatureProfileRef
        self.provenanceSealRef = provenanceSealRef
    }
}

public struct BASMemoryTemperatureProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var profileID: String
    public var currentBand: BASMemoryTemperatureBand
    public var halfLifeHours: Double
    public var promotionRules: [String]
    public var decayRules: [String]
    public var accessRules: [String]
    public var lastShiftAt: Date

    public init(
        schemaVersion: String = BASMemoryTemperatureProfile.currentSchemaVersion,
        profileID: String,
        currentBand: BASMemoryTemperatureBand,
        halfLifeHours: Double,
        promotionRules: [String] = [],
        decayRules: [String] = [],
        accessRules: [String] = [],
        lastShiftAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
        self.currentBand = currentBand
        self.halfLifeHours = halfLifeHours
        self.promotionRules = promotionRules
        self.decayRules = decayRules
        self.accessRules = accessRules
        self.lastShiftAt = lastShiftAt
    }
}

public struct BASMemoryProvenanceSeal: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sealID: String
    public var sourceClass: String
    public var consentRef: String
    public var riskStateRef: String
    public var sovereignStateRef: String
    public var creationTurnRef: String
    public var verificationState: BASMemoryVerificationState

    public init(
        schemaVersion: String = BASMemoryProvenanceSeal.currentSchemaVersion,
        sealID: String,
        sourceClass: String,
        consentRef: String,
        riskStateRef: String,
        sovereignStateRef: String,
        creationTurnRef: String,
        verificationState: BASMemoryVerificationState = .unverified
    ) {
        self.schemaVersion = schemaVersion
        self.sealID = sealID
        self.sourceClass = sourceClass
        self.consentRef = consentRef
        self.riskStateRef = riskStateRef
        self.sovereignStateRef = sovereignStateRef
        self.creationTurnRef = creationTurnRef
        self.verificationState = verificationState
    }
}

public struct BASMemoryEpisodeArc: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var arcID: String
    public var title: String
    public var linkedMemoryRefs: [String]
    public var startTime: Date
    public var currentState: String
    public var escalationPattern: String
    public var unresolvedThreads: [String]
    public var stability: Double

    public init(
        schemaVersion: String = BASMemoryEpisodeArc.currentSchemaVersion,
        arcID: String,
        title: String,
        linkedMemoryRefs: [String] = [],
        startTime: Date = .now,
        currentState: String,
        escalationPattern: String,
        unresolvedThreads: [String] = [],
        stability: Double
    ) {
        self.schemaVersion = schemaVersion
        self.arcID = arcID
        self.title = title
        self.linkedMemoryRefs = linkedMemoryRefs
        self.startTime = startTime
        self.currentState = currentState
        self.escalationPattern = escalationPattern
        self.unresolvedThreads = unresolvedThreads
        self.stability = stability
    }
}

public struct BASMemoryConflictCluster: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var clusterID: String
    public var memoryRefs: [String]
    public var conflictType: BASMemoryConflictType
    public var severity: Double
    public var preferredRef: String?
    public var unresolved: Bool

    public init(
        schemaVersion: String = BASMemoryConflictCluster.currentSchemaVersion,
        clusterID: String,
        memoryRefs: [String] = [],
        conflictType: BASMemoryConflictType,
        severity: Double,
        preferredRef: String? = nil,
        unresolved: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.clusterID = clusterID
        self.memoryRefs = memoryRefs
        self.conflictType = conflictType
        self.severity = severity
        self.preferredRef = preferredRef
        self.unresolved = unresolved
    }
}

public struct BASMemoryContinuityAnchor: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var anchorID: String
    public var hostVersionRef: String
    public var activeGoalRefs: [String]
    public var activeRelationRefs: [String]
    public var activeArcRefs: [String]
    public var samenessWeight: Double

    public init(
        schemaVersion: String = BASMemoryContinuityAnchor.currentSchemaVersion,
        anchorID: String,
        hostVersionRef: String,
        activeGoalRefs: [String] = [],
        activeRelationRefs: [String] = [],
        activeArcRefs: [String] = [],
        samenessWeight: Double
    ) {
        self.schemaVersion = schemaVersion
        self.anchorID = anchorID
        self.hostVersionRef = hostVersionRef
        self.activeGoalRefs = activeGoalRefs
        self.activeRelationRefs = activeRelationRefs
        self.activeArcRefs = activeArcRefs
        self.samenessWeight = samenessWeight
    }
}

public struct BASMemoryReplayFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var replayID: String
    public var targetRefs: [String]
    public var replayScope: BASMemoryReplayScope
    public var timeline: [String]
    public var integrityHash: String

    public init(
        schemaVersion: String = BASMemoryReplayFrame.currentSchemaVersion,
        replayID: String,
        targetRefs: [String] = [],
        replayScope: BASMemoryReplayScope,
        timeline: [String] = [],
        integrityHash: String
    ) {
        self.schemaVersion = schemaVersion
        self.replayID = replayID
        self.targetRefs = targetRefs
        self.replayScope = replayScope
        self.timeline = timeline
        self.integrityHash = integrityHash
    }
}

public struct BASMemoryQuarantineRecord: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var quarantineID: String
    public var memoryRef: String
    public var reasonCodes: [String]
    public var lineageCutRef: String?
    public var releaseConditions: [String]

    public init(
        schemaVersion: String = BASMemoryQuarantineRecord.currentSchemaVersion,
        quarantineID: String,
        memoryRef: String,
        reasonCodes: [String] = [],
        lineageCutRef: String? = nil,
        releaseConditions: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.quarantineID = quarantineID
        self.memoryRef = memoryRef
        self.reasonCodes = reasonCodes
        self.lineageCutRef = lineageCutRef
        self.releaseConditions = releaseConditions
    }
}

public struct BASMemorySanctumEntry: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var entryID: String
    public var memoryRef: String
    public var accessPolicy: String
    public var revealConditions: [String]
    public var frozenUntil: Date?

    public init(
        schemaVersion: String = BASMemorySanctumEntry.currentSchemaVersion,
        entryID: String,
        memoryRef: String,
        accessPolicy: String,
        revealConditions: [String] = [],
        frozenUntil: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.entryID = entryID
        self.memoryRef = memoryRef
        self.accessPolicy = accessPolicy
        self.revealConditions = revealConditions
        self.frozenUntil = frozenUntil
    }
}

public struct BASMemoryForgetCascade: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var cascadeID: String
    public var rootTargets: [String]
    public var dependentRefs: [String]
    public var cacheRefs: [String]
    public var foldRefs: [String]
    public var syncRefs: [String]
    public var executionState: String

    public init(
        schemaVersion: String = BASMemoryForgetCascade.currentSchemaVersion,
        cascadeID: String,
        rootTargets: [String] = [],
        dependentRefs: [String] = [],
        cacheRefs: [String] = [],
        foldRefs: [String] = [],
        syncRefs: [String] = [],
        executionState: String
    ) {
        self.schemaVersion = schemaVersion
        self.cascadeID = cascadeID
        self.rootTargets = rootTargets
        self.dependentRefs = dependentRefs
        self.cacheRefs = cacheRefs
        self.foldRefs = foldRefs
        self.syncRefs = syncRefs
        self.executionState = executionState
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
    public static let currentSchemaVersion = "1.1.0"

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
    public var outOfScope: [String]
    public var shadowTrialState: String
    public var rollbackRef: String?

    public init(
        schemaVersion: String = BASRuleCandidate.currentSchemaVersion,
        ruleID: String,
        summary: String,
        sourceTicketIDs: [String] = [],
        scope: String,
        positiveCases: [String] = [],
        negativeCases: [String] = [],
        conflictRefs: [String] = [],
        outOfScope: [String] = [],
        confidence: Double,
        shadowTrialState: String = "not_required",
        rollbackRef: String? = nil,
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
        self.outOfScope = outOfScope
        self.shadowTrialState = shadowTrialState
        self.rollbackRef = rollbackRef
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case ruleID
        case summary
        case sourceTicketIDs
        case scope
        case positiveCases
        case negativeCases
        case conflictRefs
        case confidence
        case approvalState
        case outOfScope
        case shadowTrialState
        case rollbackRef
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASRuleCandidate.currentSchemaVersion
        ruleID = try container.decode(String.self, forKey: .ruleID)
        summary = try container.decode(String.self, forKey: .summary)
        sourceTicketIDs = try container.decodeIfPresent([String].self, forKey: .sourceTicketIDs) ?? []
        scope = try container.decode(String.self, forKey: .scope)
        positiveCases = try container.decodeIfPresent([String].self, forKey: .positiveCases) ?? []
        negativeCases = try container.decodeIfPresent([String].self, forKey: .negativeCases) ?? []
        conflictRefs = try container.decodeIfPresent([String].self, forKey: .conflictRefs) ?? []
        confidence = try container.decode(Double.self, forKey: .confidence)
        approvalState = try container.decodeIfPresent(BASRuleApprovalState.self, forKey: .approvalState)
            ?? .candidate
        outOfScope = try container.decodeIfPresent([String].self, forKey: .outOfScope) ?? []
        shadowTrialState = try container.decodeIfPresent(String.self, forKey: .shadowTrialState)
            ?? "not_required"
        rollbackRef = try container.decodeIfPresent(String.self, forKey: .rollbackRef)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(ruleID, forKey: .ruleID)
        try container.encode(summary, forKey: .summary)
        try container.encode(sourceTicketIDs, forKey: .sourceTicketIDs)
        try container.encode(scope, forKey: .scope)
        try container.encode(positiveCases, forKey: .positiveCases)
        try container.encode(negativeCases, forKey: .negativeCases)
        try container.encode(conflictRefs, forKey: .conflictRefs)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(approvalState, forKey: .approvalState)
        try container.encode(outOfScope, forKey: .outOfScope)
        try container.encode(shadowTrialState, forKey: .shadowTrialState)
        try container.encodeIfPresent(rollbackRef, forKey: .rollbackRef)
    }
}
