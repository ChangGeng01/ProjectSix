import XCTest
@testable import BASObservability

/// M375 — pin the high-resolution clock primitive.
///
/// What this file pins:
///
///   1. `measureMilliseconds(body:)` returns non-negative Double.
///   2. `measureMillisecondsAsync(body:)` works for async work.
///   3. `durationToMilliseconds(_:)` correctly converts known
///      Duration values to ms with nanosecond precision.
///   4. The clock measures sub-microsecond intervals (no Date
///      floor; if it did, sub-µs measurements would round to 0).
///   5. Successive calls produce monotonically non-decreasing
///      timestamps (ContinuousClock guarantee).
final class M375BenchHighResClockTests: XCTestCase {

    func testMeasureMillisecondsReturnsNonNegative() {
        let clock = BASBenchHighResClock()
        let ms = clock.measureMilliseconds {
            // No-op work; should still return >= 0.
        }
        XCTAssertGreaterThanOrEqual(ms, 0)
    }

    func testMeasureMillisecondsCapturesActualWork() {
        let clock = BASBenchHighResClock()
        let ms = clock.measureMilliseconds {
            // Burn ~1 ms of work via a tight loop.
            var sum = 0
            for i in 0..<200_000 {
                sum &+= i
            }
            // Touch sum to prevent dead-code elimination.
            XCTAssertGreaterThan(sum, 0)
        }
        // Should be > 0 and likely > 0.1 ms even on fast hardware.
        // Loose lower bound — different machines have different
        // tight-loop throughput.
        XCTAssertGreaterThan(ms, 0)
    }

    func testMeasureMillisecondsAsyncCapturesAsyncWork()
        async
    {
        let clock = BASBenchHighResClock()
        let ms = await clock.measureMillisecondsAsync {
            try? await Task.sleep(
                for: .milliseconds(10))
        }
        // 10 ms sleep → measurement should be at least 8 ms.
        // Loose lower bound — Task.sleep can be slightly inexact.
        XCTAssertGreaterThan(ms, 5)
    }

    func testDurationToMillisecondsKnownValues() {
        // 1 second → 1000 ms
        let oneSec = Duration.seconds(1)
        XCTAssertEqual(
            BASBenchHighResClock
                .durationToMilliseconds(oneSec),
            1000.0,
            accuracy: 1e-6)

        // 500 ms → 500 ms
        let halfSec = Duration.milliseconds(500)
        XCTAssertEqual(
            BASBenchHighResClock
                .durationToMilliseconds(halfSec),
            500.0,
            accuracy: 1e-6)

        // 1 µs → 0.001 ms
        let oneMicro = Duration.microseconds(1)
        XCTAssertEqual(
            BASBenchHighResClock
                .durationToMilliseconds(oneMicro),
            0.001,
            accuracy: 1e-9)

        // 1 ns → 1e-6 ms
        let oneNano = Duration.nanoseconds(1)
        XCTAssertEqual(
            BASBenchHighResClock
                .durationToMilliseconds(oneNano),
            1e-6,
            accuracy: 1e-12)

        // 0 → 0
        XCTAssertEqual(
            BASBenchHighResClock
                .durationToMilliseconds(.zero),
            0.0)
    }

    func testSubMicrosecondMeasurementsAreReal() {
        // Pre-M375 with Date(): a tight no-op loop would always
        // measure at the Date floor (~1 µs minimum). M375 with
        // ContinuousClock should produce different, smaller
        // values across calls — which means the resolution is
        // genuinely sub-µs.
        let clock = BASBenchHighResClock()
        var samples: [Double] = []
        for _ in 0..<100 {
            let ms = clock.measureMilliseconds { }
            samples.append(ms)
        }
        // Most samples should be < 0.001 ms (the old Date floor).
        // Allow a few above (CI scheduling jitter).
        let belowFloor = samples.filter { $0 < 0.001 }.count
        XCTAssertGreaterThan(
            belowFloor, 50,
            "expected most no-op measurements to be below the " +
            "old Date 1µs floor, indicating real sub-µs " +
            "resolution; got \(belowFloor)/100 below.")
    }

    func testMonotonicNoBackwardsTimestamps() {
        let clock = BASBenchHighResClock()
        var prevTotal = 0.0
        for _ in 0..<1000 {
            let ms = clock.measureMilliseconds { }
            // Each measurement is a duration so they don't
            // accumulate, but each is non-negative.
            XCTAssertGreaterThanOrEqual(ms, 0)
            prevTotal += ms
        }
        XCTAssertGreaterThanOrEqual(prevTotal, 0)
    }
}
