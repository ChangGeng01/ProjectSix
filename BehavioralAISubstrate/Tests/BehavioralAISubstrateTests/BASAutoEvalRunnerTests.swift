// MARK: - BASAutoEvalRunnerTests — chapter 三百七七 / M864
//
// Test coverage for the auto-eval orchestration actor。Closes
// G12 P3 by exercising the full submit-cycle: persistence +
// baseline-fetch + detector comparison + report-persist + verdict
// classification。
//
// Tests verify:
//   - First-submission noBaseline path (no prior run exists)
//   - latestForBuildChapter finds prior same-chapter run
//   - latestForHostFingerprint finds prior same-host run
//   - explicitRunID looks up by ID
//   - skipBaselineLookup persists candidate but skips comparison
//   - Self-comparison guard (same runID baseline + candidate)
//   - Verdict classification: shipped / stable / regressed /
//     noBaseline
//   - Cycle persists report on success path
//   - Cycle is idempotent (resubmit same run does not duplicate)
//   - Custom tolerances flow through to detector
//   - latestReport accessor returns last report for candidate

import XCTest
@testable import BASRuntimeCore

final class BASAutoEvalRunnerTests: XCTestCase {

    // MARK: - Fixtures

    private func makeRun(
        runID: String,
        timestampMs: Int64,
        metrics: [BASEvalMetric: Double],
        buildChapter: String = "M864",
        hostFingerprint: String = "test-host"
    ) -> BASEvalRun {
        BASEvalRun(
            runID: runID,
            timestampMs: timestampMs,
            metrics: metrics,
            buildChapter: buildChapter,
            hostFingerprint: hostFingerprint,
            sampleCount: 100)
    }

    private func makeRunner()
        -> (BASAutoEvalRunner, BASInMemoryEvalRunStorage)
    {
        let storage = BASInMemoryEvalRunStorage()
        let runner = BASAutoEvalRunner(storage: storage)
        return (runner, storage)
    }

    // MARK: - First submission: noBaseline path

