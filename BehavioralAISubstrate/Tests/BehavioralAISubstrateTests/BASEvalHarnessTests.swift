// MARK: - BASEvalHarnessTests — chapter 三百七四 / M861
//
// Test coverage for C2 auto eval harness primitives:
//   - BASEvalMetric (typed enum with direction + drift tolerance)
//   - BASEvalRun (Codable bundle of metrics scored)
//   - BASEvalRegressionDetector (per-metric verdict factory)
//
// Tests verify:
//   - Each metric has a direction + drift tolerance (lint guards)
//   - Run Codable round-trip preserves metric keys
//   - Regression: improvement / regression / no-change classified
//     direction-aware
//   - Custom tolerances override defaults
//   - Empty runs return safe defaults (no false signal)
//   - Missing metrics produce `.missing` verdict
//   - Convenience accessors (anyRegressed / allImproved /
//     safeToShip) match expected semantics

import XCTest
@testable import BASRuntimeCore

final class BASEvalHarnessTests: XCTestCase {

    // MARK: - BASEvalMetric: lint guards

    func testEveryMetricHasDirection() {
        // Lint guard: every CaseIterable metric must answer
        // .direction without crashing
        for metric in BASEvalMetric.allCases {
            let direction = metric.direction
            XCTAssertTrue(
                direction == .higherIsBetter
                    || direction == .lowerIsBetter,
                "Metric \(metric.rawValue) must have a typed " +
                "direction")
        }
    }

    func testEveryMetricHasDriftTolerance() {
        // Lint guard: every CaseIterable metric must answer
        // .defaultDriftTolerance with a value in (0, 1)
        for metric in BASEvalMetric.allCases {
            let tolerance = metric.defaultDriftTolerance
            XCTAssertGreaterThan(
                tolerance, 0,
                "Metric \(metric.rawValue) tolerance must be > 0")
            XCTAssertLessThan(
                tolerance, 1,
                "Metric \(metric.rawValue) tolerance must be < 1")
        }
    }

    func testAccuracyDirectionHigherIsBetter() {
        XCTAssertEqual(
            BASEvalMetric.accuracy.direction,
            .higherIsBetter)
    }

    func testLatencyDirectionLowerIsBetter() {
        XCTAssertEqual(
            BASEvalMetric.latencyP50.direction, .lowerIsBetter)
        XCTAssertEqual(
            BASEvalMetric.latencyP95.direction, .lowerIsBetter)
        XCTAssertEqual(
            BASEvalMetric.latencyP99.direction, .lowerIsBetter)
    }

    func testHallucinationAndFailureDirectionLowerIsBetter() {
        XCTAssertEqual(
            BASEvalMetric.hallucinationRate.direction,
            .lowerIsBetter)
        XCTAssertEqual(
            BASEvalMetric.failureRate.direction,
            .lowerIsBetter)
    }

    func testAccuracyToleranceTightest() {
        // Pin: accuracy tolerance is the smallest of all metrics
        // (high precision required) per chapter 一百八十五
        let allTolerances = BASEvalMetric.allCases.map {
            $0.defaultDriftTolerance
        }
        let accuracyTolerance =
            BASEvalMetric.accuracy.defaultDriftTolerance
        XCTAssertEqual(
            accuracyTolerance, allTolerances.min(),
            "Accuracy must have tightest tolerance")
    }

    // MARK: - BASEvalRun: Codable round-trip

    func testRunCodableRoundTrip() throws {
        let run = BASEvalRun(
            runID: "test-run-1",
            timestampMs: 1_700_000_000_000,
            metrics: [
                .accuracy: 0.95,
                .latencyP95: 250.0,
                .hallucinationRate: 0.02,
            ],
            buildChapter: "M861",
            hostFingerprint: "iPhone15Pro-iOS18.0-nominal",
            sampleCount: 1_000)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(run)
        let decoded = try decoder.decode(
            BASEvalRun.self, from: data)

        XCTAssertEqual(decoded.runID, run.runID)
        XCTAssertEqual(decoded.timestampMs, run.timestampMs)
        XCTAssertEqual(decoded.metrics, run.metrics)
        XCTAssertEqual(
            decoded.buildChapter, run.buildChapter)
        XCTAssertEqual(
            decoded.hostFingerprint, run.hostFingerprint)
        XCTAssertEqual(
            decoded.sampleCount, run.sampleCount)
        XCTAssertEqual(decoded, run)
    }

