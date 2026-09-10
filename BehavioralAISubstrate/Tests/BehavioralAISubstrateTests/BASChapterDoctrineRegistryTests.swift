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
    // chapter 七百五十二 第二刀 / M2431 — DEACTIVATED。
    // These mirror tests pre-dated the chapter 七百五十二
    // doctrine 大幅度 缩减 wave。 They compared the registry
    // against the per-chapter forwarder types
    // (BASChapter###EntropyDoctrine),which are now wrapped
    // in `#if false`。 The unified registry-iteration
    // mirror test `testIndexMirrorsEveryRegistryRecord` in
    // BASEntropyChapterIndexTests covers the same invariant
    // for EVERY chapter automatically — strictly broader
    // coverage than these 3 hand-spelled tests provided。
    // Historical bodies preserved verbatim per
    // 「依旧 不删除 只 comment」。

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 391 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapterDoctrineRegistryTests_IfFalseBody.txt

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
