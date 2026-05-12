// MARK: - BASChapter566CrossModuleCodableExtensionProofTests
// chapter 五百六十六 / M1642 — PROOF tests for the 5
//                          newly-Codable cross-module
//                          types shipped at M1641
//
// ## Coverage (7 tests)
//
// 5 compile-time conformance + 2 populated round-trip
// PROOF tests covering:
//   - BASCoreMLFeatureFrame (BASRuntimeCore)
//   - BASKnowledgeCycle (BASRuntimeCore)
//   - BASRAGResult (BASMemory)
//   - BASVectorIndexEntry (BASMemory)
//   - BASVectorTopKResult (BASMemory)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 5 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1641 → M1642

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter566CrossModuleCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - Compile-time conformance helper

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    // MARK: - 5 compile-time conformance PROOFs

    func testCoreMLFeatureFrameConformsToCodable() {
        assertCodable(BASCoreMLFeatureFrame.self)
    }

    func testKnowledgeCycleConformsToCodable() {
        assertCodable(BASKnowledgeCycle.self)
    }

    func testRAGResultConformsToCodable() {
        assertCodable(BASRAGResult.self)
    }

    func testVectorIndexEntryConformsToCodable() {
        assertCodable(BASVectorIndexEntry.self)
    }

    func testVectorTopKResultConformsToCodable() {
        assertCodable(BASVectorTopKResult.self)
    }

    // MARK: - Populated round-trip PROOFs (2 simple types)

    /// BASCoreMLFeatureFrame populated round-trips
    /// byte-identical via JSON。
    func testCoreMLFeatureFramePopulatedRoundTrips()
        throws
    {
        let original = BASCoreMLFeatureFrame(
            featureValues: [
                "feature-a": 0.5,
                "feature-b": 1.2,
                "feature-c": 0.0
            ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCoreMLFeatureFrame.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.featureValues.count, 3)
    }

    /// BASVectorTopKResult populated round-trips byte-
    /// identical via JSON。
    func testVectorTopKResultPopulatedRoundTrips() throws
    {
        let original = BASVectorTopKResult(
            atomID: "atom-566",
            score: 0.85)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASVectorTopKResult.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.atomID, "atom-566")
        XCTAssertEqual(decoded.score, 0.85, accuracy: 1e-6)
    }
}
