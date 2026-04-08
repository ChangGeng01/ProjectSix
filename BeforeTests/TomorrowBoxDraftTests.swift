import XCTest
@testable import Before

@MainActor
final class TomorrowBoxDraftTests: XCTestCase {
    func testQuickDraftRestoresSelectedAnswers() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Take a breath first")
        session.scenario = .scroll
        session.motivation = .stressed
        session.expectedOutcome = .regret
        session.controlLevel = .maybe

        let restored = TomorrowBoxDraft.quick(from: session)
            .restoreQuickSession(entrySource: .app)

        XCTAssertEqual(restored.scenario, .scroll)
        XCTAssertEqual(restored.motivation, .stressed)
        XCTAssertEqual(restored.expectedOutcome, .regret)
        XCTAssertEqual(restored.controlLevel, .maybe)
        XCTAssertEqual(restored.note, "Take a breath first")
    }

    func testBalanceDraftRestoresBoardFields() {
        let session = BalanceBoardSession(entrySource: .app, prompt: "Should I take this contract?")
        session.desire = "Momentum"
        session.concern = "Burnout"
        session.constraint = "No spare weekends"
        session.longTerm = "Will this pull me off the main track?"

        let restored = TomorrowBoxDraft.balance(from: session)
            .restoreBalanceSession(entrySource: .app)

        XCTAssertEqual(restored.prompt, "Should I take this contract?")
        XCTAssertEqual(restored.desire, "Momentum")
        XCTAssertEqual(restored.concern, "Burnout")
        XCTAssertEqual(restored.constraint, "No spare weekends")
        XCTAssertEqual(restored.longTerm, "Will this pull me off the main track?")
    }

    func testMirrorDraftRestoresMirrorFields() {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I leave this relationship?")
        session.emotion = "Exhausted"
        session.relationship = "The same boundary keeps breaking"
        session.reality = "We still live together"
        session.longTerm = "I keep shrinking"
        session.selfLens = "I trust myself less"

        let restored = TomorrowBoxDraft.mirror(from: session)
            .restoreMirrorSession(entrySource: .app)

        XCTAssertEqual(restored.prompt, "Should I leave this relationship?")
        XCTAssertEqual(restored.emotion, "Exhausted")
        XCTAssertEqual(restored.relationship, "The same boundary keeps breaking")
        XCTAssertEqual(restored.reality, "We still live together")
        XCTAssertEqual(restored.longTerm, "I keep shrinking")
        XCTAssertEqual(restored.selfLens, "I trust myself less")
    }
}
