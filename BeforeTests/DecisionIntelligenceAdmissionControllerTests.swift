import XCTest
@testable import Before

final class DecisionIntelligenceAdmissionControllerTests: XCTestCase {
    func testQuickAdmissionAllowsComfortableBudget() {
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: QuickCheckResult(
                currentPerspective: "You want relief.",
                afterPerspective: "It may pass quickly.",
                verdict: .pause,
                primaryAction: .wait90s,
                secondaryActions: []
            ),
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "Short note."
            )
        )

        let decision = DecisionIntelligenceAdmissionController.decide(for: envelope)

        XCTAssertTrue(decision.isAllowed)
        XCTAssertNil(decision.skipReason)
    }

    func testQuickAdmissionSkipsWhenTemplateAlreadyCoversTheTurn() {
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: QuickCheckResult(
                currentPerspective: "You want relief.",
                afterPerspective: "It may pass quickly.",
                verdict: .pause,
                primaryAction: .wait90s,
                secondaryActions: []
            ),
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: ""
            )
        )

        let decision = DecisionIntelligenceAdmissionController.decide(for: envelope)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.skipReason, .templateAlreadySufficient)
    }

    func testQuickAdmissionSkipsWhenPromptBudgetIsExceeded() {
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: QuickCheckResult(
                currentPerspective: "You want relief.",
                afterPerspective: "It may pass quickly.",
                verdict: .pause,
                primaryAction: .wait90s,
                secondaryActions: []
            ),
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "Short note."
            ),
            neuralState: DecisionNeuralState(
                mode: .quick,
                dominantActivations: [
                    DecisionActivation(signal: .urgency, strength: 0.9)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .waitBuffer, score: 0.9)
                ],
                suppressedBehaviors: Array(repeating: "long_explanation", count: 80),
                detail: String(repeating: "high-pressure-", count: 140)
            )
        )

        let decision = DecisionIntelligenceAdmissionController.decide(for: envelope)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.skipReason, .budgetExceeded)
        XCTAssertEqual(decision.pressure, .severe)
    }

    func testReminderAdmissionSkipsWhenThereIsOnlyOneCandidate() {
        let selection = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "Keep it simple.")
            ],
            scenario: .buy,
            prompt: "I want this now.",
            mode: .quick
        )

        let decision = DecisionIntelligenceAdmissionController.decide(
            for: selection.prompt,
            reminderCandidateCount: selection.candidates.count
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.skipReason, .insufficientReminderChoice)
    }

    func testBalanceAdmissionSkipsWhenThereIsNotEnoughOpenTextMaterial() {
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: BalanceBoardResult(
                headline: "Base headline",
                summary: "Base summary",
                focusTitle: "Base focus",
                focusDescription: "Base description",
                nextAction: "Base next action"
            ),
            input: BalanceBoardInput(
                prompt: "Should I do it?",
                desire: "",
                concern: "",
                constraint: "Time is tight.",
                longTerm: ""
            )
        )

        let decision = DecisionIntelligenceAdmissionController.decide(for: envelope)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.skipReason, .insufficientSourceMaterial)
    }

    func testTestingStubAdmissionAlwaysAllowsPrompt() {
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: BalanceBoardResult(
                headline: "Base headline",
                summary: "Base summary",
                focusTitle: "Base focus",
                focusDescription: "Base description",
                nextAction: "Base next action"
            ),
            input: BalanceBoardInput(
                prompt: "Should I take this side project?",
                desire: "Momentum",
                concern: "Burnout",
                constraint: String(repeating: "constraint-", count: 80),
                longTerm: String(repeating: "future-", count: 80)
            ),
            neuralState: DecisionNeuralState(
                mode: .balance,
                dominantActivations: [
                    DecisionActivation(signal: .constraintPressure, strength: 0.9)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .setBoundary, score: 0.9)
                ],
                suppressedBehaviors: Array(repeating: "long_explanation", count: 80),
                detail: String(repeating: "pressure-", count: 120)
            )
        )

        let decision = DecisionIntelligenceAdmissionController.testingStubDecision(for: envelope)

        XCTAssertTrue(decision.isAllowed)
        XCTAssertNil(decision.skipReason)
    }
}
