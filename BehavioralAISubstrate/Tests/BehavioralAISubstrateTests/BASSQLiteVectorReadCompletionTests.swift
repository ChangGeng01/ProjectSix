import Foundation
import SQLite3
import XCTest

@testable import BASMemory
@testable import BASRuntimeCore

final class BASSQLiteVectorReadCompletionTests: XCTestCase {
    private enum FixtureError: Error, CustomStringConvertible {
        case sqlite(operation: String, code: Int32, message: String)
        case unexpectedStep(
            expectedRows: [String],
            actualRows: [String],
            finalCode: Int32,
            message: String
        )

        var description: String {
            switch self {
            case let .sqlite(operation, code, message):
                return "\(operation) failed with SQLite code \(code): \(message)"
            case let .unexpectedStep(expectedRows, actualRows, finalCode, message):
                return "expected rows \(expectedRows) followed by SQLITE_ERROR; "
                    + "got rows \(actualRows), final code \(finalCode): \(message)"
            }
        }
    }

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

    func testColdReopenedEmptyStoreIsGenuinelyEmptyAndComplete() async throws {
        let url = makeDatabaseURL()
        do {
            _ = try BASSQLiteVectorIndexStorage(databaseURL: url)
        }

        let reopened = try BASSQLiteVectorIndexStorage(databaseURL: url)
        let entries = try await reopened.allEntriesOrThrow()

        XCTAssertEqual(entries, [])
    }

    func testColdReopenedCompleteStoreReturnsEveryRow() async throws {
        let url = makeDatabaseURL()
        do {
            let store = try BASSQLiteVectorIndexStorage(databaseURL: url)
            try await store.upsert(makeEntry(atomID: "atom-1", value: 1))
            try await store.upsert(makeEntry(atomID: "atom-0", value: 2))
        }

        let reopened = try BASSQLiteVectorIndexStorage(databaseURL: url)
        let entries = try await reopened.allEntriesOrThrow()

        XCTAssertEqual(entries.map(\.atomID), ["atom-0", "atom-1"])
    }

    func testAllEntriesOrThrowPropagatesReadErrorBeforeFirstRow() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteVectorIndexStorage(databaseURL: url)
        try await store.upsert(makeEntry(atomID: "atom-0", value: 1))
        try installRuntimeErrorView(at: url, failingAtomID: "atom-0")
        try verifyRuntimeErrorFixture(at: url, expectedRowsBeforeError: [])

