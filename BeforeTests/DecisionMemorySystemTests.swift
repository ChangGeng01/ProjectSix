import XCTest
import SwiftData
@testable import Before

final class DecisionMemorySystemTests: XCTestCase {
    @MainActor
    func testRefreshStoredMemoriesDerivesStructuredRecordsFromHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        let memories = DecisionMemorySystem.refreshStoredMemories(in: context)

        XCTAssertTrue(memories.contains(where: { $0.id == "preference.communication.concise" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "semantic.scenario.buy" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertTrue(memories.contains(where: { $0.type == .goal }))
    }

    @MainActor
    func testRefreshStoredMemoriesStagesSituationalCandidatesWithoutPromotingThem() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)
        let candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let quickCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "situational.quick.latest" }))
        XCTAssertEqual(quickCandidate.status, .pending)
        XCTAssertEqual(quickCandidate.lastWriteOperation, .noop)
        XCTAssertFalse(
            DecisionMemorySystem.fetchMemoryRecords(in: context)
                .contains(where: { $0.id == "situational.quick.latest" })
        )
    }

    @MainActor
    func testRefreshStoredMemoriesUsesExplicitMemoryWriteOperations() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)
        var candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let supportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(supportCandidate.status, .promoted)
        XCTAssertEqual(supportCandidate.lastWriteOperation, .add)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)
        candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let unchangedSupportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(unchangedSupportCandidate.lastWriteOperation, .noop)
        XCTAssertEqual(unchangedSupportCandidate.confirmationCount, 1)
    }

    @MainActor
    func testLoadBrainStateReconstructsProfileGoalsAndRelevantMemories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.profileCore.contains("Short, direct language lands better."))
        XCTAssertTrue(brainState.activeGoals.contains(where: { $0.contains("Sleep before midnight") }))
        XCTAssertTrue(brainState.relevantMemories.contains(where: { $0.contains("Buy pressure keeps recurring.") }))
        XCTAssertTrue(brainState.relevantMemories.contains(where: {
            $0.contains("Tomorrow Box") || $0.contains("lighter, shorter guidance")
        }))
        XCTAssertTrue(brainState.sessionBiases.contains("Keep the language short and concrete."))
        XCTAssertTrue(brainState.sessionBiases.contains(where: { $0.localizedCaseInsensitiveContains("late at night") }))
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.briefLanguage, 0.9)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.8)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.9)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.totalRecordCount, 4)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.pendingCandidateCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.loadedPromotedMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.deferredCandidateCount, 1)
        XCTAssertTrue(brainState.retrievalTags.contains("quick"))
        XCTAssertTrue(brainState.retrievalTags.contains("buy"))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .profile &&
                $0.governanceStatus == .admitted &&
                $0.eligibility == .allowed(.defaultAllowed)
        }))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .goal &&
                $0.eligibility == .allowed(.goalOverride)
        }))
    }

    @MainActor
    func testLoadBrainStateRaisesInterruptiveBiasWhenReflectionsRewardPausePaths() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T08:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I almost bought it again after a stressful morning.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "Tomorrow usually feels quieter.",
                verdict: .pause,
                finalAction: .wait90s,
                reflectionOutcome: .notNeeded,
                entrySource: .app
            )
        )
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T09:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I pushed through anyway and felt worse.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "It usually feels noisy tomorrow.",
                verdict: .pause,
                finalAction: .goAheadAnyway,
                reflectionOutcome: .feltEmptier,
                entrySource: .app
            )
        )

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this again late at night.",
            context: context,
            now: date("2026-04-09T23:20:00Z")
        )

        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.95)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.85)
    }

    @MainActor
    func testLoadBrainStateScreensOutStalePendingMemoriesWhenTheyAreNotRelevant() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Help me think about whether I should cook at home tonight.",
            context: context,
            now: date("2026-04-10T18:00:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutPendingMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.confidenceNoOverlap] ?? 0,
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: \.isPending))
    }

    @MainActor
    func testLoadBrainStateMakesRetrievalModeExecutable() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let filtered = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z")
        )

        let off = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .off,
            now: date("2026-04-09T23:10:00Z")
        )

        let adaptive = DecisionMemorySystem.loadBrainState(
            mode: .mirror,
            prompt: "Should I stay in this relationship?",
            context: context,
            retrievalMode: .adaptive,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertGreaterThan(filtered.memorySlices.count, off.memorySlices.count)
        XCTAssertGreaterThan(filtered.memoryGovernance.loadedPendingMemoryCount, off.memoryGovernance.loadedPendingMemoryCount)
        XCTAssertEqual(off.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertLessThanOrEqual(off.relevantMemories.count, 1)
        XCTAssertGreaterThanOrEqual(adaptive.relevantMemories.count, 2)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: CheckEvent.self,
            SelfReminder.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
    }

    @MainActor
    private func seedHistory(into context: ModelContext) {
        let checkDates = [
            date("2026-04-08T22:10:00Z"),
            date("2026-04-07T22:45:00Z"),
            date("2026-04-06T23:05:00Z")
        ]

        checkDates.forEach { createdAt in
            context.insert(
                CheckEvent(
                    createdAt: createdAt,
                    scenario: .buy,
                    motivation: .reward,
                    expectedOutcome: .temporaryRelief,
                    controlLevel: .maybe,
                    note: "I want these shoes after a rough day.",
                    currentPerspective: "You want a quick hit of relief.",
                    afterPerspective: "It usually feels noisy tomorrow.",
                    verdict: .pause,
                    finalAction: .decideTomorrow,
                    entrySource: .app
                )
            )
        }

        context.insert(
            BalanceDecisionRecord(
                createdAt: date("2026-04-08T09:00:00Z"),
                updatedAt: date("2026-04-08T09:05:00Z"),
                prompt: "Should I keep taking late freelance work?",
                desire: "Extra income",
                concern: "It wrecks sleep",
                constraint: "Bills are real",
                longTerm: "Sleep before midnight",
                focusTitle: "Protect sleep",
                focusSummary: "The real trade-off is cash versus recovery.",
                nextAction: "Cap late work to two nights.",
                entrySource: .app
            )
        )

        context.insert(
            MirrorDecisionRecord(
                createdAt: date("2026-04-08T12:00:00Z"),
                updatedAt: date("2026-04-08T12:10:00Z"),
                prompt: "Should I stay in this relationship?",
                emotion: "Drained",
                relationship: "I keep shrinking around them.",
                reality: "Nothing changes after the apology.",
                longTerm: "Stop shrinking myself in love",
                selfLens: "I stay because ending it feels empty.",
                coreTension: "Comfort keeps beating truth.",
                nextActionTitle: "Name the real cost",
                nextAction: "Write what staying is costing your life.",
                entrySource: .app
            )
        )

        [
            "Keep it short. I do not need a speech.",
            "This is stress shopping again.",
            "Tomorrow is still an option."
        ].forEach { content in
            context.insert(
                SelfReminder(
                    content: content,
                    scenario: .buy,
                    source: .userWritten,
                    createdAt: date("2026-04-08T08:00:00Z"),
                    lastUsedAt: date("2026-04-08T21:55:00Z"),
                    useCount: 1
                )
            )
        }

        try? context.save()
    }

    private func date(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601) ?? .now
    }
}
