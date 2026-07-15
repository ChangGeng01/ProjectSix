import XCTest
@testable import BASMLXAdapter

/// audit M-g — the B2 post-prefill difficulty probe REFINES the decode
/// budget after reading the prefill hidden state. It must only ever spend
/// LESS than the caller asked: floored at 8, and never above the caller's
/// `maxTokens`. The old inline `max(8, probe)` let a probe returning a
/// large number overrun the caller's hard limit.
final class BASClampedProbeBudgetTests: XCTestCase {

    private func clamp(_ p: Int, _ m: Int) -> Int {
        BASQwen35MTPSpecDecoder.clampedProbeBudget(p, maxTokens: m)
    }

    func testProbeRefinesDownWithinRange() {
        XCTAssertEqual(clamp(50, 200), 50, "an in-range probe budget passes through")
    }

    /// THE fix — a probe cannot overrun the caller's maxTokens。
    func testProbeCannotExceedMaxTokens() {
        XCTAssertEqual(clamp(500, 200), 200,
            "a probe asking for more than the caller's ceiling is clamped to it")
    }

    func testProbeFlooredAtEight() {
        XCTAssertEqual(clamp(3, 200), 8, "a tiny probe can't kill generation — floor 8")
    }

    /// Floor never beats the ceiling — a caller asking for < 8 gets its
    /// exact limit, not the floor。
    func testMaxTokensBelowFloorWins() {
        XCTAssertEqual(clamp(3, 5), 5, "never exceed maxTokens, even under the floor")
        XCTAssertEqual(clamp(500, 5), 5)
    }

    func testProbeEqualsMaxTokens() {
        XCTAssertEqual(clamp(200, 200), 200)
    }
}
