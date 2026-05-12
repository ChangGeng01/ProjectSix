// MARK: - BASChapter511To522PipelineDoctrineTests
// chapter 五百二十三 / M1469 — 12-chapter arc tests

import XCTest
@testable import BASRuntimeCore

final class BASChapter511To522PipelineDoctrineTests:
    XCTestCase
{

    func testChapter523ShipRecordPins() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertEqual(
            r.firstChapterTag, "chapter 五百十一")
        XCTAssertEqual(
            r.lastChapterTag, "chapter 五百二十二")
        XCTAssertEqual(r.firstMNumber, 1421)
        XCTAssertEqual(r.lastMNumber, 1468)
        XCTAssertEqual(r.chapterCount, 12)
        XCTAssertEqual(r.commitCount, 48)
        XCTAssertEqual(r.typedInputBlockCount, 8)
        XCTAssertEqual(
            r.totalPackagedFieldCount, 69)
        XCTAssertTrue(
            r.hundredPercentPackagingCoverage)
    }

    func testV1LOCReductionInvariant() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertEqual(
            r.preFoldV1CallSiteLOC
                - r.postFoldV1CallSiteLOC,
            r.v1CallSiteLOCReductionNet)
        XCTAssertEqual(r.preFoldV1CallSiteLOC, 118)
        XCTAssertEqual(r.postFoldV1CallSiteLOC, 60)
        XCTAssertEqual(
            r.v1CallSiteLOCReductionNet, 58)
        XCTAssertEqual(
            r.v1CallSiteLOCReductionPercent, 49,
            "49% reduction (~58 / 118)")
    }

    func testCommitsPerChapterInvariant() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertEqual(
            r.commitCount,
            r.chapterCount * 4)
    }

    func testMNumberRangeInvariant() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertEqual(
            r.lastMNumber - r.firstMNumber + 1,
            r.commitCount)
    }

    func testADR016RangeInvariant() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertEqual(r.adr016StartMNumber, 1416)
        XCTAssertEqual(r.adr016EndMNumber, 1472)
        XCTAssertGreaterThan(
            r.adr016EndMNumber, r.adr016StartMNumber)
    }

    func testCodableRoundTrip() throws {
        let original = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASChapter511To522PipelineDoctrine.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHashableConformance() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        var set:
            Set<BASChapter511To522PipelineDoctrine> = []
        set.insert(r)
        set.insert(r)
        XCTAssertEqual(set.count, 1)
    }

    func testHundredPercentMilestonePin() {
        let r = BASChapter511To522PipelineDoctrine
            .chapter523ShipRecord
        XCTAssertTrue(
            r.hundredPercentPackagingCoverage,
            "chapter 522 achieved 100% V1 call-site" +
            " packaging coverage (every field through" +
            " a typed input surface)")
    }
}
