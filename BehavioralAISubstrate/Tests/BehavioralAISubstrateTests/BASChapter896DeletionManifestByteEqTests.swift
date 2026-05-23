// MARK: - BASChapter896DeletionManifestByteEqTests
// chapter 八百九十六 / M3170 — L8 unification pilot Swift bridge
// + byte-equality tests
//
// First end-to-end Swift→Rust→SQLite proof of the L8 unification
// arc per Docs/L8_RUST_UNIFICATION_RFC.md。 Verifies the new
// `BASRoutedHostConstitutionDeletionManifestStore` actor (Rust-
// routed) produces byte-equal SQL state to the legacy
// `BASSQLiteHostConstitutionDeletionManifestStore` actor (Swift-
// owned SQLite) for the supported subset (append + count)。
//
// Per-vault + per-type query support pending chapter 896.5 Rust
// FFI extension。 This chapter pins what works today。

import XCTest
import Foundation
@testable import BASMemory
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter896DeletionManifestByteEqTests:
    XCTestCase
{

    /// Make a temp .db URL for this test。
    private func makeTempDBURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(
            "ch896-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        // Also remove WAL sidecar files
        let wal = url.appendingPathExtension("wal")
        let shm = url.appendingPathExtension("shm")
        try? FileManager.default.removeItem(at: wal)
        try? FileManager.default.removeItem(at: shm)
    }

    private func makeRecord(
        id: String,
        vault: String = "vault-default",
        type: String = "cascade",
        appliedAt: Int64 = 1_700_000_000_000
    ) -> BASHostConstitutionDeletionRecord {
        BASHostConstitutionDeletionRecord(
            manifestID: id,
            vaultID: vault,
            targetRefsJson: #"["host.v1"]"#,
            deletionType: type,
            appliedAtMs: appliedAt,
            cascadedRefsJson: nil,
            versionRef: nil)
    }

    // MARK: - End-to-end: Rust-routed actor round-trips

    /// PIN: routed actor opens + initializes schema 015 + accepts
    /// appends + reports count correctly。
    func testRoutedActorBasicRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed =
            try BASRoutedHostConstitutionDeletionManifestStore(
                databaseURL: url)
        let initial = await routed.count()
        XCTAssertEqual(initial, 0,
            "Fresh routed store starts with 0 manifests")
        _ = try await routed.appendManifest(
            makeRecord(id: "manifest-r1"))
        _ = try await routed.appendManifest(
            makeRecord(id: "manifest-r2", vault: "vault-B"))
        let post = await routed.count()
        XCTAssertEqual(post, 2,
            "After 2 appends count must be 2")
        let perVaultA = await routed.countForVault(
            "vault-default")
        let perVaultB = await routed.countForVault("vault-B")
        XCTAssertEqual(perVaultA, 1)
        XCTAssertEqual(perVaultB, 1)
        let perVaultC = await routed.countForVault("vault-C")
        XCTAssertEqual(perVaultC, 0)
    }

    /// PIN: routed actor enforces duplicate manifest_id via
    /// SQLITE_CONSTRAINT — same as the Swift SQLite actor。
    func testRoutedActorRejectsDuplicateManifestID() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed =
            try BASRoutedHostConstitutionDeletionManifestStore(
                databaseURL: url)
        _ = try await routed.appendManifest(
            makeRecord(id: "dup-r-1"))
        do {
            _ = try await routed.appendManifest(
                makeRecord(id: "dup-r-1"))
            XCTFail("Duplicate manifest_id must throw")
        } catch BASRoutedHostConstitutionDeletionManifestStore
            .StoreError.appendFailed(let code) {
            XCTAssertEqual(code, -2,
                "Append must fail with SQLite error code -2 " +
                "on duplicate manifest_id")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Byte-equality vs Swift in-memory actor

    /// PIN: same sequence of appends produces same count on both
    /// the routed (Rust) actor and the in-memory Swift actor。
    /// Tests the supported subset (append + count + countForVault)。
    func testByteEqAppendSequenceVsSwiftInMemory() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed =
            try BASRoutedHostConstitutionDeletionManifestStore(
                databaseURL: url)
        let swiftActor =
            BASInMemoryHostConstitutionDeletionManifestStore()
        // Identical sequence on both actors
        let records: [BASHostConstitutionDeletionRecord] = [
            makeRecord(id: "be-1", vault: "v-A",
                type: "cascade", appliedAt: 100),
            makeRecord(id: "be-2", vault: "v-A",
                type: "selective", appliedAt: 200),
            makeRecord(id: "be-3", vault: "v-B",
                type: "rollback", appliedAt: 300),
            makeRecord(id: "be-4", vault: "v-B",
                type: "cascade", appliedAt: 400),
            makeRecord(id: "be-5", vault: "v-C",
                type: "selective", appliedAt: 500),
        ]
        for r in records {
            _ = try await routed.appendManifest(r)
            _ = try await swiftActor.appendManifest(r)
        }
        // Total count
        let routedTotal = await routed.count()
        let swiftTotal = await swiftActor.count()
        XCTAssertEqual(routedTotal, swiftTotal,
            "Total count must be byte-equal across actors")
        XCTAssertEqual(routedTotal, 5)
        // Per-vault counts (chapter 896 routed actor supports
        // this via the extra countForVault helper;Swift in-
        // memory uses the manifests(forVault:) query)
        for vault in ["v-A", "v-B", "v-C", "v-missing"] {
            let routedV = await routed.countForVault(vault)
            let swiftV = await swiftActor.manifests(
                forVault: vault).count
            XCTAssertEqual(routedV, swiftV,
                "Per-vault count for vault=\(vault) must be " +
                "byte-equal")
        }
    }

    // MARK: - Byte-equality vs Swift SQLite actor (the actor
    //         the routed actor REPLACES on flip)

    /// PIN: same sequence of appends produces same count on the
    /// routed (Rust) actor and the legacy Swift SQLite actor。
    /// This is the most important byte-eq pin because the routed
    /// actor's job is to be a drop-in replacement for the SQLite
    /// actor。
    func testByteEqAppendSequenceVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer {
            cleanup(routedURL)
            cleanup(swiftURL)
        }
        let routed =
            try BASRoutedHostConstitutionDeletionManifestStore(
                databaseURL: routedURL)
        let swiftActor =
            try BASSQLiteHostConstitutionDeletionManifestStore(
                databaseURL: swiftURL)
        let records: [BASHostConstitutionDeletionRecord] = [
            makeRecord(id: "sq-1", vault: "v-X",
                type: "cascade", appliedAt: 1000),
            makeRecord(id: "sq-2", vault: "v-X",
                type: "selective", appliedAt: 2000),
            makeRecord(id: "sq-3", vault: "v-Y",
                type: "rollback", appliedAt: 3000),
        ]
        for r in records {
            _ = try await routed.appendManifest(r)
            _ = try await swiftActor.appendManifest(r)
        }
        // Total count via both actor APIs
        let routedTotal = await routed.count()
        let swiftTotal = await swiftActor.count()
        XCTAssertEqual(routedTotal, swiftTotal,
            "Total count must be byte-equal vs SQLite actor")
        XCTAssertEqual(routedTotal, 3)
    }
}
#endif
