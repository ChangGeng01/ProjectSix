// ADR-033 follow-up — Phase 2: the routed memory CONSUMES a durable L8 vector index
// (`BASSQLiteVectorIndexStorage`). `refresh()` loads persisted embeddings (no CoreML re-embed; lazy
// backfill on a miss); the admit path upserts each self-populated atom's embedding so vectors survive
// restart. `retrieve()` stays SYNC over the snapshot (ch883) — the index is touched only in async
// refresh()/drainIntents(). Cosine is scale-invariant, so the (normalized) loaded vector reproduces
// recall; tests assert recall/identity, not byte-equality vs an un-normalized embed.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

#if canImport(CoreML) && !os(iOS)

/// Thread-safe call counter for a sync embedder, so a test can prove `refresh()` did NOT re-embed.
private final class EmbedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func bump() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}

final class BASL8RoutedMemoryServiceVectorIndexTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-vidx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let d = tempDir { try? FileManager.default.removeItem(at: d) }
    }
    private func dbURL(_ name: String) -> URL {
        tempDir.appendingPathComponent("\(name).sqlite")
    }

    private func budget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard, maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 180,
            retrievalDepth: 3, precisionProfile: .protected, deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch, maintenanceAllowed: false)
    }
    private func profile() -> BASHostProfile { BASHostProfile(hostID: "test") }
    private func frame(_ text: String) -> BASDecomposeFrame {
        var f = BASDecomposeFrame(); f.mirrorText = text; return f
    }
    private func selfPopAtom(id: UUID, content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .session, sensitivity: .low,
            tier: .hot, confidence: 0.7, sourceType: BASL8RoutedMemoryService.Parameters.atomSource,
            governanceStatus: .governed, provenanceSummary: "t")
    }
    // Host adapters from BASSQLiteVectorIndexStorage to the two persistence closures.
    private func loadClosure(_ v: BASSQLiteVectorIndexStorage)
        -> @Sendable (String) async -> [Float]? {
        { id in await v.entry(forID: id)?.normalizedEmbedding.vector }
    }
    private func upsertClosure(_ v: BASSQLiteVectorIndexStorage)
        -> @Sendable (String, [Float], String) async -> Void {
        { id, vec, domain in
            _ = try? await v.upsert(BASVectorIndexEntry(
                atomID: id,
                normalizedEmbedding: BASEmbedding(
                    vector: vec, dimension: vec.count, providerVersion: "test").normalized,
                domain: domain))
        }
    }

    // MARK: - refresh() loads the persisted embedding instead of re-embedding

    func testRefreshLoadsPersistedEmbeddingInsteadOfReEmbedding() async throws {
        let vindex = try BASSQLiteVectorIndexStorage(databaseURL: dbURL("vindex"))
        let atomID = UUID()
        let g = selfPopAtom(id: atomID, content: "weather forecast sunny rain clouds")

        // Pre-seed the index with a DISTINCTIVE sentinel (a unit basis vector, NOT lexical(content)).
        let sentinel = (0..<64).map { Float($0 == 7 ? 1.0 : 0.0) }
        _ = try await vindex.upsert(BASVectorIndexEntry(
            atomID: atomID.uuidString,
            normalizedEmbedding: BASEmbedding(vector: sentinel, dimension: 64, providerVersion: "test").normalized,
            domain: BASL8RoutedMemoryService.Parameters.atomSource))

        let counter = EmbedCounter()
        let base = BASL8RoutedMemoryService.lexicalEmbed(dimension: 64)
        let counting: @Sendable (String) -> [Float] = { t in counter.bump(); return base(t) }

        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [g] }, syncEmbed: counting, embeddingDimension: 64,
            loadEmbedding: loadClosure(vindex), upsertEmbedding: upsertClosure(vindex))

        let before = counter.value
        await svc.refresh()
        XCTAssertEqual(counter.value, before,
            "refresh() loaded the persisted embedding — it did NOT call the embedder")
        XCTAssertEqual(svc.snapshotCount, 1)

        let loaded = svc.snapshotEmbedding(forAtomID: atomID.uuidString)
        let expected = BASEmbedding(vector: sentinel, dimension: 64, providerVersion: "test").normalized.vector
        XCTAssertEqual(loaded, expected,
            "the snapshot vector is the persisted sentinel — the index was consumed, not re-embedded")
    }

    // MARK: - empty index ⇒ embed once + backfill; second refresh ⇒ index hit, no re-embed

    func testLazyBackfillUpsertsEmbeddingOnFirstRefresh() async throws {
        let vindex = try BASSQLiteVectorIndexStorage(databaseURL: dbURL("vindex"))
        let g = selfPopAtom(id: UUID(), content: "alpine skiing winter")
        let counter = EmbedCounter()
        let base = BASL8RoutedMemoryService.lexicalEmbed(dimension: 64)
        let counting: @Sendable (String) -> [Float] = { t in counter.bump(); return base(t) }
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [g] }, syncEmbed: counting, embeddingDimension: 64,
            loadEmbedding: loadClosure(vindex), upsertEmbedding: upsertClosure(vindex))

        await svc.refresh()
        XCTAssertEqual(counter.value, 1, "index miss ⇒ embedded once")
        let n1 = await vindex.totalCount
        XCTAssertEqual(n1, 1, "lazy backfill wrote the embedding to the durable index")

        await svc.refresh()
        XCTAssertEqual(counter.value, 1, "index hit on the 2nd refresh ⇒ embedder NOT called again")
    }

    // MARK: - drainIntents upserts each self-populated atom's embedding to the index

    func testDrainUpsertsSelfPopEmbeddingToIndex() async throws {
        let vindex = try BASSQLiteVectorIndexStorage(databaseURL: dbURL("vindex"))
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] },
            syncEmbed: BASL8RoutedMemoryService.lexicalEmbed(dimension: 64),
            embeddingDimension: 64, selfPopulate: true,
            admitAtom: { _ in },                       // no-op admit — this test isolates the embedding upsert
            upsertEmbedding: upsertClosure(vindex))

        _ = svc.retrieve(decomposeFrame: frame("weather sunny today"),
                         hostContext: profile(), budget: budget())
        _ = svc.retrieve(decomposeFrame: frame("quarterly stock market earnings"),
                         hostContext: profile(), budget: budget())
        let drained = await svc.drainIntents()
        XCTAssertEqual(drained.admitted, 2)
        let n = await vindex.totalCount
        XCTAssertEqual(n, 2, "each self-populated atom's embedding was upserted to the durable index")
    }

    // MARK: - reopen the vector index over the SAME file → recall WITHOUT re-embedding (MiniLM)

    func testReopenVectorIndexRecallsWithoutReEmbedding() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let atomsURL = dbURL("atoms")
        let vindexURL = dbURL("vindex")

        // "Process 1": file-backed atom store + vector index; self-pop + drain (embeddings written).
        do {
            let store1 = try BASSQLiteMemoryAtomStore(databaseURL: atomsURL)
            let vindex1 = try BASSQLiteVectorIndexStorage(databaseURL: vindexURL)
            let svc1 = BASL8RoutedMemoryService(
                loadAllAtoms: { (try? await store1.allAtoms()) ?? [] },
                syncEmbed: mini.syncEmbedClosure(), embeddingDimension: 384,
                atomStore: store1, selfPopulate: true,
                admitAtom: { _ = try? await store1.admit($0) },
                loadEmbedding: loadClosure(vindex1), upsertEmbedding: upsertClosure(vindex1))
            _ = svc1.retrieve(decomposeFrame: frame("alpine skiing in deep winter snow"),
                              hostContext: profile(), budget: budget())
            _ = svc1.retrieve(decomposeFrame: frame("ocean scuba diving on the coral reef"),
                              hostContext: profile(), budget: budget())
            let drained = await svc1.drainIntents()
            XCTAssertEqual(drained.admitted, 2)
            let vc = await vindex1.totalCount
            XCTAssertEqual(vc, 2, "both embeddings written to the durable index")
        }   // store1 + vindex1 + svc1 deallocate (files closed)

        // "Process 2": NEW stores over the SAME files + a COUNTING MiniLM; refresh must load, not embed.
        let store2 = try BASSQLiteMemoryAtomStore(databaseURL: atomsURL)
        let vindex2 = try BASSQLiteVectorIndexStorage(databaseURL: vindexURL)
        let counter = EmbedCounter()
        let miniClosure = mini.syncEmbedClosure()
        let countingMini: @Sendable (String) -> [Float] = { t in counter.bump(); return miniClosure(t) }
        let svc2 = BASL8RoutedMemoryService(
            loadAllAtoms: { (try? await store2.allAtoms()) ?? [] },
            syncEmbed: countingMini, embeddingDimension: 384,
            loadEmbedding: loadClosure(vindex2))

        await svc2.refresh()
        XCTAssertEqual(counter.value, 0,
            "refresh() loaded all embeddings from the durable index — ZERO CoreML re-embeds across restart")
        XCTAssertEqual(svc2.snapshotCount, 2)

        let recalled = svc2.retrieve(
            decomposeFrame: frame("winter mountain snow sports"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(recalled.atoms.first?.summary, "alpine skiing in deep winter snow",
            "recall reproduces from disk-loaded vectors (skiing, not diving)")
    }
}
#endif
