// MARK: - BASSQLiteAtomLifecycleStore
// chapter 七百九十二 / M2611-M2615 — L8 storage completion
//
// Cross-session SQLite-backed `BASAtomLifecycleStore` conformer。
// Persists atom-lifecycle events to schema 023 (chapter 七百八十四
// `atom_lifecycle_events`)。 Pairs with:
//
//   - bas-atom-lifecycle Rust crate (chapter 七百八十二):state-
//     machine transitions
//   - BASAtomLifecycleBridge (chapter 七百八十三):Swift bridge to
//     the Rust C ABI
//   - BASAtomLifecycleStore protocol (chapter 七百八十九):persistence
//     seam shared with BASInMemoryAtomLifecycleStore
//
// ## Pattern source
//
// Mirrors BASSQLiteMemoryAtomStore (chapter 二百四十八 / M735):
//   - Owned SQLite handle in an actor
//   - WAL journal mode + synchronous=NORMAL + foreign_keys=ON
//   - schemaVersion read via PRAGMA user_version on first open
//   - All work serialized through actor isolation
//
// ## ADR-014 OPT-IN preserved
//
// BASInMemoryAtomLifecycleStore (chapter 七百八十九) stays the
// LIVE default reference impl。 Hosts opt in to SQLite by passing
// this conformer to any consumer that accepts a
// BASAtomLifecycleStore。 No production caller forced onto SQLite。

import Foundation
import SQLite3

