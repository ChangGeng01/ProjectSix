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

public protocol BASAppleReminderMemoryEntity: PersistentModel {
    var basReminderMemoryInput: BASSelfReminderMemoryInput { get }
}

public protocol BASAppleCheckEventMemoryEntity: PersistentModel {
    var basCheckEventMemoryInput: BASCheckEventMemoryInput { get }
}

public protocol BASAppleBalanceMemoryEntity: PersistentModel {
    var basBalanceMemoryInput: BASBalanceMemoryInput { get }
}

public protocol BASAppleMirrorMemoryEntity: PersistentModel {
    var basMirrorMemoryInput: BASMirrorMemoryInput { get }
}

public struct BASAppleProjectionGovernanceSnapshot: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var deferredCandidateCount: Int
    public var admittedCandidateCount: Int

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        deferredCandidateCount: Int,
        admittedCandidateCount: Int
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.deferredCandidateCount = deferredCandidateCount
        self.admittedCandidateCount = admittedCandidateCount
    }
}

public enum BASAppleMemoryProjectionAdapter {
    public static func compile(
        _ request: BASBrainProjectionCompileRequest
    ) -> BASBrainProjection {
        BASBrainProjectionCompiler.compile(request)
    }

    public static func compileProjection<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Event: BASAppleProjectionEventSource
    >(
        records: [Governed],
        candidates: [Candidate],
        events: [Event],
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot? = nil
    ) -> BASBrainProjection {
        compile(
            BASBrainProjectionCompileRequest(
                records: records.map { record in
                    let snapshot = record.basSnapshot
                    return BASProjectionGovernedMemoryInput(
                        id: snapshot.id,
                        typeID: snapshot.typeID,
                        headline: snapshot.headline,
                        confidence: snapshot.confidence,
                        sourceID: snapshot.source.rawValue,
                        lastConfirmedAt: snapshot.lastConfirmedAt,
                        lifecycleStateID: snapshot.lifecycleState.rawValue,
                        tierID: snapshot.tierID,
                        provenanceSummary: snapshot.provenanceSummary
                    )
                },
                candidates: candidates.map { candidate in
                    let snapshot = candidate.basSnapshot
                    return BASProjectionCandidateInput(
                        id: snapshot.id,
                        typeID: snapshot.typeID,
                        headline: snapshot.headline,
                        confidence: snapshot.confidence,
                        priority: snapshot.priority,
                        sourceID: snapshot.source.rawValue,
                        retrievalTags: snapshot.retrievalTags,
                        lastObservedAt: snapshot.lastObservedAt,
                        decayPolicyID: snapshot.decayPolicy.rawValue,
                        statusID: snapshot.status.rawValue,
                        governanceDecisionID: snapshot.lastGovernanceDecision.rawValue,
                        evidenceCount: snapshot.evidenceCount,
                        provenanceSummary: snapshot.provenanceSummary
                    )
                },
                events: events.map(\.basProjectionEventInput),
                governanceSnapshot: governanceSnapshot.map {
                    BASProjectionGovernanceInput(
                        totalRecordCount: $0.totalRecordCount,
                        totalCandidateCount: $0.totalCandidateCount,
                        pendingCandidateCount: $0.pendingCandidateCount,
                        promotedCandidateCount: $0.promotedCandidateCount,
                        deferredCandidateCount: $0.deferredCandidateCount,
                        admittedCandidateCount: $0.admittedCandidateCount
                    )
                }
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
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        reminders: [Reminder],
        checkEvents: [Event],
        balanceRecords: [Balance],
        mirrorRecords: [Mirror],
        now: Date,
        behavior: BASMemoryDerivationBehavior = .generic
    ) -> [BASDerivedMemoryDraft] {
        deriveDrafts(
            BASMemoryDerivationRequest(
                reminders: reminders
                    .map(\.basReminderMemoryInput)
                    .sorted { $0.lastUsedAt > $1.lastUsedAt },
                checkEvents: checkEvents
                    .map(\.basCheckEventMemoryInput)
                    .sorted { $0.createdAt > $1.createdAt },
                balanceRecords: balanceRecords
                    .map(\.basBalanceMemoryInput)
                    .sorted { $0.updatedAt > $1.updatedAt },
                mirrorRecords: mirrorRecords
                    .map(\.basMirrorMemoryInput)
                    .sorted { $0.updatedAt > $1.updatedAt },
                now: now,
                behavior: behavior
            )
        )
    }

    public static func deriveDrafts<
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        balanceRecordType: Balance.Type,
        mirrorRecordType: Mirror.Type,
        behavior: BASMemoryDerivationBehavior = .generic
    ) -> [BASDerivedMemoryDraft] {
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let checkEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let balanceRecords = (try? context.fetch(FetchDescriptor<Balance>())) ?? []
        let mirrorRecords = (try? context.fetch(FetchDescriptor<Mirror>())) ?? []

        return deriveDrafts(
            reminders: reminders,
            checkEvents: checkEvents,
            balanceRecords: balanceRecords,
            mirrorRecords: mirrorRecords,
            now: now,
            behavior: behavior
        )
    }
}
