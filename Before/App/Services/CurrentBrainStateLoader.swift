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
        BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
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
    }
}
