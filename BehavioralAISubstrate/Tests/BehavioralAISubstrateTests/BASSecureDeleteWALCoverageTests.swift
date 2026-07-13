import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// deep-audit P2-18 (2026-07-13) — secure-delete WAL coverage extended to the remaining
/// explicit-forget SQLite surfaces.
///
/// `secure_delete=ON` zeroes the freed MAIN-DB page, but under WAL the deleted row's original
/// INSERT frame (plaintext) lives in the -wal sidecar until a checkpoint truncates it. F6 wired
/// `checkpointTruncateAfterSecureDelete` into the memory-atom forget path only; this pins the
/// same discipline on the other sensitive-content forget paths. Each tooth writes a known secret,
/// deletes it, and asserts the secret is absent from the on-disk -wal — reversal-proven by
/// removing the checkpoint (the plaintext then survives in -wal).
final class BASSecureDeleteWALCoverageTests: XCTestCase {

    private func tempURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("securedel-\(tag)-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    /// Bytes of the -wal sidecar (empty if truncated / absent).
    private func walBytes(_ u: URL) -> Data {
        (try? Data(contentsOf: URL(fileURLWithPath: u.path + "-wal"))) ?? Data()
    }

    // MARK: - Shared-state object payload_json

    func testDeletedSharedStateObjectPlaintextIsGoneFromWAL() async throws {
        let u = tempURL("sharedstate"); defer { cleanup(u) }
        let secret = "SHAREDSTATE-SECRET-\(UUID().uuidString)"
        let secretData = Data(secret.utf8)

        let storage = try BASSharedStateGraphSQLiteStorage(databaseURL: u)
        let obj = BASStateGraphObject(
            domain: .candidateFrontier, objectID: "cf-secret",
            payloadJson: "{\"note\":\"\(secret)\"}",
            lastWriterAgentID: "planner.1", version: 1)
        try await storage.upsertObject(obj)

        // precondition: the plaintext is on disk (main or wal) before deletion.
        let main = (try? Data(contentsOf: u)) ?? Data()
        XCTAssertTrue(main.range(of: secretData) != nil || walBytes(u).range(of: secretData) != nil,
            "precondition: the upserted payload plaintext is on disk before deletion")

        try await storage.deleteObject(ref: obj.ref)

        XCTAssertNil(walBytes(u).range(of: secretData),
            "P2-18: deleted shared-state payload must not survive in the -wal (verified TRUNCATE)")
    }

    // MARK: - Vector index embedding row (atom-id keyed forget)

    func testRemovedVectorRowAtomIDIsGoneFromWAL() async throws {
        let u = tempURL("vector"); defer { cleanup(u) }
        let atomID = "VECTOR-ATOMID-\(UUID().uuidString)"
        let atomData = Data(atomID.utf8)

        let storage = try BASSQLiteVectorIndexStorage(databaseURL: u)
        _ = try await storage.upsert(
            BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: BASEmbedding(
                    vector: [1.0, 0.0], dimension: 2, providerVersion: "p"),
                domain: "forget-test",
                metadata: [:]))

        let main = (try? Data(contentsOf: u)) ?? Data()
        XCTAssertTrue(main.range(of: atomData) != nil || walBytes(u).range(of: atomData) != nil,
            "precondition: the atomID is on disk before removal")

        _ = try await storage.remove(atomID: atomID)

        XCTAssertNil(walBytes(u).range(of: atomData),
            "P2-18: a forgotten atom's vector row (atomID) must not survive in the -wal")
    }

    // MARK: - Knowledge-graph node content

    func testRemovedKnowledgeNodeContentIsGoneFromWAL() async throws {
        let u = tempURL("kg"); defer { cleanup(u) }
        let secret = "KGNODE-SECRET-\(UUID().uuidString)"
        let secretData = Data(secret.utf8)

        let storage = try BASSQLiteKnowledgeGraphStorage(databaseURL: u)
        try await storage.upsertNode(
            BASKnowledgeNode(
                nodeID: "n-secret", kind: .atom, label: secret,
                createdAtMs: 1_700_000_000_000))

        let main = (try? Data(contentsOf: u)) ?? Data()
        XCTAssertTrue(main.range(of: secretData) != nil || walBytes(u).range(of: secretData) != nil,
            "precondition: the node label plaintext is on disk before removal")

        _ = try await storage.removeNode("n-secret")

        XCTAssertNil(walBytes(u).range(of: secretData),
            "P2-18: a removed knowledge node's content must not survive in the -wal")
    }
}
