// MARK: - BASChapter407EntropyDoctrineTests — chapter 四百七 / M999

import XCTest
@testable import BASRuntimeCore

final class BASChapter407EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.chapterTag,
            "chapter 四百七")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.mNumberFirst, 998)
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.mNumberLast, 999)
    }

    func testKnivesLedgerCovers2Cuts() {
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.knives.count, 2)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter407EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [998, 999])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter407EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter407EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    // MARK: - Cross-doctrine adjacency

    func testM406AndM407RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.mNumberLast + 1,
            BASChapter407EntropyDoctrine.mNumberFirst)
    }

    func testAllSevenChapterDoctrinesReachable() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            "chapter 四百二")
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.chapterTag,
            "chapter 四百三")
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.chapterTag,
            "chapter 四百四")
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.chapterTag,
            "chapter 四百五")
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.chapterTag,
            "chapter 四百六")
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.chapterTag,
            "chapter 四百七")
    }
}
