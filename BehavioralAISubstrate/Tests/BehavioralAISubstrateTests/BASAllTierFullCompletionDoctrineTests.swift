// MARK: - BASAllTierFullCompletionDoctrineTests
// chapter 六百九十二 / M2141 第四刀 — anti-drift PROOF
//                                  tests for the all-
//                                  tier completion
//                                  doctrine。

import XCTest
@testable import BASRuntimeCore

final class BASAllTierFullCompletionDoctrineTests: XCTestCase {

    // MARK: - Chapter / milestone pins

    func testChapterTag() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine.chapterTag,
            "chapter 六百九十二")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .milestoneMNumber, 2141)
    }

    // MARK: - Per-tier completion claims

    func testTierAShipped() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine.tierAShipped)
    }

    func testTierATotalCountIs8() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierATotalCount, 8)
    }

    func testTierAChapter683Count() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierAChapter683Count, 2)
    }

    func testTierAChapter692Count() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierAChapter692Count, 6)
    }

    func testTierAChapterCountsSumToTotal() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierAChapter683Count
                + BASAllTierFullCompletionDoctrine
                    .tierAChapter692Count,
            BASAllTierFullCompletionDoctrine
                .tierATotalCount)
    }

    func testTierBShipped() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine.tierBShipped)
    }

    func testTierBPrimitiveCountIs4() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierBPrimitiveCount, 4)
    }

    func testTierBUnblockedMigrationCountIs42() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierBUnblockedMigrationCount, 42)
    }

    func testTierCShipped() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine.tierCShipped)
    }

    func testTierCCandidateCountIs4() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierCCandidateCount, 4)
    }

    func testTierCParametricGenericCountIs2() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierCParametricGenericCount, 2)
    }

    func testTierCTypedConcreteStructCountIs2() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierCTypedConcreteStructCount, 2)
    }

    func testTierCSubCountsSumToCandidateCount() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .tierCParametricGenericCount
                + BASAllTierFullCompletionDoctrine
                    .tierCTypedConcreteStructCount,
            BASAllTierFullCompletionDoctrine
                .tierCCandidateCount)
    }

    // MARK: - Aggregate claims

    func testAllTiersShipped() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .allTiersShipped)
    }

    func testTierCountIs3() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine.tierCount, 3)
    }

    func testPerTierDoctrineRefCountIs3() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .perTierDoctrineRefCount, 3)
    }

    func testPerTierDoctrineRefsMentionAllThree() {
        let combined = BASAllTierFullCompletionDoctrine
            .perTierDoctrineRefs.joined(separator: " ")
        XCTAssertTrue(combined.contains(
            "BASTierACompletionDoctrine"))
        XCTAssertTrue(combined.contains(
            "BASTierBGenericPrimitivesDoctrine"))
        XCTAssertTrue(combined.contains(
            "BASTierCADR019CompletionDoctrine"))
    }

    // MARK: - Chapter 692 stats

    func testChapter692CommitCountIs4() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .chapter692CommitCount, 4)
    }

    func testChapter692CommitsListHas4Entries() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .chapter692Commits.count, 4)
    }

    func testChapter692ProofTestCount() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .chapter692ProofTestCount, 66)
    }

    // MARK: - Invariants

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .purelyAdditive)
    }

    func testV1ByteEqualityPreserved() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .v1ByteEqualityPreserved)
    }

    func testADR014OptOutPreserved() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .adr014OptOutPreserved)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .directiveScoreImpact, 0)
    }

    func testAggregateScoreUnchanged() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .aggregateScoreUnchanged)
    }

    func testSubstrateAtRestPreserved() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .substrateAtRestPreserved)
    }

    // MARK: - Methodology

    func testMethodologyCountIs3() {
        XCTAssertEqual(
            BASAllTierFullCompletionDoctrine
                .methodologyCount, 3)
    }

    func testMethodologyMentionsAllThreeTiers() {
        let keys = Set(BASAllTierFullCompletionDoctrine
            .methodologyByTier.keys)
        XCTAssertTrue(keys.contains("tierA"))
        XCTAssertTrue(keys.contains("tierB"))
        XCTAssertTrue(keys.contains("tierC"))
    }

    func testTierBMethodologyIsHonestDiscovery() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .methodologyByTier["tierB"]?
                .contains("HONEST DISCOVERY") ?? false)
    }

    func testTierCMethodologyIsReframedContract() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .methodologyByTier["tierC"]?
                .contains("REFRAMED CONTRACT") ?? false)
    }

    // MARK: - Cross-doctrine refs

    func testPriorFinal60SealRef() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .priorFinal60SealRef.contains(
                    "BASRealHotPathAttackTier2"))
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .priorFinal60SealRef.contains("M2129"))
    }

    func testPriorSubstrateAtRestRef() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .priorSubstrateAtRestRef.contains(
                    "BASPostSealFollowupCatalogDoctrine"))
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .priorSubstrateAtRestRef.contains("M2137"))
    }

    func testPriorADR019ProposalRef() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .priorADR019ProposalRef.contains(
                    "BASADR019TierCProposalDoctrine"))
    }

    func testOriginalPlanContractReframed() {
        XCTAssertTrue(
            BASAllTierFullCompletionDoctrine
                .originalPlanContractReframed)
    }
}
