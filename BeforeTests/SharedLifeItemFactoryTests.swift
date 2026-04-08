import XCTest
@testable import Before

@MainActor
final class SharedLifeItemFactoryTests: XCTestCase {
    func testQuickFactoryPreservesQuickDraft() throws {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Should I order this tonight?")
        session.scenario = .eat
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        let item = SharedLifeItemFactory.makeQuickItem(from: session)

        XCTAssertEqual(item.mode, .quick)
        XCTAssertEqual(item.prompt, "Should I order this tonight?")
        XCTAssertEqual(item.title, "Eat decision")
        XCTAssertFalse(item.detail.contains("order this tonight"))
        XCTAssertEqual(try XCTUnwrap(item.draft).scenarioRaw, ScenarioType.eat.rawValue)
    }

    func testBalanceFactoryPreservesTradeoffFields() throws {
        let session = BalanceBoardSession(entrySource: .app, prompt: "Should we take the cheaper option?")
        session.concern = "It may create more friction later."

        let item = SharedLifeItemFactory.makeBalanceItem(from: session)

        XCTAssertEqual(item.mode, .balance)
        XCTAssertEqual(item.title, "Shared trade-off")
        XCTAssertEqual(item.detail, "Use shared rules to name what matters most here.")
        XCTAssertEqual(try XCTUnwrap(item.draft).concern, "It may create more friction later.")
    }

    func testMirrorFactoryPreservesMirrorDraft() throws {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should we keep living this way?")
        session.reality = "The schedule is breaking both of us."

        let item = SharedLifeItemFactory.makeMirrorItem(from: session)

        XCTAssertEqual(item.mode, .mirror)
        XCTAssertEqual(item.title, "Shared mirror")
        XCTAssertEqual(item.detail, "This needs a slower shared read.")
        XCTAssertEqual(try XCTUnwrap(item.draft).reality, "The schedule is breaking both of us.")
    }
}
