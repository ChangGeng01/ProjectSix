// MARK: - BASChapter434EntropyDoctrineTests — chapter 四百三十四 / M1115

import XCTest
@testable import BASRuntimeCore

final class BASChapter434EntropyDoctrineTests: XCTestCase {

    func testChapterTagIs434() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.chapterTag,
            "chapter 四百三十四")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.mNumberFirst,
            1110)
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.mNumberLast,
            1115)
    }

    func testV1MilestoneAtM1115() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine
                .v1MilestoneMNumber, 1115)
        XCTAssertEqual(
            BASChapter434EntropyDoctrine
                .v1MilestoneStatus,
            "chapter-434-v1-post-radical-safety-substrate")
    }

    func testKnivesLedger6Cuts() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.knives.count, 6)
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.knives.map {
                $0.mNumber
            },
            [1110, 1111, 1112, 1113, 1114, 1115])
    }

    func testM433EndsAtM1109AndM434StartsAtM1110() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.mNumberLast,
            1109)
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.mNumberFirst,
            1110,
            "chapter 434 starts contiguous to chapter 433")
    }

    func testIsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testPinHeldIncludesPostRadicalLabel() {
        XCTAssertTrue(
            BASChapter434EntropyDoctrine.pinHeld.contains {
                $0.contains("POST-RADICAL")
            },
            "chapter 434 must explicitly tag itself as" +
            " POST-RADICAL EVOLUTION SWEEP first chapter")
    }

    func testADR016Advances() {
        XCTAssertTrue(
            BASChapter434EntropyDoctrine.pinHeld.contains {
                $0.contains("M1109 → M1115") ||
                    $0.contains("advanced")
            })
    }

    func testEntropyClassesAttacked6() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine
                .entropyClassesAttacked.count, 6)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter434EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter434EntropyDoctrine.summary,
            BASChapter434EntropyDoctrine.summary)
    }
}
