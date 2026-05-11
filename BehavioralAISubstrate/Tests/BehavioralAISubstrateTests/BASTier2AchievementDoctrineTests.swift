// MARK: - BASTier2AchievementDoctrineTests
// chapter 四百九十七 / M1366 — Tier 2 typed milestone tests

import XCTest
@testable import BASRuntimeCore

final class BASTier2AchievementDoctrineTests: XCTestCase {

    // MARK: - 1) Chapter + M-number range pin

    func testChapterRangeIs495To497() {
        XCTAssertEqual(
            BASTier2AchievementDoctrine.chapterRange,
            495...497)
    }

    func testMNumberRangeCoversTier2() {
        XCTAssertEqual(
            BASTier2AchievementDoctrine.mNumberRange,
            1357...1368)
    }

    // MARK: - 2) Commits + chapters count

    func testTotalCommitsAndChaptersMatchPlan() {
        XCTAssertEqual(
            BASTier2AchievementDoctrine.totalCommits, 12)
        XCTAssertEqual(
            BASTier2AchievementDoctrine.totalChapters, 3)
    }

    // MARK: - 3) Per-directive coverage

    func testSixDirectivesCovered() {
        XCTAssertEqual(
            BASTier2AchievementDoctrine.achievements
                .count,
            6,
            "Tier 2 must cover all 6 user directives" +
            " (parity with Tier 1)")
    }

    func testDirectiveNamesMatchTier1Set() {
        let tier2Names = Set(
            BASTier2AchievementDoctrine.achievements
                .map(\.directiveName))
        let tier1Names = Set(
            BASTier1AchievementDoctrine.achievements
                .map(\.directiveName))
        XCTAssertEqual(tier2Names, tier1Names,
            "Tier 2 directive names must mirror Tier 1" +
            " (allows side-by-side delta comparison)")
    }

    // MARK: - 4) Per-directive scores are in [0, 10]

    func testScoresWithinRange() {
        for achievement in
            BASTier2AchievementDoctrine.achievements
        {
            XCTAssertGreaterThanOrEqual(
                achievement.currentScore, 0)
            XCTAssertLessThanOrEqual(
                achievement.currentScore, 10)
        }
    }

    // MARK: - 5) Aggregate score sums correctly

    func testAggregateScoreSumsCorrectly() {
        let expected =
            BASTier2AchievementDoctrine.achievements
                .reduce(0) { $0 + $1.currentScore }
        XCTAssertEqual(
            BASTier2AchievementDoctrine.aggregateScore,
            expected)
    }

    // MARK: - 6) maxAggregate = directiveCount × 10

    func testMaxAggregateMatchesDirectiveCount() {
        XCTAssertEqual(
            BASTier2AchievementDoctrine.maxAggregate,
            BASTier2AchievementDoctrine.achievements
                .count * 10)
    }

    // MARK: - 7) Aggregate ratio in [0, 1]

    func testAggregateRatioInRange() {
        let r = BASTier2AchievementDoctrine
            .aggregateRatio
        XCTAssertGreaterThanOrEqual(r, 0.0)
        XCTAssertLessThanOrEqual(r, 1.0)
    }

    // MARK: - 8) External blockers exposed as typed list

    func testExternalBlockersList() {
        let blockers =
            BASTier2AchievementDoctrine.externalBlockers
        XCTAssertGreaterThan(blockers.count, 0,
            "Tier 2 explicitly documents external" +
            " blockers honestly — list should not be" +
            " empty at chapter 497 close-out")
    }

    // MARK: - 9) Honest summary contains key markers

    func testHonestSummaryHasMarkers() {
        let summary = BASTier2AchievementDoctrine
            .honestSummary
        XCTAssertTrue(summary
            .contains("external-blocker"))
        XCTAssertTrue(summary
            .contains("chapters"))
        XCTAssertTrue(summary
            .contains("blockers documented honestly"))
    }

    // MARK: - 10) Codable round-trip on achievement record

    func testAchievementCodableRoundTrip() throws {
        let original = BASTier2DirectiveAchievement(
            directiveName: "test-directive",
            tier2DeltaFromTier1: 2,
            currentScore: 7,
            evidenceShipped: ["e1", "e2"],
            remainingGapToTen: "test gap",
            externalBlocker: "test blocker")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTier2DirectiveAchievement.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
