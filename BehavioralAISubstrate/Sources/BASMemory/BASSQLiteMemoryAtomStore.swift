// MARK: - BASSQLiteMemoryAtomStore — chapter 二百四十八 / M735
//
// Cross-session SQLite-backed L8 memory atom persistence.
//
// ## Why this exists
//
// chapter 二百四十七 closing audit (附录 V Stage 0 §V.3) confirmed
// `BASInMemoryMemoryAtomStore` is the **only** production conformer
// of `BASMemoryAtomStore`. Every session boots with `[String:
// BASGovernedMemory] = [:]` — the L8 hippocampal layer schema is
// complete but cross-session continuity is empty. M91 ledger pattern
// (chapter 一百九十一) and M270 ticket pattern (chapter 二百六十八)
// both showed the right shape for SQLite-backed actor storage that
// preserves invariant #3 (host data stays out of base weights — disk
// is just durable replay of the atoms an in-memory actor would also
// hold).
//
// chapter 二百四十八 introduces a SQLite-backed conformer keeping
// byte-equal semantics with the in-memory implementation:
//   - `actor BASSQLiteMemoryAtomStore: BASMemoryAtomStore`
//   - same `init(initial: [BASGovernedMemory] = [])` ctor surface
//   - same 4 protocol methods (atom / updateTier /
//     updateGovernanceStatus / remove) routed through SQLite CRUD
//   - per-atom JSON Codable payload in `payload_json` (mirror of
//     M270 `entry_json`); structural columns mirror BASGovernedMemory
//     fields so future SQL queries can filter without parsing JSON
//   - additional `admit(_:)` and observation surfaces (`count`,
//     `allIDs`) for parity with the in-memory store
//
// ## Doctrine pins
//
//   - 不变量 #1 先醒再答: storage doesn't change runtime ordering.
//   - 不变量 #2 神经不掌权: persistence is plumbing, never a permit
//     gate; the L11 single commit mouth is unchanged.
//   - 不变量 #3 私有经验不进权重: the SQLite payload is the same
//     `BASGovernedMemory` data the in-memory actor would carry —
//     persisting it does not feed L2 base weights.
//   - chapter 一百二 五级删除 doctrine: `remove(forID:)` issues a
//     real `DELETE` (not a tombstone). Higher-level protections
//     (host vault revocation cascade, sovereign warrant) remain in
//     their respective layers.
//   - chapter 一百九十一 M91 / chapter 二百六十八 M270 storage idiom:
//     `import SQLite3` system framework (no new package deps),
//     `OpaquePointer` db handle owned by the actor, transient bind
//     destructor for Swift `String` lifetime, WAL journal mode for
//     concurrent readers (cross-process distillation pipeline).
//   - chapter 二百十一 single-source-of-truth: protocol contract
//     stays in `BASMemoryAtomStore.swift`; this file is the second
//     conformer (no contract duplication).
//
// ## Schema (version 1)
//
//   CREATE TABLE memory_atoms (
//     atom_id TEXT PRIMARY KEY NOT NULL,    -- UUID.uuidString
//     kind TEXT NOT NULL,                   -- BASMemoryKind raw
//     scope TEXT NOT NULL,                  -- BASMemoryScope raw
//     sensitivity TEXT NOT NULL,            -- BASMemorySensitivity
//     tier TEXT NOT NULL,                   -- BASMemoryTier raw
//     governance_status TEXT NOT NULL,      -- BASMemoryGovernance
//     created_at_ms INTEGER NOT NULL,       -- admit timestamp
//     last_updated_at_ms INTEGER NOT NULL,  -- last mutation time
//     payload_json TEXT NOT NULL            -- BASGovernedMemory JSON
//   );
//   CREATE INDEX memory_atoms_tier_idx ON memory_atoms(tier);
//   CREATE INDEX memory_atoms_governance_idx
//     ON memory_atoms(governance_status);
//
// `payload_json` is the source of truth on read. Indexed columns
// give SQL filtering without JSON parsing — useful for future
// migrations (e.g. tier-rebalance batch jobs) but functionally
// secondary today.

import Foundation
import SQLite3
import BASRuntimeCore

