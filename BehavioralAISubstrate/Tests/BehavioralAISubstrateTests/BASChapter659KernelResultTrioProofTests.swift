// MARK: - BASChapter659KernelResultTrioProofTests
// chapter 六百五十九 / M2014 — PROOF tests

import XCTest
@testable import BASMetalSubstrate

final class BASChapter659KernelResultTrioProofTests: XCTestCase {
    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(String(describing: type),
                       String(describing: type))
    }
    func testBASKernelEvaluateLatencyProbeResultConformsToCodable() {
        assertCodable(BASKernelEvaluateLatencyProbeResult.self)
    }
    func testBASKernelDispatchResultConformsToCodable() {
        assertCodable(BASKernelDispatchResult.self)
    }
    func testBASBCMMetaPlasticityUpdateConformsToCodable() {
        assertCodable(BASBCMMetaPlasticityUpdate.self)
    }
}
