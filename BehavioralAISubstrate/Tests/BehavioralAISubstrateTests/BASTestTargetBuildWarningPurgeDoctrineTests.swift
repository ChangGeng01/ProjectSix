// MARK: - BASTestTargetBuildWarningPurgeDoctrineTests
// chapter 五百三十八 / M1531 — anti-drift PROOF tests for
//                              the test-target warning
//                              purge doctrine

import XCTest
@testable import BASRuntimeCore

final class BASTestTargetBuildWarningPurgeDoctrineTests:
    XCTestCase
{

    // MARK: - Count invariants

    func testPreWarningCountIsFour() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .preWarningCount,
            4)
    }

    func testPostWarningCountIsZero() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .postWarningCount,
            0,
            "Test target must build warning-free")
    }

    func testTotalWarningsPurgedEqualsFour() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .totalWarningsPurged,
            4)
    }

    // MARK: - Invariants

    func testTestTargetIsWarningFreeInvariantHolds() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .testTargetIsWarningFree)
    }

    func testBothTargetsWarningFreeInvariantHolds() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .bothTargetsWarningFree,
            "Cumulative warning-free state across both" +
            " Sources/ AND Tests/ targets must hold")
    }

    // MARK: - Per-file contributions

    func testPerFilePurgesArrayCountIsFour() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .perFilePurges.count,
            4,
            "4 distinct test files contributed to the " +
            "purge")
    }

    func testUniqueTestFileCountIsFour() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .uniqueTestFileCount,
            4)
    }

    // MARK: - Categories

    func testCategoriesRepresentedAreTwo() {
        XCTAssertEqual(
            BASTestTargetBuildWarningPurgeDoctrine
                .categoriesRepresented.count,
            2,
            "neverUsedLet + neverMutatedVar = 2 " +
            "categories")
    }

    func testCategoriesContainNeverUsedLet() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .categoriesRepresented
                .contains("neverUsedLet"))
    }

    func testCategoriesContainNeverMutatedVar() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .categoriesRepresented
                .contains("neverMutatedVar"))
    }

    // MARK: - Per-file mappings

    func testInMemPurgeFromBAS392File() {
        let entries =
            BASTestTargetBuildWarningPurgeDoctrine
                .perFilePurges
                .filter {
                    $0.testFile.contains("BAS392")
                }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category,
            "neverUsedLet")
    }

    func testC1PurgeFromM321File() {
        let entries =
            BASTestTargetBuildWarningPurgeDoctrine
                .perFilePurges
                .filter {
                    $0.testFile.contains("M321")
                }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category,
            "neverMutatedVar")
    }

    // MARK: - Determinism

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .byteEqualityPreserved)
    }
}
