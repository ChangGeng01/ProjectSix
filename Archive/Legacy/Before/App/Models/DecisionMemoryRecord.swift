import Foundation
import SwiftData
import BASHostKit
// M86 — BASMemory is @_exported from BASHostKit; direct import removed
// per check_sdk_import_boundaries.sh (FORBIDDEN_REGEX).

enum DecisionMemoryType: String, Codable, Sendable {
    case identity
    case preference
    case goal
    case situational
    case semantic
    case support
}

enum DecisionMemorySource: String, Codable, Sendable {
    case history
    case reflection
    case reminder
    case pattern
}

enum DecisionMemoryDecayPolicy: String, Codable, Sendable {
    case stable
    case slow
    case medium
    case fast
}

enum DecisionMemoryWriteOperation: String, Codable, Sendable {
    case add
    case update
    case delete
    case noop
}

enum DecisionMemoryCandidateStatus: String, Codable, Sendable {
    case pending
    case promoted
}

enum DecisionMemoryGovernanceDecision: String, Codable, Sendable {
    case admit
    case deferred
    case reject
}

enum DecisionMemoryLifecycleState: String, Codable, Sendable {
    case active
    case aging
    case retired
}

enum DecisionMemorySourceType: String, Codable, Sendable {
    case userConfirmed
    case repeatedBehavior
    case reflectionInference
    case externalRetrieval
}

enum DecisionTemporalSieveDisposition: String, Codable, Sendable {
    case reject
    case admitHotWarm
    case conflictCluster
    case quarantine
}

struct DecisionTemporalProjection: Codable, Equatable, Sendable {
    var temporalMemoryID: String?
    var sieveDisposition: DecisionTemporalSieveDisposition
    var normalRetrievalBlocked: Bool
    var temperatureProfileID: String?
    var provenanceSealID: String?
    var sanctumEntryID: String?
    var sanctumAccessPolicy: String?
    var sanctumRevealConditions: [String]
    var sanctumFrozenUntil: Date?
    var episodeArcIDs: [String]
    var conflictClusterIDs: [String]
    var continuityAnchorID: String?
    var replayFrameID: String?
    var quarantineRecordID: String?
    var forgetExecutionState: String?
    var forgetCascadeIDs: [String]

    init(
        temporalMemoryID: String? = nil,
        sieveDisposition: DecisionTemporalSieveDisposition,
        normalRetrievalBlocked: Bool = false,
        temperatureProfileID: String? = nil,
        provenanceSealID: String? = nil,
        sanctumEntryID: String? = nil,
        sanctumAccessPolicy: String? = nil,
        sanctumRevealConditions: [String] = [],
        sanctumFrozenUntil: Date? = nil,
        episodeArcIDs: [String] = [],
        conflictClusterIDs: [String] = [],
        continuityAnchorID: String? = nil,
        replayFrameID: String? = nil,
        quarantineRecordID: String? = nil,
        forgetExecutionState: String? = nil,
        forgetCascadeIDs: [String] = []
    ) {
        self.temporalMemoryID = temporalMemoryID
        self.sieveDisposition = sieveDisposition
        self.normalRetrievalBlocked = normalRetrievalBlocked
        self.temperatureProfileID = temperatureProfileID
        self.provenanceSealID = provenanceSealID
        self.sanctumEntryID = sanctumEntryID
        self.sanctumAccessPolicy = sanctumAccessPolicy
        self.sanctumRevealConditions = sanctumRevealConditions
        self.sanctumFrozenUntil = sanctumFrozenUntil
        self.episodeArcIDs = episodeArcIDs
        self.conflictClusterIDs = conflictClusterIDs
        self.continuityAnchorID = continuityAnchorID
        self.replayFrameID = replayFrameID
        self.quarantineRecordID = quarantineRecordID
        self.forgetExecutionState = forgetExecutionState
        self.forgetCascadeIDs = forgetCascadeIDs
    }

