// MARK: - BASTier1HonestClosureMilestoneDoctrineTests
// chapter 五百一 / M1381 — Tier 1 honest milestone tests

import XCTest
@testable import BASRuntimeCore

final class BASTier1HonestClosureMilestoneDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Supplemental chapter range pin

    func testSupplementalChapterRangePin() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .supplementalChapterRange,
            498...501)
    }

    func testSupplementalMNumberRangePin() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .supplementalMNumberRange,
            1369...1384)
    }

    func testSupplementalCommitsAndChapters() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .supplementalCommits, 16)
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .supplementalChapters, 4)
    }

    func testNewTypedSurfacesCount() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .newTypedSurfaces, 9)
    }

    // MARK: - 2) 6 directives all bumped

    func testSixDirectivesBumped() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .bumps.count, 6,
            "Tier 1 closure milestone MUST cover all 6" +
            " user directives (parity with Tier 1" +
            " baseline doctrine)")
    }

    func testDirectiveNamesMatchTier1Baseline() {
        let bumpedNames = Set(
            BASTier1HonestClosureMilestoneDoctrine
                .bumps.map(\.directiveName))
        let baselineNames = Set(
            BASTier1AchievementDoctrine.achievements
                .map(\.directiveName))
        XCTAssertEqual(bumpedNames, baselineNames,
            "milestone directive names MUST mirror" +
            " Tier 1 baseline for side-by-side delta" +
            " comparison")
    }

    // MARK: - 3) All bumps have non-negative delta

    func testAllBumpsHaveNonNegativeDelta() {
        for bump in
            BASTier1HonestClosureMilestoneDoctrine.bumps
        {
            XCTAssertGreaterThanOrEqual(bump.delta, 0,
                "directive \(bump.directiveName) bump" +
                " MUST be >= 0 (honest progress only)")
        }
    }

    // MARK: - 4) Aggregate delta sums correctly

    func testAggregateDeltaSumsCorrectly() {
        let expectedDelta =
            BASTier1HonestClosureMilestoneDoctrine.bumps
                .reduce(0) { $0 + $1.delta }
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .aggregateDelta,
            expectedDelta)
    }

    // MARK: - 5) New aggregate matches honest ceiling

    func testNewAggregateEqualsHonestCeiling() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .newAggregate,
            BASTier1HonestClosureMilestoneDoctrine
                .honestSubstrateCeiling,
            "Tier 1 honest closure milestone aggregate" +
            " MUST equal the documented honest substrate" +
            " ceiling (52/60)")
    }

    // MARK: - 6) Honest ceiling is documented

    func testHonestSubstrateCeilingIs52() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .honestSubstrateCeiling,
            52,
            "honest substrate ceiling at chapter 501" +
            " close-out MUST be 52/60 per the 8-point" +
            " external-blocker attribution documented" +
            " in the doctrine source")
    }

    // MARK: - 7) External-blocker reasons documented

    func testExternalBlockerReasonsDocumented() {
        let reasons =
            BASTier1HonestClosureMilestoneDoctrine
                .externalBlockerReasons
        XCTAssertGreaterThan(reasons.count, 0,
            "external blockers MUST be typed-enumerated" +
            " — gap to 60/60 is honestly attributed")
        for reason in reasons {
            XCTAssertFalse(reason.isEmpty)
        }
    }

    // MARK: - 8) Accounting invariant holds (NO SILENT
    //             UNDER-DELIVERY)

    func testAccountedForCorrectlyInvariant() {
        XCTAssertTrue(
            BASTier1HonestClosureMilestoneDoctrine
                .accountedForCorrectly,
            "INVARIANT: newAggregate +" +
            " external-blocker-points == maxAggregate" +
            " (60)。 If this fails the doctrine has" +
            " silent under-delivery drift")
    }

    // MARK: - 9) maxAggregate = directiveCount × 10

    func testMaxAggregateMatchesDirectiveCount() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .maxAggregate, 60)
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .maxAggregate,
            BASTier1HonestClosureMilestoneDoctrine
                .bumps.count * 10)
    }

    // MARK: - 10) baselineAggregate matches Tier 1
    //             baseline doctrine

    func testBaselineAggregateMatchesTier1Baseline() {
        XCTAssertEqual(
            BASTier1HonestClosureMilestoneDoctrine
                .baselineAggregate,
            BASTier1AchievementDoctrine
                .aggregateScore,
            "baselineAggregate MUST equal" +
            " BASTier1AchievementDoctrine.aggregateScore" +
            " — milestone tracks delta FROM that baseline")
    }

    // MARK: - 11) Bumps where currentScore < 10 have
    //             deferral reason

    func testNonMaxBumpsHaveDeferralReason() {
        for bump in
            BASTier1HonestClosureMilestoneDoctrine.bumps
        {
            if bump.bumpedScore < 10 {
                XCTAssertNotNil(bump.deferralReason,
                    "directive \(bump.directiveName) at" +
                    " \(bump.bumpedScore)/10 MUST have" +
                    " a deferralReason explaining the" +
                    " remaining gap honestly")
            }
        }
    }

    // MARK: - 12) Bumps where currentScore == 10 have
    //             no deferral reason

    func testMaxBumpsHaveNoDeferralReason() {
        for bump in
            BASTier1HonestClosureMilestoneDoctrine.bumps
        {
            if bump.bumpedScore == 10 {
                XCTAssertNil(bump.deferralReason,
                    "directive \(bump.directiveName)" +
                    " at 10/10 MUST NOT have deferral" +
                    " reason (no gap to attribute)")
            }
        }
    }

    // MARK: - 13) Honest summary mentions key markers

    func testHonestSummaryMentionsKeyMarkers() {
        let summary =
            BASTier1HonestClosureMilestoneDoctrine
                .honestSummary
        XCTAssertTrue(summary.contains("baseline"))
        XCTAssertTrue(summary.contains("bumped"))
        XCTAssertTrue(summary
            .contains("substrate"))
        XCTAssertTrue(summary
            .contains("ceiling"))
        XCTAssertTrue(summary
            .contains("external blockers"))
    }

    // MARK: - 14) Bump record Codable round-trip

    func testBumpRecordCodableRoundTrip() throws {
        let original = BASTier1DirectiveBumpRecord(
            directiveName: "test",
            baselineScore: 7,
            bumpedScore: 9,
            bumpEvidence: ["e1", "e2"],
            deferralReason: "test gap")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTier1DirectiveBumpRecord.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.delta, 2)
    }
}
