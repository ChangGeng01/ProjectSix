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

    // MARK: - M891 (post-deep-audit) NaN/Infinity validation

    func testM891NaNMetricFilteredAtConstruction() {
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [
                .accuracy: 0.95,
                .latencyP95: .nan,
                .hallucinationRate: .infinity,
                .failureRate: -.infinity,
                .driftScore: 0.5,
            ],
            buildChapter: "M891-test",
            hostFingerprint: "test",
            sampleCount: 10)

        // Non-finite values silently dropped at construction
        // (chapter 一百九十一 substrate-boundary integrity:
        // safer than crash on encode or undefined comparison)
        XCTAssertEqual(run.metrics.count, 2,
            "NaN + Inf + -Inf must be filtered;only " +
            "finite values (accuracy + driftScore) survive")
        XCTAssertNotNil(run.metrics[.accuracy])
        XCTAssertNotNil(run.metrics[.driftScore])
        XCTAssertNil(run.metrics[.latencyP95])
        XCTAssertNil(run.metrics[.hallucinationRate])
        XCTAssertNil(run.metrics[.failureRate])
    }

    func testM891CleanRunCodableRoundTripStillWorks()
        throws
    {
        // Pin:M891 filter doesn't break valid runs。
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 100,
            metrics: [.accuracy: 0.95, .latencyP95: 200],
            buildChapter: "M891",
            hostFingerprint: "test",
            sampleCount: 100)
        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(
            BASEvalRun.self, from: data)
        XCTAssertEqual(decoded, run)
    }

    func testM891NaNRunSerializableAfterFilter() throws {
        // Pin:a run constructed with NaN values must
        // serialize cleanly (NaN got filtered → JSON encode
        // doesn't crash)。Pre-M891 this would throw
        // encodeFailed during storage.append。
        let runWithNaN = BASEvalRun(
            runID: "r-nan",
            timestampMs: 100,
            metrics: [.accuracy: .nan, .latencyP95: 200],
            buildChapter: "M891",
            hostFingerprint: "test",
            sampleCount: 10)
        // Encode must succeed (NaN was filtered)
        XCTAssertNoThrow(
            try JSONEncoder().encode(runWithNaN))
    }

    // M895 (post-deep-audit round 7) — tighter NaN edge case
    // coverage based on test-pin completeness audit findings

    func testM895FilteredRunRoundTripsThroughJSON()
        throws
    {
        // Stronger pin:NaN-containing run must encode AND
        // decode cleanly,with the surviving (finite) values
        // round-tripping byte-equal。
        let original = BASEvalRun(
            runID: "r-nan",
            timestampMs: 100,
            metrics: [
                .accuracy: .nan,
                .latencyP95: 200.0,
                .hallucinationRate: 0.02,
            ],
            buildChapter: "M895",
            hostFingerprint: "test",
            sampleCount: 10)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEvalRun.self, from: data)
        XCTAssertEqual(decoded, original,
            "Filtered run must round-trip byte-equal " +
            "(NaN already filtered at construction,not " +
            "introduced by encode/decode pipeline)")
        XCTAssertEqual(decoded.metrics.count, 2,
            "NaN entry must NOT have round-tripped back")
    }

    func testM895NegativeZeroIsFinitePassesFilter() {
        // -0.0 and +0.0 are both finite per IEEE 754。
        // Filter should pass both through。
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 0,
            metrics: [
                .accuracy: -0.0,
                .latencyP95: 0.0,
            ],
            buildChapter: "M895",
            hostFingerprint: "test",
            sampleCount: 1)
        XCTAssertEqual(run.metrics.count, 2,
            "Both signed zeros are finite,must pass filter")
    }

    func testM895SubnormalNumberPassesFilter() {
        // Smallest positive double > 0 (subnormal range)
        let subnormal = Double.leastNonzeroMagnitude
        XCTAssertTrue(subnormal.isFinite,
            "Subnormal must report isFinite (sanity)")
        let run = BASEvalRun(
            runID: "r1",
            timestampMs: 0,
            metrics: [.accuracy: subnormal],
            buildChapter: "M895",
            hostFingerprint: "test",
            sampleCount: 1)
        XCTAssertEqual(run.metrics.count, 1,
            "Subnormal magnitudes are still finite → " +
            "must pass M891 filter")
    }

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

    // MARK: - M893 baseline-near-zero epsilon guard

    func testM893TinyBaselineUsesAbsoluteDelta() {
        // Pre-M893:baseline 1e-12 + candidate 1.0 → relative
        // delta ~1e12 (numerically unbounded,misleading in
        // dashboards)。Post-M893:baseline below epsilon (1e-9)
        // is treated as effectively zero,comparison uses
        // absolute delta — verdict still classified correctly,
        // but relativeDelta is nil。
        let baseline = makeRun(metrics: [.accuracy: 1e-12])
        let candidate = makeRun(metrics: [.accuracy: 1.0])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        let result = report.results[.accuracy]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.verdict, .improved,
            "Verdict still correct (huge improvement)")
        XCTAssertNil(result?.relativeDelta,
            "Relative delta is nil for near-zero baseline " +
            "(would be unbounded otherwise)")
    }

    func testM893NormalBaselineStillUsesRelativeDelta() {
        // Pin:M893 epsilon guard only kicks in for tiny
        // baselines。Normal baselines (like 0.9) keep using
        // relative delta as before。
        let baseline = makeRun(metrics: [.accuracy: 0.9])
        let candidate = makeRun(metrics: [.accuracy: 0.95])
        let report = BASEvalRegressionDetector.compare(
            baseline: baseline,
            candidate: candidate)

        let result = report.results[.accuracy]
        XCTAssertNotNil(result?.relativeDelta,
            "Normal baselines use relative delta")
        // (cv - bv) / |bv| = 0.05 / 0.9 ≈ 0.0556
        XCTAssertEqual(
            result?.relativeDelta ?? 0, 0.0556,
            accuracy: 0.001)
    }

    func testM893EpsilonConstantPin() {
        // chapter 一百八十五 anti-magic-number pin:epsilon
        // is a typed named constant,not inline magic
        XCTAssertEqual(
            BASEvalRegressionDetector.baselineNearZeroEpsilon,
            1e-9,
            "Epsilon is below typical metric noise floors")
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