    private enum CodingKeys: String, CodingKey {
        case temporalMemoryID
        case sieveDisposition
        case normalRetrievalBlocked
        case temperatureProfileID
        case provenanceSealID
        case sanctumEntryID
        case sanctumAccessPolicy
        case sanctumRevealConditions
        case sanctumFrozenUntil
        case episodeArcIDs
        case conflictClusterIDs
        case continuityAnchorID
        case replayFrameID
        case quarantineRecordID
        case forgetExecutionState
        case forgetCascadeIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let temporalMemoryID = try container.decodeIfPresent(String.self, forKey: .temporalMemoryID)
        let temperatureProfileID = try container.decodeIfPresent(String.self, forKey: .temperatureProfileID)
        let provenanceSealID = try container.decodeIfPresent(String.self, forKey: .provenanceSealID)
        let sanctumEntryID = try container.decodeIfPresent(String.self, forKey: .sanctumEntryID)
        let sanctumAccessPolicy = try container.decodeIfPresent(String.self, forKey: .sanctumAccessPolicy)
        let sanctumRevealConditions = try container.decodeIfPresent(
            [String].self,
            forKey: .sanctumRevealConditions
        ) ?? []
        let sanctumFrozenUntil = try container.decodeIfPresent(Date.self, forKey: .sanctumFrozenUntil)
        let episodeArcIDs = try container.decodeIfPresent([String].self, forKey: .episodeArcIDs) ?? []
        let conflictClusterIDs = try container.decodeIfPresent([String].self, forKey: .conflictClusterIDs) ?? []
        let continuityAnchorID = try container.decodeIfPresent(String.self, forKey: .continuityAnchorID)
        let replayFrameID = try container.decodeIfPresent(String.self, forKey: .replayFrameID)
        let quarantineRecordID = try container.decodeIfPresent(String.self, forKey: .quarantineRecordID)
        let forgetExecutionState = try container.decodeIfPresent(String.self, forKey: .forgetExecutionState)
        let forgetCascadeIDs = try container.decodeIfPresent([String].self, forKey: .forgetCascadeIDs) ?? []

        let sieveDisposition = try container.decodeIfPresent(
            DecisionTemporalSieveDisposition.self,
            forKey: .sieveDisposition
        ) ?? Self.legacyDisposition(
            temporalMemoryID: temporalMemoryID,
            conflictClusterIDs: conflictClusterIDs,
            quarantineRecordID: quarantineRecordID
        )
        let normalRetrievalBlocked = try container.decodeIfPresent(
            Bool.self,
            forKey: .normalRetrievalBlocked
        ) ?? Self.legacyNormalRetrievalBlocked(
            sanctumEntryID: sanctumEntryID,
            quarantineRecordID: quarantineRecordID
        )

        self.init(
            temporalMemoryID: temporalMemoryID,
            sieveDisposition: sieveDisposition,
            normalRetrievalBlocked: normalRetrievalBlocked,
            temperatureProfileID: temperatureProfileID,
            provenanceSealID: provenanceSealID,
            sanctumEntryID: sanctumEntryID,
            sanctumAccessPolicy: sanctumAccessPolicy,
            sanctumRevealConditions: sanctumRevealConditions,
            sanctumFrozenUntil: sanctumFrozenUntil,
            episodeArcIDs: episodeArcIDs,
            conflictClusterIDs: conflictClusterIDs,
            continuityAnchorID: continuityAnchorID,
            replayFrameID: replayFrameID,
            quarantineRecordID: quarantineRecordID,
            forgetExecutionState: forgetExecutionState,
            forgetCascadeIDs: forgetCascadeIDs
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(temporalMemoryID, forKey: .temporalMemoryID)
        try container.encode(sieveDisposition, forKey: .sieveDisposition)
        try container.encode(normalRetrievalBlocked, forKey: .normalRetrievalBlocked)
        try container.encodeIfPresent(temperatureProfileID, forKey: .temperatureProfileID)
        try container.encodeIfPresent(provenanceSealID, forKey: .provenanceSealID)
        try container.encodeIfPresent(sanctumEntryID, forKey: .sanctumEntryID)
        try container.encodeIfPresent(sanctumAccessPolicy, forKey: .sanctumAccessPolicy)
        try container.encode(sanctumRevealConditions, forKey: .sanctumRevealConditions)
        try container.encodeIfPresent(sanctumFrozenUntil, forKey: .sanctumFrozenUntil)
        try container.encode(episodeArcIDs, forKey: .episodeArcIDs)
        try container.encode(conflictClusterIDs, forKey: .conflictClusterIDs)
        try container.encodeIfPresent(continuityAnchorID, forKey: .continuityAnchorID)
        try container.encodeIfPresent(replayFrameID, forKey: .replayFrameID)
        try container.encodeIfPresent(quarantineRecordID, forKey: .quarantineRecordID)
        try container.encodeIfPresent(forgetExecutionState, forKey: .forgetExecutionState)
        try container.encode(forgetCascadeIDs, forKey: .forgetCascadeIDs)
    }

