// MARK: - BASChapter433EntropyDoctrineTests — chapter 四百三十三 / M1107

import XCTest
@testable import BASRuntimeCore

final class BASChapter433EntropyDoctrineTests: XCTestCase {

    func testChapterTagIs433() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.chapterTag,
            "chapter 四百三十三")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.mNumberFirst,
            1104)
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.mNumberLast,
            1109,
            "M1109 self-extension:bumped from M1107" +
            " to M1109 to cover deep-review remediation" +
            " rounds 1 (M1108) + 2 (M1109) inside the" +
            " chapter doctrine system")
    }

    func testV1MilestoneAtM1109() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine
                .v1MilestoneMNumber, 1109,
            "M1109 self-extension bumped milestone" +
            " M-number from M1107 to M1109")
        XCTAssertEqual(
            BASChapter433EntropyDoctrine
                .v1MilestoneStatus,
            "chapter-433-v1-radical-evolution-sweep-final-closeout")
    }

    func testKnivesLedger6Cuts() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.knives.count, 6,
            "M1109 self-extension:bumped from 4 cuts" +
            " (M1104-M1107) to 6 cuts (added M1108 +" +
            " M1109 deep-review remediation cuts)")
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.knives.map {
                $0.mNumber
            },
            [1104, 1105, 1106, 1107, 1108, 1109])
    }

    func testM432EndsAtM1103AndM433StartsAtM1104() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.mNumberLast,
            1103)
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.mNumberFirst,
            1104,
            "Final close-out chapter starts contiguous" +
            " to Phase F close-out")
    }

    func testEntropyClassesAttacked6() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine
                .entropyClassesAttacked.count, 6,
            "M1109 self-extension:bumped from 4 to 6" +
            " (added doctrine-self-contradiction-entropy" +
            " for M1108 + doctrine-stale-claim-entropy" +
            " for M1109)")
    }

    func testIsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testPinHeldIncludesFinalCloseOut() {
        XCTAssertTrue(
            BASChapter433EntropyDoctrine.pinHeld.contains {
                $0.contains("final close-out")
            })
    }

    func testADR016Advances() {
        XCTAssertTrue(
            BASChapter433EntropyDoctrine.pinHeld.contains {
                $0.contains("M1103 → M1107") ||
                    $0.contains("advanced")
            },
            "Final close-out must explicitly note that" +
            " ADR-016 advances (not held)")
    }

    // (testEntropyClassesAttacked4 retired by M1109
    // self-extension — count is now 6;see
    // testEntropyClassesAttacked6 above)

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter433EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter433EntropyDoctrine.summary,
            BASChapter433EntropyDoctrine.summary)
    }
}
