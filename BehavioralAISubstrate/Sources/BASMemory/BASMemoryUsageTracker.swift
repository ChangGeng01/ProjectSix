// MARK: - BASMemoryUsageTracker — chapter 二百五十一 / M738
//
// L8 memory retrieval usage logging — Stage 1 Step 1 of 3
// (Memory Importance Loop).
//
// ## Why this exists
//
// 附录 V Stage 0 closed cross-session memory persistence (chapters
// 二百四十八-二百五十). What's still open: the L8 atom store has
// no signal for "was this atom actually USED" beyond
// `BASMemoryGovernedMemory.lastConfirmedAt: Date?` (single
// timestamp per atom, mutated only on retrieval). With one
// timestamp the scorer cannot distinguish "retrieved 100 times in
// the past hour" vs "retrieved once a week ago" — both look like
// the same `lastConfirmedAt`.
//
// chapter 二百五十一 ships a typed retrieval-event log: every L8
// recall appends one `BASMemoryUsageRecord`. The
// `BASMemoryImportanceScorer` (chapter 二百五十二) reads the log and
// computes `recency × frequency × helped-rate × tier-decay` to
// recommend tier promotion / demotion. The L8 retrieval path
// (chapter 二百五十三) wires both: log on recall, apply scorer
// output via `BASMemoryAtomStore.updateTier(...)`.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: tracker is observability —
//     it records what happened, never grants permits, never feeds
//     base weights. The scorer's tier mutation hint goes through
//     the same `BASMemoryAtomStore` protocol and the same L8
//     governance status pipeline that already exists.
//   - 红线 7 (watcher only-hint): the scorer (next chapter) emits
//     hint records, not commits. The L8 retrieval integration
//     (chapter 二百五十三) calls the existing `updateTier` /
//     `updateGovernanceStatus` mutators which still respect every
//     downstream doctrine gate.
//   - chapter 二百四十八 SQLite idiom: same `import SQLite3`,
//     transient bind destructor, schema-version pragma, WAL mode,
//     actor-isolated `OpaquePointer` via `nonisolated(unsafe)`.
//   - chapter 二百十一 single-source-of-truth: this file owns the
//     `BASMemoryUsageRecord` schema and the tracker actor. No
//     other file defines either.
//
// ## Schema (version 1)
//
//   CREATE TABLE memory_usage_records (
//     record_id TEXT PRIMARY KEY NOT NULL,    -- per-event UUID
//     atom_id TEXT NOT NULL,                  -- BASGovernedMemory.id
//     retrieved_at_ms INTEGER NOT NULL,
//     session_ref TEXT NOT NULL,              -- session ID
//     turn_ref TEXT NOT NULL,                 -- turn ID
//     permit_mode TEXT NOT NULL,              -- BASActionPermitMode raw
//     helped_state TEXT NOT NULL              -- HelpedFlag raw value
//   );
//   CREATE INDEX memory_usage_atom_idx
//     ON memory_usage_records(atom_id);
//   CREATE INDEX memory_usage_session_idx
//     ON memory_usage_records(session_ref);
//
// `helped_state` starts as `.unknown` and may be updated by a
// post-LLM signal — was the response actually informed by this
// atom? The simplest signal: the host runtime sees the LLM output
// reference the atom (e.g. by ID embedded in an audit code) and
// calls `markHelped(recordID:helped:)`. Without that signal the
// scorer treats `.unknown` as a half-credit by default.
//
// ## In-memory mode
//
// Tests + ephemeral hosts pass `databaseURL: nil` to get an
// in-memory tracker (no SQLite, faster, but no cross-session
// continuity). Production hosts pass a SQLite URL paired with the
// chapter 二百四十八 + 二百五十 unified-storage layout.

import Foundation
import SQLite3
import BASRuntimeCore

