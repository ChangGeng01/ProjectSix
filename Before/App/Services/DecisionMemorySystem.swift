import Foundation
import SwiftData
import BASAppleAdapters
import BASMemory

enum DecisionMemorySystem {
    static let projectionRecordLimit = BASAppleMemoryProjectionRefreshLimits.default.recordLimit
    static let projectionCandidateLimit = BASAppleMemoryProjectionRefreshLimits.default.candidateLimit
    static let projectionCheckEventLimit = BASAppleMemoryProjectionRefreshLimits.default.checkEventLimit

    struct BrainStateGovernanceSnapshot {
        let totalRecordCount: Int
        let totalCandidateCount: Int
        let pendingCandidateCount: Int
        let promotedCandidateCount: Int
        let deferredCandidateCount: Int
        let admittedCandidateCount: Int
    }

    struct BrainStateProjection {
        struct Diagnostics {
            let recordCount: Int
            let candidateCount: Int
            let allCandidatesPending: Bool
        }

        let baseProjection: BASBrainProjection
        let governanceSnapshot: BrainStateGovernanceSnapshot
        let diagnostics: Diagnostics
        let refreshedAt: Date
    }

    static func refreshStoredMemories(
        in context: ModelContext,
        now: Date = .now
    ) -> [DecisionMemoryRecord] {
        let result: BASAppleMemoryReconciliationWriteResult<
            DecisionMemoryRecord,
            DecisionMemoryCandidateRecord
        > = BASAppleMemoryGovernanceAdapter.refreshStoredMemories(
            in: context,
            now: now,
            reminderType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            balanceRecordType: BalanceDecisionRecord.self,
            mirrorRecordType: MirrorDecisionRecord.self,
            onSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "reconciling governed memory records"
                )
            }
        )
        return result.orderedRecords
    }

    static func refreshProjection(
        in context: ModelContext,
        now: Date = .now
    ) -> BrainStateProjection {
        let refreshed = BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            governanceSnapshot: substrateGovernanceSnapshot(
                from: fetchGovernanceSnapshot(in: context)
            ),
            refreshGovernanceSnapshot: { substrateGovernanceSnapshot(from: fetchGovernanceSnapshot(in: $0)) },
            reminderType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            balanceRecordType: BalanceDecisionRecord.self,
            mirrorRecordType: MirrorDecisionRecord.self,
            fetchRecords: { fetchMemoryRecords(in: $0, limit: $1) },
            fetchCandidates: { fetchCandidateRecords(in: $0, limit: $1) },
            fetchCheckEvents: { fetchCheckEvents(in: $0, limit: $1) },
            fetchBalanceRecords: { fetchBalanceRecords(in: $0, limit: $1) },
            fetchMirrorRecords: { fetchMirrorRecords(in: $0, limit: $1) },
            rebuildEmbeddings: { records, candidates, checkEvents, balanceRecords, mirrorRecords in
                EmbeddingMemoryStore.rebuildIndex(
                    records: records,
                    candidates: candidates,
                    checkEvents: checkEvents,
                    balance: balanceRecords,
                    mirror: mirrorRecords
                )
            },
            onSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "reconciling governed memory records"
                )
            }
        )

        return BrainStateProjection(
            baseProjection: refreshed.baseProjection,
            governanceSnapshot: BrainStateGovernanceSnapshot(
                totalRecordCount: refreshed.governanceSnapshot.totalRecordCount,
                totalCandidateCount: refreshed.governanceSnapshot.totalCandidateCount,
                pendingCandidateCount: refreshed.governanceSnapshot.pendingCandidateCount,
                promotedCandidateCount: refreshed.governanceSnapshot.promotedCandidateCount,
                deferredCandidateCount: refreshed.governanceSnapshot.deferredCandidateCount,
                admittedCandidateCount: refreshed.governanceSnapshot.admittedCandidateCount
            ),
            diagnostics: BrainStateProjection.Diagnostics(
                recordCount: refreshed.diagnostics.recordCount,
                candidateCount: refreshed.diagnostics.candidateCount,
                allCandidatesPending: refreshed.diagnostics.allCandidatesPending
            ),
            refreshedAt: refreshed.refreshedAt
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        context: ModelContext,
        retrievalMode: DecisionRetrievalMode = .filtered,
        now: Date = .now
    ) -> DecisionBrainState {
        loadBrainState(
            mode: mode,
            prompt: prompt,
            projection: refreshProjection(in: context, now: now),
            retrievalMode: retrievalMode,
            now: now
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        projection: BrainStateProjection,
        retrievalMode: DecisionRetrievalMode = .filtered,
        now: Date = .now
    ) -> DecisionBrainState {
        let bootstrapped = BehavioralAISubstrateBridge.bootstrapBrainState(
            mode: mode,
            prompt: prompt,
            source: .sessionPrime,
            sourceSurface: .app,
            riskLevel: .low,
            taskGraph: nil,
            projection: projection,
            retrievalMode: retrievalMode,
            activeTemplateIDs: [],
            failureGuardIDs: [],
            now: now
        )
        return bootstrapped.brainState
    }

    static func fetchMemoryRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryRecord] {
        var descriptor = FetchDescriptor<DecisionMemoryRecord>(
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.lastConfirmedAt, order: .reverse)
            ]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchCandidateRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryCandidateRecord] {
        let pendingRaw = DecisionMemoryCandidateStatus.pending.rawValue
        var descriptor = FetchDescriptor<DecisionMemoryCandidateRecord>(
            predicate: #Predicate<DecisionMemoryCandidateRecord> {
                $0.statusRaw == pendingRaw
            },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.lastObservedAt, order: .reverse)
            ]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchCheckEvents(
        in context: ModelContext,
        limit: Int = projectionCheckEventLimit
    ) -> [CheckEvent] {
        var descriptor = FetchDescriptor<CheckEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchBalanceRecords(
        in context: ModelContext,
        limit: Int = BASAppleMemoryProjectionRefreshLimits.default.balanceRecordLimit
    ) -> [BalanceDecisionRecord] {
        var descriptor = FetchDescriptor<BalanceDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchMirrorRecords(
        in context: ModelContext,
        limit: Int = BASAppleMemoryProjectionRefreshLimits.default.mirrorRecordLimit
    ) -> [MirrorDecisionRecord] {
        var descriptor = FetchDescriptor<MirrorDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchGovernanceSnapshot(
        in context: ModelContext
    ) -> BrainStateGovernanceSnapshot {
        let pendingRaw = DecisionMemoryCandidateStatus.pending.rawValue
        let promotedRaw = DecisionMemoryCandidateStatus.promoted.rawValue
        let deferredRaw = DecisionMemoryGovernanceDecision.deferred.rawValue
        let admittedRaw = DecisionMemoryGovernanceDecision.admit.rawValue

        return BrainStateGovernanceSnapshot(
            totalRecordCount: fetchCount(FetchDescriptor<DecisionMemoryRecord>(), in: context),
            totalCandidateCount: fetchCount(FetchDescriptor<DecisionMemoryCandidateRecord>(), in: context),
            pendingCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.statusRaw == pendingRaw
                    }
                ),
                in: context
            ),
            promotedCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.statusRaw == promotedRaw
                    }
                ),
                in: context
            ),
            deferredCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.lastGovernanceDecisionRaw == deferredRaw
                    }
                ),
                in: context
            ),
            admittedCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.lastGovernanceDecisionRaw == admittedRaw
                    }
                ),
                in: context
            )
        )
    }

    private static func fetchCount<Model>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext
    ) -> Int where Model: PersistentModel {
        (try? context.fetchCount(descriptor)) ?? 0
    }

    private static func substrateGovernanceSnapshot(
        from snapshot: BrainStateGovernanceSnapshot
    ) -> BASAppleProjectionGovernanceSnapshot {
        BASAppleProjectionGovernanceSnapshot(
            totalRecordCount: snapshot.totalRecordCount,
            totalCandidateCount: snapshot.totalCandidateCount,
            pendingCandidateCount: snapshot.pendingCandidateCount,
            promotedCandidateCount: snapshot.promotedCandidateCount,
            deferredCandidateCount: snapshot.deferredCandidateCount,
            admittedCandidateCount: snapshot.admittedCandidateCount
        )
    }
}
