import Foundation
import SwiftData
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
        var brainState = artifact.bootstrapped.brainState
        brainState.evolutionState = DecisionEvolutionEngine.recordCheckpoint(
            mode: mode,
            source: source,
            brainState: brainState,
            context: context,
            now: now
        )

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

        let update = BrainStateUpdate(
            storedFields: BASCurrentBrainPersistenceApplier.updateFields(
                createdAt: now,
                source: source.rawValue,
                input: artifact.persistenceInput
            )
        )
        context.insert(update)
        trimOldUpdates(in: context, now: now)
        try? context.save()
        return current
    }

    private static func trimOldUpdates(in context: ModelContext, now: Date) {
        let descriptor = FetchDescriptor<BrainStateUpdate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let updates = (try? context.fetch(descriptor)) ?? []
        let retainedIDs = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: updates.map(\.storedFields),
            now: now
        )
        for stale in updates where !retainedIDs.contains(stale.id) {
            context.delete(stale)
        }
    }
}
