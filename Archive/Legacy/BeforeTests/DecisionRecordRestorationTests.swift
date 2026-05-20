import XCTest
@testable import Before

@MainActor
final class DecisionRecordRestorationTests: XCTestCase {
    func testCheckEventRestoresEvaluatedQuickSession() {
        let event = CheckEvent(
            scenario: .scroll,
            motivation: .avoiding,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "I am about to keep going.",
            currentPerspective: "You want a little relief.",
            afterPerspective: "You usually feel emptier after.",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )

        let session = event.restoredSession()

        XCTAssertEqual(session.scenario, ScenarioType.scroll)
        XCTAssertEqual(session.motivation, MotivationChoice.avoiding)
        XCTAssertEqual(session.expectedOutcome, OutcomeChoice.regret)
        XCTAssertEqual(session.controlLevel, ControlChoice.maybe)
        XCTAssertEqual(session.note, "I am about to keep going.")
        XCTAssertNotNil(session.result)
    }

    func testBalanceRecordRestoresEvaluatedBoard() {
        let record = BalanceDecisionRecord(
            prompt: "Should I take this plan?",
            desire: "I want the easier option.",
            concern: "I am trying to protect energy.",
            constraint: "The schedule is already full.",
            longTerm: "I will feel stretched all week.",
            focusTitle: "Let reality lead first",
            focusSummary: "This is a trade-off.",
            nextAction: "Write the hard limit first.",
            entrySource: .app
        )

        let session = record.restoredSession()

        XCTAssertEqual(session.prompt, "Should I take this plan?")
        XCTAssertEqual(session.constraint, "The schedule is already full.")
        XCTAssertNotNil(session.result)
    }

    func testMirrorRecordCreatesTomorrowBoxItemWithMirrorMode() {
        let record = MirrorDecisionRecord(
            prompt: "Should I stay in this?",
            emotion: "Hurt",
            relationship: "The pattern keeps repeating.",
            reality: "Housing is tied together.",
            longTerm: "I keep shrinking inside this.",
            selfLens: "I feel less like myself.",
            coreTension: "This may be asking you to stay smaller.",
            nextActionTitle: "Write the boundary",
            nextAction: "Name what you can no longer surrender.",
            entrySource: .app
        )

        let item = record.makeTomorrowBoxItem()

        XCTAssertEqual(item.mode, .mirror)
        XCTAssertEqual(item.prompt, "Should I stay in this?")
        XCTAssertEqual(item.detail, "This may be asking you to stay smaller.")
        XCTAssertNotNil(item.draft)
    }
}
