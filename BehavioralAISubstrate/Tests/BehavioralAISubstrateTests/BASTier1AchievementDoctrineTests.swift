// MARK: - BASTier1AchievementDoctrineTests
// chapter 四百九十 / M1337

import XCTest
@testable import BASRuntimeCore

final class BASTier1AchievementDoctrineTests: XCTestCase {

    func testSixDirectivesCovered() {
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .achievements.count, 6)
    }

    func testChapterRangePinned() {
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .chapterRange.lowerBound, 474)
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .chapterRange.upperBound, 490)
    }

    func testMNumberRangePinned() {
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .mNumberRange.lowerBound, 1272)
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .mNumberRange.upperBound, 1339)
    }

    func testTotalCommitsAndChapters() {
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .totalCommits, 68)
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .totalChapters, 17)
    }

    func testAggregateScore() {
        // 9 + 7 + 8 + 5 + 8 + 8 = 45
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .aggregateScore, 45)
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .maxAggregate, 60)
    }

    func testAggregateRatio() {
        XCTAssertEqual(
            BASTier1AchievementDoctrine
                .aggregateRatio,
            45.0 / 60.0, accuracy: 0.001)
    }

    func testEveryDirectiveHasEvidence() {
        for ach in BASTier1AchievementDoctrine
            .achievements
        {
            XCTAssertFalse(
                ach.evidenceShipped.isEmpty,
                "directive '\(ach.directiveName)'" +
                " must have evidence")
        }
    }

    func testEveryDirectiveAcknowledgesGap() {
        for ach in BASTier1AchievementDoctrine
            .achievements
        {
            XCTAssertFalse(
                ach.remainingGapToTen.isEmpty,
                "directive '\(ach.directiveName)'" +
                " must acknowledge gap to 10/10")
        }
    }

    func testHonestSummaryFormatted() {
        let summary = BASTier1AchievementDoctrine
            .honestSummary
        XCTAssertTrue(summary.contains("45/60"),
            "summary must report actual aggregate")
        XCTAssertTrue(summary.contains("Tier 2"),
            "summary must acknowledge Tier 2 deferred")
    }

    func testCodableRoundTrip() throws {
        let achievements = BASTier1AchievementDoctrine
            .achievements
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(achievements)
        let decoded = try JSONDecoder().decode(
            [BASTier1DirectiveAchievement].self,
            from: data)
        XCTAssertEqual(decoded, achievements)
    }
}
