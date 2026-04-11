import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASStructuredTruthCompiler")
struct BASStructuredTruthCoreTests {
    @Test("governed truth state carries goal boundary and dominant reaction weight")
    func governedTruthStateCarriesBrainStateSignals() {
        let brainState = BASDecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect sleep before midnight."],
            relevantMemories: ["Holding the decision often breaks the loop."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["night", "sleep"],
            reactionWeights: BASReactionWeights(
                briefLanguage: 0.91,
                warmDirectTone: 0.73,
                lowCognitiveLoad: 0.88,
                interruptiveActionBias: 0.94,
                boundaryNamingBias: 0.21,
                tradeoffClarityBias: 0.26
            ),
            loadedAt: .now
        )

        let truthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .quick,
                brainState: brainState
            )
        )

        #expect(truthState?.mode == "primary")
        #expect(truthState?.currentGoal == "Protect sleep before midnight.")
        #expect(truthState?.allowedActions == Array(brainState.boundaryPolicy.allowedActionClasses.prefix(3)))
        #expect(truthState?.forbiddenActions == Array(brainState.boundaryPolicy.blockedActionClasses.prefix(2)))
        #expect(truthState?.sessionFacts["boundary_mode"] == brainState.boundaryPolicy.mode.rawValue)
        #expect(truthState?.sessionFacts["dominant_reaction_weight"] == brainState.reactionWeights.dominantKey.rawValue)
        #expect(truthState?.personaRules.contains("Keep the interruption short, calm, and non-shaming.") == true)
        #expect(truthState?.personaRules.contains(brainState.identityProfile.relationshipBoundary) == true)
    }

    @Test("reminder truth state can be built without a loaded brain")
    func reminderTruthStateWorksWithoutBrainState() {
        let truthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .reminder,
                brainState: nil,
                reminderSurfaceMode: .balance
            )
        )

        #expect(truthState?.mode == "reminder")
        #expect(truthState?.currentGoal == nil)
        #expect(truthState?.sessionFacts["surface_mode"] == "comparative")
        #expect(truthState?.sessionFacts["boundary_mode"] == nil)
        #expect(truthState?.personaRules.contains("Choose from retained reminders only and do not invent new reminders.") == true)
        #expect(truthState?.allowedActions == ["render_local_guidance", "load_governed_memory"])
    }

    @Test("governed truth is nil for non-reminder flows when no brain is loaded")
    func nonReminderTruthRequiresBrainState() {
        let truthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .mirror,
                brainState: nil
            )
        )

        #expect(truthState == nil)
    }
}
