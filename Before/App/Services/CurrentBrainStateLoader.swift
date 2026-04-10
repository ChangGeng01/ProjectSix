import Foundation
import SwiftData
import BASAppleAdapters
import BASMemory
import BASPolicy

enum CurrentBrainStateLoader {
    @discardableResult
    static func bootstrapCurrentBrainState(
        mode: DecisionMode,
        prompt: String,
        source: BrainStateUpdateSource,
        envelope: DecisionIntentEnvelope? = nil,
        taskGraph: DecisionTaskGraphSnapshot?,
        context: ModelContext,
        projection: DecisionMemorySystem.BrainStateProjection,
        retrievalMode: DecisionRetrievalMode,
        now: Date = .now
    ) -> CurrentBrainState {
        InterventionTemplateStore.ensureDefaults(in: context)
        FailurePatternStore.syncFromHistory(in: context)

        let artifact = BehavioralAISubstrateBridge.bootstrapCurrentBrainStateArtifact(
            mode: mode,
            prompt: prompt,
            source: source,
            envelope: envelope,
            taskGraph: taskGraph,
            context: context,
            projection: projection,
            retrievalMode: retrievalMode,
            now: now
        )
        let commit: BASAppleCurrentBrainCommitWriteResult<
            BrainStateUpdate,
            DecisionEvolutionCheckpoint
        > = BASAppleCurrentBrainCommitter.commit(
            modeName: mode.rawValue,
            sourceID: source.rawValue,
            brainState: artifact.bootstrapped.brainState,
            persistenceInput: artifact.persistenceInput,
            in: context,
            createdAt: now,
            checkpointLimit: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            checkpointRetentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
            onCheckpointSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "recording evolution checkpoints"
                )
            },
            onUpdateSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "persisting current brain updates"
                )
            }
        )
        let brainState = commit.brainState

        let current = CurrentBrainState(
            source: source,
            sourceSurface: artifact.sourceSurface,
            mode: mode,
            riskLevel: artifact.riskLevel,
            taskGraph: taskGraph,
            brainState: brainState,
            dominantGoal: artifact.bootstrapped.dominantGoal,
            activeConstraints: artifact.bootstrapped.activeConstraints,
            activeTemplateIDs: artifact.activeTemplateIDs,
            failureGuardIDs: artifact.failureGuardIDs,
            sourceIntentEnvelope: envelope,
            loadedAt: now
        )
        return current
    }
}
