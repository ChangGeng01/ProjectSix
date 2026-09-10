import XCTest
@testable import BASObservability

/// M355 — pin the typed benchmark latency statistics primitive.
///
/// What this file pins:
///
///   1. compute() returns nil for empty input.
///   2. p50/p95/p99/p99.9 use nearest-rank algorithm
///      (`ceil(p × N) - 1`).
///   3. Variance uses population formula (`/ N`, not `/ (N-1)`).
///   4. Outlier count = samples beyond 3 standard deviations
///      from mean.
///   5. Single-sample input has stddev = 0 and outliers = 0.
///   6. Codable round-trip stable.
///   7. bannerLines produces uniformly-formatted multi-line output.
///   8. Computed properties (variance / outlierRate / coefficient
///      of variation) match expectations including edge cases.
final class M355BenchLatencyStatsTests: XCTestCase {

    func testEmptyInputReturnsNil() {
        XCTAssertNil(BASBenchLatencyStats.compute(samples: []))
    }

    func testSingleSampleHasZeroSpread() {
        let stats = BASBenchLatencyStats.compute(
            samples: [42.0])!
        XCTAssertEqual(stats.sampleCount, 1)
        XCTAssertEqual(stats.min, 42.0)
        XCTAssertEqual(stats.max, 42.0)
        XCTAssertEqual(stats.mean, 42.0)
        XCTAssertEqual(stats.p50, 42.0)
        XCTAssertEqual(stats.p95, 42.0)
        XCTAssertEqual(stats.p99, 42.0)
        XCTAssertEqual(stats.p999, 42.0)
        XCTAssertEqual(stats.standardDeviation, 0)
        XCTAssertEqual(stats.outlierCount, 0)
    }

    func testKnownInputReproducesExpectedStats() {
        // 100 samples, deterministic.
        let samples = (1...100).map { Double($0) }
        let stats = BASBenchLatencyStats.compute(
            samples: samples)!
        XCTAssertEqual(stats.sampleCount, 100)
        XCTAssertEqual(stats.min, 1.0)
        XCTAssertEqual(stats.max, 100.0)
        XCTAssertEqual(stats.mean, 50.5)
        // nearest-rank p50: ceil(0.5*100)-1 = 49 → samples[49] = 50.0
        XCTAssertEqual(stats.p50, 50.0)
        // nearest-rank p95: ceil(0.95*100)-1 = 94 → samples[94] = 95.0
        XCTAssertEqual(stats.p95, 95.0)
        // nearest-rank p99: ceil(0.99*100)-1 = 98 → samples[98] = 99.0
        XCTAssertEqual(stats.p99, 99.0)
        // nearest-rank p99.9: ceil(0.999*100)-1 = 99 → samples[99] = 100.0
        XCTAssertEqual(stats.p999, 100.0)
    }

    func testPopulationVarianceFormula() {
        // Samples [1, 2, 3, 4, 5] — mean = 3, variance population
        // = (4+1+0+1+4)/5 = 2, stddev = sqrt(2) ≈ 1.4142.
        // Sample formula would give 10/4 = 2.5 — pin we use
        // population formula not sample.
        let stats = BASBenchLatencyStats.compute(
            samples: [1.0, 2.0, 3.0, 4.0, 5.0])!
        XCTAssertEqual(stats.mean, 3.0)
        XCTAssertEqual(
            stats.standardDeviation,
            2.0.squareRoot(),
            accuracy: 1e-10)
        XCTAssertEqual(
            stats.variance, 2.0, accuracy: 1e-10)
    }

    func testOutlierCountDetectsSamplesBeyondThreeSigma() {
        // 1000 samples of 0.5, plus one outlier at 1000.
        var samples = [Double](
            repeating: 0.5, count: 1000)
        samples.append(1000.0)
        let stats = BASBenchLatencyStats.compute(
            samples: samples)!
        // Mean ≈ 1.5; stddev high; the 1000.0 is way beyond 3σ.
        XCTAssertGreaterThanOrEqual(stats.outlierCount, 1)
    }

    func testOutlierCountIsZeroForUniformSamples() {
        // All samples identical → stddev = 0 → no outliers
        // (compute() guards against threshold = 0).
        let stats = BASBenchLatencyStats.compute(
            samples: Array(repeating: 5.0, count: 100))!
        XCTAssertEqual(stats.outlierCount, 0)
    }