    private static func legacyDisposition(
        temporalMemoryID: String?,
        conflictClusterIDs: [String],
        quarantineRecordID: String?
    ) -> DecisionTemporalSieveDisposition {
        if quarantineRecordID != nil {
            return .quarantine
        }
        if conflictClusterIDs.isEmpty == false {
            return .conflictCluster
        }
        if temporalMemoryID != nil {
            return .admitHotWarm
        }
        return .reject
    }

    private static func legacyNormalRetrievalBlocked(
        sanctumEntryID: String?,
        quarantineRecordID: String?
    ) -> Bool {
        sanctumEntryID != nil || quarantineRecordID != nil
    }
}

@Model
final class DecisionMemoryRecord {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var topic: String
    var headline: String
    var value: String
    var confidence: Double
    var priority: Double
    var sourceRaw: String
    var lastConfirmedAt: Date
    var decayPolicyRaw: String
    var retrievalTagsBlob: String
    var evidenceCount: Int
    var observationCount: Int
    var provenanceSummary: String
    var lifecycleStateRaw: String?
    var lastReviewedAt: Date?
    var tierRaw: String?
    var temporalProjectionBlob: String?

    init(
        id: String,
        type: DecisionMemoryType,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: DecisionMemorySource,
        lastConfirmedAt: Date,
        decayPolicy: DecisionMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        observationCount: Int,
        provenanceSummary: String,
        lifecycleState: DecisionMemoryLifecycleState = .active,
        lastReviewedAt: Date? = nil,
        tier: DecisionMemoryTier = .warm,
        temporalProjection: DecisionTemporalProjection? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceRaw = source.rawValue
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicyRaw = decayPolicy.rawValue
        self.retrievalTagsBlob = Self.encodeTags(retrievalTags)
        self.evidenceCount = evidenceCount
        self.observationCount = observationCount
        self.provenanceSummary = provenanceSummary
        self.lifecycleStateRaw = lifecycleState.rawValue
        self.lastReviewedAt = lastReviewedAt ?? lastConfirmedAt
        self.tierRaw = tier.rawValue
        self.temporalProjectionBlob = Self.encodeTemporalProjection(temporalProjection)
    }
}

@Model
final class DecisionMemoryCandidateRecord {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var topic: String
    var headline: String
    var value: String
    var confidence: Double
    var priority: Double
    var sourceRaw: String
    var firstObservedAt: Date
    var lastObservedAt: Date
    var decayPolicyRaw: String
    var retrievalTagsBlob: String
    var evidenceCount: Int
    var confirmationCount: Int
    var lastObservationFingerprint: String
    var statusRaw: String
    var provenanceSummary: String
    var lastWriteOperationRaw: String
    var lastGovernanceDecisionRaw: String
    var governanceReason: String
    var tierRaw: String?
    var temporalProjectionBlob: String?

