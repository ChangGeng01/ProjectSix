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
                kind: .primary,
                brainState: brainState
            )
        )

        #expect(truthState?.mode == "primary")
        #expect(truthState?.currentGoal == "Protect sleep before midnight.")
        #expect(truthState?.allowedActions == Array(brainState.boundaryPolicy.allowedActionClasses.prefix(3)))
        #expect(truthState?.forbiddenActions == Array(brainState.boundaryPolicy.blockedActionClasses.prefix(2)))
        #expect(truthState?.sessionFacts["boundary_mode"] == brainState.boundaryPolicy.mode.rawValue)
        #expect(truthState?.sessionFacts["dominant_reaction_weight"] == brainState.reactionWeights.dominantKey.rawValue)
        #expect(truthState?.personaRules.contains("Keep the active guidance short, calm, and bounded.") == true)
        #expect(truthState?.personaRules.contains(brainState.identityProfile.relationshipBoundary) == true)
    }

    @Test("selection truth state can be built without a loaded brain")
    func selectionTruthStateWorksWithoutBrainState() {
        let truthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .selection,
                brainState: nil,
                selectionSurfaceMode: .comparative
            )
        )

        #expect(truthState?.mode == BASAdaptiveTraceKind.selectionID)
        #expect(truthState?.currentGoal == nil)
        #expect(truthState?.sessionFacts["surface_mode"] == "comparative")
        #expect(truthState?.sessionFacts["boundary_mode"] == nil)
        #expect(truthState?.personaRules.contains("Choose only from retained candidates and do not invent a new option.") == true)
        #expect(truthState?.allowedActions == ["render_local_guidance", "load_governed_memory"])
    }

    @Test("governed truth is nil for non-selection flows when no brain is loaded")
    func nonSelectionTruthRequiresBrainState() {
        let truthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .reflective,
                brainState: nil
            )
        )

        #expect(truthState == nil)
    }

    @Test("structured truth compiler honors host-specific behavior overrides")
    func structuredTruthCompilerHonorsHostSpecificBehaviorOverrides() {
        let behavior = BASStructuredTruthBehavior(
            modeNamesByKindID: [
                BASAdaptiveTraceKind.primary.rawValue: "atlas.primary",
                BASAdaptiveTraceKind.selection.rawValue: "atlas.selection"
            ],
            kernelPersonaRulesByKindID: [
                BASAdaptiveTraceKind.primary.rawValue: "Keep the interruption short, calm, and non-shaming.",
                BASAdaptiveTraceKind.selection.rawValue: "Choose from retained candidates only and do not invent new ones."
            ]
        )

        let primaryTruthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .primary,
                brainState: hostOverrideBrainState(),
                behavior: behavior
            )
        )

        let selectionTruthState = BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: .selection,
                brainState: nil,
                selectionSurfaceMode: .primary,
                behavior: behavior
            )
        )

        #expect(primaryTruthState?.mode == "atlas.primary")
        #expect(primaryTruthState?.personaRules.contains("Keep the interruption short, calm, and non-shaming.") == true)
        #expect(selectionTruthState?.mode == "atlas.selection")
        #expect(selectionTruthState?.personaRules.contains("Choose from retained candidates only and do not invent new ones.") == true)
    }

    private func hostOverrideBrainState() -> BASDecisionBrainState {
        BASDecisionBrainState(
            profileCore: ["Stay local and bounded."],
            activeGoals: ["Protect the next step."],
            relevantMemories: ["Similar loops calmed down after a pause."],
            sessionBiases: ["Keep it short."],
            retrievalTags: ["pause"],
            reactionWeights: BASReactionWeights.defaults(forModeName: BASDecisionMode.primary.rawValue),
            loadedAt: .now
        )
    }
}
