// MARK: - BASSignalTenIntegrationTestTriageDoctrineTests
// chapter 六百九十三 / M2143 第二刀 — anti-drift PROOF
//                                  tests for the signal-10
//                                  triage doctrine。

import XCTest
@testable import BASRuntimeCore

final class BASSignalTenIntegrationTestTriageDoctrineTests: XCTestCase {

    // MARK: - Chapter / milestone pins

    func testChapterTag() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .chapterTag, "chapter 六百九十三")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .milestoneMNumber, 2143)
    }

    // MARK: - Affected test inventory

    func testAffectedTestCountIs12() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .affectedTestCount, 12)
    }

    func testAffectedTestClassCountIs3() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .affectedTestClassCount, 3)
    }

    func testAffectedTestClassesContent() {
        let classes = Set(
            BASSignalTenIntegrationTestTriageDoctrine
                .affectedTestClasses)
        XCTAssertTrue(classes.contains(
            "BASSubstrateReauditShadowEvaluatorTests"))
        XCTAssertTrue(classes.contains(
            "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests"))
        XCTAssertTrue(classes.contains(
            "M306MultiSessionContinuityTests"))
    }

    func testAffectedTestMethodNamesAreFullyQualified() {
        for name in BASSignalTenIntegrationTestTriageDoctrine
            .affectedTestMethodNames
        {
            XCTAssertTrue(
                name.contains("."),
                "Expected ClassName.methodName format; got \(name)")
        }
    }

    // MARK: - Pattern signature

    func testCommonPatternSignatureMentionsAsyncAndStartSession()
    {
        let sig = BASSignalTenIntegrationTestTriageDoctrine
            .commonPatternSignature
        XCTAssertTrue(sig.contains("async"))
        XCTAssertTrue(sig.contains("startSession"))
        XCTAssertTrue(sig.contains("SIGBUS"))
    }

    // MARK: - Toolchain context

    func testObservedToolchainMentionsXcodeAndSwift() {
        let tc = BASSignalTenIntegrationTestTriageDoctrine
            .observedToolchain
        XCTAssertTrue(tc.contains("Xcode 26"))
        XCTAssertTrue(tc.contains("Swift 6"))
    }

    func testSignalCodeIsTen() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .signalCode, 10)
    }

    func testSignalNameIsSIGBUS() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .signalName, "SIGBUS")
    }

    // MARK: - Triage classification

    func testIsPreExisting() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .isPreExisting)
    }

    func testIsNotBlocking() {
        XCTAssertFalse(
            BASSignalTenIntegrationTestTriageDoctrine
                .isBlocking)
    }

    func testIsOptional() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .isOptional)
    }

    // MARK: - Recovery paths

    func testRecoveryCandidateCountIs5() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .recoveryCandidateCount, 5)
    }

    func testChosenRecoveryPathIsXCTSkip() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .chosenRecoveryPathChapter693,
            "per-test-XCTSkip-with-doctrine-reference")
    }

    func testRecoveryCandidatesIncludeXCTSkipAndEnvOverride() {
        let cands = Set(
            BASSignalTenIntegrationTestTriageDoctrine
                .recoveryCandidates)
        XCTAssertTrue(cands.contains(
            "per-test-XCTSkip-with-doctrine-reference"))
        XCTAssertTrue(cands.contains(
            "phase-l-revert-via-BAS_RUNTIME_MODE_OVERRIDE-env-var"))
    }

    // MARK: - Score impact

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .directiveScoreImpact, 0)
    }

    func testSaturationInvariantPreserved() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .saturationInvariantPreserved)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPostSealFollowupCatalogRef() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .priorPostSealFollowupCatalogRef.contains(
                    "BASPostSealFollowupCatalogDoctrine"))
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .priorPostSealFollowupCatalogRef.contains(
                    "M2137"))
    }

    func testPriorPhaseLFlipRef() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .priorPhaseLFlipRef.contains(
                    "BASPhaseLDefaultFlipCompletionDoctrine"))
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .priorPhaseLFlipRef.contains("M2074"))
    }

    func testPhaseLEnvOverrideMechanism() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .phaseLEnvOverrideMechanism,
            "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal")
    }

    // MARK: - Methodology

    func testMethodologyIsHonestTriage() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .methodology.contains("HONEST TRIAGE"))
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .purelyAdditive)
    }

    // MARK: - Coverage invariants

    func testEachAffectedClassContributesTestMethods() {
        for cls in BASSignalTenIntegrationTestTriageDoctrine
            .affectedTestClasses
        {
            let countForClass =
                BASSignalTenIntegrationTestTriageDoctrine
                    .affectedTestMethodNames
                    .filter { $0.hasPrefix(cls + ".") }
                    .count
            XCTAssertGreaterThan(
                countForClass, 0,
                "Expected \(cls) to contribute at least 1 method to inventory")
        }
    }

    // MARK: - M2144 amendment — swift-testing flakiness

    func testSwiftTestingConcurrentRunFlakinessKnown() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingConcurrentRunFlakinessKnown)
    }

    func testKnownFlakySwiftTestingSuite() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .knownFlakySwiftTestingSuite,
            "BASAppleObservabilityAdapterTests")
    }

    // M2147 CORRECTION:recovery framing rewritten;
    // separate-invocations claim was inaccurate。
    func testSwiftTestingFlakinessRecoveryMentionsFilter()
    {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingFlakinessRecovery.contains(
                    "filter"))
    }

    // MARK: - M2147 swift-testing framing correction

    func testM2147CorrectionApplied() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .m2147CorrectionApplied)
    }

    func testSwiftTestingFailureFramingMentionsFullSuite() {
        let framing = BASSignalTenIntegrationTestTriageDoctrine
            .swiftTestingFailureFraming
        XCTAssertTrue(framing.contains("full-suite"))
        XCTAssertTrue(framing.contains("SIGBUS"))
        XCTAssertTrue(framing.contains("swiftpm-testing-helper"))
    }

    func testFullSuiteCrashesEvenWithXCTestDisabled() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .fullSuiteCrashesEvenWithXCTestDisabled)
    }

    func testSwiftTestingTestCountIs419() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingTestCount, 419)
    }

    func testSwiftTestingSuiteCountIs67() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingSuiteCount, 67)
    }

    func testSwiftTestingStartedBeforeCrashIs398() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingStartedBeforeCrash, 398)
    }

    func testSwiftTestingCompletedBeforeCrashIsZero() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingCompletedBeforeCrash, 0)
    }

    func testStartedExceedsCompletedDueToCrash() {
        XCTAssertGreaterThan(
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingStartedBeforeCrash,
            BASSignalTenIntegrationTestTriageDoctrine
                .swiftTestingCompletedBeforeCrash)
    }

    // MARK: - M2146 empirical diagnosis pins

    func testEmpiricalDiagnosisRunAtM2146() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosisRunAtMNumber, 2146)
    }

    func testEmpiricalDiagnosticCountIs4() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosticCount, 4)
    }

    func testEmpiricalDiagnosticsPassedIsOne() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosticsPassed, 1)
    }

    func testEmpiricalDiagnosticsCrashedIsThree() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosticsCrashed, 3)
    }

    func testEmpiricalCountsAddTo4() {
        XCTAssertEqual(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosticsPassed
                + BASSignalTenIntegrationTestTriageDoctrine
                    .empiricalDiagnosticsCrashed,
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosticCount)
    }

    func testRefinedPatternSignatureMentionsBothTriggers() {
        let sig = BASSignalTenIntegrationTestTriageDoctrine
            .refinedPatternSignaturePostM2146
        XCTAssertTrue(sig.contains("Task.detached"))
        XCTAssertTrue(sig.contains("async"))
        XCTAssertTrue(sig.contains("startSession"))
        XCTAssertTrue(sig.contains("SIGBUS"))
    }

    func testHypothesisTwoV2PathFalsified() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .hypothesisTwoV2PathFalsified)
    }

    func testHypothesisOneTaskDetachedRefined() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .hypothesisOneTaskDetachedRefined)
    }

    func testWrapperBasedRecoveryNotViable() {
        XCTAssertFalse(
            BASSignalTenIntegrationTestTriageDoctrine
                .wrapperBasedRecoveryViable)
    }

    func testEmpiricalDiagnosisTestFileRef() {
        XCTAssertTrue(
            BASSignalTenIntegrationTestTriageDoctrine
                .empiricalDiagnosisTestFile.contains(
                    "BASSignal10EmpiricalDiagnosisTests.swift"))
    }

    func testInventoryCoverageMatches6Plus3Plus3() {
        // 6 from BASSubstrateReauditShadowEvaluatorTests
        // + 3 from BASMemoryClosedLoopApplierHostRuntime
        //         IntegrationTests
        // + 3 from M306MultiSessionContinuityTests
        let countByClass = Dictionary(
            grouping: BASSignalTenIntegrationTestTriageDoctrine
                .affectedTestMethodNames,
            by: { $0.components(separatedBy: ".").first ?? "" })
            .mapValues { $0.count }
        XCTAssertEqual(
            countByClass[
                "BASSubstrateReauditShadowEvaluatorTests"], 6)
        XCTAssertEqual(
            countByClass[
                "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests"],
            3)
        XCTAssertEqual(
            countByClass["M306MultiSessionContinuityTests"], 3)
    }
}
