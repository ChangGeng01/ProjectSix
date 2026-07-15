// MARK: - BASChapter662BiomimeticSignalRecordTrioProofTests
// chapter 六百六十二 / M2026 — PROOF tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASOrgan

final class BASChapter662BiomimeticSignalRecordTrioProofTests: XCTestCase {

    func testBASBiomimeticTurnSignalConformsToCodable() {
        // #18: real round-trip (all-optional/default init)
        assertCodableRoundTrips(
            BASBiomimeticTurnSignal())
    }

    func testBASBiomimeticTurnObservationConformsToCodable() {
        // #18: real round-trip (all-optional/default init)
        assertCodableRoundTrips(
            BASBiomimeticTurnObservation())
    }

    func testBASFoundationModelsMockCallRecordConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASFoundationModelsMockCallRecord(
                request: BASOrganRequest(
                    requestID: "",
                    role: .scout,
                    preset: .scout,
                    instruction: ""),
                respondedWith: .text(body: ""),
                calledAtMs: 0))
    }
}
