// ADR-039 Phase 2 — L8 LIVE seam: Metal cosine-topK over the in-Swift snapshot corpus, wired into
// BASL8RoutedMemoryService.retrieve(). Proves the three load-bearing properties of the live wiring:
//   1. WEDGE-SAFE — a nil seam result (Metal fault / timeout) is byte-identical to the CPU score-all path.
//   2. WIRING — a CPU-reference stub (no GPU) surfaces exactly the CPU score-all path's atoms (the
//      corpus-flatten + rowIndex→atomID mapping is correct).
//   3. INTEGRATION — the REAL dispatcher through the REAL sync bridge never corrupts the result (it either
//      matches the CPU set on the GPU, or falls back to the identical CPU set). GPU-execution parity per
//      se is proven by BASMetalTopKParityTests (Mac GPU) + the on-device BAS_METAL_SMOKE cert.
//
// Determinism boundary (ADR-039 §2): only `atomID` crosses into the spine — the durable store / event-log /
// governance verdict are verified Metal-free. The Metal score becomes atom.confidence on the reasoning-side
// bundle, which IS in the replay-digest preimage; since the Metal score is non-reproducible, the path is
// APPROXIMATE + NOT replay-stable (default-off; not for replay-over-routed-backend). These tests assert the
// atomID membership (CPU-identical via the shared sort, since the seam requests all rows) + the wedge-safe
// CPU retreat — NOT replay-stability, which this path deliberately does not provide.

import XCTest
import Foundation

