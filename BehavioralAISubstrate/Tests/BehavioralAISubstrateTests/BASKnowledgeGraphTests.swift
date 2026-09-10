// MARK: - BASKnowledgeGraphTests — chapter 三百六九 / M856
//
// Test coverage for P2 G9 deliverable: knowledge graph + causal
// graph primitives。Verifies:
//   - Node + edge typed shape (Codable, Equatable)
//   - Insert / upsert / remove (with edge cascade)
//   - Duplicate ID rejection
//   - Missing-endpoint rejection on edge insert
//   - Outgoing edge query
//   - Cycle detection: simple cycles, dedupe across rotations,
//     bounded by maxLength + maxCycles
//   - User vision §10 case: "焦虑 → 加技术 → 做不完 → 焦虑" loop
//     detection via filter

import XCTest
@testable import BASRuntimeCore

final class BASKnowledgeGraphTests: XCTestCase {

    // MARK: - Fixtures

    private func makeNode(
        id: String,
        kind: BASKnowledgeNodeKind = .event,
        label: String? = nil
    ) -> BASKnowledgeNode {
        BASKnowledgeNode(
            nodeID: id,
            kind: kind,
            label: label ?? id,
            createdAtMs: 1_700_000_000_000)
    }

    private func makeEdge(
        from: String,
        to: String,
        kind: BASKnowledgeEdgeKind = .causes,
        weight: Double = 0.5
    ) -> BASKnowledgeEdge {
        BASKnowledgeEdge(
            edgeID: "\(from)->\(to)",
            fromNodeID: from,
            toNodeID: to,
            kind: kind,
            weight: weight,
            createdAtMs: 1_700_000_000_000)
    }

    // MARK: - Node + edge shape

    func testNodeKindRawValueStability() {
        XCTAssertEqual(
            BASKnowledgeNodeKind.event.rawValue, "event")
        XCTAssertEqual(
            BASKnowledgeNodeKind.atom.rawValue, "atom")
        XCTAssertEqual(
            BASKnowledgeNodeKind.project.rawValue, "project")
        XCTAssertEqual(
            BASKnowledgeNodeKind.goal.rawValue, "goal")
        XCTAssertEqual(
            BASKnowledgeNodeKind.state.rawValue, "state")
        XCTAssertEqual(
            BASKnowledgeNodeKind.external.rawValue, "external")
    }

    func testEdgeKindRawValueStability() {
        XCTAssertEqual(
            BASKnowledgeEdgeKind.causes.rawValue, "causes")
        XCTAssertEqual(
            BASKnowledgeEdgeKind.delays.rawValue, "delays")
        XCTAssertEqual(
            BASKnowledgeEdgeKind.replaces.rawValue, "replaces")
        XCTAssertEqual(
            BASKnowledgeEdgeKind.contradicts.rawValue,
            "contradicts")
        XCTAssertEqual(
            BASKnowledgeEdgeKind.supports.rawValue, "supports")
        XCTAssertEqual(
            BASKnowledgeEdgeKind.mentions.rawValue, "mentions")
    }

    func testEdgeWeightClamps() {
        let above = makeEdge(
            from: "a", to: "b", weight: 5.0)
        let below = makeEdge(
            from: "a", to: "b", weight: -1.0)
        XCTAssertEqual(above.weight, 1.0)
        XCTAssertEqual(below.weight, 0.0)
    }