        await assertAllEntriesThrowsStepFailure(store)
    }

    func testAllEntriesOrThrowRejectsAccumulatedRowsAfterLaterReadError() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteVectorIndexStorage(databaseURL: url)
        try await store.upsert(makeEntry(atomID: "atom-0", value: 1))
        try await store.upsert(makeEntry(atomID: "atom-1", value: 2))
        try installRuntimeErrorView(at: url, failingAtomID: "atom-1")
        try verifyRuntimeErrorFixture(
            at: url,
            expectedRowsBeforeError: ["atom-0"]
        )

        await assertAllEntriesThrowsStepFailure(store)
    }

    func testPreloadOrThrowLeavesDestinationUnchangedAfterLaterReadError() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteVectorIndexStorage(databaseURL: url)
        try await store.upsert(makeEntry(atomID: "atom-0", value: 1))
        try await store.upsert(makeEntry(atomID: "atom-1", value: 2))
        try installRuntimeErrorView(at: url, failingAtomID: "atom-1")
        try verifyRuntimeErrorFixture(
            at: url,
            expectedRowsBeforeError: ["atom-0"]
        )
        let destination = BASVectorIndex()
        try await destination.upsert(makeEntry(atomID: "existing", value: 3))

        do {
            _ = try await store.preloadOrThrow(into: destination)
            XCTFail("strict preload must reject an incomplete durable enumeration")
        } catch let error as BASSQLiteVectorIndexStorage.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected stepFailed, got \(error)")
            }
        }

        let count = await destination.entryCount
        let hasExisting = await destination.contains(atomID: "existing")
        let hasPrefix = await destination.contains(atomID: "atom-0")
        XCTAssertEqual(count, 1)
        XCTAssertTrue(hasExisting)
        XCTAssertFalse(hasPrefix)
    }

    private func makeDatabaseURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-vector-read-completion-\(UUID().uuidString).sqlite"
            )
        databaseURLs.append(url)
        return url
    }

    private func makeEntry(atomID: String, value: Float) -> BASVectorIndexEntry {
        let embedding = BASEmbedding(
            vector: [value, 1],
            dimension: 2,
            providerVersion: "read-completion-test"
        )
        return BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding.normalized,
            domain: "test.vector-read-completion",
            metadata: ["source": atomID]
        )
    }

    private func installRuntimeErrorView(
        at url: URL,
        failingAtomID: String
    ) throws {
        let sql = """
            ALTER TABLE vector_index RENAME TO vector_index_backing;
            CREATE VIEW vector_index AS
            SELECT atom_id, dimension, provider_version, embedding_blob, domain,
                   CASE WHEN atom_id = '\(failingAtomID)'
                        THEN abs(-9223372036854775808)
                        ELSE metadata_json
                   END AS metadata_json
            FROM vector_index_backing;
            """
        try withDatabase(at: url) { db in
            var errorMessage: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
            defer { sqlite3_free(errorMessage) }
            guard code == SQLITE_OK else {
                throw FixtureError.sqlite(
                    operation: "install runtime-error view",
                    code: code,
                    message: errorMessage.map { String(cString: $0) }
                        ?? String(cString: sqlite3_errmsg(db))
                )
            }
        }
    }

    private func verifyRuntimeErrorFixture(
        at url: URL,
        expectedRowsBeforeError: [String]
    ) throws {
        try withDatabase(at: url) { db in
            let sql = """
                SELECT atom_id, dimension, provider_version,
                       embedding_blob, domain, metadata_json
                FROM vector_index
                ORDER BY atom_id ASC
                """
            var statement: OpaquePointer?
            let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepareCode == SQLITE_OK, let statement else {
                throw FixtureError.sqlite(
                    operation: "prepare fixture probe",
                    code: prepareCode,
                    message: String(cString: sqlite3_errmsg(db))
                )
            }
            defer { sqlite3_finalize(statement) }

            var rows: [String] = []
            var finalCode = sqlite3_step(statement)
            while finalCode == SQLITE_ROW {
                guard let text = sqlite3_column_text(statement, 0) else {
                    throw FixtureError.sqlite(
                        operation: "read fixture atom_id",
                        code: SQLITE_MISMATCH,
                        message: "atom_id was unexpectedly NULL"
                    )
                }
                rows.append(String(cString: text))
                finalCode = sqlite3_step(statement)
            }

            let message = String(cString: sqlite3_errmsg(db))
            guard rows == expectedRowsBeforeError,
                  finalCode == SQLITE_ERROR,
                  message.contains("integer overflow")
            else {
                throw FixtureError.unexpectedStep(
                    expectedRows: expectedRowsBeforeError,
                    actualRows: rows,
                    finalCode: finalCode,
                    message: message
                )
            }
        }
    }

    private func withDatabase(
        at url: URL,
        _ body: (OpaquePointer) throws -> Void
    ) throws {
        var db: OpaquePointer?
        let openCode = sqlite3_open_v2(
            url.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openCode == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) }
                ?? "sqlite3_open_v2 returned \(openCode)"
            if db != nil { sqlite3_close_v2(db) }
            throw FixtureError.sqlite(
                operation: "open fixture database",
                code: openCode,
                message: message
            )
        }
        defer { sqlite3_close_v2(db) }
        try body(db)
    }

    private func assertAllEntriesThrowsStepFailure(
        _ store: BASSQLiteVectorIndexStorage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            let entries = try await store.allEntriesOrThrow()
            XCTFail(
                "expected a SQLite step failure, got atom IDs \(entries.map(\.atomID))",
                file: file,
                line: line
            )
        } catch let error as BASSQLiteVectorIndexStorage.StorageError {
            guard case .stepFailed = error else {
                XCTFail(
                    "expected stepFailed, got \(error)",
                    file: file,
                    line: line
                )
                return
            }
        } catch {
            XCTFail(
                "expected StorageError.stepFailed, got \(error)",
                file: file,
                line: line
            )
        }
    }
}
