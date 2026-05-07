// MARK: - BASAutoEvalRunner — chapter 三百七七 / M864
//
// G12 第四刀: actor that orchestrates the full auto-eval cycle:
//
//   1. Append candidate `BASEvalRun` to storage (M863)
//   2. Fetch baseline via `latestRun(forBuildChapter:)` or
//      `latestRun(forHostFingerprint:)`
//   3. Compare baseline + candidate via `BASEvalRegressionDetector`
//      (M861)
//   4. Persist the regression report via storage `appendReport(...)`
//   5. Emit a typed `BASAutoEvalCycleResult` for the caller — the
//      L11 gate / CI hook reads `safeToShip` / `anyRegressed` to
//      decide ship-or-block
//
// Future P3 G12 CI integration wires `submit(...)` as the post-eval
// hook in CI builds:caller passes the candidate run,actor handles
// storage + comparison + report emission in one call site。
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — eval is observation only,actor
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — the cycle result is a HINT;L11 gate
//   decides what action to take (ship / block / open ticket)
// - chapter 二百一一 single-source-of-truth — ONE actor module
//   owns the orchestration shape;hosts compose via it
// - chapter 一百八十五 anti-magic-number — baseline lookup mode
//   typed (BASAutoEvalBaselineMode),no inline strings
// - ADR-014 OPT-IN → PROD — actor is opt-in;hosts that don't
//   submit runs see zero behavior change

import Foundation

// MARK: - Baseline lookup mode

/// Typed enum naming WHICH baseline strategy the actor should use
/// when comparing a freshly submitted candidate。chapter 一百八十五
/// pin — every strategy has a typed case,not a free-form string。
public enum BASAutoEvalBaselineMode:
    Sendable, Equatable, Hashable
{
    /// Compare against the most-recent run sharing the same
    /// `buildChapter`。Use for "did this commit regress vs prior
    /// commit on same chapter?"。
    case latestForBuildChapter

    /// Compare against the most-recent run sharing the same
    /// `hostFingerprint`。Use for "did this host segment
    /// regress?" cross-chapter analysis。
    case latestForHostFingerprint

    /// Compare against an explicit baseline runID。Use for CI
    /// gates pinned to "last green main build"。
    case explicitRunID(String)

    /// Skip baseline lookup;persist only the candidate (no
    /// report)。Useful when the candidate is itself the new
    /// baseline (e.g. first run of a new build chapter)。
    case skipBaselineLookup
}

// MARK: - Cycle result

/// Typed result of one auto-eval submission cycle。Hosts query
/// `safeToShip` / `anyRegressed` for CI gate decisions;
/// `verdict` enumerates the four possible cycle outcomes。
public struct BASAutoEvalCycleResult:
    Sendable, Equatable, Codable, Hashable
{
    public enum Verdict:
        String, Sendable, Equatable, Codable, Hashable,
        CaseIterable
    {
        /// Candidate compared against baseline,no regressions
        /// detected,at least one improvement → ship signal。
        case shipped = "shipped"

        /// Candidate compared,zero regressions but no
        /// improvement either。Stable build。
        case stable = "stable"

        /// Candidate compared,at least one regression。Block
        /// signal for CI gate。
        case regressed = "regressed"

        /// No baseline available (first run / explicit skip)。
        /// Candidate persisted;no comparison performed。
        case noBaseline = "no-baseline"
    }

    /// Run ID the host submitted。
    public let candidateRunID: String

    /// Run ID of the baseline used for comparison,or nil if
    /// `noBaseline` verdict。
    public let baselineRunID: String?

    /// Cycle verdict per the typed enum above。
    public let verdict: Verdict

    /// Full regression report,or nil if `noBaseline` verdict。
    public let report: BASEvalRegressionReport?

    /// True iff the report contains zero regressions AND at
    /// least one improvement (matches `BASEvalRegressionReport
    /// .safeToShip`)。Always false when `noBaseline`。
    public var safeToShip: Bool {
        verdict == .shipped
    }

    /// True iff the report contains at least one regression。
    /// Always false when `noBaseline` or no report。
    public var anyRegressed: Bool {
        report?.anyRegressed ?? false
    }

    public init(
        candidateRunID: String,
        baselineRunID: String?,
        verdict: Verdict,
        report: BASEvalRegressionReport?
    ) {
        self.candidateRunID = candidateRunID
        self.baselineRunID = baselineRunID
        self.verdict = verdict
        self.report = report
    }
}

// MARK: - Auto eval runner actor

