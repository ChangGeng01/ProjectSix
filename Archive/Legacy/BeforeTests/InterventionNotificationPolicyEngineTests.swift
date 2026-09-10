import XCTest
import SwiftData
@testable import Before

final class InterventionNotificationPolicyEngineTests: XCTestCase {
    @MainActor
    func testAllowsHighRiskCandidateWithEnoughEvidence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 23, minute: 10)
        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "Slow this down",
            detail: "Night pressure is high.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Two recent regret patterns plus night pressure suggest a slower path.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertNil(decision.blockReason)
    }

    @MainActor
    func testBlocksMediumRiskDuringQuietHours() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 23, minute: 30)
        let candidate = InterventionPredictionCandidate(
            riskLevel: .medium,
            title: "Pause",
            detail: "You may need one cleaner mirror.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Recent friction suggests a slower move.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .quietHours)
    }

    @MainActor
    func testBlocksWhenCooldownIsStillActive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 15, minute: 0)
        context.insert(
            InterventionTrigger(
                createdAt: now.addingTimeInterval(-(60 * 20)),
                riskLevel: .high,
                title: "Older nudge",
                detail: "Already sent",
                reason: "Recent history",
                suggestedMode: .mirror,
                wasDelivered: true
            )
        )
        try context.save()

        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "New nudge",
            detail: "Another high-risk moment.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Repeated regret pattern.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .cooldownActive)
    }

    @MainActor
    func testBlocksAfterRecentDismissal() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 16, minute: 0)
        context.insert(
            InterventionTrigger(
                createdAt: now.addingTimeInterval(-(60 * 60)),
                riskLevel: .medium,
                title: "Dismissed nudge",
                detail: "Dismissed earlier",
                reason: "Recent friction",
                suggestedMode: .mirror,
                wasDelivered: true,
                wasDismissed: true
            )
        )
        try context.save()

        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "Another nudge",
            detail: "Stay slow.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Pattern still strong.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .recentDismissalSuppression)
    }

    @MainActor
    func testBlocksWhenDailyCapIsReached() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 14, minute: 0)
        for offset in [120.0, 240.0] {
            context.insert(
                InterventionTrigger(
                    createdAt: now.addingTimeInterval(-offset),
                    riskLevel: .high,
                    title: "Delivered",
                    detail: "Already delivered",
                    reason: "Pattern",
                    suggestedMode: .mirror,
                    wasDelivered: true
                )
            )
        }
        try context.save()

        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "Cap test",
            detail: "Would normally send.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Pattern is strong.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .dailyCapReached)
    }

    @MainActor
    func testBlocksWhenEvidenceIsTooThin() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 13, minute: 0)
        let candidate = InterventionPredictionCandidate(
            riskLevel: .medium,
            title: "Thin evidence",
            detail: "Only one weak signal.",
            evidenceSignalCount: 1,
            suggestedMode: .mirror,
            reason: "One weak signal.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .insufficientEvidence)
    }

    @MainActor
    func testBlocksWhenConsistencyHarnessRejectsHarshNotificationCopy() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = localDate(year: 2026, month: 4, day: 11, hour: 15, minute: 30)
        let brainState = DecisionBrainState(
            profileCore: ["Gentle, bounded interventions work best."],
            activeGoals: ["Protect sleep before midnight."],
            relevantMemories: ["Night pushes need lighter language."],
            sessionBiases: ["Keep the tone gentle and brief."],
            retrievalTags: ["sleep", "night"],
            reactionWeights: DecisionReactionWeights.defaults(for: .quick),
            loadedAt: now
        )
        let currentBrainState = CurrentBrainState(
            source: .notification,
            sourceSurface: .notification,
            mode: .quick,
            riskLevel: .high,
            taskGraph: nil,
            brainState: brainState,
            dominantGoal: "Protect sleep before midnight.",
            activeConstraints: ["require_confirmation"],
            activeTemplateIDs: [],
            failureGuardIDs: [],
            sourceIntentEnvelope: nil,
            loadedAt: now
        )
        let candidate = InterventionPredictionCandidate(
            riskLevel: .high,
            title: "You should have known better",
            detail: "You failed this before and obviously need to stop right now.",
            evidenceSignalCount: 2,
            suggestedMode: .mirror,
            reason: "Night pressure is high.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(60 * 30)
        )

        let decision = InterventionNotificationPolicyEngine.decide(
            candidate: candidate,
            preferences: .default,
            currentBrainState: currentBrainState,
            context: context,
            now: now
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .consistencyRejected)
        XCTAssertNotNil(decision.consistencyCheck)
        XCTAssertTrue(
            decision.consistencyCheck?.violations.contains(where: { $0.kind == .personaDrift }) == true
        )
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: InterventionTrigger.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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
