// MARK: - BASEBrainTurnResultClusterBundleCodableArcSealedDoctrineTests
// chapter 五百四十八 / M1570 — anti-drift PROOF tests for
//                              the 6-chapter Codable arc
//                              sealed doctrine

import XCTest
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableArcSealedDoctrineTests:
    XCTestCase
{

    // MARK: - Arc shape invariants

    func testArcChapterCountIsSeven() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcChapterCount,
            7)
    }

    func testChaptersArrayLengthIsSeven() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters.count,
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcChapterCount)
    }

    func testArcFirstMNumberIs1541() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcFirstMNumber,
            1541)
    }

    func testArcLastMNumberIs1568() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcLastMNumber,
            1568)
    }

    func testArcCommitCountIsTwentyEight() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcCommitCount,
            28,
            "7 chapters × 4 commits = 28")
    }

    // MARK: - 100% milestone invariants

    func testFinalExplicitCoverageCountIsNine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .finalExplicitCoverageCount,
            9)
    }

    func testFinalCoverageRatioIsExactlyOne() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .finalCoverageRatio,
            1.0)
    }

    func testHundredPercentMilestoneAchievedInvariantHolds() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .hundredPercentMilestoneAchieved,
            "100% milestone invariant must hold:" +
            " coverage == 9 AND ratio == 1.0")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .byteEqualityPreserved)
    }

    // MARK: - Per-chapter entries

    func testChapter541IsFirst() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters.first!.chapterTag,
            "chapter 五百四十一")
    }

    func testChapter547IsLast() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters.last!.chapterTag,
            "chapter 五百四十七")
    }

    func testChaptersAreChronologicallyOrdered() {
        let chapters =
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters
        for i in 1..<chapters.count {
            XCTAssertGreaterThan(
                chapters[i].mNumberFirst,
                chapters[i - 1].mNumberLast,
                "Chapters must have strictly ascending " +
                "non-overlapping M-number ranges")
        }
    }

    func testCoverageProgressesMonotonically() {
        let chapters =
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters
        for i in 1..<chapters.count {
            XCTAssertGreaterThanOrEqual(
                chapters[i].coverageAfterChapter,
                chapters[i - 1].coverageAfterChapter,
                "Coverage must be monotonically non-" +
                "decreasing across chapters")
        }
    }

    func testFinalChapterReachesNineCoverage() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters.last!.coverageAfterChapter,
            9)
    }

    // MARK: - Replay-determinism PROOF method pin

    func testReplayDeterminismProofMethodPinned() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .replayDeterminismProof,
            "codable-sortedKeys-json-round-trip-deterministic-fixtures")
    }
}