/// Actor that orchestrates the full auto-eval cycle on top of
/// M861 (`BASEvalRegressionDetector`) + M863 (`BASEvalRunStorage`)。
///
/// **Single-call surface**: `submit(candidate:baselineMode:tolerances:)`
/// performs persistence + lookup + comparison + report write
/// atomically (within the actor's serialized execution context)。
///
/// **No hidden retries**: storage failures bubble up as throws。
/// Per chapter 一百九十一 M91 doctrine,integrity outranks
/// availability — a corrupt or unavailable store fails fast
/// rather than silently dropping eval data。
public actor BASAutoEvalRunner {

    // MARK: - Stored state

    /// Underlying storage (typically `BASSQLiteEvalRunStorage`
    /// in production,`BASInMemoryEvalRunStorage` in tests)。
    private let storage: any BASEvalRunStorage

    // MARK: - Init

    public init(storage: any BASEvalRunStorage) {
        self.storage = storage
    }

    // MARK: - Submit (the single orchestration entry point)

    /// Submit a candidate run + run the full cycle。
    ///
    /// Steps:
    ///   1. Append the candidate to storage (idempotent on
    ///      duplicate runID)
    ///   2. Fetch baseline per `baselineMode`
    ///   3. If baseline found,compare via
    ///      `BASEvalRegressionDetector`
    ///   4. Persist the regression report (idempotent on
    ///      duplicate baseline-candidate pair)
    ///   5. Emit typed `BASAutoEvalCycleResult`
    ///
    /// **Tolerance overrides**: `customTolerances` flows through
    /// to the detector unchanged (chapter 一百八十五 pin)。
    ///
    /// **Submit timestamp**: report's `timestampMs` storage
    /// column uses the candidate's `timestampMs`。Hosts that need
    /// per-cycle wall clock can pass via candidate fields。
    ///
    /// - Parameters:
    ///   - candidate: caller-supplied freshly-completed run
    ///   - baselineMode: typed baseline lookup strategy
    ///   - customTolerances: per-metric drift tolerance overrides
    /// - Returns: typed cycle result
    /// - Throws: storage append errors (per chapter 一百九十一)
    @discardableResult
    public func submit(
        candidate: BASEvalRun,
        baselineMode: BASAutoEvalBaselineMode =
            .latestForBuildChapter,
        customTolerances: [BASEvalMetric: Double] = [:]
    ) async throws -> BASAutoEvalCycleResult {

        // Step 1: baseline lookup BEFORE persisting candidate
        // so the storage's `latestRun(for...)` doesn't return
        // the candidate itself。This lets us delegate the
        // predicate filtering to the storage's indexed query
        // (chapter 三百七六 M863 indexes) instead of pulling
        // every run into memory and filtering manually
        // (post-M872 deep review fix)。
        let baseline =
            try await fetchBaseline(
                for: candidate, mode: baselineMode)

        // Step 2: persist the candidate (idempotent)
        _ = try await storage.append(candidate)

        // Step 3: noBaseline short-circuit
        guard let baseline else {
            return BASAutoEvalCycleResult(
                candidateRunID: candidate.runID,
                baselineRunID: nil,
                verdict: .noBaseline,
                report: nil)
        }

        // Step 4: don't compare a run against itself (caller
        // accidentally passed the same runID for both — emit
        // noBaseline rather than a self-comparison report that
        // would always be all-noChange)
        guard baseline.runID != candidate.runID else {
            return BASAutoEvalCycleResult(
                candidateRunID: candidate.runID,
                baselineRunID: nil,
                verdict: .noBaseline,
                report: nil)
        }

        // Step 5: detector comparison
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate,
            customTolerances: customTolerances)

        // Step 6: persist the report (idempotent)
        _ = try await storage.appendReport(
            report,
            timestampMs: candidate.timestampMs)

        // Step 7: classify verdict
        let verdict = classifyVerdict(
            report: report)
        return BASAutoEvalCycleResult(
            candidateRunID: candidate.runID,
            baselineRunID: baseline.runID,
            verdict: verdict,
            report: report)
    }

    // MARK: - Read-only accessors (delegate to storage)

    /// Fetch a stored run by ID。
    public func run(forID runID: String) async -> BASEvalRun? {
        await storage.run(forID: runID)
    }

    /// Fetch the latest report for `candidateRunID`,or nil
    /// if none。
    public func latestReport(
        forCandidate candidateRunID: String
    ) async -> BASEvalRegressionReport? {
        let reports = await storage.reportsForCandidate(
            candidateRunID)
        return reports.last
    }

    /// Total run count from storage (diagnostic / dashboard)。
    public var totalRunCount: Int {
        get async {
            await storage.totalRunCount
        }
    }

    /// Total report count from storage (diagnostic / dashboard)。
    public var totalReportCount: Int {
        get async {
            await storage.totalReportCount
        }
    }

    // MARK: - Private helpers

    /// Look up the baseline per the typed mode。Returns nil for
    /// `.skipBaselineLookup` and for any mode that finds no
    /// matching prior run。
    ///
    /// Delegates the per-mode predicate filtering to the storage
    /// protocol methods (`latestRun(forBuildChapter:)` /
    /// `latestRun(forHostFingerprint:)`) rather than fetching all
    /// runs into memory then filtering。SQLite-backed storage
    /// honors the indexed scan (chapter 三百七六 M863 added the
    /// `(build_chapter, timestamp_ms)` + `(host_fingerprint,
    /// timestamp_ms)` indexes specifically for this lookup)。
    ///
    /// Self-comparison guard:if the candidate happens to be the
    /// latest match (e.g. it was just appended in the same submit
    /// cycle),return nil so `submit(...)` emits `.noBaseline`
    /// rather than a meaningless self-compare report。
    private func fetchBaseline(
        for candidate: BASEvalRun,
        mode: BASAutoEvalBaselineMode
    ) async throws -> BASEvalRun? {
        switch mode {
        case .latestForBuildChapter:
            let latest = await storage.latestRun(
                forBuildChapter: candidate.buildChapter)
            return latest?.runID == candidate.runID
                ? nil : latest

        case .latestForHostFingerprint:
            let latest = await storage.latestRun(
                forHostFingerprint: candidate.hostFingerprint)
            return latest?.runID == candidate.runID
                ? nil : latest

        case .explicitRunID(let runID):
            return await storage.run(forID: runID)

        case .skipBaselineLookup:
            return nil
        }
    }

    /// Classify the report into a typed verdict。
    private func classifyVerdict(
        report: BASEvalRegressionReport
    ) -> BASAutoEvalCycleResult.Verdict {
        if report.anyRegressed {
            return .regressed
        }
        if report.safeToShip {
            return .shipped
        }
        return .stable
    }
}
