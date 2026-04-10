import Foundation

public enum BASMemoryWriteOperation: String, Codable, Sendable {
    case add
    case update
    case delete
    case noop
}

public enum BASMemoryCandidateStatus: String, Codable, Sendable {
    case pending
    case promoted
}

public struct BASExistingGovernedMemorySnapshot: Codable, Equatable, Sendable {
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

public struct BASExistingCandidateMemorySnapshot: Codable, Equatable, Sendable {
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

public struct BASMemoryReconciliationDraftInput: Codable, Equatable, Sendable {
    public var draft: BASMemoryGovernanceDraftInput
    public var fingerprint: String

    public init(
        draft: BASMemoryGovernanceDraftInput,
        fingerprint: String
    ) {
        self.draft = draft
        self.fingerprint = fingerprint
    }
}

public struct BASGovernedMemoryWritePlan: Codable, Equatable, Sendable {
    public var id: String
    public var operation: BASMemoryWriteOperation
    public var snapshot: BASExistingGovernedMemorySnapshot?

    public init(
        id: String,
        operation: BASMemoryWriteOperation,
        snapshot: BASExistingGovernedMemorySnapshot?
    ) {
        self.id = id
        self.operation = operation
        self.snapshot = snapshot
    }
}

public struct BASCandidateMemoryWritePlan: Codable, Equatable, Sendable {
    public var id: String
    public var operation: BASMemoryWriteOperation
    public var snapshot: BASExistingCandidateMemorySnapshot?

    public init(
        id: String,
        operation: BASMemoryWriteOperation,
        snapshot: BASExistingCandidateMemorySnapshot?
    ) {
        self.id = id
        self.operation = operation
        self.snapshot = snapshot
    }
}

public struct BASMemoryReconciliationRequest: Codable, Equatable, Sendable {
    public var drafts: [BASMemoryReconciliationDraftInput]
    public var existingRecords: [BASExistingGovernedMemorySnapshot]
    public var existingCandidates: [BASExistingCandidateMemorySnapshot]
    public var reviewNow: Date

    public init(
        drafts: [BASMemoryReconciliationDraftInput],
        existingRecords: [BASExistingGovernedMemorySnapshot],
        existingCandidates: [BASExistingCandidateMemorySnapshot],
        reviewNow: Date
    ) {
        self.drafts = drafts
        self.existingRecords = existingRecords
        self.existingCandidates = existingCandidates
        self.reviewNow = reviewNow
    }
}

public struct BASMemoryReconciliationPlan: Codable, Equatable, Sendable {
    public var candidatePlans: [BASCandidateMemoryWritePlan]
    public var recordPlans: [BASGovernedMemoryWritePlan]

