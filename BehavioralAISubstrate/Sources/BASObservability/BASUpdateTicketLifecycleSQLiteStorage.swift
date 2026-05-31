import Foundation
import SQLite3
import BASRuntimeCore

/// M270 — SQLite-backed implementation of
/// `BASUpdateTicketLifecycleStorage`.
///
/// ## Why this exists
///
/// M268 shipped a JSON-file storage adapter that round-trips the
/// full entry dictionary on every mutation. That works fine for
/// hosts with low ticket throughput, but a single rewrite of the
/// whole file per turn becomes O(N²) on growing pools (10k tickets
/// × per-turn rewrite = 10k disk syncs). M270 trades the
/// per-mutation file rewrite for per-mutation SQLite UPSERT —
/// O(1) write per mutation regardless of pool size.
///
/// Mirrors `BASSovereignLedgerSQLiteStorage` (M91) — same SQLite3
/// system-framework import, same try/finalize discipline, same
/// non-Sendable contract (the actor that owns the storage
/// serializes access).
///
/// ## Schema
///
/// One table:
///
/// ```sql
/// CREATE TABLE IF NOT EXISTS lifecycle_entries (
///     ticket_id  TEXT PRIMARY KEY NOT NULL,
///     state      TEXT NOT NULL,
///     entry_json TEXT NOT NULL
/// );
/// ```
///
/// `entry_json` is a Codable JSON encoding of the full
/// `BASUpdateTicketLifecycleEntry`. Storing the JSON rather than
/// flattening the entry into columns keeps schema migrations
/// simple as the Swift type evolves — `BASUpdateTicketLifecycleEntry`
/// is already Codable + Sendable. `state` is replicated as a
/// column so callers can bypass the JSON parse for queries
/// like "what's in the distillation queue right now."
///
/// `ticket_id` is the natural primary key. `INSERT OR REPLACE`
/// (UPSERT) handles the create vs update branching internally
/// — no need for the caller to track which path applies.
///
/// ## Concurrency
///
/// `BASUpdateTicketLifecycleSQLiteStorage` is **not Sendable**.
/// The host actor (`BASUpdateTicketLifecycleCoordinator`) that
/// owns the storage serializes every call. Two coordinator actors
/// pointing at the same SQLite file would race; M271 (cross-
/// process lock) is the future companion that lets that work.
public final class BASUpdateTicketLifecycleSQLiteStorage:
    BASUpdateTicketLifecycleStorage, @unchecked Sendable
{
    public enum SQLiteError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(reason: String)
        case prepareFailed(sql: String, reason: String)
        case stepFailed(sql: String, reason: String)
        case beginTransactionFailed(reason: String)
        case commitTransactionFailed(reason: String)
        case decodeEntryFailed(ticketID: String, reason: String)
        case encodeEntryFailed(ticketID: String, reason: String)
    }

    public let url: URL

    /// Owned SQLite handle. Lives for the storage instance's
    /// lifetime; closed in deinit. The non-Sendable nature of
    /// raw `OpaquePointer` is why the whole class needs
    /// `@unchecked Sendable` wrapper — host actor's executor
    /// is the synchronization point.
    private var db: OpaquePointer?

    /// M277 — fire `wal_checkpoint(TRUNCATE)` after this many
    /// `save(_:)` calls to keep the `-wal` file from growing
    /// unbounded under sustained high-throughput writes.
    /// Default 100; pass 0 to disable auto-checkpoint (callers
    /// who want fully manual checkpoint scheduling).
    public let autoCheckpointEvery: Int

    /// M277 — count of `save(_:)` calls since the last
    /// checkpoint. Reset to 0 on every successful checkpoint.
    private var savesSinceCheckpoint: Int = 0

    /// ch1044 D6 audit fix — serializes save / checkpoint / load. The owning actor's
    /// `persistQuietly()` dispatches writes inside an unstructured `Task`, and these
    /// methods are `nonisolated async` on a Sendable class, so an awaited call runs on
    /// the GLOBAL concurrent executor — NOT the actor's serial executor. Without this
    /// lock two `BEGIN…COMMIT` transactions can overlap on the one connection
    /// (spurious "transaction within a transaction", or a DELETE landing inside
    /// another save's INSERT loop) and `savesSinceCheckpoint += 1` can lose updates.
    /// Used only via scoped `withLock { performX() }` around the fully-synchronous
    /// `perform*` helpers, so the lock is never held across a suspension point.
    private let ioLock = NSLock()

    public init(
        url: URL,
        autoCheckpointEvery: Int = 100
    ) throws {
        self.url = url
        self.autoCheckpointEvery = max(0, autoCheckpointEvery)
        try openDatabase()
        try createSchemaIfNeeded()
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - Protocol conformance

    public func load() async throws
    -> [String: BASUpdateTicketLifecycleEntry] {
        try ioLock.withLock { try performLoad() }
    }

    private func performLoad() throws
    -> [String: BASUpdateTicketLifecycleEntry] {
        var result: [String: BASUpdateTicketLifecycleEntry] = [:]
        let sql =
            "SELECT ticket_id, entry_json FROM lifecycle_entries"
        var stmt: OpaquePointer?
        let prepRC = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        if prepRC != SQLITE_OK {
            throw SQLiteError.prepareFailed(
                sql: sql,
                reason: lastErrorMessage()
                    ?? "rc=\(prepRC)")
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0)
            else { continue }
            let ticketID = String(cString: idC)
            guard let jsonC = sqlite3_column_text(stmt, 1)
            else { continue }
            let json = String(cString: jsonC)
            guard let data = json.data(using: .utf8) else {
                throw SQLiteError.decodeEntryFailed(
                    ticketID: ticketID,
                    reason: "json column not utf8")
            }
            do {
                let entry = try JSONDecoder().decode(
                    BASUpdateTicketLifecycleEntry.self,
                    from: data)
                result[ticketID] = entry
            } catch {
                throw SQLiteError.decodeEntryFailed(
                    ticketID: ticketID,
                    reason: "\(error)")
            }
        }
        return result
    }

    public func save(
        _ entries: [String: BASUpdateTicketLifecycleEntry]
    ) async throws {
        try ioLock.withLock { try performSave(entries) }
    }

    private func performSave(
        _ entries: [String: BASUpdateTicketLifecycleEntry]
    ) throws {
        // Atomic batch write: BEGIN, DELETE all, INSERT each,
        // COMMIT. On error rollback so a half-written batch
        // doesn't corrupt prior state.
        try execute(sql: "BEGIN TRANSACTION", phase: "begin")
        do {
            try execute(
                sql: "DELETE FROM lifecycle_entries",
                phase: "delete-all")

            let upsertSQL = """
                INSERT INTO lifecycle_entries
                  (ticket_id, state, entry_json)
                VALUES (?, ?, ?)
                """
            var stmt: OpaquePointer?
            let prepRC = sqlite3_prepare_v2(
                db, upsertSQL, -1, &stmt, nil)
            if prepRC != SQLITE_OK {
                throw SQLiteError.prepareFailed(
                    sql: upsertSQL,
                    reason: lastErrorMessage()
                        ?? "rc=\(prepRC)")
            }
            defer { sqlite3_finalize(stmt) }

            for (ticketID, entry) in entries {
                let jsonData: Data
                do {
                    jsonData = try JSONEncoder().encode(entry)
                } catch {
                    throw SQLiteError.encodeEntryFailed(
                        ticketID: ticketID,
                        reason: "\(error)")
                }
                guard let json = String(
                    data: jsonData, encoding: .utf8) else {
                    throw SQLiteError.encodeEntryFailed(
                        ticketID: ticketID,
                        reason: "encoded json not utf8")
                }

                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                _ = sqlite3_bind_text(
                    stmt, 1, ticketID, -1, Self.sqliteTransient)
                _ = sqlite3_bind_text(
                    stmt, 2, entry.state.rawValue, -1,
                    Self.sqliteTransient)
                _ = sqlite3_bind_text(
                    stmt, 3, json, -1,
                    Self.sqliteTransient)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw SQLiteError.stepFailed(
                        sql: upsertSQL,
                        reason: lastErrorMessage()
                            ?? "step != DONE")
                }
            }

            try execute(
                sql: "COMMIT", phase: "commit")
        } catch {
            // Rollback — if BEGIN succeeded we owe a ROLLBACK
            // before re-throwing so the connection state stays
            // consistent.
            _ = try? execute(
                sql: "ROLLBACK", phase: "rollback")
            throw error
        }

        // M277 — auto-checkpoint after threshold writes.
        // Errors absorbed: checkpoint failure shouldn't fail
        // a successful save (the data is durable in WAL even
        // without checkpoint; just the merge to main DB is
        // deferred).
        if autoCheckpointEvery > 0 {
            savesSinceCheckpoint += 1
            if savesSinceCheckpoint >= autoCheckpointEvery {
                _ = try? performCheckpoint()  // already holding ioLock
                savesSinceCheckpoint = 0
            }
        }
    }

    /// M277 — manually trigger `PRAGMA wal_checkpoint(TRUNCATE)`.
    /// Merges any committed-but-not-yet-merged WAL pages into
    /// the main DB and truncates the `-wal` file to zero
    /// length. Hosts call this at known checkpoint moments
    /// (idle, app background, before backup) to bound disk
    /// usage. Returns the number of WAL frames that were
    /// merged + total frames in WAL before the call (for
    /// observability).
    @discardableResult
    public func checkpoint() throws -> CheckpointResult {
        try ioLock.withLock { try performCheckpoint() }
    }

    /// ch1044 D6 — checkpoint body WITHOUT acquiring `ioLock`, for callers already
    /// holding it (e.g. `performSave`'s auto-checkpoint). NSLock is non-recursive, so
    /// re-entering `checkpoint()` from a locked save would deadlock.
    private func performCheckpoint() throws -> CheckpointResult {
        // PRAGMA wal_checkpoint(TRUNCATE) returns one row with
        // 3 columns: busy (0/1), log (frames in WAL),
        // checkpointed (frames merged).
        var stmt: OpaquePointer?
        let sql = "PRAGMA wal_checkpoint(TRUNCATE)"
        let prepRC = sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil)
        if prepRC != SQLITE_OK {
            throw SQLiteError.prepareFailed(
                sql: sql,
                reason: lastErrorMessage()
                    ?? "rc=\(prepRC)")
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.stepFailed(
                sql: sql,
                reason: lastErrorMessage()
                    ?? "step != ROW")
        }
        let busy = sqlite3_column_int(stmt, 0)
        let log = sqlite3_column_int(stmt, 1)
        let checkpointed = sqlite3_column_int(stmt, 2)
        return CheckpointResult(
            wasBusy: busy != 0,
            walFramesAtStart: Int(log),
            framesMerged: Int(checkpointed))
    }

    /// M277 — return current `-wal` file size in bytes, or
    /// `nil` if the file doesn't exist (no writes since last
    /// checkpoint TRUNCATE). Host observability layers use
    /// this to size budgets / decide when to call
    /// `checkpoint()` manually.
    public func walSizeBytes() -> Int64? {
        let walURL = url.appendingPathExtension("wal")
            .deletingPathExtension()
            .appendingPathExtension("sqlite-wal")
        // The actual `-wal` file lives at "<base>-wal" not
        // "<base>.sqlite-wal" — SQLite appends `-wal` to the
        // exact open path. Construct directly.
        let walPath = url.path + "-wal"
        let walFileURL = URL(fileURLWithPath: walPath)
        _ = walURL  // silence; preserved for readability
        guard let attrs = try? FileManager.default
            .attributesOfItem(atPath: walFileURL.path),
            let size = attrs[.size] as? Int64
        else { return nil }
        return size
    }

    /// M277 — observability bundle for one checkpoint call.
    public struct CheckpointResult: Codable, Sendable, Equatable {
        public let wasBusy: Bool
        public let walFramesAtStart: Int
        public let framesMerged: Int
    }

    // MARK: - Helpers

    private func openDatabase() throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(
            url.path, &handle, flags, nil)
        if rc != SQLITE_OK {
            let msg = handle.flatMap {
                String(cString: sqlite3_errmsg($0))
            } ?? "rc=\(rc)"
            sqlite3_close(handle)
            throw SQLiteError.openFailed(reason: msg)
        }
        db = handle

        // M274 — WAL (Write-Ahead Logging) journal mode.
        //
        // Default rollback journal blocks readers while a write
        // transaction is in flight. WAL lets readers proceed
        // concurrently with writers — exactly what hosts running
        // an external offline-distillation pipeline alongside a
        // host runtime need (the pipeline reads the queue while
        // the runtime writes new tickets).
        //
        // WAL mode persists in the DB file (one-time set) but
        // setting on every open is harmless idempotent. Pair
        // with `synchronous=NORMAL` — safer than OFF (still
        // crash-safe at WAL-checkpoint boundaries) and faster
        // than FULL.
        try execute(sql: "PRAGMA journal_mode=WAL",
                    phase: "wal-mode")
        try execute(sql: "PRAGMA synchronous=NORMAL",
                    phase: "synchronous-normal")
    }

    /// M274 — return the active journal mode string. Public so
    /// tests can verify WAL is engaged. Returns `nil` if the
    /// query fails for any reason (defensive — never crashes
    /// the storage instance just because a diagnostic read
    /// errored).
    public func journalMode() -> String? {
        let sql = "PRAGMA journal_mode"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        guard let cstr = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        return String(cString: cstr).lowercased()
    }

    private func createSchemaIfNeeded() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS lifecycle_entries (
                ticket_id  TEXT PRIMARY KEY NOT NULL,
                state      TEXT NOT NULL,
                entry_json TEXT NOT NULL
            )
            """
        try execute(sql: sql, phase: "create-table")

        let indexSQL = """
            CREATE INDEX IF NOT EXISTS lifecycle_state_idx
              ON lifecycle_entries(state)
            """
        try execute(sql: indexSQL, phase: "create-index")
    }

    private func execute(sql: String, phase: String) throws {
        var stmt: OpaquePointer?
        let prepRC = sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil)
        if prepRC != SQLITE_OK {
            throw SQLiteError.prepareFailed(
                sql: sql,
                reason: lastErrorMessage() ?? "rc=\(prepRC)")
        }
        defer { sqlite3_finalize(stmt) }
        let stepRC = sqlite3_step(stmt)
        guard stepRC == SQLITE_DONE
            || stepRC == SQLITE_ROW else {
            switch phase {
            case "begin":
                throw SQLiteError.beginTransactionFailed(
                    reason: lastErrorMessage()
                        ?? "rc=\(stepRC)")
            case "commit":
                throw SQLiteError.commitTransactionFailed(
                    reason: lastErrorMessage()
                        ?? "rc=\(stepRC)")
            default:
                throw SQLiteError.stepFailed(
                    sql: sql,
                    reason: lastErrorMessage()
                        ?? "rc=\(stepRC)")
            }
        }
    }

    private func lastErrorMessage() -> String? {
        guard let db = db else { return nil }
        return String(cString: sqlite3_errmsg(db))
    }

    /// SQLite expects either `SQLITE_STATIC` or `SQLITE_TRANSIENT`
    /// for the destructor parameter on bind. The system header
    /// uses an `unsafeBitCast` of `-1` for transient. Hide the
    /// magic here so call sites stay readable.
    private static let sqliteTransient = unsafeBitCast(
        -1, to: sqlite3_destructor_type.self)
}
