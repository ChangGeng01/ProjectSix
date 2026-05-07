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
    public enum StorageError: Error, Equatable {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case corruptedRow(table: String, reason: String)
    }

    public static let schemaVersion: Int = 1

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

        try Self.runExec(
            db: handle,
            sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle,
            sql: "PRAGMA foreign_keys=ON;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch 0 → write current,equal → accept,mismatch → throw。
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
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
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public protocol surface

    public func loadState() throws -> (
        entries: [BASSovereignAuditLedger.AppendedEntry],
        segments: [BASSovereignLedgerSegment]
    ) {
        let entries = try loadEntries()
        let segments = try loadSegments()
        return (entries, segments)
    }

    public func persistAppended(
        _ appended: BASSovereignAuditLedger.AppendedEntry
    ) throws {
        guard let db else { return }
        let sql = """
            INSERT INTO audit_entries (
                audit_id, session_id, turn_id, verdict_ref,
                rule_ids, signal_refs, action_refs,
                snapshot_ref, actor, signature, appended_at_ms,
                prior_hash, self_hash, insertion_order
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
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
        Self.bindText(stmt, 5, e.ruleIDs.joined(separator: ","))
        Self.bindText(stmt, 6, e.signalRefs.joined(separator: ","))
        Self.bindText(stmt, 7, e.actionRefs.joined(separator: ","))
        Self.bindText(stmt, 8, e.snapshotRef)
        Self.bindText(stmt, 9, e.actor.rawValue)
        Self.bindText(stmt, 10, e.signature)
        sqlite3_bind_int64(
            stmt, 11,
            Int64(e.appendedAt.timeIntervalSince1970 * 1000))
        Self.bindText(stmt, 12, appended.priorHash)
        Self.bindText(stmt, 13, appended.selfHash)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
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
        let sql = """
            SELECT audit_id, session_id, turn_id, verdict_ref,
                   rule_ids, signal_refs, action_refs,
                   snapshot_ref, actor, signature, appended_at_ms,
                   prior_hash, self_hash
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
        while sqlite3_step(stmt) == SQLITE_ROW {
            let auditID = Self.readText(stmt, 0)
            let sessionID = Self.readText(stmt, 1)
            let turnID = Self.readText(stmt, 2)
            let verdictRef = Self.readText(stmt, 3)
            let ruleIDs = Self.splitCommaJoined(
                Self.readText(stmt, 4))
            let signalRefs = Self.splitCommaJoined(
                Self.readText(stmt, 5))
            let actionRefs = Self.splitCommaJoined(
                Self.readText(stmt, 6))
            let snapshotRef = Self.readText(stmt, 7)
            let actorRaw = Self.readText(stmt, 8)
            let signature = Self.readText(stmt, 9)
            let appendedAtMs = sqlite3_column_int64(stmt, 10)
            let priorHash = Self.readText(stmt, 11)
            let selfHash = Self.readText(stmt, 12)

            guard let actor = BASSovereignAuditActor(rawValue: actorRaw)
            else {
                throw StorageError.corruptedRow(
                    table: "audit_entries",
                    reason: "unknown actor rawValue '\(actorRaw)' for \(auditID)")
            }
            let entry = BASSovereignAuditEntry(
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
        while sqlite3_step(stmt) == SQLITE_ROW {
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
        }
        return segments
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
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
                insertion_order INTEGER NOT NULL UNIQUE
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

    private static func splitCommaJoined(_ s: String) -> [String] {
        s.isEmpty ? [] : s.split(separator: ",").map(String.init)
    }
}
