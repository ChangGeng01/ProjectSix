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
        XCTAssertTrue(envelope.payload.contains("TASK_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"mode\":\"Quick\""))
        XCTAssertTrue(envelope.payload.contains("\"scenario\":\"\(input.scenario.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"motivation\":\"\(input.motivation.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"note\":\"Not provided.\""))
        XCTAssertTrue(envelope.payload.contains("Current perspective: \(base.currentPerspective)"))
        XCTAssertTrue(envelope.payload.contains("After perspective: \(base.afterPerspective)"))
        XCTAssertTrue(envelope.payload.contains("OUTPUT_GUARD:"))
        XCTAssertTrue(envelope.budget.isWithinTarget)
    }

    func testBalanceRefinementEnvelopeIncludesContextLifecycleWhenProvided() {
        let contextState = DecisionContextPreparedState(
            rebuiltSession: true,
            generation: 2,
            activeFields: [.balancePrompt, .balanceConcern],
            staleFields: [.balanceDesire]
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
            contextState: contextState
        )

        XCTAssertTrue(envelope.payload.contains("CONTEXT_LIFECYCLE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"rebuilt_session\":true"))
        XCTAssertTrue(envelope.payload.contains("\"generation\":2"))
        XCTAssertTrue(envelope.payload.contains("\"active_fields\":[\"balancePrompt\",\"balanceConcern\"]"))
        XCTAssertTrue(envelope.payload.contains("\"stale_fields\":[\"balanceDesire\"]"))
        XCTAssertTrue(envelope.payload.contains("\"stale_field_count\":1"))
        XCTAssertTrue(envelope.budget.isWithinTarget)
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
        XCTAssertTrue(envelope.prompt.payload.contains("0: This is stress shopping again."))
        XCTAssertTrue(envelope.prompt.payload.contains("1: You already knew this was a real replacement."))
        XCTAssertTrue(envelope.prompt.payload.contains("2: This is discomfort, not a need."))
        XCTAssertFalse(envelope.prompt.payload.contains("This fourth option should be clipped away."))
        XCTAssertTrue(envelope.prompt.budget.isWithinTarget)
    }
}
