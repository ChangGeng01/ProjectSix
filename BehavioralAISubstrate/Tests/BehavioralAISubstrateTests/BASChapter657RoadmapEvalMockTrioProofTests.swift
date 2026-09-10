// MARK: - BASChapter657RoadmapEvalMockTrioProofTests
// chapter 六百五十七 / M2006 — PROOF tests for the M2005
//                              roadmap-eval-mock trio
//                              Codable extension (1st
//                              post-hexa-#7 gap-fill,
//                              cross-module BASRuntime
//                              Core + BASOrgan reach)

import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan

final class BASChapter657RoadmapEvalMockTrioProofTests:
    XCTestCase
{

    func testBASRoadmapPhaseStatusConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(BASRoadmapPhaseStatus.shipped)
        assertCodableRoundTrips(
            BASRoadmapPhaseStatus.partiallyShipped(percent: 0))
    }

    func testBASAutoEvalBaselineModeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASAutoEvalBaselineMode.latestForBuildChapter)
        assertCodableRoundTrips(
            BASAutoEvalBaselineMode.explicitRunID(""))
    }

    func testBASFoundationModelsMockErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASFoundationModelsMockError.scriptExhausted)
        assertCodableRoundTrips(
            BASFoundationModelsMockError.scripted(reason: ""))
    }
}
