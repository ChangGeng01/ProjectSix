// MARK: - BASChapter438EntropyDoctrineTests — chapter 四百三十八 / M1131

import XCTest
@testable import BASRuntimeCore

final class BASChapter438EntropyDoctrineTests: XCTestCase {

    func testChapterTagIs438() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.chapterTag,
            "chapter 四百三十八")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.mNumberFirst,
            1128)
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.mNumberLast,
            1131)
    }

    func testV1MilestoneAtM1131() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine
                .v1MilestoneMNumber, 1131)
        XCTAssertEqual(
            BASChapter438EntropyDoctrine
                .v1MilestoneStatus,
            "chapter-438-v1-host-side-injection")
    }

    func testKnivesLedger4Cuts() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.knives.count, 4)
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.knives.map {
                $0.mNumber
            },
            [1128, 1129, 1130, 1131])
    }

    func testM437EndsAtM1127AndM438StartsAtM1128() {
        XCTAssertEqual(
            BASChapter437EntropyDoctrine.mNumberLast,
            1127)
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.mNumberFirst,
            1128,
            "chapter 438 contiguous to chapter 437")
    }

    func testIsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testPinHeldIncludesWave9Label() {
        XCTAssertTrue(
            BASChapter438EntropyDoctrine.pinHeld.contains {
                $0.contains("Wave 9")
            },
            "chapter 438 must explicitly tag itself as" +
            " POST-RADICAL EVOLUTION SWEEP Wave 9 entry")
    }

    func testADR016Advances() {
        XCTAssertTrue(
            BASChapter438EntropyDoctrine.pinHeld.contains {
                $0.contains("M1127 → M1131") ||
                    $0.contains("advanced")
            })
    }

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine
                .entropyClassesAttacked.count, 4)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter438EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter438EntropyDoctrine.summary,
            BASChapter438EntropyDoctrine.summary)
    }
}
