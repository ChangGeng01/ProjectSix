import Foundation
import SwiftData

public enum BASAppleMemoryProjectionSelectionAdapter {
    public static func governanceSnapshot<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        in context: ModelContext,
        recordType: Governed.Type,
        candidateType: Candidate.Type
    ) -> BASAppleProjectionGovernanceSnapshot {
        governanceSnapshot(
            records: (try? context.fetch(FetchDescriptor<Governed>())) ?? [],
            candidates: (try? context.fetch(FetchDescriptor<Candidate>())) ?? []
        )
    }

    public static func governanceSnapshot<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        records: [Governed],
        candidates: [Candidate]
    ) -> BASAppleProjectionGovernanceSnapshot {
        BASAppleProjectionGovernanceSnapshot(
            totalRecordCount: records.count,
            totalCandidateCount: candidates.count,
            pendingCandidateCount: candidates.filter { $0.basStatus == .pending }.count,
            promotedCandidateCount: candidates.filter { $0.basStatus == .promoted }.count,
            deferredCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .deferred }.count,
            admittedCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .admit }.count
        )
    }

    public static func fetchProjectionRecords<Governed: BASAppleGovernedMemoryEntity>(
        in context: ModelContext,
        recordType: Governed.Type,
        limit: Int? = nil
    ) -> [Governed] {
        let records = (try? context.fetch(FetchDescriptor<Governed>())) ?? []
        let ordered = records.sorted { lhs, rhs in
            if lhs.basPriority == rhs.basPriority {
                if lhs.basLastConfirmedAt == rhs.basLastConfirmedAt {
                    return lhs.basID < rhs.basID
                }
                return lhs.basLastConfirmedAt > rhs.basLastConfirmedAt
            }
            return lhs.basPriority > rhs.basPriority
        }
        guard let limit else { return ordered }
        return Array(ordered.prefix(limit))
    }

    public static func fetchPendingProjectionCandidates<Candidate: BASAppleCandidateMemoryEntity>(
        in context: ModelContext,
        candidateType: Candidate.Type,
        limit: Int? = nil
    ) -> [Candidate] {
        let candidates = ((try? context.fetch(FetchDescriptor<Candidate>())) ?? [])
            .filter { $0.basStatus == .pending }
            .sorted { lhs, rhs in
                if lhs.basPriority == rhs.basPriority {
                    if lhs.basLastObservedAt == rhs.basLastObservedAt {
                        return lhs.basID < rhs.basID
                    }
                    return lhs.basLastObservedAt > rhs.basLastObservedAt
                }
                return lhs.basPriority > rhs.basPriority
            }
        guard let limit else { return candidates }
        return Array(candidates.prefix(limit))
    }

    public static func fetchProjectionTemporalEntries<Entry: PersistentModel>(
        in context: ModelContext,
        entryType: Entry.Type,
        limit: Int? = nil,
        timestamp: (Entry) -> Date,
        stableID: (Entry) -> String = { String(describing: $0.persistentModelID) }
    ) -> [Entry] {
        let entries = ((try? context.fetch(FetchDescriptor<Entry>())) ?? [])
            .sorted { lhs, rhs in
                if timestamp(lhs) == timestamp(rhs) {
                    return stableID(lhs) < stableID(rhs)
                }
                return timestamp(lhs) > timestamp(rhs)
            }
        guard let limit else { return entries }
        return Array(entries.prefix(limit))
    }

    public static func fetchProjectionCheckEvents<Event: BASAppleCheckEventMemoryEntity>(
        in context: ModelContext,
        eventType: Event.Type,
        limit: Int? = nil
    ) -> [Event] {
        fetchProjectionTemporalEntries(
            in: context,
            entryType: eventType,
            limit: limit,
            timestamp: { $0.basCheckEventMemoryInput.createdAt },
            stableID: { $0.basCheckEventMemoryInput.id }
        )
    }

    public static func fetchProjectionComparativeRecords<Comparative: BASAppleComparativeMemoryEntity>(
        in context: ModelContext,
        comparativeType: Comparative.Type,
        limit: Int? = nil
    ) -> [Comparative] {
        fetchProjectionTemporalEntries(
            in: context,
            entryType: comparativeType,
            limit: limit,
            timestamp: { $0.basComparativeMemoryInput.updatedAt }
        )
    }

    public static func fetchProjectionReflectiveRecords<Reflective: BASAppleReflectiveMemoryEntity>(
        in context: ModelContext,
        reflectiveType: Reflective.Type,
        limit: Int? = nil
    ) -> [Reflective] {
        fetchProjectionTemporalEntries(
            in: context,
            entryType: reflectiveType,
            limit: limit,
            timestamp: { $0.basReflectiveMemoryInput.updatedAt }
        )
    }

    public static func fetchProjectionBalanceRecords<Balance: BASAppleBalanceMemoryEntity>(
        in context: ModelContext,
        balanceType: Balance.Type,
        limit: Int? = nil
    ) -> [Balance] {
        fetchProjectionComparativeRecords(
            in: context,
            comparativeType: balanceType,
            limit: limit
        )
    }

    public static func fetchProjectionMirrorRecords<Mirror: BASAppleMirrorMemoryEntity>(
        in context: ModelContext,
        mirrorType: Mirror.Type,
        limit: Int? = nil
    ) -> [Mirror] {
        fetchProjectionReflectiveRecords(
            in: context,
            reflectiveType: mirrorType,
            limit: limit
        )
    }
}
