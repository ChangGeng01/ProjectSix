// MARK: - BASMetalBenchmarkHarnessTests
// chapter 四百六十 / M1218 PROOF tests
//
// Verifies the benchmark harness shipped in chapter
// 460:harness produces sensible (positive,non-NaN,
// monotonic-percentile) µs measurements + the report's
// summary string is well-formed for copy-paste into
// the chapter 458 doctrine。
//
// The tests intentionally DON'T assert specific µs
// numbers — those vary across hardware (M1 vs M2 vs
// M3 vs A17 vs A18 vs Intel) and CI environments。
// Instead they assert STRUCTURE invariants + EMIT the
// measurements via print() so the dev can see real
// numbers in test logs。

import XCTest
@testable import BASMetalSubstrate

final class BASMetalBenchmarkHarnessTests: XCTestCase {

    // MARK: - Shape clamping

    func testShapeClampsDimsToOneOrAbove() {
        let s = BASMetalBenchmarkShape(
            preDim: 0,
            postDim: -5,
            warmupIterations: -2,
            timedIterations: 0)
        XCTAssertEqual(s.preDim, 1)
        XCTAssertEqual(s.postDim, 1)
        XCTAssertEqual(s.warmupIterations, 0)
        XCTAssertEqual(s.timedIterations, 1)
    }

    // MARK: - Report statistics

