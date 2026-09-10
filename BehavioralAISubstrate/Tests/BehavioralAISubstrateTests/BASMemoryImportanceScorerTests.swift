import XCTest
@testable import BASMemory

/// chapter 二百五十二 / M739 — `BASMemoryImportanceScorer` coverage.
///
/// Stage 1 Step 2 of 3 (Memory Importance Loop). The scorer is a
/// pure function: read usage history, compute per-atom importance
/// scores, recommend tier mutations. This suite verifies:
///
///   1. Each component (recency / frequency / helped / tierDecay)
///      behaves on edge cases (empty history, all-helped, all-cold,
///      etc.).
///   2. Total score combines components into a [0, 1] value.
///   3. Recommended tier moves up / down per threshold.
///   4. `scoreAll(atomTiers:records:)` aggregates correctly.
///   5. Scorer is fully deterministic given fixed `now:`.
final class BASMemoryImportanceScorerTests: XCTestCase {

    // MARK: - Fixtures

    private let referenceNow = Date(
        timeIntervalSince1970: 1_700_000_000)

    private func makeRecord(
        atomID: String = "atom-1",
        retrievedAt: Date,
        helped: BASMemoryUsageRecord.HelpedFlag = .unknown
    ) -> BASMemoryUsageRecord {
        BASMemoryUsageRecord(
            atomID: atomID,
            retrievedAt: retrievedAt,
            sessionRef: "s",
            turnRef: "t",
            permitMode: "answer",
            helpedFlag: helped)
    }

    // MARK: - 1. Empty records → neutral helped, zero recency

    func testEmptyRecordsScoresNeutralHelpedZeroRecency()
        async throws
    {
        let scorer = BASMemoryImportanceScorer()
        let score = scorer.score(
            atomID: "atom-empty",
            currentTier: .warm,
            records: [],
            now: referenceNow)
        XCTAssertEqual(score.recordCount, 0)
        XCTAssertEqual(score.recencyComponent, 0)
        XCTAssertEqual(score.frequencyComponent, 0)
        XCTAssertEqual(score.helpedComponent, 0.5)
        XCTAssertEqual(
            score.tierDecayComponent,
            BASMemoryImportanceScorer.defaultTierDecayWarm)
        // audit blindspot-③ HIGH: a no-history atom must score NEUTRAL and STAY, not near-min (~0.0077)
        // and be demoted on arrival. Reversal (geometric mean governs) reds both of these.
        XCTAssertEqual(score.totalScore, 0.5,
            "a brand-new atom with no usage history must score neutral, not near-min")
        XCTAssertEqual(score.recommendedTier, .warm,
            "a no-history warm atom must STAY warm — never demoted to cold before it is ever used")
    }

    // MARK: - 2. Recency: just-now retrieval ≈ 1.0

