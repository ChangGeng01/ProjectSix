import Foundation
import SwiftData
import BASAppleAdapters
import BASMemory

enum DecisionMemorySystem {
    static let projectionRecordLimit = BASAppleMemoryProjectionRefreshLimits.default.recordLimit
    static let projectionCandidateLimit = BASAppleMemoryProjectionRefreshLimits.default.candidateLimit
    static let projectionCheckEventLimit = BASAppleMemoryProjectionRefreshLimits.default.checkEventLimit

    typealias BrainStateProjection = BASAppleMemoryProjectionRefreshResult

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
        BASAppleMemoryProjectionRuntime.refresh(
            in: context,
            now: now,
            recordType: DecisionMemoryRecord.self,
            candidateType: DecisionMemoryCandidateRecord.self,
            reminderType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            balanceRecordType: BalanceDecisionRecord.self,
            mirrorRecordType: MirrorDecisionRecord.self,
            fetchRecords: {
                BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
                    in: $0,
                    recordType: DecisionMemoryRecord.self,
                    limit: $1
                )
            },
            fetchCandidates: {
                BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
                    in: $0,
                    candidateType: DecisionMemoryCandidateRecord.self,
                    limit: $1
                )
            },
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
        let request = BASAppleBrainBootstrapRequestAdapter.request(
            modeID: mode.rawValue,
            prompt: prompt,
            triggerID: BrainStateUpdateSource.sessionPrime.rawValue,
            sourceSurfaceOverrideID: DecisionIntentSourceSurface.app.rawValue,
            riskLevelOverrideID: InterventionRiskLevel.low.rawValue,
            preferredLanguages: Locale.preferredLanguages,
            now: now,
            retrievalMode: retrievalMode.rawValue
        )
        return BASAppleBrainBootstrapRuntime.bootstrap(
            request: request,
            projection: projection.baseProjection
        ).brainState
    }

    static func fetchMemoryRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
            in: context,
            recordType: DecisionMemoryRecord.self,
            limit: limit
        )
    }

    static func fetchCandidateRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryCandidateRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
            in: context,
            candidateType: DecisionMemoryCandidateRecord.self,
            limit: limit
        )
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

}
