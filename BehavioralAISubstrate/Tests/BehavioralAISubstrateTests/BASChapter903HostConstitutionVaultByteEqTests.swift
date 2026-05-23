// MARK: - BASChapter903HostConstitutionVaultByteEqTests
// chapter 九百三 / M3215 — HIGH-risk migration #3 (final)
//
// L8 unification — byte-equality vs BASHostConstitutionSQLite
// Storage。 More thorough than ch 895-900 bridges (HIGH-risk
// store) but no per-table split needed (1 table only,621 LOC
// vs MemoryUsageTracker's 2714)。
//
// Coverage:
//   - save returns wasNew Bool correctly (true/false on
//     UPSERT idempotent)
//   - UPSERT replaces ALL non-PK columns on conflict
//   - DELETE returns wasRemoved bool
//   - Round-trip Codable parity (encode → store → load →
//     decode equals original)
//   - vaultCount + countForHost parity vs Swift actor

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter903HostConstitutionVaultByteEqTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch903-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: url.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(
            at: url.appendingPathExtension("shm"))
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

    // MARK: - Native save / load round-trip

    func testSaveThenLoadReturnsEqualVault() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: url)
        let vault = makeVault()
        let isNew = try await store.save(vault)
        XCTAssertTrue(isNew,
            "First save returns wasNew=true")
        let fetched = try await store.loadVault(
            vaultID: vault.vaultID)
        XCTAssertEqual(fetched, vault,
            "Codable round-trip preserves all fields")
    }

    func testSaveAgainReturnsFalseAndReplacesPayload() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: url)
        let v1 = makeVault(activeVersion: "host.v1")
        let v2 = BASHostConstitutionVault(
            vaultID: v1.vaultID,
            constitutionSnapshot: BASHostConstitution(
                hostID: v1.constitutionSnapshot.hostID,
                activeVersion: "host.v2"),
            deviceConsistencyReport:
                v1.deviceConsistencyReport)
        let isNew1 = try await store.save(v1)
        let isNew2 = try await store.save(v2)
        XCTAssertTrue(isNew1)
        XCTAssertFalse(isNew2,
            "UPSERT on same vault_id returns wasNew=false")
        let fetched = try await store.loadVault(
            vaultID: v1.vaultID)
        XCTAssertEqual(
            fetched?.constitutionSnapshot.activeVersion,
            "host.v2",
            "UPSERT propagates ALL non-PK columns")
        let count = await store.vaultCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - DELETE

    func testRemoveReturnsTrueOnHitFalseOnMiss() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: url)
        let v = makeVault()
        try await store.save(v)
        let r1 = try await store.remove(vaultID: v.vaultID)
        XCTAssertTrue(r1,
            "DELETE on existing returns true")
        let r2 = try await store.remove(vaultID: v.vaultID)
        XCTAssertFalse(r2,
            "DELETE on missing returns false")
        let count = await store.vaultCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - loadFirstVault(forHostID:)

    func testLoadFirstVaultForHostReturnsMatching() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: url)
        let vA = makeVault(hostID: "host.alpha")
        let vB = makeVault(hostID: "host.beta")
        try await store.save(vA)
        try await store.save(vB)
        let firstA = try await store.loadFirstVault(
            forHostID: "host.alpha")
        let firstB = try await store.loadFirstVault(
            forHostID: "host.beta")
        let firstMissing = try await store.loadFirstVault(
            forHostID: "host.no-such")
        XCTAssertEqual(firstA?.constitutionSnapshot.hostID,
            "host.alpha")
        XCTAssertEqual(firstB?.constitutionSnapshot.hostID,
            "host.beta")
        XCTAssertNil(firstMissing)
        let cA = await store.countForHost("host.alpha")
        let cB = await store.countForHost("host.beta")
        XCTAssertEqual(cA, 1)
        XCTAssertEqual(cB, 1)
    }

    // MARK: - Byte-equality vs BASHostConstitutionSQLiteStorage

    func testByteEqVaultSaveLoadVsSwift() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: routedURL)
        let swiftActor = try BASHostConstitutionSQLiteStorage(
            databaseURL: swiftURL)
        // Drive 3 vaults across 2 hosts through both stores
        let vaults = [
            makeVault(hostID: "host-A", activeVersion: "v1"),
            makeVault(hostID: "host-A", activeVersion: "v2"),
            makeVault(hostID: "host-B", activeVersion: "v1"),
        ]
        // Note: vaultID is derived from hostID by default
        // ("host-A.constitution.vault") so v1+v2 collide on
        // PK。 Force unique vaultIDs by passing explicit IDs。
        let unique: [BASHostConstitutionVault] =
            vaults.enumerated().map { idx, v in
                BASHostConstitutionVault(
                    vaultID: "be-v\(idx)",
                    constitutionSnapshot: v.constitutionSnapshot,
                    deviceConsistencyReport:
                        v.deviceConsistencyReport)
            }
        for v in unique {
            let rNew = try await routed.save(v)
            let sNew = try await swiftActor.save(v)
            XCTAssertEqual(rNew, sNew,
                "wasNew parity for vault=\(v.vaultID)")
            XCTAssertTrue(rNew)
        }
        // Counts byte-eq
        let rTotal = await routed.vaultCount
        let sTotal = await swiftActor.vaultCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 3)
        // Per-host counts (Swift exposes via loadAll filter,
        // Rust via direct count_for_host)
        let allSwift = try await swiftActor.loadAll()
        let swiftHostA = allSwift.filter {
            $0.constitutionSnapshot.hostID == "host-A"
        }.count
        let routedHostA = await routed.countForHost("host-A")
        XCTAssertEqual(routedHostA, swiftHostA)
        XCTAssertEqual(routedHostA, 2)
        // Round-trip parity:loading vault from Rust must
        // equal loading from Swift
        for v in unique {
            let r = try await routed.loadVault(
                vaultID: v.vaultID)
            let s = try await swiftActor.loadVault(
                vaultID: v.vaultID)
            XCTAssertEqual(r, s,
                "Round-trip Codable parity for \(v.vaultID)")
            XCTAssertEqual(r, v)
        }
    }

    func testByteEqRemoveVsSwift() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: routedURL)
        let swiftActor = try BASHostConstitutionSQLiteStorage(
            databaseURL: swiftURL)
        let v = makeVault()
        try await routed.save(v)
        try await swiftActor.save(v)
        // Both: remove returns true on hit
        let rRemoved = try await routed.remove(
            vaultID: v.vaultID)
        let sRemoved = await swiftActor.remove(
            vaultID: v.vaultID)
        XCTAssertEqual(rRemoved, sRemoved != nil)
        XCTAssertTrue(rRemoved)
        // Both: remove returns false (Rust) / nil (Swift) on miss
        let r2 = try await routed.remove(vaultID: v.vaultID)
        let s2 = await swiftActor.remove(vaultID: v.vaultID)
        XCTAssertFalse(r2)
        XCTAssertNil(s2)
        // Counts converge to 0
        let rTotal = await routed.vaultCount
        let sTotal = await swiftActor.vaultCount
        XCTAssertEqual(rTotal, 0)
        XCTAssertEqual(sTotal, 0)
    }
}
#endif
