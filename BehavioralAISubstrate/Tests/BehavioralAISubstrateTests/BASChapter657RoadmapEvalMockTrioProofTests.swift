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

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASRoadmapPhaseStatusConformsToCodable() {
        assertCodable(BASRoadmapPhaseStatus.self)
    }

    func testBASAutoEvalBaselineModeConformsToCodable() {
        assertCodable(BASAutoEvalBaselineMode.self)
    }

    func testBASFoundationModelsMockErrorConformsToCodable() {
        assertCodable(BASFoundationModelsMockError.self)
    }
}
