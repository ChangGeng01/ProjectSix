// MARK: - BASChapter937VersionTreeFullRowTests
// chapter 九百三十七 / M3390
//
// 4th SUBSTANCE chapter post-USER-PASS (ch 933) — VersionTree
// bridge had 3 stubbed methods (`versions(forVault:)`,
// `rollbackPoints(forVault:)`,`version(forID:)`) since chapter
// 899。 Mix of ch 934/935 (array) + ch 936 (Optional) patterns。
//
// Complication beyond ch 934-936:`signature_hash` is BLOB (Data
// in Swift) — JSON encoding uses base64 (Foundation default for
// Codable Data fields)。 Rust hand-rolled base64 encoder (no crate
// dep per ch 894 minimal-dep doctrine);Foundation JSONDecoder
// auto-decodes base64 → Data。

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter937VersionTreeFullRowTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch937-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    /// versions(forVault:) round-trip with signature_hash base64
    /// encoding + Optional fields。 If reverted to `return []`,
    /// fails on count assertion。
    func testVersionsForVaultRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)

        let sig1 = Data([0x01, 0x02, 0x03, 0xff])
        let sig2 = Data(repeating: 0xab, count: 32)  // SHA-256 size

        let v1 = BASHostConstitutionVersionRecord(
            versionID: "v-rt-1",
            vaultID: "vault-A",
            parentVersionID: nil,
            createdAtMs: 1_000,
            signatureHash: sig1,
            isRollbackPoint: false,
            mergedFromJson: nil)
        let v2 = BASHostConstitutionVersionRecord(
            versionID: "v-rt-2",
            vaultID: "vault-A",
            parentVersionID: "v-rt-1",
            createdAtMs: 2_000,
            signatureHash: sig2,
            isRollbackPoint: true,
            mergedFromJson: "[\"src-a\",\"src-b\"]")

        _ = try await store.appendVersion(v1)
        _ = try await store.appendVersion(v2)

        let read = await store.versions(forVault: "vault-A")
        XCTAssertEqual(read.count, 2,
            "versions(forVault:) must return both " +
            "(REGRESSION: if 0, ch 937 fix reverted to stub)")
        // Ordering: created_at_ms ASC
        XCTAssertEqual(read[0].versionID, "v-rt-1")
        XCTAssertEqual(read[1].versionID, "v-rt-2")
        // Full field equality on v1
        XCTAssertEqual(read[0].vaultID, "vault-A")
        XCTAssertNil(read[0].parentVersionID)
        XCTAssertEqual(read[0].createdAtMs, 1_000)
        XCTAssertEqual(read[0].signatureHash, sig1,
            "signatureHash must round-trip through base64")
        XCTAssertEqual(read[0].isRollbackPoint, false)
        XCTAssertNil(read[0].mergedFromJson)
        // v2
        XCTAssertEqual(read[1].parentVersionID, "v-rt-1")
        XCTAssertEqual(read[1].signatureHash, sig2,
            "32-byte SHA-256 length signature must round-trip")
        XCTAssertEqual(read[1].isRollbackPoint, true)
        XCTAssertEqual(read[1].mergedFromJson,
                       "[\"src-a\",\"src-b\"]")
    }

    func testVersionsForVaultEmpty() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)
        let read = await store.versions(forVault: "vault-NONE")
        XCTAssertEqual(read.count, 0)
    }

    /// rollbackPoints(forVault:) filters by is_rollback_point=1
    func testRollbackPointsFilter() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)

        let sig = Data([0xff])
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "rp-1", vaultID: "vlt",
                parentVersionID: nil, createdAtMs: 1,
                signatureHash: sig, isRollbackPoint: false))
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "rp-2", vaultID: "vlt",
                parentVersionID: "rp-1", createdAtMs: 2,
                signatureHash: sig, isRollbackPoint: true))
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "rp-3", vaultID: "vlt",
                parentVersionID: "rp-2", createdAtMs: 3,
                signatureHash: sig, isRollbackPoint: true))

        let rb = await store.rollbackPoints(forVault: "vlt")
        XCTAssertEqual(rb.count, 2)
        XCTAssertEqual(Set(rb.map { $0.versionID }),
                       Set(["rp-2", "rp-3"]))

        let all = await store.versions(forVault: "vlt")
        XCTAssertEqual(all.count, 3)
    }

    /// version(forID:) round-trip + not-found semantics
    func testVersionForIDRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)

        let sig = Data([0xde, 0xad, 0xbe, 0xef])
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "single-v",
                vaultID: "single-vlt",
                parentVersionID: nil,
                createdAtMs: 1234,
                signatureHash: sig,
                isRollbackPoint: false))

        let found = await store.version(forID: "single-v")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.versionID, "single-v")
        XCTAssertEqual(found?.signatureHash, sig)
        // chapter 九百四十三 / M3420 (15P-HIGH-5) — full-field
        // backfill on found (was only versionID + signatureHash
        // before)。 Validates that vaultID + parentVersionID +
        // createdAtMs + isRollbackPoint all round-trip correctly。
        XCTAssertEqual(found?.vaultID, "single-vlt")
        XCTAssertEqual(found?.parentVersionID, nil,
            "nil parentVersionID must round-trip as nil")
        XCTAssertEqual(found?.createdAtMs, 1234)
        XCTAssertEqual(found?.isRollbackPoint, false)

        let missing = await store.version(forID: "no-such")
        XCTAssertNil(missing,
            "unknown version_id must return nil")
    }

    /// Vault-isolation: versions(forVault:) for A doesn't see B
    func testVersionsVaultIsolation() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)
        let sig = Data([0])
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "A-1", vaultID: "vault-A",
                parentVersionID: nil, createdAtMs: 1,
                signatureHash: sig, isRollbackPoint: false))
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "B-1", vaultID: "vault-B",
                parentVersionID: nil, createdAtMs: 2,
                signatureHash: sig, isRollbackPoint: false))
        let a = await store.versions(forVault: "vault-A")
        let b = await store.versions(forVault: "vault-B")
        XCTAssertEqual(a.map { $0.versionID }, ["A-1"])
        XCTAssertEqual(b.map { $0.versionID }, ["B-1"])
    }
}
