// MARK: - BASChapter436EntropyDoctrineTests — chapter 四百三十六 / M1123

import XCTest
@testable import BASRuntimeCore

final class BASChapter436EntropyDoctrineTests: XCTestCase {

    func testChapterTagIs436() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.chapterTag,
            "chapter 四百三十六")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.mNumberFirst,
            1120)
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.mNumberLast,
            1123)
    }

    func testV1MilestoneAtM1123() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine
                .v1MilestoneMNumber, 1123)
        XCTAssertEqual(
            BASChapter436EntropyDoctrine
                .v1MilestoneStatus,
            "chapter-436-v1-first-ledger-driven-dispatch")
    }

    func testKnivesLedger4Cuts() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.knives.count, 4)
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.knives.map {
                $0.mNumber
            },
            [1120, 1121, 1122, 1123])
    }

    func testM435EndsAtM1119AndM436StartsAtM1120() {
        XCTAssertEqual(
            BASChapter435EntropyDoctrine.mNumberLast,
            1119)
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.mNumberFirst,
            1120,
            "chapter 436 contiguous to chapter 435")
    }

    func testIsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testPinHeldIncludesWave7Label() {
        XCTAssertTrue(
            BASChapter436EntropyDoctrine.pinHeld.contains {
                $0.contains("Wave 7")
            },
            "chapter 436 must explicitly tag itself as" +
            " POST-RADICAL EVOLUTION SWEEP Wave 7 entry")
    }

    func testADR016Advances() {
        XCTAssertTrue(
            BASChapter436EntropyDoctrine.pinHeld.contains {
                $0.contains("M1119 → M1123") ||
                    $0.contains("advanced")
            })
    }

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine
                .entropyClassesAttacked.count, 4)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter436EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter436EntropyDoctrine.summary,
            BASChapter436EntropyDoctrine.summary)
    }
}
