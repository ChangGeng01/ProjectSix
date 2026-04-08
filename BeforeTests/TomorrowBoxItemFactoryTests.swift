import XCTest
@testable import Before

@MainActor
final class TomorrowBoxItemFactoryTests: XCTestCase {
    func testQuickFactoryFallsBackToScenarioTitleAndNormalizesDueDate() {
        let calendar = fixedCalendar()
        let referenceDate = Date(timeIntervalSince1970: 1_712_597_600) // 2024-04-10 12:00 UTC
        let eventID = UUID()

        let session = QuickCheckSession(entrySource: .app)
        session.scenario = .scroll

        let result = QuickCheckResult(
            currentPerspective: "You want relief fast.",
            afterPerspective: "You usually feel flatter after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let item = TomorrowBoxItemFactory.makeQuickItem(
            from: session,
            result: result,
            eventID: eventID,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(item.mode, .quick)
        XCTAssertEqual(item.title, "Scroll later")
        XCTAssertEqual(item.detail, "You usually feel flatter after.")
        XCTAssertEqual(item.linkedCheckEventID, eventID)
        XCTAssertEqual(
            item.dueAt,
            BeforePolicy.Notifications.normalizedReminderDate(after: referenceDate, calendar: calendar)
        )
        XCTAssertEqual(item.draft?.scenarioRaw, ScenarioType.scroll.rawValue)
    }

    func testBalanceFactoryTrimsPromptAndKeepsFocusSummary() throws {
        let session = BalanceBoardSession(entrySource: .shortcut, prompt: "  Should I take this dinner plan?  ")
        session.desire = "I want the easy option."
        session.concern = "I do not want to overextend."
        session.constraint = "This week is already full."
        session.longTerm = "I will feel stretched tomorrow too."
        session.evaluate()
        let result = try XCTUnwrap(session.result)

        let item = TomorrowBoxItemFactory.makeBalanceItem(
            from: session,
            result: result
        )

        XCTAssertEqual(item.mode, .balance)
        XCTAssertEqual(item.prompt, "Should I take this dinner plan?")
        XCTAssertEqual(item.title, "Should I take this dinner plan?")
        XCTAssertEqual(item.entrySource, .shortcut)
        XCTAssertEqual(item.detail, session.result?.summary)
        XCTAssertEqual(item.draft?.constraint, "This week is already full.")
    }

    func testMirrorFactoryFromRecordPreservesPromptAndDraft() {
        let record = MirrorDecisionRecord(
            prompt: "  Should I keep staying here?  ",
            emotion: "Exhausted",
            relationship: "The same disrespect keeps coming back.",
            reality: "The lease still ties us together.",
            longTerm: "I keep shrinking in this shape.",
            selfLens: "I do not feel like myself.",
            coreTension: "This keeps asking you to shrink.",
            nextActionTitle: "Write the boundary",
            nextAction: "Name what you cannot keep surrendering.",
            entrySource: .app
        )

        let item = TomorrowBoxItemFactory.makeMirrorItem(from: record, entrySource: .spotlight)

        XCTAssertEqual(item.mode, .mirror)
        XCTAssertEqual(item.prompt, "Should I keep staying here?")
        XCTAssertEqual(item.title, "Should I keep staying here?")
        XCTAssertEqual(item.detail, "This keeps asking you to shrink.")
        XCTAssertEqual(item.entrySource, .spotlight)
        XCTAssertEqual(item.draft?.selfLens, "I do not feel like myself.")
    }

    func testSupportFactoryCarriesDraftAndModeIntoTomorrowBox() throws {
        let request = SupportRequest(
            kind: .helpMeJudgeThis,
            message: "Help me sort this out.",
            mode: .balance,
            draft: TomorrowBoxDraft(
                prompt: "Should I take the offer?",
                concern: "The hours look rough.",
                constraint: "The salary is better."
            )
        )

        let item = try XCTUnwrap(TomorrowBoxItemFactory.makeSupportItem(from: request))

        XCTAssertEqual(item.mode, .balance)
        XCTAssertEqual(item.title, "Help me sort this out.")
        XCTAssertEqual(item.prompt, "Should I take the offer?")
        XCTAssertEqual(item.draft?.concern, "The hours look rough.")
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