    func testOutlierRateClampsToZeroForEmptyOrZeroSampleCount()
    {
        let zero = BASBenchLatencyStats(
            sampleCount: 0, min: 0, max: 0, mean: 0,
            p50: 0, p95: 0, p99: 0, p999: 0,
            standardDeviation: 0, outlierCount: 0)
        XCTAssertEqual(zero.outlierRate, 0)
    }

    func testCoefficientOfVariationHandlesZeroMean() {
        let zero = BASBenchLatencyStats(
            sampleCount: 100, min: 0, max: 0, mean: 0,
            p50: 0, p95: 0, p99: 0, p999: 0,
            standardDeviation: 0.5, outlierCount: 0)
        XCTAssertEqual(zero.coefficientOfVariation, 0)
    }

    func testCoefficientOfVariationKnownInput() {
        let s = BASBenchLatencyStats(
            sampleCount: 10, min: 0, max: 10, mean: 5.0,
            p50: 0, p95: 0, p99: 0, p999: 0,
            standardDeviation: 1.0, outlierCount: 0)
        XCTAssertEqual(s.coefficientOfVariation, 0.2)
    }

    func testCodableRoundTrip() throws {
        let original = BASBenchLatencyStats.compute(
            samples: [1.0, 2.0, 3.0, 4.0, 5.0])!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASBenchLatencyStats.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testBannerLinesProducesExpectedShape() {
        let stats = BASBenchLatencyStats.compute(
            samples: [1.0, 2.0, 3.0])!
        let lines = stats.bannerLines(unit: "ms")
        // Lines: samples / min / p50 / p95 / p99 / p99.9 / max
        // / mean / stddev / outliers / CV
        XCTAssertEqual(lines.count, 11)
        XCTAssertTrue(lines[0].contains("samples:"))
        XCTAssertTrue(lines[0].contains("3"))
        XCTAssertTrue(lines[1].contains("min:"))
        XCTAssertTrue(lines[1].contains("ms"))
        XCTAssertTrue(lines.last!.contains("CV:"))
    }

    func testPercentileNearestRankExactBoundary() {
        let sorted = [1.0, 2.0, 3.0, 4.0, 5.0]
        // p=0 → ceil(0)-1 = -1 → clamped to 0 → 1.0
        XCTAssertEqual(
            BASBenchLatencyStats.percentile(
                sorted: sorted, p: 0), 1.0)
        // p=1 → ceil(5)-1 = 4 → 5.0
        XCTAssertEqual(
            BASBenchLatencyStats.percentile(
                sorted: sorted, p: 1.0), 5.0)
        // p=0.5 → ceil(2.5)-1 = 2 → 3.0
        XCTAssertEqual(
            BASBenchLatencyStats.percentile(
                sorted: sorted, p: 0.5), 3.0)
    }

    func testPercentileEmptySortedReturnsZero() {
        XCTAssertEqual(
            BASBenchLatencyStats.percentile(
                sorted: [], p: 0.5),
            0)
    }

    func testTenThousandSampleStatsAreReasonable() {
        // Synthesize 10000 samples uniformly distributed in [0, 100].
        var samples: [Double] = []
        var seed: UInt64 = 42
        for _ in 0..<10_000 {
            // LCG for deterministic test - not crypto-grade.
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let normalized = Double(seed >> 11)
                / Double(1 << 53)
            samples.append(normalized * 100.0)
        }
        let stats = BASBenchLatencyStats.compute(
            samples: samples)!
        XCTAssertEqual(stats.sampleCount, 10_000)
        XCTAssertGreaterThanOrEqual(stats.min, 0)
        XCTAssertLessThanOrEqual(stats.max, 100)
        XCTAssertEqual(stats.mean, 50.0, accuracy: 2.0)
        // Uniform distribution → p50 ≈ 50, p95 ≈ 95, p99 ≈ 99.
        XCTAssertEqual(stats.p50, 50.0, accuracy: 2.0)
        XCTAssertEqual(stats.p95, 95.0, accuracy: 2.0)
        XCTAssertEqual(stats.p99, 99.0, accuracy: 2.0)
    }
}
