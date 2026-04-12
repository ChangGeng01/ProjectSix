import Foundation
import SwiftData
import BASHostKit

enum DecisionMemorySystem {
    static let projectionRefreshLimits = BeforeProductCompatibility.projectionRefreshLimits
    static let projectionRecordLimit = projectionRefreshLimits.recordLimit
    static let projectionCandidateLimit = projectionRefreshLimits.candidateLimit
    static let projectionCheckEventLimit = projectionRefreshLimits.checkEventLimit

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
            cueType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            comparativeRecordType: BalanceDecisionRecord.self,
            reflectiveRecordType: MirrorDecisionRecord.self,
            behavior: BeforeProductCompatibility.memoryDerivationBehavior,
            memoryTrustBehavior: BeforeProductCompatibility.memoryTrustBehavior,
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
            limits: projectionRefreshLimits,
            recordType: DecisionMemoryRecord.self,
            candidateType: DecisionMemoryCandidateRecord.self,
            cueType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            comparativeRecordType: BalanceDecisionRecord.self,
            reflectiveRecordType: MirrorDecisionRecord.self,
            behavior: BeforeProductCompatibility.memoryDerivationBehavior,
            memoryTrustBehavior: BeforeProductCompatibility.memoryTrustBehavior,
            rebuildEmbeddings: { records, candidates, checkEvents, comparativeRecords, reflectiveRecords in
                EmbeddingMemoryStore.rebuildIndex(
                    records: records,
                    candidates: candidates,
                    checkEvents: checkEvents,
                    balance: comparativeRecords,
                    mirror: reflectiveRecords
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
        do {
            return try BASAppleCurrentBrainProjectionStateCompiler.appSessionBrainState(
                modeID: mode.substrateModeID,
                prompt: prompt,
                projection: projection.baseProjection,
                retrievalMode: retrievalMode.rawValue,
                reactionWeightSeed: BeforeProductCompatibility.reactionWeights(for: mode),
                identityProfileOverride: BeforeProductCompatibility.identityProfile(for: mode),
                cognitionBehavior: BeforeProductCompatibility.substrateCognitionBehavior,
                preferredLanguages: Locale.preferredLanguages,
                now: now
            )
        } catch {
            PersistenceIssueRecorder.record(
                error: error,
                operation: "bootstrapping current brain state from projection"
            )
            let relevantMemories = projection.baseProjection.records
                .prefix(3)
                .map(\.content)
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return DecisionBrainState(
                profileCore: [],
                activeGoals: trimmedPrompt.isEmpty ? [] : [trimmedPrompt],
                relevantMemories: relevantMemories,
                sessionBiases: ["brain-bootstrap-fallback", "retrieval:\(retrievalMode.rawValue)"],
                retrievalTags: ["fallback", "retrieval:\(retrievalMode.rawValue)"],
                reactionWeights: BeforeProductCompatibility.reactionWeights(for: mode),
                identityProfile: BeforeProductCompatibility.identityProfile(for: mode),
                boundaryPolicy: .default(riskLevel: InterventionRiskLevel.low),
                loadedAt: now
            )
        }
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
        limit: Int = projectionRefreshLimits.comparativeRecordLimit
    ) -> [BalanceDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionComparativeRecords(
            in: context,
            comparativeType: BalanceDecisionRecord.self,
            limit: limit
        )
    }

    static func fetchMirrorRecords(
        in context: ModelContext,
        limit: Int = projectionRefreshLimits.reflectiveRecordLimit
    ) -> [MirrorDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionReflectiveRecords(
            in: context,
            reflectiveType: MirrorDecisionRecord.self,
            limit: limit
        )
    }

}
