// MARK: - BASChapter801L5HostConstitutionRecordingActivationTests
// chapter 八百一 / M2656-M2660
//
// Verifies the L5 version-tree + deletion-manifest recorder
// activation against the L5 storage adapters (chapter 七百九十六)。
//
// Six invariants pinned:
//
//   1. `recordVersion(...)` computes signature_hash as SHA-256
//      of the supplied canonical bytes (byte-identical to a
//      direct CryptoKit hash) and persists with the supplied
//      lineage fields。
//   2. `mergedFromVersionIDs` encodes as JSON array when non-
//      empty;nil / [] both round-trip as nil in the column
//      (schema 014 "not a merge" semantics)。
//   3. Genesis versions (no parent) round-trip with
//      parentVersionID == nil。
//   4. `recordDeletion(...)` validates the deletion-type enum
//      against schema 015 CHECK literals (cascade / selective /
//      rollback) and encodes target/cascade refs as JSON arrays。
//   5. Optional cascadedRefs / versionRef stay nil in the column
//      when not supplied。
//   6. SQLite cold-restart through BOTH stores preserves every
//      field including the 32-byte signature hash and the
//      stored JSON ref lists。

import XCTest
import CryptoKit
@testable import BASMemory

final class BASChapter801L5HostConstitutionRecordingActivationTests: XCTestCase {