    init(
        id: String,
        type: DecisionMemoryType,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: DecisionMemorySource,
        firstObservedAt: Date,
        lastObservedAt: Date,
        decayPolicy: DecisionMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        confirmationCount: Int,
        lastObservationFingerprint: String,
        status: DecisionMemoryCandidateStatus,
        provenanceSummary: String,
        lastWriteOperation: DecisionMemoryWriteOperation,
        lastGovernanceDecision: DecisionMemoryGovernanceDecision,
        governanceReason: String,
        tier: DecisionMemoryTier = .warm,
        temporalProjection: DecisionTemporalProjection? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceRaw = source.rawValue
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.decayPolicyRaw = decayPolicy.rawValue
        self.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(retrievalTags)
        self.evidenceCount = evidenceCount
        self.confirmationCount = confirmationCount
        self.lastObservationFingerprint = lastObservationFingerprint
        self.statusRaw = status.rawValue
        self.provenanceSummary = provenanceSummary
        self.lastWriteOperationRaw = lastWriteOperation.rawValue
        self.lastGovernanceDecisionRaw = lastGovernanceDecision.rawValue
        self.governanceReason = governanceReason
        self.tierRaw = tier.rawValue
        self.temporalProjectionBlob = DecisionMemoryRecord.encodeTemporalProjection(temporalProjection)
    }
}

extension DecisionMemoryRecord {
    var type: DecisionMemoryType {
        DecisionMemoryType(rawValue: typeRaw) ?? .semantic
    }

    var source: DecisionMemorySource {
        DecisionMemorySource(
            rawValue: BeforeLegacyMigration.normalizedHostMemorySourceIdentifier(sourceRaw)
        ) ?? .history
    }

    var decayPolicy: DecisionMemoryDecayPolicy {
        DecisionMemoryDecayPolicy(rawValue: decayPolicyRaw) ?? .medium
    }

    var retrievalTags: [String] {
        Self.decodeTags(retrievalTagsBlob)
    }

    var lifecycleState: DecisionMemoryLifecycleState {
        DecisionMemoryLifecycleState(rawValue: lifecycleStateRaw ?? "") ?? .active
    }

    var tier: DecisionMemoryTier {
        DecisionMemoryTier(rawValue: tierRaw ?? "") ?? .warm
    }

    var reviewedAt: Date {
        lastReviewedAt ?? lastConfirmedAt
    }

    var temporalProjection: DecisionTemporalProjection? {
        get { Self.decodeTemporalProjection(temporalProjectionBlob) }
        set { temporalProjectionBlob = Self.encodeTemporalProjection(newValue) }
    }

    static func encodeTags(_ tags: [String]) -> String {
        let payload = Array(Set(tags.map { $0.lowercased() })).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let blob = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return blob
    }

    static func decodeTags(_ blob: String) -> [String] {
        guard let data = blob.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }

    static func encodeTemporalProjection(_ projection: DecisionTemporalProjection?) -> String? {
        guard let projection,
              let data = try? JSONEncoder().encode(projection),
              let blob = String(data: data, encoding: .utf8) else {
            return nil
        }
        return blob
    }

    static func decodeTemporalProjection(_ blob: String?) -> DecisionTemporalProjection? {
        guard let blob,
              let data = blob.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DecisionTemporalProjection.self, from: data)
    }
}

extension DecisionMemoryCandidateRecord {
    var type: DecisionMemoryType {
        DecisionMemoryType(rawValue: typeRaw) ?? .semantic
    }

    var source: DecisionMemorySource {
        DecisionMemorySource(
            rawValue: BeforeLegacyMigration.normalizedHostMemorySourceIdentifier(sourceRaw)
        ) ?? .history
    }

    var decayPolicy: DecisionMemoryDecayPolicy {
        DecisionMemoryDecayPolicy(rawValue: decayPolicyRaw) ?? .medium
    }

    var status: DecisionMemoryCandidateStatus {
        DecisionMemoryCandidateStatus(rawValue: statusRaw) ?? .pending
    }

    var lastWriteOperation: DecisionMemoryWriteOperation {
        DecisionMemoryWriteOperation(rawValue: lastWriteOperationRaw) ?? .noop
    }