    public init(
        candidatePlans: [BASCandidateMemoryWritePlan],
        recordPlans: [BASGovernedMemoryWritePlan]
    ) {
        self.candidatePlans = candidatePlans
        self.recordPlans = recordPlans
    }
}

public enum BASMemoryReconciler {
    public static func plan(
        _ request: BASMemoryReconciliationRequest
    ) -> BASMemoryReconciliationPlan {
        var recordsByID = Dictionary(uniqueKeysWithValues: request.existingRecords.map { ($0.id, $0) })
        var candidatesByID = Dictionary(uniqueKeysWithValues: request.existingCandidates.map { ($0.id, $0) })
        var recordPlansByID: [String: BASGovernedMemoryWritePlan] = [:]
        var candidatePlansByID: [String: BASCandidateMemoryWritePlan] = [:]
        var seenDraftIDs = Set<String>()

        for input in request.drafts {
            let draft = input.draft
            seenDraftIDs.insert(draft.id)

            let assessment = BASMemoryGovernance.assess(draft: draft)

            if assessment.decision == .reject {
                if recordsByID[draft.id] != nil {
                    recordPlansByID[draft.id] = BASGovernedMemoryWritePlan(
                        id: draft.id,
                        operation: .delete,
                        snapshot: nil
                    )
                    recordsByID[draft.id] = nil
                }
                if candidatesByID[draft.id] != nil {
                    candidatePlansByID[draft.id] = BASCandidateMemoryWritePlan(
                        id: draft.id,
                        operation: .delete,
                        snapshot: nil
                    )
                    candidatesByID[draft.id] = nil
                }
                continue
            }

            let existingCandidate = candidatesByID[draft.id]
            let candidate = existingCandidate ?? makeCandidate(
                from: draft,
                fingerprint: input.fingerprint,
                governanceAssessment: assessment
            )
            let observedNewFingerprint = candidate.lastObservationFingerprint != input.fingerprint

            let updatedCandidate = updateCandidate(
                candidate,
                from: draft,
                fingerprint: input.fingerprint,
                observedNewFingerprint: observedNewFingerprint,
                governanceAssessment: assessment
            )

            let shouldPromote = BASMemoryGovernance.shouldPromote(
                policy: draft.promotionPolicy,
                confirmationCount: updatedCandidate.confirmationCount,
                evidenceCount: updatedCandidate.evidenceCount
            )
            let effectiveStatus: BASMemoryCandidateStatus =
                assessment.decision == .deferred || !shouldPromote ? .pending : .promoted

            var promotedCandidate = updatedCandidate
            promotedCandidate.status = effectiveStatus

            var recordPlan: BASGovernedMemoryWritePlan?
            let writeOperation: BASMemoryWriteOperation

            if effectiveStatus == .promoted, !draft.promotionPolicy.isCandidateOnly {
                if let existingRecord = recordsByID[draft.id] {
                    let updatedRecord = makeUpdatedRecord(
                        existing: existingRecord,
                        draft: draft,
                        observationCount: promotedCandidate.confirmationCount
                    )
                    let didChange = governedRecordChanged(existing: existingRecord, updated: updatedRecord)
                    writeOperation = didChange ? .update : .noop
                    recordPlan = BASGovernedMemoryWritePlan(
                        id: draft.id,
                        operation: writeOperation,
                        snapshot: updatedRecord
                    )
                    recordsByID[draft.id] = updatedRecord
                } else {
                    let newRecord = makeRecord(
                        from: draft,
                        observationCount: promotedCandidate.confirmationCount,
                        reviewNow: request.reviewNow
                    )
                    writeOperation = .add
                    recordPlan = BASGovernedMemoryWritePlan(
                        id: draft.id,
                        operation: .add,
                        snapshot: newRecord
                    )
                    recordsByID[draft.id] = newRecord
                }
            } else if recordsByID[draft.id] != nil, draft.promotionPolicy.isCandidateOnly {
                writeOperation = .delete
                recordPlan = BASGovernedMemoryWritePlan(
                    id: draft.id,
                    operation: .delete,
                    snapshot: nil
                )
                recordsByID[draft.id] = nil
            } else {
                writeOperation = .noop
            }

            promotedCandidate.lastWriteOperation = writeOperation
            candidatesByID[draft.id] = promotedCandidate
            candidatePlansByID[draft.id] = BASCandidateMemoryWritePlan(
                id: draft.id,
                operation: existingCandidate == nil ? .add : .update,
                snapshot: promotedCandidate
            )
            if let recordPlan {
                recordPlansByID[draft.id] = recordPlan
            }
        }

        for id in recordsByID.keys.filter({ !seenDraftIDs.contains($0) }) {
            guard let record = recordsByID[id] else { continue }
            let nextState = BASMemoryGovernance.nextLifecycleState(
                for: BASMemoryLifecycleReviewInput(
                    source: record.source,
                    evidenceCount: record.evidenceCount,
                    decayPolicy: record.decayPolicy,
                    provenanceSummary: record.provenanceSummary,
                    lastConfirmedAt: record.lastConfirmedAt,
                    reviewNow: request.reviewNow
                )
            )
            let updatedRecord = transitionRecord(
                record,
                lifecycleState: nextState,
                reviewNow: request.reviewNow
            )
            recordPlansByID[id] = BASGovernedMemoryWritePlan(
                id: id,
                operation: .update,
                snapshot: updatedRecord
            )
            recordsByID[id] = updatedRecord
        }

        for id in candidatesByID.keys.filter({ !seenDraftIDs.contains($0) }) {
            candidatePlansByID[id] = BASCandidateMemoryWritePlan(
                id: id,
                operation: .delete,
                snapshot: nil
            )
            candidatesByID[id] = nil
        }

        return BASMemoryReconciliationPlan(
            candidatePlans: candidatePlansByID.values.sorted { $0.id < $1.id },
            recordPlans: recordPlansByID.values.sorted { $0.id < $1.id }
        )
    }

    private static func makeCandidate(
        from draft: BASMemoryGovernanceDraftInput,
        fingerprint: String,
        governanceAssessment: BASMemoryGovernanceAssessment
    ) -> BASExistingCandidateMemorySnapshot {
        let retrievalTags = normalizedTags(draft.retrievalTags)
        return BASExistingCandidateMemorySnapshot(
            id: draft.id,
            typeID: draft.typeID,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            firstObservedAt: draft.lastConfirmedAt,
            lastObservedAt: draft.lastConfirmedAt,
            decayPolicy: draft.decayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: draft.evidenceCount,
            confirmationCount: 1,
            lastObservationFingerprint: fingerprint,
            status: .pending,
            provenanceSummary: draft.provenanceSummary,
            lastWriteOperation: .noop,
            lastGovernanceDecision: governanceAssessment.decision,
            governanceReason: governanceAssessment.reason,
            tierID: draft.tierID
        )
    }

