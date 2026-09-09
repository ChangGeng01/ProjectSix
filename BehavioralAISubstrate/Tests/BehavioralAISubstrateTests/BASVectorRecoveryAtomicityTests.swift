import Foundation
import XCTest

@testable import BASMemory
@testable import BASRuntimeCore

final class BASVectorRecoveryAtomicityTests: XCTestCase {
    private var databaseURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in databaseURLs {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-shm"))
        }
    }

    func testUpsertAllLeavesExistingFloatStateUnchangedAfterLaterDimensionError() async throws {
        let index = BASVectorIndex()
        try await index.upsert(entry("old", [1, 0]))

        do {
            try await index.upsertAll([
                entry("new-valid", [0, 1]),
                entry("later-invalid", [1, 0, 0]),
            ])
            XCTFail("later dimension mismatch must reject the whole batch")
        } catch let error as BASVectorIndex.BASVectorIndexError {
            XCTAssertEqual(error, .dimensionMismatch(expected: 2, got: 3))
        }

        let count = await index.entryCount
        let dimension = await index.dimension
        let hasOld = await index.contains(atomID: "old")
        let hasValid = await index.contains(atomID: "new-valid")
        let hasInvalid = await index.contains(atomID: "later-invalid")
        XCTAssertEqual(count, 1)
        XCTAssertEqual(dimension, 2)
        XCTAssertTrue(hasOld)
        XCTAssertFalse(hasValid)
        XCTAssertFalse(hasInvalid)
    }

    func testUpsertAllLeavesExistingFloatStateUnchangedAfterLaterNonfiniteError() async throws {
        let index = BASVectorIndex()
        try await index.upsert(entry("old", [1, 0]))

        do {
            try await index.upsertAll([
                entry("new-valid", [0, 1]),
                entry("later-invalid", [.nan, 0]),
            ])
            XCTFail("later nonfinite embedding must reject the whole batch")
        } catch let error as BASVectorIndex.BASVectorIndexError {
            XCTAssertEqual(error, .nonFiniteEmbedding("later-invalid"))
        }

        let count = await index.entryCount
        let dimension = await index.dimension
        let hasOld = await index.contains(atomID: "old")
        let hasValid = await index.contains(atomID: "new-valid")
        XCTAssertEqual(count, 1)
        XCTAssertEqual(dimension, 2)
        XCTAssertTrue(hasOld)
        XCTAssertFalse(hasValid)
    }

    func testUpsertAllFailurePreservesInt8BoundState() async throws {
        let oldFlag = BASVectorIndex.useInt8VectorStorage
        BASVectorIndex.useInt8VectorStorage = true
        defer { BASVectorIndex.useInt8VectorStorage = oldFlag }

        let index = BASVectorIndex()
        let int8 = try XCTUnwrap(BASInt8VectorIndexEntry(
            atomID: "int8-old",
            normalizedEmbedding: [1, 0],
            domain: "int8-domain"
        ))
        try await index.insertInt8(int8)

        do {
            try await index.upsertAll([
                entry("float-valid", [0, 1]),
                entry("float-invalid", [1, 0, 0]),
            ])
            XCTFail("batch must validate against the int8-bound dimension before mutation")
        } catch let error as BASVectorIndex.BASVectorIndexError {
            XCTAssertEqual(error, .dimensionMismatch(expected: 2, got: 3))
        }

        let floatCount = await index.entryCount
        let int8Count = await index.int8EntryCount
        let dimension = await index.dimension
        let int8Results = await index.topKInt8(
            query: embedding([1, 0]),
            k: 2
        )
        XCTAssertEqual(floatCount, 0)
        XCTAssertEqual(int8Count, 1)
        XCTAssertEqual(dimension, 2)
        XCTAssertEqual(int8Results.map(\.atomID), ["int8-old"])
    }

    func testUpsertAllMergesReplacesAndUsesLastDuplicateWithoutDuplicateIDs() async throws {
        let index = BASVectorIndex()
        try await index.upsert(entry("replace", [1, 0]))

        try await index.upsertAll([
            entry("replace", [0, 1]),
            entry("duplicate", [1, 0]),
            entry("new", [0, 1]),
            entry("duplicate", [-1, 0]),
        ])

        let count = await index.entryCount
        let vertical = await index.topK(query: embedding([0, 1]), k: 3)
        let horizontal = await index.topK(query: embedding([1, 0]), k: 3)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(vertical.first?.atomID, "new")
        XCTAssertEqual(Set(vertical.map(\.atomID)), ["replace", "duplicate", "new"])
        XCTAssertEqual(horizontal.last?.atomID, "duplicate")
        XCTAssertEqual(horizontal.last?.score ?? 0, -1, accuracy: 0.000_01)
    }

    func testUpsertAllEmptyBatchIsNoOpForEmptyAndBoundIndices() async throws {
        let empty = BASVectorIndex()
        try await empty.upsertAll([])
        let emptyCount = await empty.entryCount
        let emptyDimension = await empty.dimension
        XCTAssertEqual(emptyCount, 0)
        XCTAssertNil(emptyDimension)

        let bound = BASVectorIndex()
        try await bound.upsert(entry("old", [1, 0]))
        try await bound.upsertAll([])
        let boundCount = await bound.entryCount
        let boundDimension = await bound.dimension
        XCTAssertEqual(boundCount, 1)
        XCTAssertEqual(boundDimension, 2)
    }

    func testPreloadOrThrowAtomicallyMergesAndReturnsDurableRowCount() async throws {
        let storage = try BASSQLiteVectorIndexStorage(databaseURL: makeDatabaseURL())
        try await storage.upsert(entry("replace", [0, 1]))
        try await storage.upsert(entry("new", [1, 0]))
        let index = BASVectorIndex()
        try await index.upsert(entry("replace", [1, 0]))

        let loaded = try await storage.preloadOrThrow(into: index)

        let count = await index.entryCount
        let results = await index.topK(query: embedding([0, 1]), k: 2)
        XCTAssertEqual(loaded, 2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(results.first?.atomID, "replace")
    }

    func testPreloadOrThrowLeavesDestinationUnchangedAfterLaterDimensionError() async throws {
        let storage = try BASSQLiteVectorIndexStorage(databaseURL: makeDatabaseURL())
        try await storage.upsert(entry("a-valid", [0, 1]))
        try await storage.upsert(entry("z-invalid", [1, 0, 0]))
        let index = BASVectorIndex()
        try await index.upsert(entry("old", [1, 0]))

        do {
            _ = try await storage.preloadOrThrow(into: index)
            XCTFail("preload must reject a later mismatched row atomically")
        } catch let error as BASVectorIndex.BASVectorIndexError {
            XCTAssertEqual(error, .dimensionMismatch(expected: 2, got: 3))
        }

        let count = await index.entryCount
        let hasOld = await index.contains(atomID: "old")
        let hasValid = await index.contains(atomID: "a-valid")
        let dimension = await index.dimension
        XCTAssertEqual(count, 1)
        XCTAssertTrue(hasOld)
        XCTAssertFalse(hasValid)
        XCTAssertEqual(dimension, 2)
    }

    func testPreloadOrThrowLeavesInt8BoundDestinationUnchangedAfterNonfiniteError() async throws {
        let oldFlag = BASVectorIndex.useInt8VectorStorage
        BASVectorIndex.useInt8VectorStorage = true
        defer { BASVectorIndex.useInt8VectorStorage = oldFlag }

        let storage = try BASSQLiteVectorIndexStorage(databaseURL: makeDatabaseURL())
        try await storage.upsert(entry("a-valid", [0, 1]))
        try await storage.upsert(entry("z-invalid", [.infinity, 0]))
        let index = BASVectorIndex()
        let int8 = try XCTUnwrap(BASInt8VectorIndexEntry(
            atomID: "int8-old",
            normalizedEmbedding: [1, 0]
        ))
        try await index.insertInt8(int8)

        do {
            _ = try await storage.preloadOrThrow(into: index)
            XCTFail("preload must reject nonfinite rows before mutating an int8-bound index")
        } catch let error as BASVectorIndex.BASVectorIndexError {
            XCTAssertEqual(error, .nonFiniteEmbedding("z-invalid"))
        }

        let floatCount = await index.entryCount
        let int8Count = await index.int8EntryCount
        let dimension = await index.dimension
        let int8Results = await index.topKInt8(query: embedding([1, 0]), k: 1)
        XCTAssertEqual(floatCount, 0)
        XCTAssertEqual(int8Count, 1)
        XCTAssertEqual(dimension, 2)
        XCTAssertEqual(int8Results.map(\.atomID), ["int8-old"])
    }

    func testPreloadOrThrowEmptyStorageIsNoOp() async throws {
        let storage = try BASSQLiteVectorIndexStorage(databaseURL: makeDatabaseURL())
        let index = BASVectorIndex()
        try await index.upsert(entry("old", [1, 0]))

        let loaded = try await storage.preloadOrThrow(into: index)

        let count = await index.entryCount
        let dimension = await index.dimension
        XCTAssertEqual(loaded, 0)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(dimension, 2)
    }

    private func makeDatabaseURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-vector-atomic-recovery-\(UUID().uuidString).sqlite"
            )
        databaseURLs.append(url)
        return url
    }

    private func embedding(_ vector: [Float]) -> BASEmbedding {
        BASEmbedding(
            vector: vector,
            dimension: vector.count,
            providerVersion: "task-12"
        )
    }

    private func entry(_ atomID: String, _ vector: [Float]) -> BASVectorIndexEntry {
        BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding(vector),
            domain: "test.vector-recovery",
            metadata: ["id": atomID]
        )
    }
}
