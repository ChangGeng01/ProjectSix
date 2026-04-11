import XCTest
@testable import BASAppleAdapters

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
        XCTAssertEqual(candidate?.preferredModeID, "reflective")
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("regret") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 2)
    }

    func testPredictCandidateIncludesFailureGuardReasonFromCurrentBrainState() {
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: true,
                currentModeID: "primary",
                negativeRecentCount: 0,
                failureGuardIDs: ["night_fast_path_failure"],
                now: date("2026-04-10T23:10:00Z")
            )
        )

        XCTAssertNotNil(candidate)
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("suppressing night fast paths") == true)
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
        XCTAssertEqual(candidate?.preferredModeID, "reflective")
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
        XCTAssertEqual(candidate?.preferredModeID, "primary")
        XCTAssertTrue(candidate?.reason.localizedCaseInsensitiveContains("low-friction pause") == true)
        XCTAssertEqual(candidate?.evidenceSignalCount, 0)
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