    private static func updateCandidate(
        _ candidate: BASExistingCandidateMemorySnapshot,
        from draft: BASMemoryGovernanceDraftInput,
        fingerprint: String,
        observedNewFingerprint: Bool,
        governanceAssessment: BASMemoryGovernanceAssessment
    ) -> BASExistingCandidateMemorySnapshot {
        let retrievalTags = normalizedTags(draft.retrievalTags)
        return BASExistingCandidateMemorySnapshot(
            id: candidate.id,
            typeID: draft.typeID,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            firstObservedAt: candidate.firstObservedAt,
            lastObservedAt: max(candidate.lastObservedAt, draft.lastConfirmedAt),
            decayPolicy: draft.decayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: max(candidate.evidenceCount, draft.evidenceCount),
            confirmationCount: observedNewFingerprint ? candidate.confirmationCount + 1 : candidate.confirmationCount,
            lastObservationFingerprint: observedNewFingerprint ? fingerprint : candidate.lastObservationFingerprint,
            status: candidate.status,
            provenanceSummary: draft.provenanceSummary,
            lastWriteOperation: candidate.lastWriteOperation,
            lastGovernanceDecision: governanceAssessment.decision,
            governanceReason: governanceAssessment.reason,
            tierID: draft.tierID
        )
    }

    private static func makeRecord(
        from draft: BASMemoryGovernanceDraftInput,
        observationCount: Int,
        reviewNow: Date
    ) -> BASExistingGovernedMemorySnapshot {
        let retrievalTags = normalizedTags(draft.retrievalTags)
        return BASExistingGovernedMemorySnapshot(
            id: draft.id,
            typeID: draft.typeID,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            lastConfirmedAt: draft.lastConfirmedAt,
            decayPolicy: draft.decayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: draft.evidenceCount,
            observationCount: observationCount,
            provenanceSummary: draft.provenanceSummary,
            lifecycleState: .active,
            lastReviewedAt: reviewNow,
            tierID: draft.tierID
        )
    }

    private static func makeUpdatedRecord(
        existing: BASExistingGovernedMemorySnapshot,
        draft: BASMemoryGovernanceDraftInput,
        observationCount: Int
    ) -> BASExistingGovernedMemorySnapshot {
        let retrievalTags = normalizedTags(draft.retrievalTags)
        return BASExistingGovernedMemorySnapshot(
            id: existing.id,
            typeID: draft.typeID,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            lastConfirmedAt: draft.lastConfirmedAt,
            decayPolicy: draft.decayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: draft.evidenceCount,
            observationCount: observationCount,
            provenanceSummary: draft.provenanceSummary,
            lifecycleState: .active,
            lastReviewedAt: max(existing.lastReviewedAt, draft.lastConfirmedAt),
            tierID: draft.tierID
        )
    }

    private static func transitionRecord(
        _ record: BASExistingGovernedMemorySnapshot,
        lifecycleState: BASMemoryLifecycleState,
        reviewNow: Date
    ) -> BASExistingGovernedMemorySnapshot {
        BASExistingGovernedMemorySnapshot(
            id: record.id,
            typeID: record.typeID,
            topic: record.topic,
            headline: record.headline,
            value: record.value,
            confidence: record.confidence,
            priority: record.priority,
            source: record.source,
            lastConfirmedAt: record.lastConfirmedAt,
            decayPolicy: record.decayPolicy,
            retrievalTags: record.retrievalTags,
            evidenceCount: record.evidenceCount,
            observationCount: record.observationCount,
            provenanceSummary: record.provenanceSummary,
            lifecycleState: lifecycleState,
            lastReviewedAt: reviewNow,
            tierID: record.tierID
        )
    }

    private static func governedRecordChanged(
        existing: BASExistingGovernedMemorySnapshot,
        updated: BASExistingGovernedMemorySnapshot
    ) -> Bool {
        existing.typeID != updated.typeID ||
            existing.topic != updated.topic ||
            existing.headline != updated.headline ||
            existing.value != updated.value ||
            existing.confidence != updated.confidence ||
            existing.priority != updated.priority ||
            existing.source != updated.source ||
            existing.lastConfirmedAt != updated.lastConfirmedAt ||
            existing.decayPolicy != updated.decayPolicy ||
            existing.retrievalTags != updated.retrievalTags ||
            existing.evidenceCount != updated.evidenceCount ||
            existing.observationCount != updated.observationCount ||
            existing.provenanceSummary != updated.provenanceSummary ||
            existing.tierID != updated.tierID
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.lowercased() })).sorted()
    }
}