    func testRunEncodingIsHumanReadable() throws {
        // Pin: metrics encode as JSON object keyed by raw value,
        // not as Swift's default heterogeneous-key array form
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 0,
            metrics: [.accuracy: 0.9],
            buildChapter: "M861",
            hostFingerprint: "test",
            sampleCount: 10)

        let data = try JSONEncoder().encode(run)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(
            json.contains("\"accuracy\":0.9"),
            "Metrics must encode by raw value as JSON object: " +
            "got \(json)")
    }

    func testRunDecodingDropsUnknownMetricsForwardCompat() throws
    {
        // Pin: unknown metric raw values silently drop, not crash
        // (forward-compat: future metrics added by newer hosts)
        let json = """
        {
          "runID":"r1",
          "timestampMs":0,
          "metrics":{"accuracy":0.9,"unknown-future-metric":1.0},
          "buildChapter":"M861",
          "hostFingerprint":"test",
          "sampleCount":1
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASEvalRun.self, from: data)
        XCTAssertEqual(decoded.metrics.count, 1)
        XCTAssertEqual(
            decoded.metrics[.accuracy], 0.9)
    }

    func testEmptyRunSentinel() {
        let empty = BASEvalRun.empty()
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.sampleCount, 0)
        XCTAssertTrue(empty.metrics.isEmpty)
    }

    func testIsEmptyTrueWhenSampleCountZero() {
        let zeroSamples = BASEvalRun(
            runID: "r1",
            timestampMs: 0,
            metrics: [.accuracy: 0.9],
            buildChapter: "M861",
            hostFingerprint: "test",
            sampleCount: 0)
        XCTAssertTrue(
            zeroSamples.isEmpty,
            "Zero sample count → effectively empty (avoids " +
            "false regression signals)")
    }

    func testValueLookup() {
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 0,
            metrics: [.accuracy: 0.9],
            buildChapter: "M861",
            hostFingerprint: "test",
            sampleCount: 10)
        XCTAssertEqual(run.value(for: .accuracy), 0.9)
        XCTAssertNil(run.value(for: .latencyP50))
    }

    // MARK: - BASEvalRegressionDetector: improvement detection

    func testAccuracyImprovementClassified() {
        let baseline = makeRun(metrics: [.accuracy: 0.90])
        let candidate = makeRun(metrics: [.accuracy: 0.95])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        let result = report.results[.accuracy]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.verdict, .improved)
        XCTAssertEqual(result?.baselineValue, 0.90)
        XCTAssertEqual(result?.candidateValue, 0.95)
    }

    func testAccuracyRegressionClassified() {
        let baseline = makeRun(metrics: [.accuracy: 0.95])
        let candidate = makeRun(metrics: [.accuracy: 0.85])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .regressed)
        XCTAssertTrue(report.anyRegressed)
        XCTAssertFalse(report.allImproved)
    }

    func testLatencyImprovementClassified() {
        // p95 200ms → 100ms is improvement (lowerIsBetter)
        let baseline = makeRun(metrics: [.latencyP95: 200])
        let candidate = makeRun(metrics: [.latencyP95: 100])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.latencyP95]?.verdict, .improved)
    }

    func testLatencyRegressionClassified() {
        // p95 100ms → 200ms is regression (lowerIsBetter)
        let baseline = makeRun(metrics: [.latencyP95: 100])
        let candidate = makeRun(metrics: [.latencyP95: 200])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.latencyP95]?.verdict, .regressed)
    }

    // MARK: - BASEvalRegressionDetector: tolerance band

    func testWithinToleranceIsNoChange() {
        // Default accuracy tolerance is 0.5%; 0.90 → 0.902 is
        // within tolerance
        let baseline = makeRun(metrics: [.accuracy: 0.900])
        let candidate = makeRun(metrics: [.accuracy: 0.902])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .noChange,
            "0.2% delta is within 0.5% accuracy tolerance")
    }

    func testCustomToleranceOverridesDefault() {
        // Default accuracy tolerance is 0.5%; with a 10% custom
        // tolerance, even a 5% drop is no-change
        let baseline = makeRun(metrics: [.accuracy: 0.95])
        let candidate = makeRun(metrics: [.accuracy: 0.90])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate,
            customTolerances: [.accuracy: 0.10])

        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .noChange,
            "5% delta within 10% custom tolerance → noChange")
    }

    func testTighterToleranceCatchesSmallerRegression() {
        let baseline = makeRun(metrics: [.accuracy: 0.900])
        let candidate = makeRun(metrics: [.accuracy: 0.898])
        // Default 0.5% would be noChange; 0.1% catches it
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate,
            customTolerances: [.accuracy: 0.001])

        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .regressed,
            "~0.22% delta > 0.1% custom tolerance → regressed")
    }

    // MARK: - BASEvalRegressionDetector: missing metrics

    func testMetricInBaselineButNotCandidateIsMissing() {
        let baseline = makeRun(metrics: [
            .accuracy: 0.9,
            .latencyP95: 100,
        ])
        let candidate = makeRun(metrics: [.accuracy: 0.92])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.latencyP95]?.verdict, .missing)
    }

    func testMetricInCandidateButNotBaselineIsMissing() {
        let baseline = makeRun(metrics: [.accuracy: 0.9])
        let candidate = makeRun(metrics: [
            .accuracy: 0.92,
            .driftScore: 0.3,
        ])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertEqual(
            report.results[.driftScore]?.verdict, .missing)
    }

    // MARK: - BASEvalRegressionDetector: empty-run safety

    func testEmptyBaselineReturnsAllNoChange() {
        let baseline = BASEvalRun.empty()
        let candidate = makeRun(metrics: [.accuracy: 0.95])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertFalse(
            report.anyRegressed,
            "Empty baseline must NEVER produce regression " +
            "signal (avoids false alarms on first run)")
        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .noChange)
    }

    func testEmptyCandidateReturnsAllNoChange() {
        let baseline = makeRun(metrics: [.accuracy: 0.95])
        let candidate = BASEvalRun.empty()
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertFalse(report.anyRegressed)
        XCTAssertEqual(
            report.results[.accuracy]?.verdict, .noChange)
    }

    // MARK: - Convenience accessors

    func testAnyRegressedAndAllImproved() {
        let baseline = makeRun(metrics: [
            .accuracy: 0.9,
            .latencyP95: 100,
        ])
        let candidate = makeRun(metrics: [
            .accuracy: 0.95,   // improved
            .latencyP95: 80,   // improved
        ])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertFalse(report.anyRegressed)
        XCTAssertTrue(report.allImproved)
        XCTAssertTrue(report.safeToShip)
        XCTAssertEqual(report.improvedMetrics.count, 2)
        XCTAssertEqual(report.regressedMetrics.count, 0)
    }

    func testMixedReportIsNotSafeToShip() {
        let baseline = makeRun(metrics: [
            .accuracy: 0.9,
            .latencyP95: 100,
        ])
        let candidate = makeRun(metrics: [
            .accuracy: 0.95,    // improved
            .latencyP95: 200,   // regressed
        ])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        XCTAssertTrue(report.anyRegressed)
        XCTAssertFalse(report.allImproved)
        XCTAssertFalse(
            report.safeToShip,
            "Mixed improvements + regressions → not safe to ship")
    }

    // MARK: - Codable round-trip on report

    func testReportCodableRoundTrip() throws {
        let baseline = makeRun(
            runID: "base-1",
            metrics: [.accuracy: 0.9])
        let candidate = makeRun(
            runID: "cand-1",
            metrics: [.accuracy: 0.95])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            BASEvalRegressionReport.self, from: data)

        XCTAssertEqual(
            decoded.baselineRunID, "base-1")
        XCTAssertEqual(
            decoded.candidateRunID, "cand-1")
        XCTAssertEqual(
            decoded.results[.accuracy]?.verdict, .improved)
    }

    // MARK: - Helpers

    private func makeRun(
        runID: String = "test-run",
        metrics: [BASEvalMetric: Double]
    ) -> BASEvalRun {
        BASEvalRun(
            runID: runID,
            timestampMs: 1_700_000_000_000,
            metrics: metrics,
            buildChapter: "M861-test",
            hostFingerprint: "test-fingerprint",
            sampleCount: 100)
    }
}
