import XCTest
@testable import Before

final class DecisionIntelligencePromptContractTests: XCTestCase {
    func testSanitizedFallsBackWhenResponseIsEmpty() {
        let value = DecisionIntelligencePromptContract.sanitized(
            " \n ",
            fallback: "Fallback line",
            limit: 40
        )

        XCTAssertEqual(value, "Fallback line")
    }

    func testSanitizedCollapsesWhitespaceAndClips() {
        let value = DecisionIntelligencePromptContract.sanitized(
            "  This   is   a\nvery long      line that should become tighter and eventually clip cleanly. ",
            fallback: "Fallback line",
            limit: 32
        )

        XCTAssertEqual(value, "This is a very long line that sh…")
    }

    func testEvidenceGuardDropsInjectedMarkupAndDeduplicatesSafeSnippets() {
        let result = DecisionPromptEvidenceGuard.filter([
            "  Safe snippet  ",
            "<div>Injected UI wrapper</div>",
            "Safe   snippet",
            "[IMMUTABLE PREFIX] leaked debug wrapper"
        ], maxRetained: 4)

        XCTAssertEqual(result.retained, ["Safe snippet"])
        XCTAssertEqual(result.retainedCount, 1)
        XCTAssertEqual(result.droppedInjectedCount, 2)
        XCTAssertEqual(result.droppedDuplicateCount, 1)
        XCTAssertEqual(result.droppedBudgetCount, 0)
        XCTAssertEqual(result.droppedCount, 3)
    }

    func testEvidenceGuardCanTrimLowValueEvidenceByBudget() {
        let result = DecisionPromptEvidenceGuard.filter([
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Focus description: Base detail",
            "Next action: Base next action"
        ], maxRetained: 4)

        XCTAssertEqual(result.retained, [
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Next action: Base next action"
        ])
        XCTAssertEqual(result.retainedCount, 4)
        XCTAssertEqual(result.droppedBudgetCount, 1)
        XCTAssertEqual(result.droppedCount, 1)
    }