/// One retrieval event. Append-only log row produced by the L8
/// recall path; consumed by `BASMemoryImportanceScorer` (chapter
/// 二百五十二) when computing per-atom importance scores.
public struct BASMemoryUsageRecord: BASSchemaVersioned,
    Sendable, Equatable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public enum HelpedFlag: String, Codable, Sendable, Hashable {
        /// Default — recall logged, no post-LLM signal yet.
        case unknown
        /// Post-LLM signal: the response did reference / depend
        /// on this atom.
        case helped
        /// Post-LLM signal: the response did not use this atom
        /// (or actively flagged it as unhelpful).
        case notHelped
    }

    public var schemaVersion: String
    public let recordID: String
    public let atomID: String
    public let retrievedAt: Date
    public let sessionRef: String
    public let turnRef: String
    public let permitMode: String
    public var helpedFlag: HelpedFlag

    public init(
        schemaVersion: String =
            BASMemoryUsageRecord.currentSchemaVersion,
        recordID: String? = nil,
        atomID: String,
        retrievedAt: Date = Date(),
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        helpedFlag: HelpedFlag = .unknown
    ) {
        self.schemaVersion = schemaVersion
        self.recordID = recordID ?? UUID().uuidString
        self.atomID = atomID
        self.retrievedAt = retrievedAt
        self.sessionRef = sessionRef
        self.turnRef = turnRef
        self.permitMode = permitMode
        self.helpedFlag = helpedFlag
    }
}

