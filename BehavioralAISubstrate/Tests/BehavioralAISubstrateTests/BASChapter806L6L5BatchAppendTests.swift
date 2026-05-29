// MARK: - BASChapter806L6L5BatchAppendTests
// chapter 八百六 / M2681-M2685
//
// Verifies the L6 + L5 batch-append extension of the chapter 八百
// 四 / 八百五 pattern across the remaining 3 storage adapter pairs:
//   - BASInMemoryPresenceObservationStore                + SQLite
//   - BASInMemoryHostConstitutionVersionTreeStore        + SQLite
//   - BASInMemoryHostConstitutionDeletionManifestStore   + SQLite
//
// Five invariants pinned (mirror of chapter 八百四 / 八百五 contracts):
//
//   1. Empty input is a no-op on every conformer。
//   2. Multi-record batch round-trips through SQLite with all
//      records preserved AND insertion order preserved。
//   3. Duplicate ID mid-batch ROLLS BACK the entire transaction —
//      no partial writes leak。
//   4. L5 version-tree batch preserves the 32-byte BLOB
//      signature_hash + nullable parent_version_id + nullable
//      merged_from_json column shape per row。
//   5. SQLite batch throughput is measurably faster than per-
//      single call (≥3× speedup floor — same threshold as L8/L7)。

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASSovereign

final class BASChapter806L6L5BatchAppendTests: XCTestCase {

