import XCTest
@testable import BASMemory

/// chapter 二百四十九 / M736 — SQLite-backed
/// `BASHostConstitutionVault` persistence coverage.
///
/// Pre-chapter 二百四十九 the L5 host vault lived only in actor
/// state — every session boot rebuilt the vault from scratch,
/// every save was a value-type snapshot in memory. This suite
/// verifies that `BASHostConstitutionSQLiteStorage`:
///
///   1. Round-trips `BASHostConstitutionVault` byte-for-byte
///      (every field on the vault + the snapshot it wraps).
///   2. Persists across instance close/reopen — the cross-session
///      continuity invariant附录 V Stage 0 was designed to deliver.
///   3. Real-deletes (not tombstones) per chapter 一百二 五级删除
///      doctrine. Domain-level cascading lives in the host runtime
///      via `BASHostDeletionManifest`; the storage handles the
///      terminal level.
final class BASHostConstitutionSQLiteStorageTests: XCTestCase {

    // MARK: - Fixtures

    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-host-vault-test-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    private func makeVault(
        hostID: String = "host.alpha",
        activeVersion: String = "host.v1"
    ) -> BASHostConstitutionVault {
        let snapshot = BASHostConstitution(
            hostID: hostID,
            activeVersion: activeVersion)
        let report = BASHostDeviceConsistencyReport(
            sourceDeviceID: "device.alpha")
        return BASHostConstitutionVault(
            constitutionSnapshot: snapshot,
            deviceConsistencyReport: report)
    }

    // MARK: - 1. Empty store