/// Append-only L8 retrieval usage log. Two modes:
///
///   - **In-memory** (databaseURL: nil): records live in the actor
///     for the session only. Tests + ephemeral hosts.
///   - **SQLite-backed** (databaseURL: non-nil): records persist
///     across process restarts; cross-session importance scoring
///     can read history from prior sessions.
///
/// Records are immutable except for `helpedFlag` which the host
/// runtime can flip from `.unknown` to `.helped` / `.notHelped`
/// once the post-LLM "did the response actually use this atom"
/// signal is known.
public actor BASMemoryUsageTracker {

    public enum TrackerError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case unknownRecord(id: String)
    }

    public static let schemaVersion: Int = 1

    /// SQLite file URL when persistent; nil when in-memory.
    public let databaseURL: URL?

    /// SQLite handle (nil in in-memory mode). See chapter
    /// 二百四十八 / M735 commentary on why `nonisolated(unsafe)`
    /// is the right opt-out for deinit cleanup of an
    /// actor-isolated `OpaquePointer`.
    private nonisolated(unsafe) var db: OpaquePointer?

    /// In-memory record store keyed by recordID. Used in
    /// in-memory mode AND as a write-through cache in SQLite
    /// mode (so `recordCount` / `recentRecords` don't need a
    /// SQL round-trip). Reloaded from disk on init.
    private var inMemory: [String: BASMemoryUsageRecord] = [:]

    // MARK: - Lifecycle

    /// Construct an in-memory tracker. No disk I/O.
    public init() {
        self.databaseURL = nil
        self.db = nil
    }

    /// Construct a SQLite-backed tracker. Loads any prior records
    /// from disk into the in-memory cache so subsequent reads
    /// don't need a round-trip.
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
            throw TrackerError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle

        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(db: handle, sql: "PRAGMA foreign_keys=ON;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch 0 → write current,equal → accept,mismatch → throw。
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw TrackerError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)

        // Load prior records into the in-memory cache.
        let prior = try Self.fetchAllRecords(db: handle)
        for record in prior {
            inMemory[record.recordID] = record
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public surface

    /// Append one retrieval event. Returns the recordID so the
    /// host can later call `markHelped(recordID:helped:)` once
    /// the post-LLM signal is known.
    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) async throws -> String {
        let record = BASMemoryUsageRecord(
            atomID: atomID,
            retrievedAt: retrievedAt,
            sessionRef: sessionRef,
            turnRef: turnRef,
            permitMode: permitMode)
        inMemory[record.recordID] = record
        if let db { try Self.insertRecord(db: db, record: record) }
        return record.recordID
    }

    /// Update the `.helped` / `.notHelped` flag on a recorded
    /// event. Throws if the recordID is unknown.
    public func markHelped(
        recordID: String,
        helped: Bool
    ) async throws {
        guard var record = inMemory[recordID] else {
            throw TrackerError.unknownRecord(id: recordID)
        }
        record.helpedFlag = helped ? .helped : .notHelped
        inMemory[recordID] = record
        if let db { try Self.upsertRecord(db: db, record: record) }
    }

    /// Total number of records in the log.
    public var recordCount: Int { inMemory.count }

    /// Number of retrieval events for a given atom.
    public func usageCount(forAtomID atomID: String) -> Int {
        inMemory.values.filter { $0.atomID == atomID }.count
    }

    /// Most recent N records for `atomID`, sorted descending by
    /// `retrievedAt` (newest first). Useful for recency-weighted
    /// scoring.
    public func recentRecords(
        forAtomID atomID: String,
        limit: Int = 50
    ) -> [BASMemoryUsageRecord] {
        let all = inMemory.values.filter { $0.atomID == atomID }
        let sorted = all.sorted { $0.retrievedAt > $1.retrievedAt }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// Every record in the log, sorted ascending by `retrievedAt`.
    /// Used by the scorer to compute global frequency stats.
    public func allRecords() -> [BASMemoryUsageRecord] {
        inMemory.values.sorted {
            $0.retrievedAt < $1.retrievedAt
        }
    }

    /// Look up one record by ID. Returns nil if absent.
    public func record(forID id: String) -> BASMemoryUsageRecord? {
        inMemory[id]
    }

    /// Garbage-collect records older than `olderThan`. Returns
    /// the count of records removed. Hosts call this periodically
    /// to bound disk + memory usage; the scorer typically only
    /// needs records from the last N days.
    @discardableResult
    public func purge(olderThan cutoff: Date) async throws -> Int {
        let stale = inMemory.values
            .filter { $0.retrievedAt < cutoff }
        for record in stale {
            inMemory.removeValue(forKey: record.recordID)
        }
        if let db {
            try Self.deleteOlderThan(db: db, cutoff: cutoff)
        }
        return stale.count
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_records (
                record_id TEXT PRIMARY KEY NOT NULL,
                atom_id TEXT NOT NULL,
                retrieved_at_ms INTEGER NOT NULL,
                session_ref TEXT NOT NULL,
                turn_ref TEXT NOT NULL,
                permit_mode TEXT NOT NULL,
                helped_state TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_atom_idx
              ON memory_usage_records(atom_id);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_session_idx
              ON memory_usage_records(session_ref);
            """)
    }

    private static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw TrackerError.schemaVersionMismatch(
                found: version, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - SQL primitives

    fileprivate static func insertRecord(
        db: OpaquePointer,
        record: BASMemoryUsageRecord
    ) throws {
        try upsertRecord(db: db, record: record)
    }

    fileprivate static func upsertRecord(
        db: OpaquePointer,
        record: BASMemoryUsageRecord
    ) throws {
        let sql = """
            INSERT INTO memory_usage_records (
                record_id, atom_id, retrieved_at_ms,
                session_ref, turn_ref, permit_mode, helped_state
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(record_id) DO UPDATE SET
                helped_state = excluded.helped_state
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, record.recordID)
        bindText(stmt, 2, record.atomID)
        sqlite3_bind_int64(
            stmt, 3,
            Int64(record.retrievedAt.timeIntervalSince1970 * 1000))
        bindText(stmt, 4, record.sessionRef)
        bindText(stmt, 5, record.turnRef)
        bindText(stmt, 6, record.permitMode)
        bindText(stmt, 7, record.helpedFlag.rawValue)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAllRecords(
        db: OpaquePointer
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             ORDER BY retrieved_at_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var records: [BASMemoryUsageRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recordID = readText(stmt, 0)
            let atomID = readText(stmt, 1)
            let ms = sqlite3_column_int64(stmt, 2)
            let sessionRef = readText(stmt, 3)
            let turnRef = readText(stmt, 4)
            let permitMode = readText(stmt, 5)
            let helpedRaw = readText(stmt, 6)
            let helped = BASMemoryUsageRecord.HelpedFlag(
                rawValue: helpedRaw) ?? .unknown
            records.append(BASMemoryUsageRecord(
                recordID: recordID,
                atomID: atomID,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(ms) / 1000),
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                helpedFlag: helped))
        }
        return records
    }

    fileprivate static func deleteOlderThan(
        db: OpaquePointer,
        cutoff: Date
    ) throws {
        let sql = """
            DELETE FROM memory_usage_records
             WHERE retrieved_at_ms < ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(
            stmt, 1,
            Int64(cutoff.timeIntervalSince1970 * 1000))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Utility

    fileprivate static func runExec(
        db: OpaquePointer,
        sql: String
    ) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let message = errMsg.flatMap { ptr -> String in
                let s = String(cString: ptr)
                sqlite3_free(ptr)
                return s
            } ?? "sqlite3_exec rc=\(rc)"
            throw TrackerError.prepareFailed(
                sql: sql, message: message)
        }
    }

    fileprivate static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    fileprivate static func bindText(
        _ stmt: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    fileprivate static func readText(
        _ stmt: OpaquePointer,
        _ index: Int32
    ) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else {
            return ""
        }
        return String(cString: raw)
    }
}
