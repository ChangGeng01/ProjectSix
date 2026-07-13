import Foundation
import SQLite3
import BASRuntimeCore

/// M91 — Cross-process persistence for `BASSovereignAuditLedger`.
///
/// ## Why this exists
///
/// Pre-M91 the ledger was actor-resident only. A process restart
/// erased every audit entry, every segment, every coverage verdict,
/// every LINEAGE_CUT outcome. BR-012's chain-integrity promise only
/// held within a single process lifetime; the "integrity > availability"
/// failure-closed doctrine the ledger was built around was vacuously
/// true because the chain never survived a crash.
///
/// M91 introduces a storage protocol + a SQLite-backed implementation.
/// A ledger constructed with storage loads prior entries + segments at
/// init, appends to storage on every append / rotation, and — because
/// Ed25519 signatures (M87) are public-key verifiable — a cross-process
/// verifier reading the same SQLite file can reconstruct and verify the
/// chain independently.
///
/// ## M91 scope (what is / isn't persisted)
///
/// Persisted (two SQLite tables):
///   - `audit_entries` — every append-only hash-chained entry (what
///     BR-012 actually depends on for integrity)
///   - `segments` — per-session rotation state (`closedAt`,
///     `closedBy`, `closingRotationID`, `tailHash`) that is NOT
///     re-derivable from entries alone and thus must survive restart
///
/// NOT yet persisted (stay in-memory, re-derive or rebuild on next
/// live session — slated for M92 extension):
///   - `coverageVerdicts[]` (M45 rollup) — re-derivable from a fresh
///     `recordTurnCoverage()` call; observability not integrity
///   - `observationBundles[]` (M90 L1–L13 stream) — observer-level
///     data, opt-in, acceptable loss on restart
///   - `cutOutcomes[:]` (M83 LINEAGE_CUT reverse index) — derivable
///     by scanning loaded entries for marker audits
///
/// This partition is deliberate: M91 persists the data whose loss
/// breaks BR-012 (chain integrity) and whose absence cannot be
/// reconstructed (segment rotation metadata). Everything else is
/// observer-grade and cleanly recoverable next session.
///
/// ## Thread-safety
///
/// `BASSovereignLedgerSQLiteStorage` is NOT Sendable — every call must
/// happen from inside the `BASSovereignAuditLedger` actor. The
/// `BASSovereignLedgerStorage` protocol does not promise
/// concurrency-safe access on its own; it's the ledger actor's job
/// to serialize.

// MARK: - Protocol

/// A pluggable storage surface for the sovereign audit ledger.
///
/// The two concrete implementations M91 ships with are:
///
/// - `BASSovereignLedgerNullStorage` — the default "in-memory only"
///   mode that preserves pre-M91 behaviour byte-for-byte
/// - `BASSovereignLedgerSQLiteStorage` — SQLite-backed cross-process
///   persistence
///
/// Hosts that want their own persistence (e.g. in-app keychain-wrapped
/// blob, encrypted vault, remote sink) can implement the protocol
/// directly. All methods are synchronous and must throw on any I/O
/// or integrity failure — the ledger actor serializes access.
public protocol BASSovereignLedgerStorage {
    /// Load prior state from persistent storage. Called once during
    /// `BASSovereignAuditLedger` init. Implementations should return
    /// `([], [])` for a fresh store.
    ///
    /// The entries MUST be returned in chain order (oldest first).
    /// Segments MAY be returned in any order; the ledger will
    /// re-index them on load.
    func loadState() throws -> (
        entries: [BASSovereignAuditLedger.AppendedEntry],
        segments: [BASSovereignLedgerSegment])

    /// Persist one freshly-appended audit entry. Called from inside
    /// the actor on every successful `append(...)`.
    func persistAppended(
        _ entry: BASSovereignAuditLedger.AppendedEntry
    ) throws

    /// Persist a segment (insert or update by `segmentID`).
    /// Called from inside the actor on rotation or when segments
    /// change state.
    func persistSegment(_ segment: BASSovereignLedgerSegment) throws

