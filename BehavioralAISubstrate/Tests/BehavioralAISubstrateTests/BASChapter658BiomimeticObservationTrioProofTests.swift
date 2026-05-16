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

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASPredictiveCodingObservationConformsToCodable() {
        assertCodable(BASPredictiveCodingObservation.self)
    }

    func testBASPlasticityUpdateConformsToCodable() {
        assertCodable(BASPlasticityUpdate.self)
    }

    func testBASHierarchicalObservationConformsToCodable() {
        assertCodable(BASHierarchicalObservation.self)
    }
}
