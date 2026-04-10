import Foundation
import SwiftData
import BASMemory

enum DecisionMemoryGovernor {
    struct GovernanceAssessment: Equatable, Sendable {
        let decision: DecisionMemoryGovernanceDecision
        let reason: String
    }

    static func reconcile(
        drafts: [DecisionMemoryDraft],
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

        return fetchRecords(in: context)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.lastConfirmedAt > rhs.lastConfirmedAt
                }
                return lhs.priority > rhs.priority
            }
    }

    private static func fetchRecords(in context: ModelContext) -> [DecisionMemoryRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryRecord>())) ?? []
    }

    private static func fetchCandidates(in context: ModelContext) -> [DecisionMemoryCandidateRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())) ?? []
    }

    static func assess(draft: DecisionMemoryDraft) -> GovernanceAssessment {
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
            if let existing = recordsByID[recordPlan.id] {
                apply(recordSnapshot: snapshot, to: existing)
            } else {
                let record = makeRecord(from: snapshot)
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
            if let existing = candidatesByID[candidatePlan.id] {
                apply(candidateSnapshot: snapshot, to: existing)
            } else {
                let candidate = makeCandidate(from: snapshot)
                context.insert(candidate)
                candidatesByID[candidate.id] = candidate
            }
        }
    }

    private static func makeRecord(
        from snapshot: BASExistingGovernedMemorySnapshot
    ) -> DecisionMemoryRecord {
        DecisionMemoryRecord(
            id: snapshot.id,
            type: DecisionMemoryType(rawValue: snapshot.typeID) ?? .semantic,
            topic: snapshot.topic,
            headline: snapshot.headline,
            value: snapshot.value,
            confidence: snapshot.confidence,
            priority: snapshot.priority,
            source: DecisionMemorySource(rawValue: snapshot.source.rawValue) ?? .history,
            lastConfirmedAt: snapshot.lastConfirmedAt,
            decayPolicy: DecisionMemoryDecayPolicy(rawValue: snapshot.decayPolicy.rawValue) ?? .medium,
            retrievalTags: snapshot.retrievalTags,
            evidenceCount: snapshot.evidenceCount,
            observationCount: snapshot.observationCount,
            provenanceSummary: snapshot.provenanceSummary,
            lifecycleState: DecisionMemoryLifecycleState(snapshot.lifecycleState),
            lastReviewedAt: snapshot.lastReviewedAt,
            tier: DecisionMemoryTier(rawValue: snapshot.tierID) ?? .warm
        )
    }

    private static func apply(
        recordSnapshot: BASExistingGovernedMemorySnapshot,
        to record: DecisionMemoryRecord
    ) {
        record.typeRaw = recordSnapshot.typeID
        record.topic = recordSnapshot.topic
        record.headline = recordSnapshot.headline
        record.value = recordSnapshot.value
        record.confidence = recordSnapshot.confidence
        record.priority = recordSnapshot.priority
        record.sourceRaw = recordSnapshot.source.rawValue
        record.lastConfirmedAt = recordSnapshot.lastConfirmedAt
        record.decayPolicyRaw = recordSnapshot.decayPolicy.rawValue
        record.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(recordSnapshot.retrievalTags)
        record.evidenceCount = recordSnapshot.evidenceCount
        record.observationCount = recordSnapshot.observationCount
        record.provenanceSummary = recordSnapshot.provenanceSummary
        record.lifecycleStateRaw = DecisionMemoryLifecycleState(recordSnapshot.lifecycleState).rawValue
        record.lastReviewedAt = recordSnapshot.lastReviewedAt
        record.tierRaw = recordSnapshot.tierID
    }

    private static func makeCandidate(
        from snapshot: BASExistingCandidateMemorySnapshot
    ) -> DecisionMemoryCandidateRecord {
        DecisionMemoryCandidateRecord(
            id: snapshot.id,
            type: DecisionMemoryType(rawValue: snapshot.typeID) ?? .semantic,
            topic: snapshot.topic,
            headline: snapshot.headline,
            value: snapshot.value,
            confidence: snapshot.confidence,
            priority: snapshot.priority,
            source: DecisionMemorySource(rawValue: snapshot.source.rawValue) ?? .history,
            firstObservedAt: snapshot.firstObservedAt,
            lastObservedAt: snapshot.lastObservedAt,
            decayPolicy: DecisionMemoryDecayPolicy(rawValue: snapshot.decayPolicy.rawValue) ?? .medium,
            retrievalTags: snapshot.retrievalTags,
            evidenceCount: snapshot.evidenceCount,
            confirmationCount: snapshot.confirmationCount,
            lastObservationFingerprint: snapshot.lastObservationFingerprint,
            status: DecisionMemoryCandidateStatus(snapshot.status),
            provenanceSummary: snapshot.provenanceSummary,
            lastWriteOperation: DecisionMemoryWriteOperation(snapshot.lastWriteOperation),
            lastGovernanceDecision: DecisionMemoryGovernanceDecision(snapshot.lastGovernanceDecision),
            governanceReason: snapshot.governanceReason,
            tier: DecisionMemoryTier(rawValue: snapshot.tierID) ?? .warm
        )
    }

    private static func apply(
        candidateSnapshot: BASExistingCandidateMemorySnapshot,
        to candidate: DecisionMemoryCandidateRecord
    ) {
        candidate.typeRaw = candidateSnapshot.typeID
        candidate.topic = candidateSnapshot.topic
        candidate.headline = candidateSnapshot.headline
        candidate.value = candidateSnapshot.value
        candidate.confidence = candidateSnapshot.confidence
        candidate.priority = candidateSnapshot.priority
        candidate.sourceRaw = candidateSnapshot.source.rawValue
        candidate.firstObservedAt = candidateSnapshot.firstObservedAt
        candidate.lastObservedAt = candidateSnapshot.lastObservedAt
        candidate.decayPolicyRaw = candidateSnapshot.decayPolicy.rawValue
        candidate.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(candidateSnapshot.retrievalTags)
        candidate.evidenceCount = candidateSnapshot.evidenceCount
        candidate.confirmationCount = candidateSnapshot.confirmationCount
        candidate.lastObservationFingerprint = candidateSnapshot.lastObservationFingerprint
        candidate.statusRaw = DecisionMemoryCandidateStatus(candidateSnapshot.status).rawValue
        candidate.provenanceSummary = candidateSnapshot.provenanceSummary
        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation(candidateSnapshot.lastWriteOperation).rawValue
        candidate.lastGovernanceDecisionRaw = DecisionMemoryGovernanceDecision(candidateSnapshot.lastGovernanceDecision).rawValue
        candidate.governanceReason = candidateSnapshot.governanceReason
        candidate.tierRaw = candidateSnapshot.tierID
    }
}
