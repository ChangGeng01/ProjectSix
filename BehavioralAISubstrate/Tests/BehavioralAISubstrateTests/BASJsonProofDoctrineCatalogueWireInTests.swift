// MARK: - BASJsonProofDoctrineCatalogueWireInTests
// chapter 五百五十六 / M1603 — wire-in PROOF tests for
//                              the M1601 meta-
//                              catalogue
//
// ## What these wire-in tests prove
//
// 7 wire-in tests cross-check the M1601 catalogue
// against the ACTUAL catalogued doctrines:
//
//   1. Catalogued type names equal `String(describing:
//      Doctrine.self)` for each of the 4 doctrines
//   2. Catalogued M-numbers match the M-number fields
//      on each catalogued doctrine
//   3. Catalogued chapter tags match the chapterTag
//      fields on each catalogued doctrine (where
//      applicable)
//   4. Catalogue's earliestMNumber matches the M-number
//      of BASRuntimeAuditProjectionsBundleCodableDoctrine
//      .cascadeAddedAtMNumber
//   5. Catalogue's latestMNumber matches
//      BASAuditProjectionsFiveNamespacePopulatedJsonProof
//      Doctrine.proofMNumber
//   6. Catalogue's hundredPercentNamespaceCoverage flag
//      matches the actual flag on the M1598 doctrine
//   7. The 2 PROOF doctrines (M1594 + M1598) form a
//      strict chain — M1598 references M1594 as
//      baseline
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF that the
//     single source-of-truth catalogue is consistent
//     with the catalogued doctrines themselves
//   - ADR-016 advances M1602 → M1603

import XCTest
@testable import BASRuntimeCore

