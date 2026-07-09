import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore

/// audit memory-b F3 — admit() used to overwrite the in-process content cache on EVERY new event,
/// including a conflicting re-admit of the same id with LOWER confidence. The M942 reducer keeps
/// the higher-confidence winner's METADATA, but the cache then held the loser's CONTENT, so
/// atom(forID:) returned a winner-metadata + loser-content HYBRID. (The prior "close" was a
/// docs-only comment fix — the behavioral defect was still live.)
final class BASEventSourcedContentCachePollutionTests: XCTestCase {

    private func atom(id: UUID, confidence: Double, content: String) -> BASGovernedMemory {
        BASGovernedMemory(id: id, kind: .episodic, content: content, scope: .session,
                          sensitivity: .low, tier: .warm, confidence: confidence,
                          sourceType: "t", governanceStatus: .governed, provenanceSummary: "p")
    }

    func testLowerConfidenceReAdmitDoesNotPolluteWinnerContent() async throws {
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(), sessionID: "s")
        let id = UUID()
        _ = try await store.admit(atom(id: id, confidence: 0.9, content: "WINNER"))
        _ = try await store.admit(atom(id: id, confidence: 0.3, content: "LOSER"))  // loses the tiebreak
        let got = await store.atom(forID: id.uuidString)
        XCTAssertEqual(got?.confidence, 0.9, "the reducer keeps the higher-confidence winner's metadata")
        XCTAssertEqual(got?.content, "WINNER",
            "content must be the WINNER's — a lower-confidence re-admit must NOT pollute it (the F3 hybrid)")
    }

    func testHigherConfidenceReAdmitDoesUpdateContent() async throws {
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(), sessionID: "s")
        let id = UUID()
        _ = try await store.admit(atom(id: id, confidence: 0.3, content: "OLD"))
        _ = try await store.admit(atom(id: id, confidence: 0.9, content: "NEW"))    // strictly wins
        let got = await store.atom(forID: id.uuidString)
        XCTAssertEqual(got?.confidence, 0.9)
        XCTAssertEqual(got?.content, "NEW",
            "a strictly-higher-confidence re-admit IS the new winner — its content must be cached")
    }
}
