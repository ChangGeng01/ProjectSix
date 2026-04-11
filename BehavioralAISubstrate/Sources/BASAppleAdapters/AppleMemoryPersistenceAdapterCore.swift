import Foundation
import BASMemory

public struct BASAppleMemoryPersistenceRequest: Codable, Equatable, Sendable {
    public var drafts: [BASDerivedMemoryDraft]
    public var existingRecords: [BASExistingGovernedMemorySnapshot]
    public var existingCandidates: [BASExistingCandidateMemorySnapshot]
    public var reviewNow: Date
    public var memoryTrustBehavior: BASMemoryTrustBehavior

    public init(
        drafts: [BASDerivedMemoryDraft],
        existingRecords: [BASExistingGovernedMemorySnapshot],
        existingCandidates: [BASExistingCandidateMemorySnapshot],
        reviewNow: Date,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic
    ) {
        self.drafts = drafts
        self.existingRecords = existingRecords
        self.existingCandidates = existingCandidates
        self.reviewNow = reviewNow
        self.memoryTrustBehavior = memoryTrustBehavior
    }
}

public struct BASAppleGovernedMemoryMutation: Codable, Equatable, Sendable {
    public var id: String
    public var operation: BASMemoryWriteOperation
    public var fields: BASGovernedMemoryStoredFields?

    public init(
        id: String,
        operation: BASMemoryWriteOperation,
        fields: BASGovernedMemoryStoredFields?
    ) {
        self.id = id
        self.operation = operation
        self.fields = fields
    }
}

public struct BASAppleCandidateMemoryMutation: Codable, Equatable, Sendable {
    public var id: String
    public var operation: BASMemoryWriteOperation
    public var fields: BASCandidateMemoryStoredFields?

    public init(
        id: String,
        operation: BASMemoryWriteOperation,
        fields: BASCandidateMemoryStoredFields?
    ) {
        self.id = id
        self.operation = operation
        self.fields = fields
    }
}

public struct BASAppleMemoryPersistenceOutcome: Codable, Equatable, Sendable {
    public var recordMutations: [BASAppleGovernedMemoryMutation]
    public var candidateMutations: [BASAppleCandidateMemoryMutation]
    public var orderedRecordIDs: [String]
    public var orderedCandidateIDs: [String]

    public init(
        recordMutations: [BASAppleGovernedMemoryMutation],
        candidateMutations: [BASAppleCandidateMemoryMutation],
        orderedRecordIDs: [String],
        orderedCandidateIDs: [String]
    ) {
        self.recordMutations = recordMutations
        self.candidateMutations = candidateMutations
        self.orderedRecordIDs = orderedRecordIDs
        self.orderedCandidateIDs = orderedCandidateIDs
    }
}

public enum BASAppleMemoryPersistenceAdapter {
    public static func reconcile(
        _ request: BASAppleMemoryPersistenceRequest
    ) -> BASAppleMemoryPersistenceOutcome {
        let plan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: request.drafts.map(\.reconciliationDraftInput),
                existingRecords: request.existingRecords,
                existingCandidates: request.existingCandidates,
                reviewNow: request.reviewNow,
                memoryTrustBehavior: request.memoryTrustBehavior
            )
        )

        let recordMutations = plan.recordPlans.map { recordPlan in
            BASAppleGovernedMemoryMutation(
                id: recordPlan.id,
                operation: recordPlan.operation,
                fields: recordPlan.snapshot.map(BASMemoryPersistenceApplier.governedFields(from:))
            )
        }
        let candidateMutations = plan.candidatePlans.map { candidatePlan in
            BASAppleCandidateMemoryMutation(
                id: candidatePlan.id,
                operation: candidatePlan.operation,
                fields: candidatePlan.snapshot.map(BASMemoryPersistenceApplier.candidateFields(from:))
            )
        }

        let finalRecords = applyRecordPlans(plan.recordPlans, to: request.existingRecords)
        let finalCandidates = applyCandidatePlans(plan.candidatePlans, to: request.existingCandidates)

        return BASAppleMemoryPersistenceOutcome(
            recordMutations: recordMutations,
            candidateMutations: candidateMutations,
            orderedRecordIDs: BASMemoryPersistenceApplier.canonicalGovernedOrder(for: finalRecords),
            orderedCandidateIDs: BASMemoryPersistenceApplier.canonicalCandidateOrder(for: finalCandidates)
        )
    }

    private static func applyRecordPlans(
        _ plans: [BASGovernedMemoryWritePlan],
        to existing: [BASExistingGovernedMemorySnapshot]
    ) -> [BASExistingGovernedMemorySnapshot] {
        var recordsByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for plan in plans {
            switch plan.operation {
            case .delete:
                recordsByID[plan.id] = nil
            case .add, .update, .noop:
                if let snapshot = plan.snapshot {
                    recordsByID[plan.id] = snapshot
                }
            }
        }
        return Array(recordsByID.values)
    }

    private static func applyCandidatePlans(
        _ plans: [BASCandidateMemoryWritePlan],
        to existing: [BASExistingCandidateMemorySnapshot]
    ) -> [BASExistingCandidateMemorySnapshot] {
        var candidatesByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for plan in plans {
            switch plan.operation {
            case .delete:
                candidatesByID[plan.id] = nil
            case .add, .update, .noop:
                if let snapshot = plan.snapshot {
                    candidatesByID[plan.id] = snapshot
                }
            }
        }
        return Array(candidatesByID.values)
    }
}
