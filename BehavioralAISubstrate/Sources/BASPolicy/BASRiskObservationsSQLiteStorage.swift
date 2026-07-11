// MARK: - BASRiskObservationsSQLiteStorage
// chapter 七百五十一 第三刀 / M2428
//
// MATURATION ARC SQL persistence go-live — user directive
// 2026-05-20「SQL 不要只做 schema,继续接入真实持久化和 replay」。
//
// ## What this exists for
//
// Chapter 七百三十八 第一刀 (M2361) landed the `006_risk_observations
// .sql` schema unconditionally。 Chapter 七百三十九 measured the
// L11 risk_plane Rust port at 1.12× — below the 1.5× default-flip
// threshold,so the in-memory ring stayed default。 But the SQL
// persistence layer NEVER WIRED into production code — schema lived
// in the codebase without consumers。 This file fixes that:
//
//   - Opens a SQLite database at a caller-supplied path
//   - Applies `RiskObservationsSchema.allStatementsSQL` on first
//     open (CREATE TABLE / INDEX IF NOT EXISTS — idempotent)
//   - Persists a typed `BASRiskObservationRecord` via INSERT
//   - Loads observations for a session via indexed SELECT
//   - Supports replay:cold-start re-opens the same DB,reads
//     observations back identical to pre-restart state
//
// ## Why this matters
//
// The chapter 七百三十八 第一刀 SQL schema preamble (line 35-46)
// declared two enabled queries:
//   1. "all hazardReading observations in session S between t1+t2"
//   2. "how many high-band observations in the last 24h?"
//
// Neither query was reachable in production code before this knife
// because no storage actor consumed the schema。 This knife makes
// both queries LIVE — hosts can now persist + replay risk
// observations across process restarts。
//
// ## ADR-014 OPT-IN preserved
//
// This storage class is purely additive。 Callers that don't
// instantiate it stay on the chapter 七百三十八 in-memory ring。
// The existing `BASRiskObservationLedger` actor surface is
// untouched at this knife。 Hosts that WANT persistence wire it
// in alongside the ledger;the ledger continues to serve the
// 128-entry in-memory fast path for non-persisted callers。

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - Storage error

public enum BASRiskObservationsSQLiteStorageError:
    Error, Equatable
{
    case sqliteOpenFailed(code: Int32, message: String)
    case schemaApplyFailed(message: String)
    case prepareFailed(sql: String, message: String)
    case stepFailed(sql: String, message: String)
    case corruptedRow(table: String, reason: String)
}

// MARK: - Typed record

/// Mirrors the `006_risk_observations.sql` row shape one-for-one。
/// Constructors that build this from `BASRiskObservation` live in
/// chapter 七百五十一 第四刀 production wire-up;at this knife the
/// storage is wired purely via the typed record。
public struct BASRiskObservationRecord:
    Equatable, Hashable, Sendable
{
    public let eventID: String
    public let sessionID: String
    public let turnID: String
    public let intentID: String
    public let observedAtMs: Int64
    public let riskBand: String
    public let riskScore: Double
    public let observationKind: String
    public let salience: Double
    public let confidence: Double
    public let payloadJSON: String?

    public init(
        eventID: String,
        sessionID: String,
        turnID: String,
        intentID: String,
        observedAtMs: Int64,
        riskBand: String,
        riskScore: Double,
        observationKind: String,
        salience: Double,
        confidence: Double,
        payloadJSON: String?
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.turnID = turnID
        self.intentID = intentID
        self.observedAtMs = observedAtMs
        self.riskBand = riskBand
        self.riskScore = riskScore
        self.observationKind = observationKind
        self.salience = salience
        self.confidence = confidence
        self.payloadJSON = payloadJSON
    }
}

// MARK: - Storage actor

