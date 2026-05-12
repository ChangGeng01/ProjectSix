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

    func testCatalogueHasSevenEntries() {
        // M1616 extended the catalogue with the M1614
        // floating-point determinism PROOF doctrine。
        // New count is 7。
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .catalogue.count,
            7)
    }

    func testTotalCataloguedIsSeven() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .totalCatalogued,
            7)
    }

    func testFirstChapterTagIs551() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .firstChapterTag,
            "chapter 五百五十一")
    }

    func testLastChapterTagIs559() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .lastChapterTag,
            "chapter 五百五十九")
    }

    // MARK: - M-number invariants

    func testEarliestMNumberIs1582() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .earliestMNumber,
            1582)
    }

    func testLatestMNumberIs1614() {
        // Updated at M1616 with new 7th catalogue
        // entry (M1614 — floating-point determinism
        // PROOF)。
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .latestMNumber,
            1614)
    }

    func testMNumberSpanIsThirtyThree() {
        // 1614 - 1582 + 1 = 33
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .mNumberSpan,
            33)
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

    /// 7 catalogued doctrines with their expected (
    /// chapter,M-number) values。 Single test ensures
    /// no drift on any entry。 Extended at M1616 to
    /// cover the 7th entry (M1614 floating-point
    /// determinism PROOF)。
    func testAllSevenCatalogueEntriesAreConsistent() {
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
             "chapter 五百五十七", 1606),
            ("BASAuditProjectionsJsonRejectionProofDoctrine",
             "chapter 五百五十八", 1610),
            ("BASAuditProjectionsFloatingPointDeterminismProofDoctrine",
             "chapter 五百五十九", 1614)
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
        XCTAssertEqual(decoded.count, 7)
        // Determinism:3 repeat encodes byte-identical。
        let d1 = try encoder.encode(catalogue)
        let d2 = try encoder.encode(catalogue)
        let d3 = try encoder.encode(catalogue)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }
}
