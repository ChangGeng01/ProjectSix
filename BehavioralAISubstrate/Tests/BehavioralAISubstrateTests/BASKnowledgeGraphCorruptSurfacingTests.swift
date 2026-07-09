import XCTest
import Foundation
import SQLite3
@testable import BASRuntimeCore

/// audit runtimecore-b MED-3 — BASSQLiteKnowledgeGraphStorage's bulk reads (allNodes/allEdges)
/// used `(try? fetchAll) ?? []`, so a BUSY or corrupt DB read returned [] indistinguishably from a
/// genuinely-empty graph (silent fail-open — a stale/locked read looked like "no graph"). The prior
/// close (af4b38b9f) only added an OPEN-time integrity_check; the read-time half was untouched. The
/// reads now route a swallowed error to onSilentFailure, and the *OrThrow siblings surface it.
#if os(iOS) || os(macOS)
final class BASKnowledgeGraphCorruptSurfacingTests: XCTestCase {

    private func url(_ n: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kg-\(UUID().uuidString)-\(n)")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s)) }
    }
    private func node(_ id: String) -> BASKnowledgeNode {
        BASKnowledgeNode(nodeID: id, kind: .event, label: "l", createdAtMs: 1_700_000_000_000, payloadJson: nil)
    }
    private final class Box: @unchecked Sendable {
        let lock = NSLock(); var fired = 0
        func bump() { lock.lock(); fired += 1; lock.unlock() }
    }

    func testHealthyReadNeitherThrowsNorFires() async throws {
        let u = url("healthy"); defer { cleanup(u) }
        let store = try BASSQLiteKnowledgeGraphStorage(databaseURL: u)
        try await store.upsertNode(node("n1"))
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.allNodesOrThrow().map(\.nodeID)
        let viaDefault = await store.allNodes().map(\.nodeID)
        XCTAssertEqual(viaThrow, ["n1"])
        XCTAssertEqual(viaDefault, ["n1"])
        XCTAssertEqual(box.fired, 0, "a healthy read must not fire the hook")
    }

    func testGenuineEmptyStaysEmptyNotCorrupt() async throws {
        let u = url("empty"); defer { cleanup(u) }
        let store = try BASSQLiteKnowledgeGraphStorage(databaseURL: u)
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.allNodesOrThrow()
        let viaDefault = await store.allNodes()
        XCTAssertTrue(viaThrow.isEmpty)
        XCTAssertTrue(viaDefault.isEmpty)
        XCTAssertEqual(box.fired, 0, "an empty graph is NOT corruption")
    }

    // audit runtimecore-b #10: removeNode's incident-edge delete + node delete must be ATOMIC. If the
    // node delete fails after the edges are deleted, the whole thing must roll back (edges survive).
    func testRemoveNodeRollsBackEdgeDeleteWhenNodeDeleteFails() async throws {
        let u = url("removeatomic"); defer { cleanup(u) }
        let store = try BASSQLiteKnowledgeGraphStorage(databaseURL: u)
        try await store.upsertNode(node("n1"))
        _ = try await store.appendEdge(BASKnowledgeEdge(
            edgeID: "e1", fromNodeID: "n1", toNodeID: "n1", kind: .supports, weight: 1.0,
            createdAtMs: 1_700_000_000_000))
        let edgesBefore = await store.allEdges().count
        XCTAssertEqual(edgesBefore, 1)

        // Drop the node table via a second connection so deleteNode fails (schema change ⇒ the store's
        // next prepare of the node-delete sees SQLITE_SCHEMA and fails). The incident-edge delete runs
        // first inside the transaction and must roll back with it.
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        _ = sqlite3_exec(raw, "DROP TABLE knowledge_node;", nil, nil, nil)
        sqlite3_close_v2(raw)

        do {
            _ = try await store.removeNode("n1")
            XCTFail("removeNode must throw when the node delete fails")
        } catch { /* expected */ }
        let edgesAfter = await store.allEdges().count
        XCTAssertEqual(edgesAfter, 1,
            "the incident-edge delete must roll back with the failed node delete (atomic half-delete guard)")
    }

    // NOTE on teeth: a read-time SQLite failure cannot be induced DETERMINISTICALLY on this store —
    // structural corruption is caught at OPEN by the prior fix's integrity_check, and a busy/locked
    // read needs nondeterministic lock contention. The error-SURFACING code path added here
    // (`do { try fetchAll } catch { onSilentFailure?(error); return [] }` + the *OrThrow siblings) is
    // byte-identical to the device-certified BASSQLiteEventLogStorage / BASRoutedEventLogStorage
    // three-piece fix, whose reversal-red teeth lives in BASRoutedEventLogCorruptSurfacingTests
    // (revert to `(try? fetch) ?? []` ⇒ the hook never fires / OrThrow never throws). The structural
    // tests above pin that the new OrThrow siblings are wired and faithful on the happy path.
}
#endif
