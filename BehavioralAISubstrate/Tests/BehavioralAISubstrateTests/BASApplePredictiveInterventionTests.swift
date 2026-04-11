import XCTest
@testable import BASAppleAdapters
@testable import BASMemory

final class BASApplePredictiveInterventionTests: XCTestCase {
    func testPredictCandidateReturnsNilWhenPredictiveInterventionsAreDisabled() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: false,
                currentModeID: nil,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0)
            )
        )

        XCTAssertNil(candidate)
    }

    func testPredictCandidateEscalatesToHighRiskAtNightAfterRepeatedNegativeHistory() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: nil,
                negativeRecentCount: 2,
                now: localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 30)
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "high")
        XCTAssertNil(candidate?.preferredModeID)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("ended poorly") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 2)
    }

    func testPredictCandidateIncludesFailureGuardReasonFromCurrentBrainState() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: "primary",
                negativeRecentCount: 0,
                failureGuardIDs: ["night_fast_path_failure"],
                now: date("2026-04-10T23:10:00Z"),
                behavior: BASApplePredictiveInterventionBehavior(
                    failureGuardReasonsByID: [
                        "night_fast_path_failure": "Host-owned guard warning."
                    ]
                )
            )
        )

        XCTAssertNotNil(candidate)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("host-owned guard warning") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 1)
    }

    func testPredictCandidateDoesNotEscalateToHighRiskDuringDaylightForSameHistory() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: nil,
                negativeRecentCount: 2,
                now: localDate(year: 2026, month: 4, day: 10, hour: 14, minute: 0)
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "medium")
        XCTAssertNotEqual(candidate?.riskLevelID, "high")
        XCTAssertNil(candidate?.preferredModeID)
    }

    func testPredictCandidateDefaultsToLowRiskQuickPathWithoutSignals() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: nil,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0)
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "low")
        XCTAssertNil(candidate?.preferredModeID)
        XCTAssertEqual(candidate?.title, "A lighter next step may be enough.")
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("deliberate next step") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 0)
    }

    func testPredictCandidateGenericDefaultsDoNotEscalateByModeAlone() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: BASDecisionMode.mirror.identifier,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0)
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "low")
        XCTAssertNil(candidate?.preferredModeID)
    }

    func testPredictCandidateUsesHostInjectedBehaviorInsteadOfGenericCopy() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: nil,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0),
                behavior: BASApplePredictiveInterventionBehavior(
                    lowRisk: BASApplePredictiveInterventionRiskBehavior(
                        title: "Host-owned pause.",
                        detail: "The host wants to slow this down in its own language.",
                        preferredModeID: BASDecisionMode.quick.identifier
                    ),
                    mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                        title: "Host-owned reflect.",
                        detail: "The host wants a reflective pass here.",
                        preferredModeID: BASDecisionMode.mirror.identifier
                    ),
                    highRisk: BASApplePredictiveInterventionRiskBehavior(
                        title: "Host-owned friction.",
                        detail: "The host wants stronger friction before action.",
                        preferredModeID: BASDecisionMode.mirror.identifier
                    ),
                    nightWindowReason: "Host-owned time warning.",
                    negativeRecentReason: "Host-owned recent-history warning.",
                    failureGuardReasonsByID: [
                        "night_fast_path_failure": "Host-owned guard warning."
                    ],
                    defaultReason: "Host-owned fallback."
                )
            )
        )

        XCTAssertEqual(candidate?.title, "Host-owned pause.")
        XCTAssertEqual(candidate?.detail, "The host wants to slow this down in its own language.")
        XCTAssertEqual(candidate?.reason, "Host-owned fallback.")
    }

    func testPredictCandidateUsesHostInjectedRiskResolutionInsteadOfBuiltInModeBias() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: BASDecisionMode.mirror.identifier,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0),
                behavior: BASApplePredictiveInterventionBehavior(
                    preferredModeIDsByCurrentModeID: [:]
                )
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "low")
        XCTAssertNil(candidate?.preferredModeID)
    }

    func testPredictCandidateDoesNotAssumeRapidModeWhenCurrentModeIsUnknown() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: nil,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0),
                behavior: BASApplePredictiveInterventionBehavior(
                    preferredModeIDsByCurrentModeID: [BASDecisionMode.quick.identifier: BASDecisionMode.quick.identifier]
                )
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "low")
        XCTAssertNil(candidate?.preferredModeID)
    }

    func testPredictCandidateCanRecommendHostModeWithoutElevatingRisk() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: BASDecisionMode.mirror.identifier,
                negativeRecentCount: 0,
                now: localDate(year: 2026, month: 4, day: 10, hour: 11, minute: 0),
                behavior: BASApplePredictiveInterventionBehavior(
                    preferredModeIDsByCurrentModeID: [
                        BASDecisionMode.mirror.identifier: BASDecisionMode.comparative.identifier
                    ]
                )
            )
        )

        XCTAssertEqual(candidate?.riskLevelID, "low")
        XCTAssertEqual(candidate?.preferredModeID, BASDecisionMode.comparative.identifier)
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
