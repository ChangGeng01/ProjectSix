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

public struct BASAppleMemoryReconciliationWriteResult: Sendable {
    public let orderedRecords: [BASGovernedMemoryStoredFields]
    public let candidates: [BASCandidateMemoryStoredFields]
    public let outcome: BASAppleMemoryPersistenceOutcome

    public init(
        orderedRecords: [BASGovernedMemoryStoredFields],
        candidates: [BASCandidateMemoryStoredFields],
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
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        in context: ModelContext
    ) throws -> BASAppleMemoryReconciliationWriteResult {
        try reconcile(
            request,
            recordType: recordType,
            candidateType: candidateType,
            in: context,
            using: BASAppleLivePersistenceIO()
        )
    }

    static func reconcile<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        IO: BASApplePersistenceIO
    >(
        _ request: BASAppleMemoryPersistenceRequest,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleMemoryReconciliationWriteResult {
        try BASApplePersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            try stage(
                request,
                recordType: recordType,
                candidateType: candidateType,
                in: owned,
                using: io
            )
        }
    }

    static func stage<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        IO: BASApplePersistenceIO
    >(
        _ request: BASAppleMemoryPersistenceRequest,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleMemoryReconciliationWriteResult {
        let existingRecords = try io.fetch(recordType, in: context)
        let existingCandidates = try io.fetch(candidateType, in: context)
        return stage(
            request,
            existingRecords: existingRecords,
            existingCandidates: existingCandidates,
            in: context
        )
    }

    static func stage<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        _ request: BASAppleMemoryPersistenceRequest,
        existingRecords: [Governed],
        existingCandidates: [Candidate],
        in context: ModelContext
    ) -> BASAppleMemoryReconciliationWriteResult {
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: request.drafts,
                existingRecords: existingRecords.map(\.basSnapshot),
                existingCandidates: existingCandidates.map(\.basSnapshot),
                reviewNow: request.reviewNow,
                memoryTrustBehavior: request.memoryTrustBehavior,
                persistencePolicy: request.persistencePolicy
            )
        )

        var recordsByID = Dictionary(
            existingRecords.map { ($0.basID, $0) },
            uniquingKeysWith: { _, last in last }
        )
        var candidatesByID = Dictionary(
            existingCandidates.map { ($0.basID, $0) },
            uniquingKeysWith: { _, last in last }
        )

        for mutation in outcome.recordMutations {
            apply(mutation, in: context, recordsByID: &recordsByID)
        }
        for mutation in outcome.candidateMutations {
            apply(mutation, in: context, candidatesByID: &candidatesByID)
        }

        return makeReceipt(
            outcome: outcome,
            records: Array(recordsByID.values),
            candidates: Array(candidatesByID.values)
        )
    }

    static func makeReceipt<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        outcome: BASAppleMemoryPersistenceOutcome,
        records: [Governed],
        candidates: [Candidate]
    ) -> BASAppleMemoryReconciliationWriteResult {
        let orderedRecords = canonicalOrder(
            records,
            orderedIDs: outcome.orderedRecordIDs,
            id: \.basID
        ).map { BASGovernedMemoryStoredFields(snapshot: $0.basSnapshot) }
        let orderedCandidates = canonicalOrder(
            candidates,
            orderedIDs: outcome.orderedCandidateIDs,
            id: \.basID
        ).map { BASCandidateMemoryStoredFields(snapshot: $0.basSnapshot) }

        return BASAppleMemoryReconciliationWriteResult(
            orderedRecords: orderedRecords,
            candidates: orderedCandidates,
            outcome: outcome
        )
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

    private static func canonicalOrder<Record: PersistentModel>(
        _ records: [Record],
        orderedIDs: [String],
        id: (Record) -> String
    ) -> [Record] {
        let ordering = Dictionary(
            orderedIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        return records.sorted { lhs, rhs in
            let lhsID = id(lhs)
            let rhsID = id(rhs)
            let lhsIndex = ordering[lhsID] ?? Int.max
            let rhsIndex = ordering[rhsID] ?? Int.max
            return lhsIndex == rhsIndex ? lhsID < rhsID : lhsIndex < rhsIndex
        }
    }
}
