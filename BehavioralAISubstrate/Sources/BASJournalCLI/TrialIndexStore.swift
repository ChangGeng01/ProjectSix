// MARK: - TrialIndexStore — the CLI-owned cross-boot open-trials index (increment 3)
//
// WHY THIS EXISTS. The substrate's BASShadowTrialCoordinator keeps trial state IN MEMORY ONLY
// — it appends events to the ledger but never reads them back, so a fresh process starts with
// no knowledge of trials opened by a prior process. That is exactly the contract increment 1
// hit with the digest-only event store: the substrate is the tamper-evident RECORD, and the
// host owns whatever queryable STATE it needs. So the journal owns this small index: which
// trials are still open (for the morning `review`), and the coordinator ids needed to RESUME +
// finalize them across boots (the trialID is UUID-pumped in the dead process and unrecoverable
// otherwise). The Ed25519 ledger remains the authority on what happened; this is a cache/index.
//
// Deletion doctrine (#16): secure_delete is ON (kill-switch BAS_SECURE_DELETE=0), so a purged
// row's bytes are zeroed, matching the sovereign journal's deleted-is-truly-gone guarantee.

import Foundation
import SQLite3
import BASRuntimeCore

/// One row of the open-trials index. Holds enough to (a) render `review` and (b) reconstruct
/// the BASExperienceCandidate + BASShadowTrialRecord needed to resume the trial in a later
/// process. `decisionSummary` / `openQuestion` are operator-readable (this is the host's own
/// store, like increment 1's content sidecar); `decisionDigest` is the SHA-256 that ties the
/// trial back to the sealed decision without re-storing raw text in the sovereign ledger.
struct TrialIndexRow {
    let trialID: String
    let candidateID: String
    let atomID: String
    let decisionDigest: String
    let decisionSummary: String
    let openQuestion: String
    let trialScope: String
    let openedAt: Date
    var state: String                 // "pending" / "observing" / "passed" / "failed"
    var observedEffects: [String]
    var failConditions: [String]
    var outcome: String?              // nil until closed
    var closedAt: Date?
    var verdictAllows: Bool?
    var verdictReasons: [String]

    var isOpen: Bool { state == "pending" || state == "observing" }
}

enum TrialIndexError: Error, CustomStringConvertible {
    case openFailed(String)
    case sqlFailed(String)

    var description: String {
        switch self {
        case .openFailed(let m): return "trial index open failed: \(m)"
        case .sqlFailed(let m): return "trial index sql failed: \(m)"
        }
    }
}

/// A tiny single-table SQLite store for the open-trials index. Synchronous; the CLI drives one
/// command per process, so no concurrency wrapper is needed.
final class TrialIndexStore {
    private var db: OpaquePointer?
    private static let listSep = "\u{001F}"   // unit separator: never appears in effects/reasons