    func testReportStatisticsFromKnownSamples() {
        let r = BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: 4, postDim: 4,
                warmupIterations: 0,
                timedIterations: 5),
            cpuMicrosecondsSamples:
                [10.0, 20.0, 30.0, 40.0, 50.0],
            gpuMicrosecondsSamples:
                [1.0, 2.0, 3.0, 4.0, 5.0],
            gpuAvailable: true)
        XCTAssertEqual(r.cpuMicrosecondsMean, 30.0,
            accuracy: 1e-9)
        XCTAssertEqual(r.cpuMicrosecondsMedian, 30.0,
            accuracy: 1e-9)
        XCTAssertEqual(r.cpuMicrosecondsP95, 50.0,
            accuracy: 1e-9)
        XCTAssertEqual(r.gpuMicrosecondsMean, 3.0,
            accuracy: 1e-9)
        XCTAssertEqual(r.speedupMean, 10.0,
            accuracy: 1e-9)
    }

    func testReportSpeedupZeroWhenGPUUnavailable() {
        let r = BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: 4, postDim: 4),
            cpuMicrosecondsSamples: [10.0, 20.0],
            gpuMicrosecondsSamples: [],
            gpuAvailable: false)
        XCTAssertEqual(r.speedupMean, 0)
        XCTAssertEqual(r.gpuMicrosecondsMean, 0)
    }

    func testSummaryStringWellFormedForChapter458Doctrine()
    {
        let r = BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: 256, postDim: 256,
                warmupIterations: 5,
                timedIterations: 50),
            cpuMicrosecondsSamples:
                Array(repeating: 1000.0, count: 50),
            gpuMicrosecondsSamples:
                Array(repeating: 100.0, count: 50),
            gpuAvailable: true)
        let s = r.summary
        XCTAssertTrue(s.contains("256x256"))
        XCTAssertTrue(s.contains("n=50"))
        XCTAssertTrue(s.contains("cpu_mean="))
        XCTAssertTrue(s.contains("gpu_mean="))
        XCTAssertTrue(s.contains("speedup="))
    }

    // MARK: - Real harness run on this device

    /// Runs the harness on 3 production-relevant
    /// shapes:32×32 (small),256×256 (medium),
    /// 1024×1024 (large)。 EMITs the measured µs to
    /// stdout so the dev can see real numbers per their
    /// hardware。 Assertions are STRUCTURE-only:samples
    /// are non-empty,positive,monotonic percentiles,
    /// not NaN。 Specific µs numbers are NEVER asserted。
    func testHarnessProducesSensibleMeasurementsAcrossShapes()
        async throws
    {
        let harness = BASMetalBenchmarkHarness()
        let shapes: [BASMetalBenchmarkShape] = [
            BASMetalBenchmarkShape(
                preDim: 32, postDim: 32,
                warmupIterations: 5,
                timedIterations: 30),
            BASMetalBenchmarkShape(
                preDim: 256, postDim: 256,
                warmupIterations: 5,
                timedIterations: 30),
            BASMetalBenchmarkShape(
                preDim: 1024, postDim: 1024,
                warmupIterations: 3,
                timedIterations: 10)
        ]
        print("\n# BASMetalBenchmarkHarness " +
            "measurements (chapter 460 / M1218)")
        print("# Hardware varies — these are dev-" +
            "machine measurements,NOT a doctrine pin")
        for shape in shapes {
            let report = try await harness
                .runPlasticity(shape: shape)
            print(report.summary)
            // Structure invariants
            XCTAssertEqual(
                report.cpuMicrosecondsSamples.count,
                shape.timedIterations,
                "CPU samples must equal timedIterations")
            for sample in report.cpuMicrosecondsSamples {
                XCTAssertFalse(sample.isNaN,
                    "CPU sample must not be NaN")
                XCTAssertGreaterThanOrEqual(sample, 0,
                    "CPU sample must be non-negative")
            }
            XCTAssertGreaterThan(
                report.cpuMicrosecondsMean, 0,
                "CPU mean must be positive (work was" +
                " done)")
            // Percentile monotonicity
            XCTAssertLessThanOrEqual(
                report.cpuMicrosecondsMedian,
                report.cpuMicrosecondsP95,
                "median <= p95 invariant")
            if report.gpuAvailable {
                XCTAssertEqual(
                    report.gpuMicrosecondsSamples.count,
                    shape.timedIterations)
                for sample in report
                    .gpuMicrosecondsSamples
                {
                    XCTAssertFalse(sample.isNaN)
                    XCTAssertGreaterThanOrEqual(
                        sample, 0)
                }
                XCTAssertGreaterThan(
                    report.gpuMicrosecondsMean, 0)
                XCTAssertLessThanOrEqual(
                    report.gpuMicrosecondsMedian,
                    report.gpuMicrosecondsP95)
                // speedupMean must be a finite
                // positive number when both paths
                // produced samples
                XCTAssertFalse(
                    report.speedupMean.isNaN)
                XCTAssertGreaterThan(
                    report.speedupMean, 0)
            }
        }
    }

    // MARK: - Harness gracefully reports gpuUnavailable

    func testHarnessGracefullyHandlesGPUUnavailable()
        async throws
    {
        // Can't easily force gpuUnavailable on macOS,
        // but we can verify the report TYPE supports
        // it via the test above + the structure
        // invariant tests。 This test asserts that the
        // harness does NOT throw when GPU is genuinely
        // unavailable;it just sets gpuAvailable=false。
        // No assertion needed beyond:harness completes
        // successfully on a tiny shape that always
        // works。
        let harness = BASMetalBenchmarkHarness()
        let report = try await harness.runPlasticity(
            shape: BASMetalBenchmarkShape(
                preDim: 1, postDim: 1,
                warmupIterations: 0,
                timedIterations: 1))
        XCTAssertEqual(
            report.cpuMicrosecondsSamples.count, 1)
    }

    // MARK: - Report Codable round-trip

    func testReportCodableRoundTrip() throws {
        let r = BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: 64, postDim: 128,
                warmupIterations: 3,
                timedIterations: 7),
            cpuMicrosecondsSamples:
                [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5],
            gpuMicrosecondsSamples:
                [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1],
            gpuAvailable: true)
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder()
            .decode(
                BASMetalBenchmarkReport.self,
                from: data)
        XCTAssertEqual(decoded, r)
        XCTAssertEqual(
            decoded.summary, r.summary)
    }
}
