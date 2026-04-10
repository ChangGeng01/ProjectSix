import XCTest
import SwiftData
@testable import Before

final class CurrentBrainStateLoaderTests: XCTestCase {
    @MainActor
    func testBootstrapCurrentBrainStatePersistsBrainUpdateAndDefaultTemplates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedQuickHistory(into: context)
        try context.save()

        let bootstrapDate = localDate(year: 2026, month: 4, day: 10, hour: 20, minute: 0)

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: bootstrapDate
        )

        let current = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I text them tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapDate
        )

        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())
        let templates = try context.fetch(FetchDescriptor<InterventionTemplateRecord>())
        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())

        XCTAssertEqual(current.source, .launch)
        XCTAssertEqual(current.sourceSurface, .app)
        XCTAssertEqual(current.riskLevel, .low)
        XCTAssertFalse(current.activeTemplateIDs.isEmpty)
        XCTAssertFalse(templates.isEmpty)
        XCTAssertEqual(current.identityProfile.role, .pauseCompanion)
        XCTAssertEqual(current.boundaryPolicy.mode, .localOnlyAdvisory)
        XCTAssertEqual(current.calibrationState.status, .stable)
        XCTAssertTrue(current.calibrationState.alerts.isEmpty)
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(current.evolutionState.checkpointCount, 1)
        XCTAssertTrue(current.evolutionState.rollbackReady)
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.fingerprint, current.verificationSnapshot.fingerprint)
        XCTAssertEqual(updates.first?.activeTemplateIDs, current.activeTemplateIDs)
    }

    @MainActor
    func testBootstrapCurrentBrainStateLoadsFailureGuardsFromRecentNightFailures() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedNightFailure(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 22, minute: 10))
        seedNightFailure(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 23, minute: 20))
        try context.save()

        let bootstrapDate = localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 30)

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: bootstrapDate
        )

        let current = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "I want to send this message right now.",
            source: .sessionPrime,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapDate
        )

        XCTAssertTrue(current.failureGuardIDs.contains("night_fast_path_failure"))
        XCTAssertTrue(current.brainState.failureGuardIDs.contains("night_fast_path_failure"))
    }

    @MainActor
    func testBootstrapCurrentBrainStateIsStableAcrossRepeatedLoadsForSameProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedQuickHistory(into: context)
        try context.save()

        let bootstrapDate = localDate(year: 2026, month: 4, day: 10, hour: 21, minute: 15)
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: bootstrapDate)

        let first = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I buy this tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapDate
        )
        let second = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I buy this tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapDate
        )

        XCTAssertEqual(first.verificationSnapshot.fingerprint, second.verificationSnapshot.fingerprint)
        XCTAssertEqual(first.activeTemplateIDs, second.activeTemplateIDs)
        XCTAssertEqual(first.failureGuardIDs, second.failureGuardIDs)
        XCTAssertEqual(first.activeConstraints, second.activeConstraints)
    }

    @MainActor
    func testBootstrapCurrentBrainStateTrimsHistoricalUpdatesToSixtyEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedQuickHistory(into: context)

        let baseDate = localDate(year: 2026, month: 4, day: 10, hour: 18, minute: 0)
        for index in 0..<80 {
            context.insert(
                BrainStateUpdate(
                    createdAt: baseDate.addingTimeInterval(Double(-index) * 60),
                    source: .explicitRefresh,
                    mode: .quick,
                    dominantGoal: "goal-\(index)",
                    dominantReactionWeight: .briefLanguage,
                    fingerprint: "fingerprint-\(index)",
                    activeConstraints: [],
                    activeTemplateIDs: [],
                    failureGuardIDs: []
                )
            )
        }
        try context.save()

        let bootstrapDate = baseDate.addingTimeInterval(60)
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: bootstrapDate)
        _ = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I text them?",
            source: .sessionPrime,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapDate
        )

        let updates = try context.fetch(
            FetchDescriptor<BrainStateUpdate>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )

        XCTAssertLessThanOrEqual(updates.count, 60)
        XCTAssertTrue(updates.contains { $0.source == .sessionPrime })
    }

    @MainActor
    func testRepeatedBootstrapsDoNotDuplicateTemplatesFailurePatternsOrOverflowUpdateCap() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedQuickHistory(into: context)
        seedNightFailure(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 22, minute: 10))
        seedNightFailure(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 23, minute: 20))
        try context.save()

        let baseDate = localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 0)

        for offset in 0..<85 {
            let now = baseDate.addingTimeInterval(Double(offset) * 60)
            let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
            _ = CurrentBrainStateLoader.bootstrapCurrentBrainState(
                mode: .quick,
                prompt: "Should I send this tonight?",
                source: .sessionPrime,
                taskGraph: nil,
                context: context,
                projection: projection,
                retrievalMode: .filtered,
                now: now
            )
        }

        let templates = try context.fetch(FetchDescriptor<InterventionTemplateRecord>())
        let failurePatterns = try context.fetch(FetchDescriptor<FailurePatternRecord>())
        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())
        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())

        XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)
        XCTAssertEqual(Set(failurePatterns.map(\.id)).count, failurePatterns.count)
        XCTAssertEqual(templates.count, 4)
        XCTAssertLessThanOrEqual(updates.count, 60)
        XCTAssertLessThanOrEqual(checkpoints.count, BeforePolicy.RuntimeState.evolutionCheckpointLimit)
        XCTAssertTrue(failurePatterns.contains(where: { $0.id == "night_fast_path_failure" }))
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            BrainStateUpdate.self,
            DecisionEvolutionCheckpoint.self,
            InterventionTemplateRecord.self,
            FailurePatternRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func seedQuickHistory(into context: ModelContext) {
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-10T08:00:00Z"),
                scenario: .other,
                motivation: .genuineNeed,
                expectedOutcome: .satisfied,
                controlLevel: .maybe,
                note: "I want to reply fast.",
                currentPerspective: "You want a fast relief hit.",
                afterPerspective: "Waiting tends to clean this up.",
                verdict: .pause,
                finalAction: .decideTomorrow,
                reflectionOutcome: .betterThanExpected,
                entrySource: .app
            )
        )
    }

    @MainActor
    private func seedNightFailure(into context: ModelContext, at date: Date) {
        context.insert(
            CheckEvent(
                createdAt: date,
                scenario: .other,
                motivation: .stressed,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I want to send this tonight.",
                currentPerspective: "You want instant relief.",
                afterPerspective: "This usually lands badly by morning.",
                verdict: .pause,
                finalAction: .goAheadAnyway,
                reflectionOutcome: .regrettedIt,
                entrySource: .app
            )
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.autoupdatingCurrent
        components.timeZone = Calendar.autoupdatingCurrent.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date!
    }
}
