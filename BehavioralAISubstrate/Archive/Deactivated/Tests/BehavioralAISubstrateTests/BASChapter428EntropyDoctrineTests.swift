import XCTest
@testable import BASRuntimeCore


// chapter 七百五十二 第一刀 / M2430 — per-chapter test
// REDUCED per user directive 「大幅度 缩减 doctrine。
// 对比 之后 有必要的 全面 comment」。 The unified
// BASChapterDoctrineSchemaCompletenessTests registry-iteration
// test now covers the same invariants for every chapter。
// Historical body preserved verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十二 第一刀 deactivated
final class BASChapter428EntropyDoctrineTests: XCTestCase {

    // MARK: - Chapter tag

    func testChapterTagIs428() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.chapterTag,
            "chapter 四百二十八")
    }

    // MARK: - M-number range

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.mNumberFirst,
            1084)
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.mNumberLast,
            1087)
    }

    // MARK: - V1 milestone

    func testV1MilestoneIsAtM1087() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.v1MilestoneMNumber,
            1087)
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.v1MilestoneStatus,
            "chapter-428-v1-unified-event-log-payload-kinds")
    }

    // MARK: - 4-cut ledger

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter428EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1084, 1085, 1086, 1087])
    }

    // MARK: - Backfill positioning

    func testM427EndsAtM1083AndM428StartsAtM1084() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.mNumberLast, 1083)
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.mNumberFirst,
            1084,
            "Phase B backfill starts contiguous to" +
            " Phase A close-out")
    }

    func testM428EndsAtM1087AndM431StartsAtM1096() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.mNumberLast, 1087)
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberFirst,
            1096,
            "M1088-M1095 still reserved for Phase C/D" +
            " backfill (chapters 四百二十九/四百三十)")
    }

    // MARK: - Phase B pin

    func testPinHeldIncludesRadicalEvolutionPhaseB() {
        XCTAssertTrue(
            BASChapter428EntropyDoctrine.pinHeld.contains(
                "RADICAL EVOLUTION SWEEP Phase B"),
            "chapter 四百二十八 ships RADICAL EVOLUTION " +
            "SWEEP Phase B backfill (UNIFIED EVENT LOG " +
            "PAYLOAD-KINDS BACKBONE)")
    }

    func testADR016HeldNotBumped() {
        XCTAssertTrue(
            BASChapter428EntropyDoctrine.pinHeld.contains {
                $0.contains("held at M1103") ||
                    $0.contains("backfill chapter")
            },
            "Phase B backfill must explicitly note that" +
            " ADR-016 is HELD at M1103, not bumped" +
            " (M1087 < M1103)")
    }

    // MARK: - Phase 2 doctrine cross-check (membership only)

    func testChapter428IsMemberOfPhase2Doctrine() {
        XCTAssertTrue(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped
                .contains(
                    BASChapter428EntropyDoctrine.chapterTag),
            "chapter 四百二十八 must be in Phase 2 chapter list")
    }

    func testChapter428IsBeforeChapter431InList() {
        let list = BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped
        guard let i428 = list.firstIndex(
            of: "chapter 四百二十八"),
              let i431 = list.firstIndex(
                of: "chapter 四百三十一")
        else {
            return XCTFail(
                "both chapters must be in the list")
        }
        XCTAssertLessThan(i428, i431,
            "chronological order: chapter 428 (M1084-87)" +
            " must come before chapter 431 (M1096-99)")
    }

    // MARK: - 4 entropy classes

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine
                .entropyClassesAttacked.count, 4,
            "one entropy class per knife")
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter428EntropyDoctrine
                .plannedFutureCuts.isEmpty,
            "must enumerate the deferred ledger" +
            " deletions + projector consumer migrations")
    }

    // MARK: - Determinism

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.knives.count,
            BASChapter428EntropyDoctrine.knives.count)
        XCTAssertEqual(
            BASChapter428EntropyDoctrine.summary,
            BASChapter428EntropyDoctrine.summary)
    }
}

#endif  // chapter 七百五十二 第一刀