    func testNodeCodableRoundTrip() throws {
        let original = BASKnowledgeNode(
            nodeID: "test",
            kind: .project,
            label: "test project",
            createdAtMs: 1_700_000_000_000,
            payloadJson: "{\"priority\": \"high\"}")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKnowledgeNode.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEdgeCodableRoundTrip() throws {
        let original = makeEdge(
            from: "x", to: "y",
            kind: .delays, weight: 0.7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKnowledgeEdge.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Insert / remove

    func testInsertNodeAndQuery() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        let count = await graph.nodeCount
        XCTAssertEqual(count, 1)
        let fetched = await graph.node(forID: "a")
        XCTAssertNotNil(fetched)
    }

    func testDuplicateNodeRejected() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "dup"))
        do {
            try await graph.insert(node: makeNode(id: "dup"))
            XCTFail("Expected duplicateNodeID")
        } catch BASKnowledgeGraphError
            .duplicateNodeID(let id)
        {
            XCTAssertEqual(id, "dup")
        }
    }

    func testUpsertReplacesExisting() async {
        let graph = BASKnowledgeGraph()
        await graph.upsert(node: makeNode(
            id: "x", label: "v1"))
        await graph.upsert(node: makeNode(
            id: "x", label: "v2"))
        let count = await graph.nodeCount
        XCTAssertEqual(count, 1)
        let fetched = await graph.node(forID: "x")
        XCTAssertEqual(fetched?.label, "v2")
    }

    func testInsertEdgeRejectedOnMissingEndpoint() async {
        let graph = BASKnowledgeGraph()
        do {
            try await graph.insert(edge: makeEdge(
                from: "missing-a",
                to: "missing-b"))
            XCTFail("Expected nodeNotFound")
        } catch BASKnowledgeGraphError.nodeNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDuplicateEdgeRejected() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        try await graph.insert(node: makeNode(id: "b"))
        try await graph.insert(edge: makeEdge(
            from: "a", to: "b"))
        do {
            try await graph.insert(edge: makeEdge(
                from: "a", to: "b"))
            XCTFail("Expected duplicateEdgeID")
        } catch BASKnowledgeGraphError
            .duplicateEdgeID(let id)
        {
            XCTAssertEqual(id, "a->b")
        }
    }

    func testRemoveNodeCascadesEdges() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        try await graph.insert(node: makeNode(id: "b"))
        try await graph.insert(node: makeNode(id: "c"))
        try await graph.insert(edge: makeEdge(
            from: "a", to: "b"))
        try await graph.insert(edge: makeEdge(
            from: "c", to: "a"))  // incoming to a
        let removed = await graph.remove(nodeID: "a")
        XCTAssertTrue(removed)
        let edgeCount = await graph.edgeCount
        XCTAssertEqual(
            edgeCount, 0,
            "Both edges (outgoing + incoming to removed " +
            "node) must cascade-delete")
    }

    func testRemoveAbsentNodeReturnsFalse() async {
        let graph = BASKnowledgeGraph()
        let removed = await graph.remove(nodeID: "never")
        XCTAssertFalse(removed)
    }

    // MARK: - Outgoing edge query

    func testOutgoingEdgesReturned() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        try await graph.insert(node: makeNode(id: "b"))
        try await graph.insert(node: makeNode(id: "c"))
        try await graph.insert(edge: makeEdge(
            from: "a", to: "b"))
        try await graph.insert(edge: makeEdge(
            from: "a", to: "c"))
        let outgoing = await graph.outgoing(from: "a")
        XCTAssertEqual(outgoing.count, 2)
        XCTAssertEqual(
            Set(outgoing.map { $0.toNodeID }),
            Set(["b", "c"]))
    }

    // MARK: - Cycle detection

    func testTwoNodeCycleDetected() async throws {
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        try await graph.insert(node: makeNode(id: "b"))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "a-b",
            fromNodeID: "a", toNodeID: "b",
            kind: .causes,
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "b-a",
            fromNodeID: "b", toNodeID: "a",
            kind: .causes,
            createdAtMs: 0))
        let cycles = await graph.detectCycles()
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(
            Set(cycles[0].nodeIDs),
            Set(["a", "b"]))
        XCTAssertEqual(cycles[0].length, 2)
    }

    func testThreeNodeCycleDetected() async throws {
        let graph = BASKnowledgeGraph()
        for id in ["a", "b", "c"] {
            try await graph.insert(node: makeNode(id: id))
        }
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "ab", fromNodeID: "a",
            toNodeID: "b", kind: .causes, createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "bc", fromNodeID: "b",
            toNodeID: "c", kind: .delays, createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "ca", fromNodeID: "c",
            toNodeID: "a", kind: .causes, createdAtMs: 0))
        let cycles = await graph.detectCycles()
        XCTAssertEqual(
            cycles.count, 1,
            "Single 3-node cycle should be detected once " +
            "(canonical-rotation dedup)")
        XCTAssertEqual(cycles[0].length, 3)
        XCTAssertEqual(
            Set(cycles[0].edgeKinds),
            Set([.causes, .delays]),
            "Cycle's edge kinds preserve traversal order")
    }

    func testNoCycleInDAG() async throws {
        let graph = BASKnowledgeGraph()
        for id in ["a", "b", "c", "d"] {
            try await graph.insert(node: makeNode(id: id))
        }
        // a → b → c → d (DAG, no cycle)
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "ab", fromNodeID: "a", toNodeID: "b",
            kind: .causes, createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "bc", fromNodeID: "b", toNodeID: "c",
            kind: .causes, createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "cd", fromNodeID: "c", toNodeID: "d",
            kind: .causes, createdAtMs: 0))
        let cycles = await graph.detectCycles()
        XCTAssertEqual(cycles.count, 0,
            "DAG must have zero cycles")
    }

    func testCycleFilterByEdgeKind() async throws {
        // User vision §10 example: cycle that contains
        // `delays` edges is the "complexity addiction" loop
        let graph = BASKnowledgeGraph()
        for id in ["anxiety", "tech", "ship"] {
            try await graph.insert(node: makeNode(
                id: id, kind: .state))
        }
        // anxiety → causes → tech (add tech)
        // tech → delays → ship (delays shipping)
        // ship → causes → anxiety (failure to ship → anxiety)
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e1", fromNodeID: "anxiety",
            toNodeID: "tech", kind: .causes,
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e2", fromNodeID: "tech",
            toNodeID: "ship", kind: .delays,
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e3", fromNodeID: "ship",
            toNodeID: "anxiety", kind: .causes,
            createdAtMs: 0))
        // Filter for cycles containing `delays`
        let delayCycles = await graph.detectCycles(
            filter: {
                $0.containsEdgeKind(.delays)
            })
        XCTAssertEqual(
            delayCycles.count, 1,
            "User vision §10 'complexity addiction loop' " +
            "(anxiety → add tech → delay shipping → " +
            "anxiety) is detected with delays-edge filter")
        XCTAssertEqual(delayCycles[0].length, 3)
        XCTAssertTrue(
            delayCycles[0].containsEdgeKind(.delays))
    }

    func testCycleMaxLengthBound() async throws {
        // Long cycle should NOT be detected when maxLength
        // is below cycle length
        let graph = BASKnowledgeGraph()
        for i in 0..<10 {
            try await graph.insert(node: makeNode(
                id: "n\(i)"))
        }
        // n0 → n1 → ... → n9 → n0 (length-10 cycle)
        for i in 0..<9 {
            try await graph.insert(edge: BASKnowledgeEdge(
                edgeID: "e\(i)",
                fromNodeID: "n\(i)",
                toNodeID: "n\(i+1)",
                kind: .causes, createdAtMs: 0))
        }
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e9",
            fromNodeID: "n9",
            toNodeID: "n0",
            kind: .causes, createdAtMs: 0))
        // Default max=8 → length-10 cycle not enumerated
        let cyclesDefault = await graph.detectCycles()
        XCTAssertEqual(
            cyclesDefault.count, 0,
            "Cycle of length 10 must not be enumerated " +
            "with default maxLength=8")
        // Explicit max=11 → cycle found
        let cyclesLarger = await graph.detectCycles(
            maxLength: 11)
        XCTAssertEqual(cyclesLarger.count, 1)
    }

    func testMaxCyclesBound() async throws {
        // Build a graph with 3 distinct 2-cycles
        let graph = BASKnowledgeGraph()
        for id in ["a", "b", "c", "d", "e", "f"] {
            try await graph.insert(node: makeNode(id: id))
        }
        // a↔b, c↔d, e↔f
        let pairs: [(String, String)] = [
            ("a", "b"), ("c", "d"), ("e", "f")]
        for (lhs, rhs) in pairs {
            try await graph.insert(edge: BASKnowledgeEdge(
                edgeID: "\(lhs)-\(rhs)",
                fromNodeID: lhs, toNodeID: rhs,
                kind: .causes, createdAtMs: 0))
            try await graph.insert(edge: BASKnowledgeEdge(
                edgeID: "\(rhs)-\(lhs)",
                fromNodeID: rhs, toNodeID: lhs,
                kind: .causes, createdAtMs: 0))
        }
        let limited = await graph.detectCycles(
            maxCycles: 2)
        XCTAssertEqual(limited.count, 2,
            "maxCycles=2 must cap result to 2 even when " +
            "more cycles exist")
    }

    // MARK: - Constants pin

    func testDefaultMaxCycleLengthPin() {
        XCTAssertEqual(
            BASKnowledgeGraph.defaultMaxCycleLength, 8)
    }

    func testDefaultMaxCyclesReturnedPin() {
        XCTAssertEqual(
            BASKnowledgeGraph.defaultMaxCyclesReturned, 32)
    }

    // MARK: - Edge kind allCases pin

    func testEdgeKindAllCasesCount() {
        XCTAssertEqual(
            BASKnowledgeEdgeKind.allCases.count, 6,
            "Edge kind count pin: bumping requires explicit " +
            "audit for any code that switches on edge kind")
    }

    func testNodeKindAllCasesCount() {
        XCTAssertEqual(
            BASKnowledgeNodeKind.allCases.count, 6,
            "Node kind count pin")
    }
}
