import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration

@Suite("BASAppleReferencePromptBuilder")
struct BASAppleReferencePromptBuilderTests {
    @Test("quick envelope builds package-owned reference kind and prompt snapshots")
    func quickEnvelopeBuildsReferencePrompt() {
        let envelope = BASAppleReferencePromptBuilder.quickEnvelope(
            BASAppleQuickRefinementEnvelopeRequest(
                modeTitle: "Quick",
                scenarioTitle: "Buy",
                motivationTitle: "Reward",
                expectedOutcomeTitle: "Temporary relief",
                controlLevelTitle: "Maybe",
                note: "",
                currentPerspective: "You want a little relief.",
                afterPerspective: "It may not feel worth it tomorrow.",
                verdictTitle: "Pause",
                primaryActionTitle: "Wait 90s",
                secondaryActionTitles: ["Decide tomorrow"],
                providerIdentifier: "gemma-e4b",
                strategy: BASAppleAdaptiveStrategyRawInput(
                    kindRawValue: "quick",
                    entropyRawValue: "low",
                    runtimeGearRawValue: "low",
                    contextBudget: 220,
                    outputCharacterBudget: 120,
                    timeBudgetMs: 1100,
                    toolCallBudget: 0,
                    retrievalItemBudget: 1,
                    retrievalModeRawValue: "off",
                    thinkingModeRawValue: "off",
                    outputModeRawValue: "guided_short",
                    toneRawValue: "brief_warm",
                    actionSpace: ["encourage", "encourage", "next_step"],
                    responseLanguageRawValue: "english",
                    allowsModelInvocation: true
                ),
                contextLifecycleInput: BASApplePromptLifecycleInput(
                    rebuiltSession: true,
                    generation: 2,
                    anchorFields: [" prompt ", "mode"],
                    activeFields: ["mode", "goal"],
                    staleFields: ["note"],
                    anchorTitles: ["Current prompt", "Mode"]
                ),
                neuralInput: BASApplePromptNeuralInput(
                    dominantActivations: [
                        BASApplePromptActivationInput(signal: " urgency ", displayTitle: "Urgency")
                    ],
                    candidateActions: [
                        BASApplePromptActionCandidateInput(route: " pause ")
                    ],
                    suppressedBehaviors: ["long_explanation"]
                ),
                brainState: BASDecisionBrainState(
                    profileCore: ["Short language lands better."],
                    activeGoals: ["Protect sleep."],
                    relevantMemories: ["Holding the decision often works."],
                    sessionBiases: ["Keep it short."],
                    retrievalTags: ["buy", "night"],
                    reactionWeights: BASReactionWeights(
                        briefLanguage: 0.9,
                        warmDirectTone: 0.7,
                        lowCognitiveLoad: 0.8,
                        interruptiveActionBias: 0.9,
                        boundaryNamingBias: 0.2,
                        tradeoffClarityBias: 0.3
                    ),
                    loadedAt: .now
                )
            )
        )

        let neuralBlock = envelope.assembly.allBlocks.first { $0.kind == .neuralState }
        let runtimeStrategyBlock = envelope.assembly.allBlocks.first { $0.kind == .runtimeStrategy }

        #expect(envelope.kind == .quick)
        #expect(envelope.payload.contains("\"mode\":\"Quick\""))
        #expect(envelope.payload.contains("\"generation\":2"))
        #expect(neuralBlock?.body.contains("\"dominant_signals\":[{\"signal\":\"urgency\"}]") == true)
        #expect(runtimeStrategyBlock?.body.contains("\"provider\":\"gemma-e4b\"") == true)
        #expect(runtimeStrategyBlock?.body.contains("\"context_budget\":220") == true)
        #expect(envelope.frontstageState.dangerSignals.contains("Session rebuild"))
    }

    @Test("reminder envelope owns clipped candidate wrapper")
    func reminderEnvelopeOwnsClippedCandidateWrapper() {
        struct Candidate: Equatable, Sendable {
            let id: Int
            let text: String
        }

        let envelope = BASAppleReferencePromptBuilder.reminderEnvelope(
            candidates: [
                Candidate(id: 1, text: "Hold it until tomorrow morning."),
                Candidate(id: 2, text: "Put it in the holding lane and sleep on it."),
                Candidate(id: 3, text: "Wait for the weekend before deciding."),
                Candidate(id: 4, text: "This fourth candidate should be clipped.")
            ],
            candidateText: \.text,
            modeTitle: "Quick",
            scenarioTitle: "Buy",
            prompt: "I want to buy this tonight.",
            reminderSurfaceModeRawValue: "quick"
        )

        #expect(envelope.prompt.kind == .reminder)
        #expect(envelope.candidates.map(\.id) == [1, 2, 3])
        #expect(envelope.prompt.payload.contains("\"candidate_count\":3"))
        #expect(!envelope.prompt.payload.contains("This fourth candidate should be clipped."))
        #expect(envelope.prompt.assembly.kernelSnapshot.truthState?.sessionFacts["surface_mode"] == "primary")
    }
}
