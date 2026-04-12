import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASReferencePromptBuilder")
struct BASReferencePromptModesCoreTests {
    enum TestKind: Sendable, Equatable {
        case primary
        case selection
    }

    @Test("reference prompt kind carries package-owned adaptive trace mapping")
    func referencePromptKindCarriesAdaptiveTraceMapping() {
        #expect(BASReferencePromptKind.primary.adaptiveTraceKind == .primary)
        #expect(BASReferencePromptKind.comparative.adaptiveTraceKind == .comparative)
        #expect(BASReferencePromptKind.reflective.adaptiveTraceKind == .reflective)
        #expect(BASReferencePromptKind.selection.adaptiveTraceKind == .selection)
        #expect(BASReferencePromptKind.primary.identifier == BASAdaptiveTraceKind.primaryID)
        #expect(BASReferencePromptKind(identifier: "primary") == .primary)
        #expect(BASReferencePromptKind(identifier: "comparative") == .comparative)
        #expect(BASReferencePromptKind(identifier: "reflective") == .reflective)
        #expect(BASReferencePromptKind(identifier: "selection") == .selection)
        #expect(BASReferencePromptKind(identifier: "quick") == nil)
        #expect(BASReferencePromptKind(identifier: "balance") == nil)
        #expect(BASReferencePromptKind(identifier: "mirror") == nil)
        #expect(BASReferencePromptKind(identifier: "reminder") == nil)
    }

    @Test("primary envelope compiles structured state and secondary actions")
    func primaryEnvelopeCompilesStructuredState() {
        let envelope = BASReferencePromptBuilder.primaryEnvelope(
            BASPrimaryRefinementPromptRequest(
                kind: TestKind.primary,
                modeTitle: "Primary",
                entryContext: "Purchase",
                currentDrive: "Reward",
                anticipatedShift: "Temporary relief",
                controlEstimate: "Maybe",
                hostNote: "",
                presentView: "You want a little relief.",
                laterView: "It may not feel worth it tomorrow.",
                currentVerdict: "Pause",
                preferredAction: "Wait 90s",
                alternateActions: ["Decide tomorrow"]
            )
        )

        #expect(envelope.payload.contains("\"mode\":\"Primary\""))
        #expect(envelope.payload.contains("\"entry_context\":\"Purchase\""))
        #expect(envelope.payload.contains("\"host_note\":\"Not provided.\""))
        #expect(envelope.payload.contains("Present view: You want a little relief."))
        #expect(envelope.payload.contains("Alternate actions: Decide tomorrow"))
        #expect(envelope.assembly.kernelSnapshot.truthState == nil)
    }

    @Test("selection envelope remains available through the generic facade")
    func selectionEnvelopeUsesGenericFacade() {
        let envelope = BASReferencePromptBuilder.selectionEnvelope(
            BASSelectionPromptRequest(
                kind: TestKind.selection,
                modeTitle: "Primary",
                entryContext: "Buy",
                activePrompt: "I want to buy this tonight.",
                candidateTexts: [
                    "Hold it until tomorrow morning.",
                    "Put it in the holding lane and sleep on it."
                ],
                surfaceMode: .primary
            )
        )

        #expect(envelope.kind == .selection)
        #expect(envelope.assembly.kernelSnapshot.truthState?.sessionFacts["surface_mode"] == "primary")
    }

    @Test("selection envelope clips candidates and suppresses structured truth block")
    func selectionEnvelopeClipsCandidatesAndSuppressesTruthBlock() {
        let envelope = BASReferencePromptBuilder.selectionEnvelope(
            BASSelectionPromptRequest(
                kind: TestKind.selection,
                modeTitle: "Primary",
                scenarioTitle: "Purchase",
                prompt: "I want to buy this tonight.",
                candidateTexts: [
                    "Hold it until tomorrow morning.",
                    "Put it in the holding lane and sleep on it.",
                    "Wait for the weekend before deciding.",
                    "This fourth candidate should be clipped."
                ],
                surfaceMode: .primary
            )
        )

        #expect(envelope.payload.contains("\"candidate_count\":3"))
        #expect(envelope.payload.contains("0: Hold it until tomorrow morning."))
        #expect(envelope.payload.contains("2: Wait for the weekend before deciding."))
        #expect(!envelope.payload.contains("This fourth candidate should be clipped."))
        #expect(!envelope.payload.contains("STRUCTURED_TRUTH_JSON:"))
        #expect(envelope.assembly.kernelSnapshot.truthState?.mode == BASAdaptiveTraceKind.selectionID)
    }