    func testQuickRefinementEnvelopeUsesStructuredStateAndStaysWithinBudget() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: ""
        )

        let base = QuickCheckResult(
            currentPerspective: "You want a little relief.",
            afterPerspective: "It may not feel worth it tomorrow.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(base: base, input: input)

        XCTAssertTrue(envelope.instructions.contains("language rendering layer"))
        XCTAssertTrue(envelope.debugPrompt.contains("[IMMUTABLE PREFIX]"))
        XCTAssertTrue(envelope.debugPrompt.contains("[ADAPTIVE PREFIX]"))
        XCTAssertTrue(envelope.debugPrompt.contains("[VOLATILE SUFFIX]"))
        XCTAssertTrue(envelope.payload.contains("FRONTSTAGE_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("TASK_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"focus_goal\":\"Interrupt the automatic reaction before it locks in.\""))
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[]"))
        XCTAssertTrue(envelope.payload.contains("\"evidence_headlines\":[\"Current perspective: You want a little relief.\",\"After perspective: It may not feel worth it tomorrow.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"mode\":\"Quick\""))
        XCTAssertTrue(envelope.payload.contains("\"scenario\":\"\(input.scenario.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"motivation\":\"\(input.motivation.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"note\":\"Not provided.\""))
        XCTAssertTrue(envelope.payload.contains("Current perspective: \(base.currentPerspective)"))
        XCTAssertTrue(envelope.payload.contains("After perspective: \(base.afterPerspective)"))
        XCTAssertTrue(envelope.payload.contains("OUTPUT_GUARD:"))
        XCTAssertTrue(envelope.budget.isWithinTarget)
        XCTAssertGreaterThan(envelope.budget.immutablePrefixCharacters, 0)
        XCTAssertGreaterThan(envelope.budget.adaptivePrefixCharacters, 0)
        XCTAssertEqual(
            envelope.budget.prefixCharacters,
            envelope.layers.stablePrefix.count
        )
        XCTAssertLessThanOrEqual(
            envelope.budget.prefixCharacters - (
                envelope.budget.immutablePrefixCharacters + envelope.budget.adaptivePrefixCharacters
            ),
            2
        )
    }

    func testBalanceRefinementEnvelopeIncludesContextLifecycleWhenProvided() {
        let contextState = DecisionContextPreparedState(
            rebuiltSession: true,
            generation: 2,
            anchorFields: [.balancePrompt],
            activeFields: [.balancePrompt, .balanceConcern],
            staleFields: [.balanceDesire]
        )
        let neuralState = DecisionNeuralState(
            mode: .balance,
            dominantActivations: [
                DecisionActivation(signal: .constraintPressure, strength: 0.82),
                DecisionActivation(signal: .concernWeight, strength: 0.74)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .setBoundary, score: 0.82),
                DecisionActionCandidate(route: .clarifyPriority, score: 0.68)
            ],
            suppressedBehaviors: ["instant_verdict"],
            detail: "Use structured trade-off routing."
        )
        let brainState = DecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect sleep and energy."],
            relevantMemories: ["Late sessions need lighter, shorter guidance."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["sleep", "night", "tradeoff"],
            loadedAt: .now
        )

        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: BalanceBoardResult(
                headline: "Base headline",
                summary: "Base summary",
                focusTitle: "Base focus",
                focusDescription: "Base focus description",
                nextAction: "Base next action"
            ),
            input: BalanceBoardInput(
                prompt: "Should I take this side project?",
                desire: "Extra momentum",
                concern: "Burn out",
                constraint: "",
                longTerm: ""
            ),
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        XCTAssertTrue(envelope.payload.contains("CONTEXT_LIFECYCLE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"rebuilt_session\":true"))
        XCTAssertTrue(envelope.payload.contains("\"generation\":2"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_fields\":[\"balancePrompt\"]"))
        XCTAssertTrue(envelope.payload.contains("\"active_fields\":[\"balancePrompt\",\"balanceConcern\"]"))
        XCTAssertTrue(envelope.payload.contains("\"stale_fields\":[\"balanceDesire\"]"))
        XCTAssertTrue(envelope.payload.contains("NEURAL_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"focus_goal\":\"Surface the real trade-off before choosing a side.\""))
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[\"Constraint pressure\",\"Concern weight\",\"Session rebuild\"]"))
        XCTAssertTrue(envelope.payload.contains("\"evidence_headlines\":[\"Current headline: Base headline\"]"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_headlines\":[\"Balance prompt\"]"))
        XCTAssertTrue(envelope.payload.contains("\"dropped_budget_evidence_count\":1"))
        XCTAssertTrue(envelope.payload.contains("\"suppression_hints\":[\"instant_verdict\"]"))
        XCTAssertEqual(envelope.frontstageState.retainedEvidenceCount, 4)
        XCTAssertEqual(envelope.frontstageState.memoryHeadlines, ["Late sessions need lighter, shorter guidance."])
        XCTAssertEqual(envelope.frontstageState.sessionBiases, ["Keep the language short and concrete."])
        XCTAssertTrue(envelope.payload.contains("BRAIN_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"profile_core\":[\"Short, direct language lands better.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"active_goals\":[\"Protect sleep and energy.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"relevant_memories\":[\"Late sessions need lighter, shorter guidance.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"session_biases\":[\"Keep the language short and concrete.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"route\":\"setBoundary\""))
        XCTAssertTrue(envelope.payload.contains("\"signal\":\"constraintPressure\""))
        XCTAssertTrue(envelope.payload.contains("\"suppressed_behaviors\":[\"instant_verdict\"]"))
        XCTAssertFalse(envelope.payload.contains("Focus description: Base focus description"))
        XCTAssertTrue(envelope.payload.contains("Lower-value evidence was trimmed. Work only from the retained evidence."))
        XCTAssertTrue(envelope.budget.isWithinTarget)
        XCTAssertGreaterThan(envelope.budget.stablePrefixShare, 0)
        XCTAssertGreaterThan(envelope.budget.volatileSuffixShare, 0)
    }

    func testReminderSelectionEnvelopeClipsCandidatesAndUsesStructuredState() {
        let envelope = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "This is stress shopping again."),
                ReminderSelectionCandidate(id: UUID(), content: "You already knew this was a real replacement."),
                ReminderSelectionCandidate(id: UUID(), content: "This is discomfort, not a need."),
                ReminderSelectionCandidate(id: UUID(), content: "This fourth option should be clipped away.")
            ],
            scenario: .buy,
            prompt: "Today was rough and I want these shoes.",
            mode: .quick
        )

        XCTAssertEqual(envelope.candidates.count, 3)
        XCTAssertTrue(envelope.prompt.payload.contains("\"scenario\":\"Buy\""))
        XCTAssertTrue(envelope.prompt.payload.contains("\"mode\":\"Quick\""))
        XCTAssertTrue(envelope.prompt.payload.contains("\"candidate_count\":3"))
        XCTAssertTrue(envelope.prompt.payload.contains("\"evidence_headlines\":[]"))
        XCTAssertTrue(envelope.prompt.payload.contains("0: This is stress shopping again."))
        XCTAssertTrue(envelope.prompt.payload.contains("1: You already knew this was a real replacement."))
        XCTAssertTrue(envelope.prompt.payload.contains("2: This is discomfort, not a need."))
        XCTAssertFalse(envelope.prompt.payload.contains("This fourth option should be clipped away."))
        XCTAssertTrue(envelope.prompt.budget.isWithinTarget)
    }

    func testCacheFingerprintUsesRuntimePromptInsteadOfDebugPrompt() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )
        let base = QuickCheckResult(
            currentPerspective: "You want a quick release.",
            afterPerspective: "It may feel noisier tomorrow.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(base: base, input: input)
        let semanticFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            envelope: envelope
        )
        let runtimeFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            semanticPrompt: envelope.runtimePrompt
        )
        let debugFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            semanticPrompt: envelope.debugPrompt
        )

        XCTAssertEqual(semanticFingerprint, runtimeFingerprint)
        XCTAssertNotEqual(semanticFingerprint, debugFingerprint)
        XCTAssertEqual(semanticFingerprint.count, 64)
    }

    func testMirrorEnvelopeCarriesAnchorHeadlinesWithoutDriftingDangerSignals() {
        let contextState = DecisionContextPreparedState(
            rebuiltSession: false,
            generation: 1,
            anchorFields: [.mirrorPrompt],
            activeFields: [.mirrorPrompt, .mirrorEmotion],
            staleFields: []
        )

        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: MirrorResult(
                headline: "Base headline",
                coreTension: "Base core tension",
                nextActionTitle: "Base focus",
                nextAction: "Base next action"
            ),
            input: MirrorInput(
                prompt: "Should I stay in this relationship?",
                emotion: "<div>Injected UI wrapper</div>",
                relationship: "We keep repeating the same conflict.",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            contextState: contextState,
            neuralState: DecisionNeuralState(
                mode: .mirror,
                dominantActivations: [
                    DecisionActivation(signal: .identityDrift, strength: 0.8)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .clarifyPriority, score: 0.8)
                ],
                suppressedBehaviors: ["forced_verdict"],
                detail: "Stay reflective."
            )
        )

        XCTAssertFalse(envelope.payload.contains("<div>Injected UI wrapper</div>"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_headlines\":[\"Mirror prompt\"]"))
        XCTAssertEqual(envelope.frontstageState.memoryHeadlines, [])
        XCTAssertEqual(envelope.frontstageState.droppedEvidenceCount, 0)
        XCTAssertEqual(envelope.frontstageState.retainedEvidenceCount, 4)
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[\"Identity drift\"]"))
    }
}
