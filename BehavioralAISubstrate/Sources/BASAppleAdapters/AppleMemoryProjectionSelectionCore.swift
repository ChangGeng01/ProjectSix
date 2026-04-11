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

    public static func fetchProjectionCheckEvents<Event: BASAppleCheckEventMemoryEntity>(
        in context: ModelContext,
        eventType: Event.Type,
        limit: Int? = nil
    ) -> [Event] {
        let events = ((try? context.fetch(FetchDescriptor<Event>())) ?? [])
            .sorted { lhs, rhs in
                if lhs.basCheckEventMemoryInput.createdAt == rhs.basCheckEventMemoryInput.createdAt {
                    return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                }
                return lhs.basCheckEventMemoryInput.createdAt > rhs.basCheckEventMemoryInput.createdAt
            }
        guard let limit else { return events }
        return Array(events.prefix(limit))
    }

    public static func fetchProjectionBalanceRecords<Balance: BASAppleBalanceMemoryEntity>(
        in context: ModelContext,
        balanceType: Balance.Type,
        limit: Int? = nil
    ) -> [Balance] {
        let records = ((try? context.fetch(FetchDescriptor<Balance>())) ?? [])
            .sorted { lhs, rhs in
                if lhs.basBalanceMemoryInput.updatedAt == rhs.basBalanceMemoryInput.updatedAt {
                    return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                }
                return lhs.basBalanceMemoryInput.updatedAt > rhs.basBalanceMemoryInput.updatedAt
            }
        guard let limit else { return records }
        return Array(records.prefix(limit))
    }

    public static func fetchProjectionMirrorRecords<Mirror: BASAppleMirrorMemoryEntity>(
        in context: ModelContext,
        mirrorType: Mirror.Type,
        limit: Int? = nil
    ) -> [Mirror] {
        let records = ((try? context.fetch(FetchDescriptor<Mirror>())) ?? [])
            .sorted { lhs, rhs in
                if lhs.basMirrorMemoryInput.updatedAt == rhs.basMirrorMemoryInput.updatedAt {
                    return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                }
                return lhs.basMirrorMemoryInput.updatedAt > rhs.basMirrorMemoryInput.updatedAt
            }
        guard let limit else { return records }
        return Array(records.prefix(limit))
    }
}
