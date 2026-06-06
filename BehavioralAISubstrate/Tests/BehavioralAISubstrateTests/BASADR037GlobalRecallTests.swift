// ADR-037 — global durable cosineTopK recall on-device. Correctness proofs.
//
// Part 1 (storage): the IN-MEMORY Rust L8 engine that backs the global-recall corpus
// (`BASRoutedVectorIndexStorage.init(inMemory:)`). The engine must NOT share the durable WAL file
// with the system-SQLite durable store (rusqlite-bundled vs system SQLite3 on one -shm = corruption),
// so the global-recall replica is a private `:memory:` engine rebuilt from the durable store.
//
// Part 2 (the global-recall retrieve seam, `BASGlobalRecallSeam`) is appended once that library path
// lands.

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif
#if os(macOS)
@testable import BASHostKit
@testable import BASOrchestration
#endif

#if os(iOS) || os(macOS)
final class BASADR037GlobalRecallTests: XCTestCase {

    // MARK: - Part 1: in-memory engine (the global-recall corpus backbone)

    private func makeInMemoryEngine() throws -> BASRoutedVectorIndexStorage {
        try BASRoutedVectorIndexStorage(inMemory: ())
    }

    private func upsert(
        _ store: BASRoutedVectorIndexStorage,
        atomID: String, vector: [Float], domain: String
    ) async throws {
        _ = try await store.upsert(BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: BASEmbedding(
                vector: vector, dimension: vector.count, providerVersion: "p"),
            domain: domain, metadata: [:]))
    }

    /// The in-memory engine (`:memory:`) ranks + resolves atom_ids exactly like the file-backed one —
    /// same engine, no durable file. This is the backbone of global recall.
    func testInMemoryEngineRanksAndResolves() async throws {
        let store = try makeInMemoryEngine()
        let embeddings: [[Float]] = [
            [0.1, 0, 0, 0], [0.3, 0, 0, 0], [0.5, 0, 0, 0],
            [0.7, 0, 0, 0], [0.9, 0, 0, 0]]
        for (i, emb) in embeddings.enumerated() {
            try await upsert(store, atomID: "ord-\(i)", vector: emb, domain: "g")
        }
        let top = try store.cosineTopKAtomIDsSync(forDomain: "g", query: [1, 0, 0, 0], k: 3)
        XCTAssertEqual(top.map(\.atomID), ["ord-4", "ord-3", "ord-2"],
            "in-memory engine must rank + resolve like the file-backed engine")
        XCTAssertEqual(top[0].score, 0.9, accuracy: 1e-5)
        XCTAssertEqual(top[1].score, 0.7, accuracy: 1e-5)
        XCTAssertEqual(top[2].score, 0.5, accuracy: 1e-5)
    }

    /// totalCount reflects the in-memory corpus size (used by the host's ACTIVE log line).
    func testInMemoryEngineTotalCount() async throws {
        let store = try makeInMemoryEngine()
        for i in 0..<7 {
            try await upsert(store, atomID: "a-\(i)", vector: [Float(i + 1), 0, 0, 0], domain: "g")
        }
        let n = await store.totalCount
        XCTAssertEqual(n, 7)
    }

    /// Each `:memory:` engine is PRIVATE — two instances share no state. Proves the global-recall
    /// replica is isolated and cannot touch the durable store (the core safety claim of ADR-037).
    func testInMemoryEnginesAreIsolated() async throws {
        let a = try makeInMemoryEngine()
        let b = try makeInMemoryEngine()
        try await upsert(a, atomID: "only-in-a", vector: [1, 0, 0, 0], domain: "g")
        let countA = await a.totalCount
        let countB = await b.totalCount
        XCTAssertEqual(countA, 1)
        XCTAssertEqual(countB, 0, "each :memory: engine is private — no shared state")
    }

    /// Empty domain → empty result (no crash, no resolution attempt).
    func testInMemoryEmptyDomainReturnsEmpty() throws {
        let store = try makeInMemoryEngine()
        let empty = try store.cosineTopKAtomIDsSync(
            forDomain: "nonexistent", query: [1, 0, 0, 0], k: 5)
        XCTAssertTrue(empty.isEmpty)
    }

    #if os(macOS)
    // MARK: - Part 2: GLOBAL recall over the full durable corpus (the ADR-037 takeover)
    //
    // Wires a BASL8RoutedMemoryService with a BASGlobalRecallSeam backed by an in-memory engine +
    // resolver, and proves: (1) an atom OUTSIDE the snapshot window is recalled globally (and the
    // legacy nil-seam path cannot); (2) determinism; (3) the constitution filter still uses each
    // atom's REAL domain; (4) nil seam ⇒ score-all unchanged (byte-equal-off). Floor is set to 0 so
    // the mechanism is tested independently of the cosine/dot magnitude tuning.

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
    private func governed(id: UUID, content: String, domain: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .user,
            sensitivity: .low, tier: .warm, confidence: 0.7,
            sourceType: domain, governanceStatus: .candidate, provenanceSummary: "adr037")
    }

    /// Build an in-memory engine + resolver over `corpus` and return a wired seam. The engine stores
    /// every atom under one recall domain (`pin`) — mirroring the host's domain-pin — while the
    /// resolver returns each atom's REAL domain (for the constitution filter).
    private func makeGlobalSeam(
        corpus: [BASGovernedMemory],
        embed: @escaping @Sendable (String) -> [Float],
        pin: String
    ) async throws -> BASGlobalRecallSeam {
        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        var resolver: [String: (atom: BASMemoryAtom, domain: String)] = [:]
        for g in corpus {
            let id = g.id.uuidString
            let vec = embed(g.content)
            _ = try await engine.upsert(BASVectorIndexEntry(
                atomID: id,
                normalizedEmbedding: BASEmbedding(
                    vector: vec, dimension: vec.count, providerVersion: "p").normalized,
                domain: pin))
            resolver[id] = (BASL8RoutedMemoryService.memoryAtom(from: g), g.sourceType)
        }
        let map = resolver
        return BASGlobalRecallSeam(
            cosineTopK: { q, k in
                (try? engine.cosineTopKAtomIDsSync(forDomain: pin, query: q, k: k)) ?? []
            },
            atomForID: { id in map[id] })
    }

    /// HEADLINE: an atom OUTSIDE the snapshot window is recalled GLOBALLY — and the legacy nil-seam
    /// service over the SAME window cannot recall it (the seam is what enables global reach).
    func testGlobalRecallSurfacesAtomBeyondWindow() async throws {
        let embed = BASL8RoutedMemoryService.lexicalEmbed()
        let dim = BASL8RoutedMemoryService.Parameters.defaultLexicalDimension
        let pin = BASL8RoutedMemoryService.Parameters.atomSource
        let needleID = UUID(uuidString: "00000000-0000-0000-0000-00000000FEED")!
        let needle = governed(
            id: needleID, content: "alpine skiing deep winter snow mountain slope",
            domain: "general")
        let window = (0..<64).map { i in
            governed(id: UUID(),
                content: "tax invoice payment ledger entry number \(i)", domain: "general")
        }
        let seam = try await makeGlobalSeam(corpus: window + [needle], embed: embed, pin: pin)
        let q = frame("alpine skiing winter snow")

        let global = BASL8RoutedMemoryService(
            loadAllAtoms: { window }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0, globalRecall: seam)
        await global.refresh()
        let gr = global.retrieve(decomposeFrame: q, hostContext: profile(), budget: budget())
        XCTAssertTrue(gr.atoms.contains { $0.memoryID == needleID.uuidString },
            "global recall must surface the needle living OUTSIDE the ≤64 snapshot window")

        let windowed = BASL8RoutedMemoryService(
            loadAllAtoms: { window }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0)
        await windowed.refresh()
        let wr = windowed.retrieve(decomposeFrame: q, hostContext: profile(), budget: budget())
        XCTAssertFalse(wr.atoms.contains { $0.memoryID == needleID.uuidString },
            "the legacy windowed path cannot recall an atom outside its snapshot")
    }

    /// Determinism: same corpus + query ⇒ identical ids + confidences across calls.
    func testGlobalRecallIsDeterministic() async throws {
        let embed = BASL8RoutedMemoryService.lexicalEmbed()
        let dim = BASL8RoutedMemoryService.Parameters.defaultLexicalDimension
        let pin = BASL8RoutedMemoryService.Parameters.atomSource
        let corpus = (0..<40).map { i in
            governed(id: UUID(),
                content: "topic \(i) alpha beta gamma token\(i)", domain: "general")
        }
        let seam = try await makeGlobalSeam(corpus: corpus, embed: embed, pin: pin)
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { corpus }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0, globalRecall: seam)
        await svc.refresh()
        let q = frame("topic alpha beta gamma")
        let r1 = svc.retrieve(decomposeFrame: q, hostContext: profile(), budget: budget())
        let r2 = svc.retrieve(decomposeFrame: q, hostContext: profile(), budget: budget())
        XCTAssertFalse(r1.atoms.isEmpty)
        XCTAssertEqual(r1.atoms.map(\.memoryID), r2.atoms.map(\.memoryID))
        XCTAssertEqual(r1.atoms.map(\.confidence), r2.atoms.map(\.confidence))
    }

    /// The constitution filter uses each atom's REAL domain (from the resolver), not the engine's
    /// unified pin — so a restricted-domain atom is dropped even when the engine ranks it.
    func testGlobalRecallRespectsConstitutionDomain() async throws {
        let embed = BASL8RoutedMemoryService.lexicalEmbed()
        let dim = BASL8RoutedMemoryService.Parameters.defaultLexicalDimension
        let pin = BASL8RoutedMemoryService.Parameters.atomSource
        let healthID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
        let health = governed(
            id: healthID, content: "blood pressure medication dosage prescription",
            domain: "health")
        let seam = try await makeGlobalSeam(corpus: [health], embed: embed, pin: pin)
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] }, syncEmbed: embed, embeddingDimension: dim,
            restrictedMemoryDomains: ["health"], relevanceFloor: 0.0, globalRecall: seam)
        await svc.refresh()
        let r = svc.retrieve(
            decomposeFrame: frame("blood pressure medication"),
            hostContext: profile(), budget: budget())
        XCTAssertFalse(r.atoms.contains { $0.memoryID == healthID.uuidString },
            "constitution filter must drop the restricted-domain atom via its REAL resolver domain")
    }

    /// Nil seam ⇒ the score-all baseline is UNCHANGED (byte-equal-off, ADR-014): a windowed service
    /// recalls the lexically-closest in-window atom exactly as before the ADR-037 seam existed.
    func testNilSeamIsScoreAllUnchanged() async {
        let embed = BASL8RoutedMemoryService.lexicalEmbed()
        let dim = BASL8RoutedMemoryService.Parameters.defaultLexicalDimension
        let wID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let tID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        let atoms = [
            governed(id: wID, content: "weather forecast sunny rain clouds", domain: "general"),
            governed(id: tID, content: "tax invoice payment deadline office", domain: "general")]
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { atoms }, syncEmbed: embed, embeddingDimension: dim)
        await svc.refresh()
        let r = svc.retrieve(
            decomposeFrame: frame("will it rain today sunny weather"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(r.atoms.first?.memoryID, wID.uuidString,
            "nil seam ⇒ unchanged score-all windowed recall (byte-equal-off)")
    }
    #endif
}
#endif
