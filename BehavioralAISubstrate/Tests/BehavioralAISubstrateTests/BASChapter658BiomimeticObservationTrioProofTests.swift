// MARK: - BASChapter658BiomimeticObservationTrioProofTests
// chapter 六百五十八 / M2010 — PROOF tests for the M2009
//                              BASMetalSubstrate
//                              biomimetic-observation
//                              trio Codable extension
//                              (2nd post-hexa-#7 gap-fill
//                              ,single-module BAS
//                              MetalSubstrate reach)

import XCTest
@testable import BASMetalSubstrate

final class BASChapter658BiomimeticObservationTrioProofTests:
    XCTestCase
{

    func testBASPredictiveCodingObservationConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASPredictiveCodingObservation(
                observed: [],
                priorPrediction: [],
                error: [],
                updatedPrediction: [],
                runningMSE: 0,
                observationIndex: 0))
    }

    func testBASPlasticityUpdateConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASPlasticityUpdate(
                pre: [],
                post: [],
                outcome: 0,
                weightDelta: [],
                updatedWeightSnapshot: [],
                updateIndex: 0))
    }

    func testBASHierarchicalObservationConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASHierarchicalObservation(
                perLayer: [],
                topLayerError: [],
                topLayerMSE: 0,
                observationIndex: 0))
    }
}
