import XCTest
import BASHostKit
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

    func testQuickProfileIncludesScenarioAndVerdictSections() {
        let eventOne = CheckEvent(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "",
            currentPerspective: "Reward pull",
            afterPerspective: "Likely regret",
            verdict: .pause,
            finalAction: .wait90s,
            reflectionOutcome: .regrettedIt,
            entrySource: .app
        )
        let eventTwo = CheckEvent(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .yes,
            note: "",
            currentPerspective: "Fast relief",
            afterPerspective: "Only brief relief",
            verdict: .pause,
            finalAction: .decideTomorrow,
            reflectionOutcome: .okay,
            entrySource: .app
        )

        let profile = DecisionReviewEngine.profile(
            for: .quick,
            quick: [eventOne, eventTwo],
            balance: [],
            mirror: []
        )

        XCTAssertEqual(profile?.sections.map(\.title), ["Scenarios", "Verdicts", "Reflections"])
        XCTAssertEqual(profile?.sections.first?.rows.first?.title, "Buy")
        XCTAssertEqual(profile?.sections.first?.rows.first?.count, 2)
    }

    func testBalanceProfileIncludesCoreTradeoffSections() {
        let record = BalanceDecisionRecord(
            prompt: "Should I take the contract?",
            desire: "Momentum",
            concern: "Capacity",
            constraint: "Time",
            longTerm: "I do not want to burn out",
            focusTitle: "Capacity pressure",
            focusSummary: "The real question is whether you still have room.",
            nextAction: "Cut one commitment before adding another.",
            entrySource: .app
        )

        let profile = DecisionReviewEngine.profile(
            for: .balance,
            quick: [],
            balance: [record],
            mirror: []
        )

        XCTAssertEqual(
            profile?.sections.map(\.title),
            ["Wants", "Concerns", "Constraints", "Long-term", "Focus titles"]
        )
    }

    func testMirrorProfileIncludesEmotionAndSelfSections() {
        let record = MirrorDecisionRecord(
            prompt: "Should I stay?",
            emotion: "Grief",
            relationship: "The same boundary keeps slipping",
            reality: "We still live together",
            longTerm: "I keep shrinking",
            selfLens: "I do not trust my no",
            coreTension: "This is about what staying keeps teaching you to normalize.",
            nextActionTitle: "Name the boundary",
            nextAction: "Write the one limit you cannot keep negotiating away.",
            entrySource: .app
        )

        let profile = DecisionReviewEngine.profile(
            for: .mirror,
            quick: [],
            balance: [],
            mirror: [record]
        )

        XCTAssertEqual(
            profile?.sections.map(\.title),
            ["Emotions", "Relationship patterns", "Reality", "Long-term", "Self lens", "Mirror actions"]
        )
    }

    func testRecentEntriesForQuickStaySortedNewestFirst() {
        let older = CheckEvent(
            createdAt: Date(timeIntervalSince1970: 100),
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .yes,
            note: "",
            currentPerspective: "Older",
            afterPerspective: "Older detail",
            verdict: .goAhead,
            finalAction: .goAheadAnyway,
            entrySource: .app
        )
        let newer = CheckEvent(
            createdAt: Date(timeIntervalSince1970: 200),
            scenario: .scroll,
            motivation: .stressed,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "",
            currentPerspective: "Newer",
            afterPerspective: "Newer detail",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )

        let entries = DecisionReviewEngine.recentEntries(
            for: .quick,
            quick: [older, newer],
            balance: [],
            mirror: []
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.title, "Newer")
        XCTAssertEqual(entries.first?.detail, "Newer detail")
    }

    func testRecentEntriesForMirrorOnlyIncludeMirrorRecords() {
        let mirror = MirrorDecisionRecord(
            prompt: "Should I leave?",
            emotion: "Numb",
            relationship: "The same pattern keeps coming back",
            reality: "We still share a home",
            longTerm: "I keep disappearing inside this",
            selfLens: "I do not feel like myself",
            coreTension: "This is asking what staying keeps costing you.",
            nextActionTitle: "Write the boundary",
            nextAction: "Name what you cannot keep negotiating away.",
            entrySource: .app
        )

        let entries = DecisionReviewEngine.recentEntries(
            for: .mirror,
            quick: [
                CheckEvent(
                    scenario: .buy,
                    motivation: .reward,
                    expectedOutcome: .regret,
                    controlLevel: .maybe,
                    note: "",
                    currentPerspective: "Quick entry",
                    afterPerspective: "Quick detail",
                    verdict: .pause,
                    finalAction: .wait90s,
                    entrySource: .app
                )
            ],
            balance: [
                BalanceDecisionRecord(
                    prompt: "Should I take this job?",
                    desire: "Growth",
                    concern: "Capacity",
                    constraint: "Time",
                    longTerm: "I do not want to burn out",
                    focusTitle: "Capacity pressure",
                    focusSummary: "The real question is whether you still have room.",
                    nextAction: "Cut one commitment first.",
                    entrySource: .app
                )
            ],
            mirror: [mirror]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Should I leave?")
        XCTAssertEqual(entries.first?.actionTitle, "Write the boundary")
    }

    func testTimelineEntryPresentationForQuickCarriesVerdictAndReflection() {
        let event = CheckEvent(
            createdAt: Date(timeIntervalSince1970: 200),
            scenario: .scroll,
            motivation: .stressed,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "",
            currentPerspective: "Pause the spiral",
            afterPerspective: "Come back after breathing",
            verdict: .pause,
            finalAction: .wait90s,
            reflectionOutcome: .regrettedIt,
            entrySource: .app
        )

        let presentation = DecisionReviewEngine.timelineEntryPresentation(for: event)

        XCTAssertEqual(presentation.title, "Pause the spiral")
        XCTAssertEqual(presentation.secondaryLine, "Come back after breathing")
        XCTAssertEqual(presentation.labelTitle, "Scroll")
        XCTAssertEqual(presentation.labelSymbolName, event.scenario.symbolName)
        XCTAssertEqual(presentation.headerAccentText, "Pause")
        XCTAssertEqual(presentation.headerAccentStyle, .capsule)
        XCTAssertEqual(presentation.timestamp, event.createdAt)
        XCTAssertEqual(presentation.footerAccentText, "I regretted it")
    }

    func testRecentEntryPresentationUsesEntryModeAndActionTitle() {
        let record = BalanceDecisionRecord(
            updatedAt: Date(timeIntervalSince1970: 300),
            prompt: "Should I take the contract?",
            desire: "Momentum",
            concern: "Capacity",
            constraint: "Time",
            longTerm: "I do not want to burn out",
            focusTitle: "Capacity pressure",
            focusSummary: "The real question is whether you still have room.",
            nextAction: "Cut one commitment before adding another.",
            entrySource: .app
        )

        let presentation = DecisionReviewEngine.recentEntryPresentation(for: .balance(record))

        XCTAssertEqual(presentation.title, "Should I take the contract?")
        XCTAssertEqual(presentation.secondaryLine, "The real question is whether you still have room.")
        XCTAssertEqual(presentation.labelTitle, DecisionMode.balance.title)
        XCTAssertEqual(presentation.labelSymbolName, DecisionMode.balance.symbolName)
        XCTAssertEqual(presentation.timestamp, record.updatedAt)
        XCTAssertEqual(presentation.footerText, "Capacity pressure")
    }

    func testDetailPresentationForQuickFiltersEmptyOptionalRows() {
        let event = CheckEvent(
            scenario: .scroll,
            motivation: .stressed,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "   ",
            currentPerspective: "Pause the spiral",
            afterPerspective: "Come back after breathing",
            verdict: .pause,
            finalAction: .wait90s,
            reflectionOutcome: .regrettedIt,
            reflectionNote: "",
            entrySource: .app
        )

        let presentation = DecisionReviewEngine.detailPresentation(for: event)

        XCTAssertEqual(presentation.eyebrow, "Quick check")
        XCTAssertEqual(presentation.reopenTitle, "Reopen this check")
        XCTAssertEqual(presentation.rows.map(\.title), [
            "Scenario",
            "Verdict",
            "Why now",
            "Usually after",
            "Pull-back",
            "Reflection"
        ])
    }

    func testDetailPresentationForMirrorKeepsOrderedRows() {
        let record = MirrorDecisionRecord(
            prompt: "Should I stay?",
            emotion: "Grief",
            relationship: "The same boundary keeps slipping",
            reality: "We still live together",
            longTerm: "I keep shrinking",
            selfLens: "I do not trust my no",
            coreTension: "This is about what staying keeps teaching you to normalize.",
            nextActionTitle: "Name the boundary",
            nextAction: "Write the one limit you cannot keep negotiating away.",
            entrySource: .app
        )

        let presentation = DecisionReviewEngine.detailPresentation(for: record)

        XCTAssertEqual(presentation.eyebrow, "Mirror")
        XCTAssertEqual(presentation.title, "Should I stay?")
        XCTAssertEqual(presentation.rows.map(\.title), [
            "Emotion",
            "Relationship",
            "Reality",
            "Long-term",
            "Self",
            "Mirror action",
            "Next step"
        ])
    }

    func testReviewProfileEntryMatchesReplayRecordByStableIdentity() {
        let event = CheckEvent(
            scenario: .scroll,
            motivation: .stressed,
            expectedOutcome: .regret,
            controlLevel: .maybe,
            note: "",
            currentPerspective: "Pause the spiral",
            afterPerspective: "Come back after breathing",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )

        let entry = ReviewProfileEntry.quick(event)
        let matchingRecord = DeveloperDecisionReplayRecord.quick(event)
        let differentRecord = DeveloperDecisionReplayRecord.checkpoint(
            DecisionEvolutionLineageSnapshot(
                checkpointID: "checkpoint-1",
                createdAt: .now,
                mode: .quick,
                approvalState: .automatic,
                rollbackReady: true,
                diffSummary: ["Recovered"],
                eBrain: DeveloperDecisionReplayEBrainSummary(
                    lineageSummary: BASEvolutionLineageSummary(
                        recordedAt: .now,
                        sessionID: "lineage-1",
                        taskType: "high_pressure",
                        riskLevel: "medium",
                        permitMode: "compare",
                        hostGatePercent: 72,
                        thoughtFoldChecksum: "fold-1",
                        updateTicketSummaries: ["Hold before sending"],
                        activeKillSwitches: [],
                        guardrailFindings: [],
                        recommendedKillSwitches: []
                    )
                )
            )
        )

        XCTAssertTrue(entry.matches(matchingRecord))
        XCTAssertFalse(entry.matches(differentRecord))
    }
}
