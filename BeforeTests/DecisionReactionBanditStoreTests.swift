import XCTest
@testable import Before

final class DecisionReactionBanditStoreTests: XCTestCase {
    private let key = "before.reaction.bandit.snapshot"

    override func tearDown() {
        DecisionReactionBanditStore.clear()
        ProtectedLocalStateStore.clear(key: key)
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testRewardedArmRisesToFrontOfRecommendations() {
        let now = Date(timeIntervalSince1970: 1_000)

        for _ in 0..<3 {
            DecisionReactionBanditStore.update(
                mode: .mirror,
                riskLevel: .medium,
                languageMode: .english,
                chosenArmID: "reflective_question",
                reward: true,
                now: now
            )
        }

        let ranked = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .mirror,
            riskLevel: .medium,
            languageMode: .english,
            now: now
        )

        XCTAssertEqual(ranked.first, "reflective_question")
    }

    func testFailedArmFallsBehindOtherRecommendations() {
        let now = Date(timeIntervalSince1970: 2_000)

        for _ in 0..<4 {
            DecisionReactionBanditStore.update(
                mode: .quick,
                riskLevel: .high,
                languageMode: .english,
                chosenArmID: "slow_delay_guard",
                reward: false,
                now: now
            )
        }

        let ranked = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .quick,
            riskLevel: .high,
            languageMode: .english,
            now: now
        )

        XCTAssertEqual(ranked.last, "slow_delay_guard")
    }

    func testClearRemovesStoredSnapshot() {
        DecisionReactionBanditStore.update(
            mode: .quick,
            riskLevel: .low,
            languageMode: .english,
            chosenArmID: "brief_warm_nudge",
            reward: true
        )

        XCTAssertNotNil(ProtectedLocalStateStore.loadData(key: key))

        DecisionReactionBanditStore.clear()

        XCTAssertNil(ProtectedLocalStateStore.loadData(key: key))
    }

    func testBanditBucketsStayIsolatedAcrossRiskAndDaypart() {
        let night = localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 30)
        let morning = localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0)
        let nightArm = "reflective_question"
        let morningArm = "slow_delay_guard"
        let lowRiskArm = "brief_warm_nudge"

        for _ in 0..<3 {
            DecisionReactionBanditStore.update(
                mode: .quick,
                riskLevel: .high,
                languageMode: .english,
                chosenArmID: nightArm,
                reward: true,
                now: night
            )
            DecisionReactionBanditStore.update(
                mode: .quick,
                riskLevel: .high,
                languageMode: .english,
                chosenArmID: morningArm,
                reward: true,
                now: morning
            )
            DecisionReactionBanditStore.update(
                mode: .quick,
                riskLevel: .low,
                languageMode: .english,
                chosenArmID: lowRiskArm,
                reward: true,
                now: night
            )
        }

        let nightRanked = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .quick,
            riskLevel: .high,
            languageMode: .english,
            now: night
        )
        let morningRanked = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .quick,
            riskLevel: .high,
            languageMode: .english,
            now: morning
        )
        let lowRiskRanked = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .quick,
            riskLevel: .low,
            languageMode: .english,
            now: night
        )

        XCTAssertEqual(nightRanked.first, nightArm)
        XCTAssertEqual(morningRanked.first, morningArm)
        XCTAssertEqual(lowRiskRanked.first, lowRiskArm)
    }

    func testBanditRecommendationsPersistAcrossRepeatedReadsWithoutMutation() {
        let now = localDate(year: 2026, month: 4, day: 10, hour: 14, minute: 0)

        for _ in 0..<4 {
            DecisionReactionBanditStore.update(
                mode: .balance,
                riskLevel: .medium,
                languageMode: .english,
                chosenArmID: "brief_warm_nudge",
                reward: true,
                now: now
            )
        }

        let first = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .balance,
            riskLevel: .medium,
            languageMode: .english,
            now: now
        )
        let second = DecisionReactionBanditStore.recommendedArmIDs(
            mode: .balance,
            riskLevel: .medium,
            languageMode: .english,
            now: now
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first, "brief_warm_nudge")
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
