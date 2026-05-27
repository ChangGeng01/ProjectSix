// MARK: - BASCognitiveBrainSummaryLatencyBudgetTests
// Boundary tests for the latency budget surface on
// BASCognitiveBrainSummary。 Pure arithmetic,but the
// integer-math truncation + clamping rules need pinning。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainSummaryLatencyBudgetTests:
    XCTestCase
{

    // Helper: build a summary with a fixed latency
    // (other fields are irrelevant for budget arithmetic)。
    private func makeSummary(latencyNanos: UInt64)
        -> BASCognitiveBrainSummary
    {
        return BASCognitiveBrainSummary(
            input: "test",
            taskType: .chat,
            confidence: 1.0,
            ambiguityScore: 0.0,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: latencyNanos)
    }

    // MARK: - latencyMilliseconds conversion

    func testZeroLatencyReportsZeroMilliseconds() {
        let s = makeSummary(latencyNanos: 0)
        XCTAssertEqual(s.latencyMilliseconds, 0)
    }

    func testSubMillisecondLatencyTruncatesToZero() {
        // 999_999ns = 0.999ms → truncates to 0ms
        let s = makeSummary(latencyNanos: 999_999)
        XCTAssertEqual(s.latencyMilliseconds, 0,
            "Integer truncation must yield 0 for" +
            " sub-millisecond latencies")
    }

    func testExactlyOneMillisecondLatency() {
        let s = makeSummary(latencyNanos: 1_000_000)
        XCTAssertEqual(s.latencyMilliseconds, 1)
    }

    func testLargeLatencyConversion() {
        // 1.5s = 1500ms = 1_500_000_000ns
        let s = makeSummary(latencyNanos: 1_500_000_000)
        XCTAssertEqual(s.latencyMilliseconds, 1500)
    }

    // MARK: - exceededBudget by milliseconds

    func testZeroBudgetExceededByAnyNonZeroLatency() {
        let s = makeSummary(latencyNanos: 1)
        XCTAssertTrue(
            s.exceededBudget(milliseconds: 0))
    }

    func testZeroBudgetNotExceededByZeroLatency() {
        let s = makeSummary(latencyNanos: 0)
        XCTAssertFalse(
            s.exceededBudget(milliseconds: 0))
    }

    func testLatencyEqualToBudgetIsNotExceeded() {
        // 1ms latency, 1ms budget → NOT exceeded
        // (strict greater-than semantics)
        let s = makeSummary(latencyNanos: 1_000_000)
        XCTAssertFalse(
            s.exceededBudget(milliseconds: 1),
            "Latency exactly equal to budget should NOT" +
            " be reported as exceeded (strict >)")
    }

    func testLatencyOneNanoOverBudgetIsExceeded() {
        // 1ms+1ns latency, 1ms budget → exceeded
        let s = makeSummary(latencyNanos: 1_000_001)
        XCTAssertTrue(
            s.exceededBudget(milliseconds: 1))
    }

    func testNegativeBudgetClampedToZero() {
        let s = makeSummary(latencyNanos: 0)
        XCTAssertFalse(s.exceededBudget(milliseconds: -10),
            "Negative budget must clamp to 0;zero" +
            " latency does not exceed clamped budget")
        let s2 = makeSummary(latencyNanos: 1)
        XCTAssertTrue(s2.exceededBudget(milliseconds: -10),
            "Negative budget clamps to 0;any non-zero" +
            " latency must exceed")
    }

    // MARK: - exceededBudget via deviceState

    func testDeviceStateBudgetIntegration() {
        let deviceState = BASDeviceState(
            batteryLevel: 1.0,
            thermalLevel: .nominal,
            memoryFreeMB: 1024,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.0,
            gpuLoad: 0.0,
            npuAvailable: false,
            latencyBudgetMs: 100)
        let underBudget = makeSummary(
            latencyNanos: 50_000_000)        // 50ms
        let overBudget = makeSummary(
            latencyNanos: 200_000_000)       // 200ms
        XCTAssertFalse(
            underBudget.exceededBudget(
                deviceState: deviceState))
        XCTAssertTrue(
            overBudget.exceededBudget(
                deviceState: deviceState))
    }

    // MARK: - Real brain summary integration

    func testRealBrainSummaryUnderDefaultBudget() async throws {
        // The default device-state budget is 1500ms。 A
        // real cognitive cascade today executes in ~1-50ms
        // depending on CoreML compile state — well under
        // 1500ms。 This test guards against a future
        // regression that would push real summary() latency
        // beyond the declared budget。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let summary = await brain.summary("hello")
        let underBudget = !summary.exceededBudget(
            milliseconds: 1500)
        XCTAssertTrue(underBudget,
            "Real brain.summary() latency" +
            " \(summary.latencyMilliseconds)ms must be" +
            " under the 1500ms default budget。 If this" +
            " fails,either the cascade slowed down or" +
            " CoreML compile time regressed.")
    }

    // MARK: - Codable wire format invariance

    func testLatencyBudgetExtensionDoesNotChangeCodableFormat()
        throws
    {
        // The extension adds methods,not fields。 Codable
        // round-trip must still yield the same fields。
        // This pins the chapter 392 replay-determinism
        // contract for BASCognitiveBrainSummary。
        let s = makeSummary(latencyNanos: 1_234_567)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(s)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASCognitiveBrainSummary.self, from: data)
        XCTAssertEqual(s, decoded,
            "Codable round-trip must preserve all fields" +
            " even after the latency-budget extension was" +
            " added")
    }
}
#endif
