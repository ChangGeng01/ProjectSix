// MARK: - BASSQLiteKnowledgeGraphStorageTests — chapter 三百七九 / M866
//
// Test coverage for the SQLite-backed knowledge graph storage。
// Closes M856 deferred persistence work。Mirrors M849 vector
// index storage tests + the M863 eval run storage tests。
//
// Tests verify:
//   - Node + edge round-trip (insert + fetch)
//   - Append idempotent on duplicate IDs
//   - Upsert overwrites existing node by ID
//   - Bulk fetch ordered by createdAtMs ASC for stable preload
//   - Preload populates an in-memory graph correctly
//   - Persistence across actor reopens
//   - Remove cascades incident edges (mirror graph actor semantics)
//   - Schema version pin

import XCTest
@testable import BASRuntimeCore

final class BASSQLiteKnowledgeGraphStorageTests: XCTestCase {

    private var tempDir: URL?

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-graph-storage-test-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir!,
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    private func makeStorage() throws
        -> BASSQLiteKnowledgeGraphStorage
    {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("graph.sqlite")
        return try BASSQLiteKnowledgeGraphStorage(
            databaseURL: url)
    }

    private func makeNode(
        id: String,
        kind: BASKnowledgeNodeKind = .event,
        label: String = "test-label",
        createdAtMs: Int64 = 1_700_000_000_000,
        payload: String? = nil
    ) -> BASKnowledgeNode {
        BASKnowledgeNode(
            nodeID: id,
            kind: kind,
            label: label,
            createdAtMs: createdAtMs,
            payloadJson: payload)
    }

    private func makeEdge(
        id: String,
        from: String,
        to: String,
        kind: BASKnowledgeEdgeKind = .causes,
        weight: Double = 0.5,
        createdAtMs: Int64 = 1_700_000_000_000
    ) -> BASKnowledgeEdge {
        BASKnowledgeEdge(
            edgeID: id,
            fromNodeID: from,
            toNodeID: to,
            kind: kind,
            weight: weight,
            createdAtMs: createdAtMs)
    }

    // MARK: - Node round-trip

    func testNodeRoundTrip() async throws {
        let storage = try makeStorage()
        let node = makeNode(
            id: "n1",
            kind: .project,
            label: "test-project",
            createdAtMs: 100,
            payload: "{\"meta\":\"test\"}")

        let wasNew = try await storage.appendNode(node)
        XCTAssertTrue(wasNew)

        let fetched = await storage.node(forID: "n1")
        XCTAssertEqual(fetched, node)
    }

    func testAppendNodeIdempotent() async throws {
        let storage = try makeStorage()
        let node = makeNode(id: "n1")

        let first = try await storage.appendNode(node)
        let second = try await storage.appendNode(node)
        XCTAssertTrue(first)
        XCTAssertFalse(second,
            "Duplicate node ID must return false")
        let count = await storage.nodeCount
        XCTAssertEqual(count, 1)
    }

    func testUpsertNodeOverwrites() async throws {
        let storage = try makeStorage()
        let original = makeNode(
            id: "n1", label: "original", createdAtMs: 100)
        let updated = makeNode(
            id: "n1", label: "updated", createdAtMs: 200)

        try await storage.upsertNode(original)
        try await storage.upsertNode(updated)
        let fetched = await storage.node(forID: "n1")
        XCTAssertEqual(fetched?.label, "updated")
        XCTAssertEqual(fetched?.createdAtMs, 200)
        let count = await storage.nodeCount
        XCTAssertEqual(count, 1,
            "Upsert must not duplicate the row")
    }

    func testNullPayloadHandled() async throws {
        let storage = try makeStorage()
        let node = makeNode(id: "n1", payload: nil)
        try await storage.appendNode(node)
        let fetched = await storage.node(forID: "n1")
        XCTAssertNil(fetched?.payloadJson,
            "Nil payload must round-trip as nil")
    }

    func testAllNodesOrderedByCreatedAt() async throws {
        let storage = try makeStorage()
        try await storage.appendNode(makeNode(
            id: "n3", createdAtMs: 300))
        try await storage.appendNode(makeNode(
            id: "n1", createdAtMs: 100))
        try await storage.appendNode(makeNode(
            id: "n2", createdAtMs: 200))

        let all = await storage.allNodes()
        XCTAssertEqual(all.map { $0.nodeID },
            ["n1", "n2", "n3"],
            "allNodes must order by createdAtMs ASC for " +
            "stable preload sequence")
    }

    // MARK: - Edge round-trip

