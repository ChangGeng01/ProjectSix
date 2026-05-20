import XCTest
@testable import Before

@MainActor
final class SupportRequestFactoryTests: XCTestCase {
    func testQuickFactoryPreservesQuickDraftAndUsesSupportKind() throws {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Should I buy this tonight?")
        session.scenario = .buy
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        let result = QuickCheckResult(
            currentPerspective: "You want a fast reward.",
            afterPerspective: "You usually cool on it by tomorrow.",
            verdict: .notRecommended,
            primaryAction: .decideTomorrow,
            secondaryActions: [.goAheadAnyway]
        )

        let request = SupportRequestFactory.makeQuickRequest(from: session, result: result)

        XCTAssertEqual(request.kind, .holdMe10Minutes)
        XCTAssertEqual(request.mode, .quick)
        XCTAssertEqual(try XCTUnwrap(request.draft).scenarioRaw, ScenarioType.buy.rawValue)
        XCTAssertTrue(request.message.contains("Should I buy this tonight?"))
    }

    func testBalanceFactoryCreatesReusableDecisionDraft() throws {
        let session = BalanceBoardSession(entrySource: .shortcut, prompt: "Should I take this contract?")
        session.desire = "I want the money."
        session.concern = "I may burn out."
        session.constraint = "The timeline is tight."
        session.longTerm = "It could crowd out better work."

        let request = SupportRequestFactory.makeBalanceRequest(from: session)

        XCTAssertEqual(request.kind, .helpMeJudgeThis)
        XCTAssertEqual(request.mode, .balance)
        XCTAssertEqual(try XCTUnwrap(request.draft).constraint, "The timeline is tight.")
    }

    func testMirrorFactoryCreatesMirrorLinkedSupportRequest() throws {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I keep staying in this relationship?")
        session.emotion = "Drained"
        session.relationship = "The same boundary keeps getting crossed."
        session.reality = "We still live together."
        session.longTerm = "I keep shrinking."
        session.selfLens = "I do not like who I become here."

        let request = SupportRequestFactory.makeMirrorRequest(from: session)

        XCTAssertEqual(request.kind, .iAmGettingBlurry)
        XCTAssertEqual(request.mode, .mirror)
        XCTAssertEqual(try XCTUnwrap(request.draft).selfLens, "I do not like who I become here.")
    }
}
