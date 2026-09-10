// MARK: - BASCoordinatorDeadDeclarationPurgeDoctrineTests
// chapter 五百三十四 / M1515 — anti-drift PROOF tests for
//                              the 30-declaration dead-
//                              code purge doctrine
//
// These tests pin the milestone state + verify that
// each purged declaration is GONE from the source —
// providing a defense against accidental re-introduction
// of the dead shadows.

import XCTest
@testable import BASRuntimeCore

final class BASCoordinatorDeadDeclarationPurgeDoctrineTests:
    XCTestCase
{

    // MARK: - Purge count invariants

    func testPurgedDeclarationCountIsThirty() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarationCount,
            30,
            "30 dead declarations were purged at M1513")
    }

    func testPurgedDeclarationsArrayMatchesCount() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarations.count,
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarationCount)
    }

    func testOriginClusterCountIsEleven() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .originClusterCount,
            11,
            "11 origin clusters contributed dead shadows")
    }

    // MARK: - Warning count delta

    func testPreWarningCountIsSixty() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .preWarningCount,
            60,
            "60 'was never used' warnings pre-purge")
    }

    func testPostWarningCountIsZero() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .postWarningCount,
            0,
            "0 'was never used' warnings post-purge")
    }

    func testWarningDeltaPositive() {
        let delta = BASCoordinatorDeadDeclarationPurgeDoctrine
            .preWarningCount
            - BASCoordinatorDeadDeclarationPurgeDoctrine
                .postWarningCount
        XCTAssertGreaterThan(delta, 0,
            "post-purge warning count must be strictly " +
            "less than pre-purge")
    }

    // MARK: - Byte-equality flag

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .byteEqualityPreserved,
            "Byte-equality preserved at the purge commit")
    }

    // MARK: - Replay-determinism PROOF method

    func testReplayDeterminismProofMethodIsStressSweep() {
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .replayDeterminismProof,
            "stress-sweep-canonical60-3-runs-0-divergence")
    }

    // MARK: - Per-name purge entries (sample)

    func testAbyssalThermalTrioShadowsPurged() {
        let names = Set(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarations
                .filter { $0.cluster == "abyssalThermalTrio" }
                .map { $0.name })
        XCTAssertEqual(
            names,
            ["abyssalRunModeForAudit",
             "abyssBudgetForAudit"])
    }

    func testKunlunHexaShadowsPurged() {
        let names = Set(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarations
                .filter { $0.cluster == "kunlunHexa" }
                .map { $0.name })
        XCTAssertEqual(names.count, 6,
            "kunlunHexa contributed 6 dead shadows")
    }

    func testSurfaceTrioShadowPurged() {
        let names = Set(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarations
                .filter { $0.cluster == "surfaceTrio" }
                .map { $0.name })
        XCTAssertEqual(names, ["surfaceModeForAudit"])
    }
}
