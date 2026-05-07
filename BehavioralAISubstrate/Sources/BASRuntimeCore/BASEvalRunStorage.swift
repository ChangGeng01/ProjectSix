// MARK: - BASEvalRunStorage — chapter 三百七六 / M863
//
// G12 第三刀: typed protocol + in-memory conformer for persisted
// eval runs。Hosts append `BASEvalRun` after each eval pass + read
// back baselines for regression detection via M861's
// `BASEvalRegressionDetector`。
//
// ## What this ships
//
//   - `BASEvalRunStorage` — Sendable async protocol with append +
//     query primitives for runs AND regression reports
//   - `BASInMemoryEvalRunStorage` — actor conformer for tests +
//     one-shot CLI runs
//
// Companion file:
//   - `BASSQLiteEvalRunStorage.swift` (also chapter 三百七六) —
//     SQLite-backed conformer per chapter 二百四十八 idiom
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — eval run storage is observation
//     only,never mutates permits / verdicts / commit token
//   - 红线 7 hint-only — stored runs feed regression detector;
//     detector verdict is HINT,L11 gate decides
//   - chapter 二百一一 single-source-of-truth — ONE protocol owns
//     run + report storage shape
//   - chapter 一百二 五级删除 — append-only; no DELETE API。
//     Forget cascades operate on memory atoms,not eval data
//   - chapter 二百四十八 (M735) — SQLite conformer mirrors the
//     idiom (WAL + transient destructor + typed StorageError)
//   - ADR-014 OPT-IN → PROD — primitive only;hosts opt in by
//     wiring storage themselves

import Foundation

// MARK: - Storage protocol

/// Append-only typed eval run + regression report storage。
/// Sendable;all methods async because conformers may use actor
/// isolation。
///
/// **Contract**:
///   - `append(_:)` for runs is **idempotent on duplicate runID**
///     — re-appending returns `false` and does NOT mutate
///   - `appendReport(_:timestampMs:)` is **idempotent on the
///     (baselineRunID, candidateRunID) pair** — re-appending
///     returns `false` (overwrites are not permitted to preserve
///     audit trail)
///   - `latestRun(forBuildChapter:)` / `latestRun(forHostFingerprint:)`
///     return the most-recent run matching the predicate by
///     `timestampMs DESC` — used by the future M864 auto eval
///     runner to fetch the baseline against which a new candidate
///     is compared
///   - `runs(sinceTimestampMs:limit:)` is the timestamp range
///     scan used for trend analysis + dashboard UIs
public protocol BASEvalRunStorage: Sendable {

    // MARK: - Run CRUD

    /// Append an eval run。Returns `true` if it was new,`false`
    /// if `runID` already existed (idempotent retry semantics)。
    @discardableResult
    func append(
        _ run: BASEvalRun
    ) async throws -> Bool

    /// Read run by ID。Returns nil if not found。
    func run(forID runID: String) async -> BASEvalRun?

    /// Most-recent run matching `buildChapter` ordered by
    /// `timestampMs DESC`。Returns nil if no runs match。
    func latestRun(
        forBuildChapter buildChapter: String
    ) async -> BASEvalRun?

    /// Most-recent run matching `hostFingerprint` ordered by
    /// `timestampMs DESC`。Returns nil if no runs match。
    func latestRun(
        forHostFingerprint hostFingerprint: String
    ) async -> BASEvalRun?

    /// Runs with `timestampMs >= since`,limit applied after
    /// ordering by `timestampMs ASC`。Used for trend analysis。
    func runs(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEvalRun]

    /// Total run count (all build chapters / hosts)。
    var totalRunCount: Int { get async }

    // MARK: - Report CRUD

    /// Append a regression report。Returns `true` if new,
    /// `false` if (baselineRunID, candidateRunID) pair already
    /// existed。
    @discardableResult
    func appendReport(
        _ report: BASEvalRegressionReport,
        timestampMs: Int64
    ) async throws -> Bool

