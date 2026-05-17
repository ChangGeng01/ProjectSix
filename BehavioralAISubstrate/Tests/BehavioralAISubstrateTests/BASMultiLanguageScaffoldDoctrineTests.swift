// MARK: - BASMultiLanguageScaffoldDoctrineTests
// chapter 七百一 / M2169 第三刀 — anti-drift PROOF
//                                  tests for the multi-
//                                  language scaffold
//                                  doctrine。

import XCTest
@testable import BASRuntimeCore

final class BASMultiLanguageScaffoldDoctrineTests: XCTestCase {

    // MARK: - Chapter / milestone pins

    func testChapterTag() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine.chapterTag,
            "chapter 七百一")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .milestoneMNumber, 2169)
    }

    // MARK: - Languages enumerated

    func testAugmentedLanguageCountIs5() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .augmentedLanguageCount, 5)
    }

    func testAugmentedLanguagesMentionAll5() {
        let langs = Set(
            BASMultiLanguageScaffoldDoctrine
                .augmentedLanguages)
        XCTAssertTrue(langs.contains("SQL"))
        XCTAssertTrue(langs.contains("C"))
        XCTAssertTrue(langs.contains("Metal"))
        XCTAssertTrue(langs.contains("C++"))
        XCTAssertTrue(langs.contains("Rust"))
    }

    // MARK: - New SPM targets

    func testNewSpmTargetCountIs3() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .newSpmTargetCount, 3)
    }

    func testNewSpmTargetsIncludeAllThree() {
        let combined = BASMultiLanguageScaffoldDoctrine
            .newSpmTargets.joined(separator: " ")
        XCTAssertTrue(combined.contains(
            "BASCSystemBridge"))
        XCTAssertTrue(combined.contains(
            "BASMPSGraphExecutableCacheCxx"))
        XCTAssertTrue(combined.contains(
            "BASRustCoreBridge"))
    }

    func testSqlPilotMechanismIsPlugin() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .sqlPilotMechanism.contains(
                    "SPM build plugin"))
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .sqlPilotMechanism.contains(
                    "BASSQLSchemaGen"))
    }

    func testMetalPilotMechanismIsExcludeToResources() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .metalPilotMechanism.contains(
                    "exclude → resources"))
    }

    // MARK: - Feature flag actor

    func testFeatureFlagActorRefMentionsM2168() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .featureFlagActorRef.contains("M2168"))
    }

    func testFeatureFlagCountIs5() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .featureFlagCount, 5)
    }

    func testFeatureFlagDefaultIsFalse() {
        XCTAssertFalse(
            BASMultiLanguageScaffoldDoctrine
                .featureFlagDefaultValue)
    }

    func testFeatureFlagNamesMatchActorCases() {
        // The 5 names in the doctrine must match the 5
        // Flag cases in BASLanguageAugmentationFeatureFlags
        let doctrineNames = Set(
            BASMultiLanguageScaffoldDoctrine
                .featureFlagNames)
        let actorNames = Set(
            BASLanguageAugmentationFeatureFlags.Flag
                .allCases.map { $0.rawValue })
        XCTAssertEqual(doctrineNames, actorNames)
    }

    // MARK: - Pilot chapter roadmap

    func testPilotChapterRoadmapCountIs5() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .pilotChapterRoadmapCount, 5)
    }

    func testPilotChapterRoadmapMentionsSql() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .pilotChapterRoadmap["SQL"],
            "chapter 七百二 / M2171-M2174")
    }

    func testPilotChapterRoadmapMentionsRust() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .pilotChapterRoadmap["Rust"],
            "chapter 七百六 / M2187-M2190")
    }

    // MARK: - chapter 698 discipline gate

    func testChapter698DisciplineGateSatisfied() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .chapter698DisciplineGateSatisfied)
    }

    func testChapter698GateUsedOptionB() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .chapter698DisciplineGateOptionUsed
                .contains("option-b"))
    }

    func testUserDirectiveMentionsMultiLanguage() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .userDirective.contains("全面"))
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .userDirective.contains("Rust"))
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .userDirective.contains("Metal"))
    }

    // MARK: - Counter-sprawl honesty

    func testCounterSprawlInversionAcknowledged() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .counterSprawlInversionAcknowledged)
    }

    func testNetDoctrineDeltaIsMinus2() {
        // -3 from chapter 699+700 consolidation + 1
        // from this scaffold = -2 net
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .netDoctrineDeltaAcrossChapters699To701,
            -2)
    }

    // MARK: - Pilots without new doctrines (discipline)

    func testPilotChaptersWithoutNewDoctrineCountIs5() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .pilotChaptersWithoutNewDoctrineCount, 5)
    }

    func testEachPilotMentionsProductionCodeTypedSurface() {
        for chap in BASMultiLanguageScaffoldDoctrine
            .pilotChaptersWithoutNewDoctrine
        {
            XCTAssertTrue(
                chap.contains("production-code-typed-surface"),
                "pilot \(chap) must reference the chapter 698 discipline pattern")
        }
    }

    // MARK: - Invariants

    func testADR014OptOutPreserved() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .adr014OptOutPreserved)
    }

    func testByteEqualityInvariantPreserved() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .byteEqualityInvariantPreserved)
    }

    func testSaturationInvariantHolds() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .saturationInvariantHolds)
    }

    func testSubstrateAtRestPreserved() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .substrateAtRestPreserved)
    }

    func testTierABCCompletePreserved() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .tierABCCompletePreserved)
    }

    func testSigbusRecoveryPreserved() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .sigbusRecoveryPreserved)
    }

    // MARK: - Cross-doctrine refs

    func testCrossDoctrineRefCountIs4() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .crossDoctrineRefCount, 4)
    }

    func testPriorMaximallyResolvedRefHasAllAmendments() {
        let ref = BASMultiLanguageScaffoldDoctrine
            .priorMaximallyResolvedRef
        XCTAssertTrue(ref.contains("M2152"))
        XCTAssertTrue(ref.contains("M2155"))
        XCTAssertTrue(ref.contains("M2162"))
        XCTAssertTrue(ref.contains(
            "chapter 699 consolidation"))
    }

    func testPriorChapter698DisciplineGateRef() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .priorChapter698DisciplineGateRef
                .contains("futureNewDoctrineGate"))
    }

    func testPilotFeatureFlagActorRefMentionsActor() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .pilotFeatureFlagActorRef.contains(
                    "BASLanguageAugmentationFeatureFlags"))
    }

    // MARK: - Verification gates

    func testPerPilotVerificationGateMentionsDualMode() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .perPilotVerificationGate.contains(
                    "dual-mode"))
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .perPilotVerificationGate.contains(
                    "byte"))
    }

    func testCrossChapterRegressionGateMentions11573() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .crossChapterRegressionGate.contains(
                    "11573"))
    }

    // MARK: - Methodology + score

    func testMethodologyIsMultiLanguageAugmentation() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine.methodology
                .contains("MULTI-LANGUAGE AUGMENTATION"))
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASMultiLanguageScaffoldDoctrine
                .purelyAdditive)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .directiveScoreImpact, 0)
    }
}
