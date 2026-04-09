import Foundation
import SwiftData

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

        let languageMode = DecisionLanguageMode.detect(
            preferredLanguages: Locale.preferredLanguages,
            sampleTexts: [prompt]
        )
        let riskLevel = envelope?.riskLevel ?? inferredRiskLevel(mode: mode, prompt: prompt, now: now)
        let armIDs = DecisionReactionBanditStore.recommendedArmIDs(
            mode: mode,
            riskLevel: riskLevel,
            languageMode: languageMode,
            now: now
        )
        let templates = InterventionTemplateStore.selectTemplates(
            in: context,
            mode: mode,
            riskLevel: riskLevel,
            recommendedArmIDs: armIDs
        )
        let failurePatterns = FailurePatternStore.selectedFailurePatterns(in: context, mode: mode)

        var brainState = DecisionMemorySystem.loadBrainState(
            mode: mode,
            prompt: prompt,
            projection: projection,
            retrievalMode: retrievalMode,
            now: now
        )
        brainState.activeInterventionTemplateIDs = templates.map(\.id)
        brainState.failureGuardIDs = failurePatterns.map(\.id)
        let activeConstraints = Array(brainState.sessionBiases.prefix(3))
        let current = CurrentBrainState(
            source: source,
            mode: mode,
            taskGraph: taskGraph,
            brainState: brainState,
            dominantGoal: brainState.activeGoals.first,
            activeConstraints: activeConstraints,
            activeTemplateIDs: templates.map(\.id),
            failureGuardIDs: failurePatterns.map(\.id),
            sourceIntentEnvelope: envelope,
            loadedAt: now
        )

        let update = BrainStateUpdate(
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

    private static func inferredRiskLevel(
        mode: DecisionMode,
        prompt: String,
        now: Date
    ) -> InterventionRiskLevel {
        let lowercased = prompt.lowercased()
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        if hour >= 22 || hour < 5 {
            if lowercased.contains("message") || lowercased.contains("reply") || lowercased.contains("text") {
                return .high
            }
            return mode == .quick ? .medium : .high
        }
        if mode == .mirror {
            return .medium
        }
        return .low
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
