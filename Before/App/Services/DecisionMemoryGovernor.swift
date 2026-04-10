import Foundation
import SwiftData
import BASAppleAdapters
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
        let result: BASAppleMemoryReconciliationWriteResult<
            DecisionMemoryRecord,
            DecisionMemoryCandidateRecord
        > = BASAppleMemoryReconciliationWriter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: drafts,
                existingRecords: [],
                existingCandidates: [],
                reviewNow: reviewNow
            ),
            in: context,
            onSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "reconciling governed memory records"
                )
            }
        )
        return result.orderedRecords
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
}
