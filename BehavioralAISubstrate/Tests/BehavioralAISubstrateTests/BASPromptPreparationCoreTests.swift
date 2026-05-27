import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASPromptPreparationCore")
struct BASPromptPreparationCoreTests {
    @Test("prompt preparation compiler builds envelope from typed task state and runtime snapshots")
    func promptPreparationCompilerBuildsEnvelope() {
        let strategy = BASAdaptiveTaskStrategy(
            kind: .comparative,
            entropy: .medium,
            runtimeGear: .balanced,
            contextBudget: 420,
            retrievalMode: .filtered,
            thinkingMode: .gated,
            outputMode: .structuredBoard,
            tone: .groundedDirect,
            actionSpace: ["clarify", "name_boundary"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let brainState = BASDecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect sleep and energy."],
            relevantMemories: ["Late sessions need lighter, shorter guidance."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["sleep", "night", "tradeoff"],
            reactionWeights: BASReactionWeights(
                briefLanguage: 0.86,
                warmDirectTone: 0.74,
                lowCognitiveLoad: 0.79,
                interruptiveActionBias: 0.42,
                boundaryNamingBias: 0.38,
                tradeoffClarityBias: 0.81
            ),
            loadedAt: .now
        )

        let envelope = BASPromptPreparationCompiler.compile(
            BASPromptPreparationRequest(
                kind: "comparative",
                semanticKind: .comparative,
                adaptiveKind: .comparative,
                taskState: [
                    "mode": .string("Comparative"),
                    "prompt": .string("Should I take this side project?"),
                    "candidate_count": .integer(2)
                ],
                evidenceSnippets: [
                    "Current headline: Base headline",
                    "Current summary: Base summary",
                    "Focus title: Base focus",
                    "Focus description: Base detail",
                    "Next action: Base next step"
                ],
                outputGuard: ["Keep the same focus and next step."],
                openTextSignalCount: 1,
                defaultTargetCharacters: 1_000,
                strategy: strategy,
                contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot(
                    rebuiltSession: true,
                    generation: 2,
                    anchorFields: ["comparativePrompt"],
                    activeFields: ["comparativePrompt", "comparativeConcern"],
                    staleFields: ["comparativeDesire"],
                    anchorTitles: ["Comparative prompt"]
                ),
                neuralSnapshot: BASPromptNeuralSnapshot(
                    dominantActivations: [
                        BASPromptNeuralActivationSnapshot(
                            signal: "constraintPressure",
                            displayTitle: "Constraint pressure"
                        ),
                        BASPromptNeuralActivationSnapshot(
                            signal: "concernWeight",
                            displayTitle: "Concern weight"
                        )
                    ],
                    candidateActions: [
                        BASPromptNeuralActionCandidateSnapshot(route: "setBoundary")
                    ],
                    suppressedBehaviors: ["instant_verdict"]
                ),
                brainState: brainState
            )
        )

        #expect(envelope.payload.contains("\"mode\":\"Comparative\""))
        #expect(envelope.payload.contains("\"candidate_count\":2"))
        #expect(envelope.payload.contains("CONTEXT_LIFECYCLE_JSON:"))
        #expect(envelope.payload.contains("\"anchor_fields\":[\"comparativePrompt\"]"))
        #expect(envelope.payload.contains("\"anchor_headlines\":[\"Comparative prompt\"]"))
        #expect(envelope.assembly.allBlocks.map(\.kind).contains(.neuralState))
        #expect(envelope.payload.contains("\"danger_signals\":[\"Constraint pressure\",\"Concern weight\",\"Session rebuild\"]"))
        #expect(envelope.assembly.allBlocks.map(\.kind).contains(.brainState))
        #expect(envelope.assembly.droppedBlockKinds.contains(.neuralState))
        #expect(envelope.assembly.droppedBlockKinds.contains(.brainState))
        #expect(envelope.payload.contains("STRUCTURED_TRUTH_JSON:"))
        #expect(envelope.payload.contains("\"currentGoal\":\"Protect sleep and energy.\""))
    }
}
#endif