    @Test("reference prompt builder honors injected host presentation behavior")
    func referencePromptBuilderHonorsInjectedBehavior() {
        let behavior = BASReferencePromptBehavior(
            presentationBehavior: BASPromptPresentationBehavior(
                sharedPrelude: "Host immutable prefix.",
                adaptivePrefixByKindID: [
                    BASSemanticTaskKind.primaryID: "Host primary adaptive prefix."
                ]
            ),
            frontstageBehavior: BASFrontstagePresentationBehavior(
                focusGoalsByKindID: [
                    BASAdaptiveTraceKind.primaryID: "Host primary focus goal."
                ]
            ),
            structuredTruthBehavior: BASStructuredTruthBehavior(
                modeNamesByKindID: [
                    BASAdaptiveTraceKind.primaryID: "host.primary"
                ],
                kernelPersonaRulesByKindID: [
                    BASAdaptiveTraceKind.primaryID: "Keep the interruption short, calm, and non-shaming."
                ]
            ),
            slotVocabularyByKindID: [
                BASSemanticTaskKind.primaryID: BASReferencePromptSlotVocabulary(
                    stateKeysBySlotID: [
                        "mode": "mode",
                        "scenario": "scenario",
                        "motivation": "motivation",
                        "expected_outcome": "expected_outcome",
                        "control_level": "control_level",
                        "note": "note"
                    ],
                    evidenceLabelsBySlotID: [
                        "current_perspective": "Current perspective",
                        "after_perspective": "After perspective",
                        "verdict": "Verdict",
                        "primary_action": "Primary action",
                        "secondary_actions": "Secondary actions"
                    ]
                )
            ],
            outputGuardsByKindID: [
                BASSemanticTaskKind.primaryID: [
                    "Keep the host-specific viewpoint framing."
                ]
            ],
            targetCharactersByKindID: [
                BASSemanticTaskKind.primaryID: 900
            ]
        )

        let envelope = BASReferencePromptBuilder.primaryEnvelope(
            BASPrimaryRefinementPromptRequest(
                kind: TestKind.primary,
                modeTitle: "Primary",
                scenarioTitle: "Purchase",
                motivationTitle: "Reward",
                expectedOutcomeTitle: "Temporary relief",
                controlLevelTitle: "Maybe",
                note: "",
                currentPerspective: "You want a little relief.",
                afterPerspective: "It may not feel worth it tomorrow.",
                verdictTitle: "Pause",
                primaryActionTitle: "Wait 90s",
                secondaryActionTitles: ["Decide tomorrow"],
                brainState: hostBrainState()
            ),
            behavior: behavior
        )

        #expect(envelope.layers.immutablePrefix == "Host immutable prefix.")
        #expect(envelope.layers.adaptivePrefix == "Host primary adaptive prefix.")
        #expect(envelope.payload.contains("\"scenario\":\"Purchase\""))
        #expect(envelope.payload.contains("\"note\":\"Not provided.\""))
        #expect(envelope.payload.contains("Current perspective: You want a little relief."))
        #expect(envelope.payload.contains("Secondary actions: Decide tomorrow"))
        #expect(envelope.payload.contains("Keep the host-specific viewpoint framing."))
        #expect(envelope.budget.targetCharacters == 900)
        #expect(envelope.frontstageState.focusGoal == "Host primary focus goal.")
        #expect(envelope.assembly.kernelSnapshot.truthState?.mode == "host.primary")
        #expect(envelope.assembly.kernelSnapshot.truthState?.personaRules.contains("Keep the interruption short, calm, and non-shaming.") == true)
    }

    private func hostBrainState() -> BASDecisionBrainState {
        BASDecisionBrainState(
            profileCore: ["Keep the language steady."],
            activeGoals: ["Protect tomorrow's clarity."],
            relevantMemories: ["Similar loops softened after a pause."],
            sessionBiases: ["Keep it short."],
            retrievalTags: ["pause"],
            reactionWeights: BASReactionWeights.defaults(forModeName: BASDecisionMode.primary.rawValue),
            loadedAt: .now
        )
    }
}
