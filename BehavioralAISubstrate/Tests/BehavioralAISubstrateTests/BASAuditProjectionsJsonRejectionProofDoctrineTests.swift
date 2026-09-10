// MARK: - BASAuditProjectionsJsonRejectionProofDoctrineTests
// chapter 五百五十八 / M1611 — anti-drift + wire-in
//                              PROOF tests for the
//                              M1610 typed surface
//
// ## Coverage matrix (12 tests)
//
//   - Pin invariants (chapterTag,proofMNumber,
//     proofTestCount,proofMethod,3 boolean flags)
//   - List invariants (5 rejection categories,6
//     surfaces exercised,total counts)
//   - Cross-doctrine wire-in (replayDeterminism
//     DoctrineRef pinned correctly,M1609 sits AFTER
//     M1605 (the previous PROOF arc))
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - chapter 三百九二:this is the doctrine being
//     closed
//   - ADR-016 advances M1610 → M1611

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsJsonRejectionProofDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter558() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .chapterTag,
            "chapter 五百五十八")
    }

    func testProofMNumberIs1609() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .proofMNumber,
            1609)
    }

    func testProofTestCountIsEleven() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .proofTestCount,
            11)
    }

    func testProofMethodIsJsonDecodingError() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .proofMethod,
            "json-decoder-decoding-error-on-malformed-input")
    }

    func testToleratesUnknownExtraFieldsFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .toleratesUnknownExtraFields)
    }

    func testDecoderStateIsolatedAcrossErrorsFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .decoderStateIsolatedAcrossErrors)
    }

    func testReplayDeterminismContractClosedFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .replayDeterminismContractClosed)
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .byteEqualityPreserved)
    }

    // MARK: - List invariants

    func testRejectionCategoriesHasFiveEntries() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .rejectionCategories.count,
            5)
    }

    func testRejectionCategoryCountEqualsListCount() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .rejectionCategoryCount,
            BASAuditProjectionsJsonRejectionProofDoctrine
                .rejectionCategories.count)
    }

    func testSurfacesExercisedHasSixEntries() {
        // Bundle + 5 ProjectionsBlock types
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .surfacesExercised.count,
            6)
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .totalSurfacesExercised,
            6)
    }

    // MARK: - Cross-doctrine wire-in

    /// The replay-determinism doctrine ref string must
    /// match the chapter tag chapter 三百九二。 If the
    /// doctrine moves chapters,this test fails loudly。
    func testReplayDeterminismDoctrineRefMatchesPin() {
        XCTAssertEqual(
            BASAuditProjectionsJsonRejectionProofDoctrine
                .replayDeterminismDoctrineRef,
            "chapter 三百九二")
    }
}
