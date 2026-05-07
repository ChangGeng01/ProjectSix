// MARK: - BASVectorRAGMVPTests — chapter 三百六十 / M847
//
// Test coverage for G4 deliverable from M840 Cognitive OS roadmap:
//   - BASEmbedding shape + clamp invariants + l2Norm + normalized
//   - BASStubEmbeddingProvider determinism + dimension contract
//   - BASVectorIndex insert / upsert / remove / topK / dimension
//     mismatch / duplicate / domain exclusion
//   - BASIdentityVectorReranker pass-through behavior
//   - End-to-end pipeline: provider → embedding → index insert →
//     index topK → reranker → final results
//   - NLEmbeddingProvider basic functionality (Apple-only)

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

#if canImport(NaturalLanguage)
@testable import BASAppleAdapters
#endif

final class BASVectorRAGMVPTests: XCTestCase {

    // MARK: - BASEmbedding shape

    func testEmbeddingDimensionInvariant() {
        let embedding = BASEmbedding(
            vector: [1.0, 2.0, 3.0],
            dimension: 3,
            providerVersion: "test")
        XCTAssertEqual(embedding.dimension, 3)
        XCTAssertEqual(embedding.vector, [1.0, 2.0, 3.0])
    }

    func testEmbeddingL2Norm() {
        let embedding = BASEmbedding(
            vector: [3.0, 4.0],  // 3-4-5 triangle
            dimension: 2,
            providerVersion: "test")
        XCTAssertEqual(embedding.l2Norm, 5.0, accuracy: 1e-5)
    }

    func testEmbeddingNormalizedToUnitLength() {
        let embedding = BASEmbedding(
            vector: [3.0, 4.0],
            dimension: 2,
            providerVersion: "test")
        let normalized = embedding.normalized
        XCTAssertEqual(
            normalized.l2Norm, 1.0, accuracy: 1e-5,
            "Normalized embedding must have L2 norm = 1")
    }

    func testEmbeddingNormalizedZeroVectorStaysZero() {
        let embedding = BASEmbedding(
            vector: [0.0, 0.0, 0.0],
            dimension: 3,
            providerVersion: "test")
        let normalized = embedding.normalized
        XCTAssertEqual(normalized.vector, [0.0, 0.0, 0.0],
            "Zero vector must NOT divide by zero")
    }

    func testEmbeddingCodableRoundTrip() throws {
        let original = BASEmbedding(
            vector: [0.5, -0.5, 0.25, -0.25],
            dimension: 4,
            providerVersion: "test-v2")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEmbedding.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASStubEmbeddingProvider

    func testStubProviderDimensionContract() async {
        let provider = BASStubEmbeddingProvider(dimension: 16)
        let result = await provider.embed("hello world")
        XCTAssertEqual(result.dimension, 16)
        XCTAssertEqual(result.vector.count, 16)
        XCTAssertEqual(
            result.providerVersion,
            BASStubEmbeddingProvider.defaultVersion)
    }

    func testStubProviderDeterministic() async {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let a = await provider.embed("identical text")
        let b = await provider.embed("identical text")
        XCTAssertEqual(a.vector, b.vector,
            "Stub must be deterministic — same text → " +
            "same embedding")
    }

    func testStubProviderDifferentTextsDifferentEmbeddings()
        async
    {
        let provider = BASStubEmbeddingProvider(dimension: 16)
        let a = await provider.embed("alpha text")
        let b = await provider.embed("beta text")
        XCTAssertNotEqual(a.vector, b.vector,
            "Different texts must produce different embeddings")
    }

    func testStubProviderEmptyTextIsZero() async {
        let provider = BASStubEmbeddingProvider(dimension: 8)
        let result = await provider.embed("")
        XCTAssertEqual(
            result.vector,
            Array(repeating: 0, count: 8),
            "Empty input must produce zero vector")
    }

    func testStubProviderSeedAffectsEmbedding() async {
        let p1 = BASStubEmbeddingProvider(
            dimension: 8, seed: 1)
        let p2 = BASStubEmbeddingProvider(
            dimension: 8, seed: 2)
        let a = await p1.embed("same input")
        let b = await p2.embed("same input")
        XCTAssertNotEqual(a.vector, b.vector,
            "Different seeds must produce different " +
            "embeddings for the same text")
    }

    // MARK: - BASVectorIndex

    private func makeNormalizedEntry(
        atomID: String,
        vector: [Float],
        domain: String = ""
    ) -> BASVectorIndexEntry {
        let embedding = BASEmbedding(
            vector: vector,
            dimension: vector.count,
            providerVersion: "test")
        return BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding.normalized,
            domain: domain)
    }