    /// audit F3 (2026-07-12): persist a freshly-appended entry AND its owning segment
    /// ATOMICALLY — either both rows commit or neither does. `append()` mutates memory then
    /// mirrors to disk; before this, the two writes were independent autocommits, so a
    /// transient failure on the segment write after the entry committed left a DURABLE orphan
    /// entry whose segment count is under-recorded, and the next cold-start
    /// `segmentTotal != entries.count` cross-check permanently quarantines the whole ledger.
    ///
    /// deep-audit P2-15 (2026-07-13): this is a REQUIRED method with NO protocol-extension
    /// default — atomicity is a forcing function, not an opt-in. Previously a default provided
    /// the legacy non-atomic two-write sequence, so a host storage that simply forgot to
    /// override it silently inherited the orphan-quarantine hazard the F3 method exists to
    /// close. Every conformer must now CONSCIOUSLY decide: a store with real durability MUST
    /// wrap both writes in one transaction (see `BASSovereignLedgerSQLiteStorage`); a store
    /// that persists nothing (null) implements a no-op; a store that legitimately keeps the
    /// two-write sequence must write it out explicitly, acknowledging the non-atomicity.
    func persistAppendedEntryAndSegment(
        _ appended: BASSovereignAuditLedger.AppendedEntry,
        _ segment: BASSovereignLedgerSegment
    ) throws
}

// MARK: - Default null storage (pre-M91 in-memory-only behaviour)

/// Default storage that persists nothing. A ledger constructed
/// without an explicit storage uses this. Every method is a no-op;
/// `loadState()` always returns empty state. Preserves pre-M91
/// behaviour byte-for-byte.
public struct BASSovereignLedgerNullStorage: BASSovereignLedgerStorage {
    public init() {}

    public func loadState() throws -> (
        entries: [BASSovereignAuditLedger.AppendedEntry],
        segments: [BASSovereignLedgerSegment]
    ) {
        ([], [])
    }

    public func persistAppended(
        _ entry: BASSovereignAuditLedger.AppendedEntry
    ) throws {}

    public func persistSegment(
        _ segment: BASSovereignLedgerSegment
    ) throws {}

    /// deep-audit P2-15 (2026-07-13): null storage persists nothing, so the F3 atomic
    /// entry+segment write is trivially satisfied by a no-op — there is no disk state that
    /// could be left half-written. Written out explicitly now that there is no protocol default.
    public func persistAppendedEntryAndSegment(
        _ appended: BASSovereignAuditLedger.AppendedEntry,
        _ segment: BASSovereignLedgerSegment
    ) throws {}
}

// MARK: - SQLite-backed storage

