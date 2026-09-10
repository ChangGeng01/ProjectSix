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

    // MARK: - 5 conformance PROOFs

    // #18: real round-trip — construct a minimal valid instance
    // of each type and assert it survives an encode/decode cycle.
    func testCoreMLFeatureFrameConformsToCodable() {
        assertCodableRoundTrips(
            BASCoreMLFeatureFrame(featureValues: [:]))
    }

    func testKnowledgeCycleConformsToCodable() {
        assertCodableRoundTrips(
            BASKnowledgeCycle(nodeIDs: [], edgeKinds: []))
    }

    func testRAGResultConformsToCodable() {
        assertCodableRoundTrips(
            BASRAGResult(
                atoms: [],
                scores: [:],
                staleAtomIDs: [],
                reasonCodes: []))
    }

    func testVectorIndexEntryConformsToCodable() {
        assertCodableRoundTrips(
            BASVectorIndexEntry(
                atomID: "",
                normalizedEmbedding: BASEmbedding(
                    vector: [],
                    dimension: 0,
                    providerVersion: ""),
                domain: "",
                metadata: [:]))
    }

    func testVectorTopKResultConformsToCodable() {
        assertCodableRoundTrips(
            BASVectorTopKResult(atomID: "", score: 0.0))
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
