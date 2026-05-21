// MARK: - BASChapter796L5StoresTests
// chapter 七百九十六 / M2631-M2635
//
// L5 host-constitution version-tree + deletion-manifest store
// tests (InMemory + SQLite + cross-store cold-restart equivalence)。

import XCTest
@testable import BASMemory

final class BASChapter796L5StoresTests: XCTestCase {

    private var tempVersionURL: URL!
    private var tempDeletionURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        let dir = FileManager.default.temporaryDirectory
        tempVersionURL = dir.appendingPathComponent(
            "bas-test-l5-version-\(UUID().uuidString).sqlite")
        tempDeletionURL = dir.appendingPathComponent(
            "bas-test-l5-deletion-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        for url in [tempVersionURL, tempDeletionURL] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - Version tree: in-memory

    func testInMemoryVersionTreeAppend() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let v = makeVersion(id: "v1", parent: nil,
            rollback: true, hash: hash32(0xAA))
        _ = try await store.appendVersion(v)
        let count = await store.count()
        XCTAssertEqual(count, 1)
        let recovered = await store.version(forID: "v1")
        XCTAssertEqual(recovered, v)
    }

    func testInMemoryVersionTreeRollbackPointFilter() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        try await store.bulkInsertVersions([
            makeVersion(id: "v1", parent: nil,
                rollback: true, hash: hash32(0xAA)),
            makeVersion(id: "v2", parent: "v1",
                rollback: false, hash: hash32(0xBB)),
            makeVersion(id: "v3", parent: "v2",
                rollback: true, hash: hash32(0xCC)),
        ])
        let rollbacks = await store.rollbackPoints(
            forVault: "vault-test")
        XCTAssertEqual(rollbacks.map { $0.versionID },
            ["v1", "v3"])
    }

    func testInMemoryVersionTreeRejectsDuplicate() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let v = makeVersion(id: "v-dup", parent: nil,
            rollback: false, hash: hash32(0x11))
        _ = try await store.appendVersion(v)
        do {
            _ = try await store.appendVersion(v)
            XCTFail("expected duplicate throw")
        } catch BASInMemoryHostConstitutionVersionTreeStore
            .StoreError.duplicateVersionID(let id) {
            XCTAssertEqual(id, "v-dup")
        }
    }

    // MARK: - Version tree: SQLite cold restart

    func testSQLiteVersionTreeColdRestart() async throws {
        let versions = [
            makeVersion(id: "v1", parent: nil,
                rollback: true, hash: hash32(0xAA)),
            makeVersion(id: "v2", parent: "v1",
                rollback: false, hash: hash32(0xBB),
                mergedFromJson: "[\"v1\",\"v0\"]"),
        ]
        do {
            let store = try BASSQLiteHostConstitutionVersionTreeStore(
                databaseURL: tempVersionURL)
            for v in versions {
                _ = try await store.appendVersion(v)
            }
        }
        let reopened = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: tempVersionURL)
        let recovered = await reopened.versions(
            forVault: "vault-test")
        XCTAssertEqual(recovered, versions,
            "Version tree cold restart preserves BLOB hash + " +
            "parent_version_id + merged_from_json correctly")
    }

    func testSQLiteVersionTreeCrossMirrorWithInMemory() async throws {
        var versions: [BASHostConstitutionVersionRecord] = []
        for i in 0..<5 {
            versions.append(makeVersion(
                id: "v\(i)",
                parent: i == 0 ? nil : "v\(i - 1)",
                rollback: i % 2 == 0,
                hash: hash32(UInt8(i * 16))))
        }
        let memStore = BASInMemoryHostConstitutionVersionTreeStore()
        let sqlStore = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: tempVersionURL)
        for v in versions {
            _ = try await memStore.appendVersion(v)
            _ = try await sqlStore.appendVersion(v)
        }
        let memQuery = await memStore.versions(forVault: "vault-test")
        let sqlQuery = await sqlStore.versions(forVault: "vault-test")
        XCTAssertEqual(memQuery, sqlQuery)
    }

    // MARK: - Deletion manifest: in-memory

    func testInMemoryDeletionAppend() async throws {
        let store = BASInMemoryHostConstitutionDeletionManifestStore()
        let m = makeDeletion(id: "m1", type: "cascade")
        _ = try await store.appendManifest(m)
        let count = await store.count()
        XCTAssertEqual(count, 1)
    }

    func testInMemoryDeletionTypeFilter() async throws {
        let store = BASInMemoryHostConstitutionDeletionManifestStore()
        for (i, type) in ["cascade", "selective", "cascade", "rollback"].enumerated() {
            _ = try await store.appendManifest(
                makeDeletion(id: "m\(i)", type: type))
        }
        let cascades = await store.manifests(forType: "cascade")
        XCTAssertEqual(cascades.count, 2)
    }

    // MARK: - Deletion manifest: SQLite cold restart

    func testSQLiteDeletionColdRestart() async throws {
        let m = makeDeletion(id: "m-cold",
            type: "selective",
            cascadedRefsJson: "[\"a\",\"b\"]",
            versionRef: "v-parent")
        do {
            let store = try BASSQLiteHostConstitutionDeletionManifestStore(
                databaseURL: tempDeletionURL)
            _ = try await store.appendManifest(m)
        }
        let reopened = try BASSQLiteHostConstitutionDeletionManifestStore(
            databaseURL: tempDeletionURL)
        let recovered = await reopened.manifests(
            forVault: "vault-test")
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0], m)
    }

    func testSQLiteDeletionCrossMirrorWithInMemory() async throws {
        let types = ["cascade", "selective", "rollback"]
        var manifests: [BASHostConstitutionDeletionRecord] = []
        for i in 0..<6 {
            manifests.append(makeDeletion(
                id: "m\(i)", type: types[i % 3]))
        }
        let memStore = BASInMemoryHostConstitutionDeletionManifestStore()
        let sqlStore = try BASSQLiteHostConstitutionDeletionManifestStore(
            databaseURL: tempDeletionURL)
        for m in manifests {
            _ = try await memStore.appendManifest(m)
            _ = try await sqlStore.appendManifest(m)
        }
        let memQuery = await memStore.manifests(forVault: "vault-test")
        let sqlQuery = await sqlStore.manifests(forVault: "vault-test")
        XCTAssertEqual(memQuery, sqlQuery)
    }

    // MARK: - Codable

    func testVersionRecordCodable() throws {
        let v = makeVersion(id: "v-codable", parent: "vp",
            rollback: true, hash: hash32(0xFF))
        let data = try JSONEncoder().encode(v)
        let decoded = try JSONDecoder().decode(
            BASHostConstitutionVersionRecord.self, from: data)
        XCTAssertEqual(decoded, v)
    }

    func testDeletionRecordCodable() throws {
        let m = makeDeletion(id: "m-codable", type: "cascade")
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(
            BASHostConstitutionDeletionRecord.self, from: data)
        XCTAssertEqual(decoded, m)
    }

    // MARK: - Helpers

    private func makeVersion(
        id: String,
        parent: String?,
        rollback: Bool,
        hash: Data,
        mergedFromJson: String? = nil
    ) -> BASHostConstitutionVersionRecord {
        BASHostConstitutionVersionRecord(
            versionID: id,
            vaultID: "vault-test",
            parentVersionID: parent,
            createdAtMs: 1000,
            signatureHash: hash,
            isRollbackPoint: rollback,
            mergedFromJson: mergedFromJson)
    }

    private func makeDeletion(
        id: String,
        type: String,
        cascadedRefsJson: String? = nil,
        versionRef: String? = nil
    ) -> BASHostConstitutionDeletionRecord {
        BASHostConstitutionDeletionRecord(
            manifestID: id,
            vaultID: "vault-test",
            targetRefsJson: "[\"target1\"]",
            deletionType: type,
            appliedAtMs: 2000,
            cascadedRefsJson: cascadedRefsJson,
            versionRef: versionRef)
    }

    private func hash32(_ b: UInt8) -> Data {
        Data(repeating: b, count: 32)
    }
}

// Async-iter convenience for bulk insert
private extension BASInMemoryHostConstitutionVersionTreeStore {
    func bulkInsertVersions(
        _ batch: [BASHostConstitutionVersionRecord]
    ) async throws {
        for v in batch {
            _ = try await appendVersion(v)
        }
    }
}
