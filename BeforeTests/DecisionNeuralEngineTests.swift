import XCTest
@testable import Before

final class DecisionNeuralEngineTests: XCTestCase {
    func testQuickStatePrioritizesPauseRoutesWhenRegretAndLowControlAreHigh() {
        let state = DecisionNeuralEngine.quickState(
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .avoiding,
                expectedOutcome: .regret,
                controlLevel: .no,
                note: "I am exhausted and want to escape."
            )
        )

        XCTAssertEqual(state.mode, .quick)
        XCTAssertEqual(state.dominantActivations.first?.signal, .urgency)
        XCTAssertTrue(state.candidateActions.contains(where: { $0.route == .stepAway }))
        XCTAssertTrue(state.suppressedBehaviors.contains("long_explanation"))
    }

    func testBalanceStateSurfacesConstraintPressureAndPriorityClarification() {
        let state = DecisionNeuralEngine.balanceState(
            input: BalanceBoardInput(
                prompt: "Should I take this side project?",
                desire: "Extra momentum",
                concern: "I might burn out.",
                constraint: "My budget and schedule are already tight.",
                longTerm: "I do not want to drift."
            )
        )

        XCTAssertEqual(state.mode, .balance)
        XCTAssertTrue(state.dominantActivations.contains(where: { $0.signal == .constraintPressure }))
        XCTAssertEqual(state.dominantAction, .clarifyPriority)
        XCTAssertTrue(state.suppressedBehaviors.contains("instant_verdict"))
    }

    func testMirrorStatePrefersBoundaryProtectionWhenSelfIsShrinking() {
        let state = DecisionNeuralEngine.mirrorState(
            input: MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel exhausted and afraid.",
                relationship: "The same disrespectful pattern keeps repeating.",
                reality: "Moving out would be expensive.",
                longTerm: "I am scared of regret and loss.",
                selfLens: "I feel smaller and less like myself."
            )
        )

        XCTAssertEqual(state.mode, .mirror)
        XCTAssertTrue(state.dominantActivations.contains(where: { $0.signal == .boundaryRisk }))
        XCTAssertEqual(state.dominantAction, .setBoundary)
        XCTAssertTrue(state.suppressedBehaviors.contains("yes_no_verdict"))
    }
}
