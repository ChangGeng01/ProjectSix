import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASReferencePromptBuilder")
struct BASReferencePromptModesCoreTests {
    enum TestKind: Sendable, Equatable {
        case quick
        case reminder
    }

    @Test("reference prompt kind carries package-owned adaptive trace mapping")
    func referencePromptKindCarriesAdaptiveTraceMapping() {
        #expect(BASReferencePromptKind.quick.adaptiveTraceKind == .quick)
        #expect(BASReferencePromptKind.balance.adaptiveTraceKind == .balance)
        #expect(BASReferencePromptKind.mirror.adaptiveTraceKind == .mirror)
        #expect(BASReferencePromptKind.reminder.adaptiveTraceKind == .reminder)
        #expect(BASReferencePromptKind.primary == .quick)
        #expect(BASReferencePromptKind.comparative == .balance)
        #expect(BASReferencePromptKind.reflective == .mirror)
        #expect(BASReferencePromptKind.selection == .reminder)
        #expect(BASReferencePromptKind.quick.identifier == BASAdaptiveTraceKind.primaryID)
        #expect(BASReferencePromptKind.mirror.legacyIdentifier == "mirror")
        #expect(BASReferencePromptKind(identifier: "primary") == .quick)
        #expect(BASReferencePromptKind(identifier: "comparative") == .balance)
        #expect(BASReferencePromptKind(identifier: "reflective") == .mirror)
        #expect(BASReferencePromptKind(identifier: "selection") == .reminder)
    }

    @Test("quick envelope compiles structured state and secondary actions")
    func quickEnvelopeCompilesStructuredState() {
        let envelope = BASReferencePromptBuilder.primaryEnvelope(
            BASPrimaryRefinementPromptRequest(
                kind: TestKind.quick,
                modeTitle: "Quick",
                entryContext: "Buy",
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

        #expect(envelope.payload.contains("\"mode\":\"Quick\""))
        #expect(envelope.payload.contains("\"entry_context\":\"Buy\""))
        #expect(envelope.payload.contains("\"host_note\":\"Not provided.\""))
        #expect(envelope.payload.contains("Present view: You want a little relief."))
        #expect(envelope.payload.contains("Alternate actions: Decide tomorrow"))
        #expect(envelope.assembly.kernelSnapshot.truthState == nil)
    }

    @Test("selection envelope remains available through the generic facade")
    func selectionEnvelopeUsesGenericFacade() {
        let envelope = BASReferencePromptBuilder.selectionEnvelope(
            BASSelectionPromptRequest(
                kind: TestKind.reminder,
                modeTitle: "Primary",
                entryContext: "Buy",
                activePrompt: "I want to buy this tonight.",
                candidateTexts: [
                    "Hold it until tomorrow morning.",
                    "Put it in the holding lane and sleep on it."
                ],
                selectionSurfaceMode: .primary
            )
        )

        #expect(envelope.kind == .reminder)
        #expect(envelope.assembly.kernelSnapshot.truthState?.sessionFacts["surface_mode"] == "primary")
    }

    @Test("reminder envelope clips candidates and suppresses structured truth block")
    func reminderEnvelopeClipsCandidatesAndSuppressesTruthBlock() {
        let envelope = BASReferencePromptBuilder.reminderEnvelope(
            BASReminderSelectionPromptRequest(
                kind: TestKind.reminder,
                modeTitle: "Quick",
                scenarioTitle: "Buy",
                prompt: "I want to buy this tonight.",
                candidateTexts: [
                    "Hold it until tomorrow morning.",
                    "Put it in the holding lane and sleep on it.",
                    "Wait for the weekend before deciding.",
                    "This fourth candidate should be clipped."
                ],
                reminderSurfaceMode: .quick
            )
        )

        #expect(envelope.payload.contains("\"candidate_count\":3"))
        #expect(envelope.payload.contains("0: Hold it until tomorrow morning."))
        #expect(envelope.payload.contains("2: Wait for the weekend before deciding."))
        #expect(!envelope.payload.contains("This fourth candidate should be clipped."))
        #expect(!envelope.payload.contains("STRUCTURED_TRUTH_JSON:"))
        #expect(envelope.assembly.kernelSnapshot.truthState?.mode == "reminder")
    }

    @Test("reference prompt builder honors injected host presentation behavior")
    func referencePromptBuilderHonorsInjectedBehavior() {
        let behavior = BASReferencePromptBehavior(
            presentationBehavior: BASPromptPresentationBehavior(
                sharedPrelude: "Host immutable prefix.",
                adaptivePrefixByKindID: [
                    BASSemanticTaskKind.primaryID: "Host quick adaptive prefix."
                ]
            ),
            frontstageBehavior: BASFrontstagePresentationBehavior(
                focusGoalsByKindID: [
                    BASAdaptiveTraceKind.primaryID: "Host quick focus goal."
                ]
            ),
            structuredTruthBehavior: BASStructuredTruthBehavior(
                modeNamesByKindID: [
                    BASAdaptiveTraceKind.primaryID: "before.quick"
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

        let envelope = BASReferencePromptBuilder.quickEnvelope(
            BASQuickRefinementPromptRequest(
                kind: TestKind.quick,
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
                brainState: hostBrainState()
            ),
            behavior: behavior
        )

        #expect(envelope.layers.immutablePrefix == "Host immutable prefix.")
        #expect(envelope.layers.adaptivePrefix == "Host quick adaptive prefix.")
        #expect(envelope.payload.contains("\"scenario\":\"Buy\""))
        #expect(envelope.payload.contains("\"note\":\"Not provided.\""))
        #expect(envelope.payload.contains("Current perspective: You want a little relief."))
        #expect(envelope.payload.contains("Secondary actions: Decide tomorrow"))
        #expect(envelope.payload.contains("Keep the host-specific viewpoint framing."))
        #expect(envelope.budget.targetCharacters == 900)
        #expect(envelope.frontstageState.focusGoal == "Host quick focus goal.")
        #expect(envelope.assembly.kernelSnapshot.truthState?.mode == "before.quick")
        #expect(envelope.assembly.kernelSnapshot.truthState?.personaRules.contains("Keep the interruption short, calm, and non-shaming.") == true)
    }

    private func hostBrainState() -> BASDecisionBrainState {
        BASDecisionBrainState(
            profileCore: ["Keep the language steady."],
            activeGoals: ["Protect tomorrow's clarity."],
            relevantMemories: ["Similar loops softened after a pause."],
            sessionBiases: ["Keep it short."],
            retrievalTags: ["pause"],
            reactionWeights: BASReactionWeights.defaults(forModeName: BASDecisionMode.quick.rawValue),
            loadedAt: .now
        )
    }
}
