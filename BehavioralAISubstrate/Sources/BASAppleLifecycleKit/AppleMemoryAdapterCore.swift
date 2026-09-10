import Foundation
import SwiftData
import BASMemory

public struct BASAppleEmbeddingScoreInput: Codable, Equatable, Sendable {
    public var id: String
    public var score: Double

    public init(id: String, score: Double) {
        self.id = id
        self.score = score
    }
}

public protocol BASAppleProjectionEventSource {
    var basProjectionEventInput: BASProjectionEventInput { get }
}

public protocol BASAppleCueMemoryEntity: PersistentModel {
    var basCueMemoryInput: BASCueMemoryInput { get }
}

public protocol BASAppleCheckEventMemoryEntity: PersistentModel {
    var basCheckEventMemoryInput: BASCheckEventMemoryInput { get }
}

public protocol BASAppleWorkspaceMemoryEntity: PersistentModel {
    var basWorkspaceMemoryInput: BASWorkspaceMemoryInput { get }
}

public protocol BASAppleComparativeMemoryEntity: PersistentModel {
    var basComparativeMemoryInput: BASComparativeMemoryInput { get }
}

public protocol BASAppleReflectiveMemoryEntity: PersistentModel {
    var basReflectiveMemoryInput: BASReflectiveMemoryInput { get }
}

public struct BASAppleProjectionGovernanceSnapshot: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var deferredCandidateCount: Int
    public var admittedCandidateCount: Int
    public var externallyRefreshedCandidateCount: Int
    public var quarantinedObservationCount: Int
    public var evidenceCaveatedCandidateCount: Int

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        deferredCandidateCount: Int,
        admittedCandidateCount: Int,
        externallyRefreshedCandidateCount: Int = 0,
        quarantinedObservationCount: Int = 0,
        evidenceCaveatedCandidateCount: Int = 0
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.deferredCandidateCount = deferredCandidateCount
        self.admittedCandidateCount = admittedCandidateCount
        self.externallyRefreshedCandidateCount = externallyRefreshedCandidateCount
        self.quarantinedObservationCount = quarantinedObservationCount
        self.evidenceCaveatedCandidateCount = evidenceCaveatedCandidateCount
    }

    public static let empty = BASAppleProjectionGovernanceSnapshot(
        totalRecordCount: 0,
        totalCandidateCount: 0,
        pendingCandidateCount: 0,
        promotedCandidateCount: 0,
        deferredCandidateCount: 0,
        admittedCandidateCount: 0
    )
}

public enum BASAppleMemoryProjectionAdapter {
    public static func compile(
        _ request: BASBrainProjectionCompileRequest
    ) -> BASBrainProjection {
        BASBrainProjectionCompiler.compile(request)
    }

    public static func compileProjection<
        Governed: Collection,
        Candidate: Collection,
        Event: Collection
    >(
        records: Governed,
        candidates: Candidate,
        events: Event,
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot? = nil,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic
    ) -> BASBrainProjection
    where Governed.Element == BASGovernedMemoryStoredFields,
          Candidate.Element == BASCandidateMemoryStoredFields,
          Event.Element == BASProjectionEventInput {
        compile(
            BASBrainProjectionCompileRequest(
                records: records.map { record in
                    return BASProjectionGovernedMemoryInput(
                        id: record.id,
                        typeID: record.typeID,
                        headline: record.headline,
                        confidence: record.confidence,
                        sourceID: record.source.rawValue,
                        lastConfirmedAt: record.lastConfirmedAt,
                        lifecycleStateID: record.lifecycleState.rawValue,
                        tierID: record.tierID,
                        provenanceSummary: record.provenanceSummary
                    )
                },
                candidates: candidates.map { candidate in
                    return BASProjectionCandidateInput(
                        id: candidate.id,
                        typeID: candidate.typeID,
                        headline: candidate.headline,
                        confidence: candidate.confidence,
                        priority: candidate.priority,
                        sourceID: candidate.source.rawValue,
                        retrievalTags: candidate.retrievalTags,
                        lastObservedAt: candidate.lastObservedAt,
                        decayPolicyID: candidate.decayPolicy.rawValue,
                        statusID: candidate.status.rawValue,
                        governanceDecisionID: candidate.lastGovernanceDecision.rawValue,
                        evidenceCount: candidate.evidenceCount,
                        provenanceSummary: candidate.provenanceSummary
                    )
                },
                events: Array(events),
                governanceSnapshot: governanceSnapshot.map {
                    BASProjectionGovernanceInput(
                        totalRecordCount: $0.totalRecordCount,
                        totalCandidateCount: $0.totalCandidateCount,
                        pendingCandidateCount: $0.pendingCandidateCount,
                        promotedCandidateCount: $0.promotedCandidateCount,
                        deferredCandidateCount: $0.deferredCandidateCount,
                        admittedCandidateCount: $0.admittedCandidateCount,
                        externallyRefreshedCandidateCount: $0.externallyRefreshedCandidateCount,
                        quarantinedObservationCount: $0.quarantinedObservationCount,
                        evidenceCaveatedCandidateCount: $0.evidenceCaveatedCandidateCount
                    )
                },
                memoryTrustBehavior: memoryTrustBehavior
            )
        )
    }

