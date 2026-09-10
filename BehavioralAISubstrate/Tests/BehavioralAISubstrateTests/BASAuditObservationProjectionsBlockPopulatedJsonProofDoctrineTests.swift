// MARK: - BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrineTests
// chapter 五百五十七 / M1607 — anti-drift + wire-in
//                              PROOF tests for the
//                              M1606 typed surface
//
// ## Coverage matrix (14 tests)
//
//   - Pin invariants (chapterTag,proofMNumber,
//     proofTestCount,totalBlockCount,populated count,
//     coverage ratio,100% flag,proofMethod,byteEquality
//     flag)
//   - List invariants (1-block baseline,4-block new,
//     5-block combined,4 proven properties)
//   - Cross-doctrine wire-in (arcSealDoctrineRef
//     resolves;M1605 PROOF M-number sits AFTER arc-
//     seal range;5-of-5 coverage agrees with
//     M1591 5-blocks-Codable claim)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - chapter 三百九二:replay-determinism
//   - ADR-016 advances M1606 → M1607

import XCTest
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter557() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .chapterTag,
            "chapter 五百五十七")
    }

    func testProofMNumberIs1605() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .proofMNumber,
            1605)
    }

    func testProofTestCountIsSeven() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .proofTestCount,
            7)
    }

    func testTotalBlockCountIsFive() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .totalBlockCount,
            5)
    }

    func testPopulatedBlocksProvenCountIsFive() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .populatedBlocksProvenCount,
            5)
    }

    func testFullBlockCoverageRatioIsOne() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .fullBlockCoverageRatio,
            1.0,
            accuracy: 1e-9)
    }

    func testHundredPercentBlockCoverageFlagSet() {
        XCTAssertTrue(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .hundredPercentBlockCoverage)
    }

    func testProofMethodIsCodableSortedKeysJson() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .proofMethod,
            "codable-sortedKeys-json-round-trip")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .byteEqualityPreserved)
    }

    // MARK: - List invariants

    func testBlocksProvenAtM1593HasOneEntry() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .blocksProvenAtM1593.count,
            1)
    }

    func testBlocksNewlyProvenAtM1605HasFourEntries() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .blocksNewlyProvenAtM1605.count,
            4)
    }

    func testAllBlocksProvenEqualsBaselinePlusNew() {
        let all = BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
            .allBlocksProven
        XCTAssertEqual(
            all.count,
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .blocksProvenAtM1593.count
            + BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .blocksNewlyProvenAtM1605.count)
        XCTAssertEqual(all.count, 5)
    }

    func testProvenPropertiesHasFourEntries() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .provenProperties.count,
            4)
    }

    // MARK: - Cross-doctrine wire-in

    /// The arcSealDoctrineRef must match the actual
    /// type name of the M1591 arc-seal doctrine。
    func testArcSealDoctrineRefMatchesActualName() {
        XCTAssertEqual(
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .arcSealDoctrineRef,
            String(describing:
                BASCodableCascadeArcSealedDoctrine.self))
    }

    /// M1605 PROOF must sit AFTER the arc-seal range
    /// [arcFirstMNumber, arcLastMNumber] — proves the
    /// PROOF was shipped to BACK the arc-seal claim,
    /// not as part of the arc itself。
    func testProofMNumberIsAfterArcSealRange() {
        let arcLast =
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber
        let proofM =
            BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine
                .proofMNumber
        XCTAssertGreaterThan(proofM, arcLast)
    }
}