/// SQLite-backed persistence for risk observations。
///
/// Thread-safety:every method is `func` (NOT actor) but the actor
/// boundary is enforced by the calling `BASRiskObservationLedger`
/// — every call MUST happen from inside the ledger actor。 This
/// mirrors the chapter 七百三十八 preamble note + the
/// `BASSovereignLedgerSQLiteStorage` pattern (M91)。
public final class BASRiskObservationsSQLiteStorage: @unchecked
    Sendable
{
    public let databaseURL: URL
    private var db: OpaquePointer?

    /// Open the SQLite database at the supplied URL and apply the
    /// chapter 七百三十八 第一刀 schema。 Idempotent — calling on an
    /// existing populated DB re-applies CREATE IF NOT EXISTS
    /// without data loss。
    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var handle: OpaquePointer?
        let openFlags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(
            databaseURL.path, &handle, openFlags, nil)
        guard openRC == SQLITE_OK, let opened = handle else {
            let msg = handle.map {
                String(cString: sqlite3_errmsg($0))
            } ?? "unknown open error"
            if let h = handle { sqlite3_close_v2(h) }
            throw BASRiskObservationsSQLiteStorageError
                .sqliteOpenFailed(code: openRC, message: msg)
        }
        self.db = opened
        // audit M-c (损坏=空): surface a structurally-corrupt store at OPEN — the read paths
        // returned `[]` on any error, mistaking corruption for "no observations" (a risk gate
        // reading empty is fail-open). Default-on, fail-closed. Runs BEFORE the best-effort
        // secure_delete pragma — a corrupt file must block open, not silently proceed.
        try BASSQLiteIntegrity.assertOK(db: opened, store: "risk-observations")
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete zeroes freed pages at delete
        // time so purged risk observations aren't forensically recoverable. Default-on;
        // kill-switch BAS_SECURE_DELETE=0. Best-effort — a failure here must not block open.
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            sqlite3_exec(opened, sdSQL, nil, nil, nil)
        }
        // memory-a F4 residual: one-time legacy freelist purge (see BASSQLiteSecureDelete). Outside txn.
        BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: opened)
        try applySchema()
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    private func applySchema() throws {
        guard let db else { return }
        let sql = RiskObservationsSchema.allStatementsSQL
        var errMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) }
                ?? "schema exec failed rc=\(rc)"
            sqlite3_free(errMsg)
            throw BASRiskObservationsSQLiteStorageError
                .schemaApplyFailed(message: msg)
        }
    }

    // MARK: - Write path

    /// Insert one risk observation row。 Idempotent on event_id
    /// (PRIMARY KEY)。 The ON CONFLICT clause keeps the FIRST
    /// observed row — deterministic for replay。
    public func persistObservation(
        _ record: BASRiskObservationRecord
    ) throws {
        guard let db else { return }
        let sql = """
            INSERT INTO risk_observations (
                event_id, session_id, turn_id, intent_id,
                observed_at_ms, risk_band, risk_score,
                observation_kind, salience, confidence,
                payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(event_id) DO NOTHING
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw BASRiskObservationsSQLiteStorageError
                .prepareFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        Self.bindText(stmt, 1, record.eventID)
        Self.bindText(stmt, 2, record.sessionID)
        Self.bindText(stmt, 3, record.turnID)
        Self.bindText(stmt, 4, record.intentID)
        sqlite3_bind_int64(stmt, 5, record.observedAtMs)
        Self.bindText(stmt, 6, record.riskBand)
        sqlite3_bind_double(stmt, 7, record.riskScore)
        Self.bindText(stmt, 8, record.observationKind)
        sqlite3_bind_double(stmt, 9, record.salience)
        sqlite3_bind_double(stmt, 10, record.confidence)
        if let payload = record.payloadJSON {
            Self.bindText(stmt, 11, payload)
        } else {
            sqlite3_bind_null(stmt, 11)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw BASRiskObservationsSQLiteStorageError
                .stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Read path

    /// Load all observations for a session in ascending observed_at
    /// order。 Used by the chapter 七百五十一 第三刀 replay test:
    /// open DB,write N observations,close,re-open,read back,
    /// assert identical。
    public func loadObservations(
        sessionID: String
    ) throws -> [BASRiskObservationRecord] {
        guard let db else { return [] }
        let sql = """
            SELECT event_id, session_id, turn_id, intent_id,
                   observed_at_ms, risk_band, risk_score,
                   observation_kind, salience, confidence,
                   payload_json
              FROM risk_observations
             WHERE session_id = ?
             ORDER BY observed_at_ms ASC, event_id ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw BASRiskObservationsSQLiteStorageError
                .prepareFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        Self.bindText(stmt, 1, sessionID)

        var rows: [BASRiskObservationRecord] = []
        var rc = sqlite3_step(stmt)
        while rc == SQLITE_ROW {
            let eventID = Self.readText(stmt, 0)
            let sessID = Self.readText(stmt, 1)
            let turnID = Self.readText(stmt, 2)
            let intentID = Self.readText(stmt, 3)
            let observedAtMs = sqlite3_column_int64(stmt, 4)
            let riskBand = Self.readText(stmt, 5)
            let riskScore = sqlite3_column_double(stmt, 6)
            let observationKind = Self.readText(stmt, 7)
            let salience = sqlite3_column_double(stmt, 8)
            let confidence = sqlite3_column_double(stmt, 9)
            let payloadJSON: String?
            if sqlite3_column_type(stmt, 10) == SQLITE_NULL {
                payloadJSON = nil
            } else {
                payloadJSON = Self.readText(stmt, 10)
            }

            rows.append(BASRiskObservationRecord(
                eventID: eventID,
                sessionID: sessID,
                turnID: turnID,
                intentID: intentID,
                observedAtMs: observedAtMs,
                riskBand: riskBand,
                riskScore: riskScore,
                observationKind: observationKind,
                salience: salience,
                confidence: confidence,
                payloadJSON: payloadJSON))
            rc = sqlite3_step(stmt)
        }
        // audit policy-obs-misc LOW-2: a non-DONE terminal (BUSY/CORRUPT) is NOT a clean end-of-rows —
        // surface it instead of returning a silently-truncated partial result.
        guard rc == SQLITE_DONE else {
            throw BASRiskObservationsSQLiteStorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return rows
    }

    /// Count of observations matching a band in the time range
    /// (used for chapter 七百三十八 preamble's "how many high-band
    /// in last 24h" query)。
    public func countObservations(
        band: String,
        sinceMs: Int64
    ) throws -> Int {
        guard let db else { return 0 }
        let sql = """
            SELECT COUNT(*) FROM risk_observations
             WHERE risk_band = ? AND observed_at_ms >= ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw BASRiskObservationsSQLiteStorageError
                .prepareFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        Self.bindText(stmt, 1, band)
        sqlite3_bind_int64(stmt, 2, sinceMs)

        // audit policy-obs-misc LOW-2: a COUNT(*) query always yields exactly one ROW — a non-ROW
        // terminal is a BUSY/CORRUPT error, NOT a legitimate count of 0. Surface it, don't fabricate 0.
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw BASRiskObservationsSQLiteStorageError.stepFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Bind / read helpers

    /// SQLITE_TRANSIENT signals SQLite to copy the bound bytes
    /// before returning (needed because Swift String storage is
    /// managed by ARC)。
    private static let SQLITE_TRANSIENT =
        unsafeBitCast(
            OpaquePointer(bitPattern: -1)!,
            to: sqlite3_destructor_type.self)

    private static func bindText(
        _ stmt: OpaquePointer,
        _ idx: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            stmt, idx, value, -1, SQLITE_TRANSIENT)
    }

    private static func readText(
        _ stmt: OpaquePointer,
        _ col: Int32
    ) -> String {
        guard let cstr = sqlite3_column_text(stmt, col) else {
            return ""
        }
        return String(cString: cstr)
    }
}
