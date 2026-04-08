import XCTest
@testable import Before

final class DecisionReviewEngineTests: XCTestCase {
    func testQuickSummaryHighlightsDominantScenarioAndVerdict() {
        let events = [
            CheckEvent(
                scenario: .scroll,
                motivation: .stressed,
                expectedOutcome: .regret,
                controlLevel: .maybe,
                note: "",
                currentPerspective: "",
                afterPerspective: "",
                verdict: .pause,
                finalAction: .wait90s,
                entrySource: .app
            ),
            CheckEvent(
                scenario: .scroll,
                motivation: .reward,
                expectedOutcome: .unsure,
                controlLevel: .maybe,
                note: "",
                currentPerspective: "",
                afterPerspective: "",
                verdict: .pause,
                finalAction: .wait90s,
                entrySource: .app
            ),
            CheckEvent(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .yes,
                note: "",
                currentPerspective: "",
                afterPerspective: "",
                verdict: .goAhead,
                finalAction: .goAheadAnyway,
                entrySource: .app
            )
        ]

        let summary = DecisionReviewEngine.summaries(quick: events, balance: [], mirror: []).first

        XCTAssertEqual(summary?.mode, .quick)
        XCTAssertEqual(summary?.count, 3)
        XCTAssertEqual(
            summary?.detail,
            "Scroll shows up most, and pause is your most common fast call."
        )
    }

    func testInsightsIncludeBalanceAndTomorrowSignals() {
        let balanceRecords = [
            BalanceDecisionRecord(
                prompt: "Should I take this trip?",
                desire: "Change",
                concern: "Money",
                constraint: "Budget",
                longTerm: "I want momentum",
                focusTitle: "Budget pressure",
                focusSummary: "Money is the first trade-off to settle.",
                nextAction: "Cut one non-essential layer first.",
                entrySource: .app
            ),
            BalanceDecisionRecord(
                prompt: "Should I upgrade my setup?",
                desire: "Speed",
                concern: "Cash flow",
                constraint: "Budget",
                longTerm: "I want room to build",
                focusTitle: "Budget pressure",
                focusSummary: "Money is still the tightest axis.",
                nextAction: "Choose the cheapest strong option.",
                entrySource: .app
            )
        ]

        let insights = DecisionReviewEngine.insights(
            quick: [],
            balance: balanceRecords,
            mirror: [],
            tomorrowCount: 2
        )

        XCTAssertTrue(insights.contains(where: { $0.title == "Budget pressure keeps taking the lead." }))
        XCTAssertTrue(insights.contains(where: { $0.title == "Tomorrow Box is holding 2 decisions." }))
    }

    func testMirrorSummaryHighlightsRecurringActionTitle() {
        let records = [
            MirrorDecisionRecord(
                prompt: "Should I stay?",
                emotion: "Tired",
                relationship: "Boundaries keep slipping",
                reality: "We share a lease",
                longTerm: "I keep shrinking",
                selfLens: "I do not trust my no",
                coreTension: "You are not just asking whether to stay. You are asking what it costs to keep overriding yourself.",
                nextActionTitle: "Name the boundary",
                nextAction: "Write the one limit you cannot keep negotiating away.",
                entrySource: .app
            ),
            MirrorDecisionRecord(
                prompt: "Should I keep this role?",
                emotion: "Drained",
                relationship: "Work asks for more than it gives back",
                reality: "I still need the income",
                longTerm: "I am flattening out",
                selfLens: "I keep rationalizing it",
                coreTension: "This is not only about stress. It is about what staying keeps normalizing.",
                nextActionTitle: "Name the boundary",
                nextAction: "Write the first condition that would need to change.",
                entrySource: .app
            )
        ]

        let summary = DecisionReviewEngine.summaries(quick: [], balance: [], mirror: records).first

        XCTAssertEqual(summary?.mode, .mirror)
        XCTAssertEqual(summary?.detail, "Name the boundary keeps surfacing when the question gets heavier.")
    }
}
