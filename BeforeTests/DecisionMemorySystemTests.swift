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
    func testLoadBrainStateScreensOutContaminatedCandidateBeforeFrontstageLoad() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "semantic.injected.buy",
                type: .semantic,
                topic: "buy",
                headline: "Buy pressure keeps recurring.",
                value: "buy",
                confidence: 0.88,
                priority: 0.84,
                source: .pattern,
                firstObservedAt: date("2026-04-09T20:00:00Z"),
                lastObservedAt: date("2026-04-09T20:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["buy", "night", "pattern"],
                evidenceCount: 3,
                confirmationCount: 2,
                lastObservationFingerprint: "fp",
                status: .pending,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Pending verification."
            )
        )
        try context.save()

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this late at night again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.provenanceContamination],
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: { $0.id == "semantic.injected.buy" }))
        XCTAssertTrue(brainState.verificationSnapshot.riskFlags.contains(.contaminationGuardTriggered))
    }

    @MainActor
    func testBrainStateVerificationSnapshotIsStableForSameInputs() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let first = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let second = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(first.verificationSnapshot.fingerprint, second.verificationSnapshot.fingerprint)
        XCTAssertEqual(
            first.verificationSnapshot.dominantReactionWeight,
            second.verificationSnapshot.dominantReactionWeight
        )
        XCTAssertGreaterThan(first.verificationSnapshot.loadedMemoryCount, 0)
    }

    @MainActor
    func testLoadBrainStateAddsLanguageAndScriptTagsForChinesePrompt() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "我今晚又想买这个。",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.retrievalTags.contains("lang:chinese"))
        XCTAssertTrue(brainState.retrievalTags.contains("script:han"))
        XCTAssertTrue(brainState.retrievalTags.contains(where: { $0.contains("今晚") || $0.contains("想买") }))
    }

    @MainActor
    func testRefreshProjectionUsesBoundedWorkingSetAndPreservesGovernanceCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0..<110 {
            context.insert(
                DecisionMemoryRecord(
                    id: "record-\(index)",
                    type: .semantic,
                    topic: "topic-\(index)",
                    headline: "Headline \(index)",
                    value: "Value \(index)",
                    confidence: 0.8,
                    priority: Double(200 - index),
                    source: .pattern,
                    lastConfirmedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 60),
                    decayPolicy: .slow,
                    retrievalTags: ["tag-\(index)"],
                    evidenceCount: 2,
                    observationCount: 2,
                    provenanceSummary: "Synthetic record \(index)"
                )
            )
        }

        for index in 0..<44 {
            context.insert(
                DecisionMemoryCandidateRecord(
                    id: "candidate-\(index)",
                    type: .situational,
                    topic: "candidate-topic-\(index)",
                    headline: "Candidate \(index)",
                    value: "Candidate value \(index)",
                    confidence: 0.7,
                    priority: Double(100 - index),
                    source: .history,
                    firstObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    lastObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    decayPolicy: .fast,
                    retrievalTags: ["candidate-\(index)"],
                    evidenceCount: 1,
                    confirmationCount: 1,
                    lastObservationFingerprint: "fingerprint-\(index)",
                    status: index < 26 ? .pending : .promoted,
                    provenanceSummary: "Synthetic candidate \(index)",
                    lastWriteOperation: .add,
                    lastGovernanceDecision: index.isMultiple(of: 2) ? .admit : .deferred,
                    governanceReason: "synthetic"
                )
            )
        }
        try context.save()

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(projection.governanceSnapshot.totalRecordCount, 110)
        XCTAssertEqual(projection.governanceSnapshot.totalCandidateCount, 44)
        XCTAssertEqual(projection.governanceSnapshot.pendingCandidateCount, 26)
        XCTAssertEqual(projection.governanceSnapshot.promotedCandidateCount, 18)
        XCTAssertEqual(projection.governanceSnapshot.admittedCandidateCount, 22)
        XCTAssertEqual(projection.governanceSnapshot.deferredCandidateCount, 22)
        XCTAssertLessThanOrEqual(projection.diagnostics.recordCount, DecisionMemorySystem.projectionRecordLimit)
        XCTAssertLessThanOrEqual(projection.diagnostics.candidateCount, DecisionMemorySystem.projectionCandidateLimit)
        XCTAssertTrue(projection.diagnostics.allCandidatesPending)
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
