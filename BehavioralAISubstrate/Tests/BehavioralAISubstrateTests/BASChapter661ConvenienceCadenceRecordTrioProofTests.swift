// MARK: - BASChapter661ConvenienceCadenceRecordTrioProofTests
// chapter 六百六十一 / M2022 — PROOF tests

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter661ConvenienceCadenceRecordTrioProofTests: XCTestCase {
    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(String(describing: type),
                       String(describing: type))
    }
    func testBASCognitiveOSConvenienceCadenceConformsToCodable() {
        assertCodable(BASCognitiveOSConvenienceCadence.self)
    }
    func testBASCognitiveOSConvenienceResultConformsToCodable() {
        assertCodable(BASCognitiveOSConvenienceResult.self)
    }
    func testBASMambaInferenceLatencyRecordConformsToCodable() {
        assertCodable(BASMambaInferenceLatencyRecord.self)
    }
}
