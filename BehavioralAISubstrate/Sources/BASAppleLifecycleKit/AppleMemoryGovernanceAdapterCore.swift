import Foundation
import SwiftData
import BASMemory

public enum BASAppleMemoryGovernanceAdapter {
    public static func refreshStoredMemories<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date = .now,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted
    ) throws -> BASAppleMemoryReconciliationWriteResult {
        try BASApplePersistenceTransaction.perform(
            selectedBy: context,
            using: BASAppleLivePersistenceIO()
        ) { owned in
            try stage(
                in: owned,
                now: now,
                recordType: recordType,
                candidateType: candidateType,
                cueType: cueType,
                checkEventType: checkEventType,
                comparativeRecordType: comparativeRecordType,
                reflectiveRecordType: reflectiveRecordType,
                behavior: behavior,
                memoryTrustBehavior: memoryTrustBehavior,
                persistencePolicy: persistencePolicy,
                using: BASAppleLivePersistenceIO()
            )
        }
    }

    static func stage<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity,
        IO: BASApplePersistenceIO
    >(
        in context: ModelContext,
        now: Date,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior,
        memoryTrustBehavior: BASMemoryTrustBehavior,
        persistencePolicy: BASMemoryHorizonPersistencePolicy,
        using io: IO
    ) throws -> BASAppleMemoryReconciliationWriteResult {
        let records = try io.fetch(recordType, in: context)
        let candidates = try io.fetch(candidateType, in: context)
        let cues = try io.fetch(cueType, in: context)
        let checkEvents = try io.fetch(checkEventType, in: context)
        let comparativeRecords = try io.fetch(comparativeRecordType, in: context)
        let reflectiveRecords = try io.fetch(reflectiveRecordType, in: context)
        return stage(
            in: context,
            now: now,
            records: records,
            candidates: candidates,
            cues: cues,
            checkEvents: checkEvents,
            comparativeRecords: comparativeRecords,
            reflectiveRecords: reflectiveRecords,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            persistencePolicy: persistencePolicy
        )
    }

    static func stage<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        records: [Governed],
        candidates: [Candidate],
        cues: [Cue],
        checkEvents: [Event],
        comparativeRecords: [Comparative],
        reflectiveRecords: [Reflective],
        behavior: BASMemoryDerivationBehavior,
        memoryTrustBehavior: BASMemoryTrustBehavior,
        persistencePolicy: BASMemoryHorizonPersistencePolicy
    ) -> BASAppleMemoryReconciliationWriteResult {
        let drafts = BASAppleMemoryDraftDerivationAdapter.deriveDrafts(
            cues: cues,
            checkEvents: checkEvents,
            comparativeRecords: comparativeRecords,
            reflectiveRecords: reflectiveRecords,
            now: now,
            behavior: behavior
        )
        .sorted { lhs, rhs in
            lhs.priority == rhs.priority
                ? lhs.lastConfirmedAt > rhs.lastConfirmedAt
                : lhs.priority > rhs.priority
        }
        let reviewNow = drafts.map(\.lastConfirmedAt).max() ?? now
        return BASAppleMemoryReconciliationWriter.stage(
            BASAppleMemoryPersistenceRequest(
                drafts: drafts,
                existingRecords: [],
                existingCandidates: [],
                reviewNow: reviewNow,
                memoryTrustBehavior: memoryTrustBehavior,
                persistencePolicy: persistencePolicy
            ),
            existingRecords: records,
            existingCandidates: candidates,
            in: context
        )
    }

    public static func assess(
        draft: BASDerivedMemoryDraft,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted
    ) -> BASMemoryGovernanceAssessment {
        BASMemoryGovernance.assess(
            draft: draft.governanceDraftInput,
            behavior: memoryTrustBehavior,
            persistencePolicy: persistencePolicy
        )
    }
}
