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

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASMambaSSMScanInputsConformsToCodable() {
        assertCodable(BASMambaSSMScanInputs.self)
    }

    func testBASMambaSSMScanOutputsConformsToCodable() {
        assertCodable(BASMambaSSMScanOutputs.self)
    }

    func testBASFederatedEventLogStorageErrorConformsToCodable() {
        assertCodable(
            BASFederatedEventLogStorageError.self)
    }
}
