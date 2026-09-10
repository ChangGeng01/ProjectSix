// MARK: - BASChapter952BenchmarkRegressionFuzzTests
// chapter 九百五十二 / M3465
//
// User directive (verbatim): 「极大 提高 benchmark」 — performance
// gates that catch regressions when fuzzed inputs drive code paths
// past existing perf ceilings。
//
// Approach (measurement-first per ch 854/870 discipline):
//   1. Run N fuzz iterations against each hot-path API
//   2. Record per-iter wall-clock latency
//   3. Compute p50 / p95 / p99 from the sample
//   4. Assert p99 stays under a CEILING tuned for the target
//      device (iPhone Air arm64 vs macOS host)
//
// Why fuzz inputs for benchmarks:hardcoded inputs measure ONE
// shape's perf。 Procedural inputs measure perf ACROSS the input
// space — surfacing inputs that hit slow paths (e.g. cosine-topk
// with mostly-zero vectors,event-log writes at degenerate seq
// boundaries)。 If p99 explodes for SOME shapes,that's a perf
// bug the hardcoded benchmark would never catch。
//
// Per ch 870 + ch 854:CEILINGS are CONSERVATIVE upper bounds
// (3-5× the typical p99 observed during dev),tuned to catch
// 「something got 10× slower」 regressions without flaking on
// device-vs-host jitter。 Don't tighten without re-baselining。

import XCTest
import BASRuntimeCore
@testable import BASMemory

final class BASChapter952BenchmarkRegressionFuzzTests: XCTestCase {

    // MARK: - Tunable iteration counts

