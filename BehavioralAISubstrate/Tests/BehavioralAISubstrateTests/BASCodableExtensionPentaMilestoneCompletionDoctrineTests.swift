// MARK: - BASCodableExtensionPentaMilestoneCompletionDoctrineTests
// chapter 五百八十 / M1698 — anti-drift PROOF tests
//                        for the M1697 penta-milestone
//
// ## Coverage (24 anti-drift PROOF tests)
//
// Identity + 5 milestone identity pins (5 MilestoneRecord
// entries × per-entry validations) + aggregate accessors
// + post-arc count + achievement flags + cross-doctrine
// refs + round-number close-out。 Mirrors chapter 575
// quad-arc anti-drift pattern。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1697 → M1698

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionPentaMilestoneCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .chapterTag,
            "chapter 五百八十")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestoneMNumber,
            1697)
    }

    func testCloseOutMNumber() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .closeOutMNumber,
            1700)
    }

    func testRoundNumberCloseOutFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .isRoundNumberCloseOut)
    }

    // MARK: - Milestone count pins

    func testTotalMilestonesSealed() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalMilestonesSealed,
            5)
    }

    func testMilestonesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones.count,
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalMilestonesSealed)
    }

    func testMilestonesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestonesCountMatchesTotal)
    }

    func testArcMilestoneCount() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .arcMilestoneCount,
            4)
    }

    func testPostArcTrilogyMilestoneCount() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .postArcTrilogyMilestoneCount,
            1)
    }

    // MARK: - Per-milestone identity pins

    func testMilestone1IsCascade() {
        let m =
            BASCodableExtensionPentaMilestoneCompletionDoctrine
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
            BASCodableExtensionPentaMilestoneCompletionDoctrine
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
            BASCodableExtensionPentaMilestoneCompletionDoctrine
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
            BASCodableExtensionPentaMilestoneCompletionDoctrine
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
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[4]
        XCTAssertEqual(
            m.doctrineTypeName,
            "BASOrchestrationCodableExtensionPostArc" +
            "TrilogySealedDoctrine")
        XCTAssertEqual(m.sealedAtMNumber, 1693)
        XCTAssertEqual(m.typesExtended, 6)
        XCTAssertEqual(m.kind, "post-arc-trilogy")
    }

    // MARK: - Aggregate computed accessors

    func testTotalTypesExtendedAcrossMilestonesIs56() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalTypesExtendedAcrossMilestones,
            56)
    }

    func testTotalCommitsAcrossMilestonesIs60() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalCommitsAcrossMilestones,
            60)
    }

    func testTotalContributingChaptersIs15() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalContributingChapters,
            15)
    }

    func testTotalModulesCoveredIs4() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalModulesCovered,
            4)
    }

    // MARK: - Post-arc + session totals

    func testPostArcInputsCountIs2() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .postArcInputsCount,
            2)
    }

    func testTotalSessionLedgerSerializableIs58() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalSessionLedgerSerializable,
            58)
    }

    // MARK: - Achievement flag pins

    func testAllMilestonesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .allMilestonesRealSubstrateChange)
    }

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllMilestonesHaveAntiDriftCoverageFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .allMilestonesHaveAntiDriftCoverage)
    }

    // MARK: - Reference pins

    func testPriorQuadArcSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .priorQuadArcSnapshotRef,
            "BASCodableExtensionQuadArcCompletionDoctrine")
    }

    func testPriorTriArcSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .priorTriArcSnapshotRef,
            "BASCodableExtensionTriArcCompletionDoctrine")
    }

    // MARK: - MilestoneRecord Codable round-trip

    func testMilestoneRecordIsCodable() throws {
        let entry =
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[0]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .MilestoneRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
