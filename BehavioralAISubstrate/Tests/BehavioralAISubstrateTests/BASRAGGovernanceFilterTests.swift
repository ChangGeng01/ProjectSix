import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

// File-scope helpers so the @Sendable atomLookup closures never capture the
// (non-Sendable) XCTestCase.
private func makeGoverned(_ atomID: String, _ status: BASMemoryGovernanceStatus) -> BASGovernedMemory {
    BASGovernedMemory(
        id: UUID(), kind: .episodic, content: atomID, scope: .session,
        sensitivity: .low, tier: .warm, confidence: 0.8, sourceType: "test",
        governanceStatus: status, provenanceSummary: "t")
}
// adapt sets memoryID = content = the atomID, so results are identifiable.
private let adaptGoverned: @Sendable (BASGovernedMemory) -> BASMemoryAtom = { g in
    BASMemoryAtom(
        memoryID: g.content, summary: g.content, contentType: .hot,
        source: "test", confidence: g.confidence, conflictFingerprint: g.content)
}

/// audit memory-a F3 — a QUARANTINED (isolated) atom keeps its embedding in
/// the vector index (quarantine is REVERSIBLE — the atom REMAINS), so
/// cosineTopK still returns its ID. The naive documented atomLookup
/// (`{ id in atomStore.atom(forID: id) }`) would then bring the isolated
/// CONTENT back into L2. `BASRAGRetriever.governedAtomLookup` gates it out at
/// the lookup boundary (the only place governance is still known) while
/// leaving the embedding in place so a released atom recalls again.
final class BASRAGGovernanceFilterTests: XCTestCase {

    /// Two atoms with the SAME embedding as the query (both recall).
    private func makeIndexWithBoth(_ provider: BASStubEmbeddingProvider) async throws -> BASVectorIndex {
        let index = BASVectorIndex()
        for atomID in ["governed-1", "quarantined-1"] {
            let emb = await provider.embed("q")
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID, normalizedEmbedding: emb.normalized, domain: "user.notes"))
        }
        return index
    }

    func testGovernedAtomLookupExcludesQuarantinedFromRAG() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = try await makeIndexWithBoth(provider)
        let statuses: [String: BASMemoryGovernanceStatus] =
            ["governed-1": .governed, "quarantined-1": .quarantined]
        let lookup = BASRAGRetriever.governedAtomLookup(
            resolve: { id in statuses[id].map { makeGoverned(id, $0) } },
            adapt: adaptGoverned)
        let result = await BASRAGRetriever.retrieve(
            queryText: "q", embeddingProvider: provider,
            vectorIndex: index, atomLookup: lookup, k: 5)

        XCTAssertEqual(result.atoms.map(\.memoryID), ["governed-1"],
            "only the .governed atom is materialized into L2")
        XCTAssertTrue(result.staleAtomIDs.contains("quarantined-1"),
            "the quarantined ID is returned by the index but gated out ⇒ stale (embedding stays)")
        XCTAssertFalse(result.staleAtomIDs.contains("governed-1"))
    }

    /// Reversibility: releasing quarantine (→ .governed) recalls again —
    /// proving the embedding was NEVER removed from the index.
    func testReleasingQuarantineRestoresRecall() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = try await makeIndexWithBoth(provider)
        let lookup = BASRAGRetriever.governedAtomLookup(
            resolve: { id in ["governed-1", "quarantined-1"].contains(id)
                ? makeGoverned(id, .governed) : nil },
            adapt: adaptGoverned)
        let result = await BASRAGRetriever.retrieve(
            queryText: "q", embeddingProvider: provider,
            vectorIndex: index, atomLookup: lookup, k: 5)
        XCTAssertEqual(Set(result.atoms.map(\.memoryID)), ["governed-1", "quarantined-1"],
            "a released atom recalls again — the embedding was never removed (reversible)")
        XCTAssertTrue(result.staleAtomIDs.isEmpty)
    }

    /// The pre-fix leak, for contrast: the NAIVE lookup (no `.governed` gate)
    /// materializes the quarantined atom into L2 — the exact F3 bug that
    /// governedAtomLookup prevents.
    func testNaiveLookupLeaksQuarantinedContent() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = try await makeIndexWithBoth(provider)
        let statuses: [String: BASMemoryGovernanceStatus] =
            ["governed-1": .governed, "quarantined-1": .quarantined]
        let naive: @Sendable (String) async -> BASMemoryAtom? = { id in
            statuses[id].map { adaptGoverned(makeGoverned(id, $0)) }
        }
        let result = await BASRAGRetriever.retrieve(
            queryText: "q", embeddingProvider: provider,
            vectorIndex: index, atomLookup: naive, k: 5)
        XCTAssertTrue(result.atoms.contains { $0.memoryID == "quarantined-1" },
            "the naive lookup LEAKS the quarantined atom's content into L2 — the exact F3 bug")
    }
}
