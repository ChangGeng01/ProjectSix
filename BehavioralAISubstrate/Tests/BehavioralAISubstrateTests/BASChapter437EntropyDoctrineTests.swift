// MARK: - BASChapter437EntropyDoctrineTests — chapter 四百三十七 / M1127

import XCTest
@testable import BASRuntimeCore

final class BASChapter437EntropyDoctrineTests: XCTestCase {

    func testChapterTagIs437() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.chapterTag,
            "chapter 四百三十七")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.mNumberFirst,
            1124)
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.mNumberLast,
            1127)
    }

    func testV1MilestoneAtM1127() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine
                .v1MilestoneMNumber, 1127)
        XCTAssertEqual(
            BASChapter437EntropyDoctrine
                .v1MilestoneStatus,
            "chapter-437-v1-end-to-end-routed-dispatch")
    }

    func testKnivesLedger4Cuts() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.knives.count, 4)
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.knives.map {
                $0.mNumber
            },
            [1124, 1125, 1126, 1127])
    }

    func testM436EndsAtM1123AndM437StartsAtM1124() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.mNumberLast,
            1123)
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.mNumberFirst,
            1124,
            "chapter 437 contiguous to chapter 436")
    }

    // M1131 POST-RADICAL Wave 9 extension: chapter 438
    // is now terminal。 Chapter 437 remains a Phase 2
    // member but no longer last。
    func testIsMemberOfPhase2Doctrine() {
        XCTAssertTrue(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped
                .contains(
                    BASChapter437EntropyDoctrine.chapterTag),
            "chapter 四百三十七 must remain in Phase 2")
    }

    func testMNumberRangeFitsWithinPhase2() {
        XCTAssertGreaterThanOrEqual(
            BASChapter437EntropyDoctrine.mNumberFirst,
            BASPhase2EntropyClosureDoctrine.mNumberFirst)
        XCTAssertLessThanOrEqual(
            BASChapter437EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testPinHeldIncludesWave8Label() {
        XCTAssertTrue(
            BASChapter437EntropyDoctrine.pinHeld.contains {
                $0.contains("Wave 8")
            },
            "chapter 437 must explicitly tag itself as" +
            " POST-RADICAL EVOLUTION SWEEP Wave 8 entry")
    }

    func testADR016Advances() {
        XCTAssertTrue(
            BASChapter437EntropyDoctrine.pinHeld.contains {
                $0.contains("M1123 → M1127") ||
                    $0.contains("advanced")
            })
    }

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine
                .entropyClassesAttacked.count, 4)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter437EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.summary,
            BASChapter437EntropyDoctrine.summary)
    }
}