    func testRecencyMostRecentNowReturnsHigh() async throws {
        let scorer = BASMemoryImportanceScorer()
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: [makeRecord(retrievedAt: referenceNow)],
            now: referenceNow)
        XCTAssertGreaterThan(score.recencyComponent, 0.99)
    }

    // MARK: - 3. Recency: 1 half-life ago ≈ 0.5

    func testRecencyOneHalfLifeAgoReturnsHalf() async throws {
        let scorer = BASMemoryImportanceScorer(
            recencyHalfLifeSeconds: 1000)
        let oneHalfLifeAgo = referenceNow
            .addingTimeInterval(-1000)
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: [
                makeRecord(retrievedAt: oneHalfLifeAgo)
            ],
            now: referenceNow)
        XCTAssertEqual(
            score.recencyComponent, 0.5, accuracy: 0.01)
    }

    // MARK: - 4. Recency: 2 half-lives ago ≈ 0.25

    func testRecencyTwoHalfLivesAgoReturnsQuarter()
        async throws
    {
        let scorer = BASMemoryImportanceScorer(
            recencyHalfLifeSeconds: 1000)
        let twoHalfLivesAgo = referenceNow
            .addingTimeInterval(-2000)
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: [
                makeRecord(retrievedAt: twoHalfLivesAgo)
            ],
            now: referenceNow)
        XCTAssertEqual(
            score.recencyComponent, 0.25, accuracy: 0.01)
    }

    // MARK: - 5. Frequency: log saturation

    func testFrequencyLogSaturatesNearOne() async throws {
        let scorer = BASMemoryImportanceScorer(
            frequencySaturation: 50)
        let many = (0..<100).map { i in
            makeRecord(retrievedAt: referenceNow
                .addingTimeInterval(-Double(i)))
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: many,
            now: referenceNow)
        XCTAssertGreaterThan(score.frequencyComponent, 0.95)
    }

    // MARK: - 6. Frequency: at saturation == ~1

    func testFrequencyAtSaturationReturnsOne() async throws {
        let scorer = BASMemoryImportanceScorer(
            frequencySaturation: 50)
        let many = (0..<50).map { i in
            makeRecord(retrievedAt: referenceNow
                .addingTimeInterval(-Double(i)))
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: many,
            now: referenceNow)
        XCTAssertEqual(
            score.frequencyComponent, 1.0, accuracy: 0.001)
    }

    // MARK: - 7. Helped component: all helped → 1.0

    func testHelpedAllHelpedReturnsOne() async throws {
        let scorer = BASMemoryImportanceScorer()
        let records = (0..<5).map { _ in
            makeRecord(
                retrievedAt: referenceNow,
                helped: .helped)
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: records,
            now: referenceNow)
        XCTAssertEqual(score.helpedComponent, 1.0)
    }

    // MARK: - 8. Helped component: all notHelped → 0.0

    func testHelpedAllNotHelpedReturnsZero() async throws {
        let scorer = BASMemoryImportanceScorer()
        let records = (0..<5).map { _ in
            makeRecord(
                retrievedAt: referenceNow,
                helped: .notHelped)
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: records,
            now: referenceNow)
        XCTAssertEqual(score.helpedComponent, 0.0)
    }

    // MARK: - 9. Helped component: half-credit on unknown

    func testHelpedAllUnknownReturnsHalf() async throws {
        let scorer = BASMemoryImportanceScorer()
        let records = (0..<5).map { _ in
            makeRecord(
                retrievedAt: referenceNow,
                helped: .unknown)
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .warm,
            records: records,
            now: referenceNow)
        XCTAssertEqual(score.helpedComponent, 0.5)
    }

    // MARK: - 10. Tier decay: per-tier constants

    func testTierDecayPerTier() async throws {
        let scorer = BASMemoryImportanceScorer()
        let hot = scorer.score(
            atomID: "atom-1", currentTier: .hot,
            records: [], now: referenceNow)
        let warm = scorer.score(
            atomID: "atom-1", currentTier: .warm,
            records: [], now: referenceNow)
        let cold = scorer.score(
            atomID: "atom-1", currentTier: .cold,
            records: [], now: referenceNow)
        XCTAssertEqual(
            hot.tierDecayComponent,
            BASMemoryImportanceScorer.defaultTierDecayHot)
        XCTAssertEqual(
            warm.tierDecayComponent,
            BASMemoryImportanceScorer.defaultTierDecayWarm)
        XCTAssertEqual(
            cold.tierDecayComponent,
            BASMemoryImportanceScorer.defaultTierDecayCold)
    }

    // MARK: - 11. Hot atom with no usage → demoted

    func testHotAtomNoUsageRecommendsDemote() async throws {
        let scorer = BASMemoryImportanceScorer()
        let weekOld = referenceNow
            .addingTimeInterval(-7 * 86_400)
        let score = scorer.score(
            atomID: "atom-stale",
            currentTier: .hot,
            records: [
                makeRecord(retrievedAt: weekOld)
            ],
            now: referenceNow)
        XCTAssertLessThan(
            score.totalScore,
            BASMemoryImportanceScorer.defaultDemoteThreshold)
        XCTAssertEqual(score.recommendedTier, .warm)
    }

    // MARK: - 12. Cold atom with hot usage → promoted

    func testColdAtomHighUsageRecommendsPromote() async throws {
        let scorer = BASMemoryImportanceScorer()
        // 30 retrievals all helped, all in past hour.
        let records = (0..<30).map { i in
            makeRecord(
                atomID: "atom-cold",
                retrievedAt: referenceNow
                    .addingTimeInterval(-Double(i * 60)),
                helped: .helped)
        }
        let score = scorer.score(
            atomID: "atom-cold",
            currentTier: .cold,
            records: records,
            now: referenceNow)
        XCTAssertGreaterThanOrEqual(
            score.totalScore,
            BASMemoryImportanceScorer.defaultPromoteThreshold)
        XCTAssertEqual(score.recommendedTier, .warm)
    }

    // MARK: - 13. Hot atom already at top → stays hot on promote

    func testHotAtomCannotPromoteAboveHot() async throws {
        let scorer = BASMemoryImportanceScorer()
        let records = (0..<30).map { i in
            makeRecord(
                atomID: "atom-1",
                retrievedAt: referenceNow
                    .addingTimeInterval(-Double(i * 60)),
                helped: .helped)
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .hot,
            records: records,
            now: referenceNow)
        XCTAssertEqual(score.recommendedTier, .hot)
    }

    // MARK: - 14. Cold atom already at bottom → stays cold on demote

    func testColdAtomCannotDemoteBelowCold() async throws {
        let scorer = BASMemoryImportanceScorer()
        let weekOld = referenceNow
            .addingTimeInterval(-30 * 86_400)
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .cold,
            records: [
                makeRecord(
                    retrievedAt: weekOld,
                    helped: .notHelped)
            ],
            now: referenceNow)
        XCTAssertEqual(score.recommendedTier, .cold)
    }

    // MARK: - 15. Total score in [0, 1]

    func testTotalScoreClampedTo01() async throws {
        let scorer = BASMemoryImportanceScorer()
        let bigBatch = (0..<1000).map { i in
            makeRecord(
                retrievedAt: referenceNow
                    .addingTimeInterval(-Double(i)),
                helped: .helped)
        }
        let score = scorer.score(
            atomID: "atom-1",
            currentTier: .hot,
            records: bigBatch,
            now: referenceNow)
        XCTAssertGreaterThanOrEqual(score.totalScore, 0)
        XCTAssertLessThanOrEqual(score.totalScore, 1)
    }

    // MARK: - 16. scoreAll aggregates promotion/demotion counts

    func testScoreAllAggregatesCounts() async throws {
        let scorer = BASMemoryImportanceScorer()
        // atom-hot — many recent helped events → should
        // recommend promote
        let hotRecords = (0..<30).map { i in
            makeRecord(
                atomID: "atom-hot",
                retrievedAt: referenceNow
                    .addingTimeInterval(-Double(i * 60)),
                helped: .helped)
        }
        // atom-stale — old retrieval → demote
        let staleRecords = [
            makeRecord(
                atomID: "atom-stale",
                retrievedAt: referenceNow
                    .addingTimeInterval(-7 * 86_400))
        ]
        // atom-fresh — recent but not enough to promote
        let freshRecords = [
            makeRecord(
                atomID: "atom-fresh",
                retrievedAt: referenceNow
                    .addingTimeInterval(-3600))
        ]

        let report = scorer.scoreAll(
            atomTiers: [
                "atom-hot": .cold,
                "atom-stale": .hot,
                "atom-fresh": .warm
            ],
            records: hotRecords + staleRecords + freshRecords,
            now: referenceNow)
        XCTAssertEqual(report.scores.count, 3)
        XCTAssertGreaterThanOrEqual(report.promotionCount, 1)
        XCTAssertGreaterThanOrEqual(report.demotionCount, 1)
    }

    // MARK: - 17. scoreAll filters mutations correctly

    func testReportMutationsContainsOnlyChanges() async throws {
        let scorer = BASMemoryImportanceScorer()
        let report = scorer.scoreAll(
            atomTiers: [
                "atom-stale": .hot
            ],
            records: [
                makeRecord(
                    atomID: "atom-stale",
                    retrievedAt: referenceNow
                        .addingTimeInterval(-30 * 86_400))
            ],
            now: referenceNow)
        let mutations = report.mutations
        XCTAssertEqual(mutations.count, 1)
        XCTAssertEqual(mutations.first?.changesTier, true)
    }

    // MARK: - 18. Determinism given fixed `now`

    func testScoringDeterministicForFixedNow() async throws {
        let scorer = BASMemoryImportanceScorer()
        let records = (0..<10).map { i in
            makeRecord(
                retrievedAt: referenceNow
                    .addingTimeInterval(-Double(i * 100)),
                helped: i % 2 == 0 ? .helped : .unknown)
        }
        let s1 = scorer.score(
            atomID: "atom-d", currentTier: .warm,
            records: records, now: referenceNow)
        let s2 = scorer.score(
            atomID: "atom-d", currentTier: .warm,
            records: records, now: referenceNow)
        XCTAssertEqual(s1.totalScore, s2.totalScore)
        XCTAssertEqual(s1.recommendedTier, s2.recommendedTier)
    }

    // MARK: - 19. Init clamping protects misuse

    func testInitClampsThresholdsTo01() {
        let bad = BASMemoryImportanceScorer(
            promoteThreshold: 5.0,
            demoteThreshold: -1.0)
        XCTAssertEqual(bad.promoteThreshold, 1.0)
        XCTAssertEqual(bad.demoteThreshold, 0.0)
    }
}