    init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(
            path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let handle
        else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open_v2 failed"
            if handle != nil { sqlite3_close_v2(handle) }
            throw TrialIndexError.openFailed(msg)
        }
        self.db = handle
        do {
            try exec("PRAGMA journal_mode=WAL;")
            if let sd = BASSQLiteSecureDelete.openPragmaSQL { try exec(sd) }
            try exec("""
                CREATE TABLE IF NOT EXISTS trial_index (
                    trial_id TEXT PRIMARY KEY,
                    candidate_id TEXT NOT NULL,
                    atom_id TEXT NOT NULL,
                    decision_digest TEXT NOT NULL,
                    decision_summary TEXT NOT NULL,
                    open_question TEXT NOT NULL,
                    trial_scope TEXT NOT NULL,
                    opened_at_ms INTEGER NOT NULL,
                    state TEXT NOT NULL,
                    observed_effects TEXT NOT NULL,
                    fail_conditions TEXT NOT NULL,
                    outcome TEXT,
                    closed_at_ms INTEGER,
                    verdict_allows INTEGER,
                    verdict_reasons TEXT NOT NULL
                );
                """)
        } catch {
            sqlite3_close_v2(handle)
            self.db = nil
            throw error
        }
    }

    deinit { if let db { sqlite3_close_v2(db) } }

    // MARK: - Writes

    func insertOpen(_ row: TrialIndexRow) throws {
        try run("""
            INSERT INTO trial_index (
                trial_id, candidate_id, atom_id, decision_digest, decision_summary,
                open_question, trial_scope, opened_at_ms, state, observed_effects,
                fail_conditions, outcome, closed_at_ms, verdict_allows, verdict_reasons
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,NULL,NULL,NULL,?)
            """) { stmt in
            bindText(stmt, 1, row.trialID)
            bindText(stmt, 2, row.candidateID)
            bindText(stmt, 3, row.atomID)
            bindText(stmt, 4, row.decisionDigest)
            bindText(stmt, 5, row.decisionSummary)
            bindText(stmt, 6, row.openQuestion)
            bindText(stmt, 7, row.trialScope)
            sqlite3_bind_int64(stmt, 8, Self.ms(row.openedAt))
            bindText(stmt, 9, row.state)
            bindText(stmt, 10, row.observedEffects.joined(separator: Self.listSep))
            bindText(stmt, 11, row.failConditions.joined(separator: Self.listSep))
            bindText(stmt, 12, row.verdictReasons.joined(separator: Self.listSep))
        }
    }

    /// Mark a trial terminal, recording outcome + the fired promotion verdict.
    func close(
        trialID: String, outcome: String, closedAt: Date,
        verdictAllows: Bool, verdictReasons: [String], observedEffects: [String],
        failConditions: [String]
    ) throws {
        try run("""
            UPDATE trial_index SET state=?, outcome=?, closed_at_ms=?, verdict_allows=?,
                verdict_reasons=?, observed_effects=?, fail_conditions=? WHERE trial_id=?
            """) { stmt in
            bindText(stmt, 1, outcome)
            bindText(stmt, 2, outcome)
            sqlite3_bind_int64(stmt, 3, Self.ms(closedAt))
            sqlite3_bind_int64(stmt, 4, verdictAllows ? 1 : 0)
            bindText(stmt, 5, verdictReasons.joined(separator: Self.listSep))
            bindText(stmt, 6, observedEffects.joined(separator: Self.listSep))
            bindText(stmt, 7, failConditions.joined(separator: Self.listSep))
            bindText(stmt, 8, trialID)
        }
    }

    /// Purge every trial-index row for a decision atom — the deletion-doctrine hook: when the
    /// operator `forget`s a bet's decision, its trial rows (which retain operator-readable text)
    /// are secure-deleted too (secure_delete=ON zeroes the freed bytes). Returns rows removed.
    @discardableResult
    func purge(atomID: String) throws -> Int {
        try run("DELETE FROM trial_index WHERE atom_id=?") { stmt in bindText(stmt, 1, atomID) }
        guard let db else { return 0 }
        return Int(sqlite3_changes(db))
    }

    // MARK: - Reads

    /// Open trials, oldest first (the morning re-surfacing order).
    func openRows() throws -> [TrialIndexRow] {
        try query("SELECT * FROM trial_index WHERE state IN ('pending','observing') "
            + "ORDER BY opened_at_ms ASC")
    }

    func allRows() throws -> [TrialIndexRow] {
        try query("SELECT * FROM trial_index ORDER BY opened_at_ms ASC")
    }

    /// Resolve a caller-supplied trial-id PREFIX to exactly one row (like `forget`'s resolution).
    /// Returns nil if zero or ambiguous; the caller reports the specific case.
    func resolve(prefix: String) throws -> (row: TrialIndexRow?, matchCount: Int) {
        let all = try allRows()
        let matches = all.filter { $0.trialID.lowercased().hasPrefix(prefix.lowercased()) }
        return (matches.count == 1 ? matches.first : nil, matches.count)
    }

    // MARK: - SQLite plumbing

    private func query(_ sql: String) throws -> [TrialIndexRow] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw TrialIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var rows: [TrialIndexRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(TrialIndexRow(
                trialID: text(stmt, 0),
                candidateID: text(stmt, 1),
                atomID: text(stmt, 2),
                decisionDigest: text(stmt, 3),
                decisionSummary: text(stmt, 4),
                openQuestion: text(stmt, 5),
                trialScope: text(stmt, 6),
                openedAt: Self.date(sqlite3_column_int64(stmt, 7)),
                state: text(stmt, 8),
                observedEffects: splitList(text(stmt, 9)),
                failConditions: splitList(text(stmt, 10)),
                outcome: sqlite3_column_type(stmt, 11) == SQLITE_NULL ? nil : text(stmt, 11),
                closedAt: sqlite3_column_type(stmt, 12) == SQLITE_NULL
                    ? nil : Self.date(sqlite3_column_int64(stmt, 12)),
                verdictAllows: sqlite3_column_type(stmt, 13) == SQLITE_NULL
                    ? nil : (sqlite3_column_int64(stmt, 13) != 0),
                verdictReasons: splitList(text(stmt, 14))))
        }
        return rows
    }

    private func run(_ sql: String, _ bind: (OpaquePointer) -> Void) throws {
        guard let db else { throw TrialIndexError.sqlFailed("db closed") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw TrialIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrialIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func exec(_ sql: String) throws {
        guard let db else { throw TrialIndexError.sqlFailed("db closed") }
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let m = err.map { p -> String in let s = String(cString: p); sqlite3_free(p); return s }
                ?? "exec failed"
            throw TrialIndexError.sqlFailed(m)
        }
    }

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

    private func bindText(_ stmt: OpaquePointer, _ i: Int32, _ v: String) {
        sqlite3_bind_text(stmt, i, v, -1, Self.SQLITE_TRANSIENT)
    }
    private func text(_ stmt: OpaquePointer, _ i: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, i) else { return "" }
        return String(cString: c)
    }
    private func splitList(_ s: String) -> [String] {
        s.isEmpty ? [] : s.components(separatedBy: Self.listSep)
    }
    private static func ms(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }
    private static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }
}
