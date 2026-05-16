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
}
