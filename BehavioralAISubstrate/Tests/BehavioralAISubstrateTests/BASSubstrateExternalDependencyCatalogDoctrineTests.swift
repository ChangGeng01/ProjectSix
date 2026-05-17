// MARK: - BASSubstrateExternalDependencyCatalogDoctrineTests
// chapter 六百九十五 / M2151 第二刀 — anti-drift PROOF
//                                  tests for external
//                                  dependency catalog。

import XCTest
@testable import BASRuntimeCore

final class BASSubstrateExternalDependencyCatalogDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .chapterTag, "chapter 六百九十五")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .milestoneMNumber, 2151)
    }

    // MARK: - Categorical owners

    func testExternalOwnerCategoryCountIs4() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .externalOwnerCategoryCount, 4)
    }

    func testOwnerCategoriesMentionAllFour() {
        let combined =
            BASSubstrateExternalDependencyCatalogDoctrine
                .externalOwnerCategories
                .joined(separator: " ")
        XCTAssertTrue(combined.contains("TOOLCHAIN"))
        XCTAssertTrue(combined.contains("HOST-APP"))
        XCTAssertTrue(combined.contains(
            "EXTERNAL-ARCHITECTURE"))
        XCTAssertTrue(combined.contains("EXTERNAL-TOOLING"))
    }

    // MARK: - Toolchain blocked

    func testBlockedSignal10TestCountIs12() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedSignal10TestCount, 12)
    }

    func testBlockedDiagnosticTestCountIs3() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedDiagnosticTestCount, 3)
    }

    func testBlockedSwiftTestingTestCountIs419() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedSwiftTestingTestCount, 419)
    }

    func testToolchainBlockedTotal() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .toolchainBlockedTotal,
            12 + 3 + 419)
    }

    func testToolchainOwnerNoteMentionsXcodeAndSwift() {
        let note =
            BASSubstrateExternalDependencyCatalogDoctrine
                .toolchainOwnerNote
        XCTAssertTrue(note.contains("Xcode"))
        XCTAssertTrue(note.contains("Swift"))
    }

    func testToolchainBlockedRecoveryGateMentionsXcode265() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .toolchainBlockedRecoveryGate.contains(
                    "Xcode 26.5"))
    }

    // MARK: - Host-app blocked

    func testBlockedTierAItemAdoptionCountIs6() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedTierAItemAdoptionCount, 6)
    }

    func testPreservedSprawlStructCountIs64() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .preservedSprawlStructCount, 64)
    }

    func testBlockedIOSFoundationModelsProofItemsIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedIOSFoundationModelsProofItems, 1)
    }

    func testHostAppOwnerNoteMentionsCallSiteAdoption() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .hostAppOwnerNote.contains("call-site"))
    }

    // MARK: - External-architecture blocked

    func testBlockedMultiHostFederationItemsIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedMultiHostFederationItems, 1)
    }

    func testBlockedBASTensorZeroCopyItemsIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedBASTensorZeroCopyItems, 1)
    }

    // MARK: - External-tooling blocked

    func testBlockedMLXCoreMLCLIItemsIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedMLXCoreMLCLIItems, 1)
    }

    func testBlockedSelfTuningSchedulerItemsIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .blockedSelfTuningSchedulerItems, 1)
    }

    // MARK: - Aggregate

    func testNonTestBlockedItemCountIs11() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .nonTestBlockedItemCount, 11)
    }

    func testSubstrateActionableItemsRemainingIsZero() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .substrateActionableItemsRemaining, 0)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPostSealFollowupCatalogRef() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .priorPostSealFollowupCatalogRef.contains(
                    "BASPostSealFollowupCatalogDoctrine"))
    }

    func testPriorSignal10TriageRef() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .priorSignal10TriageRef.contains(
                    "BASSignalTenIntegrationTestTriageDoctrine"))
    }

    func testPriorSprawlScopeAuditRef() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .priorSprawlScopeAuditRef.contains(
                    "BASSprawlScopeAuditDoctrine"))
    }

    func testPriorTierACompletionRef() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .priorTierACompletionRef.contains(
                    "BASTierACompletionDoctrine"))
    }

    // MARK: - Methodology + invariants

    func testMethodologyMentionsExplicitOwnerAttribution() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .methodology.contains(
                    "EXPLICIT OWNER ATTRIBUTION"))
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .purelyAdditive)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .directiveScoreImpact, 0)
    }

    func testSubstrateAtRestPreserved() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .substrateAtRestPreserved)
    }

    // MARK: - M2165 consolidated typedAudit_* pins
    //         (migrated from former
    //         BASTypedSurfaceCountAuditDoctrine)

    func testTypedAuditConsolidatedFromAuditDoctrine() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_consolidatedFromTypedSurfaceCountAuditDoctrine)
    }

    func testTypedAuditConsolidatedAtMNumberIs2165() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_consolidatedAtMNumber, 2165)
    }

    func testTypedAuditCountedTypeKindCountIs5() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_countedTypeKindCount, 5)
    }

    func testTypedAuditExcludedCategoryCountIs4() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_excludedCategoryCount, 4)
    }

    func testTypedAuditChapter692ContributionIs10() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_chapter692AuditedContribution,
            10)
    }

    func testTypedAuditChapter692CommentClaimIs9() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_chapter692CommentClaim, 9)
    }

    func testTypedAuditChapter693ContributionIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_chapter693AuditedContribution,
            1)
    }

    func testTypedAuditChapter693CommentClaimIs2() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_chapter693CommentClaim, 2)
    }

    func testTypedAuditChapter694ContributionIs1() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_chapter694AuditedContribution,
            1)
    }

    func testTypedAuditContributionSumEqualsCommentClaimSum() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_auditedContributionSum,
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_commentClaimSum)
    }

    func testTypedAuditPerChapterAttributionsOffBy1ButCanceling() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_perChapterAttributionsOffBy1ButCanceling)
    }

    func testTypedAuditPreChapter692CountIs258() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_preChapter692TypedSurfaceCount,
            258)
    }

    func testTypedAuditPostChapter694CountIs270() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_postChapter694TypedSurfaceCount,
            270)
    }

    func testTypedAuditVerifiedCumulativeMatch() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_verifiedCumulativeMatch)
    }

    func testTypedAuditMethodologyExplicitConvention() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .typedAudit_methodology.contains(
                    "EXPLICIT COUNTING CONVENTION"))
    }

    // MARK: - M2165 consolidated sprawl_* pins
    //         (migrated from former
    //         BASSprawlScopeAuditDoctrine)

    func testSprawlConsolidatedFromSprawlAuditDoctrine() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_consolidatedFromSprawlScopeAuditDoctrine)
    }

    func testSprawlResultStructCountIs37() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_resultStructCount, 37)
    }

    func testSprawlFrameStructCountIs22() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_frameStructCount, 22)
    }

    func testSprawlPermitStructCountIs2() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_permitStructCount, 2)
    }

    func testSprawlCardStructCountIs3() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_cardStructCount, 3)
    }

    func testSprawlTotalSprawlStructCountIs64() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_totalSprawlStructCount, 64)
    }

    func testSprawlChapter691EstimatedTotalIs42() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_chapter691EstimatedTotalCount, 42)
    }

    func testSprawlActualMinusEstimatedDeltaIsPlus22() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_actualMinusEstimatedDelta, 22)
    }

    func testSprawlMigratableToTierBCountIsZero() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_migratableToTierBCount, 0)
    }

    func testSprawlDomainComplexPreservedCountIs64() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_domainComplexPreservedCount, 64)
    }

    func testSprawlMigrationPercentageIsZero() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_migrationPercentage, 0.0)
    }

    func testSprawlCategorizationRationaleCountIs4() {
        XCTAssertEqual(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_categorizationRationaleCount, 4)
    }

    func testSprawlChapter691OverestimateAcknowledged() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_chapter691OverestimateAcknowledged)
    }

    func testSprawlTierBPrimitivesRemainValuableForNewTypes() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_tierBPrimitivesRemainValuableForNewTypes)
    }

    func testSprawlMethodologyEmpiricalAudit() {
        XCTAssertTrue(
            BASSubstrateExternalDependencyCatalogDoctrine
                .sprawl_methodology.contains(
                    "EMPIRICAL SPRAWL AUDIT"))
    }
}
