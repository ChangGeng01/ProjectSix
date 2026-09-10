import SQLite3

/// Explicit, immutable write and open policy for an App event-log store.
/// `.full` selects SQLite's verified commit synchronization policy; it is not
/// a promise of bitwise RAM/power-loss restoration or filesystem encryption.
public struct BASSQLiteEventLogConfiguration: Sendable, Equatable {
    public enum Synchronization: Sendable, Equatable {
        case normal
        case full
    }

    public let synchronization: Synchronization
    public let useBinaryPayload: Bool
    public let rowIntegrityChainEnabled: Bool
    public let runIntegrityCheckOnOpen: Bool

    public init(
        synchronization: Synchronization,
        useBinaryPayload: Bool = false,
        rowIntegrityChainEnabled: Bool = false,
        runIntegrityCheckOnOpen: Bool = false
    ) {
        self.synchronization = synchronization
        self.useBinaryPayload = useBinaryPayload
        self.rowIntegrityChainEnabled = rowIntegrityChainEnabled
        self.runIntegrityCheckOnOpen = runIntegrityCheckOnOpen
    }

    /// Applies and reads back the settings that define the connection's commit
    /// durability policy. The handle remains owned by its caller.
    func apply(to db: OpaquePointer) throws {
        let journalSQL = "PRAGMA journal_mode=WAL;"
        let journalMode = try Self.singleTextRow(db: db, sql: journalSQL)
        guard journalMode.lowercased() == "wal" else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: journalSQL,
                message: "journal_mode verification expected wal, found \(journalMode)")
        }

        let requestedValue: Int64
        let synchronousSQL: String
        switch synchronization {
        case .normal:
            requestedValue = 1
            synchronousSQL = "PRAGMA synchronous=NORMAL;"
        case .full:
            requestedValue = 2
            synchronousSQL = "PRAGMA synchronous=FULL;"
        }
        try Self.executeDone(db: db, sql: synchronousSQL)
        let readSQL = "PRAGMA synchronous;"
        let found = try Self.singleIntegerRow(db: db, sql: readSQL)
        guard found == requestedValue else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: readSQL,
                message: "synchronous verification expected \(requestedValue), found \(found)")
        }
    }

    private static func prepare(db: OpaquePointer, sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private static func executeDone(db: OpaquePointer, sql: String) throws {
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func singleTextRow(db: OpaquePointer, sql: String) throws -> String {
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) == SQLITE_TEXT,
              let raw = sqlite3_column_text(statement, 0) else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: sql, message: "expected one text result: \(String(cString: sqlite3_errmsg(db)))")
        }
        let value = String(cString: raw)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: sql, message: "expected result completion: \(String(cString: sqlite3_errmsg(db)))")
        }
        return value
    }

    private static func singleIntegerRow(db: OpaquePointer, sql: String) throws -> Int64 {
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) == SQLITE_INTEGER else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: sql, message: "expected one integer result: \(String(cString: sqlite3_errmsg(db)))")
        }
        let value = sqlite3_column_int64(statement, 0)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: sql, message: "expected result completion: \(String(cString: sqlite3_errmsg(db)))")
        }
        return value
    }
}
