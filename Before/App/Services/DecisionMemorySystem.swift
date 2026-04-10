import Foundation
import SwiftData
import BASAppleAdapters
import BASMemory

enum DecisionMemorySystem {
    static let projectionRecordLimit = 72
    static let projectionCandidateLimit = 32
    static let projectionCheckEventLimit = 96

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
        var governanceSnapshot = fetchGovernanceSnapshot(in: context)
        let records = fetchMemoryRecords(
            in: context,
            limit: projectionRecordLimit
        )
        let candidates = fetchCandidateRecords(
            in: context,
            limit: projectionCandidateLimit
        )
        let resolvedRecords: [DecisionMemoryRecord]
        let resolvedCandidates: [DecisionMemoryCandidateRecord]

        if governanceSnapshot.totalRecordCount == 0 && governanceSnapshot.totalCandidateCount == 0 {
            resolvedRecords = Array(
                refreshStoredMemories(in: context, now: now)
                    .prefix(projectionRecordLimit)
            )
            governanceSnapshot = fetchGovernanceSnapshot(in: context)
            resolvedCandidates = fetchCandidateRecords(
                in: context,
                limit: projectionCandidateLimit
            )
        } else {
            resolvedRecords = records
            resolvedCandidates = candidates
        }

        let checkEvents = fetchCheckEvents(in: context)
        let balanceRecords = fetchBalanceRecords(in: context)
        let mirrorRecords = fetchMirrorRecords(in: context)
        EmbeddingMemoryStore.rebuildIndex(
            records: resolvedRecords,
            candidates: resolvedCandidates,
            checkEvents: checkEvents,
            balance: balanceRecords,
            mirror: mirrorRecords
        )

        return BrainStateProjection(
            baseProjection: BASAppleMemoryProjectionAdapter.compileProjection(
                records: resolvedRecords,
                candidates: resolvedCandidates,
                events: checkEvents,
                governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                    totalRecordCount: governanceSnapshot.totalRecordCount,
                    totalCandidateCount: governanceSnapshot.totalCandidateCount,
                    pendingCandidateCount: governanceSnapshot.pendingCandidateCount,
                    promotedCandidateCount: governanceSnapshot.promotedCandidateCount,
                    deferredCandidateCount: governanceSnapshot.deferredCandidateCount,
                    admittedCandidateCount: governanceSnapshot.admittedCandidateCount
                )
            ),
            governanceSnapshot: governanceSnapshot,
            diagnostics: BrainStateProjection.Diagnostics(
                recordCount: resolvedRecords.count,
                candidateCount: resolvedCandidates.count,
                allCandidatesPending: resolvedCandidates.allSatisfy { $0.status == .pending }
            ),
            refreshedAt: now
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

    static func fetchCheckEvents(in context: ModelContext) -> [CheckEvent] {
        var descriptor = FetchDescriptor<CheckEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = projectionCheckEventLimit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchBalanceRecords(in context: ModelContext) -> [BalanceDecisionRecord] {
        var descriptor = FetchDescriptor<BalanceDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 36
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchMirrorRecords(in context: ModelContext) -> [MirrorDecisionRecord] {
        var descriptor = FetchDescriptor<MirrorDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 36
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
}
