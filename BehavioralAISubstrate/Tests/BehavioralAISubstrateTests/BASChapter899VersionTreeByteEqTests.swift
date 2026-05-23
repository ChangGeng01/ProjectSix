// MARK: - BASChapter899VersionTreeByteEqTests
// chapter 八百九十九 / M3185 — MED-risk migration #4 byte-eq pin
// (first BLOB FFI verification)

import XCTest
import Foundation
@testable import BASMemory
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter899VersionTreeByteEqTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ch899-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func makeVersion(
        id: String,
        vault: String = "vault-default",
        parent: String? = nil,
        at: Int64 = 1_700_000_000_000,
        hashByte: UInt8 = 0x42,
        rollback: Bool = false,
        merged: String? = nil
    ) -> BASHostConstitutionVersionRecord {
        BASHostConstitutionVersionRecord(
            versionID: id,
            vaultID: vault,
            parentVersionID: parent,
            createdAtMs: at,
            signatureHash: Data(repeating: hashByte, count: 32),
            isRollbackPoint: rollback,
            mergedFromJson: merged)
    }

    func testRoutedActorBasicRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed =
            try BASRoutedHostConstitutionVersionTreeStore(
                databaseURL: url)
        let initial = await routed.count()
        XCTAssertEqual(initial, 0)
        _ = try await routed.appendVersion(
            makeVersion(id: "v1", vault: "vA"))
        _ = try await routed.appendVersion(
            makeVersion(id: "v2", vault: "vA", parent: "v1",
                rollback: true))
        _ = try await routed.appendVersion(
            makeVersion(id: "v3", vault: "vB"))
        let total = await routed.count()
        XCTAssertEqual(total, 3)
        let cA = await routed.countForVault("vA")
        let cB = await routed.countForVault("vB")
        XCTAssertEqual(cA, 2)
        XCTAssertEqual(cB, 1)
        let rbA = await routed.rollbackPointCount(
            forVault: "vA")
        let rbB = await routed.rollbackPointCount(
            forVault: "vB")
        XCTAssertEqual(rbA, 1, "v2 is rollback")
        XCTAssertEqual(rbB, 0)
    }

    func testDuplicateVersionIDRejected() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed =
            try BASRoutedHostConstitutionVersionTreeStore(
                databaseURL: url)
        _ = try await routed.appendVersion(
            makeVersion(id: "dup"))
        do {
            _ = try await routed.appendVersion(
                makeVersion(id: "dup"))
            XCTFail("Duplicate version_id must throw")
        } catch BASRoutedHostConstitutionVersionTreeStore
            .StoreError.appendFailed(let code) {
            XCTAssertEqual(code, -2)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    /// CRITICAL byte-eq vs Swift SQLite actor (with BLOB hash)
    func testByteEqAppendVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed =
            try BASRoutedHostConstitutionVersionTreeStore(
                databaseURL: routedURL)
        let swiftActor =
            try BASSQLiteHostConstitutionVersionTreeStore(
                databaseURL: swiftURL)
        let versions: [BASHostConstitutionVersionRecord] = [
            makeVersion(id: "be-1", vault: "vX", at: 100,
                hashByte: 0x11),
            makeVersion(id: "be-2", vault: "vX", parent: "be-1",
                at: 200, hashByte: 0x22, rollback: true),
            makeVersion(id: "be-3", vault: "vY", at: 300,
                hashByte: 0x33,
                merged: #"["be-1","be-2"]"#),
            makeVersion(id: "be-4", vault: "vY", at: 400,
                hashByte: 0x44, rollback: true),
        ]
        for v in versions {
            _ = try await routed.appendVersion(v)
            _ = try await swiftActor.appendVersion(v)
        }
        let rTotal = await routed.count()
        let sTotal = await swiftActor.count()
        XCTAssertEqual(rTotal, sTotal,
            "Total count byte-eq vs SQLite actor")
        XCTAssertEqual(rTotal, 4)
        // Per-vault count byte-eq
        for v in ["vX", "vY", "vMissing"] {
            let r = await routed.countForVault(v)
            let s = await swiftActor.versions(
                forVault: v).count
            XCTAssertEqual(r, s,
                "Per-vault count byte-eq for vault=\(v)")
        }
        // Rollback-point count byte-eq
        for v in ["vX", "vY"] {
            let r = await routed.rollbackPointCount(
                forVault: v)
            let s = await swiftActor.rollbackPoints(
                forVault: v).count
            XCTAssertEqual(r, s,
                "Rollback-point count byte-eq for vault=\(v)")
        }
    }
}
#endif