/// SQLite-backed `BASMemoryAtomStore`. Atoms persist across process
/// restarts in the configured database file. The actor's isolation
/// boundary serializes every protocol call, so the underlying
/// `OpaquePointer` does not need a separate lock.
///
/// **First-run cost**: the database file + table + indices are
/// created at `init` if absent. Existing databases are opened
/// read/write. The schema-version pragma is set to
/// `Self.schemaVersion` and verified on every open.
///
/// **Failure mode**: any SQLite error throws a typed
/// `StorageError`. Per chapter 一百九十一 M91 doctrine, integrity
/// outranks availability — a corrupt store is surfaced rather than
/// silently truncated.
public actor BASSQLiteMemoryAtomStore: BASMemoryAtomStore {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(atomID: String, message: String)
        case decodeFailed(atomID: String, message: String)
        case corruptedRow(atomID: String, reason: String)
    }

    public static let schemaVersion: Int = 1

    /// 先稳 P2 — OPT-IN (default off): run `PRAGMA integrity_check` at open and THROW if the DB is corrupt,
    /// surfacing subtle page corruption a lazy header check misses. Off by default (it is a full-DB scan ⇒
    /// boot latency); a host enables it for high-assurance startup. Static so it can be set before init.
    public nonisolated(unsafe) static var runIntegrityCheckOnOpen: Bool = false

    // MARK: - Stored state

    /// Database file URL. Surfaced for tests / observability —
    /// hosts that want to back up / move the file read this.
    public let databaseURL: URL

    /// Owned SQLite handle. Lives for the actor's lifetime; closed
    /// in `deinit`. Actor isolation provides serialization — no
    /// additional locking required.
    ///
    /// Marked `nonisolated(unsafe)` so the actor's nonisolated
    /// `deinit` can call `sqlite3_close_v2` on it. The
    /// invariant making this safe: deinit runs exactly once, no
    /// other actor work can race with it (the actor is being
    /// deallocated), and SQLite's `close_v2` is thread-safe with
    /// itself. All non-deinit access goes through actor-isolated
    /// methods, where the field appears as a normal isolated
    /// stored property.
    private nonisolated(unsafe) var db: OpaquePointer?

    /// 先稳 P0 — OPT-IN diagnostic hook (default nil). The non-throwing protocol methods + convenience
    /// accessors route a swallowed SQLite error here BEFORE returning their default, so a host can tell
    /// "not found" from "DB broken" (integrity > availability, M91). Fires ONLY on the error path (which
    /// already produced the default) ⇒ byte-equal on the success path. Default nil ⇒ today's exact behavior.
    public var onSilentFailure: (@Sendable (Error) -> Void)?

    /// Wire the diagnostic hook (actor-isolated; hosts set it once at setup). Zero init-signature change.
    public func setOnSilentFailure(_ handler: (@Sendable (Error) -> Void)?) {
        self.onSilentFailure = handler
    }

    /// audit x-sov #5/#6 — the error (if any) from applying file Data
    /// Protection to the DB + `-wal`/`-shm` at open. `onSilentFailure` isn't
    /// wired until AFTER construction, so the init-time protection outcome is
    /// SURFACED here (never swallowed) for a host to inspect. nil ⇒ protection
    /// applied cleanly (or the kill-switch is off).
    public private(set) var fileProtectionError: Error?

    // MARK: - Lifecycle

    /// Open or create the SQLite-backed store at `databaseURL`.
    /// If `initial` is non-empty and the database is empty, the
    /// atoms are inserted; if the database already contains atoms
    /// the `initial` set is **NOT** re-applied (preservation
    /// doctrine — existing data is canonical, ctor presets are a
    /// boot fallback).
    ///
    /// - Parameter databaseURL: Filesystem URL for the SQLite file.
    ///   Parent directory must exist.
    /// - Parameter initial: Optional seed atoms inserted only when
    ///   the table is empty (idempotent boot).
    public init(
        databaseURL: URL,
        initial: [BASGovernedMemory] = []
    ) throws {
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

        // chapter 二百六十八 M270 — WAL mode for concurrent readers
        // (the offline distillation pipeline reads while the
        // runtime writes).
        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete zeroes freed pages
        // at delete time — default-on, BAS_SECURE_DELETE=0 kill-switch.
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: sdSQL)
        }
        // memory-a F4 residual: one-time legacy freelist purge (secure_delete only
        // zeroes NEW deletions; VACUUM once rewrites the file, dropping pre-fix
        // plaintext). Marker-gated ⇒ steady-state cost is one SELECT. Outside any txn.
        BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(db: handle, sql: "PRAGMA foreign_keys=ON;")
        // 先稳 P2 — bound WAL growth over long sessions (mirrors the event log's M891 setting) so an
        // unexpected termination leaves a SMALL -wal to replay and a clean reopen stays fast.
        try Self.runExec(db: handle, sql: "PRAGMA wal_autocheckpoint=200;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch on 0/equal/mismatch。Pre-M886 unconditional pragma
        // overwrite made verify a no-op for upgraded DBs。
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
        if Self.runIntegrityCheckOnOpen {
            try Self.assertIntegrity(db: handle)   // 先稳 P2 — opt-in proactive corruption scan
        }

        // Idempotent boot: only seed `initial` when the table is
        // empty. Existing data wins.
        if !initial.isEmpty {
            let count = try Self.countAtoms(db: handle)
            if count == 0 {
                for atom in initial {
                    try Self.insertAtom(db: handle, atom: atom)
                }
            }
        }

        // audit x-sov #5 — pin file Data Protection on the memory-atom DB (the
        // highest-sensitivity on-disk point) + its -wal/-shm sidecars, matching
        // the session-KV snapshot's protection (缝2) and killing the same-repo
        // double standard. Applied AFTER the WAL pragma + seed write so the
        // sidecars exist. The outcome is surfaced (x-sov #6: not swallowed).
        self.fileProtectionError =
            BASSQLiteFileProtection.apply(toDatabaseAt: databaseURL.path)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    /// audit x-test-integrity F7 — the per-connection pragmas
    /// (synchronous / foreign_keys / wal_autocheckpoint) are NOT cross-connection
    /// observable, so a durability gate must read them from THIS store's OWN
    /// connection rather than re-issue them on a fresh handle (which verifies its
    /// own copy — a tautology that stays green even if init drops the pragma).
    /// Test seam.
    public func _connectionPragmasForTesting()
        -> (synchronous: Int, foreignKeys: Int, walAutocheckpoint: Int) {
        guard let db else { return (-1, -1, -1) }
        return (Self._pragmaIntForTesting(db, "synchronous"),
                Self._pragmaIntForTesting(db, "foreign_keys"),
                Self._pragmaIntForTesting(db, "wal_autocheckpoint"))
    }
    private static func _pragmaIntForTesting(_ db: OpaquePointer, _ name: String) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA \(name);", -1, &stmt, nil) == SQLITE_OK,
              let s = stmt else { return -1 }
        defer { sqlite3_finalize(s) }
        return sqlite3_step(s) == SQLITE_ROW ? Int(sqlite3_column_int64(s, 0)) : -1
    }

    /// 先稳 P2 — run `PRAGMA integrity_check` and throw if the result is not "ok" (proactive corruption
    /// detection). Called at init only when `runIntegrityCheckOnOpen` is set.
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

    // MARK: - Protocol — BASMemoryAtomStore

    public func atom(forID id: String) async -> BASGovernedMemory? {
        guard let db else { return nil }
        do { return try Self.fetchAtom(db: db, atomID: id) }
        catch { onSilentFailure?(error); return nil }
    }

    @discardableResult
    public func updateTier(
        forID id: String,
        to newTier: BASMemoryTier
    ) async -> Bool {
        guard let db else { return false }
        let fetched: BASGovernedMemory?
        do { fetched = try Self.fetchAtom(db: db, atomID: id) }
        catch { onSilentFailure?(error); return false }
        guard var atom = fetched else { return false }
        atom.tier = newTier
        do {
            try Self.upsertAtom(db: db, atom: atom)
            return true
        } catch {
            onSilentFailure?(error)
            return false
        }
    }

    @discardableResult
    public func updateGovernanceStatus(
        forID id: String,
        to newStatus: BASMemoryGovernanceStatus
    ) async -> Bool {
        guard let db else { return false }
        let fetched: BASGovernedMemory?
        do { fetched = try Self.fetchAtom(db: db, atomID: id) }
        catch { onSilentFailure?(error); return false }
        guard var atom = fetched else { return false }
        atom.governanceStatus = newStatus
        do {
            try Self.upsertAtom(db: db, atom: atom)
            return true
        } catch {
            onSilentFailure?(error)
            return false
        }
    }

    @discardableResult
    public func remove(
        forID id: String
    ) async -> BASGovernedMemory? {
        guard let db else { return nil }
        let existing: BASGovernedMemory?
        do { existing = try Self.fetchAtom(db: db, atomID: id) }
        catch { onSilentFailure?(error); return nil }
        guard let existing else { return nil }
        do {
            try Self.deleteAtom(db: db, atomID: id)
            // audit F6 (2026-07-12): secure_delete=ON zeroes the freed MAIN-DB page, but the
            // atom's payload plaintext also lives as the original INSERT frame in the -wal
            // file. remove() is the explicit forget/purge path (NOT the hot tiering-evict
            // loop), so truncate the WAL now — a blocked checkpoint that leaves frames THROWS
            // rather than reporting a clean forget while plaintext lingers.
            try BASSQLiteSecureDelete.checkpointTruncateAfterSecureDelete(db: db)
            return existing
        } catch {
            onSilentFailure?(error)
            return nil
        }
    }

    // MARK: - Convenience surface (parity with in-memory store)

    /// Best-effort total number of atoms in the database. Mirrors
    /// `BASInMemoryMemoryAtomStore.count`.
    /// The default `0` is not proof that an authoritative recovery read completed;
    /// use `countOrThrow()` when completeness matters.
    public var count: Int {
        get async {
            guard let db else { return 0 }
            do { return try Self.countAtoms(db: db) }
            catch { onSilentFailure?(error); return 0 }
        }
    }

    /// 先稳 P0 — throwing sibling of `count`: surfaces a SQLite error instead of returning 0, so a caller
    /// can distinguish "empty" from "DB broken". The non-throwing `count` stays the byte-equal path.
    public func countOrThrow() async throws -> Int {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.countAtoms(db: db)
    }

    /// Best-effort set of atom IDs currently stored. Mirrors
    /// `BASInMemoryMemoryAtomStore.allIDs`.
    /// The default empty set is not proof that an authoritative recovery read completed;
    /// use `allIDsOrThrow()` when completeness matters.
    public var allIDs: Set<String> {
        get async {
            guard let db else { return [] }
            do { return try Self.fetchAllIDs(db: db) }
            catch { onSilentFailure?(error); return [] }
        }
    }

    /// 先稳 P0 — throwing sibling of `allIDs` (surfaces SQLite errors instead of returning []).
    public func allIDsOrThrow() async throws -> Set<String> {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.fetchAllIDs(db: db)
    }

    /// Insert or replace an atom. Used by hosts that admit atoms
    /// after init (the canonical post-boot admission path).
    /// Returns `true` if the row was new, `false` if it replaced
    /// an existing row.
    @discardableResult
    public func admit(_ atom: BASGovernedMemory) async throws -> Bool {
        guard let db else { return false }
        // audit memory-a F7: `try?` swallowed fetch errors, so a decode-corrupt existing row read
        // as "did not exist" → this admit reported wasNew=true for a row it actually overwrote (and
        // masked the corruption). admit already throws, so surface the StorageError, mirroring the
        // *OrThrow siblings in this file.
        let existed = try Self.fetchAtom(
            db: db, atomID: atom.id.uuidString) != nil
        try Self.upsertAtom(db: db, atom: atom)
        return !existed
    }

    /// Fetch all atoms (no filter, unbounded). Caller-supplied
    /// scoping is host responsibility — this is the storage
    /// surface, not a query layer.
    public func allAtoms() async throws -> [BASGovernedMemory] {
        guard let db else { return [] }
        return try Self.fetchAllAtoms(db: db)
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_atoms (
                atom_id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                scope TEXT NOT NULL,
                sensitivity TEXT NOT NULL,
                tier TEXT NOT NULL,
                governance_status TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                last_updated_at_ms INTEGER NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_atoms_tier_idx
              ON memory_atoms(tier);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_atoms_governance_idx
              ON memory_atoms(governance_status);
            """)
    }

    private static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: version, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting it。Returns 0 for fresh DBs。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
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

    fileprivate static func insertAtom(
        db: OpaquePointer,
        atom: BASGovernedMemory
    ) throws {
        try upsertAtom(db: db, atom: atom)
    }

    fileprivate static func upsertAtom(
        db: OpaquePointer,
        atom: BASGovernedMemory
    ) throws {
        let atomID = atom.id.uuidString
        let json: String
        do {
            let data = try JSONEncoder().encode(atom)
            guard let s = String(data: data, encoding: .utf8) else {
                throw StorageError.encodeFailed(
                    atomID: atomID,
                    message: "encoded JSON not UTF-8")
            }
            json = s
        } catch let storageError as StorageError {
            throw storageError
        } catch {
            throw StorageError.encodeFailed(
                atomID: atomID, message: "\(error)")
        }

        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        let sql = """
            INSERT INTO memory_atoms (
                atom_id, kind, scope, sensitivity, tier,
                governance_status, created_at_ms,
                last_updated_at_ms, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(atom_id) DO UPDATE SET
                kind = excluded.kind,
                scope = excluded.scope,
                sensitivity = excluded.sensitivity,
                tier = excluded.tier,
                governance_status = excluded.governance_status,
                last_updated_at_ms = excluded.last_updated_at_ms,
                payload_json = excluded.payload_json
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

        bindText(stmt, 1, atomID)
        bindText(stmt, 2, atom.kind.rawValue)
        bindText(stmt, 3, atom.scope.rawValue)
        bindText(stmt, 4, atom.sensitivity.rawValue)
        bindText(stmt, 5, atom.tier.rawValue)
        bindText(stmt, 6, atom.governanceStatus.rawValue)
        sqlite3_bind_int64(stmt, 7, nowMs)
        sqlite3_bind_int64(stmt, 8, nowMs)
        bindText(stmt, 9, json)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAtom(
        db: OpaquePointer,
        atomID: String
    ) throws -> BASGovernedMemory? {
        let sql = """
            SELECT payload_json FROM memory_atoms
             WHERE atom_id = ?
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

        bindText(stmt, 1, atomID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }

        let json = readText(stmt, 0)
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                atomID: atomID,
                reason: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder()
                .decode(BASGovernedMemory.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                atomID: atomID, message: "\(error)")
        }
    }

    fileprivate static func deleteAtom(
        db: OpaquePointer,
        atomID: String
    ) throws {
        let sql = "DELETE FROM memory_atoms WHERE atom_id = ?"
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
        bindText(stmt, 1, atomID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func countAtoms(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM memory_atoms"
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

    fileprivate static func fetchAllIDs(
        db: OpaquePointer
    ) throws -> Set<String> {
        let sql = "SELECT atom_id FROM memory_atoms"
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
        var ids: Set<String> = []
        var stepRC = sqlite3_step(stmt)
        while stepRC == SQLITE_ROW {
            ids.insert(readText(stmt, 0))
            stepRC = sqlite3_step(stmt)
        }
        guard stepRC == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return ids
    }

    fileprivate static func fetchAllAtoms(
        db: OpaquePointer
    ) throws -> [BASGovernedMemory] {
        let sql = """
            SELECT atom_id, payload_json FROM memory_atoms
             ORDER BY created_at_ms ASC, atom_id ASC
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
        var atoms: [BASGovernedMemory] = []
        var stepRC = sqlite3_step(stmt)
        while stepRC == SQLITE_ROW {
            let atomID = readText(stmt, 0)
            let json = readText(stmt, 1)
            guard let data = json.data(using: .utf8) else {
                throw StorageError.corruptedRow(
                    atomID: atomID,
                    reason: "payload_json not UTF-8")
            }
            do {
                let atom = try JSONDecoder()
                    .decode(BASGovernedMemory.self, from: data)
                atoms.append(atom)
            } catch {
                throw StorageError.decodeFailed(
                    atomID: atomID, message: "\(error)")
            }
            stepRC = sqlite3_step(stmt)
        }
        guard stepRC == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return atoms
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
            throw StorageError.prepareFailed(
                sql: sql, message: message)
        }
    }

    /// SQLite's transient-destructor sentinel — copy bound text
    /// into SQLite-owned memory so the Swift `String` can be
    /// deallocated immediately after `sqlite3_bind_text` returns.
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
