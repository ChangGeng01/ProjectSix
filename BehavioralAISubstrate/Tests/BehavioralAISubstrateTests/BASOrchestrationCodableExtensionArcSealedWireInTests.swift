// MARK: - BASOrchestrationCodableExtensionArcSealedWireInTests
// chapter 五百七十四 / M1675 — wire-in PROOF tests
//                          cross-checking the M1673
//                          arc-seal against the 3
//                          chapter-specific extension
//                          doctrines
//
// ## Coverage (12 wire-in PROOF tests)
//
// For each of chapters 571/572/573:
//   1. arc-seal's perChapterContribution.mNumber must
//      match the chapter doctrine's extensionMNumber
//   2. arc-seal's perChapterContribution.typesAdded
//      must match the chapter doctrine's
//      totalTypesExtended
//   3. arc-seal's allTypesGainedCodable must include
//      the chapter doctrine's typesGainedCodable
//   4. arc-seal's chapter doctrine ref must match
//      the chapter's expected doctrine name
//
// Plus:
//   - arc-seal's parallelArcRef must point at the
//     chapter 569 cross-module arc-seal
//   - arc-seal's originatorArcRef must point at the
//     chapter 564 aggregator arc-seal
//   - arc-seal's totalTypesExtended must equal the sum
//     of the 3 chapter doctrines' typesGainedCodable
//     counts
//
// Mirrors chapter 569 BASCrossModuleCodableExtension
// ArcSealedWireInTests pattern。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1674 → M1675

import XCTest
@testable import BASRuntimeCore

final class BASOrchestrationCodableExtensionArcSealedWireInTests:
    XCTestCase
{
    // MARK: - chapter 571 wire-in

    func testChapter571ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[0].mNumber,
            BASOrchestrationCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testChapter571ContributionCountWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[0].typesAdded,
            BASOrchestrationCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testChapter571TypesInArcSealList() {
        for typeName
            in BASOrchestrationCodableExtensionDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASOrchestrationCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 571 type:\(typeName)")
        }
    }

    func testChapter571DoctrineRefMatches() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterExtensionDoctrineRefs[0],
            "BASOrchestrationCodableExtensionDoctrine")
    }

    // MARK: - chapter 572 wire-in

    func testChapter572ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[1].mNumber,
            BASOrchestrationCodableExtensionSecondWaveDoctrine
                .extensionMNumber)
    }

    func testChapter572ContributionCountWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[1].typesAdded,
            BASOrchestrationCodableExtensionSecondWaveDoctrine
                .totalTypesExtended)
    }

    func testChapter572TypesInArcSealList() {
        for typeName
            in BASOrchestrationCodableExtensionSecondWaveDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASOrchestrationCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 572 type:\(typeName)")
        }
    }

    func testChapter572DoctrineRefMatches() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterExtensionDoctrineRefs[1],
            "BASOrchestrationCodableExtensionSecondWaveDoctrine")
    }

    // MARK: - chapter 573 wire-in

    func testChapter573ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[2].mNumber,
            BASOrchestrationCodableExtensionThirdWaveDoctrine
                .extensionMNumber)
    }

    func testChapter573ContributionCountWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterContributions[2].typesAdded,
            BASOrchestrationCodableExtensionThirdWaveDoctrine
                .totalTypesExtended)
    }

    func testChapter573TypesInArcSealList() {
        for typeName
            in BASOrchestrationCodableExtensionThirdWaveDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASOrchestrationCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 573 type:\(typeName)")
        }
    }

    func testChapter573DoctrineRefMatches() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .perChapterExtensionDoctrineRefs[2],
            "BASOrchestrationCodableExtensionThirdWaveDoctrine")
    }

    // MARK: - cross-arc refs

    func testParallelArcRefMatchesChapter569() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            "BASCrossModuleCodableExtensionArcSealedDoctrine")
    }

    func testOriginatorArcRefMatchesChapter564() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .originatorArcRef,
            "BASAuditProjectionsAggregatorCodable" +
            "ExtensionArcSealedDoctrine")
    }

    // MARK: - 3-chapter sum invariant

    func testTotalEqualsSumOfThreeChapterDoctrines() {
        let sum =
            BASOrchestrationCodableExtensionDoctrine
                .totalTypesExtended
            + BASOrchestrationCodableExtensionSecondWaveDoctrine
                .totalTypesExtended
            + BASOrchestrationCodableExtensionThirdWaveDoctrine
                .totalTypesExtended
        XCTAssertEqual(
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .totalTypesExtended,
            sum)
    }

    func testCombinedOrchestrationCountWiresIn() {
        XCTAssertEqual(
            BASOrchestrationCodableExtensionThirdWaveDoctrine
                .combinedOrchestrationCount,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }
}
