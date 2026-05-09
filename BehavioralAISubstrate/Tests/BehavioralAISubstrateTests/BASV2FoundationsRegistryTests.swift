// MARK: - BASV2FoundationsRegistryTests — chapter 四百二十一 / M1054

import XCTest
@testable import BASRuntimeCore

final class BASV2FoundationsRegistryTests: XCTestCase {

    // MARK: - 12 cases present

    func testTwelveFoundationCases() {
        XCTAssertEqual(
            BASV2Foundation.allCases.count, 12)
        XCTAssertEqual(
            BASV2FoundationsRegistry.foundationCount, 12)
    }

    // MARK: - All chapter tags pinned

    func testChapterTagsCoverChapters409Through420() {
        let tags = Set(BASV2FoundationsRegistry
            .allChapterTags)
        XCTAssertTrue(tags.contains("chapter 四百九"))
        XCTAssertTrue(tags.contains("chapter 四百十"))
        XCTAssertTrue(tags.contains("chapter 四百十一"))
        XCTAssertTrue(tags.contains("chapter 四百十二"))
        XCTAssertTrue(tags.contains("chapter 四百十三"))
        XCTAssertTrue(tags.contains("chapter 四百十四"))
        XCTAssertTrue(tags.contains("chapter 四百十五"))
        XCTAssertTrue(tags.contains("chapter 四百十六"))
        XCTAssertTrue(tags.contains("chapter 四百十七"))
        XCTAssertTrue(tags.contains("chapter 四百十八"))
        XCTAssertTrue(tags.contains("chapter 四百十九"))
        XCTAssertTrue(tags.contains("chapter 四百二十"))
        XCTAssertEqual(tags.count, 12)
    }

    // MARK: - All closing M-numbers cover M1009-M1053

    func testClosingMNumbersAreFromExpectedRange() {
        let mNums = BASV2FoundationsRegistry
            .allClosingMNumbers
        // First foundation (stagePlan) → M1009
        XCTAssertEqual(mNums.first, 1009)
        // Last foundation (summaryDigest) → M1053
        XCTAssertEqual(mNums.last, 1053)
        // No duplicates
        XCTAssertEqual(
            Set(mNums).count, mNums.count)
    }

    // MARK: - Per-foundation accessor checks

    func testStagePlanFoundationMatches409M1009() {
        XCTAssertEqual(
            BASV2Foundation.stagePlan.chapterTag,
            "chapter 四百九")
        XCTAssertEqual(
            BASV2Foundation.stagePlan.mNumberClosingCut,
            1009)
    }

    func testSummaryDigestFoundationMatches420M1053() {
        XCTAssertEqual(
            BASV2Foundation.summaryDigest.chapterTag,
            "chapter 四百二十")
        XCTAssertEqual(
            BASV2Foundation.summaryDigest.mNumberClosingCut,
            1053)
    }

    // MARK: - Codable round-trip per case

    func testCodableRoundTripPreservesAllCases() throws {
        for f in BASV2Foundation.allCases {
            let data = try JSONEncoder().encode(f)
            let decoded = try JSONDecoder().decode(
                BASV2Foundation.self, from: data)
            XCTAssertEqual(decoded, f)
        }
    }

    // MARK: - Determinism

    func testRegistryIsDeterministic() {
        XCTAssertEqual(
            BASV2FoundationsRegistry.allChapterTags,
            BASV2FoundationsRegistry.allChapterTags)
        XCTAssertEqual(
            BASV2FoundationsRegistry.allClosingMNumbers,
            BASV2FoundationsRegistry.allClosingMNumbers)
    }

    // MARK: - Raw values are unique

    func testRawValuesAreUnique() {
        let raws = BASV2Foundation.allCases
            .map { $0.rawValue }
        XCTAssertEqual(raws.count, Set(raws).count)
    }
}
