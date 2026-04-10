import Foundation
import SwiftData
import BASMemory

enum DecisionMemoryGovernor {
    struct GovernanceAssessment: Equatable, Sendable {
        let decision: DecisionMemoryGovernanceDecision
        let reason: String
    }

    static func reconcile(
        drafts: [BASDerivedMemoryDraft],
        in context: ModelContext
    ) -> [DecisionMemoryRecord] {
        let reviewNow = drafts.map(\.lastConfirmedAt).max() ?? .now
        let existingRecords = fetchRecords(in: context)
        let existingCandidates = fetchCandidates(in: context)
        let plan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: drafts.map(\.reconciliationDraftInput),
                existingRecords: existingRecords.map(\.basSnapshot),
                existingCandidates: existingCandidates.map(\.basSnapshot),
                reviewNow: reviewNow
            )
        )

        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        var candidatesByID = Dictionary(uniqueKeysWithValues: existingCandidates.map { ($0.id, $0) })

        for recordPlan in plan.recordPlans {
            apply(recordPlan: recordPlan, in: context, recordsByID: &recordsByID)
        }

        for candidatePlan in plan.candidatePlans {
            apply(candidatePlan: candidatePlan, in: context, candidatesByID: &candidatesByID)
        }

        do {
            try context.save()
        } catch {
            PersistenceIssueRecorder.record(
                error: error,
                operation: "reconciling governed memory records"
            )
        }

        let resolvedRecords = fetchRecords(in: context)
        let ordering = Dictionary(
            uniqueKeysWithValues: BASMemoryPersistenceApplier
                .canonicalGovernedOrder(for: resolvedRecords.map(\.basSnapshot))
                .enumerated()
                .map { ($0.element, $0.offset) }
        )

        return resolvedRecords.sorted { lhs, rhs in
            let lhsIndex = ordering[lhs.id] ?? .max
            let rhsIndex = ordering[rhs.id] ?? .max
            if lhsIndex == rhsIndex {
                return lhs.id < rhs.id
            }
            return lhsIndex < rhsIndex
        }
    }

    private static func fetchRecords(in context: ModelContext) -> [DecisionMemoryRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryRecord>())) ?? []
    }

    private static func fetchCandidates(in context: ModelContext) -> [DecisionMemoryCandidateRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())) ?? []
    }

    static func assess(draft: BASDerivedMemoryDraft) -> GovernanceAssessment {
        let substrateAssessment = BASMemoryGovernance.assess(
            draft: draft.governanceDraftInput
        )
        return GovernanceAssessment(
            decision: DecisionMemoryGovernanceDecision(substrateAssessment.decision),
            reason: substrateAssessment.reason
        )
    }

    private static func apply(
        recordPlan: BASGovernedMemoryWritePlan,
        in context: ModelContext,
        recordsByID: inout [String: DecisionMemoryRecord]
    ) {
        switch recordPlan.operation {
        case .delete:
            guard let existing = recordsByID[recordPlan.id] else { return }
            context.delete(existing)
            recordsByID[recordPlan.id] = nil
        case .add, .update, .noop:
            guard let snapshot = recordPlan.snapshot else { return }
            let fields = BASMemoryPersistenceApplier.governedFields(from: snapshot)
            if let existing = recordsByID[recordPlan.id] {
                apply(recordFields: fields, to: existing)
            } else {
                let record = makeRecord(from: fields)
                context.insert(record)
                recordsByID[record.id] = record
            }
        }
    }

    private static func apply(
        candidatePlan: BASCandidateMemoryWritePlan,
        in context: ModelContext,
        candidatesByID: inout [String: DecisionMemoryCandidateRecord]
    ) {
        switch candidatePlan.operation {
        case .delete:
            guard let existing = candidatesByID[candidatePlan.id] else { return }
            context.delete(existing)
            candidatesByID[candidatePlan.id] = nil
        case .add, .update, .noop:
            guard let snapshot = candidatePlan.snapshot else { return }
            let fields = BASMemoryPersistenceApplier.candidateFields(from: snapshot)
            if let existing = candidatesByID[candidatePlan.id] {
                apply(candidateFields: fields, to: existing)
            } else {
                let candidate = makeCandidate(from: fields)
                context.insert(candidate)
                candidatesByID[candidate.id] = candidate
            }
        }
    }

    private static func makeRecord(
        from fields: BASGovernedMemoryStoredFields
    ) -> DecisionMemoryRecord {
        DecisionMemoryRecord(
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

    private static func apply(
        recordFields: BASGovernedMemoryStoredFields,
        to record: DecisionMemoryRecord
    ) {
        record.typeRaw = recordFields.typeID
        record.topic = recordFields.topic
        record.headline = recordFields.headline
        record.value = recordFields.value
        record.confidence = recordFields.confidence
        record.priority = recordFields.priority
        record.sourceRaw = recordFields.source.rawValue
        record.lastConfirmedAt = recordFields.lastConfirmedAt
        record.decayPolicyRaw = recordFields.decayPolicy.rawValue
        record.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(recordFields.retrievalTags)
        record.evidenceCount = recordFields.evidenceCount
        record.observationCount = recordFields.observationCount
        record.provenanceSummary = recordFields.provenanceSummary
        record.lifecycleStateRaw = DecisionMemoryLifecycleState(recordFields.lifecycleState).rawValue
        record.lastReviewedAt = recordFields.lastReviewedAt
        record.tierRaw = recordFields.tierID
    }

    private static func makeCandidate(
        from fields: BASCandidateMemoryStoredFields
    ) -> DecisionMemoryCandidateRecord {
        DecisionMemoryCandidateRecord(
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

    private static func apply(
        candidateFields: BASCandidateMemoryStoredFields,
        to candidate: DecisionMemoryCandidateRecord
    ) {
        candidate.typeRaw = candidateFields.typeID
        candidate.topic = candidateFields.topic
        candidate.headline = candidateFields.headline
        candidate.value = candidateFields.value
        candidate.confidence = candidateFields.confidence
        candidate.priority = candidateFields.priority
        candidate.sourceRaw = candidateFields.source.rawValue
        candidate.firstObservedAt = candidateFields.firstObservedAt
        candidate.lastObservedAt = candidateFields.lastObservedAt
        candidate.decayPolicyRaw = candidateFields.decayPolicy.rawValue
        candidate.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(candidateFields.retrievalTags)
        candidate.evidenceCount = candidateFields.evidenceCount
        candidate.confirmationCount = candidateFields.confirmationCount
        candidate.lastObservationFingerprint = candidateFields.lastObservationFingerprint
        candidate.statusRaw = DecisionMemoryCandidateStatus(candidateFields.status).rawValue
        candidate.provenanceSummary = candidateFields.provenanceSummary
        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation(candidateFields.lastWriteOperation).rawValue
        candidate.lastGovernanceDecisionRaw = DecisionMemoryGovernanceDecision(candidateFields.lastGovernanceDecision).rawValue
        candidate.governanceReason = candidateFields.governanceReason
        candidate.tierRaw = candidateFields.tierID
    }
}
