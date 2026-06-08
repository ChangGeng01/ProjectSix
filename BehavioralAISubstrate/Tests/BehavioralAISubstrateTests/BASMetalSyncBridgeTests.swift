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

    func testResultBoxIsOneShot() {
        let box = BASSyncResultBox<Int>()
        XCTAssertNil(box.take())
        box.set(42)
        XCTAssertEqual(box.take(), 42)
        XCTAssertNil(box.take(), "one-shot: a second take is nil")
    }
}