/// SQLite-backed persistence for the audit ledger. Two tables,
/// schema version 1:
///
///   audit_entries(
///     audit_id PRIMARY KEY,
///     session_id, turn_id, verdict_ref,
///     rule_ids, signal_refs, action_refs,   -- comma-joined
///     snapshot_ref,
///     actor, signature, appended_at_ms,
///     prior_hash, self_hash,
///     insertion_order  -- explicit chain order
///   )
///
///   segments(
///     segment_id PRIMARY KEY,
///     segment_index INTEGER,
///     session_id TEXT,
///     start_anchor TEXT,
///     tail_hash TEXT,                      -- NULL for open
///     entry_count INTEGER,
///     opened_at_ms INTEGER,
///     closed_at_ms INTEGER,                -- NULL for open
///     closed_by TEXT,                      -- NULL for open
///     closing_rotation_id TEXT             -- NULL for open
///   )
///
/// A schema-version pragma is set at open so future migrations can
/// detect the need to run ALTER TABLE. The current value is fixed at
/// 1; any mismatch on open throws `.schemaVersionMismatch`.
public final class BASSovereignLedgerSQLiteStorage:
    BASSovereignLedgerStorage
{
    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case corruptedRow(table: String, reason: String)
    }

    /// chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1 fix:
    /// bumped from 1 → 2 to add `entry_schema_version` column to
    /// `audit_entries`。 Pre-ch-994.5 schema dropped per-entry
    /// schemaVersion on persist + reload,so ch 993's hardened
    /// "1.1.0" warrant entries (which use U+001F separators in
    /// canonical bytes) would resurrect with the default "1.0.0"
    /// schemaVersion on restart → canonical-bytes recomputation
    /// picks the OLD `,`/`|` separators → signature verification
    /// fails for every reloaded 1.1.0 entry → ledger flagged
    /// corrupt。 Real ledger-integrity break。
    ///
    /// Migration: schema 1 → 2 adds `entry_schema_version TEXT
    /// NOT NULL DEFAULT '1.0.0'` column。 SQLite ALTER TABLE ADD
    /// COLUMN auto-fills existing rows with the default,
    /// preserving signature verification for pre-ch-994.5 1.0.0
    /// entries。 New writes bind `entry.schemaVersion` explicitly。
    public static let schemaVersion: Int = 2

    private var db: OpaquePointer?
    private let path: String

    public init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle else {
            let msg = handle.flatMap { db -> String? in
                String(cString: sqlite3_errmsg(db))
            } ?? "sqlite3_open_v2 rc=\(rc)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw StorageError.openFailed(code: rc, message: msg)
        }
        self.db = handle

        // chapter 九百九十六.7 META-REVIEW Round-16 MED-1 fix:
        // Swift does NOT call deinit on a class whose init
        // throws,so any throw after `sqlite3_open_v2` succeeded
        // but before init returns LEAKS the open SQLite handle
        // (deinit at line 314 never fires)。 Wrap all post-open
        // setup in a do-catch that closes the handle on any
        // throw,then rethrows the original error。
        do {
            // chapter 九百九十五.5 Round-12 HIGH-2 fix:set
            // busy_timeout BEFORE any other pragmas so concurrent
            // first-open of a fresh DB doesn't hit SQLITE_BUSY
            // on journal_mode/foreign_keys writes。 Round-11
            // HIGH-2 had set busy_timeout ONLY inside the
            // v1→v2 migration branch — Round-12 caught the
            // remaining gap at WAL setup。
            try Self.runExec(
                db: handle,
                sql: "PRAGMA busy_timeout=5000;")
            try Self.runExec(
                db: handle,
                sql: "PRAGMA journal_mode=WAL;")
            // #16 删除教义 (mega-audit, 2026-07-08): secure_delete default-on (kill-switch BAS_SECURE_DELETE=0).
            if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
                try Self.runExec(db: handle, sql: sdSQL)
            }
            // memory-a F4 residual: one-time legacy freelist purge (secure_delete only
            // zeroes NEW deletions; VACUUM once rewrites the file, dropping pre-fix
            // plaintext). Marker-gated ⇒ steady-state cost is one SELECT. Outside any txn.
            BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
            try Self.runExec(
                db: handle,
                sql: "PRAGMA foreign_keys=ON;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch 0 → write current,equal → accept,mismatch → throw。
        //
        // chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1
        // migration:schema 1 → 2 adds entry_schema_version column。
        // Migration path:read pre-existing v1 DB → ALTER TABLE ADD
        // COLUMN with safe default → bump user_version。
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion == 1 &&
                  Self.schemaVersion == 2
        {
            // ch 994.5 CRITICAL-1 migration:v1 → v2 adds
            // entry_schema_version column with DEFAULT '1.0.0'。
            // SQLite ALTER TABLE ADD COLUMN auto-fills existing
            // rows,preserving signature verification for old
            // 1.0.0 entries (canonical-bytes still picks OLD
            // separator for them per the per-entry schemaVersion
            // gate in basSovereignAuditCanonicalBytes)。
            //
            // chapter 九百九十四.7 META-REVIEW Round-11 HIGH-2 fix:
            // Round-11 caught 3 migration edge cases:
            //   (a) crash between ALTER and PRAGMA → re-open
            //       finds column-already-exists,ALTER throws
            //       duplicate-column → unrecoverable
            //   (b) ensureSchema runs AFTER migration → if
            //       partial-init state has user_version=1 but
            //       no audit_entries table,ALTER throws
            //       no-such-table
            //   (c) two concurrent processes both at v1 →
            //       second ALTER fails with duplicate-column
            //       (SQLite WAL serializes,no busy-handler)
            //
            // Fix:
            //   1. Wrap migration in BEGIN IMMEDIATE / COMMIT
            //      so ALTER + PRAGMA are atomic — crash between
            //      them leaves user_version at 1 + column not
            //      added,safe to retry
            //   2. Idempotent column check via PRAGMA
            //      table_info — skip ALTER if column exists
            //   3. Skip ALTER if table doesn't exist
            //      (ensureSchema will create it with v2 DDL)
            //   4. busy_timeout for concurrent-process safety
            try Self.runExec(
                db: handle,
                sql: "PRAGMA busy_timeout = 5000;")
            try Self.runExec(
                db: handle,
                sql: "BEGIN IMMEDIATE;")
            do {
                let tableExists = try Self.tableExists(
                    db: handle, name: "audit_entries")
                let columnExists: Bool
                if tableExists {
                    columnExists = try Self.columnExists(
                        db: handle,
                        table: "audit_entries",
                        column: "entry_schema_version")
                } else {
                    columnExists = false
                }
                if tableExists && !columnExists {
                    try Self.runExec(
                        db: handle,
                        sql: """
                        ALTER TABLE audit_entries
                        ADD COLUMN entry_schema_version TEXT
                        NOT NULL DEFAULT '1.0.0';
                        """)
                }
                // Even if table didn't exist or column already
                // existed,bump the user_version so subsequent
                // opens skip the migration check entirely。
                try Self.runExec(
                    db: handle,
                    sql: "PRAGMA user_version=\(Self.schemaVersion);")
                try Self.runExec(
                    db: handle,
                    sql: "COMMIT;")
            } catch {
                // Roll back on any migration step error so
                // user_version stays at 1 + retry is safe。
                // chapter 九百九十六.7 META-REVIEW Round-16 MED-2
                // fix:pre-fix used bare `try?` which silently
                // swallowed ROLLBACK failures (violates user's
                // coding-style.md "Never silently swallow
                // errors")。 Now logs the rollback failure to
                // stderr before propagating the original error,
                // so the original cause is preserved but the
                // rollback-failure-additional-context isn't
                // lost。
                do {
                    try Self.runExec(
                        db: handle,
                        sql: "ROLLBACK;")
                } catch let rollbackError {
                    FileHandle.standardError.write(Data(
                        ("ch 996.7 MED-2: ROLLBACK after " +
                         "migration error itself failed:" +
                         " \(rollbackError) (original error: " +
                         "\(error)) — DB may be in " +
                         "indeterminate state\n").utf8))
                }
                throw error
            }
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)
        } catch {
            // chapter 九百九十六.7 META-REVIEW Round-16 MED-1:
            // close the SQLite handle before rethrowing so the
            // throwing init doesn't leak the open handle (Swift
            // does NOT call deinit on classes whose init throws)。
            sqlite3_close_v2(handle)
            throw error
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public protocol surface

    public func loadState() throws -> (
        entries: [BASSovereignAuditLedger.AppendedEntry],
        segments: [BASSovereignLedgerSegment]
    ) {
        // deep-audit P2-16 (2026-07-13): entries and segments must be read as ONE consistent
        // snapshot. Read separately (no enclosing transaction), a concurrent writer in another
        // process could land a new entry+segment BETWEEN the two queries, so rehydrate would see
        // entries.count and segments that disagree and wrongly quarantine. WAL mode (set at open)
        // makes a plain `BEGIN` a repeatable-read snapshot for the transaction's lifetime; wrap
        // both reads in it. On any failure the read txn is ended before rethrowing.
        guard let db else {
            let entries = try loadEntries()
            let segments = try loadSegments()
            return (entries, segments)
        }
        try Self.runExec(db: db, sql: "BEGIN;")
        do {
            let entries = try loadEntries()
            let segments = try loadSegments()
            try Self.runExec(db: db, sql: "COMMIT;")
            return (entries, segments)
        } catch {
            // End the read transaction; a failed ROLLBACK must not mask the original error.
            try? Self.runExec(db: db, sql: "ROLLBACK;")
            throw error
        }
    }

    public func persistAppended(
        _ appended: BASSovereignAuditLedger.AppendedEntry
    ) throws {
        guard let db else { return }
        // chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1:
        // bind entry_schema_version so per-entry schemaVersion
        // round-trips through SQLite persist + reload。 Without
        // this,ch 993's "1.1.0" warrant entries lose their
        // version on restart → canonical-bytes recomputation
        // picks wrong separator → signature mismatch。
        let sql = """
            INSERT INTO audit_entries (
                audit_id, session_id, turn_id, verdict_ref,
                rule_ids, signal_refs, action_refs,
                snapshot_ref, actor, signature, appended_at_ms,
                prior_hash, self_hash, entry_schema_version,
                insertion_order
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                (SELECT IFNULL(MAX(insertion_order), -1) + 1
                   FROM audit_entries))
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let e = appended.entry
        Self.bindText(stmt, 1, e.auditID)
        Self.bindText(stmt, 2, e.sessionID)
        Self.bindText(stmt, 3, e.turnID)
        Self.bindText(stmt, 4, e.verdictRef)
        Self.bindText(stmt, 5, Self.encodeRefList(e.ruleIDs))
        Self.bindText(stmt, 6, Self.encodeRefList(e.signalRefs))
        Self.bindText(stmt, 7, Self.encodeRefList(e.actionRefs))
        Self.bindText(stmt, 8, e.snapshotRef)
        Self.bindText(stmt, 9, e.actor.rawValue)
        Self.bindText(stmt, 10, e.signature)
        sqlite3_bind_int64(
            stmt, 11,
            Int64(e.appendedAt.timeIntervalSince1970 * 1000))
        Self.bindText(stmt, 12, appended.priorHash)
        Self.bindText(stmt, 13, appended.selfHash)
        // ch 994.5 CRITICAL-1 fix:bind entry.schemaVersion
        Self.bindText(stmt, 14, e.schemaVersion)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    /// audit F3 (2026-07-12): the ATOMIC entry+segment write. Both INSERTs run inside one
    /// `BEGIN IMMEDIATE … COMMIT`; any failure ROLLBACKs so disk never holds an orphan entry
    /// without its segment count. Reuses the exact BEGIN/COMMIT/ROLLBACK discipline the
    /// migration path already proved. persistAppended/persistSegment remain for rotation and
    /// other single-row writes.
    public func persistAppendedEntryAndSegment(
        _ appended: BASSovereignAuditLedger.AppendedEntry,
        _ segment: BASSovereignLedgerSegment
    ) throws {
        guard db != nil else { return }
        try Self.runExec(db: db!, sql: "BEGIN IMMEDIATE;")
        do {
            try persistAppended(appended)
            try persistSegment(segment)
            try Self.runExec(db: db!, sql: "COMMIT;")
        } catch {
            do {
                try Self.runExec(db: db!, sql: "ROLLBACK;")
            } catch let rollbackError {
                FileHandle.standardError.write(Data(
                    ("[BASSovereignLedgerSQLiteStorage] audit F3: ROLLBACK after atomic "
                     + "append failed itself: \(rollbackError) (original: \(error)); DB may "
                     + "be in an indeterminate state\n").utf8))
            }
            throw error
        }
    }

    public func persistSegment(
        _ segment: BASSovereignLedgerSegment
    ) throws {
        guard let db else { return }
        let sql = """
            INSERT INTO segments (
                segment_id, segment_index, session_id,
                start_anchor, tail_hash, entry_count,
                opened_at_ms, closed_at_ms, closed_by,
                closing_rotation_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(segment_id) DO UPDATE SET
                segment_index = excluded.segment_index,
                session_id = excluded.session_id,
                start_anchor = excluded.start_anchor,
                tail_hash = excluded.tail_hash,
                entry_count = excluded.entry_count,
                opened_at_ms = excluded.opened_at_ms,
                closed_at_ms = excluded.closed_at_ms,
                closed_by = excluded.closed_by,
                closing_rotation_id = excluded.closing_rotation_id
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        Self.bindText(stmt, 1, segment.segmentID)
        sqlite3_bind_int64(stmt, 2, Int64(segment.segmentIndex))
        Self.bindText(stmt, 3, segment.sessionID)
        Self.bindText(stmt, 4, segment.startAnchor)
        if let tail = segment.tailHash {
            Self.bindText(stmt, 5, tail)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int64(stmt, 6, Int64(segment.entryCount))
        sqlite3_bind_int64(
            stmt, 7,
            Int64(segment.openedAt.timeIntervalSince1970 * 1000))
        if let closedAt = segment.closedAt {
            sqlite3_bind_int64(
                stmt, 8,
                Int64(closedAt.timeIntervalSince1970 * 1000))
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        if let closedBy = segment.closedBy {
            Self.bindText(stmt, 9, closedBy.rawValue)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        if let rotID = segment.closingRotationID {
            Self.bindText(stmt, 10, rotID)
        } else {
            sqlite3_bind_null(stmt, 10)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Load helpers

    private func loadEntries() throws
        -> [BASSovereignAuditLedger.AppendedEntry]
    {
        guard let db else { return [] }
        // chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1:
        // read entry_schema_version + propagate into
        // BASSovereignAuditEntry init。 Pre-fix this SELECT
        // dropped the field on reload。
        let sql = """
            SELECT audit_id, session_id, turn_id, verdict_ref,
                   rule_ids, signal_refs, action_refs,
                   snapshot_ref, actor, signature, appended_at_ms,
                   prior_hash, self_hash, entry_schema_version
              FROM audit_entries
             ORDER BY insertion_order ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var entries: [BASSovereignAuditLedger.AppendedEntry] = []
        // audit F4 (2026-07-12): capture the step rc so a BUSY/IOERR/CORRUPT is NOT read as
        // end-of-data. A truncated/errored read that returns a short-or-empty entry list would
        // otherwise slip past the reload cross-check and fork the audit chain (fail-open) —
        // integrity > availability: throw, so loadState() throws and rehydrate() fails closed.
        var rc = sqlite3_step(stmt)
        while rc == SQLITE_ROW {
            let auditID = Self.readText(stmt, 0)
            let sessionID = Self.readText(stmt, 1)
            let turnID = Self.readText(stmt, 2)
            let verdictRef = Self.readText(stmt, 3)
            let ruleIDs = Self.decodeRefList(
                Self.readText(stmt, 4))
            let signalRefs = Self.decodeRefList(
                Self.readText(stmt, 5))
            let actionRefs = Self.decodeRefList(
                Self.readText(stmt, 6))
            let snapshotRef = Self.readText(stmt, 7)
            let actorRaw = Self.readText(stmt, 8)
            let signature = Self.readText(stmt, 9)
            let appendedAtMs = sqlite3_column_int64(stmt, 10)
            let priorHash = Self.readText(stmt, 11)
            let selfHash = Self.readText(stmt, 12)
            // ch 994.5 CRITICAL-1 fix:read entry_schema_version
            let entrySchemaVersion = Self.readText(stmt, 13)

            guard let actor = BASSovereignAuditActor(rawValue: actorRaw)
            else {
                throw StorageError.corruptedRow(
                    table: "audit_entries",
                    reason: "unknown actor rawValue '\(actorRaw)' for \(auditID)")
            }
            let entry = BASSovereignAuditEntry(
                schemaVersion: entrySchemaVersion,
                auditID: auditID,
                sessionID: sessionID,
                turnID: turnID,
                verdictRef: verdictRef,
                ruleIDs: ruleIDs,
                signalRefs: signalRefs,
                actionRefs: actionRefs,
                snapshotRef: snapshotRef,
                actor: actor,
                signature: signature,
                appendedAt: Date(timeIntervalSince1970:
                    Double(appendedAtMs) / 1000.0))
            entries.append(BASSovereignAuditLedger.AppendedEntry(
                entry: entry,
                priorHash: priorHash,
                selfHash: selfHash))
            rc = sqlite3_step(stmt)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return entries
    }

    private func loadSegments() throws
        -> [BASSovereignLedgerSegment]
    {
        guard let db else { return [] }
        let sql = """
            SELECT segment_id, segment_index, session_id,
                   start_anchor, tail_hash, entry_count,
                   opened_at_ms, closed_at_ms, closed_by,
                   closing_rotation_id
              FROM segments
             ORDER BY segment_index ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var segments: [BASSovereignLedgerSegment] = []
        // audit F4: fail-closed on read errors (see loadEntries).
        var rc = sqlite3_step(stmt)
        while rc == SQLITE_ROW {
            let segID = Self.readText(stmt, 0)
            let segIdx = Int(sqlite3_column_int64(stmt, 1))
            let sessionID = Self.readText(stmt, 2)
            let startAnchor = Self.readText(stmt, 3)
            let tailHash: String? =
                sqlite3_column_type(stmt, 4) == SQLITE_NULL
                    ? nil : Self.readText(stmt, 4)
            let entryCount = Int(sqlite3_column_int64(stmt, 5))
            let openedAtMs = sqlite3_column_int64(stmt, 6)
            let closedAt: Date?
            if sqlite3_column_type(stmt, 7) == SQLITE_NULL {
                closedAt = nil
            } else {
                closedAt = Date(timeIntervalSince1970:
                    Double(sqlite3_column_int64(stmt, 7)) / 1000.0)
            }
            let closedBy: BASSovereignLedgerRotationReason?
            if sqlite3_column_type(stmt, 8) == SQLITE_NULL {
                closedBy = nil
            } else {
                let raw = Self.readText(stmt, 8)
                closedBy = BASSovereignLedgerRotationReason(
                    rawValue: raw)
            }
            let closingRotationID: String? =
                sqlite3_column_type(stmt, 9) == SQLITE_NULL
                    ? nil : Self.readText(stmt, 9)

            segments.append(BASSovereignLedgerSegment(
                segmentID: segID,
                segmentIndex: segIdx,
                sessionID: sessionID,
                startAnchor: startAnchor,
                tailHash: tailHash,
                entryCount: entryCount,
                openedAt: Date(timeIntervalSince1970:
                    Double(openedAtMs) / 1000.0),
                closedAt: closedAt,
                closedBy: closedBy,
                closingRotationID: closingRotationID))
            rc = sqlite3_step(stmt)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return segments
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
        // chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1:
        // entry_schema_version column added。 Fresh DBs get it
        // directly from CREATE TABLE;upgraded DBs get it via the
        // ALTER TABLE migration path in init。
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS audit_entries (
                audit_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                turn_id TEXT NOT NULL,
                verdict_ref TEXT NOT NULL,
                rule_ids TEXT NOT NULL,
                signal_refs TEXT NOT NULL,
                action_refs TEXT NOT NULL,
                snapshot_ref TEXT NOT NULL,
                actor TEXT NOT NULL,
                signature TEXT NOT NULL,
                appended_at_ms INTEGER NOT NULL,
                prior_hash TEXT NOT NULL,
                self_hash TEXT NOT NULL,
                insertion_order INTEGER NOT NULL UNIQUE,
                entry_schema_version TEXT NOT NULL DEFAULT '1.0.0'
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS audit_entries_session_idx
              ON audit_entries (session_id, insertion_order);
            """)
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS segments (
                segment_id TEXT PRIMARY KEY,
                segment_index INTEGER NOT NULL,
                session_id TEXT NOT NULL,
                start_anchor TEXT NOT NULL,
                tail_hash TEXT,
                entry_count INTEGER NOT NULL,
                opened_at_ms INTEGER NOT NULL,
                closed_at_ms INTEGER,
                closed_by TEXT,
                closing_rotation_id TEXT
            );
            """)
    }

    private static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        // M886 (M882 audit fix):version is now correctly written
        // by the read-then-branch path in init,so verify simply
        // re-reads + asserts equality。Pre-M886 the comment here
        // claimed verify was authoritative,but the unconditional
        // pragma overwrite made it tautological for upgraded DBs。
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
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
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
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

    // MARK: - Utility

    // chapter 九百九十四.7 META-REVIEW Round-11 HIGH-2 helpers:
    // idempotent migration support。 PRAGMA table_info-based
    // checks let us skip ALTER TABLE when the column already
    // exists (e.g. after a crash-then-retry mid-migration)。

    fileprivate static func tableExists(
        db: OpaquePointer, name: String
    ) throws -> Bool {
        let sql = """
            SELECT 1 FROM sqlite_master
             WHERE type='table' AND name=?
             LIMIT 1
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, name)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    fileprivate static func columnExists(
        db: OpaquePointer, table: String, column: String
    ) throws -> Bool {
        // PRAGMA table_info doesn't accept parameter binding,
        // so the table name is interpolated。 Safe because
        // callers pass literal table names ("audit_entries" /
        // "segments"),never user-controlled input。
        let sql = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            // table_info columns: cid, name, type, notnull,
            // dflt_value, pk。 We want column 1 (name)。
            let colName = readText(stmt, 1)
            if colName == column { return true }
        }
        return false
    }

    private static func runExec(
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

    // SQLite requires the transient destructor to copy text; without
    // it the binding can dangle when the Swift string is deallocated.
    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    private static func bindText(
        _ stmt: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private static func readText(
        _ stmt: OpaquePointer,
        _ index: Int32
    ) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else {
            return ""
        }
        return String(cString: raw)
    }

    // deep-audit HIGH (CH_1044_DEEP A4 / rs-integrity-canonical): ruleIDs/signalRefs/actionRefs are part
    // of the SIGNED 1.2.0 injective canonical (basSovereignAuditCanonicalBytes keeps [] vs [""] and
    // ["a,b"] vs ["a","b"] distinct). The old serialization `joined(separator: ",")` + `split(separator:
    // ",")` (which drops empty subsequences AND treats an in-band comma as a delimiter) was LOSSY: a
    // legal comma-bearing or empty-string ref round-tripped to a DIFFERENT array, so on cold-start
    // reload auditChainFull recomputed the canonical over the mis-split arrays → selfHash/signature
    // mismatch → the whole benign chain is permanently integrity-quarantined (every later append throws).
    // MCP audit entries legitimately carry commas (BASMCPInvocationAuditBridge U+001F-joined IDs).
    // Fix: store INJECTIVELY as a sentinel + per-element "<utf8ByteCount>:<element>" (netstring), so the
    // reloaded arrays byte-equal the signed originals for any content.
    private static let refListSentinel = "\u{01}nl1\u{1F}"

    /// Injective serialization of a ref array (netstring: sentinel + "<utf8ByteCount>:<bytes>" per element).
    static func encodeRefList(_ xs: [String]) -> String {
        var out = refListSentinel
        for x in xs { out += "\(x.utf8.count):\(x)" }
        return out
    }

    /// Inverse of `encodeRefList`. A stored value WITHOUT the sentinel is a legacy comma-joined row: it is
    /// re-split KEEPING empty subsequences (which exactly recovers pre-existing empty-element rows; comma-
    /// free rows are unaffected; comma-bearing legacy rows remain irrecoverable — they already quarantined
    /// on reload before this fix, so this is strictly better).
    static func decodeRefList(_ s: String) -> [String] {
        guard s.hasPrefix(refListSentinel) else {
            return s.isEmpty ? []
                : s.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }
        let bytes = Array(s.utf8)
        var i = refListSentinel.utf8.count
        var result: [String] = []
        while i < bytes.count {
            var j = i
            while j < bytes.count, bytes[j] != UInt8(ascii: ":") { j += 1 }
            guard j < bytes.count,
                  let n = Int(String(decoding: bytes[i..<j], as: UTF8.self)), n >= 0
            else { break }
            let start = j + 1, end = start + n
            guard end <= bytes.count else { break }
            result.append(String(decoding: bytes[start..<end], as: UTF8.self))
            i = end
        }
        return result
    }
}
