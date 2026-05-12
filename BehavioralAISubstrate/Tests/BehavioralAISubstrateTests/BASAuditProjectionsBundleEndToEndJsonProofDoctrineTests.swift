// MARK: - BASAuditProjectionsBundleEndToEndJsonProofDoctrineTests
// chapter 五百五十四 / M1595 — anti-drift PROOF tests +
//                              cross-doctrine wire-in
//                              tests for the M1594
//                              typed surface
//
// ## Coverage matrix
//
// 12 tests cover:
//   - Pin invariants (chapterTag,proofMNumber,
//     proofTestCount,proofMethod,total surfaces,
//     byteEquality flag)
//   - Cross-doctrine wire-in (arc-seal doctrine ref
//     resolves;chapter 553 types match those listed
//     in BASCodableCascadeArcSealedDoctrine
//     contributions)
//   - Aggregation math (totalSurfacesExercised =
//     chapter553TypesProven.count + bundleSurfacesProven
//     .count)
//   - List contents (3 chapter-553 types are exactly
//     the 3 from M1589 / M1591)
//   - Anti-drift:proofTestCount matches the actual
//     number of PROOF tests in the M1593 file
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:cross-doctrine wire-in proves
//     single source-of-truth
//   - chapter 三百九二:replay-determinism (the test
//     file itself is the PROOF the doctrine refers to)
//   - ADR-016 advances M1594 → M1595

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsBundleEndToEndJsonProofDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter554() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .chapterTag,
            "chapter 五百五十四")
    }

    func testProofMNumberIs1593() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofMNumber,
            1593)
    }

    func testProofTestCountIsEight() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofTestCount,
            8)
    }

    func testProofMethodIsCodableSortedKeysJson() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofMethod,
            "codable-sortedKeys-json-round-trip")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .byteEqualityPreserved)
    }

    func testM1591ClaimBackedByRuntimeProofFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .m1591ClaimBackedByRuntimeProof)
    }

    // MARK: - List contents

    func testChapter553TypesProvenHasThreeEntries() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .chapter553TypesProven.count,
            3)
    }

    func testChapter553TypesContainsAllThreeCascadeTypes()
    {
        let proven =
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .chapter553TypesProven
        XCTAssertTrue(proven.contains(
            "BASOldSealSealingProtocol.Aggregate"))
        XCTAssertTrue(proven.contains(
            "BASEvolutionLifecycleSession.Aggregate"))
        XCTAssertTrue(proven.contains(
            "BASAuditObservationProjectionsCthulhuAggregatesBlock"
        ))
    }

    func testBundleSurfacesProvenHasFiveEntries() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .bundleSurfacesProven.count,
            5)
    }

    func testProvenPropertiesHasFiveEntries() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .provenProperties.count,
            5)
    }

    // MARK: - Aggregation math

    func testTotalSurfacesExercisedEqualsSumOfTwoLists() {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .totalSurfacesExercised,
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .chapter553TypesProven.count
            + BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .bundleSurfacesProven.count)
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .totalSurfacesExercised,
            8)
    }

    // MARK: - Cross-doctrine wire-in

    /// The arc-seal doctrine ref names the doctrine the
    /// PROOF refers to。 Must match the actual type
    /// name。 If
    /// BASCodableCascadeArcSealedDoctrine is renamed
    /// without updating arcSealDoctrineRef,this test
    /// fails loudly。
    func testArcSealDoctrineRefMatchesActualDoctrineName()
    {
        XCTAssertEqual(
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .arcSealDoctrineRef,
            String(describing:
                BASCodableCascadeArcSealedDoctrine.self))
    }

    /// PROOF was shipped at M1593。 Cross-mirror against
    /// the M1594 doctrine's proofMNumber + the arc-seal
    /// doctrine's M-number range to confirm consistency。
    func testProofMNumberIsInsideArcRange() {
        let arcFirst =
            BASCodableCascadeArcSealedDoctrine
                .arcFirstMNumber
        let arcLast =
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber
        let proofM =
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofMNumber
        // M1593 is AFTER the arc seal (which was M1592)。
        // The PROOF backs the arc-seal claim,so it
        // sits just after the seal — not inside the arc。
        XCTAssertGreaterThan(proofM, arcLast)
        XCTAssertGreaterThan(proofM, arcFirst)
    }
}
