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

        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        var candidatesByID = Dictionary(uniqueKeysWithValues: existingCandidates.map { ($0.id, $0) })
        var seenDraftIDs = Set<String>()

        for draft in drafts {
            seenDraftIDs.insert(draft.id)

            let fingerprint = draft.fingerprint
            let assessment = assess(draft: draft)

            if assessment.decision == .reject {
                if let record = recordsByID[draft.id] {
                    context.delete(record)
                    recordsByID[draft.id] = nil
                }
                if let candidate = candidatesByID[draft.id] {
                    context.delete(candidate)
                    candidatesByID[draft.id] = nil
                }
                continue
            }

            let candidate = candidatesByID[draft.id] ?? makeCandidate(
                from: draft,
                fingerprint: fingerprint,
                governanceAssessment: assessment
            )
            let isNewCandidate = candidatesByID[draft.id] == nil
            let observedNewFingerprint = candidate.lastObservationFingerprint != fingerprint

            if isNewCandidate {
                context.insert(candidate)
                candidatesByID[draft.id] = candidate
            }

            update(
                candidate: candidate,
                from: draft,
                fingerprint: fingerprint,
                observedNewFingerprint: observedNewFingerprint,
                governanceAssessment: assessment
            )

            let shouldPromote = BASMemoryGovernance.shouldPromote(
                policy: draft.promotionPolicy,
                confirmationCount: candidate.confirmationCount,
                evidenceCount: candidate.evidenceCount
            )
            let effectiveStatus: DecisionMemoryCandidateStatus =
                assessment.decision == .deferred || !shouldPromote ? .pending : .promoted
            candidate.statusRaw = effectiveStatus.rawValue

            if effectiveStatus == .promoted, !draft.promotionPolicy.isCandidateOnly {
                if let record = recordsByID[draft.id] {
                    if applyRecordUpdateIfNeeded(record, from: draft, candidate: candidate) {
                        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.update.rawValue
                    } else {
                        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.noop.rawValue
                    }
                } else {
                    let record = draft.makeRecord(
                        observationCount: candidate.confirmationCount,
                        lifecycleState: .active,
                        lastReviewedAt: reviewNow
                    )
                    context.insert(record)
                    recordsByID[draft.id] = record
                    candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.add.rawValue
                }
            } else {
                if let record = recordsByID[draft.id], draft.promotionPolicy.isCandidateOnly {
                    context.delete(record)
                    recordsByID[draft.id] = nil
                    candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.delete.rawValue
                } else {
                    candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.noop.rawValue
                }
            }
        }

        let recordIDsToDelete = recordsByID.keys.filter { !seenDraftIDs.contains($0) }
        for id in recordIDsToDelete {
            guard let record = recordsByID[id] else { continue }
            transitionLifecycle(for: record, reviewNow: reviewNow)
            if let candidate = candidatesByID[id], record.lifecycleState == .retired {
                candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.delete.rawValue
            }
        }

        let candidateIDsToDelete = candidatesByID.keys.filter { !seenDraftIDs.contains($0) }
        for id in candidateIDsToDelete {
            guard let candidate = candidatesByID[id] else { continue }
            context.delete(candidate)
            candidatesByID[id] = nil
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

    private static func makeCandidate(
        from draft: DecisionMemoryDraft,
        fingerprint: String,
        governanceAssessment: GovernanceAssessment
    ) -> DecisionMemoryCandidateRecord {
        DecisionMemoryCandidateRecord(
            id: draft.id,
            type: draft.type,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            firstObservedAt: draft.lastConfirmedAt,
            lastObservedAt: draft.lastConfirmedAt,
            decayPolicy: draft.decayPolicy,
            retrievalTags: draft.retrievalTags,
            evidenceCount: draft.evidenceCount,
            confirmationCount: 1,
            lastObservationFingerprint: fingerprint,
            status: .pending,
            provenanceSummary: draft.provenanceSummary,
            lastWriteOperation: .noop,
            lastGovernanceDecision: governanceAssessment.decision,
            governanceReason: governanceAssessment.reason,
            tier: draft.tier
        )
    }

    private static func update(
        candidate: DecisionMemoryCandidateRecord,
        from draft: DecisionMemoryDraft,
        fingerprint: String,
        observedNewFingerprint: Bool,
        governanceAssessment: GovernanceAssessment
    ) {
        candidate.typeRaw = draft.type.rawValue
        candidate.topic = draft.topic
        candidate.headline = draft.headline
        candidate.value = draft.value
        candidate.confidence = draft.confidence
        candidate.priority = draft.priority
        candidate.sourceRaw = draft.source.rawValue
        candidate.lastObservedAt = max(candidate.lastObservedAt, draft.lastConfirmedAt)
        candidate.decayPolicyRaw = draft.decayPolicy.rawValue
        candidate.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(draft.retrievalTags)
        candidate.evidenceCount = max(candidate.evidenceCount, draft.evidenceCount)
        candidate.provenanceSummary = draft.provenanceSummary
        candidate.lastGovernanceDecisionRaw = governanceAssessment.decision.rawValue
        candidate.governanceReason = governanceAssessment.reason
        candidate.tierRaw = draft.tier.rawValue
        if observedNewFingerprint {
            candidate.confirmationCount += 1
            candidate.lastObservationFingerprint = fingerprint
        }
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

    private static func applyRecordUpdateIfNeeded(
        _ record: DecisionMemoryRecord,
        from draft: DecisionMemoryDraft,
        candidate: DecisionMemoryCandidateRecord
    ) -> Bool {
        let originalTypeRaw = record.typeRaw
        let originalTopic = record.topic
        let originalHeadline = record.headline
        let originalValue = record.value
        let originalConfidence = record.confidence
        let originalPriority = record.priority
        let originalSourceRaw = record.sourceRaw
        let originalLastConfirmedAt = record.lastConfirmedAt
        let originalDecayPolicyRaw = record.decayPolicyRaw
        let originalRetrievalTagsBlob = record.retrievalTagsBlob
        let originalEvidenceCount = record.evidenceCount
        let originalObservationCount = record.observationCount
        let originalProvenanceSummary = record.provenanceSummary
        let originalTierRaw = record.tierRaw

        record.typeRaw = draft.type.rawValue
        record.topic = draft.topic
        record.headline = draft.headline
        record.value = draft.value
        record.confidence = draft.confidence
        record.priority = draft.priority
        record.sourceRaw = draft.source.rawValue
        record.lastConfirmedAt = draft.lastConfirmedAt
        record.decayPolicyRaw = draft.decayPolicy.rawValue
        record.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(draft.retrievalTags)
        record.evidenceCount = draft.evidenceCount
        record.observationCount = candidate.confirmationCount
        record.provenanceSummary = draft.provenanceSummary
        record.tierRaw = draft.tier.rawValue
        record.lifecycleStateRaw = DecisionMemoryLifecycleState.active.rawValue
        record.lastReviewedAt = max(record.reviewedAt, draft.lastConfirmedAt)

        return originalTypeRaw != record.typeRaw ||
            originalTopic != record.topic ||
            originalHeadline != record.headline ||
            originalValue != record.value ||
            originalConfidence != record.confidence ||
            originalPriority != record.priority ||
            originalSourceRaw != record.sourceRaw ||
            originalLastConfirmedAt != record.lastConfirmedAt ||
            originalDecayPolicyRaw != record.decayPolicyRaw ||
            originalRetrievalTagsBlob != record.retrievalTagsBlob ||
            originalEvidenceCount != record.evidenceCount ||
            originalObservationCount != record.observationCount ||
            originalProvenanceSummary != record.provenanceSummary ||
            originalTierRaw != record.tierRaw
    }

    private static func transitionLifecycle(
        for record: DecisionMemoryRecord,
        reviewNow: Date
    ) {
        let nextState = DecisionMemoryLifecycleState(
            BASMemoryGovernance.nextLifecycleState(
                for: BASMemoryLifecycleReviewInput(
                    source: record.source.basSource,
                    evidenceCount: record.evidenceCount,
                    decayPolicy: record.decayPolicy.basDecayPolicy,
                    provenanceSummary: record.provenanceSummary,
                    lastConfirmedAt: record.lastConfirmedAt,
                    reviewNow: reviewNow
                )
            )
        )
        record.lifecycleStateRaw = nextState.rawValue
        record.lastReviewedAt = reviewNow
    }
}
