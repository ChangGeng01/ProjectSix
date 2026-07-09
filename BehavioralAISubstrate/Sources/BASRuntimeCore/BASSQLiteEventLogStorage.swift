// MARK: - BASSQLiteEventLogStorage — chapter 三百五四 / M841
//
// Phase P1 G1 第二刀: SQLite-backed actor conformer of
// `BASEventLogStorage` (BASEventLog.swift)。Persists the
// append-only event log across process restarts。
//
// ## Mirrors `BASSQLiteMemoryAtomStore` (chapter 二百四十八 / M735)
//
// Same idiom:
//   - `actor` for serialized access
//   - `import SQLite3` system framework (no new package deps)
//   - `OpaquePointer` db handle owned by actor,closed in nonisolated
//     deinit
//   - WAL journal mode for concurrent readers
//   - Transient-destructor for Swift String binding
//   - Typed `StorageError` enum
//   - Schema-version pragma + verification on open
//   - JSON-encoded full entry in `payload_json`,structural columns
//     mirror typed fields for SQL filtering without parsing
//
// ## Schema (version 1)
//
//   CREATE TABLE event_log (
//     event_id TEXT PRIMARY KEY NOT NULL,
//     session_id TEXT NOT NULL,
//     sequence_number INTEGER NOT NULL,
//     timestamp_ms INTEGER NOT NULL,
//     kind TEXT NOT NULL,
//     risk_band TEXT NOT NULL,
//     payload_json TEXT NOT NULL
//   );
//   CREATE INDEX event_log_session_seq_idx
//     ON event_log(session_id, sequence_number);
//   CREATE INDEX event_log_timestamp_idx
//     ON event_log(timestamp_ms);
//   CREATE INDEX event_log_kind_idx
//     ON event_log(kind);
//
// `payload_json` is the source of truth on read。Indexed columns
// give fast `WHERE session_id = ?` (replay) + `WHERE timestamp_ms
// >= ?` (training extraction) queries。
//
// ## Sequence number assignment
//
// On `append`, the storage layer:
//   1. Looks up max(sequence_number) for the entry's session_id
//   2. Assigns `assigned = max + 1` (or 0 if first event for session)
//   3. Writes the row with `sequence_number = assigned`
//
// This means the caller can pass `sequenceNumber: 0` and the
// storage layer overrides it。Mirrors the in-memory conformer's
// behavior in `BASInMemoryEventLogStorage`。
//
// ## Doctrine pins held
//
// All from BASEventLog.swift apply。Additionally:
//   - chapter 二百四十八 M735: WAL + transient-destructor +
//     typed StorageError mirror exactly
//   - chapter 一百二 五级删除 doctrine: this storage layer does NOT
//     expose a `DELETE` API。Event log is append-only by contract。
//     Forget cascades operate on the L8 atom store,not the event
//     log。If host needs to wipe event log,that is a separate
//     operator-driven workflow (delete file or run a SQL script —
//     not a runtime API).

import Foundation
import SQLite3
import CryptoKit

