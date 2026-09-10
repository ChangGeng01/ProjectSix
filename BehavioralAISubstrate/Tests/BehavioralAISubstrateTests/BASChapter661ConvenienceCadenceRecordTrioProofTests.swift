// MARK: - BASChapter661ConvenienceCadenceRecordTrioProofTests
// chapter 六百六十一 / M2022 — PROOF tests

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter661ConvenienceCadenceRecordTrioProofTests: XCTestCase {

    func testBASCognitiveOSConvenienceCadenceConformsToCodable() {
        // #18: real round-trip (all-default init)
        assertCodableRoundTrips(
            BASCognitiveOSConvenienceCadence())
    }

    func testBASCognitiveOSConvenienceResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASCognitiveOSConvenienceResult(
                eventAppended: false,
                stateFolded: false,
                graphExtracted: false,
                iterationIndex: 0))
    }

    func testBASMambaInferenceLatencyRecordConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMambaInferenceLatencyRecord(
                latencyMs: 0,
                thermalBand: .low,
                timestampMs: 0))
    }
}
