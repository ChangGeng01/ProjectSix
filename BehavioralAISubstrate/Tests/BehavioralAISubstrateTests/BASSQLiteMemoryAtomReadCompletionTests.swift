import Foundation
import SQLite3
import XCTest

@testable import BASMemory

final class BASSQLiteMemoryAtomReadCompletionTests: XCTestCase {
    private enum FailingProjection {
        case atomID
        case payloadJSON
    }

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

    private final class FailureRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var errors: [Error] = []

        func append(_ error: Error) {
            lock.lock()
            errors.append(error)
            lock.unlock()
        }

        var snapshot: [Error] {
            lock.lock()
            defer { lock.unlock() }
            return errors
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

    func testColdReopenedEmptyStoreHasCompleteEmptyEnumerations() async throws {
        let url = makeDatabaseURL()
        do {
            _ = try BASSQLiteMemoryAtomStore(databaseURL: url)
        }

        let reopened = try BASSQLiteMemoryAtomStore(databaseURL: url)
        let atoms = try await reopened.allAtoms()
        let ids = try await reopened.allIDsOrThrow()

        XCTAssertEqual(atoms, [])
        XCTAssertEqual(ids, [])
    }

    func testColdReopenedStoreReturnsEveryAtomAndID() async throws {
        let url = makeDatabaseURL()
        let first = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            content: "first"
        )
        let second = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            content: "second"
        )
        do {
            let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
            try await store.admit(first)
            try await store.admit(second)
        }

        let reopened = try BASSQLiteMemoryAtomStore(databaseURL: url)
        let atoms = try await reopened.allAtoms()
        let ids = try await reopened.allIDsOrThrow()