    func testEdgeRoundTrip() async throws {
        let storage = try makeStorage()
        // Create the nodes first so we have valid ends
        try await storage.appendNode(makeNode(id: "a"))
        try await storage.appendNode(makeNode(id: "b"))
        let edge = makeEdge(
            id: "e1", from: "a", to: "b",
            kind: .delays, weight: 0.7,
            createdAtMs: 100)
        let wasNew = try await storage.appendEdge(edge)
        XCTAssertTrue(wasNew)

        let all = await storage.allEdges()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first, edge)
    }

    func testAppendEdgeIdempotent() async throws {
        let storage = try makeStorage()
        let edge = makeEdge(id: "e1", from: "a", to: "b")
        let first = try await storage.appendEdge(edge)
        let second = try await storage.appendEdge(edge)
        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func testAllEdgesOrderedByCreatedAt() async throws {
        let storage = try makeStorage()
        try await storage.appendEdge(makeEdge(
            id: "e3", from: "a", to: "b",
            createdAtMs: 300))
        try await storage.appendEdge(makeEdge(
            id: "e1", from: "a", to: "b",
            createdAtMs: 100))
        try await storage.appendEdge(makeEdge(
            id: "e2", from: "a", to: "b",
            createdAtMs: 200))

        let all = await storage.allEdges()
        XCTAssertEqual(all.map { $0.edgeID },
            ["e1", "e2", "e3"])
    }

    // MARK: - Remove cascade

    func testRemoveNodeCascadesIncidentEdges() async throws {
        let storage = try makeStorage()
        try await storage.appendNode(makeNode(id: "a"))
        try await storage.appendNode(makeNode(id: "b"))
        try await storage.appendNode(makeNode(id: "c"))
        try await storage.appendEdge(makeEdge(
            id: "ab", from: "a", to: "b"))
        try await storage.appendEdge(makeEdge(
            id: "ac", from: "a", to: "c"))
        try await storage.appendEdge(makeEdge(
            id: "bc", from: "b", to: "c"))

        let removed = try await storage.removeNode("a")
        XCTAssertTrue(removed)

        let edges = await storage.allEdges()
        XCTAssertEqual(edges.count, 1,
            "Removing 'a' must cascade-delete edges " +
            "ab + ac (incident to 'a'), leaving only bc")
        XCTAssertEqual(edges.first?.edgeID, "bc")
    }

    // MARK: - Preload helper

    func testPreloadIntoInMemoryGraph() async throws {
        let storage = try makeStorage()
        try await storage.appendNode(makeNode(
            id: "n1", label: "n1-label"))
        try await storage.appendNode(makeNode(
            id: "n2", label: "n2-label"))
        try await storage.appendEdge(makeEdge(
            id: "e1", from: "n1", to: "n2",
            kind: .causes))

        let graph = BASKnowledgeGraph()
        let result = await storage.preload(into: graph)

        XCTAssertEqual(result.nodesLoaded, 2)
        XCTAssertEqual(result.edgesLoaded, 1)

        let graphNodeCount = await graph.nodeCount
        XCTAssertEqual(graphNodeCount, 2)
        let graphEdgeCount = await graph.edgeCount
        XCTAssertEqual(graphEdgeCount, 1)
    }

    func testPreloadEmptyStorageReturnsZero() async throws {
        let storage = try makeStorage()
        let graph = BASKnowledgeGraph()
        let result = await storage.preload(into: graph)
        XCTAssertEqual(result.nodesLoaded, 0)
        XCTAssertEqual(result.edgesLoaded, 0)
    }

    // MARK: - Persistence across reopens

    func testPersistenceAcrossReopens() async throws {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("persist.sqlite")

        do {
            let storage1 = try BASSQLiteKnowledgeGraphStorage(
                databaseURL: url)
            try await storage1.appendNode(makeNode(id: "n1"))
            try await storage1.appendNode(makeNode(id: "n2"))
            try await storage1.appendEdge(makeEdge(
                id: "e1", from: "n1", to: "n2"))
            await Task { _ = storage1 }.value
        }

        let storage2 = try BASSQLiteKnowledgeGraphStorage(
            databaseURL: url)
        let nodeCount = await storage2.nodeCount
        XCTAssertEqual(nodeCount, 2)
        let edgeCount = await storage2.edgeCount
        XCTAssertEqual(edgeCount, 1)
    }

    func testPreloadAfterReopenRestoresState() async throws {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("preload-persist.sqlite")

        do {
            let s1 = try BASSQLiteKnowledgeGraphStorage(
                databaseURL: url)
            try await s1.appendNode(makeNode(id: "x"))
            try await s1.appendNode(makeNode(id: "y"))
            try await s1.appendEdge(makeEdge(
                id: "xy", from: "x", to: "y"))
            await Task { _ = s1 }.value
        }

        let s2 = try BASSQLiteKnowledgeGraphStorage(
            databaseURL: url)
        let graph = BASKnowledgeGraph()
        let result = await s2.preload(into: graph)
        XCTAssertEqual(result.nodesLoaded, 2)
        XCTAssertEqual(result.edgesLoaded, 1)

        // The graph must be queryable post-preload
        let xNode = await graph.node(forID: "x")
        XCTAssertNotNil(xNode)
    }

    // MARK: - Schema pin

    func testSchemaVersionConstantPin() {
        XCTAssertEqual(
            BASSQLiteKnowledgeGraphStorage.schemaVersion, 1,
            "Schema version pin: any future migration must " +
            "explicitly bump this + add migration logic")
    }
}