    /// Per-test fuzz iteration count。 Default 100 (fast local
    /// run);device run sets via `BAS_FUZZ_BENCH_ITER=N` for
    /// longer sampling。
    private var benchIterCount: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_BENCH_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 100
    }

    /// Skip benchmarks unless explicitly enabled。 Local CI runs
    /// thousands of tests — benchmarks shouldn't slow that down。
    /// Set `BAS_FUZZ_BENCH_RUN=1` (or device-run profile) to
    /// enable。
    private func requireBenchmarkRun() throws {
        if ProcessInfo.processInfo
            .environment["BAS_FUZZ_BENCH_RUN"] == nil
        {
            throw XCTSkip("Benchmark regression gates skipped — " +
                          "set BAS_FUZZ_BENCH_RUN=1 to enable")
        }
    }

    // MARK: - Helper: percentile calc

    /// Compute percentile p ∈ [0, 1] of `samples` (e.g. p=0.99
    /// returns 99th-percentile value)。 Returns 0 for empty input。
    private func percentile(
        _ samples: [Double],
        _ p: Double
    ) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let idx = max(0, min(sorted.count - 1,
                             Int(Double(sorted.count - 1) * p)))
        return sorted[idx]
    }

    /// Helper:run an async closure N times measuring per-iter
    /// duration in milliseconds。 Returns the array of samples。
    private func sampleAsync(
        _ count: Int,
        op: (Int) async throws -> Void
    ) async rethrows -> [Double] {
        var samples: [Double] = []
        samples.reserveCapacity(count)
        for i in 0..<count {
            let t0 = ContinuousClock().now
            try await op(i)
            let elapsed = ContinuousClock().now - t0
            // Convert Duration to milliseconds (attoseconds → ms)
            let asec = elapsed.components.attoseconds
            let sec = elapsed.components.seconds
            let ms = Double(sec) * 1_000.0 +
                Double(asec) / 1_000_000_000_000_000.0
            samples.append(ms)
        }
        return samples
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    private func tempURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch952-bench-\(tag)-\(UUID().uuidString).sqlite")
    }

    // MARK: - L8 AtomLifecycle append benchmark

    /// Benchmark L8 AtomLifecycle event append under fuzzed event
    /// shapes。 Asserts p99 < CEILING_MS。
    ///
    /// Baseline (macOS host,Apple M-series): typical p99 ~5ms。
    /// Ceiling set to 50ms (10× margin) for device-vs-host jitter。
    func testL8AtomLifecycleAppendP99WithinCeiling() async throws {
        try requireBenchmarkRun()
        let url = tempURL("l8-append")
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        let samples = try await sampleAsync(
            benchIterCount
        ) { i in
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(rng: &rng)
            _ = try await store.appendEvent(event)
        }
        let p50 = percentile(samples, 0.50)
        let p95 = percentile(samples, 0.95)
        let p99 = percentile(samples, 0.99)
        let p99Ceiling = 50.0  // ms
        let p50Str = String(format: "%.2f", p50)
        let p95Str = String(format: "%.2f", p95)
        let p99Str = String(format: "%.2f", p99)
        print("ch952-bench L8.append: " +
              "p50=\(p50Str)ms p95=\(p95Str)ms " +
              "p99=\(p99Str)ms " +
              "ceiling=\(p99Ceiling)ms n=\(samples.count)")
        XCTAssertLessThan(p99, p99Ceiling,
            "L8 AtomLifecycle append p99 regression: " +
            "p99=\(p99)ms > ceiling=\(p99Ceiling)ms")
    }

    /// Benchmark L8 events(forAtom:) read under random workload。
    /// Pre-seeds 1000 events,then reads back N times。
    func testL8EventsForAtomReadP99WithinCeiling() async throws {
        try requireBenchmarkRun()
        let url = tempURL("l8-read")
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        // Seed corpus
        let atomIDs = (0..<10).map { "atom-bench-\($0)" }
        var seedRng = BASFuzzRng(seed: 1)
        for _ in 0..<1000 {
            let atomID = seedRng.pick(atomIDs)
            let event = BASFuzzL8.atomLifecycleEvent(
                rng: &seedRng,
                atomID: atomID)
            _ = try await store.appendEvent(event)
        }
        // Sample reads
        let samples = await sampleAsync(
            benchIterCount
        ) { i in
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let atomID = rng.pick(atomIDs)
            _ = await store.events(forAtom: atomID)
        }
        let p50 = percentile(samples, 0.50)
        let p95 = percentile(samples, 0.95)
        let p99 = percentile(samples, 0.99)
        let p99Ceiling = 100.0  // ms (1000 rows pre-seeded)
        let p50Str = String(format: "%.2f", p50)
        let p95Str = String(format: "%.2f", p95)
        let p99Str = String(format: "%.2f", p99)
        print("ch952-bench L8.events(forAtom:): " +
              "p50=\(p50Str)ms p95=\(p95Str)ms " +
              "p99=\(p99Str)ms " +
              "ceiling=\(p99Ceiling)ms n=\(samples.count)")
        XCTAssertLessThan(p99, p99Ceiling,
            "L8 events(forAtom:) p99 regression: " +
            "p99=\(p99)ms > ceiling=\(p99Ceiling)ms")
    }

    // MARK: - UserState append + state(forID:) benchmark

    /// Benchmark UserState append under fuzzed state shapes。
    func testUserStateAppendP99WithinCeiling() async throws {
        try requireBenchmarkRun()
        let url = tempURL("userstate-append")
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(databaseURL: url)
        let samples = try await sampleAsync(
            benchIterCount
        ) { i in
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let state = BASFuzzL8.userState(rng: &rng)
            let sessID = "sess-bench-\(rng.next())"
            _ = try await store.append(state, sessionID: sessID)
        }
        let p50 = percentile(samples, 0.50)
        let p95 = percentile(samples, 0.95)
        let p99 = percentile(samples, 0.99)
        let p99Ceiling = 50.0  // ms
        let p50Str = String(format: "%.2f", p50)
        let p95Str = String(format: "%.2f", p95)
        let p99Str = String(format: "%.2f", p99)
        print("ch952-bench UserState.append: " +
              "p50=\(p50Str)ms p95=\(p95Str)ms " +
              "p99=\(p99Str)ms " +
              "ceiling=\(p99Ceiling)ms n=\(samples.count)")
        XCTAssertLessThan(p99, p99Ceiling,
            "UserState append p99 regression: " +
            "p99=\(p99)ms > ceiling=\(p99Ceiling)ms")
    }

    // MARK: - EventLog append benchmark

    /// Benchmark EventLog append under fuzzed entry shapes。
    func testEventLogAppendP99WithinCeiling() async throws {
        try requireBenchmarkRun()
        let url = tempURL("eventlog-append")
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(databaseURL: url)
        let samples = try await sampleAsync(
            benchIterCount
        ) { i in
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let entry = BASFuzzL8.eventLogEntry(rng: &rng)
            _ = try await store.append(entry)
        }
        let p50 = percentile(samples, 0.50)
        let p95 = percentile(samples, 0.95)
        let p99 = percentile(samples, 0.99)
        let p99Ceiling = 50.0  // ms
        let p50Str = String(format: "%.2f", p50)
        let p95Str = String(format: "%.2f", p95)
        let p99Str = String(format: "%.2f", p99)
        print("ch952-bench EventLog.append: " +
              "p50=\(p50Str)ms p95=\(p95Str)ms " +
              "p99=\(p99Str)ms " +
              "ceiling=\(p99Ceiling)ms n=\(samples.count)")
        XCTAssertLessThan(p99, p99Ceiling,
            "EventLog append p99 regression: " +
            "p99=\(p99)ms > ceiling=\(p99Ceiling)ms")
    }

    // MARK: - L8 distribution self-test

    /// Smoke test verifying that the procedural generators
    /// actually produce a SHAPE DIVERSITY across N seeds (not
    /// stuck on one value)。 Fuzz coverage that's 100 copies of
    /// the same input is worthless。
    func testFuzzDistributionShapeDiversitySmoke() {
        var phaseCounts: [UInt8: Int] = [:]
        var atomIDs: Set<String> = []
        for i in 0..<200 {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(rng: &rng)
            phaseCounts[event.fromPhaseByte, default: 0] += 1
            atomIDs.insert(event.atomID)
        }
        // Should see at least 3 distinct phases in 200 samples
        XCTAssertGreaterThanOrEqual(
            phaseCounts.keys.count, 3,
            "fuzz gen for fromPhaseByte too narrow: " +
            "saw only \(phaseCounts.keys.sorted())")
        // Should see ≥ 50 unique atomIDs in 200 samples (mostly random)
        XCTAssertGreaterThanOrEqual(
            atomIDs.count, 50,
            "fuzz gen for atomID too narrow: " +
            "saw only \(atomIDs.count) unique IDs in 200 samples")
    }
}
