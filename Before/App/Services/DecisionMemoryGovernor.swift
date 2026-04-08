import Foundation
import SwiftData

enum DecisionMemoryGovernor {
    static func reconcile(
        drafts: [DecisionMemoryDraft],
        in context: ModelContext
    ) -> [DecisionMemoryRecord] {
        let existingRecords = fetchRecords(in: context)
        let existingCandidates = fetchCandidates(in: context)

        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        var candidatesByID = Dictionary(uniqueKeysWithValues: existingCandidates.map { ($0.id, $0) })
        var seenDraftIDs = Set<String>()

        for draft in drafts {
            seenDraftIDs.insert(draft.id)

            let fingerprint = draft.fingerprint
            let candidate = candidatesByID[draft.id] ?? makeCandidate(from: draft, fingerprint: fingerprint)
            let isNewCandidate = candidatesByID[draft.id] == nil
            let observedNewFingerprint = candidate.lastObservationFingerprint != fingerprint

            if isNewCandidate {
                context.insert(candidate)
                candidatesByID[draft.id] = candidate
            }

            update(candidate: candidate, from: draft, fingerprint: fingerprint, observedNewFingerprint: observedNewFingerprint)

            let shouldPromote = draft.promotionPolicy.shouldPromote(
                candidate: candidate
            )
            candidate.statusRaw = (shouldPromote ? DecisionMemoryCandidateStatus.promoted : .pending).rawValue

            if shouldPromote, !draft.promotionPolicy.isCandidateOnly {
                if let record = recordsByID[draft.id] {
                    if applyRecordUpdateIfNeeded(record, from: draft, candidate: candidate) {
                        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.update.rawValue
                    } else {
                        candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.noop.rawValue
                    }
                } else {
                    let record = draft.makeRecord(observationCount: candidate.confirmationCount)
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
            context.delete(record)
            if let candidate = candidatesByID[id] {
                candidate.lastWriteOperationRaw = DecisionMemoryWriteOperation.delete.rawValue
            }
            recordsByID[id] = nil
        }

        let candidateIDsToDelete = candidatesByID.keys.filter { !seenDraftIDs.contains($0) }
        for id in candidateIDsToDelete {
            guard let candidate = candidatesByID[id] else { continue }
            context.delete(candidate)
            candidatesByID[id] = nil
        }

        try? context.save()

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
        fingerprint: String
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
            lastWriteOperation: .noop
        )
    }

    private static func update(
        candidate: DecisionMemoryCandidateRecord,
        from draft: DecisionMemoryDraft,
        fingerprint: String,
        observedNewFingerprint: Bool
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
        if observedNewFingerprint {
            candidate.confirmationCount += 1
            candidate.lastObservationFingerprint = fingerprint
        }
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
            originalProvenanceSummary != record.provenanceSummary
    }
}

extension DecisionMemoryDraft {
    enum PromotionPolicy: Sendable {
        case immediate
        case repeated(minConfirmationCount: Int, minEvidenceCount: Int)
        case candidateOnly

        var isCandidateOnly: Bool {
            if case .candidateOnly = self {
                return true
            }
            return false
        }

        func shouldPromote(
            candidate: DecisionMemoryCandidateRecord
        ) -> Bool {
            switch self {
            case .immediate:
                true
            case let .repeated(minConfirmationCount, minEvidenceCount):
                candidate.confirmationCount >= minConfirmationCount ||
                    candidate.evidenceCount >= minEvidenceCount
            case .candidateOnly:
                false
            }
        }
    }
}
