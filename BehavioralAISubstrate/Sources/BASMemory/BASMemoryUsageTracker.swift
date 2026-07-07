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
        Error, Equatable, Hashable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case unknownRecord(id: String)

        /// Stable telemetry-friendly identifier for the
        /// error case discriminator,independent of
        /// associated value data。 See chapter 七百二十 /
        /// M2219 for the cross-pilot caseIdentifier
        /// contract。
        public var caseIdentifier: String {
            switch self {
            case .openFailed:
                return "openFailed"
            case .prepareFailed:
                return "prepareFailed"
            case .stepFailed:
                return "stepFailed"
            case .schemaVersionMismatch:
                return "schemaVersionMismatch"
            case .unknownRecord:
                return "unknownRecord"
            }
        }
    }

    public static let schemaVersion: Int = 1

    /// SQLite file URL when persistent; nil when in-memory.
    public let databaseURL: URL?

    /// SQLite handle (nil in in-memory mode). See chapter
    /// 二百四十八 / M735 commentary on why `nonisolated(unsafe)`
    /// is the right opt-out for deinit cleanup of an
    /// actor-isolated `OpaquePointer`.
    ///
    /// `internal` (not `private`) ONLY so the split-out `+SQLCore` /
    /// `+ReplayAuditFTS` / `+SQLPrimitives` extension files (god-object
    /// decomposition, ch1040) can reach it. It is STILL actor-isolated:
    /// every read is from an `async` actor-isolated method, and the
    /// `nonisolated(unsafe)` opt-out is consumed ONLY by `deinit`. The
    /// `internal` visibility is NOT license to touch this pointer from a
    /// `nonisolated` / `static` context — that would break isolation. The
    /// same applies to the in-memory state below (widened for the same reason).
    nonisolated(unsafe) var db: OpaquePointer?

    /// In-memory record store keyed by recordID. Used in
    /// in-memory mode AND as a write-through cache in SQLite
    /// mode (so `recordCount` / `recentRecords` don't need a
    /// SQL round-trip). Reloaded from disk on init.
    var inMemory: [String: BASMemoryUsageRecord] = [:]

    /// 主线 SQL Tombstone 抽取 — set of recordIDs marked
    /// as tombstoned。 Mirrors the SQL
    /// `memory_usage_tombstones` table when SQLite-backed;
    /// holds the only state in in-memory mode。
    var inMemoryTombstones: Set<String> = []

    /// 主线 SQL Bundle 抽取 — in-memory mirror of the
    /// `memory_usage_bundles` table。 Keyed by bundleID,
    /// value carries the ordered recordIDs + createdAt。
    var inMemoryBundles:
        [String: (recordIDs: [String],
                  createdAtMs: Int64)] = [:]

    /// 主线 SQL ReplayLog 抽取 — append-only event log。
    var inMemoryReplayLog: [BASReplayLogEntry] = []

    /// 主线 SQL AuditLog 抽取 — append-only audit trail。
    var inMemoryAuditLog: [BASAuditLogEntry] = []

    /// 主线 SQL FTS 抽取 — per-record notes for FTS5
    /// search。 Keyed by recordID。
    var inMemoryNotes: [String: String] = [:]

    // MARK: - Lifecycle

    /// Construct an in-memory tracker. No disk I/O.
    public init() {
        self.databaseURL = nil
        self.db = nil
    }

    /// Construct a SQLite-backed tracker. Loads any prior records
    /// from disk into the in-memory cache so subsequent reads
    /// don't need a round-trip.
    ///
    /// - Parameter useGeneratedSchema:M2173 chapter 七百二 第三刀
    ///   — when `true`,the schema is provisioned via the
    ///   `MemoryUsageRecordsSchema.allStatementsSQL` constant
    ///   generated by the BASSQLSchemaGen build plugin from
    ///   `Sources/BASMemory/SQL/001_memory_usage_records.sql`。
    ///   Default `false` preserves the V1 byte-equality path
    ///   (three separate inline `runExec` calls)。
    ///
    ///   ADR-014 OPT-IN preserved:callers that want the
    ///   generated path opt-in explicitly。 The async factory
    ///   `make(databaseURL:flags:)` does that opt-in based on
    ///   `BASLanguageAugmentationFeatureFlags.sqlMigratorEnabled`
    ///   (default-off feature flag → V1 path)。
    ///
    ///   Both code paths produce IDENTICAL on-disk schema (proved
    ///   by `BASMemoryUsageTrackerSqlPilotByteEqualityTests` at
    ///   M2173 第三刀)。
    public init(
        databaseURL: URL,
        useGeneratedSchema: Bool = false
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
        try Self.ensureSchema(
            db: handle, useGenerated: useGeneratedSchema)
        try Self.verifySchemaVersion(db: handle)

        // Load prior records into the in-memory cache.
        let prior = try Self.fetchAllRecords(db: handle)
        for record in prior {
            inMemory[record.recordID] = record
        }
        // H11 (mega-audit 2026-07-07): reload tombstones too. Without this a
        // SQLite-backed tracker resurrects "forgotten" records on restart —
        // isTombstoned==false, allRecords() yields them, activeRecordCount counts
        // them, and purgeTombstoned() returns 0 while the in-memory cache still
        // serves already-physically-deleted rows.
        try Self.ensureTombstoneSchema(db: handle)
        for id in try Self.fetchAllTombstoneIDs(db: handle) {
            inMemoryTombstones.insert(id)
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public surface

    /// 全面 开发 — typed payload struct for batch insert。
    /// Each entry is a record-shaped struct without the
    /// recordID (the tracker mints a UUID per insert)。
    public struct BatchEntry: Sendable, Equatable, Hashable {
        public let atomID: String
        public let sessionRef: String
        public let turnRef: String
        public let permitMode: String
        public let retrievedAt: Date

        public init(
            atomID: String,
            sessionRef: String,
            turnRef: String,
            permitMode: String,
            retrievedAt: Date = Date()
        ) {
            self.atomID = atomID
            self.sessionRef = sessionRef
            self.turnRef = turnRef
            self.permitMode = permitMode
            self.retrievedAt = retrievedAt
        }
    }

}
