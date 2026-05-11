// MARK: - BASChapterDoctrineRegistryTests
// chapter 四百六十三 / M1230 PROOF tests
//
// Verifies the doctrine-collapse Phase 1 ships
// correctly:
//   - Registry has 10 entries for chapters 453-462
//   - Each entry's data byte-matches the corresponding
//     `BASChapter###EntropyDoctrine.swift` static
//     surface (proving derivation is faithful)
//   - Codable round-trip preserves records byte-equal
//   - Lookup APIs work by both chapterTag and
//     mNumberFirst
//
// Once these tests pass,callers in the BAS test
// target can MIGRATE from `BASChapter###EntropyDoctrine
// .knives` to `BASChapterDoctrineRegistry.recordFor
// (chapterTag: "...")!.knives` without behavior
// change。 chapter 465+ then deletes the per-chapter
// Swift files。

import XCTest
@testable import BASRuntimeCore

final class BASChapterDoctrineRegistryTests:
    XCTestCase
{

    // MARK: - Registry size + ordering

    func testRegistryContainsChapters453Through462() {
        // chapter 466 / Phase 3 update:registry now
        // holds 64 entries (chapters 403-466)。 The
        // original assertion (exactly 10 entries) no
        // longer holds。 Verify the original 10 chapters
        // (453-462) all have entries reachable by
        // lookup。
        let expectedTags = [
            "chapter 四百五十三",
            "chapter 四百五十四",
            "chapter 四百五十五",
            "chapter 四百五十六",
            "chapter 四百五十七",
            "chapter 四百五十八",
            "chapter 四百五十九",
            "chapter 四百六十",
            "chapter 四百六十一",
            "chapter 四百六十二"
        ]
        for tag in expectedTags {
            XCTAssertNotNil(
                BASChapterDoctrineRegistry.recordFor(
                    chapterTag: tag),
                "registry must include \(tag)")
        }
    }

    // MARK: - Byte-mirror each entry vs source

    func testChapter453EntryMirrorsSource() {
        let record = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百五十三")
        XCTAssertNotNil(record)
        guard let r = record else { return }
        XCTAssertEqual(
            r.chapterTag,
            BASChapter453EntropyDoctrine.chapterTag)
        XCTAssertEqual(
            r.mNumberFirst,
            BASChapter453EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            r.mNumberLast,
            BASChapter453EntropyDoctrine.mNumberLast)
        XCTAssertEqual(
            r.v1MilestoneStatus,
            BASChapter453EntropyDoctrine
                .v1MilestoneStatus)
        XCTAssertEqual(
            r.knives.count,
            BASChapter453EntropyDoctrine.knives.count)
        XCTAssertEqual(
            r.pinHeld,
            BASChapter453EntropyDoctrine.pinHeld)
        XCTAssertEqual(
            r.summary,
            BASChapter453EntropyDoctrine.summary)
    }

    func testChapter462EntryMirrorsSource() {
        let record = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百六十二")
        XCTAssertNotNil(record)
        guard let r = record else { return }
        XCTAssertEqual(
            r.mNumberFirst,
            BASChapter462EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            r.mNumberLast,
            BASChapter462EntropyDoctrine.mNumberLast)
        XCTAssertEqual(
            r.knives.count,
            BASChapter462EntropyDoctrine.knives.count)
        XCTAssertEqual(
            r.entropyClassesAttacked,
            BASChapter462EntropyDoctrine
                .entropyClassesAttacked)
        XCTAssertEqual(
            r.plannedFutureCuts,
            BASChapter462EntropyDoctrine
                .plannedFutureCuts)
    }

    // MARK: - Comprehensive cross-mirror (all 10)

    /// Verifies EVERY field of EVERY chapter entry
    /// byte-matches its source。 If registry derivation
    /// drifts from any per-chapter file,this test
    /// catches it。
    func testAllRegistryEntriesByteMirrorTheirSources() {
        struct SourcePair {
            let tag: String
            let mFirst: Int
            let mLast: Int
            let v1M: Int
            let v1Status: String
            let knivesCount: Int
            let pins: [String]
            let entropyClasses: [String]
            let futureCuts: [String]
            let summary: String
        }
        let sources: [SourcePair] = [
            SourcePair(
                tag: BASChapter453EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter453EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter453EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter453EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter453EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter453EntropyDoctrine
                        .knives.count,
                pins: BASChapter453EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter453EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter453EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter453EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter454EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter454EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter454EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter454EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter454EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter454EntropyDoctrine
                        .knives.count,
                pins: BASChapter454EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter454EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter454EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter454EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter455EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter455EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter455EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter455EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter455EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter455EntropyDoctrine
                        .knives.count,
                pins: BASChapter455EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter455EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter455EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter455EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter456EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter456EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter456EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter456EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter456EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter456EntropyDoctrine
                        .knives.count,
                pins: BASChapter456EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter456EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter456EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter456EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter457EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter457EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter457EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter457EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter457EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter457EntropyDoctrine
                        .knives.count,
                pins: BASChapter457EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter457EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter457EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter457EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter458EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter458EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter458EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter458EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter458EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter458EntropyDoctrine
                        .knives.count,
                pins: BASChapter458EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter458EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter458EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter458EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter459EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter459EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter459EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter459EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter459EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter459EntropyDoctrine
                        .knives.count,
                pins: BASChapter459EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter459EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter459EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter459EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter460EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter460EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter460EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter460EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter460EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter460EntropyDoctrine
                        .knives.count,
                pins: BASChapter460EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter460EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter460EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter460EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter461EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter461EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter461EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter461EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter461EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter461EntropyDoctrine
                        .knives.count,
                pins: BASChapter461EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter461EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter461EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter461EntropyDoctrine
                    .summary),
            SourcePair(
                tag: BASChapter462EntropyDoctrine
                    .chapterTag,
                mFirst: BASChapter462EntropyDoctrine
                    .mNumberFirst,
                mLast: BASChapter462EntropyDoctrine
                    .mNumberLast,
                v1M: BASChapter462EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status:
                    BASChapter462EntropyDoctrine
                        .v1MilestoneStatus,
                knivesCount:
                    BASChapter462EntropyDoctrine
                        .knives.count,
                pins: BASChapter462EntropyDoctrine
                    .pinHeld,
                entropyClasses:
                    BASChapter462EntropyDoctrine
                        .entropyClassesAttacked,
                futureCuts:
                    BASChapter462EntropyDoctrine
                        .plannedFutureCuts,
                summary: BASChapter462EntropyDoctrine
                    .summary)
        ]
        // chapter 466 / Phase 3 update:registry now
        // holds 64 entries (61 historical + 3 native);
        // the 10 sources here are a SUBSET。 Look up by
        // tag instead of indexed position。
        XCTAssertGreaterThanOrEqual(
            BASChapterDoctrineRegistry.count,
            sources.count,
            "registry must include all 10 sources")
        for src in sources {
            guard let r = BASChapterDoctrineRegistry
                .recordFor(chapterTag: src.tag)
            else {
                XCTFail("registry missing \(src.tag)")
                continue
            }
            XCTAssertEqual(r.chapterTag, src.tag,
                "tag drift at \(src.tag)")
            XCTAssertEqual(r.mNumberFirst, src.mFirst,
                "mFirst drift at \(src.tag)")
            XCTAssertEqual(r.mNumberLast, src.mLast,
                "mLast drift at \(src.tag)")
            XCTAssertEqual(
                r.v1MilestoneMNumber, src.v1M,
                "v1M drift at \(src.tag)")
            XCTAssertEqual(
                r.v1MilestoneStatus, src.v1Status,
                "v1Status drift at \(src.tag)")
            XCTAssertEqual(
                r.knives.count, src.knivesCount,
                "knives count drift at \(src.tag)")
            XCTAssertEqual(r.pinHeld, src.pins,
                "pins drift at \(src.tag)")
            XCTAssertEqual(
                r.entropyClassesAttacked,
                src.entropyClasses,
                "entropy classes drift at \(src.tag)")
            XCTAssertEqual(
                r.plannedFutureCuts, src.futureCuts,
                "futureCuts drift at \(src.tag)")
            XCTAssertEqual(r.summary, src.summary,
                "summary drift at \(src.tag)")
        }
    }

    // MARK: - Knife structure deep-mirror

    func testKnivesPreserveMNumberKnifeConceptOrdering() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十二")!
        let sourceKnives =
            BASChapter462EntropyDoctrine.knives
        XCTAssertEqual(
            r.knives.count, sourceKnives.count)
        for i in 0..<r.knives.count {
            XCTAssertEqual(
                r.knives[i].mNumber,
                sourceKnives[i].mNumber)
            XCTAssertEqual(
                r.knives[i].knife,
                sourceKnives[i].knife)
            XCTAssertEqual(
                r.knives[i].concept,
                sourceKnives[i].concept)
        }
    }

    // MARK: - Lookup API

    func testLookupByChapterTagReturnsCorrectRecord() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.mNumberFirst, 1216)
        XCTAssertEqual(r?.mNumberLast, 1219)
    }

    func testLookupByUnknownTagReturnsNil() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 九九九九")
        XCTAssertNil(r,
            "unknown chapter tag must return nil")
    }

    func testLookupByMNumberFirstReturnsCorrectRecord() {
        let r = BASChapterDoctrineRegistry.recordFor(
            mNumberFirst: 1224)
        XCTAssertNotNil(r)
        XCTAssertEqual(
            r?.chapterTag, "chapter 四百六十二")
    }

    func testLookupByUnknownMNumberReturnsNil() {
        let r = BASChapterDoctrineRegistry.recordFor(
            mNumberFirst: 999_999)
        XCTAssertNil(r)
    }

    // MARK: - Codable round-trip

    func testRecordCodableRoundTrip() throws {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十二")!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(r)
        let decoded = try JSONDecoder()
            .decode(
                BASChapterDoctrineRecord.self,
                from: data)
        XCTAssertEqual(decoded, r)
    }

    func testWholeRegistryCodableRoundTrip() throws {
        let all = BASChapterDoctrineRegistry.all
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder()
            .decode(
                [BASChapterDoctrineRecord].self,
                from: data)
        XCTAssertEqual(decoded.count, all.count)
        XCTAssertEqual(decoded, all)
    }

    // MARK: - Knife type Codable + clamping

    func testKnifeCodableRoundTrip() throws {
        let k = BASChapterKnife(
            mNumber: 1234,
            knife: "第一刀",
            concept: "test concept")
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder()
            .decode(
                BASChapterKnife.self,
                from: data)
        XCTAssertEqual(decoded, k)
    }

    func testKnifeClampsNegativeMNumber() {
        let k = BASChapterKnife(
            mNumber: -5,
            knife: "第一刀",
            concept: "test")
        XCTAssertEqual(k.mNumber, 0)
    }

    // MARK: - Record clamping

    func testRecordClampsMNumberLastAboveMNumberFirst() {
        // Verify the init's safety clamp:if mLast <
        // mFirst,mLast gets bumped up to mFirst
        let r = BASChapterDoctrineRecord(
            chapterTag: "chapter test",
            mNumberFirst: 100,
            mNumberLast: 50,  // < first
            v1MilestoneMNumber: 100,
            v1MilestoneStatus: "test",
            knives: [],
            entropyClassesAttacked: [],
            pinHeld: [],
            plannedFutureCuts: [],
            summary: "test")
        XCTAssertEqual(r.mNumberFirst, 100)
        XCTAssertEqual(r.mNumberLast, 100,
            "mLast must be clamped to >= mFirst")
    }
}
