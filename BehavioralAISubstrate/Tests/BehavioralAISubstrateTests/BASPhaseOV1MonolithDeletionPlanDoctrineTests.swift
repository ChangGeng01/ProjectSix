// MARK: - BASPhaseOV1MonolithDeletionPlanDoctrineTests
// chapter 六百八十六 / M2116 第三刀 — anti-drift PROOF tests
//                                  for Phase O deletion
//                                  plan doctrine

import XCTest
@testable import BASRuntimeCore

final class BASPhaseOV1MonolithDeletionPlanDoctrineTests:
    XCTestCase
{
    typealias D = BASPhaseOV1MonolithDeletionPlanDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十六")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2116)
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase O")
    }

    // MARK: - Plan chapters

    func testPhaseOChapterCountIs3() {
        XCTAssertEqual(D.phaseOChapterCount, 3)
        XCTAssertEqual(D.phaseOChapters.count, 3)
    }

    func testPhaseOTotalCommitCountIs12() {
        XCTAssertEqual(D.phaseOTotalCommitCount, 12)
        XCTAssertEqual(D.phaseOChapterCount * 4,
                       D.phaseOTotalCommitCount)
    }

    // MARK: - LOC delta targets

    func testPreM2114LineCountIs1803() {
        XCTAssertEqual(
            D.plusRunTurnPreM2114LineCount, 1803)
    }

    func testPostChapter687LineCountIs1600() {
        XCTAssertEqual(
            D.plusRunTurnPostChapter687LineCount, 1600)
    }

    func testPostChapter688LineCountIs800() {
        XCTAssertEqual(
            D.plusRunTurnPostChapter688LineCount, 800)
    }

    func testPostPhaseOFinalLineCountIs80() {
        XCTAssertEqual(
            D.plusRunTurnPostPhaseOFinalLineCount, 80)
    }

    func testLineCountDecreasesAcrossPhaseO() {
        XCTAssertGreaterThan(
            D.plusRunTurnPreM2114LineCount,
            D.plusRunTurnPostChapter687LineCount)
        XCTAssertGreaterThan(
            D.plusRunTurnPostChapter687LineCount,
            D.plusRunTurnPostChapter688LineCount)
        XCTAssertGreaterThan(
            D.plusRunTurnPostChapter688LineCount,
            D.plusRunTurnPostPhaseOFinalLineCount)
    }

    func testIsAspirationalLOCTarget() {
        XCTAssertTrue(D.isAspirationalLOCTarget,
            "Honest acknowledgment that 1803→80 LOC " +
            "projection requires full V2 absorption of " +
            "V1 audit-projection responsibilities")
    }

    // MARK: - Risk profile

    func testPhaseORiskProfileCountIs3() {
        XCTAssertEqual(D.phaseORiskProfileCount, 3)
    }

    func testRiskTiersAreOrderedRiskFreeMediumHigh() {
        let tiers = D.phaseORiskProfile.map { $0.tier }
        XCTAssertEqual(tiers[0], .riskFree)
        XCTAssertEqual(tiers[1], .medium)
        XCTAssertEqual(tiers[2], .mediumHigh)
    }

    func testEveryRiskHasNonEmptyMitigation() {
        for risk in D.phaseORiskProfile {
            XCTAssertFalse(risk.mitigation.isEmpty)
        }
    }

    func testRiskTierAllCasesCountIs5() {
        XCTAssertEqual(
            D.RiskTier.allCases.count, 5)
    }

    // MARK: - Pre-flight checks

    func testPreFlightCheckCountIs6() {
        XCTAssertEqual(D.preFlightCheckCount, 6)
    }

    func testAllPreFlightChecksClear() {
        XCTAssertTrue(D.allPreFlightChecksClear)
    }

    func testPreFlightChecksMentionCanaryWindow() {
        XCTAssertTrue(D.preFlightChecks.first?.contains(
            "canary") ?? false)
    }

    // MARK: - V1 OPT-OUT impact

    func testV1OptOutMechanismCountPreIs4() {
        XCTAssertEqual(D.v1OptOutMechanismCount, 4)
    }

    func testV1OptOutMechanismCountPostIs2() {
        XCTAssertEqual(
            D.v1OptOutMechanismCountPostPhaseO, 2)
    }

    func testMigrationNoteMentionsWarnFallback() {
        XCTAssertTrue(D.v1OptOutMechanismMigrationNote
            .contains("warn-and-fall-back"))
    }

    // MARK: - Score-delta

    func testPhaseOScoreDeltaTargetIs5() {
        XCTAssertEqual(D.phaseOScoreDeltaTarget, 5)
    }

    func testPhaseODirectiveImpactIsMostExtreme() {
        XCTAssertEqual(D.phaseODirectiveImpact.count, 1)
        XCTAssertTrue(
            D.phaseODirectiveImpact.contains("最极致"))
    }

    func testPrePhaseOScoreIs60() {
        XCTAssertEqual(D.prePhaseOScore, 60)
    }

    func testPostPhaseOScoreIs60() {
        XCTAssertEqual(D.postPhaseOScoreFinal, 60)
    }

    // MARK: - Achievement flags (chapter 686 opening)

    func testPhaseOOpeningShipped() {
        XCTAssertTrue(D.phaseOOpeningShipped)
    }

    func testPhaseOWireInNotYetShipped() {
        XCTAssertFalse(D.phaseOWireInShipped)
    }

    func testPhaseODeletionNotYetShipped() {
        XCTAssertFalse(D.phaseODeletionShipped)
    }

    func testPhaseONotYetFullySealed() {
        XCTAssertFalse(D.phaseOFullySealed)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPhaseNRef() {
        XCTAssertEqual(
            D.priorPhaseNCloseRef,
            "BASChapter683TierABridgeCloseDoctrine")
    }

    func testLateClusterBundleRef() {
        XCTAssertTrue(D.lateClusterBundleRef.contains(
            "LateClusterFinalBundle"))
    }

    // MARK: - Codable round-trip on ChapterRisk

    func testChapterRiskCodableRoundTrip() throws {
        let original = D.phaseORiskProfile[0]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            D.ChapterRisk.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testRiskTierCodableRoundTrip() throws {
        let tier: D.RiskTier = .mediumHigh
        let data = try JSONEncoder().encode(tier)
        let decoded = try JSONDecoder().decode(
            D.RiskTier.self, from: data)
        XCTAssertEqual(decoded, tier)
    }
}