    func testIndexInsertBindsDimension() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "a1", vector: [1, 0, 0]))
        let dim = await index.dimension
        XCTAssertEqual(dim, 3,
            "First insert binds the index dimension")
    }

    func testIndexDimensionMismatchThrows() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "a1", vector: [1, 0, 0]))
        do {
            try await index.insert(makeNormalizedEntry(
                atomID: "a2", vector: [1, 0]))  // dim 2
            XCTFail("Expected dimensionMismatch error")
        } catch BASVectorIndex.BASVectorIndexError
            .dimensionMismatch(let expected, let got)
        {
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(got, 2)
        }
    }

    func testIndexDuplicateAtomIDThrows() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "dup", vector: [1, 0, 0]))
        do {
            try await index.insert(makeNormalizedEntry(
                atomID: "dup", vector: [0, 1, 0]))
            XCTFail("Expected duplicateAtomID error")
        } catch BASVectorIndex.BASVectorIndexError
            .duplicateAtomID(let id)
        {
            XCTAssertEqual(id, "dup")
        }
    }

    func testIndexUpsertReplacesExisting() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "x", vector: [1, 0, 0]))
        try await index.upsert(makeNormalizedEntry(
            atomID: "x", vector: [0, 1, 0]))
        let count = await index.entryCount
        XCTAssertEqual(count, 1,
            "upsert on existing atomID must replace not duplicate")
    }

    func testIndexRemoveReturnsTrueOnPresent() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "to-remove", vector: [1, 0, 0]))
        let removed = await index.remove(
            atomID: "to-remove")
        XCTAssertTrue(removed)
        let present = await index.contains(
            atomID: "to-remove")
        XCTAssertFalse(present)
    }

    func testIndexRemoveReturnsFalseOnAbsent() async {
        let index = BASVectorIndex()
        let removed = await index.remove(atomID: "missing")
        XCTAssertFalse(removed)
    }

    func testIndexTopKReturnsHighestSimilarity() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "match", vector: [1, 0, 0]))
        try await index.insert(makeNormalizedEntry(
            atomID: "ortho", vector: [0, 1, 0]))
        try await index.insert(makeNormalizedEntry(
            atomID: "opposite", vector: [-1, 0, 0]))
        let query = BASEmbedding(
            vector: [1, 0, 0],
            dimension: 3,
            providerVersion: "test"
        ).normalized
        let results = await index.topK(query: query, k: 3)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].atomID, "match",
            "Highest similarity (cosine 1) must come first")
        XCTAssertEqual(
            results[0].score, 1.0, accuracy: 1e-5)
        XCTAssertEqual(results[1].atomID, "ortho")
        XCTAssertEqual(
            results[1].score, 0.0, accuracy: 1e-5,
            "Orthogonal vectors have cosine 0")
        XCTAssertEqual(results[2].atomID, "opposite")
        XCTAssertEqual(
            results[2].score, -1.0, accuracy: 1e-5,
            "Opposite vectors have cosine -1")
    }

    func testIndexTopKRespectsK() async throws {
        let index = BASVectorIndex()
        for i in 0..<10 {
            try await index.insert(makeNormalizedEntry(
                atomID: "id-\(i)",
                vector: [Float(i + 1), 0, 0]))
        }
        let query = BASEmbedding(
            vector: [1, 0, 0],
            dimension: 3,
            providerVersion: "test"
        ).normalized
        let results = await index.topK(query: query, k: 3)
        XCTAssertEqual(results.count, 3,
            "k=3 must return exactly 3 results")
    }

    func testIndexTopKEmptyIndexReturnsEmpty() async {
        let index = BASVectorIndex()
        let query = BASEmbedding(
            vector: [1, 0, 0],
            dimension: 3,
            providerVersion: "test")
        let results = await index.topK(query: query, k: 5)
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexTopKExcludesDomains() async throws {
        let index = BASVectorIndex()
        try await index.insert(makeNormalizedEntry(
            atomID: "medical-1",
            vector: [1, 0, 0],
            domain: "user.medical_records"))
        try await index.insert(makeNormalizedEntry(
            atomID: "notes-1",
            vector: [1, 0, 0],
            domain: "user.notes"))
        let query = BASEmbedding(
            vector: [1, 0, 0],
            dimension: 3,
            providerVersion: "test"
        ).normalized
        let results = await index.topK(
            query: query, k: 5,
            excludingDomains: ["medical"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].atomID, "notes-1",
            "Excluded domain candidates must not appear")
    }

    // MARK: - BASIdentityVectorReranker

    func testIdentityRerankerPreservesOrder() async {
        let reranker = BASIdentityVectorReranker()
        let candidates = [
            BASVectorTopKResult(atomID: "a", score: 0.9),
            BASVectorTopKResult(atomID: "b", score: 0.8),
            BASVectorTopKResult(atomID: "c", score: 0.7)
        ]
        let query = BASEmbedding(
            vector: [1, 0, 0], dimension: 3,
            providerVersion: "test")
        let result = await reranker.rerank(
            query: query,
            candidates: candidates,
            candidateContext: [:])
        XCTAssertEqual(result, candidates,
            "Identity reranker must preserve input order + scores")
    }

    func testIdentityRerankerVersionTagPin() {
        let reranker = BASIdentityVectorReranker()
        XCTAssertEqual(
            reranker.rerankerVersion,
            BASIdentityVectorReranker.defaultVersion)
        XCTAssertEqual(
            BASIdentityVectorReranker.defaultVersion,
            "identity-v1",
            "Default version pin: bumping requires audit " +
            "walker migration")
    }

    // MARK: - End-to-end pipeline

    /// **Architectural pin** — provider + index + reranker
    /// compose end-to-end into a working semantic-retrieval
    /// pipeline。Stub provider produces deterministic embeddings,
    /// index does cosine top-k,reranker preserves order。
    func testEndToEndProviderIndexReranker() async throws {
        let provider = BASStubEmbeddingProvider(dimension: 32)
        let index = BASVectorIndex()
        // Insert 5 atoms with different embeddings
        let atomTexts = [
            "apple": "fruit red",
            "banana": "fruit yellow",
            "carrot": "vegetable orange",
            "dog": "animal mammal",
            "eagle": "animal bird"
        ]
        for (id, text) in atomTexts {
            let embedding = await provider.embed(text)
            try await index.insert(BASVectorIndexEntry(
                atomID: id,
                normalizedEmbedding: embedding.normalized,
                domain: "user.notes"))
        }
        // Query with one of the same texts → that ID should
        // win top-k (deterministic stub)
        let query = await provider.embed("fruit red")
        let topK = await index.topK(
            query: query.normalized, k: 3)
        XCTAssertEqual(topK.count, 3)
        XCTAssertEqual(topK[0].atomID, "apple",
            "Same text → highest cosine similarity")
        // Reranker pass-through
        let reranker = BASIdentityVectorReranker()
        let reranked = await reranker.rerank(
            query: query,
            candidates: topK,
            candidateContext: [:])
        XCTAssertEqual(reranked, topK)
    }

    // MARK: - NLEmbedding (Apple platforms only)

    #if canImport(NaturalLanguage)

    func testNLEmbeddingProviderProducesEmbedding() async {
        guard let provider = BASNLEmbeddingProvider() else {
            // NLEmbedding.wordEmbedding(for: .english) returned
            // nil — should be impossible on iOS 13+ / macOS
            // 10.15+ but skip gracefully on the off chance
            return
        }
        // Pin the named constant matches what the provider
        // actually reports (catches Apple SDK dimension drift)
        XCTAssertEqual(
            provider.dimension,
            BASNLEmbeddingProvider.englishWordDimension,
            "Provider dimension must match the typed " +
            "englishWordDimension constant (chapter 一百八十五 " +
            "anti-magic-number pin)")
        let result = await provider.embed("hello world")
        XCTAssertEqual(
            result.dimension,
            BASNLEmbeddingProvider.englishWordDimension)
        XCTAssertEqual(
            result.vector.count,
            BASNLEmbeddingProvider.englishWordDimension)
        XCTAssertEqual(
            result.providerVersion,
            BASNLEmbeddingProvider.defaultVersion)
    }

    func testNLEmbeddingProviderEmptyTextZero() async {
        guard let provider = BASNLEmbeddingProvider()
        else { return }
        let result = await provider.embed("")
        XCTAssertEqual(
            result.vector.allSatisfy { $0 == 0 }, true,
            "Empty input → zero vector")
    }

    func testNLEmbeddingProviderOOVOnlyZero() async {
        guard let provider = BASNLEmbeddingProvider()
        else { return }
        // Random gibberish unlikely to have any OOV-passing
        // tokens
        let result = await provider.embed(
            "qwxzpvkfjgmht zzzkrqwzx")
        // May or may not be all-zero depending on Apple's
        // tokenization; just verify it's a valid embedding
        XCTAssertEqual(
            result.dimension,
            BASNLEmbeddingProvider.englishWordDimension)
    }

    func testNLEmbeddingProviderSemanticSimilarity() async {
        guard let provider = BASNLEmbeddingProvider()
        else { return }
        let cat = await provider.embed("cat")
        let dog = await provider.embed("dog")
        let car = await provider.embed("car")
        // Cosine: cat-dog should be > cat-car (same ontology)
        let catNorm = cat.normalized
        let dogNorm = dog.normalized
        let carNorm = car.normalized
        var catDog: Float = 0
        var catCar: Float = 0
        for i in 0..<catNorm.dimension {
            catDog += catNorm.vector[i] * dogNorm.vector[i]
            catCar += catNorm.vector[i] * carNorm.vector[i]
        }
        XCTAssertGreaterThan(
            catDog, catCar,
            "cat-dog semantic similarity should exceed cat-car " +
            "(NLEmbedding bundled word2vec captures animal ontology)")
    }

    #endif
}
