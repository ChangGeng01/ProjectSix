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

    @Test("quick envelope compiles structured state and secondary actions")
    func quickEnvelopeCompilesStructuredState() {
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
                secondaryActionTitles: ["Decide tomorrow"]
            )
        )

        #expect(envelope.payload.contains("\"mode\":\"Quick\""))
        #expect(envelope.payload.contains("\"note\":\"Not provided.\""))
        #expect(envelope.payload.contains("Current perspective: You want a little relief."))
        #expect(envelope.payload.contains("Secondary actions: Decide tomorrow"))
        #expect(envelope.assembly.kernelSnapshot.truthState == nil)
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
                    "Put it in Tomorrow Box and sleep on it.",
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
}
