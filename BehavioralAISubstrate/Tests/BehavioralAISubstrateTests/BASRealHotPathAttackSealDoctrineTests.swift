// MARK: - BASRealHotPathAttackSealDoctrineTests
// chapter 四百九十七 / M1367 — REAL HOT-PATH ATTACK seal tests

import XCTest
@testable import BASRuntimeCore

final class BASRealHotPathAttackSealDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Arc range pin

    func testChapterRangeSpansArc() {
        XCTAssertEqual(
            BASRealHotPathAttackSealDoctrine.chapterRange,
            474...497)
    }

    func testMNumberRangeSpansArc() {
        XCTAssertEqual(
            BASRealHotPathAttackSealDoctrine.mNumberRange,
            1272...1368)
    }

    func testTotalCommitsCountMatchesArc() {
        XCTAssertEqual(
            BASRealHotPathAttackSealDoctrine.totalCommits,
            92)
    }

    // MARK: - 2) Final scoring uses Tier 1 + Tier 2

    func testFinalScoringReferencesTier1AndTier2() {
        let f = BASRealHotPathAttackSealDoctrine
            .finalScoring
        XCTAssertEqual(f.tier1Score,
            BASTier1AchievementDoctrine.aggregateScore)
        XCTAssertEqual(f.tier2Score,
            BASTier2AchievementDoctrine.aggregateScore)
        XCTAssertEqual(f.maxScore,
            BASTier2AchievementDoctrine.maxAggregate)
    }

    // MARK: - 3) Final accounted-for invariant holds
    //             (no silent under-delivery)

    func testFinalAccountedForCorrectly() {
        XCTAssertTrue(
            BASRealHotPathAttackSealDoctrine
                .finalScoring.accountedForCorrectly,
            "INVARIANT: final score + external-attributed" +
            " points must equal max。 If this fails the" +
            " doctrine has silent under-delivery drift")
    }

    // MARK: - 4) External blockers documented

    func testExternalBlockersListIsNonEmpty() {
        XCTAssertGreaterThan(
            BASRealHotPathAttackSealDoctrine
                .externalBlockers.count, 0,
            "Honest scope: external blockers MUST be" +
            " typed-enumerated so future arcs can pick" +
            " them up without rediscovery")
    }

    func testExternalBlockersCarryProductionLanguage() {
        for blocker in
            BASRealHotPathAttackSealDoctrine
                .externalBlockers
        {
            XCTAssertFalse(blocker.isEmpty,
                "blocker entry must not be empty")
        }
    }

    // MARK: - 5) Final ratio in [0, 1]

    func testFinalRatioWithinValidRange() {
        let r = BASRealHotPathAttackSealDoctrine
            .finalScoring.finalRatio
        XCTAssertGreaterThanOrEqual(r, 0.0)
        XCTAssertLessThanOrEqual(r, 1.0)
    }

    // MARK: - 6) Honest summary contains key markers

    func testHonestSummaryMarkers() {
        let summary = BASRealHotPathAttackSealDoctrine
            .honestSummary
        XCTAssertTrue(summary.contains("sealed at"))
        XCTAssertTrue(summary.contains("commits"))
        XCTAssertTrue(summary.contains("external blockers"))
        XCTAssertTrue(summary
            .contains("Honest delivery"))
    }

    // MARK: - 7) Final scoring Codable round-trip

    func testFinalScoringCodableRoundTrip() throws {
        let original = BASRealHotPathAttackSealDoctrine
            .finalScoring
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRealHotPathAttackFinalScoring.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 8) Sanity check:expected delivery range

    func testFinalScoreIsInExpectedTier2Range() {
        let score = BASRealHotPathAttackSealDoctrine
            .finalScoring.finalScore
        // Tier 2 sums to ~47/60 per chapter 497 doctrine
        XCTAssertGreaterThanOrEqual(score, 40,
            "Tier 2 delivery should be at least 40/60" +
            " given the 16+ typed surfaces shipped")
        XCTAssertLessThan(score, 60,
            "Tier 2 must not claim full 60/60 — that" +
            " would silently swallow external blockers")
    }
}
