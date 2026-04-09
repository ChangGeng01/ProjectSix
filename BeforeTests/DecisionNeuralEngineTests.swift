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

    func testQuickStateUsesBrainWeightsToFavorInterruptiveRoutes() {
        var weights = DecisionReactionWeights.defaults(for: .quick)
        weights.lowCognitiveLoad = 0.94
        weights.interruptiveActionBias = 0.98

        let state = DecisionNeuralEngine.quickState(
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I want a quick hit, but I can still pause."
            ),
            brainState: DecisionBrainState(
                profileCore: ["Keep it short."],
                activeGoals: ["Sleep before midnight"],
                relevantMemories: ["Moving this to tomorrow usually helps."],
                sessionBiases: ["Keep the load light."],
                retrievalTags: ["quick", "buy"],
                reactionWeights: weights,
                loadedAt: .now
            )
        )

        XCTAssertEqual(state.mode, .quick)
        XCTAssertTrue(state.suppressedBehaviors.contains("multi_step_planning"))
        XCTAssertNotNil(state.candidateActions.first(where: { $0.route == .moveToTomorrow }))
        XCTAssertTrue(
            state.candidateActions.first(where: { $0.route == .moveToTomorrow })?.score ?? 0 >=
                state.candidateActions.first(where: { $0.route == .continueMindfully })?.score ?? 1
        )
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

    func testMirrorStateUsesBoundaryBiasToTightenProtectionRoutes() {
        var weights = DecisionReactionWeights.defaults(for: .mirror)
        weights.boundaryNamingBias = 0.96
        weights.lowCognitiveLoad = 0.84

        let state = DecisionNeuralEngine.mirrorState(
            input: MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel exhausted and afraid.",
                relationship: "The same disrespectful pattern keeps repeating.",
                reality: "Moving out would be expensive.",
                longTerm: "I am scared of regret and loss.",
                selfLens: "I feel smaller and less like myself."
            ),
            brainState: DecisionBrainState(
                profileCore: ["Stay honest."],
                activeGoals: ["Stop shrinking myself in love"],
                relevantMemories: ["The pattern keeps repeating."],
                sessionBiases: ["Do not blur boundaries."],
                retrievalTags: ["mirror", "relationship"],
                reactionWeights: weights,
                loadedAt: .now
            )
        )

        XCTAssertEqual(state.mode, .mirror)
        XCTAssertTrue(state.suppressedBehaviors.contains("boundary_blurring"))
        XCTAssertEqual(state.dominantAction, .setBoundary)
        XCTAssertTrue(
            state.candidateActions.first(where: { $0.route == .setBoundary })?.score ?? 0 >=
                state.candidateActions.first(where: { $0.route == .askSecondRead })?.score ?? 1
        )
    }
}