public actor BASSQLiteAtomLifecycleStore: BASAtomLifecycleStore {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case duplicateEventID(String)
    }

    /// Schema version tag stored in PRAGMA user_version。 Bumped when
    /// the atom_lifecycle_events column shape changes。
    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    public let databaseURL: URL

    /// Owned SQLite handle。 Same nonisolated(unsafe) discipline as
    /// BASSQLiteMemoryAtomStore — deinit can close it safely because
    /// actor isolation guarantees no concurrent access at dealloc time。
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Lifecycle

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(
            databaseURL.path, &handle, flags, nil)
        guard openRC == SQLITE_OK, let handle else {
            let message = handle.flatMap { db -> String? in
                String(cString: sqlite3_errmsg(db))
            } ?? "sqlite3_open_v2 rc=\(openRC)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw StorageError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle

        // WAL + sync mode for concurrent reader compatibility
        // (mirrors BASSQLiteMemoryAtomStore pattern)。
        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(db: handle, sql: "PRAGMA synchronous=NORMAL;")

        // PRAGMA user_version branch:0 = empty DB,write our version;
        // equal = OK;mismatch = throw。
        let existingVersion = try Self.readUserVersion(db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }

        // Run schema 023 CREATE statements (idempotent — IF NOT EXISTS)。
        // sqlite3_exec handles multi-statement SQL natively;don't
        // split on `;` because schema comment headers may embed
        // semicolons in narrative text (e.g。 "default 0;flipped to
        // 1 when…")。
        try Self.runExec(db: handle,
            sql: AtomLifecycleEventsSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - BASAtomLifecycleStore conformance

    public func appendEvent(
        _ event: BASAtomLifecycleEvent
    ) async throws -> BASAtomLifecycleEvent {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO atom_lifecycle_events (
                event_id, atom_id, session_id,
                from_phase, to_phase, action, outcome,
                recorded_at_ms, actor_ref
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK,
              let stmt else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        Self.bindText(stmt, 1, event.eventID)
        Self.bindText(stmt, 2, event.atomID)
        Self.bindText(stmt, 3, event.sessionID)
        Self.bindText(stmt, 4,
            Self.phaseString(forByte: event.fromPhaseByte))
        Self.bindText(stmt, 5,
            Self.phaseString(forByte: event.toPhaseByte))
        Self.bindText(stmt, 6,
            Self.actionString(forByte: event.actionByte))
        Self.bindText(stmt, 7,
            Self.outcomeString(forInt32: event.outcome))
        sqlite3_bind_int64(stmt, 8, event.recordedAtMs)
        if let actorRef = event.actorRef {
            Self.bindText(stmt, 9, actorRef)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            // SQLITE_CONSTRAINT (19) on duplicate event_id PK
            if rc == SQLITE_CONSTRAINT {
                throw StorageError.duplicateEventID(event.eventID)
            }
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return event
    }

    public func events(
        forAtom atomID: String
    ) async -> [BASAtomLifecycleEvent] {
        return (try? queryEvents(
            whereClause: "atom_id = ?",
            bindings: [atomID])) ?? []
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASAtomLifecycleEvent] {
        return (try? queryEvents(
            whereClause: "session_id = ?",
            bindings: [sessionID])) ?? []
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM atom_lifecycle_events;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append optimization (chapter 八百四)

    /// Append many events in a single SQLite transaction with a
    /// single re-used prepared statement。 Cuts per-event overhead
    /// from ~60 μs (one fsync each) to ~1-3 μs (amortized fsync
    /// at COMMIT) per the chapter 八百三 measurement。
    ///
    /// Atomicity:on the first error the whole batch is ROLLBACK
    /// and NO records are persisted。 Caller sees either all
    /// events or none — matches the「append-only audit log」
    /// semantic for the schema 023 ledger。
    ///
    /// - Parameter events: events to append in insertion order
    /// - Returns: the same array (call site convenience),OR
    ///   throws if any event fails the CHECK / PK constraints
    ///
    /// Empty input is a no-op (returns []),no transaction opened。
    @discardableResult
    public func appendEventBatch(
        _ events: [BASAtomLifecycleEvent]
    ) async throws -> [BASAtomLifecycleEvent] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if events.isEmpty { return [] }

        // BEGIN IMMEDIATE acquires the writer lock up-front so
        // mid-batch contention can't surface as SQLITE_BUSY half
        // way through。 IMMEDIATE matches WAL journal semantics
        // (chapter 七百九十二 PRAGMA pin)。
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")

        let sql = """
            INSERT INTO atom_lifecycle_events (
                event_id, atom_id, session_id,
                from_phase, to_phase, action, outcome,
                recorded_at_ms, actor_ref
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            try? Self.runExec(db: db, sql: "ROLLBACK;")
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        for event in events {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            Self.bindText(stmt, 1, event.eventID)
            Self.bindText(stmt, 2, event.atomID)
            Self.bindText(stmt, 3, event.sessionID)
            Self.bindText(stmt, 4,
                Self.phaseString(forByte: event.fromPhaseByte))
            Self.bindText(stmt, 5,
                Self.phaseString(forByte: event.toPhaseByte))
            Self.bindText(stmt, 6,
                Self.actionString(forByte: event.actionByte))
            Self.bindText(stmt, 7,
                Self.outcomeString(forInt32: event.outcome))
            sqlite3_bind_int64(stmt, 8, event.recordedAtMs)
            if let actorRef = event.actorRef {
                Self.bindText(stmt, 9, actorRef)
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE {
                try? Self.runExec(db: db, sql: "ROLLBACK;")
                if rc == SQLITE_CONSTRAINT {
                    throw StorageError.duplicateEventID(
                        event.eventID)
                }
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
        }
        try Self.runExec(db: db, sql: "COMMIT;")
        return events
    }

    // MARK: - Query helpers

    private func queryEvents(
        whereClause: String,
        bindings: [String]
    ) throws -> [BASAtomLifecycleEvent] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT event_id, atom_id, session_id,
                   from_phase, to_phase, action, outcome,
                   recorded_at_ms, actor_ref
            FROM atom_lifecycle_events
            WHERE \(whereClause)
            ORDER BY recorded_at_ms ASC, rowid ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, val) in bindings.enumerated() {
            Self.bindText(stmt, Int32(i + 1), val)
        }
        var results: [BASAtomLifecycleEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let eventID = String(cString: sqlite3_column_text(stmt, 0))
            let atomID = String(cString: sqlite3_column_text(stmt, 1))
            let sessionID = String(cString: sqlite3_column_text(stmt, 2))
            let fromPhase = String(cString: sqlite3_column_text(stmt, 3))
            let toPhase = String(cString: sqlite3_column_text(stmt, 4))
            let action = String(cString: sqlite3_column_text(stmt, 5))
            let outcome = String(cString: sqlite3_column_text(stmt, 6))
            let recordedAtMs = sqlite3_column_int64(stmt, 7)
            let actorRefPtr = sqlite3_column_text(stmt, 8)
            let actorRef: String? = actorRefPtr.map {
                String(cString: $0)
            }
            results.append(BASAtomLifecycleEvent(
                eventID: eventID,
                atomID: atomID,
                sessionID: sessionID,
                fromPhaseByte: Self.byteForPhase(fromPhase),
                toPhaseByte: Self.byteForPhase(toPhase),
                actionByte: Self.byteForAction(action),
                outcome: Self.int32ForOutcome(outcome),
                recordedAtMs: recordedAtMs,
                actorRef: actorRef))
        }
        return results
    }

    // MARK: - Phase / Action / Outcome string ↔ byte mappers

    private static func phaseString(forByte b: UInt8) -> String {
        switch b {
        case 0: return "created"
        case 1: return "admitted"
        case 2: return "linked"
        case 3: return "archived"
        case 4: return "tombstoned"
        default: return "created"  // defensive — schema CHECK will reject if unknown
        }
    }

    private static func byteForPhase(_ s: String) -> UInt8 {
        switch s {
        case "created":    return 0
        case "admitted":   return 1
        case "linked":     return 2
        case "archived":   return 3
        case "tombstoned": return 4
        default: return 0
        }
    }

    private static func actionString(forByte b: UInt8) -> String {
        switch b {
        case 0: return "admit"
        case 1: return "link"
        case 2: return "archive"
        case 3: return "tombstone"
        default: return "admit"
        }
    }

    private static func byteForAction(_ s: String) -> UInt8 {
        switch s {
        case "admit":     return 0
        case "link":      return 1
        case "archive":   return 2
        case "tombstone": return 3
        default: return 0
        }
    }

    private static func outcomeString(forInt32 i: Int32) -> String {
        switch i {
        case 0: return "advanced"
        case 1: return "rejected_illegal"
        case 2: return "rejected_terminal"
        default: return "advanced"
        }
    }

    private static func int32ForOutcome(_ s: String) -> Int32 {
        switch s {
        case "advanced":          return 0
        case "rejected_illegal":  return 1
        case "rejected_terminal": return 2
        default: return 0
        }
    }

    // MARK: - SQLite helpers (mirror BASSQLiteMemoryAtomStore)

    private static func runExec(
        db: OpaquePointer, sql: String
    ) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map {
                String(cString: $0)
            } ?? "sqlite3_exec rc=\(rc)"
            if err != nil { sqlite3_free(err) }
            throw StorageError.stepFailed(sql: sql, message: msg)
        }
    }

    private static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    private static func bindText(
        _ stmt: OpaquePointer?,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }
}