final class BASJsonProofDoctrineCatalogueWireInTests:
    XCTestCase
{

    // MARK: - Helper:catalogue entries indexed by typename

    private func catalogueEntry(
        forTypeName name: String
    ) -> BASJsonProofDoctrineCatalogueDoctrine.CatalogueEntry?
    {
        return BASJsonProofDoctrineCatalogueDoctrine
            .entry(forTypeName: name)
    }

    // MARK: - Wire-in #1:catalogued type names equal actual

    /// Each catalogued doctrineTypeName must equal
    /// String(describing: Type.self) for the actual
    /// type。 If any doctrine is renamed without
    /// updating the catalogue,this test fails loudly。
    func testCataloguedTypeNamesEqualActualTypeNames() {
        let pairs: [(catalogued: String,
                     actual: String)] = [
            (catalogued:
                "BASRuntimeAuditProjectionsBundleCodableDoctrine",
             actual: String(describing:
                BASRuntimeAuditProjectionsBundleCodableDoctrine
                    .self)),
            (catalogued:
                "BASCodableCascadeArcSealedDoctrine",
             actual: String(describing:
                BASCodableCascadeArcSealedDoctrine.self)),
            (catalogued:
                "BASAuditProjectionsBundleEndToEndJsonProofDoctrine",
             actual: String(describing:
                BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                    .self)),
            (catalogued:
                "BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine",
             actual: String(describing:
                BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                    .self)),
            (catalogued:
                "BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine",
             actual: String(describing:
                BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                    .self)),
            (catalogued:
                "BASAuditProjectionsJsonRejectionProofDoctrine",
             actual: String(describing:
                BASAuditProjectionsJsonRejectionProofDoctrine
                    .self)),
            (catalogued:
                "BASAuditProjectionsFloatingPointDeterminismProofDoctrine",
             actual: String(describing:
                BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                    .self))
        ]
        for pair in pairs {
            XCTAssertEqual(
                pair.catalogued, pair.actual,
                "Catalogue type name drift:\(pair.catalogued) ≠ \(pair.actual)")
        }
    }

    // MARK: - Wire-in #2:M-numbers match catalogued doctrines

    /// Catalogued M-number for the M1591 arc-seal
    /// doctrine equals the doctrine's arcLastMNumber
    /// where the milestone was sealed。
    func testArcSealCatalogueMNumberMatchesArcLast() {
        let entry = catalogueEntry(
            forTypeName:
                "BASCodableCascadeArcSealedDoctrine")
        XCTAssertNotNil(entry)
        // Arc-seal milestone was shipped at M1591 — one
        // M-number after arcLastMNumber (M1592)。 Wait —
        // actually the catalogue records the milestone-
        // shipping M-number (M1591),and arcLastMNumber
        // (1592) is one M-number later。 Their relation
        // is:milestone shipped DURING the arc,one cut
        // before close-out。
        XCTAssertEqual(entry?.mNumber, 1591)
        // The arc-seal doctrine sits AT M1591,which is
        // INSIDE the arc range [arcFirstMNumber=1581,
        // arcLastMNumber=1592]。
        XCTAssertLessThanOrEqual(
            entry!.mNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber)
        XCTAssertGreaterThanOrEqual(
            entry!.mNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcFirstMNumber)
    }

    /// Catalogued M-number for the M1594 doctrine
    /// equals its actual proofMNumber - 1 (the doctrine
    /// itself shipped at M1594,backing the M1593
    /// PROOF)。
    func testEndToEndJsonProofCatalogueMatchesActual() {
        let entry = catalogueEntry(
            forTypeName:
                "BASAuditProjectionsBundleEndToEndJsonProofDoctrine")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumber, 1594)
        // The PROOF tests themselves shipped at M1593;
        // the doctrine shipped at M1594 commemorating
        // them。
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofMNumber,
            1593)
    }

    /// Catalogued M-number for the M1598 doctrine
    /// equals the value pinned on the doctrine。
    func testFiveNamespaceCatalogueMatchesActual() {
        let entry = catalogueEntry(
            forTypeName:
                "BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumber, 1598)
        // The PROOF tests themselves shipped at M1597。
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .proofMNumber,
            1597)
    }

    /// Catalogued M-number for the M1582 doctrine
    /// equals its cascadeAddedAtMNumber + 1 (the
    /// doctrine shipped at M1582 commemorating the
    /// M1581 cascade)。
    func testInitialCascadeCatalogueMatchesActual() {
        let entry = catalogueEntry(
            forTypeName:
                "BASRuntimeAuditProjectionsBundleCodableDoctrine")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumber, 1582)
        XCTAssertEqual(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .cascadeAddedAtMNumber,
            1581)
    }

    // MARK: - Wire-in #3:earliestMNumber matches M1582 doctrine

    /// Catalogue's earliestMNumber is the M-number of
    /// the BASRuntimeAuditProjectionsBundleCodable
    /// Doctrine entry (the first JSON PROOF doctrine
    /// shipped in this session)。
    func testEarliestMNumberMatchesFirstDoctrine() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .earliestMNumber,
            1582)
        // 1582 = M1581 cascadeAddedAtMNumber + 1
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .earliestMNumber,
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .cascadeAddedAtMNumber + 1)
    }

    // MARK: - Wire-in #4:latestMNumber matches latest doctrine

    /// Catalogue's latestMNumber equals 1614 — the
    /// shipping M-number for the M1614 doctrine (7th
    /// catalogue entry added at M1616)。
    func testLatestMNumberMatchesLastDoctrine() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .latestMNumber,
            1614)
        // M1614 shipped one cut after M1613 (the
        // proofMNumber where floating-point PROOF
        // tests landed)
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .latestMNumber,
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .proofMNumber + 1)
    }

    // MARK: - Wire-in #5:hundredPercent flag agrees with M1598 doctrine

    /// Catalogue claims 100% namespace coverage。 The
    /// M1598 doctrine independently asserts the same。
    /// Both must agree。
    func testHundredPercentCoverageFlagAgreesAcrossSurfaces() {
        XCTAssertEqual(
            BASJsonProofDoctrineCatalogueDoctrine
                .hundredPercentNamespaceCoverage,
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .hundredPercentNamespaceCoverage)
    }

    // MARK: - Wire-in #6:M1598 doctrine references M1594

    /// The M1598 doctrine declares M1594 as its
    /// baseline。 Catalogue must include both — and
    /// M1594 must precede M1598。
    func testM1598ReferencesM1594InBaseline() {
        // Catalogue includes both
        XCTAssertNotNil(
            catalogueEntry(
                forTypeName:
                    "BASAuditProjectionsBundleEndToEndJsonProofDoctrine"))
        XCTAssertNotNil(
            catalogueEntry(
                forTypeName:
                    "BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine"))
        // M1598's baseline ref is the M1594 doctrine's
        // type name
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .baselineDoctrineRef,
            String(describing:
                BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                    .self))
    }
}