        XCTAssertEqual(atoms, [first, second])
        XCTAssertEqual(
            ids,
            [first.id.uuidString, second.id.uuidString]
        )
    }

    func testAllAtomsPropagatesReadErrorBeforeFirstRow() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        let atom = makeAtom(content: "only")
        try await store.admit(atom)
        try installRuntimeErrorView(
            at: url,
            failingAtomID: atom.id.uuidString,
            projection: .payloadJSON
        )
        try verifyRuntimeErrorFixture(
            at: url,
            sql: Self.allAtomsSQL,
            rowColumn: 0,
            expectedRowsBeforeError: []
        )

        await assertAllAtomsThrowsStepFailure(store)
    }

    func testAllAtomsRejectsAccumulatedRowsAfterLaterReadError() async throws {
        let url = makeDatabaseURL()
        let first = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            content: "first"
        )
        let second = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            content: "second"
        )
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        try await store.admit(first)
        try await store.admit(second)
        try installRuntimeErrorView(
            at: url,
            failingAtomID: second.id.uuidString,
            projection: .payloadJSON
        )
        try verifyRuntimeErrorFixture(
            at: url,
            sql: Self.allAtomsSQL,
            rowColumn: 0,
            expectedRowsBeforeError: [first.id.uuidString]
        )

        await assertAllAtomsThrowsStepFailure(store)
    }

    func testAllIDsOrThrowPropagatesReadErrorBeforeFirstRow() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        let atom = makeAtom(content: "only")
        try await store.admit(atom)
        try installRuntimeErrorView(
            at: url,
            failingAtomID: atom.id.uuidString,
            projection: .atomID
        )
        try verifyRuntimeErrorFixture(
            at: url,
            sql: Self.allIDsSQL,
            rowColumn: 0,
            expectedRowsBeforeError: []
        )

        await assertAllIDsThrowsStepFailure(store)
    }

    func testAllIDsOrThrowRejectsAccumulatedRowsAfterLaterReadError() async throws {
        let url = makeDatabaseURL()
        let first = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
            content: "first"
        )
        let second = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
            content: "second"
        )
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        try await store.admit(first)
        try await store.admit(second)
        try installRuntimeErrorView(
            at: url,
            failingAtomID: second.id.uuidString,
            projection: .atomID
        )
        try verifyRuntimeErrorFixture(
            at: url,
            sql: Self.allIDsSQL,
            rowColumn: 0,
            expectedRowsBeforeError: [first.id.uuidString]
        )

        await assertAllIDsThrowsStepFailure(store)
    }

    func testLegacyAllIDsDefaultsAndReportsTheStrictReadFailure() async throws {
        let url = makeDatabaseURL()
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        let first = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
            content: "first"
        )
        let second = makeAtom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
            content: "second"
        )
        try await store.admit(first)
        try await store.admit(second)
        try installRuntimeErrorView(
            at: url,
            failingAtomID: second.id.uuidString,
            projection: .atomID
        )
        let recorder = FailureRecorder()
        await store.setOnSilentFailure { recorder.append($0) }

        let legacyIDs = await store.allIDs

        XCTAssertEqual(legacyIDs, [])
        XCTAssertEqual(recorder.snapshot.count, 1)
        guard let error = recorder.snapshot.first as? BASSQLiteMemoryAtomStore.StorageError,
              case .stepFailed = error
        else {
            return XCTFail("legacy callback must receive the strict stepFailed error")
        }
    }

    func testAllAtomsPreservesMalformedDecodeError() async throws {
        let url = makeDatabaseURL()
        let atom = makeAtom(content: "decode-target")
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url)
        try await store.admit(atom)
        try execute(
            at: url,
            sql: "UPDATE memory_atoms SET payload_json = '{' WHERE atom_id = '\(atom.id.uuidString)'"
        )

        do {
            _ = try await store.allAtoms()
            XCTFail("malformed payload_json must fail the authoritative enumeration")
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case let .decodeFailed(atomID, _) = error else {
                return XCTFail("expected decodeFailed, got \(error)")
            }
            XCTAssertEqual(atomID, atom.id.uuidString)
        }
    }

    private static let allIDsSQL = "SELECT atom_id FROM memory_atoms"

    private static let allAtomsSQL = """
        SELECT atom_id, payload_json FROM memory_atoms
         ORDER BY created_at_ms ASC, atom_id ASC
        """

    private func makeDatabaseURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-atom-read-completion-\(UUID().uuidString).sqlite"
            )
        databaseURLs.append(url)
        return url
    }

    private func makeAtom(id: UUID = UUID(), content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: .episodic,
            content: content,
            scope: .session,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.7,
            sourceType: "test.atom-read-completion",
            governanceStatus: .governed,
            provenanceSummary: "task-12"
        )
    }

    private func installRuntimeErrorView(
        at url: URL,
        failingAtomID: String,
        projection: FailingProjection
    ) throws {
        let atomIDExpression: String
        let payloadExpression: String
        switch projection {
        case .atomID:
            atomIDExpression = "CASE WHEN atom_id = '\(failingAtomID)' "
                + "THEN abs(-9223372036854775808) ELSE atom_id END"
            payloadExpression = "payload_json"
        case .payloadJSON:
            atomIDExpression = "atom_id"
            payloadExpression = "CASE WHEN atom_id = '\(failingAtomID)' "
                + "THEN abs(-9223372036854775808) ELSE payload_json END"
        }
        let sql = """
            ALTER TABLE memory_atoms RENAME TO memory_atoms_backing;
            UPDATE memory_atoms_backing SET created_at_ms = rowid;
            CREATE INDEX memory_atoms_backing_created_id_idx
                ON memory_atoms_backing(created_at_ms, atom_id);
            CREATE VIEW memory_atoms AS
            SELECT \(atomIDExpression) AS atom_id,
                   kind, scope, sensitivity, tier, governance_status,
                   created_at_ms, last_updated_at_ms,
                   \(payloadExpression) AS payload_json
            FROM memory_atoms_backing;
            """
        try execute(at: url, sql: sql)
    }

    private func verifyRuntimeErrorFixture(
        at url: URL,
        sql: String,
        rowColumn: Int32,
        expectedRowsBeforeError: [String]
    ) throws {
        try withDatabase(at: url) { db in
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
                guard let text = sqlite3_column_text(statement, rowColumn) else {
                    throw FixtureError.sqlite(
                        operation: "read fixture row",
                        code: SQLITE_MISMATCH,
                        message: "selected text was unexpectedly NULL"
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

    private func execute(at url: URL, sql: String) throws {
        try withDatabase(at: url) { db in
            var errorMessage: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
            defer { sqlite3_free(errorMessage) }
            guard code == SQLITE_OK else {
                throw FixtureError.sqlite(
                    operation: "execute fixture SQL",
                    code: code,
                    message: errorMessage.map { String(cString: $0) }
                        ?? String(cString: sqlite3_errmsg(db))
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

    private func assertAllAtomsThrowsStepFailure(
        _ store: BASSQLiteMemoryAtomStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            let atoms = try await store.allAtoms()
            XCTFail(
                "expected a SQLite step failure, got atom IDs \(atoms.map { $0.id.uuidString })",
                file: file,
                line: line
            )
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected stepFailed, got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("expected StorageError.stepFailed, got \(error)", file: file, line: line)
        }
    }

    private func assertAllIDsThrowsStepFailure(
        _ store: BASSQLiteMemoryAtomStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            let ids = try await store.allIDsOrThrow()
            XCTFail(
                "expected a SQLite step failure, got atom IDs \(ids.sorted())",
                file: file,
                line: line
            )
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected stepFailed, got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("expected StorageError.stepFailed, got \(error)", file: file, line: line)
        }
    }
}
