// MARK: - BASChapter511To520PipelineDoctrineTests
// chapter 五百二十 / M1459 — typed milestone tests
//
// PROOF tests pinning the 10-chapter projection-block
// pipeline arc invariants。

import XCTest
@testable import BASRuntimeCore

final class BASChapter511To520PipelineDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Chapter 520 ship record pins

    func testChapter520ShipRecordPins() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        XCTAssertEqual(
            r.firstChapterTag, "chapter 五百十一")
        XCTAssertEqual(
            r.lastChapterTag, "chapter 五百二十")
        XCTAssertEqual(r.firstMNumber, 1421)
        XCTAssertEqual(r.lastMNumber, 1460)
        XCTAssertEqual(r.chapterCount, 10)
        XCTAssertEqual(r.commitCount, 40)
        XCTAssertEqual(r.typedInputBlockCount, 6)
        XCTAssertEqual(
            r.totalPackagedFieldCount, 60)
        XCTAssertEqual(
            r.netNewTypedSurfaceCount, 10)
        XCTAssertEqual(
            r.netNewBASBundleAdoptions, 1)
    }

    // MARK: - 2) V1 LOC reduction invariant

    func testV1LOCReductionInvariant() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        XCTAssertEqual(
            r.preFoldV1CallSiteLOC
                - r.postFoldV1CallSiteLOC,
            r.v1CallSiteLOCReductionNet,
            "v1CallSiteLOCReductionNet must equal" +
            " (preFold - postFold)")
        XCTAssertEqual(r.preFoldV1CallSiteLOC, 118)
        XCTAssertEqual(r.postFoldV1CallSiteLOC, 68)
        XCTAssertEqual(
            r.v1CallSiteLOCReductionNet, 50)
    }

    // MARK: - 3) Commits/chapter invariant

    func testCommitsPerChapterInvariant() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        XCTAssertEqual(
            r.commitCount,
            r.chapterCount * 4,
            "every chapter is 4 commits")
    }

    // MARK: - 4) M-number range invariant

    func testMNumberRangeInvariant() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        XCTAssertEqual(
            r.lastMNumber - r.firstMNumber + 1,
            r.commitCount,
            "M-number range must equal commit count")
    }

    // MARK: - 5) ADR-016 range invariant

    func testADR016RangeInvariant() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        XCTAssertEqual(r.adr016StartMNumber, 1416)
        XCTAssertEqual(r.adr016EndMNumber, 1460)
        XCTAssertGreaterThan(
            r.adr016EndMNumber, r.adr016StartMNumber)
    }

    // MARK: - 6) Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASChapter511To520PipelineDoctrine.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 7) Hashable conformance

    func testHashableConformance() {
        let r = BASChapter511To520PipelineDoctrine
            .chapter520ShipRecord
        var set:
            Set<BASChapter511To520PipelineDoctrine> = []
        set.insert(r)
        set.insert(r)
        XCTAssertEqual(set.count, 1)
    }
}
