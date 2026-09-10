import Foundation
import SwiftData
import BASMemory

public enum BASAppleMemoryProjectionSelectionAdapter {
    public static func governanceSnapshot<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        in context: ModelContext,
        recordType: Governed.Type,
        candidateType: Candidate.Type
    ) throws -> BASAppleProjectionGovernanceSnapshot {
        governanceSnapshot(
            records: try context.fetch(FetchDescriptor<Governed>()),
            candidates: try context.fetch(FetchDescriptor<Candidate>())
        )
    }

    public static func governanceSnapshot<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity
    >(
        records: [Governed],
        candidates: [Candidate]
    ) -> BASAppleProjectionGovernanceSnapshot {
        let candidateDescriptors: [BASMemoryHorizonClaimDescriptor] = candidates.map { candidate in
            descriptor(
                retrievalTags: candidate.basRetrievalTags,
                evidenceCount: candidate.basEvidenceCount
            )
        }

        return BASAppleProjectionGovernanceSnapshot(
            totalRecordCount: records.count,
            totalCandidateCount: candidates.count,
            pendingCandidateCount: candidates.filter { $0.basStatus == .pending }.count,
            promotedCandidateCount: candidates.filter { $0.basStatus == .promoted }.count,
            deferredCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .deferred }.count,
            admittedCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .admit }.count,
            externallyRefreshedCandidateCount: candidateDescriptors.filter {
                $0.requiresExternalRefresh
            }.count,
            quarantinedObservationCount: candidateDescriptors.filter {
                $0.contaminationState == BASMemoryHorizonClaimContaminationState.quarantined
            }.count,
            evidenceCaveatedCandidateCount: candidateDescriptors.filter {
                $0.evidenceState == BASMemoryHorizonClaimEvidenceState.caveated
            }.count
        )
    }

    public static func governanceSnapshot(
        records: [BASGovernedMemoryStoredFields],
        candidates: [BASCandidateMemoryStoredFields]
    ) -> BASAppleProjectionGovernanceSnapshot {
        let candidateDescriptors = candidates.map { candidate in
            descriptor(
                retrievalTags: candidate.retrievalTags,
                evidenceCount: candidate.evidenceCount
            )
        }
        return BASAppleProjectionGovernanceSnapshot(
            totalRecordCount: records.count,
            totalCandidateCount: candidates.count,
            pendingCandidateCount: candidates.filter { $0.status == .pending }.count,
            promotedCandidateCount: candidates.filter { $0.status == .promoted }.count,
            deferredCandidateCount: candidates.filter { $0.lastGovernanceDecision == .deferred }.count,
            admittedCandidateCount: candidates.filter { $0.lastGovernanceDecision == .admit }.count,
            externallyRefreshedCandidateCount: candidateDescriptors.filter(\.requiresExternalRefresh).count,
            quarantinedObservationCount: candidateDescriptors.filter {
                $0.contaminationState == .quarantined
            }.count,
            evidenceCaveatedCandidateCount: candidateDescriptors.filter {
                $0.evidenceState == .caveated
            }.count
        )
    }

    public static func fetchProjectionRecords<Governed: BASAppleGovernedMemoryEntity>(
        in context: ModelContext,
        recordType: Governed.Type,
        limit: Int? = nil
    ) throws -> [Governed] {
        let records = try context.fetch(FetchDescriptor<Governed>())
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
    ) throws -> [Candidate] {
        let candidates = try context.fetch(FetchDescriptor<Candidate>())
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
    ) throws -> [Entry] {
        selectProjectionTemporalEntries(
            try context.fetch(FetchDescriptor<Entry>()),
            limit: limit,
            timestamp: timestamp,
            stableID: stableID
        )
    }

    static func selectProjectionTemporalEntries<Entry: PersistentModel>(
        _ entries: [Entry],
        limit: Int? = nil,
        timestamp: (Entry) -> Date,
        stableID: (Entry) -> String = { String(describing: $0.persistentModelID) }
    ) -> [Entry] {
        let ordered = entries.sorted { lhs, rhs in
            if timestamp(lhs) == timestamp(rhs) {
                return stableID(lhs) < stableID(rhs)
            }
            return timestamp(lhs) > timestamp(rhs)
        }
        guard let limit else { return ordered }
        return Array(ordered.prefix(limit))
    }

    public static func fetchProjectionCheckEvents<Event: BASAppleCheckEventMemoryEntity>(
        in context: ModelContext,
        eventType: Event.Type,
        limit: Int? = nil
    ) throws -> [Event] {
        try fetchProjectionTemporalEntries(
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
    ) throws -> [Comparative] {
        try fetchProjectionTemporalEntries(
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
    ) throws -> [Reflective] {
        try fetchProjectionTemporalEntries(
            in: context,
            entryType: reflectiveType,
            limit: limit,
            timestamp: { $0.basReflectiveMemoryInput.updatedAt }
        )
    }

    private static func descriptor(
        retrievalTags: [String],
        evidenceCount: Int
    ) -> BASMemoryHorizonClaimDescriptor {
        let horizonPolicy = BASMemoryHorizonPersistencePolicy.unrestricted
        let normalizedTags = Set(retrievalTags.map { $0.lowercased() })
        let volatileTags = Set(horizonPolicy.volatileClaimRetrievalTags.map { $0.lowercased() })
        let quarantineTags = Set(horizonPolicy.quarantineRetrievalTags.map { $0.lowercased() })
        let evidencePendingTags = Set(horizonPolicy.evidencePendingRetrievalTags.map { $0.lowercased() })

        let requiresExternalRefresh = normalizedTags.isDisjoint(with: volatileTags) == false
        let contaminationState: BASMemoryHorizonClaimContaminationState =
            normalizedTags.isDisjoint(with: quarantineTags)
            ? .isolated
            : .quarantined
        let evidenceState: BASMemoryHorizonClaimEvidenceState =
            normalizedTags.isDisjoint(with: evidencePendingTags)
            ? .durable
            : .caveated
        let stability: BASMemoryHorizonClaimStability =
            requiresExternalRefresh || contaminationState == .quarantined
            ? .volatile
            : .semiStable

        var releaseRequirements: [String] = []
        if requiresExternalRefresh {
            releaseRequirements.append("external refresh completes")
        }
        if contaminationState == .quarantined {
            releaseRequirements.append("the quarantined observation receives non-tool evidence")
        }
        if evidenceState == .caveated {
            let threshold = max(horizonPolicy.minimumDurableEvidenceCount, evidenceCount + 1)
            releaseRequirements.append(
                "at least \(threshold) corroborating evidence signals are available"
            )
        }

        return BASMemoryHorizonClaimDescriptor(
            stabilityTierID: stability == .volatile ? horizonPolicy.volatileTierID : "warm",
            stability: stability,
            requiresExternalRefresh: requiresExternalRefresh,
            contaminationState: contaminationState,
            evidenceState: evidenceState,
            minimumDurableEvidenceCount: evidenceState == .caveated
                ? max(horizonPolicy.minimumDurableEvidenceCount, evidenceCount + 1)
                : 0,
            releaseRequirements: releaseRequirements
        )
    }
}
