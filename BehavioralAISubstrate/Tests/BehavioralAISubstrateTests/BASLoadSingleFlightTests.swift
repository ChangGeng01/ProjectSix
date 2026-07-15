import XCTest
@testable import BASMLXAdapter

#if canImport(MLXLLM)
/// audit mlx-adapter-core MED-9 — loadModel had no in-flight dedup: two concurrent callers
/// both passed the `modelContainer != nil` guard and BOTH ran the download/materialize
/// (the container is assigned only AFTER the await), doubling the transient footprint into
/// a load-time jetsam SIGKILL. `_loadOnce` runs the materialize at most once concurrently.
/// Pure actor coordination — no model load, no MLX runtime.
final class BASLoadSingleFlightTests: XCTestCase {

    private func makeAdapter() -> MLXOrganAdapter {
        MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)   // never loadModel'd — pure state
    }

    private actor Counter {
        private(set) var value = 0
        func inc() { value += 1 }
    }

    func testConcurrentLoadOnceMaterializesExactlyOnce() async throws {
        let adapter = makeAdapter()
        let counter = Counter()
        // 20 concurrent callers; the materialize sleeps so the window stays open and every
        // later caller observes the first in flight.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await adapter._loadOnce {
                        await counter.inc()
                        try? await Task.sleep(nanoseconds: 3_000_000)
                    }
                }
            }
            try await group.waitForAll()
        }
        let n = await counter.value
        XCTAssertEqual(n, 1,
            "concurrent _loadOnce must materialize exactly once — the rest await the first")
    }

    func testSecondSequentialLoadOnceStillRunsWhenNotLoaded() async throws {
        // Sanity: with no model loaded and no concurrency, a fresh call still materializes
        // (the dedup is for CONCURRENT callers, not a permanent latch).
        let adapter = makeAdapter()
        let counter = Counter()
        try await adapter._loadOnce { await counter.inc() }
        try await adapter._loadOnce { await counter.inc() }
        let n = await counter.value
        XCTAssertEqual(n, 2, "sequential calls (no in-flight overlap) each run the materialize")
    }
}
#endif
