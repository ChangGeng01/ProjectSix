// MARK: - BASAuditProjectionsFloatingPointDeterminismProofDoctrineTests
// chapter 五百五十九 / M1615 — anti-drift + wire-in
//                              PROOF tests for the
//                              M1614 typed surface
//                              (100th typed surface)
//
// ## Coverage matrix (13 tests)
//
//   - Pin invariants (chapterTag,proofMNumber,
//     proofTestCount,proofMethod,equalityMethod,3
//     boolean flags)
//   - List invariants (7 double categories,3 double-
//     carrying surfaces,counts agreement)
//   - Cross-doctrine wire-in (replayDeterminism
//     DoctrineRef pinned to chapter 三百九二)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - chapter 三百九二:this is the doctrine being
//     extended
//   - ADR-016 advances M1614 → M1615

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsFloatingPointDeterminismProofDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter559() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .chapterTag,
            "chapter 五百五十九")
    }

    func testProofMNumberIs1613() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .proofMNumber,
            1613)
    }

    func testProofTestCountIsEight() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .proofTestCount,
            8)
    }

    func testProofMethodIsJsonEncoderSortedKeys() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .proofMethod,
            "json-encoder-sortedKeys-with-bit-pattern-equality-on-decode")
    }

    func testEqualityMethodIsBitPatternEquality() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .equalityMethod,
            "bit-pattern-equality")
    }

    func testOnePrecisionULPSensitivityProvenFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .onePrecisionULPSensitivityProven)
    }

    func testTrickyDoublesHandledCorrectlyFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .trickyDoublesHandledCorrectly)
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .byteEqualityPreserved)
    }

    // MARK: - List invariants

    func testDoubleCategoriesProvenHasSevenEntries() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .doubleCategoriesProven.count,
            7)
    }

    func testDoubleCategoryCountEqualsListCount() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .doubleCategoryCount,
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .doubleCategoriesProven.count)
    }

    func testDoubleCarryingSurfacesExercisedHasThreeEntries()
    {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .doubleCarryingSurfacesExercised.count,
            3)
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .totalDoubleSurfacesExercised,
            3)
    }

    // MARK: - Cross-doctrine wire-in

    /// The replay-determinism doctrine ref string must
    /// match the chapter tag chapter 三百九二。
    func testReplayDeterminismDoctrineRefMatchesPin() {
        XCTAssertEqual(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .replayDeterminismDoctrineRef,
            "chapter 三百九二")
    }

    /// M1613 proof comes AFTER M1609 (the rejection
    /// PROOF in chapter 558) — confirms this PROOF
    /// chain extends the prior PROOF chain。
    func testM1613IsAfterM1609RejectionProof() {
        XCTAssertGreaterThan(
            BASAuditProjectionsFloatingPointDeterminismProofDoctrine
                .proofMNumber,
            BASAuditProjectionsJsonRejectionProofDoctrine
                .proofMNumber)
    }
}
