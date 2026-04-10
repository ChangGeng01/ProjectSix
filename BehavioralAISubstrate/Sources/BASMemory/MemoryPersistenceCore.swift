import Foundation

public struct BASGovernedMemoryStoredFields: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var topic: String
    public var headline: String
    public var value: String
    public var confidence: Double
    public var priority: Double
    public var source: BASMemorySource
    public var lastConfirmedAt: Date
    public var decayPolicy: BASMemoryDecayPolicy
    public var retrievalTags: [String]
    public var evidenceCount: Int
    public var observationCount: Int
    public var provenanceSummary: String
    public var lifecycleState: BASMemoryLifecycleState
    public var lastReviewedAt: Date
    public var tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: BASMemorySource,
        lastConfirmedAt: Date,
        decayPolicy: BASMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        observationCount: Int,
        provenanceSummary: String,
        lifecycleState: BASMemoryLifecycleState,
        lastReviewedAt: Date,
        tierID: String
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.source = source
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicy = decayPolicy
        self.retrievalTags = retrievalTags
        self.evidenceCount = evidenceCount
        self.observationCount = observationCount
        self.provenanceSummary = provenanceSummary
        self.lifecycleState = lifecycleState
        self.lastReviewedAt = lastReviewedAt
        self.tierID = tierID
    }
}

public struct BASCandidateMemoryStoredFields: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var topic: String
    public var headline: String
    public var value: String
    public var confidence: Double
    public var priority: Double
    public var source: BASMemorySource
    public var firstObservedAt: Date
    public var lastObservedAt: Date
    public var decayPolicy: BASMemoryDecayPolicy
    public var retrievalTags: [String]
    public var evidenceCount: Int
    public var confirmationCount: Int
    public var lastObservationFingerprint: String
    public var status: BASMemoryCandidateStatus
    public var provenanceSummary: String
    public var lastWriteOperation: BASMemoryWriteOperation
    public var lastGovernanceDecision: BASMemoryGovernanceDecision
    public var governanceReason: String
    public var tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: BASMemorySource,
        firstObservedAt: Date,
        lastObservedAt: Date,
        decayPolicy: BASMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        confirmationCount: Int,
        lastObservationFingerprint: String,
        status: BASMemoryCandidateStatus,
        provenanceSummary: String,
        lastWriteOperation: BASMemoryWriteOperation,
        lastGovernanceDecision: BASMemoryGovernanceDecision,
        governanceReason: String,
        tierID: String
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.source = source
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.decayPolicy = decayPolicy
        self.retrievalTags = retrievalTags
        self.evidenceCount = evidenceCount
        self.confirmationCount = confirmationCount
        self.lastObservationFingerprint = lastObservationFingerprint
        self.status = status
        self.provenanceSummary = provenanceSummary
        self.lastWriteOperation = lastWriteOperation
        self.lastGovernanceDecision = lastGovernanceDecision
        self.governanceReason = governanceReason
        self.tierID = tierID
    }
}

public enum BASMemoryPersistenceApplier {
    public static func governedFields(
        from snapshot: BASExistingGovernedMemorySnapshot
    ) -> BASGovernedMemoryStoredFields {
        BASGovernedMemoryStoredFields(
            id: snapshot.id,
            typeID: snapshot.typeID,
            topic: snapshot.topic,
            headline: snapshot.headline,
            value: snapshot.value,
            confidence: snapshot.confidence,
            priority: snapshot.priority,
            source: snapshot.source,
            lastConfirmedAt: snapshot.lastConfirmedAt,
            decayPolicy: snapshot.decayPolicy,
            retrievalTags: canonicalTags(snapshot.retrievalTags),
            evidenceCount: snapshot.evidenceCount,
            observationCount: snapshot.observationCount,
            provenanceSummary: snapshot.provenanceSummary,
            lifecycleState: snapshot.lifecycleState,
            lastReviewedAt: snapshot.lastReviewedAt,
            tierID: snapshot.tierID
        )
    }

    public static func candidateFields(
        from snapshot: BASExistingCandidateMemorySnapshot
    ) -> BASCandidateMemoryStoredFields {
        BASCandidateMemoryStoredFields(
            id: snapshot.id,
            typeID: snapshot.typeID,
            topic: snapshot.topic,
            headline: snapshot.headline,
            value: snapshot.value,
            confidence: snapshot.confidence,
            priority: snapshot.priority,
            source: snapshot.source,
            firstObservedAt: snapshot.firstObservedAt,
            lastObservedAt: snapshot.lastObservedAt,
            decayPolicy: snapshot.decayPolicy,
            retrievalTags: canonicalTags(snapshot.retrievalTags),
            evidenceCount: snapshot.evidenceCount,
            confirmationCount: snapshot.confirmationCount,
            lastObservationFingerprint: snapshot.lastObservationFingerprint,
            status: snapshot.status,
            provenanceSummary: snapshot.provenanceSummary,
            lastWriteOperation: snapshot.lastWriteOperation,
            lastGovernanceDecision: snapshot.lastGovernanceDecision,
            governanceReason: snapshot.governanceReason,
            tierID: snapshot.tierID
        )
    }

    public static func canonicalGovernedOrder(
        for snapshots: [BASExistingGovernedMemorySnapshot]
    ) -> [String] {
        snapshots
            .map(governedFields(from:))
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    if lhs.lastConfirmedAt == rhs.lastConfirmedAt {
                        return lhs.id < rhs.id
                    }
                    return lhs.lastConfirmedAt > rhs.lastConfirmedAt
                }
                return lhs.priority > rhs.priority
            }
            .map(\.id)
    }

    public static func canonicalCandidateOrder(
        for snapshots: [BASExistingCandidateMemorySnapshot]
    ) -> [String] {
        snapshots
            .map(candidateFields(from:))
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    if lhs.lastObservedAt == rhs.lastObservedAt {
                        return lhs.id < rhs.id
                    }
                    return lhs.lastObservedAt > rhs.lastObservedAt
                }
                return lhs.priority > rhs.priority
            }
            .map(\.id)
    }

    private static func canonicalTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.lowercased() })).sorted()
    }
}
