// MARK: - BASPhaseJKLCompletionHexaCatalogDoctrineWireInTests
// chapter 六百七十六 / M2083 — wire-in PROOF tests cross-
//                              checking the M2081 hexa #9
//                              catalog against the 4 source
//                              phase-completion doctrines。
//
// Anti-drift principle:the catalog's literal field values
// must agree with the corresponding facts on the SOURCE
// phase doctrines。 If a future commit bumps a Phase J/K/L
// metric in the source doctrine but forgets to bump the
// catalog,this test fails loudly with a typed wire-in.
//
// This is STRONGER than typing the value as a constant in
// the catalog (M2082 anti-drift suite did that),because a
// constant can stay correct vs. itself even after the
// source drifts。 Wire-in tests cross both surfaces。

import XCTest
@testable import BASRuntimeCore

final class BASPhaseJKLCompletionHexaCatalogDoctrineWireInTests:
    XCTestCase
{
    typealias C = BASPhaseJKLCompletionHexaCatalogDoctrine

    // MARK: - Entry 1 wire-in against Phase J source doctrine

    typealias J = BASPhaseJKernelCacheCompletionDoctrine

    func testEntry1ChapterRangeStartWiresIn() {
        XCTAssertEqual(
            C.entries[0].chapterRangeStart,
            J.phaseStartChapter)
    }

    func testEntry1ChapterRangeEndWiresIn() {
        XCTAssertEqual(
            C.entries[0].chapterRangeEnd,
            J.phaseEndChapter)
    }

    func testEntry1MNumberFirstWiresIn() {
        XCTAssertEqual(
            C.entries[0].mNumberFirst,
            J.phaseStartMNumber)
    }

    func testEntry1MNumberLastWiresIn() {
        XCTAssertEqual(
            C.entries[0].mNumberLast,
            J.phaseEndMNumber)
    }

    func testEntry1ChaptersInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[0].chaptersInRange,
            J.phaseChapterCount)
    }

    func testEntry1CommitsInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[0].commitsInRange,
            J.phaseCommitCount)
    }

    func testEntry1ScoreDeltaWiresIn() {
        XCTAssertEqual(
            C.entries[0].scoreDelta,
            J.phaseJScoreDeltaTarget)
    }

    // MARK: - Entry 2 wire-in against Phase K source doctrine

    typealias K = BASPhaseKRuntimeModeToggleCompletionDoctrine

    func testEntry2ChapterRangeStartWiresIn() {
        XCTAssertEqual(
            C.entries[1].chapterRangeStart,
            K.phaseStartChapter)
    }

    func testEntry2ChapterRangeEndWiresIn() {
        XCTAssertEqual(
            C.entries[1].chapterRangeEnd,
            K.phaseEndChapter)
    }

    func testEntry2MNumberFirstWiresIn() {
        XCTAssertEqual(
            C.entries[1].mNumberFirst,
            K.phaseStartMNumber)
    }

    func testEntry2MNumberLastWiresIn() {
        XCTAssertEqual(
            C.entries[1].mNumberLast,
            K.phaseEndMNumber)
    }

    func testEntry2ChaptersInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[1].chaptersInRange,
            K.phaseChapterCount)
    }

    func testEntry2CommitsInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[1].commitsInRange,
            K.phaseCommitCount)
    }

    func testEntry2ScoreDeltaWiresIn() {
        XCTAssertEqual(
            C.entries[1].scoreDelta,
            K.phaseKScoreDeltaTarget)
    }

    // MARK: - Entry 3 wire-in against Phase L source doctrine

    typealias L = BASPhaseLCumulativeCompletionDoctrine

    func testEntry3ChapterRangeStartWiresIn() {
        XCTAssertEqual(
            C.entries[2].chapterRangeStart,
            L.phaseStartChapter)
    }

    func testEntry3ChapterRangeEndWiresIn() {
        XCTAssertEqual(
            C.entries[2].chapterRangeEnd,
            L.phaseEndChapter)
    }

    func testEntry3MNumberFirstWiresIn() {
        XCTAssertEqual(
            C.entries[2].mNumberFirst,
            L.phaseStartMNumber)
    }

    func testEntry3MNumberLastWiresIn() {
        XCTAssertEqual(
            C.entries[2].mNumberLast,
            L.phaseEndMNumber)
    }

    func testEntry3ChaptersInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[2].chaptersInRange,
            L.phaseChapterCount)
    }

    func testEntry3CommitsInRangeWiresIn() {
        XCTAssertEqual(
            C.entries[2].commitsInRange,
            L.phaseCommitCount)
    }

    func testEntry3ScoreDeltaWiresIn() {
        XCTAssertEqual(
            C.entries[2].scoreDelta,
            L.phaseLScoreDeltaTarget)
    }

    // MARK: - Entry 4 wire-in against THE FLIP source doctrine

    typealias F = BASPhaseLDefaultFlipCompletionDoctrine

    func testEntry4MNumberFirstWiresIn() {
        XCTAssertEqual(
            C.entries[3].mNumberFirst,
            F.flipMNumber)
    }

    func testEntry4MNumberLastWiresIn() {
        XCTAssertEqual(
            C.entries[3].mNumberLast,
            F.flipMNumber)
    }

    func testEntry4ChapterRangeStartWiresIn() {
        XCTAssertEqual(
            C.entries[3].chapterRangeStart,
            F.chapterTag)
    }

    func testEntry4ChapterRangeEndWiresIn() {
        XCTAssertEqual(
            C.entries[3].chapterRangeEnd,
            F.chapterTag)
    }

    // MARK: - Phase J/K/L score-progression chain wire-in

    func testPhaseJPreToPostScoreMatchesSourceDoctrine() {
        XCTAssertEqual(J.preResumptionScore, 45)
        XCTAssertEqual(J.postPhaseJScore, 51)
    }

    func testPhaseKPreToPostScoreMatchesSourceDoctrine() {
        XCTAssertEqual(K.postPhaseJScore, 51)
        XCTAssertEqual(K.postPhaseKScore, 54)
    }

    func testPhaseLPreToPostScoreMatchesSourceDoctrine() {
        XCTAssertEqual(L.prePhaseLScore, 54)
        XCTAssertEqual(L.postPhaseLScore, 58)
    }

    func testFlipPreToPostScoreMatchesSourceDoctrine() {
        XCTAssertEqual(F.prePhaseLScore, 54)
        XCTAssertEqual(F.postPhaseLScore, 58)
    }

    func testAggregateScoreAfterWiresInToPhaseLPost() {
        XCTAssertEqual(
            C.aggregateScoreAfter,
            L.postPhaseLScore)
    }

    func testAggregateScoreBeforeWiresInToPhaseJPre() {
        XCTAssertEqual(
            C.aggregateScoreBefore,
            J.preResumptionScore)
    }

    // MARK: - Aggregate-level chapter/commit consistency

    func testAggregateChaptersMatchSourceDoctrineSum() {
        let sum = J.phaseChapterCount
            + K.phaseChapterCount
            + L.phaseChapterCount
        XCTAssertEqual(
            C.totalChaptersAcrossPhaseEntries, sum)
        XCTAssertEqual(C.totalChaptersClaimed, sum)
    }

    func testAggregateCommitsMatchSourceDoctrineSum() {
        let sum = J.phaseCommitCount
            + K.phaseCommitCount
            + L.phaseCommitCount
        XCTAssertEqual(
            C.totalCommitsAcrossPhaseEntries, sum)
        XCTAssertEqual(C.totalCommitsClaimed, sum)
    }

    // MARK: - Run-range wire-in

    func testRunFirstMNumberWiresInToPhaseJStart() {
        XCTAssertEqual(
            C.runFirstMNumber, J.phaseStartMNumber)
    }

    func testRunLastMNumberWiresInToPhaseLEnd() {
        XCTAssertEqual(
            C.runLastMNumber, L.phaseEndMNumber)
    }

    func testRunChapterStartWiresInToPhaseJStart() {
        XCTAssertEqual(
            C.runChapterStart, J.phaseStartChapter)
    }

    func testRunChapterEndWiresInToPhaseLEnd() {
        XCTAssertEqual(
            C.runChapterEnd, L.phaseEndChapter)
    }

    // MARK: - Next-phase pointer wire-in

    func testNextPhasePointerMatchesPhaseLNextPhase() {
        XCTAssertEqual(C.nextPhase, L.nextPhase)
        XCTAssertEqual(
            C.nextPhaseChapter, L.nextPhaseChapter)
    }

    func testNextPhasePointerMatchesFlipNextPhase() {
        XCTAssertEqual(C.nextPhase, F.nextPhase)
        XCTAssertEqual(
            C.nextPhaseChapter, F.nextPhaseChapter)
    }

    // MARK: - Range contiguity proof — Phase J ends where Phase K begins

    func testPhaseJEndPlusOneEqualsPhaseKStart() {
        XCTAssertEqual(
            J.phaseEndMNumber + 1, K.phaseStartMNumber,
            "Phase J ends at M\(J.phaseEndMNumber) and " +
            "Phase K starts at M\(K.phaseStartMNumber) — " +
            "contiguous (no gap)")
    }

    func testPhaseKEndPlusOneEqualsPhaseLStart() {
        XCTAssertEqual(
            K.phaseEndMNumber + 1, L.phaseStartMNumber,
            "Phase K ends at M\(K.phaseEndMNumber) and " +
            "Phase L starts at M\(L.phaseStartMNumber) — " +
            "contiguous (no gap)")
    }

    // MARK: - Flip is contained within Phase L

    func testFlipMNumberIsWithinPhaseLRange() {
        XCTAssertGreaterThanOrEqual(
            F.flipMNumber, L.phaseStartMNumber)
        XCTAssertLessThanOrEqual(
            F.flipMNumber, L.phaseEndMNumber)
    }
}
