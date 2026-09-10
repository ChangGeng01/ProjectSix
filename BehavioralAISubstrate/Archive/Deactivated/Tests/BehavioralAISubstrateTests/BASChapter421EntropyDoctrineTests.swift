import XCTest
@testable import BASRuntimeCore


// chapter 七百五十二 第一刀 / M2430 — per-chapter test
// REDUCED per user directive 「大幅度 缩减 doctrine。
// 对比 之后 有必要的 全面 comment」。 The unified
// BASChapterDoctrineSchemaCompletenessTests registry-iteration
// test now covers the same invariants for every chapter。
// Historical body preserved verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十二 第一刀 deactivated
final class BASChapter421EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.chapterTag,
            "chapter 四百二十一")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberFirst,
            1054)
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberLast,
            1057)
    }

    func testV1MilestoneIsAtM1057() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.v1MilestoneMNumber,
            1057)
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.v1MilestoneStatus,
            "chapter-421-v1-v2-phase-2-close-out")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter421EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1054, 1055, 1056, 1057])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter421EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter421EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM420AndM421RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.mNumberLast + 1,
            BASChapter421EntropyDoctrine.mNumberFirst)
    }

    // MARK: - Phase 2 chapter membership cross-checks

    // Chapter 四百二十一 was Phase 2's terminal chapter at
    // M1057 close-out。 Phase 2 has since been extended via
    // chapter 四百二十二+ (M1058+) so the doctrine's
    // `mNumberLast` / `chapterTagsShipped.last` no longer
    // point at chapter 四百二十一。 What still holds:chapter
    // 四百二十一 IS a member of Phase 2,and its M-range fits
    // within Phase 2's overall range。
    func testChapter421IsMemberOfPhase2Doctrine() {
        XCTAssertTrue(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped
                .contains(
                    BASChapter421EntropyDoctrine.chapterTag),
            "chapter 四百二十一 must remain in Phase 2 chapter" +
            " list across post-M1057 extensions")
    }

    func testChapter421MNumberRangeFitsWithinPhase2() {
        XCTAssertGreaterThanOrEqual(
            BASChapter421EntropyDoctrine.mNumberFirst,
            BASPhase2EntropyClosureDoctrine.mNumberFirst,
            "M-first must be ≥ Phase 2 first")
        XCTAssertLessThanOrEqual(
            BASChapter421EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast,
            "M-last must be ≤ Phase 2 last (extensions" +
            " strictly grow the upper bound)")
    }
}

#endif  // chapter 七百五十二 第一刀
