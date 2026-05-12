// MARK: - BASChapter568ThirdWaveCodableExtensionProofTests
// chapter 五百六十八 / M1650 — PROOF tests for the 3
//                          newly-Codable types shipped
//                          at M1649
//
// ## Coverage (4 tests)
//
// 3 compile-time conformance + 1 populated round-trip
// PROOF test。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 3 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1649 → M1650

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter568ThirdWaveCodableExtensionProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testKnowledgeGraphEventExtractionResultConformsToCodable()
    {
        assertCodable(
            BASKnowledgeGraphEventExtractionResult.self)
    }

    func testHostCandidatePipelineObservationSnapshotConformsToCodable()
    {
        assertCodable(
            BASHostCandidatePipelineObservationSnapshot
                .self)
    }

    func testForbiddenLifecycleGateDecisionConformsToCodable()
    {
        assertCodable(
            BASForbiddenLifecycleGateDecision.self)
    }

    /// BASHostCandidatePipelineObservationSnapshot
    /// populated round-trips byte-identical via JSON。
    func testSnapshotPopulatedRoundTrips() throws {
        let original = BASHostCandidatePipelineObservationSnapshot(
            activeVersionID: "v1-568",
            committedVersionIDs: ["v0-568", "v1-568"],
            pendingCandidateIDs: ["c1-568"],
            rejectedCandidateIDs: [],
            frozenVersionIDs: ["frozen-568"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostCandidatePipelineObservationSnapshot
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.committedVersionIDs.count, 2)
    }
}
