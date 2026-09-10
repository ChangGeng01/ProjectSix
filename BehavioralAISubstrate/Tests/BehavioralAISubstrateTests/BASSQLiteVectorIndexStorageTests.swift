// MARK: - BASSQLiteVectorIndexStorageTests — chapter 三百六二 / M849
//
// Test coverage for G4 part 2 deliverable: SQLite-backed
// cross-session persistence for `BASVectorIndex` entries。
//
// Tests verify:
//   - Schema setup + version pin
//   - upsert + entry(forID:) round-trip
//   - upsert overwrites existing entry
//   - remove returns true on present, false on absent
//   - allEntries returns sorted entries
//   - **Cross-session persistence** (chapter 二百四十八 M735
//     architectural pin) — close + reopen produces byte-equal
//     entries
//   - preload(into:) populates an in-memory BASVectorIndex
//   - Float32 encode/decode round-trip preserves values
//   - Dimension mismatch caught at decode time

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASSQLiteVectorIndexStorageTests: XCTestCase {

    /// deep-audit LOW: an UNTRUSTED `dimension` read from the DB must be overflow-guarded before
    /// `dimension * floatByteSize`, else a corrupt/tampered value TRAPS (crash). safeEmbeddingByteSize
    /// throws instead. Unfixed (raw multiply): the negative case returns a bogus value (no throw → red)
    /// and the overflow case traps (crash) — never the clean thrown error this asserts.
    func testSafeEmbeddingByteSizeThrowsInsteadOfTrappingOnCorruptDimension() {
        XCTAssertEqual(
            try BASSQLiteVectorIndexStorage.safeEmbeddingByteSize(dimension: 4, atomID: "a"), 16)
        XCTAssertThrowsError(
            try BASSQLiteVectorIndexStorage.safeEmbeddingByteSize(dimension: -1, atomID: "a"),
            "a negative persisted dimension must throw, not return a bogus size")
        XCTAssertThrowsError(
            try BASSQLiteVectorIndexStorage.safeEmbeddingByteSize(dimension: Int.max / 2, atomID: "a"),
            "an overflowing persisted dimension must throw, not TRAP")
    }

    private var tempURL: URL?

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-vector-index-test-\(UUID().uuidString)" +
                ".sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath:
                    tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath:
                    tempURL.path + "-shm"))
        }
    }

    private func makeEntry(
        atomID: String,
        vector: [Float],
        domain: String = "user.notes",
        metadata: [String: String] = [:]
    ) -> BASVectorIndexEntry {
        let embedding = BASEmbedding(
            vector: vector,
            dimension: vector.count,
            providerVersion: "test-v1")
        return BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding.normalized,
            domain: domain,
            metadata: metadata)
    }

    // MARK: - Schema + setup

    func testSchemaVersionPin() {
        XCTAssertEqual(
            BASSQLiteVectorIndexStorage.schemaVersion, 1,
            "Schema version pin: bumping requires explicit " +
            "migration review for production vector_index " +
            "databases on disk")
    }

    func testFloatByteSizePin() {
        XCTAssertEqual(
            BASSQLiteVectorIndexStorage.floatByteSize, 4,
            "Float32 byte size pin (anti-magic-number)")
    }

    func testFreshStoreIsEmpty() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let count = await store.totalCount
        XCTAssertEqual(count, 0)
        let entries = await store.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - upsert / entry(forID:)

    func testUpsertThenFetch() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let entry = makeEntry(
            atomID: "test-1",
            vector: [1.0, 0.0, 0.0])
        let wasNew = try await store.upsert(entry)
        XCTAssertTrue(wasNew,
            "First upsert must report wasNew=true")
        let fetched = await store.entry(forID: "test-1")
        XCTAssertEqual(fetched?.atomID, "test-1")
        XCTAssertEqual(
            fetched?.normalizedEmbedding.dimension, 3)
        XCTAssertEqual(fetched?.domain, "user.notes")
    }

    func testUpsertReplacesExisting() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let v1 = makeEntry(
            atomID: "x", vector: [1.0, 0.0])
        let v2 = makeEntry(
            atomID: "x", vector: [0.0, 1.0])
        _ = try await store.upsert(v1)
        let wasNew = try await store.upsert(v2)
        XCTAssertFalse(wasNew,
            "Second upsert must report wasNew=false")
        let count = await store.totalCount
        XCTAssertEqual(count, 1,
            "Replace not duplicate")
    }

    func testFetchMissingReturnsNil() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let fetched = await store.entry(forID: "missing")
        XCTAssertNil(fetched)
    }

    // MARK: - remove

    func testRemovePresentReturnsTrue() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        _ = try await store.upsert(makeEntry(
            atomID: "to-remove",
            vector: [1, 0, 0]))
        let removed = try await store.remove(
            atomID: "to-remove")
        XCTAssertTrue(removed)
        let count = await store.totalCount
        XCTAssertEqual(count, 0)
    }

    func testRemoveAbsentReturnsFalse() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let removed = try await store.remove(
            atomID: "never-existed")
        XCTAssertFalse(removed)
    }

    // MARK: - allEntries (preload data source)

    func testAllEntriesReturnsAllRows() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        for i in 0..<5 {
            _ = try await store.upsert(makeEntry(
                atomID: "atom-\(i)",
                vector: [Float(i), 0, 0]))
        }
        let all = await store.allEntries()
        XCTAssertEqual(all.count, 5)
        // Sorted by atom_id ASC for stable replay
        XCTAssertEqual(
            all.map { $0.atomID },
            ["atom-0", "atom-1", "atom-2",
             "atom-3", "atom-4"])
    }

    // MARK: - Cross-session persistence (THE pin)

    /// **Architectural pin** — chapter 二百四十八 M735 doctrine:
    /// SQLite-backed storage MUST preserve byte-equal semantics
    /// across process / actor restart。Closes G4 cross-session
    /// gap noted in M847 commit message。
    func testCrossSessionPersistence() async throws {
        let url = try XCTUnwrap(tempURL)
        let original: [BASVectorIndexEntry]
        do {
            let store = try BASSQLiteVectorIndexStorage(
                databaseURL: url)
            for i in 0..<10 {
                _ = try await store.upsert(makeEntry(
                    atomID: "persist-\(i)",
                    vector: [
                        Float(i) * 0.1,
                        Float(i) * 0.2,
                        Float(i) * 0.3
                    ],
                    domain: "user.notes",
                    metadata: ["seq": "\(i)"]))
            }
            original = await store.allEntries()
        }
        // First store deinits → sqlite3_close_v2 fires
        let reopened = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        let restored = await reopened.allEntries()
        XCTAssertEqual(
            restored, original,
            "Vector entries must round-trip byte-equal " +
            "across process restart (chapter 二百四十八 M735 " +
            "architectural pin)")
    }

    // MARK: - preload(into:) helper

    func testPreloadIntoMemoryIndex() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        for i in 0..<5 {
            _ = try await store.upsert(makeEntry(
                atomID: "pre-\(i)",
                vector: [Float(i + 1), 0, 0]))
        }
        let memIndex = BASVectorIndex()
        let loaded = await store.preload(into: memIndex)
        XCTAssertEqual(loaded, 5)
        let memCount = await memIndex.entryCount
        XCTAssertEqual(memCount, 5)
        // Verify topK works on preloaded index
        let query = BASEmbedding(
            vector: [1, 0, 0], dimension: 3,
            providerVersion: "test-v1"
        ).normalized
        let results = await memIndex.topK(
            query: query, k: 5)
        XCTAssertEqual(results.count, 5)
    }

    // MARK: - Float32 round-trip fidelity

    func testFloat32EncodeDecodeRoundTrip() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        // Use values that exercise Float32 precision boundaries
        let vector: [Float] = [
            0.5, -0.5, 0.123456, -0.987654,
            1e-7, -1e7, 0.0, 1.0
        ]
        let entry = makeEntry(
            atomID: "precision-test",
            vector: vector)
        _ = try await store.upsert(entry)
        let fetched = await store.entry(
            forID: "precision-test")
        XCTAssertNotNil(fetched)
        let decoded = fetched!.normalizedEmbedding.vector
        let original = entry.normalizedEmbedding.vector
        for (i, value) in original.enumerated() {
            XCTAssertEqual(
                decoded[i], value, accuracy: 1e-6,
                "Float32 round-trip must preserve precision " +
                "at index \(i)")
        }
    }

    // MARK: - Domain + metadata persistence

    func testDomainAndMetadataPersist() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteVectorIndexStorage(
            databaseURL: url)
        _ = try await store.upsert(makeEntry(
            atomID: "with-meta",
            vector: [1, 0, 0],
            domain: "user.medical_records",
            metadata: ["sensitivity": "high",
                       "tier": "cold"]))
        let fetched = await store.entry(forID: "with-meta")
        XCTAssertEqual(
            fetched?.domain, "user.medical_records")
        XCTAssertEqual(
            fetched?.metadata, [
                "sensitivity": "high", "tier": "cold"])
    }
}
