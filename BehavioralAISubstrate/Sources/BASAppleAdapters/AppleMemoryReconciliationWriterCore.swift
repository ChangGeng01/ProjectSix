import Foundation
import SwiftData
import BASMemory

public protocol BASAppleGovernedMemoryEntity: BASAppleGovernedMemoryMutable, PersistentModel {
    static func basMake(from fields: BASGovernedMemoryStoredFields) -> Self
    var basSnapshot: BASExistingGovernedMemorySnapshot { get }
}

public protocol BASAppleCandidateMemoryEntity: BASAppleCandidateMemoryMutable, PersistentModel {
    static func basMake(from fields: BASCandidateMemoryStoredFields) -> Self
    var basSnapshot: BASExistingCandidateMemorySnapshot { get }
}

public struct BASAppleMemoryReconciliationWriteResult<
    Governed: BASAppleGovernedMemoryEntity,
    Candidate: BASAppleCandidateMemoryEntity
> {
    public let orderedRecords: [Governed]
    public let candidates: [Candidate]
    public let outcome: BASAppleMemoryPersistenceOutcome

    public init(
        orderedRecords: [Governed],
        candidates: [Candidate],
        outcome: BASAppleMemoryPersistenceOutcome
    ) {
        self.orderedRecords = orderedRecords
        self.candidates = candidates
        self.outcome = outcome
    }
}

public enum BASAppleMemoryReconciliationWriter {
    public static func reconcile<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        _ request: BASAppleMemoryPersistenceRequest,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryReconciliationWriteResult<Governed, Candidate> {
        let existingRecords = fetchRecords(in: context) as [Governed]
        let existingCandidates = fetchCandidates(in: context) as [Candidate]
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: request.drafts,
                existingRecords: existingRecords.map(\.basSnapshot),
                existingCandidates: existingCandidates.map(\.basSnapshot),
                reviewNow: request.reviewNow
            )
        )

        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.basID, $0) })
        var candidatesByID = Dictionary(uniqueKeysWithValues: existingCandidates.map { ($0.basID, $0) })

        for mutation in outcome.recordMutations {
            apply(mutation, in: context, recordsByID: &recordsByID)
        }

        for mutation in outcome.candidateMutations {
            apply(mutation, in: context, candidatesByID: &candidatesByID)
        }

        do {
            try context.save()
        } catch {
            onSaveError?(error)
        }

        let orderedRecords = canonicalOrder(
            Array(recordsByID.values),
            orderedRecordIDs: outcome.orderedRecordIDs
        )

        return BASAppleMemoryReconciliationWriteResult(
            orderedRecords: orderedRecords,
            candidates: Array(candidatesByID.values),
            outcome: outcome
        )
    }

    private static func fetchRecords<Record: BASAppleGovernedMemoryEntity>(
        in context: ModelContext
    ) -> [Record] {
        (try? context.fetch(FetchDescriptor<Record>())) ?? []
    }

    private static func fetchCandidates<Record: BASAppleCandidateMemoryEntity>(
        in context: ModelContext
    ) -> [Record] {
        (try? context.fetch(FetchDescriptor<Record>())) ?? []
    }

    private static func apply<Record: BASAppleGovernedMemoryEntity>(
        _ mutation: BASAppleGovernedMemoryMutation,
        in context: ModelContext,
        recordsByID: inout [String: Record]
    ) {
        switch mutation.operation {
        case .delete:
            guard let existing = recordsByID[mutation.id] else { return }
            context.delete(existing)
            recordsByID[mutation.id] = nil
        case .add, .update, .noop:
            let record = BASAppleMemoryMutationWriter.apply(
                mutation,
                existing: recordsByID[mutation.id],
                make: Record.basMake(from:)
            )
            if let record {
                if recordsByID[mutation.id] == nil {
                    context.insert(record)
                }
                recordsByID[record.basID] = record
            }
        }
    }

    private static func apply<Record: BASAppleCandidateMemoryEntity>(
        _ mutation: BASAppleCandidateMemoryMutation,
        in context: ModelContext,
        candidatesByID: inout [String: Record]
    ) {
        switch mutation.operation {
        case .delete:
            guard let existing = candidatesByID[mutation.id] else { return }
            context.delete(existing)
            candidatesByID[mutation.id] = nil
        case .add, .update, .noop:
            let candidate = BASAppleMemoryMutationWriter.apply(
                mutation,
                existing: candidatesByID[mutation.id],
                make: Record.basMake(from:)
            )
            if let candidate {
                if candidatesByID[mutation.id] == nil {
                    context.insert(candidate)
                }
                candidatesByID[candidate.basID] = candidate
            }
        }
    }

    private static func canonicalOrder<Record: BASAppleGovernedMemoryEntity>(
        _ records: [Record],
        orderedRecordIDs: [String]
    ) -> [Record] {
        let ordering = Dictionary(
            uniqueKeysWithValues: orderedRecordIDs.enumerated().map { ($0.element, $0.offset) }
        )
        return records.sorted { lhs, rhs in
            let lhsIndex = ordering[lhs.basID] ?? Int.max
            let rhsIndex = ordering[rhs.basID] ?? Int.max
            if lhsIndex == rhsIndex {
                return lhs.basID < rhs.basID
            }
            return lhsIndex < rhsIndex
        }
    }
}
