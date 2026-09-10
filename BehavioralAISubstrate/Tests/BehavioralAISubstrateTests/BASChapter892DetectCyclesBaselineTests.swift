// MARK: - BASChapter892DetectCyclesBaselineTests
// chapter 八百九十二 / M3150 — discovery #3 MED candidate
//
// Discovery agent #3 (post chapter 884) flagged
// `BASKnowledgeGraph.detectCycles` at
// Sources/BASRuntimeCore/BASKnowledgeGraph.swift:403-484 as the
// last remaining MED-confidence Rust migration candidate after
// arc 871-889 substantially exhausted the worthwhile candidates。
//
// Profile: exponential branching bounded by maxLength=8 +
// maxCycles=32 defaults。 Per-event reducer
// (BASUserStateGraphAwareReducer) calls await graph.detectCycles
// on every event in BASCognitiveOSConvenience.appendEvent for
// graphs that grow session-long。 String-heavy:
//   - nodes.keys.sorted() — String sort O(N log N)
//   - path.contains(edge.toNodeID) — O(path length) per visit
//   - seenCanonicalKeys: Set<String> — String hash per dedup
//
// Per chapter 870 + 881 + 890 measurement-first discipline:
// MEASURE Swift baseline FIRST。 If Swift cost is already low at
// realistic graph sizes (≤500 edges per discovery agent),
// migration would face string-FFI tax (ch 881 pattern) that
// likely exceeds the gain。 Decide based on data。
//
// Skip-by-default after capture per ch 879/881/889/890 archive
// pattern。

import XCTest
@testable import BASRuntimeCore

final class BASChapter892DetectCyclesBaselineTests: XCTestCase {

    /// Chapter 八百九十二 / M3150 baseline DEFERRED to next
    /// session per 「全面收尾」 priorities — bench infrastructure
    /// is in place + ready to capture,but the LIVE measurement
    /// run got blocked by sweep contention during chapter 891.5
    /// fix work。 Skip-by-default per ch 879/881/889/890 archive
    /// pattern;re-enable + run interactively when the
    /// detectCycles flip-or-decline question gets prioritized。
    ///
    /// Discovery agent's PROVISIONAL prediction (without
    /// measurement,based on chapter 881 + 890 string-FFI
    /// pattern):likely DECLINE because graph nodes are
    /// String-keyed → same string-FFI ser cost dominates as
    /// chapter 881/890。 But the per-call Swift cost may be
    /// large enough at large graphs (200+ nodes × 800+ edges)
    /// to flip the math — needs measurement to decide。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 892 baseline INFEASIBLE AS WRITTEN (measured 2026-07-15, was: " +
            "\"DEFERRED — blocked by sweep contention\") — this bench does not terminate: " +
            "78+ MINUTES of CPU without finishing on graphs of only 100-200 nodes. Cause is " +
            "the fixture, not the machine: its circulant graph has ZERO cycles at maxLength " +
            "8, so detectCycles' maxCycles guard never fires and it enumerates every simple " +
            "path — 48,828,100 recursive calls per call at (100,500), x110 iterations. Do " +
            "NOT simply re-enable this; the topology is one production cannot build. See the " +
            "corrected makeGraph note. Old text follows: bench" +
            " infrastructure ready,measurement run blocked" +
            " by sweep contention during ch 891.5 fix work。" +
            " Re-enable skip + run interactively to capture" +
            " the LIVE numbers when prioritized。")
    }

    /// Build a deterministic graph at given (nodes, edges)。
    ///
    /// ⚠️ CORRECTED 2026-07-15 — this claimed "a mix of cycles + tree-shaped edges to match
    /// realistic L13 / cognitive graph topology". BOTH halves are FALSE. Edges only ever go
    /// from `i` to `i+1 … i+k` (mod N), i.e. a circulant digraph. Closing a cycle requires
    /// wrapping the whole ring (~N/k hops), which vastly exceeds maxLength 8 — so this graph
    /// contains ZERO cycles at the detector's default depth, and cannot be built by the real
    /// extractor (which SYNTHESISES closing edges via H7 precisely to make short cycles).
    /// Had this bench ever terminated, its own print would have read "cycles found: 0".
    private func makeGraph(
        nodes nNodes: Int,
        edges nEdges: Int
    ) async -> BASKnowledgeGraph {
        let graph = BASKnowledgeGraph()
        // Add N nodes
        for i in 0..<nNodes {
            let node = BASKnowledgeNode(
                nodeID: "node-\(i)",
                kind: .event,
                label: "Event \(i)",
                createdAtMs: Int64(i * 1000))
            try? await graph.insert(node: node)
        }
        // Add M edges with deterministic but mixed topology
        for i in 0..<nEdges {
            let from = i % nNodes
            // Forward-only: to ∈ {from+1 … from+k} (mod N). NOT "a mix of forward + back
            // edges to create cycles" as this line claimed until 2026-07-15 — the only
            // backward-looking edge is the ring wrap, which needs ~N/k hops to close.
            let to = (from + 1 + (i / nNodes)) % nNodes
            if from == to { continue }
            let edge = BASKnowledgeEdge(
                edgeID: "edge-\(i)",
                fromNodeID: "node-\(from)",
                toNodeID: "node-\(to)",
                kind: .causes,
                weight: 0.5,
                createdAtMs: Int64(i * 100))
            try? await graph.insert(edge: edge)
        }
        return graph
    }

    private func benchAt(
        nNodes: Int, nEdges: Int
    ) async {
        let graph = await makeGraph(
            nodes: nNodes, edges: nEdges)
        let iters = nNodes >= 200 ? 20 : 100
        let warmup = 10

        // Warm
        for _ in 0..<warmup {
            _ = await graph.detectCycles()
        }
        // Bench
        let start = Date()
        var sink = 0
        for _ in 0..<iters {
            let cycles = await graph.detectCycles()
            sink = sink &+ cycles.count
        }
        let nsPerCall = Date().timeIntervalSince(start) *
            1_000_000_000.0 / Double(iters)
        print(String(
            format: "BENCH detectCycles(nodes=%d,edges=%d) — " +
                "%.0f ns/call,cycles found: %d",
            nNodes, nEdges, nsPerCall, sink / iters))
    }

    /// Small graph (discovery agent estimate:typical session
    /// graphs stay < 500 edges)。 Test below + at that bound。
    func testBaselineSmall() async {
        await benchAt(nNodes: 20, nEdges: 30)
    }

    /// Medium graph — common L13 session shape。
    func testBaselineMedium() async {
        await benchAt(nNodes: 50, nEdges: 100)
    }

    /// At-bound graph — discovery's 500-edge estimate。
    func testBaselineAtBound() async {
        await benchAt(nNodes: 100, nEdges: 500)
    }

    /// Larger-than-bound (stress test) — what does it cost when
    /// production grows past the discovery estimate?
    func testBaselineLarge() async {
        await benchAt(nNodes: 200, nEdges: 800)
    }
}
