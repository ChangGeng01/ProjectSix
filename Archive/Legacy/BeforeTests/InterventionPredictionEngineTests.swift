import XCTest
import SwiftData
@testable import Before

final class InterventionPredictionEngineTests: XCTestCase {
    @MainActor
    func testPredictCandidateReturnsNilWhenPredictiveInterventionsAreDisabled() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var preferences = BeforePreferences.default
        preferences.predictiveInterventionsEnabled = false
        let now = localDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0)

        let candidate = InterventionPredictionEngine.predictCandidate(
            currentBrainState: nil,
            context: context,
            preferences: preferences,
            now: now
        )

        XCTAssertNil(candidate)
    }

    @MainActor
    func testPredictCandidateEscalatesToHighRiskAtNightAfterRepeatedNegativeHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedNegativeQuickEvent(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 22, minute: 5), action: .goAheadAnyway)
        seedNegativeQuickEvent(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 23, minute: 5), action: .continueMindfully)
        try context.save()

        let now = localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 30)

        let candidate = InterventionPredictionEngine.predictCandidate(
            currentBrainState: nil,
            context: context,
            preferences: .default,
            now: now
        )

        XCTAssertEqual(candidate?.riskLevel, .high)
        XCTAssertEqual(candidate?.suggestedMode, .mirror)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("regret") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 2)
    }

    @MainActor
    func testPredictCandidateIncludesFailureGuardReasonFromCurrentBrainState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let current = CurrentBrainState(
            source: .explicitRefresh,
            sourceSurface: .app,
            mode: .quick,
            riskLevel: .medium,
            taskGraph: nil,
            brainState: DecisionBrainState(
                profileCore: [],
                activeGoals: [],
                relevantMemories: [],
                sessionBiases: ["Keep it simple."],
                retrievalTags: ["quick"],
                reactionWeights: .defaults(for: .quick),
                failureGuardIDs: ["night_fast_path_failure"],
                loadedAt: date("2026-04-10T23:00:00Z")
            ),
            dominantGoal: nil,
            activeConstraints: [],
            activeTemplateIDs: [],
            failureGuardIDs: ["night_fast_path_failure"],
            sourceIntentEnvelope: nil,
            loadedAt: date("2026-04-10T23:00:00Z")
        )

        let candidate = InterventionPredictionEngine.predictCandidate(
            currentBrainState: current,
            context: context,
            preferences: .default,
            now: date("2026-04-10T23:10:00Z")
        )

        XCTAssertNotNil(candidate)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("suppressing night fast paths") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 1)
    }

    @MainActor
    func testPredictCandidateDoesNotEscalateToHighRiskDuringDaylightForSameHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedNegativeQuickEvent(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 22, minute: 5), action: .goAheadAnyway)
        seedNegativeQuickEvent(into: context, at: localDate(year: 2026, month: 4, day: 9, hour: 23, minute: 5), action: .continueMindfully)
        try context.save()

        let now = localDate(year: 2026, month: 4, day: 10, hour: 14, minute: 0)

        let candidate = InterventionPredictionEngine.predictCandidate(
            currentBrainState: nil,
            context: context,
            preferences: .default,
            now: now
        )

        XCTAssertEqual(candidate?.riskLevel, .medium)
        XCTAssertNotEqual(candidate?.riskLevel, .high)
        XCTAssertEqual(candidate?.suggestedMode, .mirror)
    }

    @MainActor
    func testPredictCandidateDefaultsToLowRiskQuickPathWithoutSignals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0)

        let candidate = InterventionPredictionEngine.predictCandidate(
            currentBrainState: nil,
            context: context,
            preferences: .default,
            now: now
        )

        XCTAssertEqual(candidate?.riskLevel, .low)
        XCTAssertEqual(candidate?.suggestedMode, .quick)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("low-friction pause") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 0)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func seedNegativeQuickEvent(into context: ModelContext, at date: Date, action: CheckAction) {
        context.insert(
            CheckEvent(
                createdAt: date,
                scenario: .other,
                motivation: .stressed,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I want to send this now.",
                currentPerspective: "You want release quickly.",
                afterPerspective: "This keeps feeling worse later.",
                verdict: .pause,
                finalAction: action,
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
