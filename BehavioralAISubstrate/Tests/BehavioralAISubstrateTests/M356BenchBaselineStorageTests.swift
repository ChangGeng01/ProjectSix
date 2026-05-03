import XCTest
@testable import BASObservability

/// M356 — pin the typed baseline storage + regression detection
/// primitive.
///
/// What this file pins:
///
///   1. Reading a non-existent file returns nil (no throw).
///   2. Round-trip write+read produces byte-equal envelope.
///   3. Comparison with no baseline returns .noBaseline.
///   4. Comparison with mismatched benchName returns .incompatibleBaseline.
///   5. Comparison within tolerance returns .withinTolerance.
///   6. Comparison beyond tolerance returns .regression with
///      per-metric reports.
///   7. Default tolerance is 25% of baseline.
///   8. Zero-valued baseline metrics are skipped (no division by
///      zero).
final class M356BenchBaselineStorageTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "m356_bench_baseline_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func sampleStats(
        meanMultiplier: Double = 1.0
    ) -> BASBenchLatencyStats {
        BASBenchLatencyStats(
            sampleCount: 1000,
            min: 0.5 * meanMultiplier,
            max: 2.5 * meanMultiplier,
            mean: 1.0 * meanMultiplier,
            p50: 0.95 * meanMultiplier,
            p95: 1.5 * meanMultiplier,
            p99: 2.0 * meanMultiplier,
            p999: 2.4 * meanMultiplier,
            standardDeviation: 0.3 * meanMultiplier,
            outlierCount: 3)
    }

    // MARK: - File I/O

    func testReadNonExistentFileReturnsNil() throws {
        let path = tempDir.appendingPathComponent(
            "nonexistent.json")
        let result = try BASBenchBaselineStorage
            .readBaseline(from: path)
        XCTAssertNil(result)
    }

    func testWriteThenReadRoundTrip() throws {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        let envelope = BASBenchBaselineStorage.Envelope(
            benchName: "test-bench",
            storedAt: Date(timeIntervalSince1970: 1_700_000_000),
            stats: sampleStats())
        try BASBenchBaselineStorage.writeBaseline(
            envelope: envelope, to: path)
        let read = try BASBenchBaselineStorage
            .readBaseline(from: path)
        XCTAssertEqual(envelope, read)
    }

    // MARK: - Comparison verdicts

    func testCompareWithNoBaselineReturnsNoBaseline() throws {
        let path = tempDir.appendingPathComponent(
            "missing.json")
        let measured = sampleStats()
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "test-bench",
                baselinePath: path)
        XCTAssertEqual(verdict, .noBaseline)
    }

    func testCompareWithMismatchedBenchNameReturnsIncompatible()
        throws
    {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "wrong-bench",
                stats: sampleStats()),
            to: path)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: sampleStats(),
                benchName: "test-bench",
                baselinePath: path)
        if case .incompatibleBaseline(
            let reason) = verdict
        {
            XCTAssertTrue(
                reason.contains("test-bench"))
            XCTAssertTrue(
                reason.contains("wrong-bench"))
        } else {
            XCTFail(
                "expected incompatibleBaseline; got \(verdict)")
        }
    }

    func testCompareWithinToleranceReturnsWithinTolerance()
        throws
    {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "test-bench",
                stats: sampleStats()),
            to: path)
        // Measured is 10% slower — within default 25% tolerance.
        let measured = sampleStats(meanMultiplier: 1.10)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "test-bench",
                baselinePath: path)
        XCTAssertEqual(verdict, .withinTolerance)
    }

    func testCompareBeyondToleranceReturnsRegression() throws {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "test-bench",
                stats: sampleStats()),
            to: path)
        // Measured is 50% slower — beyond default 25% tolerance.
        let measured = sampleStats(meanMultiplier: 1.50)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "test-bench",
                baselinePath: path)
        if case .regression(let reports) = verdict {
            // 3 metrics compared (p50/p95/mean) — all should
            // regress by ~50%. M436.6 (chapter 一百九) dropped
            // p99 from the regression check because single-trial
            // p99 swings 50-150% on OS-jitter outliers alone
            // (the 1-of-N worst-sample sensitivity); real
            // regressions show in p50+p95+mean simultaneously.
            // p99 stays in the JSON baseline + markdown report
            // for diagnostic visibility, just not as alarm.
            XCTAssertEqual(reports.count, 3)
            // Pin the names to confirm p99 was specifically
            // dropped, not some other metric drift.
            let names = Set(reports.map(\.metricName))
            XCTAssertEqual(names, ["p50", "p95", "mean"])
            for report in reports {
                XCTAssertEqual(
                    report.regressionFraction, 0.50,
                    accuracy: 0.01)
                XCTAssertEqual(
                    report.toleranceFraction, 0.25)
            }
        } else {
            XCTFail("expected regression; got \(verdict)")
        }
    }

    /// M436.6 (chapter 一百九) — pin that the absolute-µs
    /// floor skips regression check on metrics where both
    /// baseline AND measured are below 5µs. Sub-µs scales are
    /// timer-jitter-dominated; pre-fix the suite would fire
    /// false-positive alarms on lifecycle-bench (~0.6µs)
    /// every other run.
    func testSubFiveMicrosecondMetricsSkipRegressionCheck() throws {
        let path = tempDir.appendingPathComponent(
            "sub-us-baseline.json")
        // All metrics in baseline are < 5µs (= 0.005ms).
        let baselineStats = BASBenchLatencyStats(
            sampleCount: 1000,
            min: 0.0005,
            max: 0.001,
            mean: 0.0006,
            p50: 0.0006,
            p95: 0.0008,
            p99: 0.0009,
            p999: 0.001,
            standardDeviation: 0.0001,
            outlierCount: 0)
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "sub-us-bench",
                stats: baselineStats),
            to: path)
        // Measured is 100% slower — but still all < 5µs, so
        // floor must skip the check.
        let measuredStats = BASBenchLatencyStats(
            sampleCount: 1000,
            min: 0.001,
            max: 0.002,
            mean: 0.0012,
            p50: 0.0012,
            p95: 0.0016,
            p99: 0.0018,
            p999: 0.002,
            standardDeviation: 0.0002,
            outlierCount: 0)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measuredStats,
                benchName: "sub-us-bench",
                baselinePath: path)
        if case .withinTolerance = verdict {
            // OK
        } else {
            XCTFail(
                "all metrics below 5µs floor must be skipped — " +
                "single-trial sub-µs measurements are timer-" +
                "jitter dominated and not stat-rigorous " +
                "(M436.6); got verdict \(verdict)")
        }
    }

    func testFasterThanBaselineDoesNotFireRegression() throws {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "test-bench",
                stats: sampleStats()),
            to: path)
        // Measured is 50% FASTER — should not fire regression.
        let measured = sampleStats(meanMultiplier: 0.50)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "test-bench",
                baselinePath: path)
        XCTAssertEqual(verdict, .withinTolerance)
    }

    func testCustomToleranceIsRespected() throws {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "test-bench",
                stats: sampleStats()),
            to: path)
        // 30% slower — would fire under default 25% tolerance,
        // but tighten test tolerance to 50% — no regression.
        let measured = sampleStats(meanMultiplier: 1.30)
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "test-bench",
                baselinePath: path,
                toleranceFraction: 0.50)
        XCTAssertEqual(verdict, .withinTolerance)
    }

    func testZeroBaselineMetricsAreSkipped() throws {
        let path = tempDir.appendingPathComponent(
            "baseline.json")
        // Baseline with all-zero stats — comparison should not
        // throw on division by zero.
        let zeroStats = BASBenchLatencyStats(
            sampleCount: 0,
            min: 0, max: 0, mean: 0,
            p50: 0, p95: 0, p99: 0, p999: 0,
            standardDeviation: 0, outlierCount: 0)
        try BASBenchBaselineStorage.writeBaseline(
            envelope: .init(
                benchName: "zero-bench",
                stats: zeroStats),
            to: path)
        let measured = sampleStats()
        let verdict = try BASBenchBaselineStorage
            .compareToBaseline(
                measured: measured,
                benchName: "zero-bench",
                baselinePath: path)
        // All baseline metrics 0 → all skipped → empty
        // reports → withinTolerance.
        XCTAssertEqual(verdict, .withinTolerance)
    }

    // MARK: - Defaults

    func testDefaultToleranceIsTwentyFivePercent() {
        XCTAssertEqual(
            BASBenchBaselineStorage
                .defaultToleranceFraction, 0.25)
    }

    func testCurrentSchemaVersionIsV1() {
        XCTAssertEqual(
            BASBenchBaselineStorage.currentSchemaVersion,
            "bas-bench-baseline.v1")
    }
}
