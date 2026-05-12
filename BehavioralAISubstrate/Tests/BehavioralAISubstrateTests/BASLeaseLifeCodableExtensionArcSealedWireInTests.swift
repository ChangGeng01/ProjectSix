// MARK: - BASLeaseLifeCodableExtensionArcSealedWireInTests
// chapter 五百八十四 / M1715 — wire-in PROOF tests
//                          cross-checking the M1713
//                          arc-seal against the 3
//                          wave-specific extension
//                          doctrines + chapter 574
//                          parallel arc seal
//
// ## Coverage (16 wire-in PROOF tests)
//
// For each of waves 1/2/3 (chapters 581/582/583):
//   1. arc-seal's perWaveContribution.mNumber must
//      match the wave doctrine's extensionMNumber
//   2. arc-seal's perWaveContribution.typesAdded must
//      match the wave doctrine's totalTypesExtended
//   3. arc-seal's allTypesGainedCodable must include
//      the wave doctrine's typesGainedCodable entries
//   4. arc-seal's per-wave doctrine ref must match
//      the wave's expected doctrine name
//
// Plus:
//   - parallelArcRef points at chapter 574
//     Orchestration arc-seal
//   - priorNarrativeArcCloseOutRef points at chapter
//     580 penta-milestone
//   - waveNumber sequence == [1, 2, 3]
//   - combined struct count wires back to wave 3
//     doctrine
//
// Mirrors chapter 574 BASOrchestrationCodable
// ExtensionArcSealedWireInTests pattern。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1714 → M1715

import XCTest
@testable import BASRuntimeCore

final class BASLeaseLifeCodableExtensionArcSealedWireInTests:
    XCTestCase
{
    // MARK: - Wave 1 — chapter 581 wire-ins

    func testWave1ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[0].mNumber,
            BASLeaseLifeCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testWave1ContributionTypesAddedWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[0].typesAdded,
            BASLeaseLifeCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testWave1TypesInArcSealList() {
        for typeName
            in BASLeaseLifeCodableExtensionDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASLeaseLifeCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 581 wave 1 type:\(typeName)")
        }
    }

    func testWave1DoctrineRefMatches() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveDoctrineRefs[0],
            "BASLeaseLifeCodableExtensionDoctrine")
    }

    // MARK: - Wave 2 — chapter 582 wire-ins

    func testWave2ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[1].mNumber,
            BASLeaseLifeCodableExtensionWaveTwoDoctrine
                .extensionMNumber)
    }

    func testWave2ContributionTypesAddedWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[1].typesAdded,
            BASLeaseLifeCodableExtensionWaveTwoDoctrine
                .totalTypesExtended)
    }

    func testWave2TypesInArcSealList() {
        for typeName
            in BASLeaseLifeCodableExtensionWaveTwoDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASLeaseLifeCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 582 wave 2 type:\(typeName)")
        }
    }

    func testWave2DoctrineRefMatches() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveDoctrineRefs[1],
            "BASLeaseLifeCodableExtensionWaveTwoDoctrine")
    }

    // MARK: - Wave 3 — chapter 583 wire-ins

    func testWave3ContributionMNumberWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[2].mNumber,
            BASLeaseLifeCodableExtensionWaveThreeDoctrine
                .extensionMNumber)
    }

    func testWave3ContributionTypesAddedWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions[2].typesAdded,
            BASLeaseLifeCodableExtensionWaveThreeDoctrine
                .totalTypesExtended)
    }

    func testWave3TypesInArcSealList() {
        for typeName
            in BASLeaseLifeCodableExtensionWaveThreeDoctrine
                .typesGainedCodable
        {
            XCTAssertTrue(
                BASLeaseLifeCodableExtensionArcSealedDoctrine
                    .allTypesGainedCodable
                    .contains(typeName),
                "Arc-seal list must include chapter" +
                " 583 wave 3 type:\(typeName)")
        }
    }

    func testWave3DoctrineRefMatches() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveDoctrineRefs[2],
            "BASLeaseLifeCodableExtensionWaveThreeDoctrine")
    }

    // MARK: - Cross-arc refs

    func testParallelArcRefMatchesChapter574() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            "BASOrchestrationCodableExtensionArcSealedDoctrine")
    }

    func testPriorNarrativeArcCloseOutRefMatchesChapter580() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .priorNarrativeArcCloseOutRef,
            "BASCodableExtensionPentaMilestoneCompletionDoctrine")
    }

    // MARK: - Cumulative invariants

    func testWaveNumberSequence() {
        let nums =
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .perWaveContributions
                .map { $0.waveNumber }
        XCTAssertEqual(nums, [1, 2, 3])
    }

    func testCombinedStructCountWiresIn() {
        XCTAssertEqual(
            BASLeaseLifeCodableExtensionWaveThreeDoctrine
                .combinedLeaseLifeStructCount,
            BASLeaseLifeCodableExtensionArcSealedDoctrine
                .totalStructTypesExtended)
    }
}
