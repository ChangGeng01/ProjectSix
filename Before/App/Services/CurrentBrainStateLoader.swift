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

        let preparation = BehavioralAISubstrateBridge.prepareCurrentBrainBootstrap(
            mode: mode,
            prompt: prompt,
            source: source,
            envelope: envelope,
            now: now
        )
        let armIDs = DecisionReactionBanditStore.recommendedArmIDs(
            mode: mode,
            riskLevel: preparation.riskLevel,
            languageMode: preparation.languageMode,
            now: now
        )
        let templates = InterventionTemplateStore.selectTemplates(
            in: context,
            mode: mode,
            riskLevel: preparation.riskLevel,
            recommendedArmIDs: armIDs
        )
        let failurePatterns = FailurePatternStore.selectedFailurePatterns(in: context, mode: mode)

        var execution = BehavioralAISubstrateBridge.executeCurrentBrainBootstrap(
            preparation: preparation,
            taskGraph: taskGraph,
            projection: projection,
            retrievalMode: retrievalMode,
            recommendedTemplateIDs: armIDs,
            templates: templates,
            failurePatterns: failurePatterns
        )
        var brainState = execution.bootstrapped.brainState
        brainState.evolutionState = DecisionEvolutionEngine.recordCheckpoint(
            mode: mode,
            source: source,
            brainState: brainState,
            context: context,
            now: now
        )
        execution = CurrentBrainBootstrapExecution(
            preparation: execution.preparation,
            bootstrapped: BASBootstrappedBrainState(
                brainState: brainState,
                dominantGoal: execution.bootstrapped.dominantGoal,
                activeConstraints: execution.bootstrapped.activeConstraints,
                activeTemplateIDs: execution.bootstrapped.activeTemplateIDs,
                failureGuardIDs: execution.bootstrapped.failureGuardIDs,
                taskGraphHint: execution.bootstrapped.taskGraphHint
            ),
            activeTemplateIDs: execution.activeTemplateIDs,
            failureGuardIDs: execution.failureGuardIDs
        )

        let current = CurrentBrainState(
            source: source,
            sourceSurface: preparation.sourceSurface,
            mode: mode,
            riskLevel: preparation.riskLevel,
            taskGraph: taskGraph,
            brainState: brainState,
            dominantGoal: execution.bootstrapped.dominantGoal,
            activeConstraints: execution.bootstrapped.activeConstraints,
            activeTemplateIDs: execution.activeTemplateIDs,
            failureGuardIDs: execution.failureGuardIDs,
            sourceIntentEnvelope: envelope,
            loadedAt: now
        )

        let update = BrainStateUpdate(
            createdAt: now,
            source: source,
            mode: mode,
            dominantGoal: current.dominantGoal,
            dominantReactionWeight: current.dominantReactionWeight,
            fingerprint: current.verificationSnapshot.fingerprint,
            activeConstraints: current.activeConstraints,
            activeTemplateIDs: current.activeTemplateIDs,
            failureGuardIDs: current.failureGuardIDs
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
        for stale in updates.dropFirst(60) {
            context.delete(stale)
        }
        for stale in updates where stale.createdAt.addingTimeInterval(60 * 60 * 24 * 14) < now {
            context.delete(stale)
        }
    }
}
