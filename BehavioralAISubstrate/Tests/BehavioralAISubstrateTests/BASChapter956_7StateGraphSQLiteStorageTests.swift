// MARK: - BASChapter956_7StateGraphSQLiteStorageTests
// chapter 九百五十六.7 / M3485.7
//
// SQLite persistence tests for `BASSharedStateGraph`。 Cover:
//   - Standalone SQLite adapter CRUD (object + writer)
//   - Write-through from graph actor (writeObject → persisted row)
//   - Auto-claim write-through (writeObject auto-claims → persisted)
//   - Explicit registerWriter write-through
//   - Hydration from disk (close graph,reopen storage,hydrate
//     graph,verify in-memory state matches)
//   - Schema version mismatch error path
//   - Idempotent upsert (re-write same ref → row replaced)
//
// Per user directive「继续 提高 Metal sql rust c c++ 比例」 these
// tests prove the SQL adapter is wired correctly and that the
// in-memory + on-disk states agree。

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter956_7StateGraphSQLiteStorageTests:
    XCTestCase
{

    // MARK: - Tmp DB helper

    private func tempDBURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-ch956.7-\(UUID().uuidString)",
                isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).sqlite")
    }

    private func cleanup(_ url: URL) {
        let parent = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }

    private func makeAgent(
        id: String,
        write: [BASStateDomain] = [.candidateFrontier]
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id,
            role: .planner,
            writeDomains: write,
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    // MARK: - Standalone storage CRUD

    func testStorage_UpsertAndLoadObject() async throws {
        let url = tempDBURL(name: "upsert")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let obj = BASStateGraphObject(
            domain: .candidateFrontier,
            objectID: "cf-1",
            payloadJson: "{\"v\":1}",
            lastWriterAgentID: "planner.1",
            version: 1)
        try await storage.upsertObject(obj)
        let loaded = try await storage.loadObject(ref: obj.ref)
        XCTAssertEqual(loaded, obj,
            "ch 956.7: upsert+load round-trips identically")
    }

    func testStorage_UpsertReplacesByRef() async throws {
        let url = tempDBURL(name: "replace")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let v1 = BASStateGraphObject(
            domain: .riskField, objectID: "rf-1",
            payloadJson: "{\"v\":1}",
            lastWriterAgentID: "risk.1", version: 1)
        let v2 = BASStateGraphObject(
            domain: .riskField, objectID: "rf-1",
            payloadJson: "{\"v\":2}",
            lastWriterAgentID: "risk.1", version: 2)
        try await storage.upsertObject(v1)
        try await storage.upsertObject(v2)
        let loaded = try await storage.loadObject(ref: v1.ref)
        XCTAssertEqual(loaded?.version, 2,
            "ch 956.7: upsert MUST replace by ref")
        XCTAssertEqual(loaded?.payloadJson, "{\"v\":2}")
        let count = await storage.objectCount
        XCTAssertEqual(count, 1,
            "ch 956.7: upsert replaces — count stays 1")
    }

    func testStorage_DeleteObject() async throws {
        let url = tempDBURL(name: "del")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let obj = BASStateGraphObject(
            domain: .memoryBundle, objectID: "mb-1",
            payloadJson: "{}", lastWriterAgentID: "mem.1",
            version: 1)
        try await storage.upsertObject(obj)
        try await storage.deleteObject(ref: obj.ref)
        let loaded = try await storage.loadObject(ref: obj.ref)
        XCTAssertNil(loaded, "ch 956.7: delete removes row")
        // Idempotent — deleting absent ref is success
        try await storage.deleteObject(ref: obj.ref)
        try await storage.deleteObject(ref: "never#existed")
    }

    func testStorage_WriterRegistryCRUD() async throws {
        let url = tempDBURL(name: "writers")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        try await storage.upsertWriter(
            domain: .candidateFrontier, agentID: "planner.1")
        try await storage.upsertWriter(
            domain: .riskField, agentID: "risk.1")
        let all = try await storage.loadAllWriters()
        XCTAssertEqual(all.count, 2)
        let asMap = Dictionary(
            uniqueKeysWithValues:
                all.map { ($0.domain, $0.agentID) })
        XCTAssertEqual(asMap[.candidateFrontier], "planner.1")
        XCTAssertEqual(asMap[.riskField], "risk.1")
        // Re-register same agent for same domain — idempotent
        try await storage.upsertWriter(
            domain: .candidateFrontier, agentID: "planner.1")
        let count = await storage.writerCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - Schema version mismatch

    func testStorage_SchemaVersionMismatchRejects() throws {
        let url = tempDBURL(name: "schema")
        defer { cleanup(url) }
        // Open + write a junk user_version,then re-open expects fail
        do {
            let storage = try BASSharedStateGraphSQLiteStorage(
                databaseURL: url)
            _ = storage  // open succeeds — sets user_version=1
        }
        // Manually mutate user_version to a different value
        // by opening a sibling connection
        var handle: OpaquePointer?
        let openRC = sqlite3_open_v2(
            url.path, &handle,
            SQLITE_OPEN_READWRITE, nil)
        XCTAssertEqual(openRC, SQLITE_OK)
        var errMsg: UnsafeMutablePointer<CChar>?
        sqlite3_exec(
            handle, "PRAGMA user_version=99",
            nil, nil, &errMsg)
        if let errMsg { sqlite3_free(errMsg) }
        sqlite3_close_v2(handle)
        // Now re-open through our storage — must throw
        XCTAssertThrowsError(
            try BASSharedStateGraphSQLiteStorage(
                databaseURL: url),
            "ch 956.7: schema mismatch MUST throw"
        ) { error in
            guard case .schemaVersionMismatch(let found, _) =
                error as? BASSharedStateGraphSQLiteStorage
                    .StorageError
            else {
                XCTFail("expected schemaVersionMismatch")
                return
            }
            XCTAssertEqual(found, 99)
        }
    }

    // MARK: - Graph write-through

    func testGraph_WriteThroughPersistsObject() async throws {
        let url = tempDBURL(name: "wt-obj")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let graph = BASSharedStateGraph(storage: storage)
        let agent = makeAgent(id: "planner.1")
        _ = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-7",
            payloadJson: "{\"frontier\":\"v3\"}",
            byAgent: agent)
        // Sibling storage handle reads the persisted row
        let storage2 = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let persisted = try await storage2.loadObject(
            ref: "candidateFrontier#cf-7")
        XCTAssertNotNil(persisted,
            "ch 956.7: writeObject MUST write-through to SQL")
        XCTAssertEqual(persisted?.payloadJson,
            "{\"frontier\":\"v3\"}")
        XCTAssertEqual(persisted?.lastWriterAgentID, "planner.1")
        XCTAssertEqual(persisted?.version, 1)
    }

    func testGraph_AutoClaimWritesWriterRow() async throws {
        let url = tempDBURL(name: "wt-claim")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let graph = BASSharedStateGraph(storage: storage)
        let agent = makeAgent(id: "planner.1")
        _ = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1", payloadJson: "{}",
            byAgent: agent)
        // Storage should now have the claim recorded
        let storage2 = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let writers = try await storage2.loadAllWriters()
        XCTAssertEqual(writers.count, 1)
        XCTAssertEqual(writers[0].domain, .candidateFrontier)
        XCTAssertEqual(writers[0].agentID, "planner.1")
    }

    func testGraph_ExplicitRegisterWriterPersists() async throws {
        let url = tempDBURL(name: "wt-reg")
        defer { cleanup(url) }
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let graph = BASSharedStateGraph(storage: storage)
        try await graph.registerWriter(
            agentID: "risk.1", domain: .riskField)
        let storage2 = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let writers = try await storage2.loadAllWriters()
        XCTAssertEqual(writers.count, 1)
        XCTAssertEqual(writers[0].agentID, "risk.1")
    }

    // MARK: - Hydration

    func testGraph_HydrateRebuildsInMemoryState() async throws {
        let url = tempDBURL(name: "hydrate")
        defer { cleanup(url) }
        // Session 1: write some state via storage
        do {
            let storage = try BASSharedStateGraphSQLiteStorage(
                databaseURL: url)
            let graph = BASSharedStateGraph(storage: storage)
            let planner = makeAgent(id: "planner.1")
            let risk = makeAgent(
                id: "risk.1",
                write: [.riskField])
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-1",
                payloadJson: "{\"v\":1}",
                byAgent: planner)
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-2",
                payloadJson: "{\"v\":2}",
                byAgent: planner)
            _ = try await graph.writeObject(
                domain: .riskField,
                objectID: "rf-1",
                payloadJson: "{\"alarm\":\"low\"}",
                byAgent: risk)
        }
        // Session 2: reopen storage,hydrate fresh graph,verify
        let storage = try BASSharedStateGraphSQLiteStorage(
            databaseURL: url)
        let graph = BASSharedStateGraph(storage: storage)
        try await graph.hydrate()
        let count = await graph.objectCount()
        XCTAssertEqual(count, 3,
            "ch 956.7: hydrate must load all 3 objects")
        let cfV = await graph.domainVersion(.candidateFrontier)
        XCTAssertEqual(cfV, 2,
            "ch 956.7: hydrate must restore max version per " +
            "domain (cf-1 v=1,cf-2 v=2 → domainVersion=2)")
        let rfV = await graph.domainVersion(.riskField)
        XCTAssertEqual(rfV, 1)
        let cfWriter = await graph.writerForDomain(
            .candidateFrontier)
        XCTAssertEqual(cfWriter, "planner.1",
            "ch 956.7: hydrate must restore writer registry")
        let rfWriter = await graph.writerForDomain(.riskField)
        XCTAssertEqual(rfWriter, "risk.1")
        // Single-Writer enforcement post-hydrate: a second agent
        // attempting to write candidateFrontier MUST be rejected
        let imposter = makeAgent(id: "planner.imposter")
        do {
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-3", payloadJson: "{}",
                byAgent: imposter)
            XCTFail("ch 956.7: post-hydrate Single-Writer must " +
                "reject imposter")
        } catch let e as BASSharedStateGraphError {
            guard case .writerIdentityMismatch = e else {
                XCTFail("expected writerIdentityMismatch,got \(e)")
                return
            }
        }
    }

    // MARK: - No-storage path stays byte-equal

    func testGraph_NoStorageInMemoryUnchanged() async throws {
        // Without storage arg,graph behaves identically to ch 954
        let graph = BASSharedStateGraph()  // default nil storage
        let agent = makeAgent(id: "planner.1")
        let obj = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1", payloadJson: "{}",
            byAgent: agent)
        XCTAssertEqual(obj.version, 1)
        let count = await graph.objectCount()
        XCTAssertEqual(count, 1)
        // Hydrate is a no-op without storage
        try await graph.hydrate()
        let count2 = await graph.objectCount()
        XCTAssertEqual(count2, 1,
            "ch 956.7: hydrate without storage MUST be no-op")
    }
}

// SQLite functions used by the schema-mismatch test
import SQLite3
