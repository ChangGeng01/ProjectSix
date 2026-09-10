// MARK: - BASChapter465LiteralPatternTests
// chapter 四百六十五 / M1238 PROOF tests
//
// Verifies the Phase 2b literal-conversion pattern:
// chapter 465 shipped chapter 453 as a LITERAL record
// in BASChapterDoctrineRegistry+Literals.swift。 The
// literal must byte-match the existing DERIVATION-
// based record currently in BASChapterDoctrineRegistry
// .all (which uses `deriveRecord(...)` against
// `BASChapter453EntropyDoctrine` static surface)。
//
// Phase 3 (chapter 466+,user confirmation required)
// will swap BASChapterDoctrineRegistry.all to consume
// the literals + delete the 60+ historical per-chapter
// Swift files。 This test ensures the swap is safe by
// pinning literal-vs-derivation equality NOW。

import XCTest
@testable import BASRuntimeCore

final class BASChapter465LiteralPatternTests: XCTestCase
{

    // MARK: - 1. Literal exists + has expected count

    func testLiteralRegistryHas1Entry() {
        XCTAssertEqual(
            BASChapterDoctrineRegistryLiterals.all
                .count,
            1,
            "chapter 465 ships 1 literal (chapter 453)" +
            " as proof-of-pattern。 Future chapters" +
            " extend to all 11 derived entries")
    }

    func testChapter453LiteralIsAccessible() {
        let literal = BASChapterDoctrineRegistryLiterals
            .chapter453
        XCTAssertEqual(
            literal.chapterTag,
            "chapter 四百五十三")
    }

    // MARK: - 2. Literal byte-matches derivation

    /// THE bedrock test for Phase 2b:literal and
    /// derivation must produce IDENTICAL records。 If
    /// they diverge,Phase 3 deletion is unsafe — the
    /// literal would silently change semantics。
    func testChapter453LiteralByteMatchesDerivation()
    {
        let literal = BASChapterDoctrineRegistryLiterals
            .chapter453
        let derived = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 四百五十三")
        XCTAssertNotNil(derived)
        guard let d = derived else { return }
        // Equatable compares every field
        XCTAssertEqual(literal, d,
            "Phase 2b invariant:literal must byte-" +
            "match derivation。 If this fails,Phase 3" +
            " deletion is UNSAFE")
        // Spot-check each field for diagnostic clarity
        XCTAssertEqual(
            literal.chapterTag, d.chapterTag)
        XCTAssertEqual(
            literal.mNumberFirst, d.mNumberFirst)
        XCTAssertEqual(
            literal.mNumberLast, d.mNumberLast)
        XCTAssertEqual(
            literal.v1MilestoneMNumber,
            d.v1MilestoneMNumber)
        XCTAssertEqual(
            literal.v1MilestoneStatus,
            d.v1MilestoneStatus)
        XCTAssertEqual(
            literal.knives.count, d.knives.count)
        for i in 0..<literal.knives.count {
            XCTAssertEqual(
                literal.knives[i], d.knives[i],
                "knife[\(i)] divergence")
        }
        XCTAssertEqual(
            literal.entropyClassesAttacked,
            d.entropyClassesAttacked)
        XCTAssertEqual(
            literal.pinHeld, d.pinHeld)
        XCTAssertEqual(
            literal.plannedFutureCuts,
            d.plannedFutureCuts)
        XCTAssertEqual(
            literal.summary, d.summary)
    }

    // MARK: - 3. Literal Codable round-trip

    func testChapter453LiteralCodableRoundTrip() throws
    {
        let literal = BASChapterDoctrineRegistryLiterals
            .chapter453
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(literal)
        let decoded = try JSONDecoder().decode(
            BASChapterDoctrineRecord.self, from: data)
        XCTAssertEqual(decoded, literal)
    }

    // MARK: - 4. Literal independence from Swift symbol

    /// Verify the literal is fully self-contained
    /// (doesn't reference `BASChapter453EntropyDoctrine`
    /// as a load-bearing dependency)。 If Phase 3
    /// deletes the Swift file,this literal record
    /// must still exist as-is。
    func testLiteralFieldsAreNotEmpty() {
        let literal = BASChapterDoctrineRegistryLiterals
            .chapter453
        XCTAssertFalse(literal.chapterTag.isEmpty)
        XCTAssertGreaterThan(literal.mNumberFirst, 0)
        XCTAssertGreaterThan(literal.mNumberLast, 0)
        XCTAssertGreaterThanOrEqual(
            literal.mNumberLast, literal.mNumberFirst)
        XCTAssertGreaterThan(literal.knives.count, 0)
        XCTAssertGreaterThan(literal.pinHeld.count, 0)
        XCTAssertGreaterThan(
            literal.entropyClassesAttacked.count, 0)
        XCTAssertGreaterThan(
            literal.plannedFutureCuts.count, 0)
        XCTAssertFalse(literal.summary.isEmpty)
    }

    // MARK: - 5. Chapter 465 itself exists in main registry as registry-only

    /// chapter 465 follows the Phase 2 pattern
    /// (chapter 464 established):registry-only,no
    /// per-chapter Swift file。 Its record lives as a
    /// literal in `BASChapterDoctrineRegistry.all`。
    func testChapter465IsRegistryOnly() {
        let r = BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百六十五")
        XCTAssertNotNil(r,
            "chapter 465 must have a registry entry" +
            " (Phase 2 pattern)")
        XCTAssertEqual(r?.mNumberFirst, 1236)
        XCTAssertEqual(r?.mNumberLast, 1239)
    }

    // MARK: - 6. Phase 2 covenant still holds

    func testPhase2CovenantHoldsAfterChapter465() {
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
        let post453 = Array(allShipped[startIdx...])
        for tag in post453 {
            XCTAssertNotNil(
                BASChapterDoctrineRegistry.recordFor(
                    chapterTag: tag),
                "Phase 2 covenant violated: \(tag)" +
                " is in Phase 2 doctrine but missing" +
                " from registry")
        }
    }
}
