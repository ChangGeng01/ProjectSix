// MARK: - BASChapter935DeletionManifestFullRowTests
// chapter 九百三十五 / M3380
//
// 2nd SUBSTANCE chapter post-USER-PASS (ch 933) — DeletionManifest
// bridge had `manifests(forVault:)` + `manifests(forType:)` as
// `return []` stubs (with DEBUG assertionFailure) since chapter
// 896,labeled「Full」 in L8_ROUTED_OVERVIEW.md。
//
// Ch 935 ships the actual full-row Rust FFI + Swift bridge
// wiring using the proven ch 934 recipe (probe + fill JSON FFI
// + JSONDecoder)。

import XCTest
@testable import BASMemory

final class BASChapter935DeletionManifestFullRowTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch935-\(UUID().uuidString).sqlite")
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

    /// Round-trip: append 2 manifests, read back via
    /// manifests(forVault:), assert full field equality + ordering。
    /// If reverted to `return []` stub, fails with empty array。
    func testManifestsForVaultRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionDeletionManifestStore(
            databaseURL: url)

        let m1 = BASHostConstitutionDeletionRecord(
            manifestID: "m-rt-1",
            vaultID: "vault-A",
            targetRefsJson: "[\"atom-1\",\"atom-2\"]",
            deletionType: "cascade",
            appliedAtMs: 1_700_000_000_000,
            cascadedRefsJson: "[\"cascade-A\"]",
            versionRef: "v1")
        let m2 = BASHostConstitutionDeletionRecord(
            manifestID: "m-rt-2",
            vaultID: "vault-A",
            targetRefsJson: "[\"atom-3\"]",
            deletionType: "selective",
            appliedAtMs: 1_700_000_001_000,
            cascadedRefsJson: nil,
            versionRef: nil)

        _ = try await store.appendManifest(m1)
        _ = try await store.appendManifest(m2)

        let read = await store.manifests(forVault: "vault-A")
        XCTAssertEqual(read.count, 2,
            "manifests(forVault:) must return both appended " +
            "records (REGRESSION: if 0, ch 935 fix reverted)")

        // Ordering: applied_at_ms ASC
        XCTAssertEqual(read[0].manifestID, "m-rt-1")
        XCTAssertEqual(read[1].manifestID, "m-rt-2")

        // Full field equality
        XCTAssertEqual(read[0].vaultID, "vault-A")
        XCTAssertEqual(read[0].targetRefsJson,
            "[\"atom-1\",\"atom-2\"]")
        XCTAssertEqual(read[0].deletionType, "cascade")
        XCTAssertEqual(read[0].appliedAtMs, 1_700_000_000_000)
        XCTAssertEqual(read[0].cascadedRefsJson, "[\"cascade-A\"]")
        XCTAssertEqual(read[0].versionRef, "v1")

        // nil-optional round-trip
        XCTAssertNil(read[1].cascadedRefsJson)
        XCTAssertNil(read[1].versionRef)
    }

    func testManifestsForVaultEmptyResult() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionDeletionManifestStore(
            databaseURL: url)
        let read = await store.manifests(forVault: "vault-NONE")
        XCTAssertEqual(read.count, 0)
    }

    func testManifestsForTypeFiltering() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionDeletionManifestStore(
            databaseURL: url)

        _ = try await store.appendManifest(
            BASHostConstitutionDeletionRecord(
                manifestID: "t-c1", vaultID: "v",
                targetRefsJson: "[]", deletionType: "cascade",
                appliedAtMs: 1_000))
        _ = try await store.appendManifest(
            BASHostConstitutionDeletionRecord(
                manifestID: "t-s1", vaultID: "v",
                targetRefsJson: "[]", deletionType: "selective",
                appliedAtMs: 2_000))
        _ = try await store.appendManifest(
            BASHostConstitutionDeletionRecord(
                manifestID: "t-c2", vaultID: "v",
                targetRefsJson: "[]", deletionType: "cascade",
                appliedAtMs: 3_000))

        let cascade = await store.manifests(forType: "cascade")
        XCTAssertEqual(cascade.count, 2)
        XCTAssertEqual(Set(cascade.map { $0.manifestID }),
                       Set(["t-c1", "t-c2"]))
        // chapter 九百四十三 / M3420 (15P-HIGH-5) — full-field
        // backfill (was only count + manifestID set before)。
        // Validates that vaultID,targetRefsJson,deletionType,
        // appliedAtMs all round-trip correctly through the FFI。
        let cascadeByID = Dictionary(
            uniqueKeysWithValues: cascade.map { ($0.manifestID, $0) })
        XCTAssertEqual(cascadeByID["t-c1"]?.vaultID, "v")
        XCTAssertEqual(cascadeByID["t-c1"]?.targetRefsJson, "[]")
        XCTAssertEqual(cascadeByID["t-c1"]?.deletionType, "cascade")
        XCTAssertEqual(cascadeByID["t-c1"]?.appliedAtMs, 1_000)
        XCTAssertEqual(cascadeByID["t-c2"]?.deletionType, "cascade")
        XCTAssertEqual(cascadeByID["t-c2"]?.appliedAtMs, 3_000)

        let selective = await store.manifests(forType: "selective")
        XCTAssertEqual(selective.count, 1)
        XCTAssertEqual(selective[0].manifestID, "t-s1")
        // chapter 九百四十三 / M3420 — single-result field backfill
        XCTAssertEqual(selective[0].vaultID, "v")
        XCTAssertEqual(selective[0].targetRefsJson, "[]")
        XCTAssertEqual(selective[0].deletionType, "selective")
        XCTAssertEqual(selective[0].appliedAtMs, 2_000)

        let rollback = await store.manifests(forType: "rollback")
        XCTAssertEqual(rollback.count, 0)
    }

    /// JSON escape: targetRefsJson may contain quotes / backslashes
    func testManifestsJsonEscapeCorrectness() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionDeletionManifestStore(
            databaseURL: url)

        let trickyTarget = "[\"atom with \\\"quotes\\\"\",\"atom\\\\backslash\"]"
        let trickyCascade = "tab\there\nnewline"
        _ = try await store.appendManifest(
            BASHostConstitutionDeletionRecord(
                manifestID: "esc-m",
                vaultID: "esc-v",
                targetRefsJson: trickyTarget,
                deletionType: "cascade",
                appliedAtMs: 1,
                cascadedRefsJson: trickyCascade,
                versionRef: nil))
        let read = await store.manifests(forVault: "esc-v")
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read[0].targetRefsJson, trickyTarget,
            "targetRefsJson must round-trip byte-for-byte")
        XCTAssertEqual(read[0].cascadedRefsJson, trickyCascade,
            "cascadedRefsJson with tab + newline must round-trip")
    }
}
