// MARK: - BASChapter652MambaFederatedStorageTrioProofTests
// chapter 六百五十二 / M1986 — PROOF tests for the M1985
//                              Mamba+federated-storage
//                              trio Codable extension
//                              (3rd post-hexa-#6 gap-
//                              fill,cross-module)

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASChapter652MambaFederatedStorageTrioProofTests:
    XCTestCase
{

    func testBASMambaSSMScanInputsConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMambaSSMScanInputs(
                x: [], delta: [], a: [], b: [], c: [],
                sequenceLength: 0))
    }

    func testBASMambaSSMScanOutputsConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMambaSSMScanOutputs(
                y: [], finalHiddenStateSnapshot: []))
    }

    func testBASFederatedEventLogStorageErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASFederatedEventLogStorageError.noBackends)
    }
}