    var lastGovernanceDecision: DecisionMemoryGovernanceDecision {
        DecisionMemoryGovernanceDecision(rawValue: lastGovernanceDecisionRaw) ?? .deferred
    }

    var retrievalTags: [String] {
        DecisionMemoryRecord.decodeTags(retrievalTagsBlob)
    }

    var tier: DecisionMemoryTier {
        DecisionMemoryTier(rawValue: tierRaw ?? "") ?? .warm
    }

    var temporalProjection: DecisionTemporalProjection? {
        get { DecisionMemoryRecord.decodeTemporalProjection(temporalProjectionBlob) }
        set { temporalProjectionBlob = DecisionMemoryRecord.encodeTemporalProjection(newValue) }
    }
}

extension DecisionMemoryRecord: BASAppleGovernedMemoryEntity {
    static func basMake(from fields: BASGovernedMemoryStoredFields) -> Self {
        Self(
            id: fields.id,
            type: DecisionMemoryType(basRawValue: fields.typeID),
            topic: fields.topic,
            headline: fields.headline,
            value: fields.value,
            confidence: fields.confidence,
            priority: fields.priority,
            source: DecisionMemorySource(fields.source),
            lastConfirmedAt: fields.lastConfirmedAt,
            decayPolicy: DecisionMemoryDecayPolicy(fields.decayPolicy),
            retrievalTags: fields.retrievalTags,
            evidenceCount: fields.evidenceCount,
            observationCount: fields.observationCount,
            provenanceSummary: fields.provenanceSummary,
            lifecycleState: DecisionMemoryLifecycleState(fields.lifecycleState),
            lastReviewedAt: fields.lastReviewedAt,
            tier: DecisionMemoryTier(basRawValue: fields.tierID)
        )
    }

    var basID: String { id }
    var basTypeID: String {
        get { typeRaw }
        set { typeRaw = newValue }
    }
    var basTopic: String {
        get { topic }
        set { topic = newValue }
    }
    var basHeadline: String {
        get { headline }
        set { headline = newValue }
    }
    var basValue: String {
        get { value }
        set { value = newValue }
    }
    var basConfidence: Double {
        get { confidence }
        set { confidence = newValue }
    }
    var basPriority: Double {
        get { priority }
        set { priority = newValue }
    }
    var basSource: BASMemorySource {
        get { source.basSource }
        set { sourceRaw = DecisionMemorySource(newValue).rawValue }
    }
    var basLastConfirmedAt: Date {
        get { lastConfirmedAt }
        set { lastConfirmedAt = newValue }
    }
    var basDecayPolicy: BASMemoryDecayPolicy {
        get { decayPolicy.basDecayPolicy }
        set { decayPolicyRaw = DecisionMemoryDecayPolicy(newValue).rawValue }
    }
    var basRetrievalTags: [String] {
        get { retrievalTags }
        set { retrievalTagsBlob = Self.encodeTags(newValue) }
    }
    var basEvidenceCount: Int {
        get { evidenceCount }
        set { evidenceCount = newValue }
    }
    var basObservationCount: Int {
        get { observationCount }
        set { observationCount = newValue }
    }
    var basProvenanceSummary: String {
        get { provenanceSummary }
        set { provenanceSummary = newValue }
    }
    var basLifecycleState: BASMemoryLifecycleState {
        get { BASMemoryLifecycleState(rawValue: lifecycleState.rawValue) ?? .active }
        set { lifecycleStateRaw = DecisionMemoryLifecycleState(newValue).rawValue }
    }
    var basLastReviewedAt: Date {
        get { reviewedAt }
        set { lastReviewedAt = newValue }
    }
    var basTierID: String {
        get { tier.rawValue }
        set { tierRaw = newValue }
    }
}

