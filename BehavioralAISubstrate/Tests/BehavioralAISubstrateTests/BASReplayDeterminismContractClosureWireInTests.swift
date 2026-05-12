// MARK: - BASReplayDeterminismContractClosureWireInTests
// chapter 五百六十 / M1619 — wire-in PROOF tests for
//                          the M1617 milestone
//                          doctrine
//
// ## What these wire-in tests prove
//
// 11 wire-in tests cross-check that the M1617 milestone
// doctrine agrees with the 5 ACTUAL contract-proving
// doctrines:
//
//   1. roundTripDoctrineRefs strings match actual
//      doctrine type names (3 doctrines)
//   2. rejectionDoctrineRef matches actual M1610
//      doctrine type name
//   3. floatingPointDoctrineRef matches actual M1614
//      doctrine type name
//   4. metaCatalogueRef matches actual catalogue
//      doctrine type name
//   5. arcFirstMNumber ≤ each contract-proving
//      doctrine's M-number
//   6. arcLastMNumber ≥ each contract-proving
//      doctrine's M-number
//   7. totalProofDoctrineCount agrees with sum
//   8. arc range includes M1591 (Codable cascade arc
//      seal) — confirms the cascade foundation is
//      part of this arc
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF that the
//     milestone is consistent with the catalogued
//     doctrines
//   - ADR-016 advances M1618 → M1619

import XCTest
@testable import BASRuntimeCore

final class BASReplayDeterminismContractClosureWireInTests:
    XCTestCase
{

    // MARK: - Type-name agreement

    /// All 3 roundTripDoctrineRefs match actual type
    /// names。 If any doctrine is renamed without
    /// updating the milestone,this test fails loudly。
    func testRoundTripDoctrineRefsMatchActualTypeNames()
    {
        let actualNames = [
            String(describing:
                BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                    .self),
            String(describing:
                BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                    .self),
            String(describing:
                BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                    .self)
        ]
        let refs = BASReplayDeterminismContractClosureDoctrine
            .roundTripDoctrineRefs
        XCTAssertEqual(refs.count, actualNames.count)
        for actual in actualNames {
            XCTAssertTrue(refs.contains(actual),
                "Round-trip refs must include \(actual)")
        }
    }

    func testRejectionDoctrineRefMatchesActualName() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .rejectionDoctrineRef,
            String(describing:
                BASAuditProjectionsJsonRejectionProofDoctrine
                    .self))
    }

    func testFloatingPointDoctrineRefMatchesActualName() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .floatingPointDoctrineRef,
            String(describing:
                BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                    .self))
    }

    func testMetaCatalogueRefMatchesActualName() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .metaCatalogueRef,
            String(describing:
                BASJsonProofDoctrineCatalogueDoctrine.self))
    }

    // MARK: - Arc M-number bounds

    /// All 5 contract-proving doctrines' M-numbers
    /// fall within [arcFirstMNumber, arcLastMNumber]。
    func testEachContractDoctrineMNumberInsideArcRange()
    {
        let arcFirst = BASReplayDeterminismContractClosureDoctrine
            .arcFirstMNumber
        let arcLast = BASReplayDeterminismContractClosureDoctrine
            .arcLastMNumber
        let proofMNumbers: [Int] = [
            // Note:doctrineMNumber for cascade-foundation
            // doctrines is on the M1591 doctrine。 We
            // cross-check the contract-proving doctrines
            // specifically:
            1594, // EndToEndJsonProofDoctrine
            1598, // FiveNamespacePopulatedJsonProofDoctrine
            1606, // BlockPopulatedJsonProofDoctrine
            1610, // JsonRejectionProofDoctrine
            1614  // FloatingPointDeterminismProofDoctrine
        ]
        for m in proofMNumbers {
            XCTAssertGreaterThanOrEqual(m, arcFirst,
                "M\(m) must be ≥ arcFirstMNumber")
            XCTAssertLessThanOrEqual(m, arcLast,
                "M\(m) must be ≤ arcLastMNumber")
        }
    }

    // MARK: - Catalogue cross-check

    /// The 5 contract-proving doctrines are all in the
    /// JSON PROOF doctrine catalogue (M1601)。 The
    /// catalogue has 7 entries total — 5 contract-
    /// proving + 2 cascade-foundation (M1582 + M1591)。
    func testCatalogueContainsAllContractProvingDoctrines()
    {
        let catalogue = BASJsonProofDoctrineCatalogueDoctrine
            .catalogue
        let catalogueNames = Set(
            catalogue.map { $0.doctrineTypeName })
        // 3 round-trip
        for ref in BASReplayDeterminismContractClosureDoctrine
            .roundTripDoctrineRefs
        {
            XCTAssertTrue(
                catalogueNames.contains(ref),
                "Catalogue must contain \(ref)")
        }
        // 1 rejection + 1 floating-point
        XCTAssertTrue(catalogueNames.contains(
            BASReplayDeterminismContractClosureDoctrine
                .rejectionDoctrineRef))
        XCTAssertTrue(catalogueNames.contains(
            BASReplayDeterminismContractClosureDoctrine
                .floatingPointDoctrineRef))
    }

    /// totalProofDoctrineCount (5) is LESS than the
    /// catalogue size (7) — confirms 2 doctrines in
    /// the catalogue are FOUNDATION (cascade) rather
    /// than contract-proving。
    func testProofDoctrineCountLessThanCatalogueSize() {
        let proofCount = BASReplayDeterminismContractClosureDoctrine
            .totalProofDoctrineCount
        let catalogueCount = BASJsonProofDoctrineCatalogueDoctrine
            .totalCatalogued
        XCTAssertLessThan(proofCount, catalogueCount)
        XCTAssertEqual(catalogueCount - proofCount, 2,
            "2 catalogued doctrines are foundation, not contract-proving")
    }

    // MARK: - Codable cascade foundation

    /// arcFirstMNumber (1581) equals the cascade arc's
    /// arcFirstMNumber from BASCodableCascadeArcSealed
    /// Doctrine — confirms the closure arc opens at
    /// the cascade origin。
    func testArcFirstMNumberMatchesCascadeArcOrigin() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .arcFirstMNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcFirstMNumber)
    }

    /// The cascade arc's arcLastMNumber (M1592) is
    /// strictly LESS than this closure milestone's
    /// arcLastMNumber (M1617) — confirms the closure
    /// arc extends BEYOND the cascade arc。
    func testClosureArcExtendsPastCascadeArc() {
        XCTAssertGreaterThan(
            BASReplayDeterminismContractClosureDoctrine
                .arcLastMNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber)
    }

    // MARK: - Contract closed flag agreement

    /// The replayDeterminismContractClosed flag on
    /// the M1610 rejection-PROOF doctrine matches the
    /// contractClosed flag on this milestone (both
    /// true)。
    func testContractClosedFlagsAgreeAcrossSurfaces() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .contractClosed,
            BASAuditProjectionsJsonRejectionProofDoctrine
                .replayDeterminismContractClosed)
    }

    // MARK: - Chapter 560 lands AT arcLastMNumber

    /// This milestone doctrine ships at M1617 which
    /// equals arcLastMNumber — the milestone IS the
    /// arc seal。
    func testMilestoneMNumberEqualsArcLastMNumber() {
        XCTAssertEqual(
            BASReplayDeterminismContractClosureDoctrine
                .milestoneMNumber,
            BASReplayDeterminismContractClosureDoctrine
                .arcLastMNumber)
    }
}