    private var presenceDB: URL!
    private var versionTreeDB: URL!
    private var deletionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        presenceDB = tmp.appendingPathComponent(
            "bas-test-l6-batch-\(token).sqlite")
        versionTreeDB = tmp.appendingPathComponent(
            "bas-test-l5-vt-batch-\(token).sqlite")
        deletionDB = tmp.appendingPathComponent(
            "bas-test-l5-del-batch-\(token).sqlite")
    }

    override func tearDown() async throws {
        for url in [presenceDB, versionTreeDB, deletionDB] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - L6 presence observations

    func testPresenceObservationBatchRoundTrip() async throws {
        let records = (0..<50).map {
            BASPresenceObservationRecord(
                eventID: "p-\($0)",
                sessionID: "s",
                turnID: "t",
                channelKind: ["task", "risk", "manipulation",
                              "environment", "bodyRhythm"][$0 % 5],
                salience: Double($0) / 50.0,
                confidence: 0.5,
                observedAtMs: Int64($0))
        }
        let store = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        _ = try await store.appendBatch(records)
        let restored = await store.records(forSession: "s")
        XCTAssertEqual(restored.count, 50)
        XCTAssertEqual(restored.map { $0.eventID },
                       records.map { $0.eventID })
        XCTAssertEqual(restored.map { $0.channelKind },
                       records.map { $0.channelKind })
    }

    func testPresenceObservationBatchEmptyNoOp() async throws {
        let mem = BASInMemoryPresenceObservationStore()
        let sql = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        let memEmpty = try await mem.appendBatch([])
        let sqlEmpty = try await sql.appendBatch([])
        XCTAssertEqual(memEmpty, [])
        XCTAssertEqual(sqlEmpty, [])
    }

    func testPresenceObservationBatchDuplicateRollsBack() async throws {
        let store = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        _ = try await store.appendRecord(
            BASPresenceObservationRecord(
                eventID: "p-3",
                sessionID: "s", turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: 0))
        let countBefore = await store.count()
        XCTAssertEqual(countBefore, 1)
        let batch = (0..<10).map {
            BASPresenceObservationRecord(
                eventID: "p-\($0)",
                sessionID: "s", turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: Int64($0))
        }
        do {
            _ = try await store.appendBatch(batch)
            XCTFail("Expected duplicate-eventID throw")
        } catch BASSQLitePresenceObservationStore.StorageError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "p-3")
        }
        let countAfter = await store.count()
        XCTAssertEqual(countAfter, 1)
    }

    // MARK: - L5 version tree

    func testVersionTreeBatchPreservesBLOBSignature() async throws {
        let versions = (0..<10).map { i -> BASHostConstitutionVersionRecord in
            // Each version commits to distinct canonical bytes →
            // distinct 32-byte SHA-256 BLOB hashes。
            let canonicalBytes = Data("v\(i)".utf8)
            let hash = Data(SHA256.hash(data: canonicalBytes))
            return BASHostConstitutionVersionRecord(
                versionID: "v-\(i)",
                vaultID: "vault",
                parentVersionID: i == 0 ? nil : "v-\(i - 1)",
                createdAtMs: Int64(i),
                signatureHash: hash,
                isRollbackPoint: (i % 3 == 0),
                mergedFromJson: i == 5
                    ? #"["v-2","v-3"]"# : nil)
        }
        let store = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: versionTreeDB)
        _ = try await store.appendBatch(versions)
        let restored = await store.versions(forVault: "vault")
        XCTAssertEqual(restored.count, 10)
        for (orig, back) in zip(versions, restored) {
            XCTAssertEqual(back.versionID, orig.versionID)
            XCTAssertEqual(back.parentVersionID,
                           orig.parentVersionID)
            XCTAssertEqual(back.signatureHash, orig.signatureHash,
                "32-byte BLOB preserved through batch insert")
            XCTAssertEqual(back.isRollbackPoint,
                           orig.isRollbackPoint)
            XCTAssertEqual(back.mergedFromJson,
                           orig.mergedFromJson)
        }
    }

    func testVersionTreeBatchDuplicateRollsBack() async throws {
        let store = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: versionTreeDB)
        let hash = Data(count: 32)
        _ = try await store.appendVersion(
            BASHostConstitutionVersionRecord(
                versionID: "v-5",
                vaultID: "vault",
                createdAtMs: 0,
                signatureHash: hash))
        let countBefore = await store.count()
        XCTAssertEqual(countBefore, 1)
        let batch = (0..<10).map {
            BASHostConstitutionVersionRecord(
                versionID: "v-\($0)",
                vaultID: "vault",
                createdAtMs: Int64($0),
                signatureHash: hash)
        }
        do {
            _ = try await store.appendBatch(batch)
            XCTFail("Expected duplicate-versionID throw")
        } catch BASSQLiteHostConstitutionVersionTreeStore.StorageError
            .duplicateVersionID(let id) {
            XCTAssertEqual(id, "v-5")
        }
        let countAfter = await store.count()
        XCTAssertEqual(countAfter, 1)
    }

    // MARK: - L5 deletion manifest

    func testDeletionManifestBatchRoundTrip() async throws {
        var manifests: [BASHostConstitutionDeletionRecord] = []
        let typeCycle = ["cascade", "selective", "rollback"]
        for i in 0..<5 {
            let cascaded: String? = (i % 2 == 0)
                ? #"["cascade-\#(i)"]"#
                : nil
            let versionRef: String? = (i == 0) ? nil : "v-\(i)"
            manifests.append(BASHostConstitutionDeletionRecord(
                manifestID: "m-\(i)",
                vaultID: "vault",
                targetRefsJson: #"["ref-\#(i)"]"#,
                deletionType: typeCycle[i % 3],
                appliedAtMs: Int64(i),
                cascadedRefsJson: cascaded,
                versionRef: versionRef))
        }
        let store = try BASSQLiteHostConstitutionDeletionManifestStore(
            databaseURL: deletionDB)
        _ = try await store.appendBatch(manifests)
        let restored = await store.manifests(forVault: "vault")
        XCTAssertEqual(restored.count, 5)
        XCTAssertEqual(restored.map { $0.deletionType },
                       manifests.map { $0.deletionType })
        XCTAssertEqual(restored.map { $0.cascadedRefsJson },
                       manifests.map { $0.cascadedRefsJson },
            "Nullable cascaded_refs_json preserved per row")
        XCTAssertEqual(restored.map { $0.versionRef },
                       manifests.map { $0.versionRef },
            "Nullable version_ref preserved per row")
    }

    // MARK: - Informational perf

    func testL6BatchFasterThanPerCall() async throws {
        let iters = 200
        // ch 1037.0 best-of-3 trials(mirror ch 1024.0 ch 868):
        // single-shot perCall/batch timing is flaky under Mac
        // scheduling noise(endurance v5/v6 flaky)— take the BEST
        // (max)speedup across 3 trials,the trial least perturbed。
        var bestRatio = 0.0
        for _ in 0..<3 {
        try? FileManager.default.removeItem(at: presenceDB)
        let perCallStore = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        _ = try await perCallStore.appendRecord(
            BASPresenceObservationRecord(
                eventID: "warmup", sessionID: "s", turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: -1))
        let perCallStart = DispatchTime.now().uptimeNanoseconds
        for i in 0..<iters {
            _ = try await perCallStore.appendRecord(
                BASPresenceObservationRecord(
                    eventID: "p-\(i)", sessionID: "s", turnID: "t",
                    channelKind: "task",
                    salience: 0.5, confidence: 0.5,
                    observedAtMs: Int64(i)))
        }
        let perCallNs = DispatchTime.now().uptimeNanoseconds
            - perCallStart

        try? FileManager.default.removeItem(at: presenceDB)
        let batchStore = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        _ = try await batchStore.appendRecord(
            BASPresenceObservationRecord(
                eventID: "warmup", sessionID: "s", turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: -1))
        let batch = (0..<iters).map {
            BASPresenceObservationRecord(
                eventID: "b-\($0)", sessionID: "s", turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: Int64($0))
        }
        let batchStart = DispatchTime.now().uptimeNanoseconds
        _ = try await batchStore.appendBatch(batch)
        let batchNs = DispatchTime.now().uptimeNanoseconds
            - batchStart

        let ratio = Double(perCallNs) / Double(batchNs)
        bestRatio = max(bestRatio, ratio)
        }  // end ch 1037.0 best-of-3 trial loop
        print(String(format:
            "== L6 PRESENCE BATCH: %d events,best-of-3 speedup %.1f×",
            iters, bestRatio))
        XCTAssertGreaterThan(bestRatio, 3.0,
            "L6 batch must be ≥3× faster than per-single call" +
            " (best of 3 trials)")
    }
}