    func testEmptyInitCreatesEmptyVaultStore() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let count = await store.vaultCount
        XCTAssertEqual(count, 0)
        let ids = await store.allVaultIDs
        XCTAssertEqual(ids, [])
    }

    // MARK: - 2. loadVault returns nil for missing

    func testLoadVaultMissReturnsNil() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let result = try await store.loadVault(
            vaultID: "no-such-vault")
        XCTAssertNil(result)
    }

    // MARK: - 3. save + loadVault round-trip

    func testSaveThenLoadReturnsEqualVault() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let vault = makeVault()
        let isNew = try await store.save(vault)
        XCTAssertTrue(isNew)

        let fetched = try await store.loadVault(
            vaultID: vault.vaultID)
        XCTAssertEqual(fetched, vault)
    }

    // MARK: - 4. Cross-session persistence (THE KEY TEST)

    /// Crystallizes 附录 V Stage 0's contract: close + reopen
    /// preserves every saved vault byte-for-byte.
    func testCrossSessionPersistenceSurvivesReopen()
        async throws
    {
        let v1 = makeVault(hostID: "host.alpha")
        let v2 = makeVault(hostID: "host.beta")

        // Session 1 — write + close
        do {
            let store = try BASHostConstitutionSQLiteStorage(
                databaseURL: tempURL)
            try await store.save(v1)
            try await store.save(v2)
            let count1 = await store.vaultCount
            XCTAssertEqual(count1, 2)
        }

        // Session 2 — reopen + verify
        let store2 = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let count2 = await store2.vaultCount
        XCTAssertEqual(count2, 2)

        let fetched1 = try await store2.loadVault(
            vaultID: v1.vaultID)
        let fetched2 = try await store2.loadVault(
            vaultID: v2.vaultID)
        XCTAssertEqual(fetched1, v1)
        XCTAssertEqual(fetched2, v2)
    }

    // MARK: - 5. Updated-vault overwrites prior

    func testReSaveReplacesPriorVault() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let v1 = makeVault(activeVersion: "host.v1")
        let v2 = BASHostConstitutionVault(
            vaultID: v1.vaultID,
            constitutionSnapshot: BASHostConstitution(
                constitutionID:
                    v1.constitutionSnapshot.constitutionID,
                hostID: v1.constitutionSnapshot.hostID,
                activeVersion: "host.v2"),
            deviceConsistencyReport:
                v1.deviceConsistencyReport)

        let firstNew = try await store.save(v1)
        XCTAssertTrue(firstNew)
        let secondNew = try await store.save(v2)
        XCTAssertFalse(secondNew)

        let fetched = try await store.loadVault(
            vaultID: v1.vaultID)
        XCTAssertEqual(
            fetched?.constitutionSnapshot.activeVersion,
            "host.v2")
        let count = await store.vaultCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - 6. remove returns prior + real DELETE

    func testRemoveReturnsPriorValueAndDeletes() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let vault = makeVault()
        try await store.save(vault)

        let removed = await store.remove(vaultID: vault.vaultID)
        XCTAssertEqual(removed, vault)

        let after = try await store.loadVault(
            vaultID: vault.vaultID)
        XCTAssertNil(after)
        let count = await store.vaultCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - 7. remove on missing returns nil

    func testRemoveMissReturnsNil() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let removed = await store.remove(vaultID: "no-such-vault")
        XCTAssertNil(removed)
    }

    // MARK: - 8. Real DELETE survives reopen

    func testRemoveSurvivesReopen() async throws {
        let vault = makeVault()
        do {
            let store = try BASHostConstitutionSQLiteStorage(
                databaseURL: tempURL)
            try await store.save(vault)
            _ = await store.remove(vaultID: vault.vaultID)
        }

        let reopened = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let fetched = try await reopened.loadVault(
            vaultID: vault.vaultID)
        XCTAssertNil(fetched)
        let count = await reopened.vaultCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - 9. loadFirstVault by hostID

    func testLoadFirstVaultByHostID() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let vAlpha = makeVault(hostID: "host.alpha")
        let vBeta = makeVault(hostID: "host.beta")
        try await store.save(vAlpha)
        try await store.save(vBeta)

        let alphaFetched = try await store.loadFirstVault(
            forHostID: "host.alpha")
        XCTAssertEqual(alphaFetched, vAlpha)

        let betaFetched = try await store.loadFirstVault(
            forHostID: "host.beta")
        XCTAssertEqual(betaFetched, vBeta)

        let missing = try await store.loadFirstVault(
            forHostID: "host.gamma")
        XCTAssertNil(missing)
    }

    // MARK: - 10. loadAll returns insertion order

    func testLoadAllReturnsAllVaultsOrderedByLastUpdate()
        async throws
    {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let v1 = makeVault(hostID: "host.first")
        try await store.save(v1)
        try await Task.sleep(nanoseconds: 5_000_000)
        let v2 = makeVault(hostID: "host.second")
        try await store.save(v2)
        try await Task.sleep(nanoseconds: 5_000_000)
        let v3 = makeVault(hostID: "host.third")
        try await store.save(v3)

        let all = try await store.loadAll()
        XCTAssertEqual(
            all.map { $0.constitutionSnapshot.hostID },
            ["host.first", "host.second", "host.third"])
    }

    // MARK: - 11. allVaultIDs reflects multi-host install

    func testAllVaultIDsReflectsAllSavedVaults() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let v1 = makeVault(hostID: "host.a")
        let v2 = makeVault(hostID: "host.b")
        let v3 = makeVault(hostID: "host.c")
        try await store.save(v1)
        try await store.save(v2)
        try await store.save(v3)

        let ids = await store.allVaultIDs
        XCTAssertEqual(ids, [
            v1.vaultID, v2.vaultID, v3.vaultID
        ])
    }

    // MARK: - 12. Mutation survives reopen

    func testActiveVersionMutationSurvivesReopen()
        async throws
    {
        let v1 = makeVault(activeVersion: "host.v1")
        do {
            let store = try BASHostConstitutionSQLiteStorage(
                databaseURL: tempURL)
            try await store.save(v1)

            let v1Updated = BASHostConstitutionVault(
                vaultID: v1.vaultID,
                constitutionSnapshot: BASHostConstitution(
                    constitutionID:
                        v1.constitutionSnapshot.constitutionID,
                    hostID: v1.constitutionSnapshot.hostID,
                    activeVersion: "host.v2-rolled-forward"),
                deviceConsistencyReport:
                    v1.deviceConsistencyReport)
            try await store.save(v1Updated)
        }

        let reopened = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let fetched = try await reopened.loadVault(
            vaultID: v1.vaultID)
        XCTAssertEqual(
            fetched?.constitutionSnapshot.activeVersion,
            "host.v2-rolled-forward")
    }

    // MARK: - 13. Schema version pin

    func testSchemaVersionConstantIsOne() {
        XCTAssertEqual(
            BASHostConstitutionSQLiteStorage.schemaVersion, 1)
    }

    // MARK: - 14. Vault with deletion manifest survives round-trip

    /// Verifies the `BASHostDeletionManifest` Codable surface
    /// round-trips through SQLite — chapter 一百二 五级删除
    /// doctrine pins this manifest as the host-level cascade
    /// descriptor; storage must preserve it byte-for-byte across
    /// sessions so the host runtime can resume the cascade after
    /// crash recovery.
    func testVaultWithDeletionManifestRoundTrips() async throws {
        let store = try BASHostConstitutionSQLiteStorage(
            databaseURL: tempURL)
        let baseSnapshot = BASHostConstitution(hostID: "host.x")
        let manifest = BASHostDeletionManifest(
            requestID: "forget-1",
            targetRefs: ["memory.atom.x", "memory.atom.y"],
            revokedProjectionRefs: ["projection.x"],
            invalidatedExportRefs: [
                "sync_exports:forget-1"
            ],
            pendingPropagationRefs: ["device.secondary"],
            verified: false)
        let report = BASHostDeviceConsistencyReport(
            sourceDeviceID: "device.x")
        let vault = BASHostConstitutionVault(
            constitutionSnapshot: baseSnapshot,
            deletionManifest: manifest,
            deviceConsistencyReport: report)
        try await store.save(vault)

        let fetched = try await store.loadVault(
            vaultID: vault.vaultID)
        XCTAssertEqual(fetched?.deletionManifest, manifest)
    }
}
