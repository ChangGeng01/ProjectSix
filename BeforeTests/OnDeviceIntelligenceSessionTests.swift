import XCTest
@testable import Before

@MainActor
final class OnDeviceIntelligenceSessionTests: XCTestCase {
    func testQuickSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = QuickCheckSession(entrySource: .app)
        session.scenario = .buy
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "long day"

        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "long day"
        )

        let expected = DecisionIntelligenceCoordinator.quickResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result?.verdict, expected.verdict)
        XCTAssertEqual(session.result?.primaryAction, expected.primaryAction)
        XCTAssertEqual(session.result?.secondaryActions, expected.secondaryActions)
        XCTAssertEqual(session.result?.currentPerspective, expected.currentPerspective)
        XCTAssertEqual(session.result?.afterPerspective, expected.afterPerspective)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    func testBalanceSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = BalanceBoardSession(entrySource: .app, prompt: "Should I take this freelance job?")
        session.desire = "I want the extra money."
        session.concern = "I do not want to burn out."
        session.constraint = "My week is already full."

        let input = BalanceBoardInput(
            prompt: "Should I take this freelance job?",
            desire: "I want the extra money.",
            concern: "I do not want to burn out.",
            constraint: "My week is already full.",
            longTerm: ""
        )

        let expected = DecisionIntelligenceCoordinator.balanceResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result, expected)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    func testMirrorSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I stay in this relationship?")
        session.emotion = "I feel tired and sad."
        session.relationship = "We keep repeating the same argument."
        session.reality = "We live far apart and avoid hard conversations."

        let input = MirrorInput(
            prompt: "Should I stay in this relationship?",
            emotion: "I feel tired and sad.",
            relationship: "We keep repeating the same argument.",
            reality: "We live far apart and avoid hard conversations.",
            longTerm: "",
            selfLens: ""
        )

        let expected = DecisionIntelligenceCoordinator.mirrorResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result, expected)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    private var offPreferences: BeforePreferences {
        BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .off
        )
    }
}