    private var versionTreeDB: URL!
    private var deletionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        versionTreeDB = tmp.appendingPathComponent(
            "bas-test-version-tree-\(token).sqlite")
        deletionDB = tmp.appendingPathComponent(
            "bas-test-deletion-\(token).sqlite")
    }

    override func tearDown() async throws {
        for url in [versionTreeDB, deletionDB] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - Version tree recorder

    func testRecordVersionComputesSHA256SignatureHash() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let canonicalBytes = Data("doctrine v1 canonical bytes".utf8)
        let expectedHash = Data(SHA256.hash(data: canonicalBytes))

        let recorded = try await BASRoutedHostConstitutionRecording
            .recordVersion(
                versionID: "v1",
                vaultID: "vault-A",
                parentVersionID: nil,
                canonicalBytes: canonicalBytes,
                createdAtMs: 100,
                isRollbackPoint: false,
                mergedFromVersionIDs: nil,
                store: store)

        XCTAssertEqual(recorded.versionID, "v1")
        XCTAssertEqual(recorded.vaultID, "vault-A")
        XCTAssertNil(recorded.parentVersionID,
            "Genesis version persists parentVersionID as nil")
        XCTAssertEqual(recorded.signatureHash.count, 32,
            "SHA-256 → 32 raw bytes")
        XCTAssertEqual(recorded.signatureHash, expectedHash,
            "signature_hash byte-identical to direct CryptoKit hash")
        XCTAssertFalse(recorded.isRollbackPoint)
        XCTAssertNil(recorded.mergedFromJson)
    }

    func testRecordVersionMergedFromEncodesAsJSONArray() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordVersion(
                versionID: "v-merge",
                vaultID: "vault",
                parentVersionID: "v-base",
                canonicalBytes: Data(),
                createdAtMs: 1,
                mergedFromVersionIDs: ["v-a", "v-b"],
                store: store)
        XCTAssertEqual(recorded.mergedFromJson, #"["v-a","v-b"]"#,
            "merged_from list encodes as compact JSON array")
    }

    func testRecordVersionEmptyMergedFromStoresAsNil() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordVersion(
                versionID: "v-empty",
                vaultID: "vault",
                canonicalBytes: Data(),
                createdAtMs: 1,
                mergedFromVersionIDs: [],
                store: store)
        XCTAssertNil(recorded.mergedFromJson,
            "Empty merged_from → nil (schema 014 semantic: not a merge)")
    }

    func testRecordVersionRollbackPointFlagPropagates() async throws {
        let store = BASInMemoryHostConstitutionVersionTreeStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordVersion(
                versionID: "v-rb",
                vaultID: "vault",
                canonicalBytes: Data([0x42]),
                createdAtMs: 1,
                isRollbackPoint: true,
                store: store)
        XCTAssertTrue(recorded.isRollbackPoint)
        let pinned = await store.rollbackPoints(forVault: "vault")
        XCTAssertEqual(pinned, [recorded])
    }

    // MARK: - Deletion manifest recorder

    func testRecordDeletionEncodesTargetRefsAsJSONArray() async throws {
        let store = BASInMemoryHostConstitutionDeletionManifestStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordDeletion(
                manifestID: "m-1",
                vaultID: "vault",
                targetRefs: ["ref-a", "ref-b", "ref-c"],
                deletionType: .selective,
                appliedAtMs: 100,
                store: store)
        XCTAssertEqual(recorded.targetRefsJson,
            #"["ref-a","ref-b","ref-c"]"#)
        XCTAssertEqual(recorded.deletionType, "selective",
            "Schema 015 CHECK literal preserved via enum rawValue")
        XCTAssertNil(recorded.cascadedRefsJson)
        XCTAssertNil(recorded.versionRef)
    }

    func testRecordDeletionCascadePersistsCascadedRefs() async throws {
        let store = BASInMemoryHostConstitutionDeletionManifestStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordDeletion(
                manifestID: "m-2",
                vaultID: "vault",
                targetRefs: ["root"],
                deletionType: .cascade,
                appliedAtMs: 1,
                cascadedRefs: ["leaf-1", "leaf-2"],
                versionRef: nil,
                store: store)
        XCTAssertEqual(recorded.deletionType, "cascade")
        XCTAssertEqual(recorded.cascadedRefsJson,
            #"["leaf-1","leaf-2"]"#)
    }

    func testRecordDeletionRollbackBindsVersionRef() async throws {
        let store = BASInMemoryHostConstitutionDeletionManifestStore()
        let recorded = try await BASRoutedHostConstitutionRecording
            .recordDeletion(
                manifestID: "m-3",
                vaultID: "vault",
                targetRefs: ["v-current"],
                deletionType: .rollback,
                appliedAtMs: 2,
                cascadedRefs: nil,
                versionRef: "v-target",
                store: store)
        XCTAssertEqual(recorded.deletionType, "rollback")
        XCTAssertEqual(recorded.versionRef, "v-target")
        XCTAssertNil(recorded.cascadedRefsJson,
            "Rollback typically has no cascade list")
    }

    func testDeletionTypeEnumExhaustiveAgainstSchemaCHECK() {
        let allRaw = BASRoutedHostConstitutionRecording
            .DeletionType.allCases.map { $0.rawValue }
        XCTAssertEqual(Set(allRaw),
                       Set(["cascade", "selective", "rollback"]),
            "DeletionType cases must match schema 015 CHECK exactly")
    }

    // MARK: - SQLite cold-restart

    func testBothRecordersSurviveSQLiteColdRestart() async throws {
        let canonicalBytes = Data(
            "cold restart canonical bytes — chapter 八百一".utf8)
        let expectedHash = Data(SHA256.hash(data: canonicalBytes))

        // Write through fresh actors
        do {
            let vStore = try BASSQLiteHostConstitutionVersionTreeStore(
                databaseURL: versionTreeDB)
            let dStore = try BASSQLiteHostConstitutionDeletionManifestStore(
                databaseURL: deletionDB)
            _ = try await BASRoutedHostConstitutionRecording
                .recordVersion(
                    versionID: "v-cold",
                    vaultID: "vault-cold",
                    parentVersionID: "v-prior",
                    canonicalBytes: canonicalBytes,
                    createdAtMs: 1_000,
                    isRollbackPoint: true,
                    mergedFromVersionIDs: ["v-a", "v-b"],
                    store: vStore)
            _ = try await BASRoutedHostConstitutionRecording
                .recordDeletion(
                    manifestID: "m-cold",
                    vaultID: "vault-cold",
                    targetRefs: ["ref-x", "ref-y"],
                    deletionType: .cascade,
                    appliedAtMs: 2_000,
                    cascadedRefs: ["ref-leaf"],
                    versionRef: "v-cold",
                    store: dStore)
        }

        // Reopen both stores from disk
        let vReopen = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: versionTreeDB)
        let dReopen = try BASSQLiteHostConstitutionDeletionManifestStore(
            databaseURL: deletionDB)

        let restoredVersion = await vReopen.version(forID: "v-cold")
        XCTAssertNotNil(restoredVersion)
        XCTAssertEqual(restoredVersion?.signatureHash, expectedHash,
            "32-byte BLOB signature_hash survives cold restart")
        XCTAssertEqual(restoredVersion?.parentVersionID, "v-prior")
        XCTAssertTrue(restoredVersion?.isRollbackPoint ?? false)
        XCTAssertEqual(restoredVersion?.mergedFromJson,
            #"["v-a","v-b"]"#)

        let restoredManifests = await dReopen.manifests(
            forVault: "vault-cold")
        XCTAssertEqual(restoredManifests.count, 1)
        XCTAssertEqual(restoredManifests[0].deletionType, "cascade")
        XCTAssertEqual(restoredManifests[0].targetRefsJson,
            #"["ref-x","ref-y"]"#)
        XCTAssertEqual(restoredManifests[0].cascadedRefsJson,
            #"["ref-leaf"]"#)
        XCTAssertEqual(restoredManifests[0].versionRef, "v-cold")
    }
}
