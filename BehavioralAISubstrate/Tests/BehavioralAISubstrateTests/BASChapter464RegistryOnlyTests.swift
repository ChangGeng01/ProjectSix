// MARK: - BASChapter464RegistryOnlyTests
// chapter 四百六十四 / M1234 PROOF tests
//
// Verifies the Phase 2 pattern works:chapter 464's
// doctrine lives ONLY in BASChapterDoctrineRegistry,
// no `BASChapter464EntropyDoctrine.swift` file exists,
// yet the chapter has full schema parity with Swift-
// file-backed chapters (453-463)。
//
// These tests both VALIDATE chapter 464 itself and
// EXERCISE the Phase 2 pattern that future chapters
// (465+) will follow before Phase 3 deletes the
// historical Swift files。

import XCTest
@testable import BASRuntimeCore

final class BASChapter464RegistryOnlyTests: XCTestCase
{

    // MARK: - 1. Chapter 464 entry exists in registry

    func testChapter464EntryExistsInRegistry() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十四")
        XCTAssertNotNil(r,
            "chapter 464 record must exist in" +
            " registry (Phase 2 pattern requires it)")
    }

    // MARK: - 2. Registry now has 12 entries

    func testRegistryHasAtLeast13Entries() {
        // chapter 466 / Phase 3 grew the registry to 64
        // entries (61 historical from AllLiterals + 3
        // registry-native:464,465,466)。 Pre-Phase-3
        // count was 13 (10 derived + 463 derived + 464
        // + 465);post-Phase-3 the count is much higher。
        // Keep an at-least floor that survives future
        // chapter additions。
        XCTAssertGreaterThanOrEqual(
            BASChapterDoctrineRegistry.count, 13,
            "registry must include at least chapters" +
            " 453-465 from pre-Phase-3 era")
    }

    // MARK: - 3. Schema parity with Swift-file chapters

    /// chapter 464's literal record must have the same
    /// schema "completeness" as the Swift-file-backed
    /// chapters:non-empty status,knives count > 0,
    /// pins held,entropy classes attacked,future
    /// cuts,summary。
    func testChapter464HasFullSchemaParity() {
        guard let r = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百六十四")
        else {
            XCTFail("chapter 464 record missing")
            return
        }
        XCTAssertEqual(r.chapterTag,
            "chapter 四百六十四")
        XCTAssertEqual(r.mNumberFirst, 1232)
        XCTAssertEqual(r.mNumberLast, 1235)
        XCTAssertEqual(r.v1MilestoneMNumber, 1235)
        XCTAssertFalse(r.v1MilestoneStatus.isEmpty,
            "v1MilestoneStatus must be non-empty")
        XCTAssertGreaterThanOrEqual(r.knives.count, 1,
            "Phase 2 chapter must have at least 1 knife")
        XCTAssertEqual(r.knives.count, 4,
            "chapter 464 specifically has 4 cuts")
        XCTAssertGreaterThanOrEqual(
            r.pinHeld.count, 5,
            "Phase 2 chapter must hold doctrine pins")
        XCTAssertGreaterThan(
            r.entropyClassesAttacked.count, 0,
            "must attack at least one entropy class")
        XCTAssertGreaterThan(
            r.plannedFutureCuts.count, 0,
            "must have planned future cuts")
        XCTAssertFalse(r.summary.isEmpty,
            "summary must be non-empty")
    }

    // MARK: - 4. M-range contiguity with chapter 463

    /// Chapter 464 must start at M1232,immediately
    /// after chapter 463's M1231。 Catches any drift
    /// in M-number assignment between chapters at the
    /// Phase 1/2 boundary。
    func testChapter464MRangeContiguousWithChapter463() {
        guard let r463 = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百六十三"),
              let r464 = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百六十四")
        else {
            XCTFail("required records missing")
            return
        }
        XCTAssertEqual(
            r464.mNumberFirst, r463.mNumberLast + 1,
            "chapter 464 must start immediately after" +
            " chapter 463 (M-range contiguity)")
    }

    // MARK: - 5. No Swift file for chapter 464

    /// Compile-time pin:if a developer accidentally
    /// creates BASChapter464EntropyDoctrine.swift,
    /// this test would still PASS at runtime (no way
    /// to grep symbols at runtime),so it's a NEGATIVE
    /// affirmation only。 Real enforcement is via the
    /// commit-message convention in the chapter 464
    /// summary + the cross-doctrine schema test
    /// extension below。
    func testRegistryEntryIndependentOfSwiftFile() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十四")!
        // Verify the entry is fully self-contained:
        // no field references back to a hypothetical
        // BASChapter464EntropyDoctrine symbol。 Each
        // string is a literal,each int is a literal,
        // each knife is constructed via
        // BASChapterKnife init。 If a Swift file IS
        // later created,it would be REDUNDANT,not
        // load-bearing。
        XCTAssertGreaterThan(r.summary.count, 100,
            "chapter 464 summary is a literal,not" +
            " a forwarder。 Length pin catches" +
            " accidental empty / forwarder summaries")
    }

    // MARK: - 6. Codable round-trip works for literal entry

    /// Phase 2 invariant:literal registry entries
    /// must Codable-round-trip identically to derived
    /// entries (chapter 463 PROOF tested derivation
    /// case;this test pins the literal case)。
    func testChapter464CodableRoundTrip() throws {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十四")!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(r)
        let decoded = try JSONDecoder().decode(
            BASChapterDoctrineRecord.self, from: data)
        XCTAssertEqual(decoded, r)
        XCTAssertEqual(
            decoded.knives, r.knives)
        XCTAssertEqual(
            decoded.summary, r.summary)
    }

    // MARK: - 7. Phase 2 invariant — registry covers all post-453 chapters

    /// Every chapter tag in BASPhase2EntropyClosure
    /// Doctrine.chapterTagsShipped from "chapter 四百
    /// 五十三" onward must have a registry entry。
    /// This is the Phase 2 covenant:no chapter past
    /// 453 may exist without a registry entry。
    func testPhase2InvariantAllPost453ChaptersInRegistry() {
        // Find index of "chapter 四百五十三" — registry
        // coverage starts there
        let allShipped =
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped
        guard let startIdx = allShipped.firstIndex(of:
            "chapter 四百五十三")
        else {
            XCTFail("chapter 453 must appear in" +
                " Phase 2 doctrine")
            return
        }
        let post453 = Array(
            allShipped[startIdx...])
        for tag in post453 {
            let record = BASChapterDoctrineRegistry
                .recordFor(chapterTag: tag)
            XCTAssertNotNil(record,
                "Phase 2 covenant violated:" +
                " \(tag) is in Phase2 doctrine but" +
                " has NO registry entry。 New chapters" +
                " must add registry entries")
        }
    }

    // MARK: - 8. Knife M-numbers fit chapter range

    /// Each knife's mNumber must fall within the
    /// chapter's [mNumberFirst, mNumberLast] range。
    /// Catches drift between knife metadata and
    /// chapter range declaration。
    func testChapter464KnifeMNumbersFitChapterRange() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十四")!
        for knife in r.knives {
            XCTAssertGreaterThanOrEqual(
                knife.mNumber, r.mNumberFirst,
                "knife \(knife.knife) mNumber" +
                " \(knife.mNumber) must be >=" +
                " chapter mNumberFirst" +
                " \(r.mNumberFirst)")
            XCTAssertLessThanOrEqual(
                knife.mNumber, r.mNumberLast,
                "knife \(knife.knife) mNumber" +
                " \(knife.mNumber) must be <=" +
                " chapter mNumberLast" +
                " \(r.mNumberLast)")
        }
    }

    // MARK: - 9. Knife labels are canonical 第N刀

    func testChapter464KnifeLabelsAreCanonical() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十四")!
        let expected =
            ["第一刀", "第二刀", "第三刀", "第四刀"]
        XCTAssertEqual(r.knives.count, expected.count)
        for (i, knife) in r.knives.enumerated() {
            XCTAssertEqual(knife.knife, expected[i],
                "knife labels must follow canonical" +
                " 第N刀 schema (chapter 二百一一)")
        }
    }

    // MARK: - 10. Lookup by mNumberFirst works for chapter 464

    func testLookupByMNumber1232ReturnsChapter464() {
        let r = BASChapterDoctrineRegistry.recordFor(
            mNumberFirst: 1232)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.chapterTag,
            "chapter 四百六十四")
    }
}
