import XCTest
@testable import Before

final class DeveloperDecisionReplayBuilderTests: XCTestCase {
    func testBuildSortsNewestEntriesAcrossModesAndLimitsResults() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now.addingTimeInterval(-120), title: "Quick")
        let balance = makeBalanceRecord(updatedAt: now.addingTimeInterval(-60), prompt: "Balance")
        let mirror = makeMirrorRecord(updatedAt: now.addingTimeInterval(-10), prompt: "Mirror")

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [balance],
            mirror: [mirror],
            traces: [],
            limit: 2
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].mode, .mirror)
        XCTAssertEqual(entries[0].title, "Mirror")
        XCTAssertEqual(entries[1].mode, .balance)
        XCTAssertEqual(entries[1].title, "Balance")
    }

    func testBuildLinksNewestMatchingTraceForEachMode() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let balance = makeBalanceRecord(updatedAt: now.addingTimeInterval(-30), prompt: "Balance")
        let mirror = makeMirrorRecord(updatedAt: now.addingTimeInterval(-60), prompt: "Mirror")

        let quickTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-5),
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .foundationModels,
            attemptedProviders: [.gemmaE4B, .foundationModels],
            allowFallbacks: true,
            usedFallback: true,
            prompt: "Quick prompt",
            outputPreview: "Quick output",
            detail: "Quick detail"
        )
        let balanceTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-35),
            kind: .balance,
            preferredProvider: .foundationModels,
            activeProvider: .foundationModels,
            attemptedProviders: [.foundationModels],
            allowFallbacks: false,
            usedFallback: false,
            prompt: "Balance prompt",
            outputPreview: "Balance output",
            detail: "Balance detail"
        )
        let staleMirrorTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-(BeforePolicy.Settings.developerReplayTraceLookbackInterval + 180)),
            kind: .mirror,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            prompt: "Mirror prompt",
            outputPreview: "Mirror output",
            detail: "Mirror detail"
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [balance],
            mirror: [mirror],
            traces: [staleMirrorTrace, balanceTrace, quickTrace]
        )

        XCTAssertEqual(entries.first(where: { $0.mode == .quick })?.trace?.prompt, "Quick prompt")
        XCTAssertEqual(entries.first(where: { $0.mode == .balance })?.trace?.prompt, "Balance prompt")
        XCTAssertNil(entries.first(where: { $0.mode == .mirror })?.trace)
    }

    func testBuildDoesNotReuseTheSameTraceTwice() {
        let now = Date()
        let newestQuick = makeQuickEvent(createdAt: now, title: "Newest")
        let olderQuick = makeQuickEvent(createdAt: now.addingTimeInterval(-20), title: "Older")
        let sharedTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-4),
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            prompt: "Shared prompt",
            outputPreview: "Shared output",
            detail: "Shared detail"
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [olderQuick, newestQuick],
            balance: [],
            mirror: [],
            traces: [sharedTrace]
        )

        XCTAssertEqual(entries[0].title, "Newest")
        XCTAssertEqual(entries[0].trace?.prompt, "Shared prompt")
        XCTAssertNil(entries[1].trace)
    }

    private func makeQuickEvent(createdAt: Date, title: String) -> CheckEvent {
        CheckEvent(
            createdAt: createdAt,
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "",
            currentPerspective: title,
            afterPerspective: "After \(title)",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )
    }

    private func makeBalanceRecord(updatedAt: Date, prompt: String) -> BalanceDecisionRecord {
        BalanceDecisionRecord(
            createdAt: updatedAt,
            updatedAt: updatedAt,
            prompt: prompt,
            desire: "Want",
            concern: "Concern",
            constraint: "Constraint",
            longTerm: "Long-term",
            focusTitle: "Focus",
            focusSummary: "Summary",
            nextAction: "Next action",
            entrySource: .app
        )
    }

    private func makeMirrorRecord(updatedAt: Date, prompt: String) -> MirrorDecisionRecord {
        MirrorDecisionRecord(
            createdAt: updatedAt,
            updatedAt: updatedAt,
            prompt: prompt,
            emotion: "Emotion",
            relationship: "Relationship",
            reality: "Reality",
            longTerm: "Long-term",
            selfLens: "Self",
            coreTension: "Tension",
            nextActionTitle: "Action",
            nextAction: "Next step",
            entrySource: .app
        )
    }
}
