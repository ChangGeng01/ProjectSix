// MARK: - BASTypedSurfaceCountAuditDoctrineTests
// chapter 六百九十四 / M2148 第三刀 — anti-drift PROOF
//                                  tests for the typed
//                                  surface count audit
//                                  doctrine。

import XCTest
@testable import BASRuntimeCore

final class BASTypedSurfaceCountAuditDoctrineTests: XCTestCase {

    // MARK: - Chapter / milestone pins

    func testChapterTag() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine.chapterTag,
            "chapter 六百九十四")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .milestoneMNumber, 2148)
    }

    // MARK: - Counting convention pins

    func testCountedTypeKindCountIs5() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .countedTypeKindCount, 5)
    }

    func testCountedTypeKindsIncludeStructEnumProtocol() {
        let kinds = Set(
            BASTypedSurfaceCountAuditDoctrine
                .countedTypeKinds)
        XCTAssertTrue(kinds.contains("public struct"))
        XCTAssertTrue(kinds.contains("public enum"))
        XCTAssertTrue(kinds.contains("public class"))
        XCTAssertTrue(kinds.contains("public actor"))
        XCTAssertTrue(kinds.contains("public protocol"))
    }

    func testExcludedCategoryCountIs4() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .excludedCategoryCount, 4)
    }

    func testExcludedCategoriesMentionTypealiasAndTestOnly() {
        let combined = BASTypedSurfaceCountAuditDoctrine
            .excludedCategories.joined(separator: " ")
        XCTAssertTrue(combined.contains("typealias"))
        XCTAssertTrue(combined.contains("test-only"))
        XCTAssertTrue(combined.contains("nested"))
        XCTAssertTrue(combined.contains("test refactor"))
    }

    // MARK: - Per-chapter contribution audit

    func testChapter692AuditedContributionIs10() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .chapter692AuditedContribution, 10)
    }

    func testChapter692CommentClaimIs9() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .chapter692CommentClaim, 9)
    }

    func testChapter693AuditedContributionIs1() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .chapter693AuditedContribution, 1)
    }

    func testChapter693CommentClaimIs2() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .chapter693CommentClaim, 2)
    }

    func testChapter694AuditedContributionIs1() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .chapter694AuditedContribution, 1)
    }

    func testAuditedContributionSum() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .auditedContributionSum,
            BASTypedSurfaceCountAuditDoctrine
                .chapter692AuditedContribution
                + BASTypedSurfaceCountAuditDoctrine
                    .chapter693AuditedContribution)
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .auditedContributionSum, 11)
    }

    func testCommentClaimSum() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .commentClaimSum,
            BASTypedSurfaceCountAuditDoctrine
                .chapter692CommentClaim
                + BASTypedSurfaceCountAuditDoctrine
                    .chapter693CommentClaim)
    }

    func testCommentClaimSumEqualsAuditedContributionSum() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .commentClaimSum,
            BASTypedSurfaceCountAuditDoctrine
                .auditedContributionSum,
            "Errors must cancel to preserve cumulative correctness")
    }

    func testPerChapterAttributionsOffBy1ButCanceling() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .perChapterAttributionsOffBy1ButCanceling)
    }

    // MARK: - Cumulative totals

    func testPreChapter692TypedSurfaceCountIs258() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .preChapter692TypedSurfaceCount, 258)
    }

    func testPostChapter694TypedSurfaceCountIs270() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .postChapter694TypedSurfaceCount, 270)
    }

    func testVerifiedCumulativeMatch() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .verifiedCumulativeMatch)
    }

    // MARK: - Cross-doctrine refs

    func testPostSealFollowupCatalogRef() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .prePostSealFollowupCatalogRef.contains(
                    "BASPostSealFollowupCatalogDoctrine"))
    }

    func testPriorTriageDoctrineRef() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .priorTriageDoctrineRef.contains(
                    "BASSignalTenIntegrationTestTriageDoctrine"))
    }

    func testPriorAllTierCompletionRef() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .priorAllTierCompletionRef.contains(
                    "BASAllTierFullCompletionDoctrine"))
    }

    // MARK: - Methodology

    func testMethodologyMentionsExplicitConvention() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .methodology.contains(
                    "EXPLICIT COUNTING CONVENTION"))
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASTypedSurfaceCountAuditDoctrine
                .purelyAdditive)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASTypedSurfaceCountAuditDoctrine
                .directiveScoreImpact, 0)
    }
}