extension DecisionMemoryCandidateRecord: BASAppleCandidateMemoryEntity {
    static func basMake(from fields: BASCandidateMemoryStoredFields) -> Self {
        Self(
            id: fields.id,
            type: DecisionMemoryType(basRawValue: fields.typeID),
            topic: fields.topic,
            headline: fields.headline,
            value: fields.value,
            confidence: fields.confidence,
            priority: fields.priority,
            source: DecisionMemorySource(fields.source),
            firstObservedAt: fields.firstObservedAt,
            lastObservedAt: fields.lastObservedAt,
            decayPolicy: DecisionMemoryDecayPolicy(fields.decayPolicy),
            retrievalTags: fields.retrievalTags,
            evidenceCount: fields.evidenceCount,
            confirmationCount: fields.confirmationCount,
            lastObservationFingerprint: fields.lastObservationFingerprint,
            status: DecisionMemoryCandidateStatus(fields.status),
            provenanceSummary: fields.provenanceSummary,
            lastWriteOperation: DecisionMemoryWriteOperation(fields.lastWriteOperation),
            lastGovernanceDecision: DecisionMemoryGovernanceDecision(fields.lastGovernanceDecision),
            governanceReason: fields.governanceReason,
            tier: DecisionMemoryTier(basRawValue: fields.tierID)
        )
    }

    var basID: String { id }
    var basTypeID: String {
        get { typeRaw }
        set { typeRaw = newValue }
    }
    var basTopic: String {
        get { topic }
        set { topic = newValue }
    }
    var basHeadline: String {
        get { headline }
        set { headline = newValue }
    }
    var basValue: String {
        get { value }
        set { value = newValue }
    }
    var basConfidence: Double {
        get { confidence }
        set { confidence = newValue }
    }
    var basPriority: Double {
        get { priority }
        set { priority = newValue }
    }
    var basSource: BASMemorySource {
        get { source.basSource }
        set { sourceRaw = DecisionMemorySource(newValue).rawValue }
    }
    var basFirstObservedAt: Date {
        get { firstObservedAt }
        set { firstObservedAt = newValue }
    }
    var basLastObservedAt: Date {
        get { lastObservedAt }
        set { lastObservedAt = newValue }
    }
    var basDecayPolicy: BASMemoryDecayPolicy {
        get { decayPolicy.basDecayPolicy }
        set { decayPolicyRaw = DecisionMemoryDecayPolicy(newValue).rawValue }
    }
    var basRetrievalTags: [String] {
        get { retrievalTags }
        set { retrievalTagsBlob = DecisionMemoryRecord.encodeTags(newValue) }
    }
    var basEvidenceCount: Int {
        get { evidenceCount }
        set { evidenceCount = newValue }
    }
    var basConfirmationCount: Int {
        get { confirmationCount }
        set { confirmationCount = newValue }
    }
    var basLastObservationFingerprint: String {
        get { lastObservationFingerprint }
        set { lastObservationFingerprint = newValue }
    }
    var basStatus: BASMemoryCandidateStatus {
        get { BASMemoryCandidateStatus(rawValue: status.rawValue) ?? .pending }
        set { statusRaw = DecisionMemoryCandidateStatus(newValue).rawValue }
    }
    var basProvenanceSummary: String {
        get { provenanceSummary }
        set { provenanceSummary = newValue }
    }
    var basLastWriteOperation: BASMemoryWriteOperation {
        get { BASMemoryWriteOperation(rawValue: lastWriteOperation.rawValue) ?? .noop }
        set { lastWriteOperationRaw = DecisionMemoryWriteOperation(newValue).rawValue }
    }
    var basLastGovernanceDecision: BASMemoryGovernanceDecision {
        get { BASMemoryGovernanceDecision(rawValue: lastGovernanceDecision.rawValue) ?? .deferred }
        set { lastGovernanceDecisionRaw = DecisionMemoryGovernanceDecision(newValue).rawValue }
    }
    var basGovernanceReason: String {
        get { governanceReason }
        set { governanceReason = newValue }
    }
    var basTierID: String {
        get { tier.rawValue }
        set { tierRaw = newValue }
    }
}
