// ADR-039 Phase 2 — the async→sync bridge logic (hard timeout + guaranteed fallback). The real Metal
// wedge-leak behavior is an on-device concern; here we certify the BRIDGE: fast→op result, failure→
// fallback, timeout→fallback (never blocks past the timeout).

import XCTest
@testable import BASMetalSubstrate

final class BASMetalSyncBridgeTests: XCTestCase {

    func testReturnsOpResultWhenFastAndNonNil() {
        let (value, usedFallback) = BASMetalSyncBridge.runWithTimeout(
            timeoutMs: 1000, { "metal" }, fallback: { "fallback" })
        XCTAssertEqual(value, "metal")
        XCTAssertFalse(usedFallback)
    }

    func testFallsBackWhenOpReturnsNil() {
        let (value, usedFallback) = BASMetalSyncBridge.runWithTimeout(
            timeoutMs: 1000, { nil as String? }, fallback: { "fallback" })
        XCTAssertEqual(value, "fallback")
        XCTAssertTrue(usedFallback)
    }

    func testFallsBackWhenOpExceedsTimeout() {
        let start = Date()
        let (value, usedFallback) = BASMetalSyncBridge.runWithTimeout(
            timeoutMs: 50,
            { try? await Task.sleep(nanoseconds: 600_000_000); return "slow" },
            fallback: { "fallback" })
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(value, "fallback")
        XCTAssertTrue(usedFallback)
        XCTAssertLessThan(elapsed, 0.5, "must return at the timeout, NOT wait for the slow op")
    }

    func testConcurrentSaturationStaysLive() async {
        // device-recon id11 / gaps[92]: runWithTimeout blocks a COOPERATIVE thread
        // on DispatchSemaphore.wait from a sync context. Launching N > pool-size
        // callers saturates the pool so the inner `Task { await op() }` may be
        // unable to schedule (priority inversion) — but the internal timeout
        // BOUNDS each call, so every one still returns (falling back). This
        // exercises the concurrent-saturation path (Mac-reproducible from LOAD,
        // which gaps[92] conflated with device-only thermal); testFallsBackWhen
        // OpExceedsTimeout only covers a single call.
        //
        // Honest limitation: this is a POSITIVE liveness pin, not adversarially
        // reversible — removing the internal timeout would DEADLOCK the whole
        // cooperative pool (every thread blocked on a never-signaled wait), a
        // hang that no in-pool watchdog could catch (the watchdog can't schedule
        // either). The regression manifests as a runner timeout, not a clean red.
        let n = min(ProcessInfo.processInfo.activeProcessorCount * 2, 16)
        let start = DispatchTime.now()
        let returned = await withTaskGroup(of: Bool.self) { group -> Int in
            for _ in 0..<n {
                group.addTask {
                    let (_, usedFallback) = BASMetalSyncBridge.runWithTimeout(
                        timeoutMs: 40,
                        { try? await Task.sleep(nanoseconds: 300_000_000); return 1 },  // 300ms ≫ 40ms
                        fallback: { 0 })
                    return usedFallback
                }
            }
            var c = 0
            for await _ in group { c += 1 }
            return c
        }
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1e6
        XCTAssertEqual(returned, n,
            "every one of \(n) saturating concurrent calls returned — no unbounded priority inversion")
        XCTAssertLessThan(elapsedMs, 5000,
            "bounded by the per-call timeout, not the 300ms op × n — the sync wait can't stall the pool")
    }

    func testResultBoxIsOneShot() {
        let box = BASSyncResultBox<Int>()
        XCTAssertNil(box.take())
        box.set(42)
        XCTAssertEqual(box.take(), 42)
        XCTAssertNil(box.take(), "one-shot: a second take is nil")
    }
}
