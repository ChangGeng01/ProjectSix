// MARK: - BASCodableExtensionHexaMilestoneCompletionDoctrineTests
// chapter 五百八十五 / M1718 — anti-drift PROOF tests
//                        for the M1717 hexa-milestone
//
// ## Coverage (28 anti-drift PROOF tests)
//
// Identity + milestone counts (incl。 3 kind-bucket
// counts) + 6 per-milestone identity pins + aggregate
// accessors + post-arc count + achievement flags +
// triple prior-snapshot refs + consecutive-commit pin
// + MilestoneRecord Codable round-trip。 Mirrors
// chapter 580 penta anti-drift pattern with
// extensions for the new "beyond-m1700-arc" kind +
// 300-commit milestone pin。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1717 → M1718

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionHexaMilestoneCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .chapterTag,
            "chapter 五百八十五")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestoneMNumber,
            1717)
    }

    // MARK: - Milestone count pins

    func testTotalMilestonesSealed() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalMilestonesSealed,
            6)
    }

    func testMilestonesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones.count,
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalMilestonesSealed)
    }

    func testMilestonesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestonesCountMatchesTotal)
    }

    func testArcMilestoneCount() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .arcMilestoneCount,
            4)
    }

    func testPostArcTrilogyMilestoneCount() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .postArcTrilogyMilestoneCount,
            1)
    }

    func testBeyondM1700ArcMilestoneCount() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .beyondM1700ArcMilestoneCount,
            1)
    }

    // MARK: - Per-milestone identity pins

    func testMilestone1IsCascade() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[0]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASCodableCascadeArcSealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1591)
        XCTAssertEqual(m.typesExtended, 16)
        XCTAssertEqual(m.kind, "arc")
    }

    func testMilestone2IsAggregator() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[1]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASAuditProjectionsAggregator" +
            "CodableExtensionArcSealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1633)
        XCTAssertEqual(m.typesExtended, 15)
        XCTAssertEqual(m.kind, "arc")
    }

    func testMilestone3IsCrossModule() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[2]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASCrossModuleCodableExtensionArc" +
            "SealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1653)
        XCTAssertEqual(m.typesExtended, 13)
        XCTAssertEqual(m.kind, "arc")
    }

    func testMilestone4IsOrchestrationArc() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[3]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASOrchestrationCodableExtensionArc" +
            "SealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1673)
        XCTAssertEqual(m.typesExtended, 6)
        XCTAssertEqual(m.kind, "arc")
    }

    func testMilestone5IsPostArcTrilogy() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[4]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASOrchestrationCodableExtensionPostArc" +
            "TrilogySealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1693)
        XCTAssertEqual(m.typesExtended, 6)
        XCTAssertEqual(m.kind, "post-arc-trilogy")
    }

    func testMilestone6IsBASLeaseLifeArc() {
        let m =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[5]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASLeaseLifeCodableExtensionArc" +
            "SealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1713)
        XCTAssertEqual(m.typesExtended, 7)
        XCTAssertEqual(m.kind, "beyond-m1700-arc")
    }

    // MARK: - Aggregate computed accessors

    func testTotalTypesExtendedAcrossMilestonesIs63() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalTypesExtendedAcrossMilestones,
            63)
    }

    func testTotalCommitsAcrossMilestonesIs72() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalCommitsAcrossMilestones,
            72)
    }

    func testTotalContributingChaptersIs18() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalContributingChapters,
            18)
    }

    func testTotalModulesCoveredIs5() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalModulesCovered,
            5)
    }

    // MARK: - Post-arc + session totals

    func testPostArcInputsCountIs2() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .postArcInputsCount,
            2)
    }

    func testTotalSessionLedgerSerializableIs65() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .totalSessionLedgerSerializable,
            65)
    }

    // MARK: - Achievement flag pins

    func testAllMilestonesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .allMilestonesRealSubstrateChange)
    }

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllMilestonesHaveAntiDriftCoverageFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .allMilestonesHaveAntiDriftCoverage)
    }

    // MARK: - Reference pins (3 prior snapshots)

    func testPriorPentaSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .priorPentaSnapshotRef,
            "BASCodableExtensionPentaMilestoneCompletionDoctrine")
    }

    func testPriorQuadArcSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .priorQuadArcSnapshotRef,
            "BASCodableExtensionQuadArcCompletionDoctrine")
    }

    func testPriorTriArcSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .priorTriArcSnapshotRef,
            "BASCodableExtensionTriArcCompletionDoctrine")
    }

    // MARK: - 300-commit milestone pin

    func testConsecutiveCleanCommitsAtPriorArcIs300() {
        XCTAssertEqual(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .consecutiveCleanCommitsAtPriorArc,
            300)
    }

    // MARK: - MilestoneRecord Codable round-trip

    func testMilestoneRecordIsCodable() throws {
        let entry =
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .milestones[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASCodableExtensionHexaMilestoneCompletionDoctrine
                .MilestoneRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
