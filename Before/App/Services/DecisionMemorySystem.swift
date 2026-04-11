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
        BASAppleCurrentBrainStateCompiler.brainState(
            modeID: mode.rawValue,
            prompt: prompt,
            projection: projection.baseProjection,
            retrievalMode: retrievalMode.rawValue,
            triggerID: BrainStateUpdateSource.sessionPrime.rawValue,
            sourceSurfaceOverrideID: DecisionIntentSourceSurface.app.rawValue,
            riskLevelOverrideID: InterventionRiskLevel.low.rawValue,
            preferredLanguages: Locale.preferredLanguages,
            now: now
        )
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
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionCheckEvents(
            in: context,
            eventType: CheckEvent.self,
            limit: limit
        )
    }

    static func fetchBalanceRecords(
        in context: ModelContext,
        limit: Int = BASAppleMemoryProjectionRefreshLimits.default.balanceRecordLimit
    ) -> [BalanceDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionBalanceRecords(
            in: context,
            balanceType: BalanceDecisionRecord.self,
            limit: limit
        )
    }

    static func fetchMirrorRecords(
        in context: ModelContext,
        limit: Int = BASAppleMemoryProjectionRefreshLimits.default.mirrorRecordLimit
    ) -> [MirrorDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionMirrorRecords(
            in: context,
            mirrorType: MirrorDecisionRecord.self,
            limit: limit
        )
    }

}
