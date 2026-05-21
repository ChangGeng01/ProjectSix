// MARK: - BASChapter679MambaSSMFixturesShipDoctrineTests
// chapter 六百七十九 / M2096 第四刀 — anti-drift PROOF tests
//                                    for chapter 679 close-
//                                    out doctrine

import XCTest
@testable import BASRuntimeCore

final class
BASChapter679MambaSSMFixturesShipDoctrineTests:
    XCTestCase
{
    typealias D = BASChapter679MambaSSMFixturesShipDoctrine

    // MARK: - Chapter identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十九")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    func testPhaseStatus() {
        XCTAssertEqual(D.phaseStatus, "in-progress")
    }

    // MARK: - M-number range

    func testMNumberRangeMatchesKnives() {
        XCTAssertEqual(D.firstKnifeMNumber, 2093)
        XCTAssertEqual(D.secondKnifeMNumber, 2094)
        XCTAssertEqual(D.thirdKnifeMNumber, 2095)
        XCTAssertEqual(D.fourthKnifeMNumber, 2096)
        XCTAssertEqual(D.mNumberFirst, 2093)
        XCTAssertEqual(D.mNumberLast, 2096)
    }

    func testKnivesCountIsFour() {
        XCTAssertEqual(D.knivesCount, 4)
    }

    // MARK: - Artifacts

    func testJSONFixtureArtifactCountIs7() {
        // 6 JSON fixtures + 1 README = 7
        XCTAssertEqual(D.jsonFixtureArtifactCount, 7)
    }

    func testJSONArtifactsAllUnderVendor() {
        for path in D.jsonFixtureArtifacts {
            XCTAssertTrue(
                path.hasPrefix("Vendor/mamba-ssm-fixtures/"),
                "fixture path \(path) must be under " +
                "Vendor/mamba-ssm-fixtures/")
        }
    }

    func testReadmeArtifactPresent() {
        XCTAssertTrue(D.jsonFixtureArtifacts.contains(
            "Vendor/mamba-ssm-fixtures/README.md"))
    }

    func testAll6JsonFixturesPresent() {
        for i in 1...6 {
            let prefix = String(format: "%02d_", i)
            let matched = D.jsonFixtureArtifacts
                .filter { $0.contains(
                    "/\(prefix)") }
            XCTAssertEqual(
                matched.count, 1,
                "exactly one fixture starting with " +
                "prefix \(prefix) must be present")
        }
    }

    func testProductionArtifactsIncludeRegistry() {
        XCTAssertTrue(D.productionArtifacts.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanFixtureRegistry.swift"))
    }

    func testTestArtifactsIncludeBothSuites() {
        XCTAssertEqual(D.testArtifacts.count, 2)
    }

    // MARK: - New types

    func testNewTypesIncludeFixtureAndRegistry() {
        XCTAssertEqual(D.newTypes.count, 2)
        XCTAssertTrue(D.newTypes.contains("BASSSMScanFixture"))
        XCTAssertTrue(D.newTypes.contains(
            "BASSSMScanFixtureRegistry"))
    }

    // MARK: - Fixture catalog

    func testCanonicalFixtureCountIs6() {
        XCTAssertEqual(D.canonicalFixtureCount, 6)
    }

    func testAllSixFixtureNamesUnique() {
        XCTAssertEqual(
            Set(D.fixtureNames).count,
            D.fixtureNames.count)
        XCTAssertEqual(
            D.fixtureNames.count,
            D.canonicalFixtureCount)
    }

    func testFixtureNamesIncludeAllExpected() {
        for expected in [
            "zero_delta_zero_output",
            "identity_unit_step",
            "two_step_decay",
            "three_step_accumulation",
            "two_channel_independence",
            "two_batch_independence"
        ] {
            XCTAssertTrue(
                D.fixtureNames.contains(expected))
        }
    }

    // MARK: - Honest provenance

    func testProvenanceIsAnalyticNotPython() {
        XCTAssertTrue(D.provenanceIsAnalyticDerivation)
        XCTAssertFalse(D.provenanceIsPythonReferenceCapture)
    }

    // MARK: - Test counts

    func testRegistryAntiDriftTestCountIs18() {
        XCTAssertEqual(D.registryAntiDriftTestCount, 18)
    }

    func testFixtureValidationTestCountIs14() {
        XCTAssertEqual(D.fixtureValidationTestCount, 14)
    }

    func testTotalChapter679TestCountIs32() {
        XCTAssertEqual(D.totalChapter679TestCount, 32)
    }

    func testCpuVsGpuValidationCountsEqual() {
        XCTAssertEqual(
            D.cpuValidationTestCount,
            D.gpuValidationTestCount)
        XCTAssertEqual(D.cpuValidationTestCount, 6)
    }

    func testAllFixturesLoopTestCountIs2() {
        XCTAssertEqual(D.allFixturesLoopTestCount, 2)
    }

    // MARK: - Triangulation oracles

    func testCorrectnessOracleCountIs3() {
        XCTAssertEqual(D.correctnessOracleCount, 3)
    }

    func testCorrectnessOraclesListMatchesCount() {
        XCTAssertEqual(
            D.correctnessOracles.count,
            D.correctnessOracleCount)
    }

    // MARK: - Tolerance

    func testUniformToleranceIs1eMinus5() {
        XCTAssertEqual(
            D.uniformToleranceFloat32,
            1e-5, accuracy: 1e-10)
    }

    // MARK: - Achievement flags

    func testCanonicalFixturesShipped() {
        XCTAssertTrue(D.canonicalFixturesShipped)
    }

    func testSwiftRegistryMirrorsJsonFixtures() {
        XCTAssertTrue(D.swiftRegistryMirrorsJsonFixtures)
    }

    func testCpuMatchesAllFixtures() {
        XCTAssertTrue(D.cpuMatchesAllFixtures)
    }

    func testGpuMatchesAllFixtures() {
        XCTAssertTrue(D.gpuMatchesAllFixtures)
    }

    func testTriangulationAchieved() {
        XCTAssertTrue(D.triangulationAchieved)
    }

    func testHonestProvenanceDocumented() {
        XCTAssertTrue(D.honestProvenanceDocumented)
    }

    // MARK: - Phase M progress

    func testPhaseMChaptersCompleteIs3() {
        XCTAssertEqual(D.phaseMChaptersComplete, 3)
    }

    func testPhaseMCommitsCompleteIs12() {
        XCTAssertEqual(D.phaseMCommitsComplete, 12)
    }

    func testPhaseMHalfwayDone() {
        XCTAssertEqual(
            D.phaseMPercentComplete,
            50.0, accuracy: 0.1)
    }

    // MARK: - Next chapter

    func testNextChapterIs680() {
        XCTAssertEqual(
            D.nextChapter, "chapter 六百八十")
    }

    func testNextChapterMNumberStartIs2097() {
        XCTAssertEqual(D.nextChapterMNumberStart, 2097)
    }
}
