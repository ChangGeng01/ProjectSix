// MARK: - BASKnowledgeGraphCycleWorkBoundTests
//
// 2026-07-15 — pins that detectCycles' WORK is bounded, not just its output.
//
// `maxCycles` bounds only what is RETURNED, and a filter-rejected cycle never increments
// that count, so before the reachability prune the walk could enumerate every simple path
// on a graph whose cycles fail the caller's filter. Measured on a modelled production graph
// (BASUserStateGraphAwareReducer's real filter): ~638 walk steps when the filter matches vs
// ~3,324,239 when it does not — the same call, returning [] either way.
//
// These assert STEPS, not SECONDS, deliberately. A wall-clock bound would make this a load
// detector — the exact defect corrected in BASChapter905StorePerfBenchmarkTests, where a
// busy machine reported Rust "2.14x slower" and RED a 2x guard. Step counts are
// deterministic for a given graph.

import XCTest
@testable import BASRuntimeCore

final class BASKnowledgeGraphCycleWorkBoundTests: XCTestCase {

    /// Circulant digraph: every edge steps forward +1…+k (mod n), which is chapter 892's
    /// generator. Closing a cycle needs ~n/k hops, so at n=40/k=4 there is NO cycle within
    /// the default maxLength of 8 — the worst case for the old code, because zero cycles
    /// means the maxCycles guard never fires.
    private func makeCirculant(nodes n: Int, outDegree k: Int) async -> BASKnowledgeGraph {
        let graph = BASKnowledgeGraph()
        for i in 0..<n {
            try? await graph.insert(node: BASKnowledgeNode(
                nodeID: "node-\(i)", kind: .event, label: "E\(i)",
                createdAtMs: Int64(i)))
        }
        for i in 0..<n {
            for step in 1...k {
                let to = (i + step) % n
                if to == i { continue }
                try? await graph.insert(edge: BASKnowledgeEdge(
                    edgeID: "edge-\(i)-\(step)",
                    fromNodeID: "node-\(i)", toNodeID: "node-\(to)",
                    kind: .causes, weight: 0.5, createdAtMs: Int64(i)))
            }
        }
        return graph
    }

    /// ★ THE TOOTH. On a graph with NO cycles within maxLength, the walk must not enumerate
    /// the whole path space.
    ///
    /// Unpruned this is 40 · 4^8 ≈ 2.6M walk steps; chapter 892 hit the same shape at
    /// (100,500) and burned 78+ MINUTES of CPU without terminating. n=40 is chosen so the
    /// REVERSAL is provable in seconds rather than hours.
    func testAcyclicWithinDepthDoesNotEnumerateThePathSpace() async {
        let graph = await makeCirculant(nodes: 40, outDegree: 4)
        let cycles = await graph.detectCycles()
        let steps = await graph.lastDetectCyclesWalkSteps

        XCTAssertEqual(
            cycles.count, 0,
            "a forward-only circulant with step ≤4 needs ~10 hops to close; none exist at "
            + "maxLength 8")
        XCTAssertLessThan(
            steps, 50_000,
            "detectCycles enumerated \(steps) walk steps on a 40-node graph with no cycles "
            + "in range. The reachability prune is gone or defeated: maxCycles bounds the "
            + "OUTPUT only, so with zero cycles nothing stops the walk (unpruned ≈ 40·4^8 "
            + "≈ 2.6M). This is the shape that made chapter 892 run for 78+ minutes.")
    }

    /// The production-shaped defect: cycles EXIST but the caller's filter rejects them, so
    /// the maxCycles budget never fills. Returning [] must still be cheap.
    func testFilterRejectingEveryCycleStillBoundsTheWork() async {
        // Small ring + chords: rich in short cycles, unlike the circulant above.
        let graph = BASKnowledgeGraph()
        for i in 0..<24 {
            try? await graph.insert(node: BASKnowledgeNode(
                nodeID: "node-\(i)", kind: .event, label: "E\(i)", createdAtMs: Int64(i)))
        }
        for i in 0..<24 {
            for step in [1, 5, 23] {   // 23 ≡ -1 (mod 24) ⇒ genuine back edges ⇒ 2-cycles
                let to = (i + step) % 24
                if to == i { continue }
                try? await graph.insert(edge: BASKnowledgeEdge(
                    edgeID: "e-\(i)-\(step)", fromNodeID: "node-\(i)", toNodeID: "node-\(to)",
                    kind: .causes, weight: 0.5, createdAtMs: Int64(i)))
            }
        }
        // Sanity: unfiltered, this graph HAS cycles — otherwise the test below proves nothing.
        let unfiltered = await graph.detectCycles()
        XCTAssertGreaterThan(
            unfiltered.count, 0,
            "fixture must be cycle-RICH, else the filter arm is vacuous")

        // Now a filter nothing satisfies — the reducer's shape (requires an edge kind the
        // graph never uses).
        let none = await graph.detectCycles(filter: { $0.containsEdgeKind(.delays) })
        let steps = await graph.lastDetectCyclesWalkSteps
        XCTAssertEqual(none.count, 0)
        // Bound chosen to SEPARATE the two regimes, not merely to be true: pruned measures
        // 9,840 steps; unpruned is ~24·3^8 ≈ 157,000. A 200,000 bound (the first cut) sat
        // above BOTH and proved nothing — the reversal passed and exposed it.
        XCTAssertLessThan(
            steps, 30_000,
            "every cycle was filter-rejected, so cycles.count stayed 0 and the maxCycles "
            + "guard never fired — \(steps) walk steps. This is the live production shape: "
            + "the reducer asks for .delays cycles touching the current project, and when "
            + "that project has none the call pays full freight to return [].")
    }
}