#if os(macOS)
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASMetalL8SeamTests: XCTestCase {

    // MARK: - Fixtures (mirror BASADR037GlobalRecallTests)

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
    private func governed(id: UUID, content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .user,
            sensitivity: .low, tier: .warm, confidence: 0.7,
            sourceType: "general", governanceStatus: .candidate, provenanceSummary: "adr039")
    }

    /// A spread-out corpus so the top-K is meaningful (distinct-ish lexical neighborhoods).
    private func corpus() -> [BASGovernedMemory] {
        [
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
                content: "alpine skiing winter snow mountain slope powder"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
                content: "tax invoice payment ledger accounting deadline"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
                content: "alpine winter snow resort lift ticket season"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!,
                content: "garden tomato basil soil watering sunlight"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!,
                content: "snowboard alpine winter mountain freestyle jump"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A6")!,
                content: "quarterly report revenue forecast spreadsheet"),
        ]
    }

    private func makeService(
        metalSeam: BASMetalCosineTopKSeam?
    ) async -> BASL8RoutedMemoryService {
        let embed = BASL8RoutedMemoryService.lexicalEmbed()
        let dim = BASL8RoutedMemoryService.Parameters.defaultLexicalDimension
        let atoms = corpus()
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { atoms }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0,            // floor 0 ⇒ test the seam independent of magnitude tuning
            selfPopulate: false,            // no self-pop ⇒ a stable snapshot == the corpus
            metalCosineTopK: metalSeam)
        await svc.refresh()
        return svc
    }

    private func ids(_ svc: BASL8RoutedMemoryService) -> [String] {
        svc.retrieve(
            decomposeFrame: frame("alpine winter snow mountain"),
            hostContext: profile(), budget: budget()
        ).atoms.map(\.memoryID)
    }

    // MARK: - 1. WEDGE-SAFE: nil seam result ⇒ byte-identical to the CPU score-all path

    func testNilResultIsByteIdenticalToCpuPath() async {
        // Seam ALWAYS returns nil (simulates a Metal fault / timeout on every call).
        let alwaysNil: BASMetalCosineTopKSeam = { _, _, _, _ in nil }
        let metalSvc = await makeService(metalSeam: alwaysNil)
        let cpuSvc = await makeService(metalSeam: nil)   // no seam ⇒ pure CPU score-all

        let metalResult = metalSvc.retrieve(
            decomposeFrame: frame("alpine winter snow mountain"),
            hostContext: profile(), budget: budget())
        let cpuResult = cpuSvc.retrieve(
            decomposeFrame: frame("alpine winter snow mountain"),
            hostContext: profile(), budget: budget())

        XCTAssertFalse(cpuResult.atoms.isEmpty, "fixture should recall something")
        XCTAssertEqual(metalResult.atoms.map(\.memoryID), cpuResult.atoms.map(\.memoryID),
            "a nil Metal result must retreat to the byte-identical CPU score-all path (wedge-safe)")
        XCTAssertEqual(metalResult.atoms.map(\.confidence), cpuResult.atoms.map(\.confidence),
            "the wedge-safe fallback reproduces the CPU confidences exactly")
    }

    // MARK: - 2. WIRING: a CPU-reference stub surfaces exactly the CPU score-all path's atoms

    func testCpuReferenceStubMatchesScoreAll() async {
        // The stub computes the SAME selection the Metal dispatcher would (its own cpuReference), over the
        // flat corpus the service builds — proving the corpus-flatten + rowIndex→atomID mapping is correct.
        let stub: BASMetalCosineTopKSeam = { query, corpus, dim, k in
            BASMetalTopKDispatcher.cpuReference(query: query, corpus: corpus, dim: dim, k: k)
                .map { (rowIndex: $0.rowIndex, score: $0.score) }
        }
        let metalSvc = await makeService(metalSeam: stub)
        let cpuSvc = await makeService(metalSeam: nil)

        let metalIDs = ids(metalSvc)
        let cpuIDs = ids(cpuSvc)
        XCTAssertFalse(cpuIDs.isEmpty)
        XCTAssertEqual(metalIDs.count, cpuIDs.count)
        XCTAssertEqual(Set(metalIDs), Set(cpuIDs),
            "the Metal-branch rowIndex→atomID mapping must surface exactly the CPU path's atoms")
    }

    // MARK: - 2b. SAFETY: a dim-mismatched query SKIPS Metal (no crash) and falls back to CPU (C-1 guard)

    func testRaggedQuerySkipsMetalAndFallsBackToCpu() async {
        // Simulate an embedding failure for ONE query (returns []), while the corpus embeds normally at the
        // declared dim. The service's `query.count == embeddingDimension` guard must skip Metal (the flat
        // GPU corpus + cpuReference would otherwise index query[d] out of bounds) and take the CPU path.
        let dim = 8
        let embed: @Sendable (String) -> [Float] = { text in
            text == "POISON-QUERY"
                ? []                                                   // embedding failure for this query
                : (0..<dim).map { Float(($0 + text.count) % 5) }       // normal vector otherwise
        }
        // The seam ASSERTS it is never called with a dim-mismatched query — if the guard regresses, this
        // fires. With the guard intact, the seam is simply not invoked for the poison query.
        let guardProbe: BASMetalCosineTopKSeam = { query, _, dim, _ in
            XCTAssertEqual(query.count, dim,
                "the service must never invoke the Metal seam with a dim-mismatched query")
            return nil
        }
        let atoms = [
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!, content: "alpha"),
            governed(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!, content: "beta gamma"),
        ]
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { atoms }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0, selfPopulate: false, metalCosineTopK: guardProbe)
        let cpuSvc = BASL8RoutedMemoryService(
            loadAllAtoms: { atoms }, syncEmbed: embed, embeddingDimension: dim,
            relevanceFloor: 0.0, selfPopulate: false)   // no seam ⇒ pure CPU
        await svc.refresh(); await cpuSvc.refresh()
        // Must NOT crash; the poison (empty) query takes the CPU path, byte-identical to the no-seam service.
        let guarded = svc.retrieve(
            decomposeFrame: frame("POISON-QUERY"), hostContext: profile(), budget: budget())
        let cpu = cpuSvc.retrieve(
            decomposeFrame: frame("POISON-QUERY"), hostContext: profile(), budget: budget())
        XCTAssertEqual(guarded.atoms.map(\.memoryID), cpu.atoms.map(\.memoryID),
            "a dim-mismatched query must skip Metal (no trap) and match the CPU path exactly")
    }

    // MARK: - 3. INTEGRATION: the REAL dispatcher through the REAL sync bridge never corrupts the result

    func testRealDispatcherThroughSyncBridgeNeverCorrupts() async {
        let dispatcher = BASMetalTopKDispatcher(
            loader: BASMetalKernelLibraryLoader(useMetalKernelV2: true))
        // The EXACT shape the runner wires: a sync seam that runs the async dispatch under a hard timeout
        // with a nil→CPU-fallback contract.
        let seam: BASMetalCosineTopKSeam = { query, corpus, dim, k in
            let (value, usedFallback) = BASMetalSyncBridge.runWithTimeout(
                timeoutMs: 2000,
                {
                    guard let approx = try? await dispatcher.dispatch(
                        query: query, corpus: corpus, dim: dim, k: k) else { return nil }
                    return approx.approximateOnly().map {
                        (rowIndex: $0.rowIndex, score: $0.score) }
                },
                fallback: { [] as [(rowIndex: Int, score: Float)] })
            return usedFallback ? nil : value
        }
        let metalSvc = await makeService(metalSeam: seam)
        let cpuSvc = await makeService(metalSeam: nil)

        // Whether Metal ran on the Mac GPU OR fell back to CPU, the LIVE wiring must produce exactly the
        // CPU path's atom set — it never corrupts/loses a result. (GPU-execution parity is proven by
        // BASMetalTopKParityTests + the on-device cert.)
        let metalIDs = Set(ids(metalSvc))
        let cpuIDs = Set(ids(cpuSvc))
        XCTAssertFalse(cpuIDs.isEmpty)
        XCTAssertEqual(metalIDs, cpuIDs,
            "the real dispatcher + sync bridge must match the CPU set (parity on GPU, or safe fallback)")
    }
}
#endif
