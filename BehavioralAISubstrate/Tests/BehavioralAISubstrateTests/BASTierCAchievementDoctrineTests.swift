// MARK: - BASTierCAchievementDoctrineTests
// chapter 五百八 / M1411 — Tier C achievement doctrine tests

import XCTest
@testable import BASRuntimeCore

final class BASTierCAchievementDoctrineTests: XCTestCase {

    // MARK: - 1) Chapter range pin

    func testChapterRangePin() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine.chapterRange,
            507...508)
    }

    func testMNumberRangePin() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine.mNumberRange,
            1405...1412)
    }

    // MARK: - 2) All 4 primitives recorded

    func testAllFourPrimitivesRecorded() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .primitives.count, 4)
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .primitivesShipped, 4)
    }

    // MARK: - 3) Primitive proposal names match ADR-019

    func testPrimitiveProposalNamesMatchADR019() {
        let proposalNames = Set(
            BASTierCAchievementDoctrine.primitives
                .map(\.proposalName))
        let expected: Set<String> = [
            "BASInspectionFrame<Body>",
            "BASRiskCard<Kind, Body>",
            "BASArbitrationFrame<Body>",
            "BASGovernanceCard<Authority, Decision>",
        ]
        XCTAssertEqual(proposalNames, expected,
            "all 4 ADR-019 proposal names MUST be" +
            " accounted for in achievement doctrine")
    }

    // MARK: - 4) Renames captured honestly

    func testTwoRenamesCapturedHonestly() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .renamedPrimitiveCount, 2,
            "Tier C had 2 name collisions:BASRiskCard" +
            " + BASArbitrationFrame")
        let renamed = BASTierCAchievementDoctrine
            .primitives.filter(\.wasRenamed)
        for p in renamed {
            XCTAssertNotNil(p.renameReason,
                "renamed primitives MUST have" +
                " renameReason for honest doctrine" +
                " audit")
        }
    }

    // MARK: - 5) M-number provenance per primitive

    func testMNumberProvenancePerPrimitive() {
        let byProposalName = Dictionary(
            uniqueKeysWithValues:
                BASTierCAchievementDoctrine.primitives
                    .map { ($0.proposalName, $0) })
        XCTAssertEqual(
            byProposalName["BASInspectionFrame<Body>"]?
                .mNumber, 1406)
        XCTAssertEqual(
            byProposalName[
                "BASRiskCard<Kind, Body>"]?.mNumber,
            1407)
        XCTAssertEqual(
            byProposalName[
                "BASArbitrationFrame<Body>"]?.mNumber,
            1409)
        XCTAssertEqual(
            byProposalName[
                "BASGovernanceCard<Authority, Decision>"]?
                .mNumber,
            1410)
    }

    // MARK: - 6) HONEST migration count pin

    func testMigrationCountIsZero() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .migrationsCompleted, 0,
            "chapter 508 close-out HONEST pin:0 of 4" +
            " existing types yet migrated — primitives" +
            " are pure-additive,migration is follow-" +
            "up arc")
    }

    func testMigrationTargetIsFour() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .migrationTarget, 4)
    }

    // MARK: - 7) Combined completion ratio

    func testCombinedCompletionRatio() {
        // chapter 509 update: 4 primitives + 2 adapters
        // + 0 migrations = 6 of 12 = 50%
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .combinedCompletionRatio,
            0.5, accuracy: 0.001,
            "3-layer accounting: 4/4 primitives + 2/4" +
            " adapters + 0/4 migrations = 6/12 = 50%")
    }

    // MARK: - 7a) Typed adapters shipped count

    func testTypedAdaptersShippedIsTwo() {
        XCTAssertEqual(
            BASTierCAchievementDoctrine
                .typedAdaptersShipped, 2,
            "chapter 509 ships 2 typed adapters:" +
            " BASRiskObservationCardAdapter +" +
            " BASInspectionBundleFrameAdapter")
    }

    // MARK: - 8) Honest summary contains key markers

    func testHonestSummaryMarkers() {
        let summary =
            BASTierCAchievementDoctrine.honestSummary
        XCTAssertTrue(summary.contains("Tier C"))
        XCTAssertTrue(summary
            .contains("primitives"))
        XCTAssertTrue(summary
            .contains("typed"))
        XCTAssertTrue(summary
            .contains("adapters"))
        XCTAssertTrue(summary
            .contains("migrations"))
        XCTAssertTrue(summary
            .contains("renamed honestly"))
        XCTAssertTrue(summary
            .contains("follow-up"))
    }

    // MARK: - 9) Primitive record Codable round-trip

    func testPrimitiveRecordCodableRoundTrip() throws {
        let original = BASTierCPrimitiveRecord(
            proposalName: "BASTest<Body>",
            actualShippedName: "BASTestRenamed<Body>",
            mNumber: 9999,
            chapterTag: "chapter test",
            renameReason: "test rename")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTierCPrimitiveRecord.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.wasRenamed)
    }

    // MARK: - 10) wasRenamed false when names match

    func testWasRenamedFalseWhenNamesMatch() {
        let p = BASTierCPrimitiveRecord(
            proposalName: "BASSame<X>",
            actualShippedName: "BASSame<X>",
            mNumber: 1,
            chapterTag: "c")
        XCTAssertFalse(p.wasRenamed)
        XCTAssertNil(p.renameReason)
    }
}
