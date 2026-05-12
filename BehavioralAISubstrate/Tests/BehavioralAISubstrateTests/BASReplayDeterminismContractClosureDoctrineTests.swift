// MARK: - BASReplayDeterminismContractClosureDoctrineTests
// chapter 五百六十 / M1618 — anti-drift PROOF tests for
//                          the M1617 milestone
//                          doctrine
//
// ## Coverage matrix (17 tests)
//
//   - Pin invariants (chapterTag,milestoneMNumber,
//     contractOriginChapter,contractClosed flag,
//     6 boolean / string flag pins)
//   - List + count invariants (3 halves,3 round-
//     trip doctrines,9 contributing chapters,total
//     proof doctrine count = 5)
//   - Arc range invariants (arcFirstMNumber,
//     arcLastMNumber,arcMNumberSpan = 37)
//   - First / last contributing chapter pins
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:single source-of-truth pins
//   - chapter 三百九二:this doctrine commemorates
//     closing that contract
//   - ADR-016 advances M1617 → M1618

import XCTest
@testable import BASRuntimeCore

final class BASReplayDeterminismContractClosureDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter560() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .chapterTag,
            "chapter 五百六十")
    }

    func testMilestoneMNumberIs1617() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .milestoneMNumber,
            1617)
    }

    func testContractOriginChapterIs392() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .contractOriginChapter,
            "chapter 三百九二")
    }

    func testContractClosedFlagSet() {
        XCTAssertTrue(
            BASReplayDeterminismContractClosureDoctrine
                .contractClosed)
    }

    func testAllHalvesHaveDoctrineSurfacesFlagSet() {
        XCTAssertTrue(
            BASReplayDeterminismContractClosureDoctrine
                .allHalvesHaveDoctrineSurfaces)
    }

    func testCenturyMilestoneInsideArcFlagSet() {
        XCTAssertTrue(
            BASReplayDeterminismContractClosureDoctrine
                .centuryMilestoneInsideArc)
    }

    func testDoubleCenturyLandmarkInsideArcFlagSet() {
        XCTAssertTrue(
            BASReplayDeterminismContractClosureDoctrine
                .doubleCenturyLandmarkInsideArc)
    }

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASReplayDeterminismContractClosureDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testStrictestVerificationMethodPinned() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .strictestVerificationMethod,
            "bit-pattern-equality-for-doubles-byte-identical-for-everything-else")
    }

    // MARK: - List + count invariants

    func testVerificationHalvesHasThreeEntries() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .verificationHalves.count,
            3)
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .verificationHalfCount,
            3)
    }

    func testRoundTripDoctrineRefsHasThreeEntries() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .roundTripDoctrineRefs.count,
            3)
    }

    func testTotalProofDoctrineCountIsFive() {
        // 3 round-trip + 1 rejection + 1 floating-point
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .totalProofDoctrineCount,
            5)
    }

    func testChaptersContributingHasNineEntries() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .chaptersContributingToClosure.count,
            9)
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .contributingChapterCount,
            9)
    }

    // MARK: - Arc range invariants

    func testArcFirstMNumberIs1581() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .arcFirstMNumber,
            1581)
    }

    func testArcLastMNumberIs1617() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .arcLastMNumber,
            1617)
    }

    func testArcMNumberSpanIsThirtySeven() {
        // 1617 - 1581 + 1 = 37
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .arcMNumberSpan,
            37)
    }

    // MARK: - First / last chapter pins

    func testFirstContributingChapterIs551() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .firstContributingChapter,
            "chapter 五百五十一")
    }

    func testLastContributingChapterIs560() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .lastContributingChapter,
            "chapter 五百六十")
    }
}
