import XCTest
@testable import BASMLXAdapter

/// gaps-reconciliation MED-8 (2026-07-11): the generic single-flight slot behind
/// MLXOrganAdapter._resolveMTPDecoderBox. These teeth prove the CONTROL FLOW on Mac (the fix
/// sketch's "injected construction counter"): concurrent cold callers build exactly once, errors
/// propagate to every waiter and clear the slot, and sequential callers rebuild (caching is the
/// caller's job). The ~300MB MTP payoff itself is device-runtime-observable (adjudicated).
final class BASSingleFlightSlotTests: XCTestCase {

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func increment() -> Int { lock.withLock { n += 1; return n } }
        var value: Int { lock.withLock { n } }
    }

    func testConcurrentCallersBuildExactlyOnce() async throws {
        let slot = BASSingleFlightSlot<Int>()
        let builds = Counter()
        let results = try await withThrowingTaskGroup(of: Int.self) { group -> [Int] in
            for _ in 0..<8 {
                group.addTask {
                    try await slot.run {
                        let n = builds.increment()
                        try? await Task.sleep(nanoseconds: 10_000_000)   // hold the window open
                        return n * 100
                    }
                }
            }
            var out: [Int] = []
            for try await r in group { out.append(r) }
            return out
        }
        XCTAssertEqual(builds.value, 1, "8 concurrent callers ⇒ exactly ONE build (the MED-8 property)")
        XCTAssertEqual(Set(results), [100], "every caller gets the SAME build's value")
    }

    func testErrorPropagatesToAllWaitersAndSlotRetries() async {
        struct Boom: Error {}
        let slot = BASSingleFlightSlot<Int>()
        let builds = Counter()
        let failures = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    do {
                        _ = try await slot.run {
                            _ = builds.increment()
                            try? await Task.sleep(nanoseconds: 5_000_000)
                            throw Boom()
                        }
                    } catch { _ = failures.increment() }
                }
            }
            await group.waitForAll()
        }
        XCTAssertEqual(builds.value, 1, "one failing build, not four")
        XCTAssertEqual(failures.value, 4, "the failure reaches EVERY waiter (no silent success)")
        // the slot cleared ⇒ a later call retries fresh
        let retried = try? await slot.run { builds.increment() }
        XCTAssertEqual(retried, 2, "after a failure the slot retries (no poisoned cache)")
    }

    func testSequentialCallersRebuild() async throws {
        let slot = BASSingleFlightSlot<Int>()
        let builds = Counter()
        let a = try await slot.run { builds.increment() }
        let b = try await slot.run { builds.increment() }
        XCTAssertEqual([a, b], [1, 2],
            "sequential calls rebuild — CACHING is the caller's job (mtpDecoderBox), the slot only "
            + "coalesces IN-FLIGHT builds")
    }
}