    func testFirstSubmissionEmitsNoBaseline() async throws {
        let (runner, _) = makeRunner()
        let run = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])

        let result = try await runner.submit(candidate: run)

        XCTAssertEqual(result.verdict, .noBaseline)
        XCTAssertNil(result.baselineRunID)
        XCTAssertNil(result.report)
        XCTAssertFalse(result.safeToShip)
        XCTAssertFalse(result.anyRegressed)
    }

    func testFirstSubmissionPersistsCandidate() async throws {
        let (runner, storage) = makeRunner()
        let run = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: run)

        let stored = await storage.run(forID: "r1")
        XCTAssertEqual(stored, run,
            "First submission must persist candidate even " +
            "when no baseline exists yet")
    }

    // MARK: - Baseline lookup: latestForBuildChapter

    func testSecondSubmissionFindsBaselineByBuildChapter()
        async throws
    {
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.90],
            buildChapter: "M863")
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95],
            buildChapter: "M863")

        _ = try await runner.submit(candidate: baseline)
        let result = try await runner.submit(
            candidate: candidate)

        XCTAssertEqual(result.verdict, .shipped,
            "Accuracy 0.90 → 0.95 is improvement → shipped " +
            "verdict")
        XCTAssertEqual(result.baselineRunID, "r1")
        XCTAssertNotNil(result.report)
        XCTAssertTrue(result.safeToShip)
        XCTAssertFalse(result.anyRegressed)
    }

    func testBuildChapterModeIgnoresOtherChapters() async throws
    {
        let (runner, _) = makeRunner()
        let m860 = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.50],
            buildChapter: "M860")
        let m863 = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95],
            buildChapter: "M863")

        _ = try await runner.submit(candidate: m860)
        let result = try await runner.submit(
            candidate: m863,
            baselineMode: .latestForBuildChapter)

        XCTAssertEqual(result.verdict, .noBaseline,
            "Different buildChapter must NOT be used as " +
            "baseline (would compare apples to oranges)")
    }

    // MARK: - Baseline lookup: latestForHostFingerprint

    func testHostFingerprintMode() async throws {
        let (runner, _) = makeRunner()
        let priorOnHost = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.latencyP95: 100.0],
            buildChapter: "M860",
            hostFingerprint: "fp-A")
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.latencyP95: 50.0],
            buildChapter: "M863",
            hostFingerprint: "fp-A")

        _ = try await runner.submit(candidate: priorOnHost)
        let result = try await runner.submit(
            candidate: candidate,
            baselineMode: .latestForHostFingerprint)

        XCTAssertEqual(result.verdict, .shipped,
            "p95 latency 100 → 50 is improvement (lower better)")
        XCTAssertEqual(result.baselineRunID, "r1")
    }

    // MARK: - Baseline lookup: explicitRunID

    func testExplicitRunIDMode() async throws {
        let (runner, _) = makeRunner()
        let oldBaseline = makeRun(
            runID: "old",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let recentRun = makeRun(
            runID: "recent",
            timestampMs: 200,
            metrics: [.accuracy: 0.90])
        let candidate = makeRun(
            runID: "candidate",
            timestampMs: 300,
            metrics: [.accuracy: 0.92])

        _ = try await runner.submit(candidate: oldBaseline)
        _ = try await runner.submit(candidate: recentRun)
        let result = try await runner.submit(
            candidate: candidate,
            baselineMode: .explicitRunID("old"))

        XCTAssertEqual(result.baselineRunID, "old",
            "Explicit run ID must override timestamp-based " +
            "lookup")
    }

    func testExplicitRunIDMissingReturnsNoBaseline()
        async throws
    {
        let (runner, _) = makeRunner()
        let candidate = makeRun(
            runID: "candidate",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])

        let result = try await runner.submit(
            candidate: candidate,
            baselineMode: .explicitRunID("nonexistent"))

        XCTAssertEqual(result.verdict, .noBaseline)
    }

    // MARK: - skipBaselineLookup

    func testSkipBaselineLookup() async throws {
        let (runner, storage) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: baseline)
        let result = try await runner.submit(
            candidate: candidate,
            baselineMode: .skipBaselineLookup)

        XCTAssertEqual(result.verdict, .noBaseline,
            "skipBaselineLookup must produce noBaseline " +
            "verdict regardless of prior runs in storage")

        // But the candidate IS still persisted
        let stored = await storage.run(forID: "r2")
        XCTAssertNotNil(stored)
    }

    // MARK: - Self-comparison guard

    func testSelfComparisonReturnsNoBaseline() async throws {
        let (runner, _) = makeRunner()
        let run = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: run)
        // Resubmit same runID — should return noBaseline
        // since the only matching baseline is itself
        let result = try await runner.submit(candidate: run)

        XCTAssertEqual(result.verdict, .noBaseline,
            "Resubmit must not compare a run against itself")
    }

    // MARK: - Verdict classification

    func testRegressedVerdict() async throws {
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.85])

        _ = try await runner.submit(candidate: baseline)
        let result = try await runner.submit(
            candidate: candidate)

        XCTAssertEqual(result.verdict, .regressed)
        XCTAssertTrue(result.anyRegressed)
        XCTAssertFalse(result.safeToShip)
    }

    func testStableVerdict() async throws {
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.900])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.901])
            // 0.1% delta is within 0.5% accuracy tolerance

        _ = try await runner.submit(candidate: baseline)
        let result = try await runner.submit(
            candidate: candidate)

        XCTAssertEqual(result.verdict, .stable,
            "All-noChange report → stable verdict (no " +
            "regression but no meaningful improvement)")
        XCTAssertFalse(result.anyRegressed)
        XCTAssertFalse(result.safeToShip)
    }

    // MARK: - Custom tolerances

    func testCustomTolerancesFlowThrough() async throws {
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.90])

        // Default 0.5% tolerance → regressed
        _ = try await runner.submit(candidate: baseline)
        let withDefaults = try await runner.submit(
            candidate: candidate)
        XCTAssertEqual(withDefaults.verdict, .regressed)
    }

    func testCustomTolerancesAllowLargerDrift() async throws {
        // Re-run with same scenario but a 10% custom tolerance
        // → should classify as stable (or shipped if any
        // improvement) rather than regressed
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.90])

        _ = try await runner.submit(candidate: baseline)
        let result = try await runner.submit(
            candidate: candidate,
            customTolerances: [.accuracy: 0.10])

        XCTAssertNotEqual(result.verdict, .regressed,
            "10% tolerance must not flag 5% drop as regression")
    }

    // MARK: - Report persistence

    func testCyclePersistsReport() async throws {
        let (runner, storage) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: baseline)
        _ = try await runner.submit(candidate: candidate)

        let storedReport = await storage.report(
            baselineRunID: "r1", candidateRunID: "r2")
        XCTAssertNotNil(storedReport,
            "Cycle must persist the report for the comparison")
        let reportCount = await storage.totalReportCount
        XCTAssertEqual(reportCount, 1)
    }

    // MARK: - Idempotency

    func testResubmitDoesNotDuplicateRunsOrReports()
        async throws
    {
        let (runner, storage) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let candidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: baseline)
        _ = try await runner.submit(candidate: candidate)
        // Resubmit candidate — should NOT add duplicate run
        // or duplicate report
        _ = try await runner.submit(candidate: candidate)

        let runCount = await storage.totalRunCount
        XCTAssertEqual(runCount, 2)
        let reportCount = await storage.totalReportCount
        XCTAssertEqual(reportCount, 1)
    }

    // MARK: - Read-only accessors

    func testRunForIDDelegatesToStorage() async throws {
        let (runner, _) = makeRunner()
        let run = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: run)

        let fetched = await runner.run(forID: "r1")
        XCTAssertEqual(fetched, run)
    }

    func testLatestReportAccessor() async throws {
        let (runner, _) = makeRunner()
        let baseline = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let firstCandidate = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.90])
        let secondCandidate = makeRun(
            runID: "r3",
            timestampMs: 300,
            metrics: [.accuracy: 0.95])

        _ = try await runner.submit(candidate: baseline)
        _ = try await runner.submit(
            candidate: firstCandidate)
        _ = try await runner.submit(
            candidate: secondCandidate)

        let r2Report = await runner.latestReport(
            forCandidate: "r2")
        XCTAssertNotNil(r2Report)
        XCTAssertEqual(r2Report?.baselineRunID, "r1")
    }

    func testTotalCountAccessors() async throws {
        let (runner, _) = makeRunner()
        let r1 = makeRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.85])
        let r2 = makeRun(
            runID: "r2",
            timestampMs: 200,
            metrics: [.accuracy: 0.95])
        _ = try await runner.submit(candidate: r1)
        _ = try await runner.submit(candidate: r2)

        let runs = await runner.totalRunCount
        let reports = await runner.totalReportCount
        XCTAssertEqual(runs, 2)
        XCTAssertEqual(reports, 1)
    }

    // MARK: - Verdict enum lint guard

    func testVerdictIsCaseIterableComplete() {
        // Pin: every Verdict case must be reachable via the
        // classifier。Lint guard ensures we don't add a new
        // case without updating the cycle classifier。
        XCTAssertEqual(
            BASAutoEvalCycleResult.Verdict.allCases.count, 4)
    }
}
