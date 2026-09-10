import Foundation

/// M375 — high-resolution clock for bench sample collection.
///
/// Pre-M375 every bench used `Date()` for timing. `Date` has
/// microsecond resolution at best on Darwin (often only ~1 µs in
/// tight loops because the call itself takes ~100s of nanoseconds).
/// This put a hard floor under sub-microsecond benches:
///
///   - M363 lifecycle bench warm samples cluster at 0.003-0.005 ms
///     — most of that is Date overhead, not lifecycle work
///   - M334 throughput-bench at "0.001 ms" was effectively at the
///     Date resolution floor
///
/// Chapter 八十四.6 Open Opportunity A flagged this directly. M375
/// ships the cure: `ContinuousClock` (Swift 5.7+) provides
/// nanosecond resolution + monotonic guarantees + a much faster
/// per-call cost (~10s of ns).
///
/// ## Doctrine
///
/// - **Monotonic.** ContinuousClock is monotonic — never goes
///   backwards even across system clock adjustments.
/// - **Nanosecond precision.** `Duration.components.attoseconds`
///   is preserved through `nanosecondsBetween(...)` so sub-µs
///   measurements are real signal.
/// - **No baseline incompatibility.** This primitive replaces the
///   `Date()` math inside each bench but the output stays
///   `Double` milliseconds — same shape that
///   `BASBenchLatencyStats.compute(samples:)` expects. No baseline
///   schema changes; existing committed baselines remain valid
///   (though the numbers will look different — they were already
///   noise-floor-limited).
///
/// ## Why milliseconds in / nanosecond precision
///
/// `BASBenchLatencyStats` is unit-agnostic; consumers chose
/// milliseconds for benches that span sub-µs to seconds. M375
/// produces nanosecond-precision Doubles that get scaled to ms
/// before stats compute (so `0.003 ms` = `3000 ns` is preserved
/// as `0.003`, not rounded to the previous Date floor of `0.001`
/// or `0.002`).
public struct BASBenchHighResClock: Sendable {

    private let clock = ContinuousClock()

    public init() {}

    /// Measure the wall-clock duration of `body` and return it
    /// in milliseconds with nanosecond precision. Use inside a
    /// tight bench loop — `body` should be the work being measured.
    public func measureMilliseconds(
        body: () throws -> Void
    ) rethrows -> Double {
        let start = clock.now
        try body()
        let duration = clock.now - start
        return Self.durationToMilliseconds(duration)
    }

    /// Async variant of `measureMilliseconds`. Same contract +
    /// returns ms with ns precision. Use for benches that drive
    /// `async` work (e.g., audit ledger append).
    public func measureMillisecondsAsync(
        body: () async throws -> Void
    ) async rethrows -> Double {
        let start = clock.now
        try await body()
        let duration = clock.now - start
        return Self.durationToMilliseconds(duration)
    }

    /// Convert a `Duration` to milliseconds with nanosecond
    /// precision. Public so callers that already hold a Duration
    /// (e.g., from `clock.measure { ... }`) can scale into the
    /// `Double` unit `BASBenchLatencyStats` expects without
    /// re-implementing the math.
    public static func durationToMilliseconds(
        _ duration: Duration
    ) -> Double {
        let components = duration.components
        // seconds + attoseconds (10⁻¹⁸) → milliseconds (10⁻³)
        // 1 second = 1000 ms; 1 attosecond = 10⁻¹⁵ ms.
        return Double(components.seconds) * 1000.0
            + Double(components.attoseconds) / 1.0e15
    }
}
