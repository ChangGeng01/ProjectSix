// MARK: - BASSprawlScopeAuditDoctrineTests
// chapter 六百九十五 / M2150 第一刀 — anti-drift PROOF
//                                  tests for sprawl
//                                  scope audit。

import XCTest
@testable import BASRuntimeCore

final class BASSprawlScopeAuditDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine.chapterTag,
            "chapter 六百九十五")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .milestoneMNumber, 2150)
    }

    // MARK: - Actual sprawl counts

    func testResultStructCountIs37() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .resultStructCount, 37)
    }

    func testFrameStructCountIs22() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .frameStructCount, 22)
    }

    func testPermitStructCountIs2() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .permitStructCount, 2)
    }

    func testCardStructCountIs3() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .cardStructCount, 3)
    }

    func testTotalSprawlStructCountIs64() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .totalSprawlStructCount, 64)
    }

    // MARK: - Chapter 691 estimates + delta

    func testChapter691EstimatedTotalIs42() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .chapter691EstimatedTotalCount, 42)
    }

    func testActualMinusEstimatedDeltaIsPlus22() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .actualMinusEstimatedDelta, 22)
    }

    // MARK: - Migratability classification

    func testMigratableToTierBCountIsZero() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .migratableToTierBCount, 0)
    }

    func testDomainComplexPreservedCountIs64() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .domainComplexPreservedCount, 64)
    }

    func testMigratablePlusPreservedEqualsTotal() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .migratableToTierBCount
                + BASSprawlScopeAuditDoctrine
                    .domainComplexPreservedCount,
            BASSprawlScopeAuditDoctrine
                .totalSprawlStructCount)
    }

    func testMigrationPercentageIsZero() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .migrationPercentage, 0.0)
    }

    // MARK: - Rationale

    func testCategorizationRationaleCountIs4() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .categorizationRationaleCount, 4)
    }

    func testCategorizationRationaleMentionsAllFour() {
        let keys = Set(
            BASSprawlScopeAuditDoctrine
                .categorizationRationale.keys)
        XCTAssertTrue(keys.contains("*Result"))
        XCTAssertTrue(keys.contains("*Frame"))
        XCTAssertTrue(keys.contains("*Permit"))
        XCTAssertTrue(keys.contains("*Card"))
    }

    // MARK: - Honest framing pins

    func testChapter691OverestimateAcknowledged() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .chapter691OverestimateAcknowledged)
    }

    func testTierBPrimitivesRemainValuableForNewTypes() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .tierBPrimitivesRemainValuableForNewTypes)
    }

    func testBASTierBDoctrineUnblockedClaimRetainedForHistory() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .bastierBDoctrineUnblockedClaimRetainedForHistory)
    }

    // MARK: - Cross-doctrine refs

    func testPriorTierBPrimitivesDoctrineRef() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .priorTierBPrimitivesDoctrineRef.contains(
                    "BASTierBGenericPrimitivesDoctrine"))
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .priorTierBPrimitivesDoctrineRef.contains(
                    "M2139"))
    }

    func testPriorPostSealFollowupCatalogRef() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .priorPostSealFollowupCatalogRef.contains(
                    "BASPostSealFollowupCatalogDoctrine"))
    }

    func testPriorTypedSurfaceCountAuditRef() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine
                .priorTypedSurfaceCountAuditRef.contains(
                    "BASTypedSurfaceCountAuditDoctrine"))
    }

    // MARK: - Methodology

    func testMethodologyIsEmpiricalSprawlAudit() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine.methodology.contains(
                "EMPIRICAL SPRAWL AUDIT"))
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASSprawlScopeAuditDoctrine.purelyAdditive)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASSprawlScopeAuditDoctrine
                .directiveScoreImpact, 0)
    }
}
