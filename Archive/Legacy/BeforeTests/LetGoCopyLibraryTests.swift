import XCTest
@testable import Before

final class LetGoCopyLibraryTests: XCTestCase {
    func testTomorrowBoxContextForQuickUsesHomeAndBoxTargets() {
        let item = TomorrowBoxItem(
            dueAt: .now.addingTimeInterval(3_600),
            mode: .quick,
            title: "Buy this now?",
            detail: "A quick urge that can wait.",
            prompt: "Should I buy it?",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.tomorrowBoxContext(for: item)

        XCTAssertEqual(context.mode, .quick)
        XCTAssertEqual(context.primaryTarget, .home)
        XCTAssertEqual(context.secondaryTarget, .box)
        XCTAssertEqual(context.eyebrow, "Tomorrow Box")
        XCTAssertFalse(context.title.isEmpty)
    }

    func testTomorrowBoxContextForMirrorUsesStageEndingLanguage() {
        let item = TomorrowBoxItem(
            dueAt: .now.addingTimeInterval(3_600),
            mode: .mirror,
            title: "Should I keep doing this?",
            detail: "A heavier question that needs distance.",
            prompt: "Should I stay?",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.tomorrowBoxContext(for: item)

        XCTAssertEqual(context.mode, .mirror)
        XCTAssertTrue(context.title.contains("enough"))
        XCTAssertTrue(context.completionSubtitle.contains("evening"))
    }

    func testSavedBalanceContextPointsToHistoryAsSecondarySurface() {
        let record = BalanceDecisionRecord(
            prompt: "Should I take the easier option?",
            desire: "Convenience",
            concern: "Drift",
            constraint: "Time",
            longTerm: "Regret",
            focusTitle: "Reality first",
            focusSummary: "The schedule pressure matters more than the fantasy version of the plan.",
            nextAction: "Choose the version you can actually sustain tonight.",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.savedBalanceContext(for: record)

        XCTAssertEqual(context.mode, .balance)
        XCTAssertEqual(context.primaryTarget, .home)
        XCTAssertEqual(context.secondaryTarget, .history)
        XCTAssertTrue(context.settledDetail.contains("History"))
    }

    func testSavedMirrorContextUsesMirrorSpecificEndingLanguage() {
        let record = MirrorDecisionRecord(
            prompt: "Should I keep doing this?",
            emotion: "Tired",
            relationship: "Misaligned",
            reality: "Shared commitments",
            longTerm: "More erosion",
            selfLens: "I feel smaller here",
            coreTension: "I keep confusing care with endurance.",
            nextActionTitle: "Separate the fear from the fit",
            nextAction: "Write what would need to change for staying to feel honest.",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.savedMirrorContext(for: record)

        XCTAssertEqual(context.mode, .mirror)
        XCTAssertTrue(context.title.contains("enough"))
        XCTAssertTrue(context.completionSubtitle.contains("night"))
        XCTAssertEqual(context.secondaryTarget, .history)
    }

    @MainActor
    func testQuickStepAwayContextUsesHistoryAsSecondarySurface() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Should I keep scrolling?")
        session.scenario = .scroll

        let result = QuickCheckResult(
            currentPerspective: "You want relief more than content.",
            afterPerspective: "Staying here will probably keep your head louder, not calmer.",
            verdict: .notRecommended,
            primaryAction: .leaveStimulus,
            secondaryActions: [.wait90s]
        )

        let context = LetGoCopyLibrary.quickStepAwayContext(for: session, result: result)

        XCTAssertEqual(context.mode, .quick)
        XCTAssertEqual(context.primaryTarget, .home)
        XCTAssertEqual(context.secondaryTarget, .history)
        XCTAssertTrue(context.title.contains("trigger"))
    }
}
