import XCTest
@testable import BASPolicy

final class BASPredictiveNotificationPolicyTests: XCTestCase {
    func testAllowsHighRiskCandidateWithEnoughEvidence() {
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: makeInput(
                riskLevelID: "high",
                evidenceSignalCount: 2,
                now: localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 40)
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertNil(decision.blockReason)
    }

    func testBlocksMediumRiskDuringQuietHours() {
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: makeInput(
                riskLevelID: "medium",
                evidenceSignalCount: 2,
                now: localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 40)
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .quietHours)
    }

    func testBlocksWhenEvidenceIsTooThin() {
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: makeInput(
                riskLevelID: "medium",
                evidenceSignalCount: 1,
                now: localDate(year: 2026, month: 4, day: 10, hour: 18, minute: 0)
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .insufficientEvidence)
    }

    func testBlocksAfterRecentDismissal() {
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: makeInput(
                riskLevelID: "high",
                evidenceSignalCount: 2,
                recentSignals: [
                    BASPredictiveNotificationHistorySignal(
                        createdAt: localDate(year: 2026, month: 4, day: 10, hour: 17, minute: 50),
                        wasDelivered: false,
                        wasDismissed: true
                    )
                ],
                now: localDate(year: 2026, month: 4, day: 10, hour: 18, minute: 0)
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .recentDismissalSuppression)
    }

    func testBlocksWhenConsistencyHarnessRejectsHarshNotificationCopy() {
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: makeInput(
                riskLevelID: "high",
                evidenceSignalCount: 2,
                title: "You failed again.",
                detail: "That was wrong and obviously reckless.",
                reason: "You should have known better.",
                boundaryModeID: "local_only_protective",
                forbiddenActions: ["autonomous_external_action"],
                personaRules: ["Keep notification copy non-judgmental.", "Keep notification copy brief."],
                now: localDate(year: 2026, month: 4, day: 10, hour: 18, minute: 0)
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.blockReason, .consistencyRejected)
        XCTAssertNotNil(decision.consistencyCheck)
    }

    private func makeInput(
        riskLevelID: String,
        evidenceSignalCount: Int,
        title: String = "Pause before you decide.",
        detail: String = "A predicted pattern says a slower move is safer here.",
        reason: String = "A recent pattern suggests more friction before acting.",
        boundaryModeID: String? = nil,
        forbiddenActions: [String] = [],
        personaRules: [String] = [],
        recentSignals: [BASPredictiveNotificationHistorySignal] = [],
        now: Date
    ) -> BASPredictiveNotificationPolicyInput {
        BASPredictiveNotificationPolicyInput(
            predictiveInterventionsEnabled: true,
            riskLevelID: riskLevelID,
            evidenceSignalCount: evidenceSignalCount,
            title: title,
            detail: detail,
            reason: reason,
            expiresAt: now.addingTimeInterval(60 * 30),
            currentGoal: "Stay clear.",
            boundaryModeID: boundaryModeID,
            forbiddenActions: forbiddenActions,
            personaRules: personaRules,
            recentSignals: recentSignals,
            now: now,
            quietHoursStartHour: 22,
            quietHoursEndHour: 5,
            dailyCap: 2,
            cooldownInterval: 60 * 30,
            dismissalSuppressionInterval: 60 * 30
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
