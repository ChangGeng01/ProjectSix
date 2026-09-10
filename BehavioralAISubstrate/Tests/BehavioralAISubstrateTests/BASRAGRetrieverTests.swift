// MARK: - BASRAGRetrieverTests — chapter 三百六三 / M850
//
// Test coverage for G4 part 3: typed RAG retrieval facade
// composing embedding provider + vector index + reranker +
// atom lookup。
//
// Tests verify:
//   - Empty query → empty result + emits empty-query reason code
//   - Empty index → empty result + no-candidates reason code
//   - Happy path: query → embed → topK → rerank → atom lookup
//     produces ordered atoms + scores + reason codes
//   - Stale entries (vector index has ID but atomLookup returns
//     nil) accumulate in staleAtomIDs
//   - excludingDomains parameter filters at index stage
//   - Reranker version + provider version + k value emitted
//     in reason codes
//   - End-to-end with default identity reranker preserves score
//     order from index

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASRAGRetrieverTests: XCTestCase {

    // MARK: - Fixtures

    private func makeAtom(id: String) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: id,
            summary: "test summary for \(id)",
            contentType: .hot,
            source: "test",
            confidence: 0.8,
            conflictFingerprint: id)
    }

    private func makeIndexEntry(
        atomID: String,
        vector: [Float],
        domain: String = "user.notes"
    ) -> BASVectorIndexEntry {
        let embedding = BASEmbedding(
            vector: vector,
            dimension: vector.count,
            providerVersion: "test-v1")
        return BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding.normalized,
            domain: domain)
    }

    // MARK: - Defensive cases

    func testEmptyQueryReturnsEmpty() async {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        let result = await BASRAGRetriever.retrieve(
            queryText: "",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { _ in nil })
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:empty-query"))
    }

    func testWhitespaceOnlyQueryReturnsEmpty() async {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        let result = await BASRAGRetriever.retrieve(
            queryText: "   \n\t   ",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { _ in nil })
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertTrue(
            result.reasonCodes.contains("rag:empty-query"))
    }

    func testEmptyIndexReturnsNoCandidates() async {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()  // empty
        let result = await BASRAGRetriever.retrieve(
            queryText: "any query",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { _ in nil })
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:no-candidates"))
    }

    // MARK: - Happy path

    func testHappyPathProducesOrderedAtoms() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        // Insert 3 entries
        for atomID in ["a", "b", "c"] {
            let embedding = await provider.embed(atomID)
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: embedding.normalized,
                domain: "user.notes"))
        }
        // Query with same text as one of the atoms — that atom
        // should win top-k
        let atomLookup: @Sendable (String) async
            -> BASMemoryAtom? = { id in
            BASMemoryAtom(
                memoryID: id,
                summary: "summary of \(id)",
                contentType: .hot,
                source: "test",
                confidence: 0.8,
                conflictFingerprint: id)
        }
        let result = await BASRAGRetriever.retrieve(
            queryText: "a",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: atomLookup,
            k: 3)
        XCTAssertEqual(result.atoms.count, 3)
        XCTAssertEqual(
            result.atoms.first?.memoryID, "a",
            "Same-text query should match its own atom first " +
            "(deterministic stub embedding)")
        XCTAssertTrue(
            result.scores.keys.contains("a"))
        XCTAssertTrue(result.staleAtomIDs.isEmpty)
        // Reason codes carry provider + reranker + k
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:provider:" +
                BASStubEmbeddingProvider.defaultVersion))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:reranker:" +
                BASIdentityVectorReranker.defaultVersion))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:k:3"))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:resolved:3"))
    }

    // MARK: - Stale entries

    func testStaleEntriesAccumulateWhenAtomLookupReturnsNil()
        async throws
    {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        for atomID in ["found-1", "stale-1", "stale-2"] {
            let e = await provider.embed(atomID)
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: e.normalized,
                domain: "test"))
        }
        // Lookup only resolves "found-1"
        let result = await BASRAGRetriever.retrieve(
            queryText: "any",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { id in
                id == "found-1"
                    ? BASMemoryAtom(
                        memoryID: id,
                        summary: id,
                        contentType: .hot,
                        source: "test",
                        confidence: 0.5,
                        conflictFingerprint: id)
                    : nil
            },
            k: 5)
        XCTAssertEqual(result.atoms.count, 1)
        XCTAssertEqual(result.staleAtomIDs.count, 2)
        XCTAssertTrue(
            result.staleAtomIDs.contains("stale-1"))
        XCTAssertTrue(
            result.staleAtomIDs.contains("stale-2"))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:stale:2"))
        XCTAssertTrue(
            result.reasonCodes.contains("rag:resolved:1"))
    }

    // MARK: - excludingDomains composition

    func testExcludingDomainsFiltersAtIndexStage() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        let atomDomains = [
            "medical-1": "user.medical_records",
            "notes-1": "user.notes",
            "financial-1": "user.financial.bank"
        ]
        for (atomID, domain) in atomDomains {
            let e = await provider.embed(atomID)
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: e.normalized,
                domain: domain))
        }
        let result = await BASRAGRetriever.retrieve(
            queryText: "any",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { id in
                BASMemoryAtom(
                    memoryID: id,
                    summary: id,
                    contentType: .hot,
                    source: "test",
                    confidence: 0.5,
                    conflictFingerprint: id)
            },
            k: 5,
            excludingDomains: [
                "medical", "financial"])
        XCTAssertEqual(result.atoms.count, 1)
        XCTAssertEqual(
            result.atoms.first?.memoryID, "notes-1",
            "Only the non-restricted domain should pass " +
            "through to the result")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:excluded-domains:2"))
    }

    // MARK: - candidateContextBuilder propagation

    /// Custom reranker that records which contexts it received。
    /// Used to verify the contextBuilder closure threads through。
    private actor CtxCapturingReranker: BASVectorReranker {
        nonisolated let rerankerVersion: String =
            "ctx-test-v1"
        var capturedContexts: [String: String] = [:]

        func rerank(
            query: BASEmbedding,
            candidates: [BASVectorTopKResult],
            candidateContext: [String: String]
        ) async -> [BASVectorTopKResult] {
            capturedContexts = candidateContext
            return candidates
        }
    }

    func testContextBuilderThreadsToReranker() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let index = BASVectorIndex()
        for atomID in ["x", "y"] {
            let e = await provider.embed(atomID)
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: e.normalized))
        }
        let reranker = CtxCapturingReranker()
        _ = await BASRAGRetriever.retrieve(
            queryText: "query",
            embeddingProvider: provider,
            vectorIndex: index,
            reranker: reranker,
            atomLookup: { _ in nil },  // all stale, that's fine
            k: 2,
            candidateContextBuilder: { id in
                "context-for-\(id)"
            })
        let captured = await reranker.capturedContexts
        XCTAssertEqual(
            captured["x"], "context-for-x")
        XCTAssertEqual(
            captured["y"], "context-for-y")
    }

    // MARK: - Identity reranker preserves score order

    func testIdentityRerankerPreservesIndexOrder()
        async throws
    {
        let provider = BASStubEmbeddingProvider(dimension: 32)
        let index = BASVectorIndex()
        // Insert with intentionally ordered scores: highest
        // similarity wins
        let texts = ["first match", "second related",
                     "third unrelated"]
        for text in texts {
            let e = await provider.embed(text)
            try await index.insert(BASVectorIndexEntry(
                atomID: text,
                normalizedEmbedding: e.normalized))
        }
        let result = await BASRAGRetriever.retrieve(
            queryText: "first match",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: { id in
                BASMemoryAtom(
                    memoryID: id,
                    summary: id,
                    contentType: .hot,
                    source: "test",
                    confidence: 0.5,
                    conflictFingerprint: id)
            },
            k: 3)
        // Identity reranker preserves order; same-text atom
        // wins
        XCTAssertEqual(
            result.atoms.first?.memoryID,
            "first match")
    }

    // MARK: - Constants pin

    func testDefaultTopKPin() {
        XCTAssertEqual(BASRAGRetriever.defaultTopK, 10,
            "Default top-k pin (anti-magic-number)")
    }

    func testReasonCodePrefixPin() {
        XCTAssertEqual(
            BASRAGRetriever.reasonCodePrefix, "rag",
            "Reason code prefix pin (chapter 八十七 raw value " +
            "stability — audit walkers grep this)")
    }

    // MARK: - End-to-end M847 + M849 + M850 composition

    /// **Architectural pin** — full G4 stack composes:
    /// SQLite-backed storage + in-memory index + RAG retriever。
    /// Closes G4 end-to-end per M840 §3.4。
    func testEndToEndSQLitePersistencePlusRAGRetrieval()
        async throws
    {
        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-rag-e2e-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath:
                    tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath:
                    tempURL.path + "-shm"))
        }
        let provider = BASStubEmbeddingProvider(dimension: 32)
        // Session 1: populate SQLite + verify retrieval works
        do {
            let storage = try BASSQLiteVectorIndexStorage(
                databaseURL: tempURL)
            let index = BASVectorIndex()
            for atomID in ["alpha", "beta", "gamma"] {
                let e = await provider.embed(atomID)
                let entry = BASVectorIndexEntry(
                    atomID: atomID,
                    normalizedEmbedding: e.normalized,
                    domain: "user.notes")
                try await index.insert(entry)
                _ = try await storage.upsert(entry)
            }
            let result = await BASRAGRetriever.retrieve(
                queryText: "alpha",
                embeddingProvider: provider,
                vectorIndex: index,
                atomLookup: { id in
                    BASMemoryAtom(
                        memoryID: id,
                        summary: id,
                        contentType: .hot,
                        source: "test",
                        confidence: 0.5,
                        conflictFingerprint: id)
                })
            XCTAssertEqual(
                result.atoms.first?.memoryID, "alpha")
        }
        // Session 2: reopen SQLite, preload to fresh index,
        // verify retrieval still works
        let storage = try BASSQLiteVectorIndexStorage(
            databaseURL: tempURL)
        let restoredIndex = BASVectorIndex()
        let loaded = await storage.preload(
            into: restoredIndex)
        XCTAssertEqual(loaded, 3,
            "All 3 entries must preload from SQLite")
        let restoredResult = await BASRAGRetriever.retrieve(
            queryText: "beta",
            embeddingProvider: provider,
            vectorIndex: restoredIndex,
            atomLookup: { id in
                BASMemoryAtom(
                    memoryID: id,
                    summary: id,
                    contentType: .hot,
                    source: "test",
                    confidence: 0.5,
                    conflictFingerprint: id)
            })
        XCTAssertEqual(
            restoredResult.atoms.first?.memoryID, "beta",
            "RAG retrieval must work on the preloaded index " +
            "(end-to-end SQLite persistence pin)")
    }
}
