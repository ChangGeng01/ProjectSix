// MARK: - BASJsonProofDoctrineCatalogueDoctrineTests
// chapter 五百五十六 / M1602 — anti-drift PROOF tests
//                              for the M1601 meta-
//                              catalogue
//
// ## Coverage matrix
//
// 14 tests cover:
//   - Catalogue size invariant (4 entries)
//   - First/last chapter tag pins
//   - Earliest/latest M-number pins (1582, 1598)
//   - mNumberSpan computation (17)
//   - 100% coverage flag
//   - byteEquality flag
//   - Pattern reference string
//   - Per-entry pins (4 entries × M-number + chapter
//     + typename)
//   - Lookup helpers (forTypeName + forChapterTag)
//   - Codable round-trip on the catalogue
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:test-side validation of the
//     single source-of-truth catalogue
//   - chapter 三百九二:replay-determinism (the
//     catalogue itself is Codable)
//   - ADR-016 advances M1601 → M1602

import XCTest
@testable import BASRuntimeCore

final class BASJsonProofDoctrineCatalogueDoctrineTests:
    XCTestCase
{

    // MARK: - Size + scope invariants

    func testCatalogueHasFiveEntries() {
        // M1608 extended the catalogue with the M1606
        // doctrine。 New count is 5。
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .catalogue.count,
            5)
    }

    func testTotalCataloguedIsFive() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .totalCatalogued,
            5)
    }

    func testFirstChapterTagIs551() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .firstChapterTag,
            "chapter 五百五十一")
    }

    func testLastChapterTagIs557() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .lastChapterTag,
            "chapter 五百五十七")
    }

    // MARK: - M-number invariants

    func testEarliestMNumberIs1582() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .earliestMNumber,
            1582)
    }

    func testLatestMNumberIs1606() {
        // Updated at M1608 with new 5th catalogue
        // entry (M1606)。
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .latestMNumber,
            1606)
    }

    func testMNumberSpanIsTwentyFive() {
        // 1606 - 1582 + 1 = 25
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .mNumberSpan,
            25)
    }

    // MARK: - Flag pins

    func testHundredPercentNamespaceCoverageFlagSet() {
        XCTAssertTrue(
            BASJsonProofDoctrineCatalogueDoctrine
                .hundredPercentNamespaceCoverage)
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASJsonProofDoctrineCatalogueDoctrine
                .byteEqualityPreserved)
    }

    func testPatternRefIsSessionMilestoneCatalogue() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .patternRef,
            "BASSessionMilestoneDoctrineCatalogueDoctrine")
    }

    // MARK: - Per-entry pins

    /// 5 catalogued doctrines with their expected (
    /// chapter,M-number) values。 Single test ensures
    /// no drift on any entry。 Extended at M1608 to
    /// cover the 5th entry (M1606)。
    func testAllFiveCatalogueEntriesAreConsistent() {
        let expected: [(typeName: String,
                        chapterTag: String,
                        mNumber: Int)] = [
            ("BASRuntimeAuditProjectionsBundleCodableDoctrine",
             "chapter 五百五十一", 1582),
            ("BASCodableCascadeArcSealedDoctrine",
             "chapter 五百五十三", 1591),
            ("BASAuditProjectionsBundleEndToEndJsonProofDoctrine",
             "chapter 五百五十四", 1594),
            ("BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine",
             "chapter 五百五十五", 1598),
            ("BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine",
             "chapter 五百五十七", 1606)
        ]
        let catalogue = BASJsonProofDoctrineCatalogueDoctrine
            .catalogue
        XCTAssertEqual(catalogue.count, expected.count)
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(
                catalogue[i].doctrineTypeName,
                exp.typeName,
                "Entry \(i) doctrineTypeName drift")
            XCTAssertEqual(
                catalogue[i].chapterTag,
                exp.chapterTag,
                "Entry \(i) chapterTag drift")
            XCTAssertEqual(
                catalogue[i].mNumber,
                exp.mNumber,
                "Entry \(i) mNumber drift")
        }
    }

    // MARK: - Lookup helpers

    func testEntryLookupByTypeNameResolvesAll() {
        for entry in
            BASJsonProofDoctrineCatalogueDoctrine.catalogue
        {
            let found = BASJsonProofDoctrineCatalogueDoctrine
                .entry(
                    forTypeName: entry.doctrineTypeName)
            XCTAssertNotNil(found)
            XCTAssertEqual(found, entry)
        }
    }

    func testEntryLookupByChapterTagResolvesAll() {
        for entry in
            BASJsonProofDoctrineCatalogueDoctrine.catalogue
        {
            let found = BASJsonProofDoctrineCatalogueDoctrine
                .entry(forChapterTag: entry.chapterTag)
            XCTAssertNotNil(found)
            XCTAssertEqual(found, entry)
        }
    }

    func testEntryLookupForUnknownNameReturnsNil() {
        XCTAssertNil(
            BASJsonProofDoctrineCatalogueDoctrine
                .entry(forTypeName: "no-such-doctrine"))
        XCTAssertNil(
            BASJsonProofDoctrineCatalogueDoctrine
                .entry(forChapterTag: "chapter 一万"))
    }

    // MARK: - Codable round-trip on the catalogue

    /// The catalogue itself is Codable;each
    /// CatalogueEntry round-trips byte-identical via
    /// JSON。 PROOF that the meta-catalogue can be
    /// serialized into audit replay logs。
    func testCatalogueEntryJsonRoundTripsByteIdentical()
        throws
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let catalogue = BASJsonProofDoctrineCatalogueDoctrine
            .catalogue
        let data = try encoder.encode(catalogue)
        let decoded = try JSONDecoder().decode(
            [BASJsonProofDoctrineCatalogueDoctrine
                .CatalogueEntry].self,
            from: data)
        XCTAssertEqual(decoded, catalogue)
        XCTAssertEqual(decoded.count, 5)
        // Determinism:3 repeat encodes byte-identical。
        let d1 = try encoder.encode(catalogue)
        let d2 = try encoder.encode(catalogue)
        let d3 = try encoder.encode(catalogue)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }
}
