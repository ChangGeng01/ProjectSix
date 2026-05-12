// MARK: - BASEBrainTurnResultEvolutionBundleTests
// chapter 五百二十四 / M1473 — evolution bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultEvolutionBundleTests:
    XCTestCase
{

    func testEmptyBundleHasZeroPopulatedCount() {
        let bundle =
            BASEBrainTurnResultEvolutionBundle()
        XCTAssertEqual(bundle.populatedFieldCount, 0)
        XCTAssertTrue(bundle.isCold)
    }

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASEBrainTurnResultEvolutionBundle.empty,
            BASEBrainTurnResultEvolutionBundle())
    }

    func testEvolutionFieldCountPinnedToTen() {
        XCTAssertEqual(
            BASEBrainTurnResultEvolutionBundle
                .evolutionFieldCount,
            10,
            "10 evolution cluster fields:experienceCandidates" +
            " + workflowCandidates + guardTemplate" +
            "Candidates + biasRecords + riskPatternCandidates" +
            " + learningExportBundles + shadowTrialRecords" +
            " + versionDeltas + retractionOrders +" +
            " evolutionSeals")
    }

    func testPopulatedFieldCountCounts() {
        // Use real init signatures - kept fixtures
        // minimal to avoid coupling to upstream schema
        // changes
        let exp = BASExperienceCandidate(
            candidateID: "exp-1",
            candidateType: .success,
            summary: "test",
            stabilitySignal: 0.5,
            contaminationRisk: 0.2,
            hostScope: "host.s1",
            sovereignScope: "sov.s1")
        let bundle =
            BASEBrainTurnResultEvolutionBundle(
                experienceCandidates: [exp])
        XCTAssertEqual(bundle.populatedFieldCount, 1)
        XCTAssertFalse(bundle.isCold)
    }

    func testEquatableValueEquality() {
        let b1 =
            BASEBrainTurnResultEvolutionBundle()
        let b2 =
            BASEBrainTurnResultEvolutionBundle()
        XCTAssertEqual(b1, b2)
    }
}
