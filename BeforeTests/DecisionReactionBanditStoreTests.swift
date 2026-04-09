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
}
