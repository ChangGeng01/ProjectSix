// MARK: - BASChapter886SyncResolveCandidatesTests
// chapter 八百八十六 / M3120 — chapter 883 Trigger C path: sync
// resolution helper for RAG Stage 4
//
// Context: chapter 883 DECLINED wiring the full async
// `BASRAGRetriever.retrieve(...)` through
// `BASHostRuntimeEBrainMemoryService.retrieve()` because that
// substrate contract is sync。 Trigger C said 「BASRAGRetriever
// ships a SYNC variant」 — chapter 886 ships that variant as the
// sync Stage 4 (atom-ID → atom materialization) helper。
//
// Caller is responsible for Stages 1-3 (embed async + topK async
// + rerank async)。 Stage 4 is the sync atom-ID resolution that
// the substrate's sync MemoryService.retrieve() CAN now call。
//
// Chapter 887 wires this through MemoryService。

import XCTest
@testable import BASMemory

final class BASChapter886SyncResolveCandidatesTests:
    XCTestCase
{

    /// Make a deterministic candidate list for tests。
    private func makeCandidates(
        _ ids: [String], baseScore: Float = 0.9
    ) -> [BASVectorTopKResult] {
        return ids.enumerated().map { i, id in
            BASVectorTopKResult(
                atomID: id,
                score: baseScore - Float(i) * 0.05)
        }
    }

    private func makeAtom(_ id: String) -> BASMemoryAtom {
        return BASMemoryAtom(
            memoryID: id,
            summary: "summary-\(id)",
            contentType: .hot,
            source: "test",
            confidence: 0.8,
            conflictFingerprint: "fp-\(id)")
    }

    // MARK: - Stage 4 sync resolution

    func testResolveCandidatesPopulatesAtomsAndScores() {
        let candidates = makeCandidates(
            ["a", "b", "c"])
        let atomMap: [String: BASMemoryAtom] = [
            "a": makeAtom("a"),
            "b": makeAtom("b"),
            "c": makeAtom("c"),
        ]
        let result = BASRAGRetriever
            .resolveCandidatesSync(
                candidates: candidates,
                atomLookupSync: { atomMap[$0] },
                k: 10)
        XCTAssertEqual(result.atoms.count, 3,
            "All 3 candidates must resolve")
        XCTAssertEqual(
            result.atoms.map(\.memoryID),
            ["a", "b", "c"],
            "Atom order must match candidate order")
        XCTAssertEqual(result.scores["a"] ?? 0,
            Float(0.9), accuracy: Float(1e-6))
        XCTAssertEqual(result.scores["b"] ?? 0,
            Float(0.85), accuracy: Float(1e-6))
        XCTAssertEqual(result.staleAtomIDs, [],
            "No stale atoms when all map entries hit")
    }

    func testStaleAtomIDsCapturedWhenLookupReturnsNil() {
        let candidates = makeCandidates(
            ["a", "missing", "c"])
        let atomMap: [String: BASMemoryAtom] = [
            "a": makeAtom("a"),
            "c": makeAtom("c"),
        ]
        let result = BASRAGRetriever
            .resolveCandidatesSync(
                candidates: candidates,
                atomLookupSync: { atomMap[$0] },
                k: 10)
        XCTAssertEqual(result.atoms.count, 2,
            "Only mapped candidates resolve")
        XCTAssertEqual(result.staleAtomIDs, ["missing"],
            "Missing candidate ID lands in staleAtomIDs")
        XCTAssertEqual(
            result.atoms.map(\.memoryID),
            ["a", "c"],
            "Stale candidate filtered from atoms array")
    }

    func testKLimitTruncatesCandidates() {
        let candidates = makeCandidates(
            ["a", "b", "c", "d", "e"])
        let atomMap: [String: BASMemoryAtom] = [
            "a": makeAtom("a"), "b": makeAtom("b"),
            "c": makeAtom("c"), "d": makeAtom("d"),
            "e": makeAtom("e"),
        ]
        let result = BASRAGRetriever
            .resolveCandidatesSync(
                candidates: candidates,
                atomLookupSync: { atomMap[$0] },
                k: 2)
        XCTAssertEqual(result.atoms.count, 2,
            "k=2 must truncate to first 2 candidates")
        XCTAssertEqual(
            result.atoms.map(\.memoryID),
            ["a", "b"],
            "First 2 candidates kept (highest scores)")
    }

    func testEmptyCandidatesProducesEmptyResult() {
        let result = BASRAGRetriever
            .resolveCandidatesSync(
                candidates: [],
                atomLookupSync: { _ in nil },
                k: 10)
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertTrue(result.scores.isEmpty)
        XCTAssertTrue(result.staleAtomIDs.isEmpty)
        XCTAssertTrue(
            result.reasonCodes.contains(where: {
                $0.contains("no-candidates")
            }),
            "Empty candidates must emit no-candidates " +
            "reason code")
    }

    // MARK: - Reason codes

    func testReasonCodesEmittedInExpectedShape() {
        let candidates = makeCandidates(
            ["a", "stale"])
        let result = BASRAGRetriever
            .resolveCandidatesSync(
                candidates: candidates,
                atomLookupSync: {
                    $0 == "a" ? self.makeAtom("a") : nil
                },
                k: 10,
                extraReasonCodes: [
                    "rag:host-context:foo"
                ])
        // Standard shape
        XCTAssertTrue(
            result.reasonCodes.contains("rag:sync-resolve"))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:k:10"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:host-context:foo"),
            "extraReasonCodes must propagate")
        XCTAssertTrue(
            result.reasonCodes.contains("rag:resolved:1"))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:stale:1"))
    }

    // MARK: - Determinism (byte-equality with same inputs)

    func testDeterministicAcrossInvocations() {
        let candidates = makeCandidates(
            ["alpha", "beta", "gamma"])
        let atomMap: [String: BASMemoryAtom] = [
            "alpha": makeAtom("alpha"),
            "beta": makeAtom("beta"),
            "gamma": makeAtom("gamma"),
        ]
        let r1 = BASRAGRetriever.resolveCandidatesSync(
            candidates: candidates,
            atomLookupSync: { atomMap[$0] },
            k: 5)
        let r2 = BASRAGRetriever.resolveCandidatesSync(
            candidates: candidates,
            atomLookupSync: { atomMap[$0] },
            k: 5)
        XCTAssertEqual(r1.atoms.map(\.memoryID),
            r2.atoms.map(\.memoryID),
            "Two invocations with same input must be " +
            "byte-equal in atoms")
        XCTAssertEqual(r1.scores, r2.scores,
            "Score maps byte-equal")
        XCTAssertEqual(r1.staleAtomIDs, r2.staleAtomIDs,
            "Stale IDs byte-equal")
        XCTAssertEqual(r1.reasonCodes, r2.reasonCodes,
            "Reason codes byte-equal")
    }
}
