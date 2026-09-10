import Foundation
import SQLite3

/// Synchronous, non-owning metadata reader used while the storage actor is
/// isolated. It neither closes nor exposes the actor-owned connection.
struct BASSQLiteEventLogSessionDiscoveryReader {
    private let db: OpaquePointer

    init(db: OpaquePointer) {
        self.db = db
    }

    func read(
        prefix: String,
        after: String?,
        limits: BASEventLogSessionDiscoveryLimits
    ) throws -> BASEventLogSessionPage {
        let prefixUTF8 = prefix.utf8
        guard !prefixUTF8.isEmpty,
              prefixUTF8.count <= limits.maximumSessionIDBytes else {
            throw BASEventLogSessionDiscoveryError.invalidQuery
        }
        if let after {
            let afterUTF8 = after.utf8
            guard afterUTF8.count <= limits.maximumSessionIDBytes,
                  afterUTF8.starts(with: prefixUTF8) else {
                throw BASEventLogSessionDiscoveryError.invalidQuery
            }
        }

        try execute("BEGIN DEFERRED;")
        do {
            let result = try readPage(
                prefix: prefix, after: after, limits: limits)
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func readPage(
        prefix: String,
        after: String?,
        limits: BASEventLogSessionDiscoveryLimits
    ) throws -> BASEventLogSessionPage {
        let upperBound = Self.exclusivePrefixUpperBound(prefix)
        var predicates = ["session_id >= ? COLLATE BINARY"]
        if upperBound != nil { predicates.append("session_id < ? COLLATE BINARY") }
        if after != nil { predicates.append("session_id > ? COLLATE BINARY") }
        let sql = """
            SELECT MIN(rowid), typeof(session_id)
            FROM event_log INDEXED BY event_log_session_seq_idx
            WHERE \(predicates.joined(separator: " AND "))
            GROUP BY session_id COLLATE BINARY
            ORDER BY session_id COLLATE BINARY
            LIMIT ?
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var binding: Int32 = 1
        try bindText(statement, index: binding, value: prefix)
        binding += 1
        if let upperBound {
            try bindText(statement, index: binding, value: upperBound)
            binding += 1
        }
        if let after {
            try bindText(statement, index: binding, value: after)
            binding += 1
        }
        guard sqlite3_bind_int64(
            statement, binding, Int64(limits.maximumSessionCount + 1)) == SQLITE_OK else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }

        var metadata: [(rowID: Int64, type: String)] = []
        var hasLookahead = false
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(sql) }
            guard sqlite3_column_type(statement, 0) == SQLITE_INTEGER,
                  sqlite3_column_type(statement, 1) == SQLITE_TEXT,
                  let rawType = sqlite3_column_text(statement, 1) else {
                throw BASEventLogSessionDiscoveryError.malformedIdentity
            }
            if metadata.count < limits.maximumSessionCount {
                metadata.append((
                    rowID: sqlite3_column_int64(statement, 0),
                    type: String(cString: rawType)))
            } else {
                hasLookahead = true
            }
        }

        let recoveryReader = BASSQLiteEventLogRecoveryReader(db: db)
        var sessionIDs: [String] = []
        var totalBytes = 0
        for item in metadata {
            let identity = try recoveryReader.sessionIdentity(
                rowID: item.rowID,
                storedType: item.type,
                maximumUTF8Bytes: limits.maximumSessionIDBytes)
            let (newTotal, overflow) = totalBytes.addingReportingOverflow(identity.utf8ByteCount)
            guard !overflow, newTotal <= limits.maximumTotalSessionIDBytes else {
                throw BASEventLogSessionDiscoveryError.totalSessionIDBytesExceeded
            }
            totalBytes = newTotal
            sessionIDs.append(identity.value)
        }
        return BASEventLogSessionPage(
            sessionIDs: sessionIDs,
            nextAfter: hasLookahead ? sessionIDs.last : nil)
    }

    private static func exclusivePrefixUpperBound(_ prefix: String) -> String? {
        var scalars = Array(prefix.unicodeScalars)
        while let last = scalars.popLast() {
            let value = last.value
            let nextValue: UInt32
            if value < 0xD7FF {
                nextValue = value + 1
            } else if value == 0xD7FF {
                nextValue = 0xE000
            } else if value < 0x10FFFF {
                nextValue = value + 1
            } else {
                continue
            }
            guard let next = Unicode.Scalar(nextValue) else { continue }
            scalars.append(next)
            return String(String.UnicodeScalarView(scalars))
        }
        return nil
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func bindText(
        _ statement: OpaquePointer,
        index: Int32,
        value: String
    ) throws {
        let bytes = Array(value.utf8)
        guard bytes.count <= Int(Int32.max) else {
            throw BASEventLogSessionDiscoveryError.invalidQuery
        }
        let rc = bytes.withUnsafeBytes { raw in
            sqlite3_bind_text(
                statement, index,
                raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                Int32(raw.count), transient)
        }
        guard rc == SQLITE_OK else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: "bind session discovery query",
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func execute(_ sql: String) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw stepError(sql) }
    }

    private func stepError(_ sql: String) -> BASSQLiteEventLogStorage.StorageError {
        .stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
    }

    private var transient: sqlite3_destructor_type {
        unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    }
}
