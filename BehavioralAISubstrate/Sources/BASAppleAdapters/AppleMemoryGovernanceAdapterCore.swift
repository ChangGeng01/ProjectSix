import Foundation
import SwiftData
import BASMemory

public enum BASAppleMemoryGovernanceAdapter {
    public static func refreshStoredMemories<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        in context: ModelContext,
        now: Date = .now,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        balanceRecordType: Balance.Type,
        mirrorRecordType: Mirror.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryReconciliationWriteResult<Governed, Candidate> {
        let drafts = BASAppleMemoryDraftDerivationAdapter.deriveDrafts(
            in: context,
            now: now,
            reminderType: reminderType,
            checkEventType: checkEventType,
            balanceRecordType: balanceRecordType,
            mirrorRecordType: mirrorRecordType,
            behavior: behavior
        )
        .sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.lastConfirmedAt > rhs.lastConfirmedAt
            }
            return lhs.priority > rhs.priority
        }

        let reviewNow = drafts.map(\.lastConfirmedAt).max() ?? now
        return BASAppleMemoryReconciliationWriter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: drafts,
                existingRecords: [],
                existingCandidates: [],
                reviewNow: reviewNow
            ),
            in: context,
            onSaveError: onSaveError
        )
    }

    public static func assess(
        draft: BASDerivedMemoryDraft
    ) -> BASMemoryGovernanceAssessment {
        BASMemoryGovernance.assess(draft: draft.governanceDraftInput)
    }
}
