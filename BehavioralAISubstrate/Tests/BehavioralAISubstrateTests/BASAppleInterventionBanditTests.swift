import Foundation
import Testing
@testable import BASAppleAdapters

@Suite("BASApple Intervention Bandit")
struct BASAppleInterventionBanditTests {
    @Test("rewarded arm rises to the front of the bucket ordering")
    func rewardedArmRisesToFront() {
        let now = Date(timeIntervalSince1970: 1_000)
        let bucketID = BASAppleInterventionBanditAdvisor.bucketID(
            modeID: "mirror",
            riskLevelID: "medium",
            languageModeID: "english",
            now: now
        )

        var snapshot = BASAppleInterventionBanditAdvisor.emptySnapshot()
        for _ in 0..<3 {
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: bucketID,
                chosenArmID: "reflective_question",
                reward: true
            )
        }

        #expect(BASAppleInterventionBanditAdvisor.orderedArmIDs(snapshot: snapshot, bucketID: bucketID).first == "reflective_question")
    }

    @Test("bucket identity stays isolated across daypart risk and language")
    func bucketIdentityStaysIsolated() {
        let night = localDate(year: 2026, month: 4, day: 10, hour: 23, minute: 30)
        let morning = localDate(year: 2026, month: 4, day: 11, hour: 9, minute: 0)

        let nightBucket = BASAppleInterventionBanditAdvisor.bucketID(
            modeID: "quick",
            riskLevelID: "high",
            languageModeID: "english",
            now: night
        )
        let morningBucket = BASAppleInterventionBanditAdvisor.bucketID(
            modeID: "quick",
            riskLevelID: "high",
            languageModeID: "english",
            now: morning
        )
        let chineseBucket = BASAppleInterventionBanditAdvisor.bucketID(
            modeID: "quick",
            riskLevelID: "high",
            languageModeID: "chinese",
            now: night
        )

        var snapshot = BASAppleInterventionBanditAdvisor.emptySnapshot()
        for _ in 0..<3 {
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: nightBucket,
                chosenArmID: "reflective_question",
                reward: true
            )
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: morningBucket,
                chosenArmID: "slow_delay_guard",
                reward: true
            )
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: chineseBucket,
                chosenArmID: "brief_warm_nudge",
                reward: true
            )
        }

        #expect(BASAppleInterventionBanditAdvisor.orderedArmIDs(snapshot: snapshot, bucketID: nightBucket).first == "reflective_question")
        #expect(BASAppleInterventionBanditAdvisor.orderedArmIDs(snapshot: snapshot, bucketID: morningBucket).first == "slow_delay_guard")
        #expect(BASAppleInterventionBanditAdvisor.orderedArmIDs(snapshot: snapshot, bucketID: chineseBucket).first == "brief_warm_nudge")
    }

    @Test("tie scores stay lexicographic for deterministic reads")
    func tieScoresStayLexicographic() {
        let now = localDate(year: 2026, month: 4, day: 10, hour: 16, minute: 30)
        let bucketID = BASAppleInterventionBanditAdvisor.bucketID(
            modeID: "balance",
            riskLevelID: "medium",
            languageModeID: "english",
            now: now
        )
        var snapshot = BASAppleInterventionBanditAdvisor.emptySnapshot()
        for _ in 0..<2 {
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: bucketID,
                chosenArmID: "brief_warm_nudge",
                reward: true
            )
            snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
                snapshot: snapshot,
                bucketID: bucketID,
                chosenArmID: "reflective_question",
                reward: true
            )
        }

        let ordered = BASAppleInterventionBanditAdvisor.orderedArmIDs(snapshot: snapshot, bucketID: bucketID)
        #expect(Array(ordered.prefix(2)) == ["brief_warm_nudge", "reflective_question"])
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
        return components.date ?? .distantPast
    }
}