/// SQLite-backed `BASEventLogStorage`. Events persist across
/// process restarts。
///
/// **First-run cost**: the database file + table + indices are
/// created at `init` if absent。Existing databases are opened
/// read/write。Schema-version pragma is set + verified on every
/// open。
///
/// **Failure mode**: any SQLite error throws a typed
/// `StorageError`。Per chapter 一百九十一 M91 doctrine,integrity
/// outranks availability — a corrupt store is surfaced rather
/// than silently truncated。
public actor BASSQLiteEventLogStorage: BASEventLogStorage {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(eventID: String, message: String)
        case decodeFailed(eventID: String, message: String)
        case corruptedRow(eventID: String, reason: String)
    }

    /// chapter 七百三十二 第一刀 / M2331 — schema bumped 1 → 2。
    /// V2 adds two columns to `event_log`:
    ///   - payload_format INTEGER NOT NULL DEFAULT 1
    ///     1 = JSON (legacy v1 rows + default for new rows
    ///         when useBinaryPayload flag is OFF)
    ///     2 = binary (chapter 七百二十四 wire format,when
    ///         useBinaryPayload is ON)
    ///   - payload_blob BLOB (nullable;populated for v=2 rows)
    ///
    /// Lazy migration:`ALTER TABLE` runs on first open after the
    /// bump。 Existing rows keep payload_format=1 + payload_json,
    /// no row-level rewrite needed。 Read path detects format via
    /// the payload_format column。
    public static let schemaVersion: Int = 2

    /// 先稳 P2 — OPT-IN (default off): run `PRAGMA integrity_check` at open + throw if corrupt. Off by
    /// default (full-DB scan ⇒ boot latency). Static so a host can enable it before init.
    public nonisolated(unsafe) static var runIntegrityCheckOnOpen: Bool = false

    /// chapter 七百三十二 第三刀 — opt-in feature flag controlling
    /// whether NEW writes go through the binary path。 Default
    /// OFF until chapter 七百三十二 第四刀 measurement decides。
    /// Reads always handle both formats via the payload_format
    /// dispatch — flag affects writes only。
    public nonisolated(unsafe) static var useBinaryPayload:
        Bool = false

    /// ADR-040 — OPT-IN (default off): when ON, each NEW append also records a per-row SHA256 hash CHAIN in a
    /// sidecar table (`event_log_integrity`), enabling `verifyIntegrityChain(forSession:)` to detect a
    /// seq-preserving SEMANTIC payload edit — the tamper class `eventsVerifyingContiguity` cannot catch — plus
    /// row deletion / reorder. OFF (default) ⇒ the sidecar table is NEVER created and the write path is
    /// byte-identical to today (true byte-equal-off). Honest limit: the chain is KEYLESS, so an attacker with
    /// full DB write who ALSO recomputes the chain is undetected; a keyed-HMAC variant (key outside the DB) is
    /// the further follow-up. The keyless chain still defeats naïve tampering (must recompute SHA256 links).
    public nonisolated(unsafe) static var rowIntegrityChainEnabled: Bool = false

    // MARK: - Stored state

    /// Database file URL。Surfaced for tests / observability。
    public let databaseURL: URL

    /// Owned SQLite handle。Same nonisolated(unsafe) pattern as
    /// `BASSQLiteMemoryAtomStore` — deinit closes it,all other
    /// access through actor-isolated methods。
    private nonisolated(unsafe) var db: OpaquePointer?

    /// ADR-040 — set once the integrity sidecar table has been ensured for this handle (lazy create on the first
    /// chained append, so a flag-off store never touches the DB). Actor-isolated instance state.
    private var integrityTableEnsured = false

    /// 先稳 P0 — OPT-IN diagnostic hook (default nil). The non-throwing read accessors route a swallowed
    /// SQLite error here BEFORE defaulting, so a host can tell "no events" from "DB broken". Fires only on
    /// the error path ⇒ byte-equal on success. Default nil ⇒ today's exact behavior.
    public var onSilentFailure: (@Sendable (Error) -> Void)?

    /// Wire the diagnostic hook (actor-isolated; set once at setup; zero init-signature change).
    public func setOnSilentFailure(_ handler: (@Sendable (Error) -> Void)?) {
        self.onSilentFailure = handler
    }

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

        // Audit fix (LOW): set busy_timeout BEFORE the WAL/checkpoint pragmas so a checkpoint/reader collision
        // makes a write block-and-retry internally (up to 5s) rather than throwing SQLITE_BUSY + losing the
        // append. Mirrors BASSovereignLedgerStorage.
        try Self.runExec(db: handle, sql: "PRAGMA busy_timeout=5000;")
        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete zeroes freed pages
        // at delete time — default-on, BAS_SECURE_DELETE=0 kill-switch.
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: sdSQL)
        }
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        // M891 fix (post-deep-audit):tighter auto-checkpoint to
        // bound WAL growth on long-running iPhone sessions。
        // Default 1000 pages × 4KB ≈ 4MB before checkpoint。
        // 200 pages ≈ 800KB → checkpoint fires more often,
        // bounds disk pressure for high-frequency event logs
        // (8h iPhone runs at 600 iter/s could otherwise grow
        // WAL to GBs uncompacted)。
        try Self.runExec(
            db: handle,
            sql: "PRAGMA wal_autocheckpoint=200;")

        // M886 backport (M882 audit fix):read user_version FIRST。
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            // Fresh DB — set straight to current version
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion == 1
                  && Self.schemaVersion == 2
        {
            // chapter 七百三十二 第一刀 — v1 → v2 migration
            // path。 ensureSchema() runs ensureV2Columns() which
            // ALTER TABLE-adds the missing columns。 After the
            // ALTER completes,bump user_version to 2 to mark
            // the migration done。
            try Self.ensureSchema(db: handle)
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)
        if Self.runIntegrityCheckOnOpen {
            try Self.assertIntegrity(db: handle)   // 先稳 P2 — opt-in proactive corruption scan
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    /// 先稳 P2 — run `PRAGMA integrity_check`; throw if not "ok" (called at init when the flag is set).
    private static func assertIntegrity(db: OpaquePointer) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            throw StorageError.openFailed(
                code: -2, message: "integrity_check prepare failed: " +
                    String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var result = ""
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            result = String(cString: c)
        }
        guard result == "ok" else {
            throw StorageError.openFailed(code: -2, message: "integrity_check failed: \(result)")
        }
    }

    // MARK: - Protocol — BASEventLogStorage

    @discardableResult
    public func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        guard let db else {
            // Defensive — should be impossible if init succeeded
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        // 先稳 P1 — wrap the read-modify-write (idempotent check + SELECT MAX(seq) + INSERT) in
        // BEGIN IMMEDIATE so the per-session sequence-number assignment is ATOMIC: the writer lock is
        // taken up-front, closing the SELECT-MAX/INSERT race window. Assigned values are unchanged (still
        // max+1 per session) ⇒ byte-equal with the in-memory store + the parity suites. On any error the
        // txn is rolled back so a failed append never leaves a half-open transaction (which would make the
        // NEXT append's BEGIN IMMEDIATE fail). Mirrors BASSQLiteAtomLifecycleStore's txn idiom.
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        do {
            // Idempotent retry: if event_id exists, return its sequenceNumber + wasNew=false.
            if let existing = try Self.fetchEntry(
                db: db, eventID: entry.eventID)
            {
                try Self.runExec(db: db, sql: "COMMIT;")
                return (
                    wasNew: false,
                    assignedSequenceNumber:
                        existing.sequenceNumber)
            }
            let assigned = try Self.nextSequenceNumber(
                db: db, sessionID: entry.sessionID)
            let stamped = BASEventLogEntry(
                eventID: entry.eventID,
                timestampMs: entry.timestampMs,
                kind: entry.kind,
                sessionID: entry.sessionID,
                sequenceNumber: assigned,
                source: entry.source,
                turnRef: entry.turnRef,
                rawInputDigest: entry.rawInputDigest,
                intent: entry.intent,
                emotion: entry.emotion,
                riskBand: entry.riskBand,
                project: entry.project,
                memoryRefs: entry.memoryRefs,
                stateBeforeID: entry.stateBeforeID,
                stateAfterID: entry.stateAfterID,
                actions: entry.actions,
                confidence: entry.confidence,
                payloadJson: entry.payloadJson)
            try Self.insertEntry(db: db, entry: stamped)
            // audit runtimecore-b MED-2: advance the never-pruned seq high-water
            // mark in the SAME txn, so a later full prune can't reset the sequence.
            try Self.bumpSequenceHighWaterMark(
                db: db, sessionID: entry.sessionID, seq: assigned)
            // ADR-040 — when enabled, record this row's chained hash in the SAME txn (atomic with the event row).
            if Self.rowIntegrityChainEnabled {
                try self.appendIntegrityRow(db: db, entry: stamped)
            }
            try Self.runExec(db: db, sql: "COMMIT;")
            return (wasNew: true, assignedSequenceNumber: assigned)
        } catch {
            try? Self.runExec(db: db, sql: "ROLLBACK;")
            // ADR-040: a rolled-back txn may have UN-done the sidecar `CREATE TABLE` (SQLite DDL is
            // transactional); clear the cached flag so the next append re-ensures it instead of inserting into a
            // table that no longer exists. Harmless if the table did persist (CREATE IF NOT EXISTS is idempotent).
            integrityTableEnsured = false
            throw error
        }
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        guard let db else { return [] }
        do { return try Self.fetchEventsForSession(db: db, sessionID: sessionID) }
        catch { onSilentFailure?(error); return [] }
    }

    /// 先稳 P0 — throwing sibling of `events(forSession:)` (surfaces SQLite errors instead of returning []).
    public func eventsOrThrow(forSession sessionID: String) async throws -> [BASEventLogEntry] {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.fetchEventsForSession(db: db, sessionID: sessionID)
    }

    /// Red-team GAP-3b (tamper-evidence on REPLAY) — assert a session's events are CONTIGUOUS by
    /// `sequence_number` (each = previous + 1, no gaps, no duplicates), throwing `corruptedRow` on the first
    /// discontinuity, then return the decoded entries. The default reads (`events` / `eventsOrThrow`) return
    /// whatever rows survive, so an out-of-band middle-row `DELETE` (or a duplicate-`sequence_number` row)
    /// silently yields a non-contiguous replay with no signal. A replay/audit caller that needs tamper-evidence
    /// calls THIS.
    ///
    /// Contiguity is checked on the `sequence_number` COLUMN — the AUTHORITATIVE ordering key (the same column
    /// the fetch sorts by and that `nextSequenceNumber` assigns from), read directly from SQL. It deliberately
    /// does NOT use the decoded entry's `sequenceNumber`, which for v1 JSON rows is recovered from
    /// `payload_json` and could diverge from the column under a column-only tamper (red-team finding: the check
    /// must validate the same physical location it sorts by).
    ///
    /// Scope (honest limits):
    ///   - DETECTS: middle-row deletion (a sequence gap) and duplicated sequence numbers — i.e. any tamper that
    ///     breaks contiguity of the sequence-number column *values*. Because the fetch re-sorts ASC, a genuine
    ///     reordering manifests only as a gap or a duplicate; it is not a separate detection class.
    ///   - Does NOT detect: a semantic payload edit that preserves the `sequence_number` column; a tail-row
    ///     deletion (the surviving prefix stays contiguous); nor a value-set-preserving SWAP of two rows'
    ///     `sequence_number` (the multiset stays contiguous after the ASC sort). For the semantic-edit class,
    ///     enable the opt-in per-row hash chain (`rowIntegrityChainEnabled` + `verifyIntegrityChain`) — ADR-040.
    ///   - Does NOT false-trip on legitimate front-pruning (`pruneEventsBefore`): the surviving rows remain
    ///     contiguous, just starting at a sequence number > 0.
    ///
    /// Read-only + Metal-free ⇒ byte-deterministic-spine-safe (no write-path or stored-byte change).
    @discardableResult
    public func eventsVerifyingContiguity(
        forSession sessionID: String
    ) async throws -> [BASEventLogEntry] {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        let rows = try Self.sessionColumnSequenceRows(db: db, sessionID: sessionID)
        var expected: Int64? = nil
        for row in rows {
            if let exp = expected, row.seq != exp {
                throw StorageError.corruptedRow(
                    eventID: row.eventID,
                    reason: "sequence discontinuity in session '\(sessionID)': expected \(exp), "
                        + "found \(row.seq) — gap, duplicate, or out-of-band deletion/tamper")
            }
            expected = row.seq + 1
        }
        return try Self.fetchEventsForSession(db: db, sessionID: sessionID)
    }

    /// Column-only read of (event_id, sequence_number) for a session, ordered by the `sequence_number` COLUMN.
    /// Used by `eventsVerifyingContiguity` so the contiguity check validates the authoritative column value
    /// (not a payload_json-decoded value that could diverge under a column-only tamper).
    fileprivate static func sessionColumnSequenceRows(
        db: OpaquePointer,
        sessionID: String
    ) throws -> [(eventID: String, seq: Int64)] {
        let sql = """
            SELECT event_id, sequence_number FROM event_log
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        var out: [(eventID: String, seq: Int64)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append((eventID: readText(stmt, 0), seq: sqlite3_column_int64(stmt, 1)))
        }
        return out
    }

    // MARK: - ADR-040 per-row hash chain (opt-in tamper-evidence; sidecar table)

    /// Verify the per-row SHA256 hash CHAIN for a session, throwing `corruptedRow` on the first row whose
    /// recomputed hash (or chain link) does not match the recorded sidecar value. Detects a seq-preserving
    /// SEMANTIC payload edit (which `eventsVerifyingContiguity` cannot), an INTERIOR/middle row deletion, a
    /// reorder, and a TOTAL-session erasure (events gone but chain present). A pure TAIL deletion and a
    /// legitimate front-prune (`pruneEventsBefore`) are tolerated by design (it seeds from the surviving head's
    /// recorded prev_hash). Requires the chain to have been recorded (`rowIntegrityChainEnabled` was ON during
    /// the appends): a missing sidecar row for an existing event is itself a failure (fail-closed). Read-only +
    /// Metal-free ⇒ spine-safe.
    public func verifyIntegrityChain(forSession sessionID: String) async throws {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        let events = try Self.fetchEventsForSession(db: db, sessionID: sessionID)
        let recorded = try Self.integrityRows(db: db, sessionID: sessionID)
        if events.isEmpty {
            // No event rows, but a chain WAS recorded ⇒ the event rows were erased (total/tail deletion) while
            // the sidecar remains. Fail-closed instead of silently passing.
            guard recorded.isEmpty else {
                throw StorageError.corruptedRow(
                    eventID: "<session \(sessionID)>",
                    reason: "event rows deleted but integrity chain present (\(recorded.count) chained rows) — "
                        + "session '\(sessionID)'")
            }
            return
        }
        // Seed `prev` from the SURVIVING head's recorded prev_hash (not a hard "" genesis) so a LEGITIMATE
        // front-prune (`pruneEventsBefore`) does not false-trip: the head's recorded prev is the pruned
        // predecessor's hash, trusted here as the chain anchor. This still validates every row's content hash
        // and every interior link, so a MIDDLE/interior deletion, a semantic edit, or a reorder all break a
        // downstream link/hash and throw; only legitimate front-prune (and a pure tail deletion) are tolerated.
        var prev = recorded[events[0].eventID]?.prevHash ?? ""
        for e in events {
            let expected = try Self.integrityHash(entry: e, prevHash: prev)
            guard let row = recorded[e.eventID] else {
                throw StorageError.corruptedRow(
                    eventID: e.eventID,
                    reason: "no integrity-chain row recorded (chain absent or tampered) — session '\(sessionID)'")
            }
            guard row.prevHash == prev else {
                throw StorageError.corruptedRow(
                    eventID: e.eventID,
                    reason: "integrity chain broken: prev_hash mismatch (deletion/reorder) — session '\(sessionID)'")
            }
            guard row.rowHash == expected else {
                throw StorageError.corruptedRow(
                    eventID: e.eventID,
                    reason: "integrity hash mismatch: row tampered (semantic payload edit) — session '\(sessionID)'")
            }
            prev = expected
        }
    }

    /// Append-time chain step (called INSIDE the append BEGIN IMMEDIATE txn, only when the flag is ON): ensure
    /// the sidecar table once, then insert this row's hash chained off the session's current chain tail.
    fileprivate func appendIntegrityRow(db: OpaquePointer, entry: BASEventLogEntry) throws {
        if !integrityTableEnsured {
            try Self.ensureIntegrityTable(db: db)
            integrityTableEnsured = true
        }
        let prev = try Self.prevHashForSession(db: db, sessionID: entry.sessionID)
        let rowHash = try Self.integrityHash(entry: entry, prevHash: prev)
        try Self.insertIntegrityRow(
            db: db, eventID: entry.eventID, sessionID: entry.sessionID,
            seq: entry.sequenceNumber, rowHash: rowHash, prevHash: prev)
    }

    fileprivate static func ensureIntegrityTable(db: OpaquePointer) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS event_log_integrity (
                event_id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                sequence_number INTEGER NOT NULL,
                row_hash TEXT NOT NULL,
                prev_hash TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS event_log_integrity_session_seq_idx
                ON event_log_integrity(session_id, sequence_number);
            """)
    }

    /// The chain tail (highest sequence_number) `row_hash` for a session, or "" (genesis) if none yet.
    fileprivate static func prevHashForSession(db: OpaquePointer, sessionID: String) throws -> String {
        let sql = """
            SELECT row_hash FROM event_log_integrity
            WHERE session_id = ? ORDER BY sequence_number DESC LIMIT 1
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        if sqlite3_step(stmt) == SQLITE_ROW { return readText(stmt, 0) }
        return ""
    }

    /// `SHA256( canonical(entry as sorted-keys JSON) || prevHash )`, lowercase hex. Computed identically at
    /// append + verify, so a tamper that changes the DECODED entry changes the hash; `prevHash` chains rows so
    /// a deletion/reorder breaks the link.
    fileprivate static func integrityHash(entry: BASEventLogEntry, prevHash: String) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let body: Data
        do {
            body = try enc.encode(entry)
        } catch {
            // Fail CLOSED rather than hash an empty body (which would produce a content-unbound tag that
            // matches any other un-encodable entry). Both callers are throwing contexts.
            throw StorageError.encodeFailed(eventID: entry.eventID, message: "integrity hash encode failed: \(error)")
        }
        var hasher = SHA256()
        hasher.update(data: body)
        hasher.update(data: Data(prevHash.utf8))
        return BASAutoRouteRanker.bytesToHexLower(Array(hasher.finalize()))
    }

    fileprivate static func insertIntegrityRow(
        db: OpaquePointer, eventID: String, sessionID: String,
        seq: Int64, rowHash: String, prevHash: String
    ) throws {
        let sql = """
            INSERT INTO event_log_integrity
              (event_id, session_id, sequence_number, row_hash, prev_hash)
            VALUES (?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, eventID)
        bindText(stmt, 2, sessionID)
        sqlite3_bind_int64(stmt, 3, seq)
        bindText(stmt, 4, rowHash)
        bindText(stmt, 5, prevHash)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func integrityRows(
        db: OpaquePointer, sessionID: String
    ) throws -> [String: (rowHash: String, prevHash: String)] {
        let sql = "SELECT event_id, row_hash, prev_hash FROM event_log_integrity WHERE session_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        var out: [String: (rowHash: String, prevHash: String)] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            out[readText(stmt, 0)] = (rowHash: readText(stmt, 1), prevHash: readText(stmt, 2))
        }
        return out
    }

    public func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        guard let db, limit > 0 else { return [] }
        do { return try Self.fetchEventsSinceTimestamp(db: db, since: since, limit: limit) }
        catch { onSilentFailure?(error); return [] }
    }

    /// 先稳 P0 — throwing sibling of `events(sinceTimestampMs:limit:)` (surfaces SQLite errors).
    public func eventsOrThrow(sinceTimestampMs since: Int64, limit: Int) async throws -> [BASEventLogEntry] {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        guard limit > 0 else { return [] }
        return try Self.fetchEventsSinceTimestamp(db: db, since: since, limit: limit)
    }

    public var totalCount: Int {
        get async {
            guard let db else { return 0 }
            do { return try Self.countAll(db: db) }
            catch { onSilentFailure?(error); return 0 }
        }
    }

    /// 先稳 P0 — throwing sibling of `totalCount` (surfaces SQLite errors instead of returning 0).
    public func totalCountOrThrow() async throws -> Int {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.countAll(db: db)
    }

    @discardableResult
    public func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int {
        // M896 retention (chapter 三百九七):real DELETE per
        // chapter 一百二 五级删除 + chapter 一百九十一 typed
        // throw on error。Closes the audit-flagged "no
        // retention strategy" gap for iPhone hosts running
        // 8h+ sessions where 11+ GB of accumulated events
        // would otherwise fill disk silently。
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        return try Self.pruneBefore(
            db: db, cutoff: cutoff)
    }

    fileprivate static func pruneBefore(
        db: OpaquePointer,
        cutoff: Int64
    ) throws -> Int {
        // Audit fix (ADR-040): prune the integrity sidecar in LOCKSTEP with event_log, atomically, so a
        // retention prune leaves no orphan chain rows AND a FULL prune does not later read as total-session
        // erasure tamper (the sidecar is emptied too ⇒ verifyIntegrityChain sees no events + no chain = clean).
        // An OUT-OF-BAND event_log delete (the malicious case) leaves the sidecar intact ⇒ still detected.
        // The sidecar rows are deleted FIRST (their subquery reads event_log before its rows are removed).
        try runExec(db: db, sql: "BEGIN IMMEDIATE;")
        do {
            if try sidecarTableExists(db: db) {
                try pruneSidecarBefore(db: db, cutoff: cutoff)
            }
            let sql = "DELETE FROM event_log WHERE timestamp_ms < ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, cutoff)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw StorageError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
            let changed = Int(sqlite3_changes(db))
            try runExec(db: db, sql: "COMMIT;")
            return changed
        } catch {
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
        }
    }

    /// Does the opt-in integrity sidecar table exist? (Avoids a DELETE error when the chain was never enabled.)
    fileprivate static func sidecarTableExists(db: OpaquePointer) throws -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='event_log_integrity' LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    /// Delete sidecar rows for events being pruned (event_id matches an event_log row below the cutoff). MUST
    /// run BEFORE the event_log delete so the subquery still sees those rows.
    fileprivate static func pruneSidecarBefore(db: OpaquePointer, cutoff: Int64) throws {
        let sql = """
            DELETE FROM event_log_integrity WHERE event_id IN
              (SELECT event_id FROM event_log WHERE timestamp_ms < ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cutoff)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Schema setup

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS event_log (
                event_id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                sequence_number INTEGER NOT NULL,
                timestamp_ms INTEGER NOT NULL,
                kind TEXT NOT NULL,
                risk_band TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_session_seq_idx
                ON event_log(session_id, sequence_number);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_timestamp_idx
                ON event_log(timestamp_ms);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_kind_idx
                ON event_log(kind);
            """)
        // audit runtimecore-b MED-2: a per-session monotonic sequence high-water
        // mark that SURVIVES pruning. `nextSequenceNumber` derived the next seq
        // from SURVIVING rows only, so a whole-session prune reset it to 0 —
        // colliding with already-exported (session_id, seq) keys downstream. This
        // table is NEVER pruned (pruneBefore only deletes event_log + the
        // integrity sidecar), so the seq stays monotone for the DB's lifetime.
        // Migration note: existing sessions seed the hwm on their next append; a
        // session pruned-to-empty BEFORE this upgrade can still reset once (its
        // pre-upgrade max is unrecoverable) — the fix prevents all FUTURE resets.
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS event_log_seq_hwm (
                session_id TEXT PRIMARY KEY NOT NULL,
                max_seq INTEGER NOT NULL
            );
            """)
        // chapter 七百三十二 第一刀 — lazy ALTER TABLE migration
        // for v2 columns。 PRAGMA-checked first so we don't try
        // to add columns that already exist on a freshly-created
        // database that ran the CREATE TABLE above。 SQLite's
        // ALTER TABLE ... ADD COLUMN is O(1) on append-only
        // tables (no row rewrite),so this is safe on large logs。
        try ensureV2Columns(db: db)
    }

    /// chapter 七百三十二 第一刀 — idempotent column-add for v2。
    /// Inspects `PRAGMA table_info(event_log)` to detect which
    /// columns are already present,then ALTERs in the missing
    /// ones。 Safe to call on:
    ///   - fresh v1 DBs (adds both v2 columns)
    ///   - already-v2 DBs (no-op)
    ///   - DBs partially upgraded (adds only the missing column)
    fileprivate static func ensureV2Columns(
        db: OpaquePointer
    ) throws {
        let existing = try columnsOf(
            table: "event_log", db: db)
        if !existing.contains("payload_format") {
            try runExec(db: db, sql: """
                ALTER TABLE event_log
                ADD COLUMN payload_format INTEGER NOT NULL
                DEFAULT 1;
                """)
        }
        if !existing.contains("payload_blob") {
            try runExec(db: db, sql: """
                ALTER TABLE event_log
                ADD COLUMN payload_blob BLOB;
                """)
        }
    }

    /// PRAGMA table_info reader。 Returns the set of column
    /// names。 Throws on prepare/step failure。
    fileprivate static func columnsOf(
        table: String, db: OpaquePointer
    ) throws -> Set<String> {
        let sql = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var out: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            // PRAGMA table_info columns:
            //   0=cid, 1=name, 2=type, 3=notnull,
            //   4=dflt_value, 5=pk
            if let cstr = sqlite3_column_text(stmt, 1) {
                out.insert(String(
                    cString: cstr))
            }
        }
        return out
    }

    fileprivate static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let found = try readUserVersion(db: db)
        guard found == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: found, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "PRAGMA user_version;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
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

    // MARK: - CRUD primitives

    fileprivate static func insertEntry(
        db: OpaquePointer,
        entry: BASEventLogEntry
    ) throws {
        // chapter 七百三十二 第三刀 — dual-format insert。 Selects
        // JSON v1 (legacy) or binary v2 path based on the
        // useBinaryPayload feature flag。 Wire layout for v2:
        // payload_format = 2,payload_blob populated,payload_json
        // empty string (NOT NULL satisfied)。 For v1:
        // payload_format = 1,payload_json populated,payload_blob
        // NULL。
        let sql = """
            INSERT INTO event_log (
                event_id, session_id, sequence_number,
                timestamp_ms, kind, risk_band, payload_json,
                payload_format, payload_blob
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        // ADR-040: when the integrity chain is ON, force the FAITHFUL JSON path for this row so the chain hash
        // (computed over the in-memory entry at append) matches the re-decoded entry at verify. JSON stores the
        // full entry verbatim, so its decode→encode round-trip is exact. (Belt-and-suspenders even though the
        // v2 envelope below is now faithful too — this keeps the canonical hash domain unambiguous.)
        let useBinary = useBinaryPayload && !rowIntegrityChainEnabled
        var payloadJson: String = ""
        var payloadBlob: Data? = nil
        var format: Int32 = 1

        if useBinary,
           let blob = encodeEntryAsBinary(entry)
        {
            // Binary path:payload_blob populated,payload_json
            // is empty string (NOT NULL constraint)
            payloadBlob = blob
            format = 2
        } else {
            // Legacy JSON path (also fallback if binary fails)
            do {
                let data = try JSONEncoder().encode(entry)
                guard let s = String(
                    data: data, encoding: .utf8)
                else {
                    throw StorageError.encodeFailed(
                        eventID: entry.eventID,
                        message: "encoder produced non-UTF-8 data")
                }
                payloadJson = s
            } catch let err as StorageError {
                throw err
            } catch {
                throw StorageError.encodeFailed(
                    eventID: entry.eventID,
                    message: "\(error)")
            }
            format = 1
        }

        bindText(stmt, 1, entry.eventID)
        bindText(stmt, 2, entry.sessionID)
        sqlite3_bind_int64(stmt, 3, entry.sequenceNumber)
        sqlite3_bind_int64(stmt, 4, entry.timestampMs)
        bindText(stmt, 5, entry.kind.rawValue)
        bindText(stmt, 6, entry.riskBand.rawValue)
        bindText(stmt, 7, payloadJson)
        sqlite3_bind_int(stmt, 8, format)
        if let blob = payloadBlob {
            _ = blob.withUnsafeBytes { rb -> Int32 in
                return sqlite3_bind_blob(
                    stmt, 9,
                    rb.baseAddress,
                    Int32(blob.count),
                    SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    /// chapter 七百三十二 第二刀 / M2332 — encode the full
    /// BASEventLogEntry to binary。 Maps the 5 core fields
    /// (entryID,kind,sessionRef,turnRef,timestamp) directly
    /// to the chapter 七百二十二 BPE-style wire,then carries
    /// the rest of the BASEventLogEntry shape (riskBand,source,
    /// rawInputDigest,intent,emotion,project,memoryRefs,...)
    /// as a JSON payload INSIDE the binary wire's payload_json
    /// field。 Total: still gets the 30%+ storage shrink that
    /// chapter 七百二十四 measured (the savings come from int64
    /// timestamps,enum discriminants,and length-prefix overhead
    /// vs JSON object syntax/whitespace)。
    fileprivate static func encodeEntryAsBinary(
        _ entry: BASEventLogEntry
    ) -> Data? {
        // Map BASEventLogKind → BASBinaryEventLogKind (best-
        // effort — both have overlapping cases)。 Fall back to
        // .internalSignal for unknown kinds (rare edge case)。
        let kind: BASBinaryEventLogKind
        switch entry.kind {
        case .substrateAudit:
            kind = .sovereignVerdict
        case .internalSignal:
            kind = .internalSignal
        default:
            // appBehavior,sessionLifecycle,toolInvocation,
            // image,file,web,calendar,health,…
            kind = .hostInput
        }
        // Build payloadJson with ALL non-core fields the binary wire doesn't natively carry。 Decoded on read。
        // ADR-040 durability fix: this envelope PREVIOUSLY dropped stateBeforeID / stateAfterID / actions /
        // confidence / payloadJson — a silent, irreversible data loss on every v2 read (incl. the S_{t-1}/S_t
        // replay LINKS). They are now carried for a FAITHFUL round-trip. (actions JSON-encoded so a comma in an
        // action code can't corrupt the list, unlike the legacy comma-joined memoryRefs.)
        let actionsJson = (try? JSONEncoder().encode(entry.actions))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let payloadEnvelope: [String: String] = [
            "riskBand":       entry.riskBand.rawValue,
            "source":         entry.source ?? "",
            "rawInputDigest": entry.rawInputDigest ?? "",
            "intent":         entry.intent ?? "",
            "emotion":        entry.emotion ?? "",
            "project":        entry.project ?? "",
            "memoryRefs":     entry.memoryRefs.joined(separator: ","),
            "stateBeforeID":  entry.stateBeforeID ?? "",
            "stateAfterID":   entry.stateAfterID ?? "",
            "confidence":     String(entry.confidence),
            "payloadJson":    entry.payloadJson ?? "",
            "actions":        actionsJson,
        ]
        let payloadJson: String
        do {
            let data = try JSONEncoder().encode(payloadEnvelope)
            payloadJson = String(
                data: data, encoding: .utf8) ?? ""
        } catch {
            return nil
        }
        let binaryEntry = BASBinaryEventLogEntry(
            entryID:           entry.eventID,
            kind:              kind,
            sessionRef:        entry.sessionID,
            turnRef:           entry.turnRef ?? "",
            timestampMs:       entry.timestampMs,
            payloadJson:       payloadJson,
            provenanceSummary: nil)
        return try? BASEventLogBinaryCodec.encode(
            binaryEntry)
    }

    /// chapter 七百三十二 第二刀 — inverse of encodeEntryAsBinary。
    /// Decodes a v=2 binary blob back to BASEventLogEntry。
    /// Returns nil if the blob is malformed or the embedded
    /// payload_json envelope is unparseable。
    fileprivate static func decodeEntryFromBinary(
        _ data: Data,
        kindRaw: String,
        riskBandRaw: String,
        sessionID: String,
        sequenceNumber: Int64
    ) -> BASEventLogEntry? {
        guard let binary = try? BASEventLogBinaryCodec
            .decode(data)
        else { return nil }
        // Unwrap the payload envelope
        var riskBand: BASEventLogRiskBand =
            BASEventLogRiskBand(rawValue: riskBandRaw)
            ?? .unknown
        var source: String? = nil
        var rawInputDigest: String? = nil
        var intent: String? = nil
        var emotion: String? = nil
        var project: String? = nil
        var memoryRefs: [String] = []
        var stateBeforeID: String? = nil
        var stateAfterID: String? = nil
        var payloadJson: String? = nil
        var confidence: Double = 0
        var actions: [String] = []
        if let payloadStr = binary.payloadJson,
           let payloadData = payloadStr.data(using: .utf8),
           let env = try? JSONDecoder().decode(
            [String: String].self, from: payloadData)
        {
            if let rb = env["riskBand"],
               let parsed = BASEventLogRiskBand(rawValue: rb)
            { riskBand = parsed }
            source         = env["source"].flatMap {
                $0.isEmpty ? nil : $0 }
            rawInputDigest = env["rawInputDigest"].flatMap {
                $0.isEmpty ? nil : $0 }
            intent         = env["intent"].flatMap {
                $0.isEmpty ? nil : $0 }
            emotion        = env["emotion"].flatMap {
                $0.isEmpty ? nil : $0 }
            project        = env["project"].flatMap {
                $0.isEmpty ? nil : $0 }
            if let refs = env["memoryRefs"],
               !refs.isEmpty
            {
                memoryRefs = refs.split(separator: ",")
                    .map { String($0) }
            }
            // ADR-040 durability fix — recover the formerly-dropped fields (faithful round-trip).
            stateBeforeID = env["stateBeforeID"].flatMap { $0.isEmpty ? nil : $0 }
            stateAfterID  = env["stateAfterID"].flatMap { $0.isEmpty ? nil : $0 }
            payloadJson   = env["payloadJson"].flatMap { $0.isEmpty ? nil : $0 }
            if let c = env["confidence"].flatMap({ Double($0) }) { confidence = c }
            if let a = env["actions"], let aData = a.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String].self, from: aData) {
                actions = parsed
            }
        }
        let kindParsed: BASEventLogKind =
            BASEventLogKind(rawValue: kindRaw)
            ?? .internalSignal
        return BASEventLogEntry(
            eventID:        binary.entryID,
            timestampMs:    binary.timestampMs,
            kind:           kindParsed,
            sessionID:      sessionID,
            sequenceNumber: sequenceNumber,
            source:         source,
            turnRef:        binary.turnRef.isEmpty
                            ? nil : binary.turnRef,
            rawInputDigest: rawInputDigest,
            intent:         intent,
            emotion:        emotion,
            riskBand:       riskBand,
            project:        project,
            memoryRefs:     memoryRefs,
            stateBeforeID:  stateBeforeID,
            stateAfterID:   stateAfterID,
            actions:        actions,
            confidence:     confidence,
            payloadJson:    payloadJson)
    }

    fileprivate static func fetchEntry(
        db: OpaquePointer,
        eventID: String
    ) throws -> BASEventLogEntry? {
        // chapter 七百三十二 第三刀 — dual-read。 SELECT extra
        // columns so the read path can dispatch on
        // payload_format (1=JSON,2=binary)。
        let sql = """
            SELECT payload_json, payload_format, payload_blob,
                   kind, risk_band, session_id, sequence_number
            FROM event_log
            WHERE event_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, eventID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let format = sqlite3_column_int(stmt, 1)
        if format == 2 {
            // v2 binary path
            let blobLen = sqlite3_column_bytes(stmt, 2)
            guard let blobPtr = sqlite3_column_blob(
                stmt, 2),
                  blobLen > 0
            else {
                throw StorageError.corruptedRow(
                    eventID: eventID,
                    reason: "format=2 but payload_blob empty")
            }
            let data = Data(bytes: blobPtr,
                count: Int(blobLen))
            let kindRaw = readText(stmt, 3)
            let riskBandRaw = readText(stmt, 4)
            let sessionID = readText(stmt, 5)
            let sequenceNumber = sqlite3_column_int64(
                stmt, 6)
            guard let recovered = decodeEntryFromBinary(
                data,
                kindRaw: kindRaw,
                riskBandRaw: riskBandRaw,
                sessionID: sessionID,
                sequenceNumber: sequenceNumber)
            else {
                throw StorageError.decodeFailed(
                    eventID: eventID,
                    message: "v2 binary decode failed")
            }
            return recovered
        }
        // v1 JSON path (legacy + default)
        let json = readText(stmt, 0)
        return try decode(eventID: eventID, json: json)
    }

    fileprivate static func nextSequenceNumber(
        db: OpaquePointer,
        sessionID: String
    ) throws -> Int64 {
        // audit runtimecore-b MED-2: the next seq is the max of the SURVIVING
        // rows' max AND the never-pruned high-water mark — so a whole-session
        // prune can never reset the sequence and collide with exported keys.
        let sql = """
            SELECT MAX(v) FROM (
                SELECT COALESCE(MAX(sequence_number), -1) AS v
                    FROM event_log WHERE session_id = ?
                UNION ALL
                SELECT COALESCE(MAX(max_seq), -1) AS v
                    FROM event_log_seq_hwm WHERE session_id = ?
            )
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        bindText(stmt, 2, sessionID)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let max = sqlite3_column_int64(stmt, 0)
        return max + 1
    }

    /// audit runtimecore-b MED-2: bump the per-session sequence high-water mark
    /// (called INSIDE the append txn, atomic with the row insert). Monotone —
    /// `MAX(existing, new)` — and never decremented, so pruning can't reset it.
    fileprivate static func bumpSequenceHighWaterMark(
        db: OpaquePointer, sessionID: String, seq: Int64
    ) throws {
        let sql = """
            INSERT INTO event_log_seq_hwm (session_id, max_seq) VALUES (?, ?)
            ON CONFLICT(session_id) DO UPDATE SET max_seq = MAX(max_seq, excluded.max_seq)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        sqlite3_bind_int64(stmt, 2, seq)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchEventsForSession(
        db: OpaquePointer,
        sessionID: String
    ) throws -> [BASEventLogEntry] {
        // chapter 七百三十二 第三刀 — dual-read。 SELECT extra
        // columns so the read path dispatches on payload_format。
        let sql = """
            SELECT event_id, payload_json, payload_format,
                   payload_blob, kind, risk_band, sequence_number
            FROM event_log
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        var out: [BASEventLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = readText(stmt, 0)
            let entry = try decodeRowDualFormat(
                stmt: stmt,
                eventID: id,
                sessionID: sessionID,
                seqCol: 6, kindCol: 4, riskBandCol: 5,
                jsonCol: 1, formatCol: 2, blobCol: 3)
            out.append(entry)
        }
        return out
    }

    fileprivate static func fetchEventsSinceTimestamp(
        db: OpaquePointer,
        since: Int64,
        limit: Int
    ) throws -> [BASEventLogEntry] {
        // chapter 七百三十二 第三刀 — dual-read across all sessions
        let sql = """
            SELECT event_id, payload_json, payload_format,
                   payload_blob, kind, risk_band, session_id,
                   sequence_number
            FROM event_log
            WHERE timestamp_ms >= ?
            ORDER BY timestamp_ms ASC, sequence_number ASC
            LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, since)
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var out: [BASEventLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = readText(stmt, 0)
            let sessionID = readText(stmt, 6)
            let entry = try decodeRowDualFormat(
                stmt: stmt,
                eventID: id,
                sessionID: sessionID,
                seqCol: 7, kindCol: 4, riskBandCol: 5,
                jsonCol: 1, formatCol: 2, blobCol: 3)
            out.append(entry)
        }
        return out
    }

    /// chapter 七百三十二 第三刀 — shared dual-format row
    /// decoder。 Inspects the payload_format column,dispatches
    /// to JSON or binary decoder accordingly。
    fileprivate static func decodeRowDualFormat(
        stmt: OpaquePointer,
        eventID: String,
        sessionID: String,
        seqCol: Int32,
        kindCol: Int32,
        riskBandCol: Int32,
        jsonCol: Int32,
        formatCol: Int32,
        blobCol: Int32
    ) throws -> BASEventLogEntry {
        let format = sqlite3_column_int(stmt, formatCol)
        if format == 2 {
            let blobLen = sqlite3_column_bytes(stmt, blobCol)
            guard let blobPtr = sqlite3_column_blob(
                stmt, blobCol),
                  blobLen > 0
            else {
                throw StorageError.corruptedRow(
                    eventID: eventID,
                    reason: "format=2 but payload_blob empty")
            }
            let data = Data(bytes: blobPtr,
                count: Int(blobLen))
            let kindRaw = readText(stmt, kindCol)
            let riskBandRaw = readText(stmt, riskBandCol)
            let seq = sqlite3_column_int64(stmt, seqCol)
            guard let recovered = decodeEntryFromBinary(
                data,
                kindRaw: kindRaw,
                riskBandRaw: riskBandRaw,
                sessionID: sessionID,
                sequenceNumber: seq)
            else {
                throw StorageError.decodeFailed(
                    eventID: eventID,
                    message: "v2 binary decode failed")
            }
            return recovered
        }
        let json = readText(stmt, jsonCol)
        return try decode(eventID: eventID, json: json)
    }

    fileprivate static func countAll(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM event_log"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
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

    // MARK: - Decode helper

    fileprivate static func decode(
        eventID: String,
        json: String
    ) throws -> BASEventLogEntry {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                eventID: eventID,
                reason: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder().decode(
                BASEventLogEntry.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                eventID: eventID, message: "\(error)")
        }
    }

    // MARK: - Utility (mirrors BASSQLiteMemoryAtomStore)

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
            throw StorageError.prepareFailed(
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