    public static func overlayEmbeddingScores(
        _ matches: [BASAppleEmbeddingScoreInput],
        on projection: BASBrainProjection
    ) -> BASBrainProjection {
        var updated = projection
        updated.embeddingScoresByID = Dictionary(
            matches.map { ($0.id, $0.score) },
            uniquingKeysWith: max
        )
        return updated
    }
}

public enum BASAppleMemoryDraftDerivationAdapter {
    public static func deriveDrafts(
        _ request: BASMemoryDerivationRequest
    ) -> [BASDerivedMemoryDraft] {
        BASMemoryDraftCompiler.derive(request)
    }

    public static func deriveDrafts<
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Workspace: BASAppleWorkspaceMemoryEntity
    >(
        cues: [Cue],
        checkEvents: [Event],
        workspaceRecords: [Workspace],
        now: Date,
        behavior: BASMemoryDerivationBehavior = .generic
    ) -> [BASDerivedMemoryDraft] {
        deriveDrafts(
            BASMemoryDerivationRequest(
                cues: cues
                    .map(\.basCueMemoryInput)
                    .sorted { $0.lastUsedAt > $1.lastUsedAt },
                checkEvents: checkEvents
                    .map(\.basCheckEventMemoryInput)
                    .sorted { $0.createdAt > $1.createdAt },
                workspaceRecords: workspaceRecords
                    .map(\.basWorkspaceMemoryInput)
                    .sorted { $0.updatedAt > $1.updatedAt },
                now: now,
                behavior: behavior
            )
        )
    }

    public static func deriveDrafts<
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        cues: [Cue],
        checkEvents: [Event],
        comparativeRecords: [Comparative],
        reflectiveRecords: [Reflective],
        now: Date,
        behavior: BASMemoryDerivationBehavior = .generic
    ) -> [BASDerivedMemoryDraft] {
        deriveDrafts(
            BASMemoryDerivationRequest(
                cues: cues
                    .map(\.basCueMemoryInput)
                    .sorted { $0.lastUsedAt > $1.lastUsedAt },
                checkEvents: checkEvents
                    .map(\.basCheckEventMemoryInput)
                    .sorted { $0.createdAt > $1.createdAt },
                workspaceRecords: (
                    comparativeRecords.map(\.basComparativeMemoryInput.workspaceInput) +
                    reflectiveRecords.map(\.basReflectiveMemoryInput.workspaceInput)
                )
                .sorted { $0.updatedAt > $1.updatedAt },
                now: now,
                behavior: behavior
            )
        )
    }

    public static func deriveDrafts<
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic
    ) throws -> [BASDerivedMemoryDraft] {
        let cues = try context.fetch(FetchDescriptor<Cue>())
        let checkEvents = try context.fetch(FetchDescriptor<Event>())
        let comparativeRecords = try context.fetch(FetchDescriptor<Comparative>())
        let reflectiveRecords = try context.fetch(FetchDescriptor<Reflective>())

        return deriveDrafts(
            cues: cues,
            checkEvents: checkEvents,
            comparativeRecords: comparativeRecords,
            reflectiveRecords: reflectiveRecords,
            now: now,
            behavior: behavior
        )
    }

}