    /// Read report by (baseline, candidate) pair。Returns nil
    /// if not found。
    func report(
        baselineRunID: String,
        candidateRunID: String
    ) async -> BASEvalRegressionReport?

    /// All reports targeting `candidateRunID`,ordered by
    /// timestamp ASC。Used to find every comparison run against
    /// a candidate (e.g. when ratcheting baselines)。
    func reportsForCandidate(
        _ candidateRunID: String
    ) async -> [BASEvalRegressionReport]

    /// Total report count (all baseline-candidate pairs)。
    var totalReportCount: Int { get async }
}

// MARK: - In-memory conformer

/// Default in-memory `BASEvalRunStorage` conformer。Process-scoped;
/// does NOT persist across restarts。For cross-build continuity
/// use `BASSQLiteEvalRunStorage`。
public actor BASInMemoryEvalRunStorage: BASEvalRunStorage {

    // Index by runID — primary key
    private var runs: [String: BASEvalRun] = [:]

    // Insertion order for ascending-timestamp range scans
    private var runInsertionOrder: [String] = []

    // Reports keyed by composite (baselineRunID, candidateRunID)
    // Stored alongside an insertion timestamp (ms epoch) so
    // ordering matches SQLite conformer semantics。
    private var reports:
        [ReportKey: (
            report: BASEvalRegressionReport,
            timestampMs: Int64)] = [:]
    private var reportInsertionOrder: [ReportKey] = []

    public init() {}

    // MARK: - Run CRUD

    @discardableResult
    public func append(
        _ run: BASEvalRun
    ) async throws -> Bool {
        if runs[run.runID] != nil { return false }
        runs[run.runID] = run
        runInsertionOrder.append(run.runID)
        return true
    }

    public func run(forID runID: String) async -> BASEvalRun? {
        runs[runID]
    }

    public func latestRun(
        forBuildChapter buildChapter: String
    ) async -> BASEvalRun? {
        runs.values
            .filter { $0.buildChapter == buildChapter }
            .max { $0.timestampMs < $1.timestampMs }
    }

    public func latestRun(
        forHostFingerprint hostFingerprint: String
    ) async -> BASEvalRun? {
        runs.values
            .filter {
                $0.hostFingerprint == hostFingerprint
            }
            .max { $0.timestampMs < $1.timestampMs }
    }

    public func runs(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEvalRun] {
        guard limit > 0 else { return [] }
        let filtered = runs.values
            .filter { $0.timestampMs >= since }
            .sorted { $0.timestampMs < $1.timestampMs }
        return Array(filtered.prefix(limit))
    }

    public var totalRunCount: Int {
        runs.count
    }

    // MARK: - Report CRUD

    @discardableResult
    public func appendReport(
        _ report: BASEvalRegressionReport,
        timestampMs: Int64
    ) async throws -> Bool {
        let key = ReportKey(
            baselineRunID: report.baselineRunID,
            candidateRunID: report.candidateRunID)
        if reports[key] != nil { return false }
        reports[key] = (
            report: report, timestampMs: timestampMs)
        reportInsertionOrder.append(key)
        return true
    }

    public func report(
        baselineRunID: String,
        candidateRunID: String
    ) async -> BASEvalRegressionReport? {
        let key = ReportKey(
            baselineRunID: baselineRunID,
            candidateRunID: candidateRunID)
        return reports[key]?.report
    }

    public func reportsForCandidate(
        _ candidateRunID: String
    ) async -> [BASEvalRegressionReport] {
        reportInsertionOrder
            .filter { $0.candidateRunID == candidateRunID }
            .compactMap { reports[$0]?.report }
    }

    public var totalReportCount: Int {
        reports.count
    }

    // MARK: - Internal key

    /// Composite key for `(baseline, candidate)` report uniqueness。
    private struct ReportKey: Hashable, Sendable {
        let baselineRunID: String
        let candidateRunID: String
    }
}
