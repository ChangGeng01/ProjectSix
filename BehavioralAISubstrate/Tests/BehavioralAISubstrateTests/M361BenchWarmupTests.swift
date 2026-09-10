import XCTest
@testable import BASObservability

/// M361 — pin the warmup configuration + cold/warm split
/// outcome primitive.
///
/// What this file pins:
///
///   1. `BASBenchWarmupConfig.coldSampleCount` clamps negative
///      values to 0.
///   2. `compute()` returns nil for empty input.
///   3. `compute()` returns combined / cold / warm stats with
///      correct sample counts.
///   4. With `coldSampleCount > samples.count`, all samples are
///      cold and warm is nil.
///   5. With `includeColdInWarm == true`, warm includes cold
///      samples too.
///   6. With `coldSampleCount == 0`, cold is nil and warm
///      equals combined.
///   7. Codable round-trip stable.
///   8. Banner lines include cold and warm sections only when
///      they have samples.
///   9. Convenience constants (`.none` / `.strictFirstSample`
///      / `.extended`) have expected shape.
///   10. Real-world cold-spike scenario: cold stat has higher
///      mean than warm stat.
final class M361BenchWarmupTests: XCTestCase {

    func testNegativeColdCountClampsToZero() {
        let config = BASBenchWarmupConfig(
            coldSampleCount: -5)
        XCTAssertEqual(config.coldSampleCount, 0)
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(
            BASBenchWarmupOutcome.compute(samples: []))
    }

    func testStrictFirstSampleSplit() {
        // Samples [50, 5, 5, 5, 5] — cold=50, warm avg ~5
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [50.0, 5.0, 5.0, 5.0, 5.0],
            config: .strictFirstSample)!
        XCTAssertEqual(
            outcome.combined.sampleCount, 5)
        XCTAssertEqual(outcome.cold?.sampleCount, 1)
        XCTAssertEqual(outcome.cold?.mean, 50.0)
        XCTAssertEqual(outcome.warm?.sampleCount, 4)
        XCTAssertEqual(outcome.warm?.mean, 5.0)
    }

    func testColdCountExceedsSampleCountAllCold() {
        // 3 samples, coldSampleCount=10 → all 3 are cold,
        // warm is nil.
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [10.0, 20.0, 30.0],
            config: BASBenchWarmupConfig(
                coldSampleCount: 10))!
        XCTAssertEqual(outcome.cold?.sampleCount, 3)
        XCTAssertNil(outcome.warm)
    }

    func testIncludeColdInWarmKeepsAllSamplesInWarm() {
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [50.0, 5.0, 5.0, 5.0, 5.0],
            config: BASBenchWarmupConfig(
                coldSampleCount: 1,
                includeColdInWarm: true))!
        XCTAssertEqual(outcome.cold?.sampleCount, 1)
        // warm includes all 5 samples (cold inclusive).
        XCTAssertEqual(outcome.warm?.sampleCount, 5)
        XCTAssertEqual(outcome.warm?.mean,
                       outcome.combined.mean)
    }

    func testZeroColdCountWarmEqualsCombined() {
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [10.0, 20.0, 30.0],
            config: .none)!
        XCTAssertNil(outcome.cold)
        XCTAssertEqual(outcome.warm?.sampleCount, 3)
        XCTAssertEqual(outcome.warm, outcome.combined)
    }

    func testCodableRoundTrip() throws {
        let original = BASBenchWarmupOutcome.compute(
            samples: [50.0, 5.0, 5.0, 5.0, 5.0])!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASBenchWarmupOutcome.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testBannerLinesShowAllPresentSections() {
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [50.0, 5.0, 5.0, 5.0, 5.0])!
        let lines = outcome.bannerLines(unit: "ms")
        let combined = lines.contains {
            $0.contains("combined")
        }
        let cold = lines.contains {
            $0.contains("cold")
        }
        let warm = lines.contains {
            $0.contains("warm")
        }
        XCTAssertTrue(combined)
        XCTAssertTrue(cold)
        XCTAssertTrue(warm)
    }

    func testBannerLinesOmitsColdSectionWhenZero() {
        let outcome = BASBenchWarmupOutcome.compute(
            samples: [10.0, 20.0, 30.0],
            config: .none)!
        let lines = outcome.bannerLines()
        let cold = lines.contains {
            $0.contains("── cold")
        }
        XCTAssertFalse(cold)
    }

    func testConveniencesHaveExpectedShape() {
        XCTAssertEqual(
            BASBenchWarmupConfig.none.coldSampleCount, 0)
        XCTAssertEqual(
            BASBenchWarmupConfig.strictFirstSample
                .coldSampleCount, 1)
        XCTAssertEqual(
            BASBenchWarmupConfig.extended
                .coldSampleCount, 5)
        // None of them include cold in warm.
        XCTAssertFalse(
            BASBenchWarmupConfig.none.includeColdInWarm)
        XCTAssertFalse(
            BASBenchWarmupConfig.strictFirstSample
                .includeColdInWarm)
        XCTAssertFalse(
            BASBenchWarmupConfig.extended
                .includeColdInWarm)
    }

    func testRealWorldColdSpikeIsolated() {
        // M359 full-stack-bench smoke shape: 3 cold spikes
        // dominate p95 of combined, but warm distribution is
        // tight. Pin that the cold/warm split reveals this.
        let samples = [
            45.0, 12.0, 38.0,  // cold spikes
            5.5, 5.2, 5.4, 5.3, 5.5, 5.4, 5.6,  // warm
        ]
        let outcome = BASBenchWarmupOutcome.compute(
            samples: samples,
            config: BASBenchWarmupConfig(
                coldSampleCount: 3))!
        // Cold mean: (45+12+38)/3 ≈ 31.7
        XCTAssertEqual(
            outcome.cold!.mean, 31.67, accuracy: 0.01)
        // Warm mean: (5.5+5.2+5.4+5.3+5.5+5.4+5.6)/7 ≈ 5.41
        XCTAssertEqual(
            outcome.warm!.mean, 5.41, accuracy: 0.01)
        // Cold p99 dominated by spike; warm p99 close to mean.
        XCTAssertGreaterThan(
            outcome.cold!.mean, outcome.warm!.mean)
        XCTAssertLessThan(
            outcome.warm!.coefficientOfVariation,
            outcome.combined.coefficientOfVariation)
    }
}
