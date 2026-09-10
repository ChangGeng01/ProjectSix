// MARK: - BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrineTests
// chapter 五百五十五 / M1599 — anti-drift PROOF tests +
//                              cross-doctrine wire-in
//                              for the M1598 typed
//                              surface
//
// ## Coverage matrix
//
// 14 tests cover:
//   - Pin invariants (chapterTag,proofMNumber,
//     proofTestCount,totalNamespaceCount,populated
//     count,coverage ratio,100% flag,proofMethod,
//     byteEquality flag)
//   - List invariants (3-namespace baseline list,
//     2-namespace new list,combined 5-namespace list,
//     5 proven properties)
//   - Cross-doctrine wire-in (baselineDoctrineRef
//     resolves to BASAuditProjectionsBundleEndToEnd
//     JsonProofDoctrine;M1597 is AFTER M1593 baseline)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:cross-doctrine wire-in PROOF
//   - chapter 三百九二:replay-determinism
//   - ADR-016 advances M1598 → M1599

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter555() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .chapterTag,
            "chapter 五百五十五")
    }

    func testProofMNumberIs1597() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .proofMNumber,
            1597)
    }

    func testProofTestCountIsEight() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .proofTestCount,
            8)
    }

    func testTotalNamespaceCountIsFive() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .totalNamespaceCount,
            5)
    }

    func testPopulatedNamespacesProvenCountIsFive() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .populatedNamespacesProvenCount,
            5)
    }

    func testFullNamespaceCoverageRatioIsOne() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .fullNamespaceCoverageRatio,
            1.0,
            accuracy: 1e-9)
    }

    func testHundredPercentCoverageFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .hundredPercentNamespaceCoverage)
    }

    func testProofMethodIsCodableSortedKeysJson() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .proofMethod,
            "codable-sortedKeys-json-round-trip")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .byteEqualityPreserved)
    }

    // MARK: - List invariants

    func testNamespacesProvenAtM1593HasThreeEntries() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .namespacesProvenAtM1593.count,
            3)
    }

    func testNamespacesNewlyProvenAtM1597HasTwoEntries() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .namespacesNewlyProvenAtM1597.count,
            2)
    }

    func testAllNamespacesProvenEqualsBaselinePlusNew() {
        let all = BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
            .allNamespacesProven
        XCTAssertEqual(
            all.count,
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .namespacesProvenAtM1593.count
            + BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .namespacesNewlyProvenAtM1597.count)
        XCTAssertEqual(all.count, 5)
    }

    func testProvenPropertiesHasFiveEntries() {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .provenProperties.count,
            5)
    }

    // MARK: - Cross-doctrine wire-in

    /// The baseline doctrine ref must match the actual
    /// type name of the M1594 doctrine。
    func testBaselineDoctrineRefMatchesActualDoctrineName()
    {
        XCTAssertEqual(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .baselineDoctrineRef,
            String(describing:
                BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                    .self))
    }

    /// M1597 (chapter 555 PROOF) must come AFTER M1593
    /// (chapter 554 PROOF) — chapter 555 extends 554,
    /// not the other way around。
    func testM1597IsAfterM1593() {
        XCTAssertGreaterThan(
            BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine
                .proofMNumber,
            BASAuditProjectionsBundleEndToEndJsonProofDoctrine
                .proofMNumber)
    }
}
