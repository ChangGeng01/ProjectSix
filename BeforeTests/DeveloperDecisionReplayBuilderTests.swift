import XCTest
import BASHostKit
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

    func testBuildFallsBackToPersistedCheckpointLineageWhenLiveTurnIsMissing() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let lineage = BASEvolutionLineageSummary(
            recordedAt: now.addingTimeInterval(-5),
            sessionID: "before.quick.lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checksum",
            updateTicketSummaries: ["Hold before sending"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"]
        )
        let persisted = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-1",
            createdAt: now.addingTimeInterval(-4),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Recovered from checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineage)
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [],
            persistedLineages: [persisted]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].trace)
        XCTAssertEqual(entries[0].eBrain?.sessionID, lineage.sessionID)
        XCTAssertEqual(entries[0].eBrain?.riskLevel, lineage.riskLevel)
        XCTAssertEqual(entries[0].eBrain?.permitMode, lineage.permitMode)
        XCTAssertEqual(entries[0].eBrain?.hostGatePercent, lineage.hostGatePercent)
        XCTAssertEqual(entries[0].eBrain?.thoughtFoldChecksum, lineage.thoughtFoldChecksum)
        XCTAssertEqual(entries[0].eBrain?.updateTicketSummaries, lineage.updateTicketSummaries)
        XCTAssertEqual(entries[0].eBrain?.guardrailFindings, lineage.guardrailFindings)
        XCTAssertEqual(entries[0].eBrain?.killSwitches, lineage.recommendedKillSwitches)
    }

    func testBuildIncludesCheckpointOnlyReplayEntriesWhenNoMatchingRecordExists() {
        let now = Date()
        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "before.mirror.lineage",
            taskType: "reflection",
            riskLevel: "medium",
            permitMode: "compare",
            hostGatePercent: 61,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["capture calmer follow-up"],
            guardrailFindings: ["Recovered lineage available"],
            recommendedKillSwitches: []
        )
        let persisted = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-standalone",
            createdAt: now.addingTimeInterval(5),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Recovered persisted checkpoint without matching replay record"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineage)
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [],
            persistedLineages: [persisted]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].mode, .mirror)
        XCTAssertEqual(entries[0].title, "Recovered Mirror lineage")
        XCTAssertEqual(entries[0].statusTitle, "Review Suggested")
        XCTAssertEqual(entries[0].summaryLine, "Recovered persisted checkpoint without matching replay record")
        XCTAssertEqual(entries[0].eBrain?.source, .persistedCheckpoint)
        XCTAssertEqual(entries[0].eBrain?.sessionID, lineage.sessionID)
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
